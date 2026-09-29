#!/usr/bin/env bash
# Build and publish older commits on demand - the optional companion to the AFK poller
# (tools/pipeline-poll.sh), which only ever builds master's newest commit. Use it to get a
# win-<sha> release for commits the poller skipped, e.g. to bisect a regression in game with
# `bash tools/fetch-and-play.sh <commit>` on the Windows PC.
#
# Usage: bash tools/pipeline-backfill.sh <commit-ish | A..B> [...]
#   <commit-ish> - one commit, e.g. a0fe3fa or a PR's merge commit.
#   A..B         - every commit on B's first-parent chain after A, oldest first: for master, one
#                  merge commit per PR (never the individual feature-branch commits each merge brought
#                  in - same reasoning as the poller's --first-parent). E.g. 5d915e6..origin/master.
#
# Each commit goes through `tools/pipeline-process-commit.sh --backfill`, one at a time: the same
# clean-worktree build and full suite as the poller, but a green release is never marked Latest and
# the pipeline:red issue is never touched - an old commit's result says nothing about master now.
# Already-published commits are a quick no-op (process-commit's own idempotency check). A red
# commit gets no release and backfilling carries on with the next one - for a bisect, knowing which
# commits are red is the point. An environment blocker (3) or a pipeline error (2) stops the run:
# every later commit would hit the same problem.
#
# Exit status:
#   0 - every commit is published (just now, or already was).
#   1 - finished, but at least one commit was red (no release for it).
#   2 - usage error, a commit-ish/range that doesn't resolve, or a pipeline error stopped the run.
#   3 - an environment blocker stopped the run (see that commit's ENVIRONMENT line).
#
# Injectable for testing (tools/test-pipeline-backfill.sh):
#   - CHEXTREK_PIPELINE_BACKFILL_CMD - the per-commit command, `eval`'d with the commit's full SHA
#                                      appended (default:
#                                      "bash \"${SCRIPT_DIR}/pipeline-process-commit.sh\" --backfill").
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

if [ "$#" -eq 0 ]; then
	echo "Usage: bash tools/pipeline-backfill.sh <commit-ish | A..B> [...]" >&2
	exit 2
fi

# So a commit or range naming something only just pushed resolves. Best effort: a failed fetch
# still lets locally-known commits resolve; anything that doesn't is reported below.
if git -C "$REPO_ROOT" remote get-url origin >/dev/null 2>&1; then
	git -C "$REPO_ROOT" fetch --quiet origin 2>&1 || echo "==> warning: 'git fetch origin' failed - resolving against local refs only"
fi

# --- resolve every argument up front, so a typo fails before any build starts ---
COMMITS=()
for ARG in "$@"; do
	case "$ARG" in
	*..*)
		if ! RANGE_RAW="$(git -C "$REPO_ROOT" rev-list --first-parent --reverse "$ARG" 2>/dev/null)"; then
			echo "error: '${ARG}' isn't a valid range in ${REPO_ROOT}" >&2
			exit 2
		fi
		if [ -z "$RANGE_RAW" ]; then
			echo "error: '${ARG}' contains no commits" >&2
			exit 2
		fi
		mapfile -t RANGE <<<"$RANGE_RAW"
		COMMITS+=("${RANGE[@]}")
		;;
	*)
		SHA="$(git -C "$REPO_ROOT" rev-parse --verify --quiet "${ARG}^{commit}")"
		if [ -z "$SHA" ]; then
			echo "error: '${ARG}' doesn't resolve to a commit in ${REPO_ROOT}" >&2
			exit 2
		fi
		COMMITS+=("$SHA")
		;;
	esac
done

CMD="${CHEXTREK_PIPELINE_BACKFILL_CMD:-bash \"${SCRIPT_DIR}/pipeline-process-commit.sh\" --backfill}"

echo "=== pipeline-backfill: ${#COMMITS[@]} commit(s), oldest first ==="
RESULTS=()
EXIT=0
for SHA in "${COMMITS[@]}"; do
	echo "==> backfilling ${SHA}"
	eval "$CMD" '"$SHA"'
	CODE=$?
	case "$CODE" in
	0) RESULTS+=("${SHA} published") ;;
	1)
		RESULTS+=("${SHA} red - no release")
		EXIT=1
		;;
	3)
		RESULTS+=("${SHA} environment blocker - stopped here")
		EXIT=3
		break
		;;
	*)
		RESULTS+=("${SHA} pipeline error (exit ${CODE}) - stopped here")
		EXIT=2
		break
		;;
	esac
done

echo
echo "=== pipeline-backfill: summary ==="
printf '%s\n' "${RESULTS[@]}"
if [ "${#RESULTS[@]}" -lt "${#COMMITS[@]}" ]; then
	echo "($(( ${#COMMITS[@]} - ${#RESULTS[@]} )) later commit(s) not attempted)"
fi
exit "$EXIT"
