#!/usr/bin/env bash
# Pipeline entry point (spec #58/#66): "process commit X". Checks X out into its own clean
# worktree - never the owner's or an agent's working copy - builds chextrek.dll and runs the full
# suite (tools/run-all-tests.sh) against that worktree, and on green publishes X as a GitHub
# Release tagged win-<sha>, targeting X, with chextrek.dll and chextrek.pdb as assets, marked
# Latest (not prerelease), notes containing the suite summary. Idempotent: re-processing an
# already-published commit publishes nothing new.
#
# Invoked by hand for now (#66) - no trigger yet (#68) and no red-issue handling yet (#67). This
# script's exit codes are the seam #67 hangs off of: 1 (red) vs 3 (environment blocker) are always
# kept distinct, the same contract tools/run-all-tests.sh already makes.
#
# Usage: tools/pipeline-process-commit.sh <commit-ish>
#
# Exit status:
#   0 - the commit is published: either a new release was created just now, or one already existed
#       for this commit (idempotent no-op - AC "re-processing doesn't create a duplicate release").
#   1 - the suite ran and found a real test FAIL - nothing published.
#   2 - a pipeline-level error (bad commit-ish, missing built assets, a worktree/gh failure) - not
#       a game result.
#   3 - an environment blocker, propagated verbatim from tools/run-all-tests.sh's own exit 3 (e.g.
#       Wine not on PATH, missing Doom 3 data) - not a test result.
#
# Logs: one file per run under CHEXTREK_PIPELINE_STATE_DIR's logs/ subdirectory (see below) -
# outside every repo and worktree, so they survive worktree cleanup and are readable without a
# checkout. Every run's outcome (published/red/environment/error) is on the last line.
#
# Injectable for testing (tools/test-pipeline-process-commit.sh stubs every one of these - a test
# must never point any of them at the real wScottSh/chex-trek repo or a real `gh`):
#   - gh                            - put a fake `gh` earlier on PATH (repo convention - see
#                                     tools/test-run-all-tests-*.sh). This script only ever calls
#                                     `gh release view` / `gh release create`, both with an explicit
#                                     --repo, so a test's fake repo name is enough to keep a broken
#                                     stub from ever reaching a real repo even if PATH leaks.
#   - CHEXTREK_PIPELINE_REPO        - owner/repo passed to every `gh` call (default: parsed from
#                                     `git remote get-url origin` of the repo this script lives in).
#   - CHEXTREK_PIPELINE_SUITE_CMD   - the build+test command run inside the scratch worktree,
#                                     via `bash -c`, cwd set to that worktree (default:
#                                     "bash tools/run-all-tests.sh" - the harness's own Wine must
#                                     already be on PATH, same as docs/agents/unicron-build-test.md;
#                                     this script prepends the default Wine location itself if
#                                     `wine` isn't already on PATH, so it works unattended too).
#   - CHEXTREK_PIPELINE_STATE_DIR   - root for scratch worktrees and logs, outside every
#                                     repo/worktree (default: $XDG_STATE_HOME/chextrek-pipeline, or
#                                     $HOME/.local/state/chextrek-pipeline).
#   - CHEXTREK_PIPELINE_TAG_PREFIX  - release tag prefix (default: "win-").
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

usage() {
	echo "Usage: tools/pipeline-process-commit.sh <commit-ish>" >&2
}

COMMITISH="${1:-}"
if [ -z "$COMMITISH" ]; then
	usage
	exit 2
fi

# --- resolve the exact commit up front: a moving ref like "master" must be pinned to one sha now,
# so the release tag, the worktree checkout and the notes all agree on the exact same commit ---
FULL_SHA="$(git -C "$REPO_ROOT" rev-parse --verify "${COMMITISH}^{commit}" 2>/dev/null)"
if [ -z "$FULL_SHA" ]; then
	echo "error: '${COMMITISH}' doesn't resolve to a commit in $(git -C "$REPO_ROOT" rev-parse --show-toplevel 2>/dev/null || echo "$REPO_ROOT")" >&2
	exit 2
fi
SHORT_SHA="$(git -C "$REPO_ROOT" rev-parse --short "$FULL_SHA")"

TAG_PREFIX="${CHEXTREK_PIPELINE_TAG_PREFIX:-win-}"
TAG="${TAG_PREFIX}${SHORT_SHA}"

# --- repo: explicit override for tests, else parsed from this checkout's own origin remote -
# never inferred by `gh` implicitly, so every `gh` call below states its target in its own argv ---
if [ -n "${CHEXTREK_PIPELINE_REPO:-}" ]; then
	REPO="$CHEXTREK_PIPELINE_REPO"
else
	REMOTE_URL="$(git -C "$REPO_ROOT" remote get-url origin 2>/dev/null)"
	if [ -z "$REMOTE_URL" ]; then
		echo "error: no 'origin' remote in $(git -C "$REPO_ROOT" rev-parse --show-toplevel) and CHEXTREK_PIPELINE_REPO isn't set" >&2
		exit 2
	fi
	REPO="$(printf '%s' "$REMOTE_URL" | sed -E 's#^(git\+ssh://|ssh://)?(git@)?github\.com[:/]##; s#\.git$##')"
fi

if ! command -v gh >/dev/null 2>&1; then
	echo "error: gh not found on PATH" >&2
	exit 2
fi

# --- state dir: outside every repo/worktree on purpose, so worktree cleanup below never touches
# it and logs outlive the scratch checkout they describe ---
STATE_DIR="${CHEXTREK_PIPELINE_STATE_DIR:-${XDG_STATE_HOME:-${HOME}/.local/state}/chextrek-pipeline}"
LOG_DIR="${STATE_DIR}/logs"
WORKTREE_ROOT="${STATE_DIR}/worktrees"
mkdir -p "$LOG_DIR" "$WORKTREE_ROOT"

RUN_STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
# $$ guards against two runs of the *same* commit (e.g. an idempotent re-run right after the
# first) landing in the same wall-clock second and clobbering each other's log file.
LOG_FILE="${LOG_DIR}/${RUN_STAMP}-${TAG}-$$.log"
: > "$LOG_FILE"

log() {
	printf '%s\n' "$*" | tee -a "$LOG_FILE"
}

log "=== pipeline: process commit ${FULL_SHA} (${TAG}) -> ${REPO} ==="
log "log: ${LOG_FILE}"

# --- idempotency (AC: re-processing the same commit doesn't create a duplicate release): check
# before doing any build work, so a repeat run of an already-published commit is cheap ---
if gh release view "$TAG" --repo "$REPO" >>"$LOG_FILE" 2>&1; then
	log "OUTCOME: already published - ${TAG} already exists on ${REPO}, nothing to do"
	exit 0
fi

# --- clean worktree: never the caller's own working copy. A stale worktree from a crashed prior
# run of this exact commit is removed first, so this run starts from a genuinely clean checkout ---
WT_DIR="${WORKTREE_ROOT}/${TAG}"
WT_CREATED=0
cleanup() {
	if [ "$WT_CREATED" = "1" ] && [ -d "$WT_DIR" ]; then
		git -C "$REPO_ROOT" worktree remove --force "$WT_DIR" >>"$LOG_FILE" 2>&1
		git -C "$REPO_ROOT" worktree prune >>"$LOG_FILE" 2>&1 || true
	fi
}
trap cleanup EXIT

if [ -d "$WT_DIR" ]; then
	log "==> stale scratch worktree at ${WT_DIR} from an earlier run - removing it first"
	git -C "$REPO_ROOT" worktree remove --force "$WT_DIR" >>"$LOG_FILE" 2>&1 || rm -rf "$WT_DIR"
	git -C "$REPO_ROOT" worktree prune >>"$LOG_FILE" 2>&1 || true
fi

log "==> checking out ${FULL_SHA} into its own worktree at ${WT_DIR}"
if ! git -C "$REPO_ROOT" worktree add --detach "$WT_DIR" "$FULL_SHA" >>"$LOG_FILE" 2>&1; then
	log "OUTCOME: pipeline error - couldn't create the scratch worktree for ${FULL_SHA}"
	exit 2
fi
WT_CREATED=1

# --- build + full suite, run inside that scratch worktree only ---
if ! command -v wine >/dev/null 2>&1 && [ -x /opt/wine-11.0-wow64/bin/wine ]; then
	# The harness's own Wine (docs/dev-setup.md) isn't on PATH by default in a fresh/unattended
	# shell - put it there ourselves so this entry point doesn't depend on the caller remembering
	# the `export` from docs/agents/unicron-build-test.md (matters once #68 invokes this
	# unattended, with nobody around to have set up their shell first).
	export PATH="/opt/wine-11.0-wow64/bin:${PATH}"
fi

SUITE_CMD="${CHEXTREK_PIPELINE_SUITE_CMD:-bash tools/run-all-tests.sh}"
log "==> running suite: ${SUITE_CMD}"
(cd "$WT_DIR" && eval "$SUITE_CMD") >>"$LOG_FILE" 2>&1
SUITE_EXIT=$?
log "==> suite exited ${SUITE_EXIT}"

if [ "$SUITE_EXIT" = "3" ]; then
	log "OUTCOME: environment blocker - see the ENVIRONMENT line above; nothing published"
	exit 3
fi
if [ "$SUITE_EXIT" != "0" ]; then
	log "OUTCOME: red - the suite failed; nothing published"
	exit 1
fi

# --- green: publish ---
DLL="${WT_DIR}/chextrek.dll"
PDB="${WT_DIR}/chextrek.pdb"
if [ ! -f "$DLL" ] || [ ! -f "$PDB" ]; then
	log "OUTCOME: pipeline error - suite passed but ${DLL} and/or ${PDB} are missing"
	exit 2
fi

SUMMARY="$(sed -n '/^=== summary:/,$p' "$LOG_FILE")"
NOTES="$(printf 'Pipeline build of %s (%s).\n\n%s\n' "$FULL_SHA" "$TAG" "$SUMMARY")"

log "==> publishing ${TAG} (target ${FULL_SHA}) with chextrek.dll + chextrek.pdb, marked Latest"
if gh release create "$TAG" \
	--repo "$REPO" \
	--target "$FULL_SHA" \
	--title "$TAG" \
	--notes "$NOTES" \
	--latest \
	"$DLL" "$PDB" >>"$LOG_FILE" 2>&1; then
	log "OUTCOME: published - ${TAG} created on ${REPO}, marked Latest"
	exit 0
fi

# `gh release create` failed - the only expected reason is a race with another run of the same
# commit publishing first between the idempotency check above and here. Re-check before calling
# this a pipeline error.
if gh release view "$TAG" --repo "$REPO" >>"$LOG_FILE" 2>&1; then
	log "OUTCOME: already published - lost a race with another run of the same commit; nothing to do"
	exit 0
fi

log "OUTCOME: pipeline error - gh release create failed and ${TAG} still doesn't exist on ${REPO}"
exit 2
