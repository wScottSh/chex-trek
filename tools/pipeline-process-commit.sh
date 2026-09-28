#!/usr/bin/env bash
# Pipeline entry point (spec #58/#66): "process commit X". Checks X out into its own clean
# worktree - never the owner's or an agent's working copy - builds chextrek.dll and runs the full
# suite (tools/run-all-tests.sh) against that worktree, and on green publishes X as a GitHub
# Release tagged win-<sha>, targeting X, with chextrek.dll and chextrek.pdb as assets, marked
# Latest (not prerelease), notes containing the suite summary. Idempotent: re-processing an
# already-published commit publishes nothing new.
#
# Invoked by hand for now (#66) - no trigger yet (#68) and no red-issue handling yet (#67). This
# script's exit codes are the seam #67 hangs off of: 1 (red), 3 (environment blocker) and 2
# (pipeline error - not a game result either way) are always kept distinct, the same 0/1/3 contract
# tools/run-all-tests.sh already makes, plus 2 for this script's own failure modes. A per-commit
# lock (see below) makes two runs of the same commit safe to overlap - #68's poller and a by-hand
# run, or two by-hand runs, can never corrupt each other's scratch worktree.
#
# Usage: tools/pipeline-process-commit.sh <commit-ish>
#
# Exit status:
#   0 - the commit is published: either a new release was created just now, or one already existed
#       for this commit (idempotent no-op - AC "re-processing doesn't create a duplicate release").
#   1 - the suite ran and reported an ordinary FAIL (exit 1) - nothing published.
#   2 - a pipeline-level error: bad commit-ish, missing built assets, a worktree/gh failure, or the
#       suite exited with anything other than 0/1/3 (e.g. killed by a signal) - never treated as a
#       red test result, since it isn't one. Not a game result.
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
#   - CHEXTREK_PIPELINE_SUITE_CMD   - the build+test command run inside the scratch worktree, via
#                                     `eval`, cwd set to that worktree (default:
#                                     "bash tools/run-all-tests.sh"). This script prepends the
#                                     harness's own Wine location to PATH itself if `wine` isn't
#                                     already on it (see below), so callers don't need the `export`
#                                     from docs/agents/unicron-build-test.md first - that doc is for
#                                     a human's own shell when proving a change directly, not this
#                                     entry point.
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
# A fixed length (not plain `rev-parse --short`, which auto-grows as the repo's object count
# grows) so the same commit always maps to the same tag - a length that changed later would make
# the idempotency check below miss an already-published commit and create a duplicate release.
SHORT_SHA="$(git -C "$REPO_ROOT" rev-parse --short=10 "$FULL_SHA")"

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
	REPO="$(printf '%s' "$REMOTE_URL" | sed -E 's#^(https?://|git\+ssh://|ssh://)?(git@)?github\.com[:/]##; s#\.git$##')"
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
LOCK_DIR="${STATE_DIR}/locks"
mkdir -p "$LOG_DIR" "$WORKTREE_ROOT" "$LOCK_DIR"

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

# --- per-tag lock: two runs of the *same* commit (e.g. a caller and #68's poller racing, or two
# by-hand invocations) must never touch the same scratch worktree at once - a second run treating
# the first run's live worktree as "stale" and force-removing it out from under an in-progress
# build would corrupt or kill that first run. Different commits get different tags and never
# contend. Held for the whole run (idempotency check through cleanup), released automatically on
# exit since the lock lives on this shell's own fd 9 - the suite command explicitly closes its own
# copy of fd 9 (see below) so a wine/Xvfb process it starts can never hold it past this run. ---
LOCK_FILE="${LOCK_DIR}/${TAG}.lock"
exec 9>"$LOCK_FILE"
if ! flock -n 9; then
	log "==> waiting for another run already processing ${TAG}..."
	if ! flock 9; then
		log "OUTCOME: pipeline error - couldn't acquire the per-tag lock at ${LOCK_FILE} (is 'flock' on PATH?)"
		exit 2
	fi
fi

# --- idempotency (AC: re-processing the same commit doesn't create a duplicate release): check
# before doing any build work, so a repeat run of an already-published commit is cheap. Inside the
# lock above, so this and the eventual publish can't race with another run of the same commit. ---
if gh release view "$TAG" --repo "$REPO" >>"$LOG_FILE" 2>&1; then
	log "OUTCOME: already published - ${TAG} already exists on ${REPO}, nothing to do"
	exit 0
fi

# --- clean worktree: never the caller's own working copy. A stale worktree from a crashed prior
# run of this exact commit is removed first, so this run starts from a genuinely clean checkout -
# safe to do unconditionally here since the lock above rules out a live concurrent run owning it. ---
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
SUITE_LOG_LINES_BEFORE="$(wc -l <"$LOG_FILE")"
# `unset CHEXTREK_SKIP_BUILD` inside this subshell only (never touches the outer shell or a
# caller's own env): an inherited CHEXTREK_SKIP_BUILD=1 (the docs/dev-setup.md-documented way to
# run the suite against a prebuilt DLL) would make the suite skip building in this brand-new
# scratch worktree, where no prebuilt DLL exists - a false red, not the "builds fresh from this
# exact commit" guarantee this pipeline exists to make.
#
# `9>&-` closes this subshell's own copy of the per-tag lock fd before the suite runs: the suite
# itself starts wine/Xvfb (tools/lib-harness.sh, #62), which can daemonize past this pipeline run -
# lib-harness.sh closes its own lock fd for exactly this reason (see _chextrek_acquire_lock there).
# Without this, an orphaned wineserver/Xvfb from a killed or timed-out run could keep holding this
# tag's lock forever, hanging every future run of the same commit at the blocking `flock 9` above.
(cd "$WT_DIR" && unset CHEXTREK_SKIP_BUILD && eval "$SUITE_CMD" 9>&-) >>"$LOG_FILE" 2>&1
SUITE_EXIT=$?
# The suite's own output only (not this script's later log lines) - the source for the notes
# summary below, so a `=== summary:` line from some *other* nested self-test earlier in the run
# can't be mistaken for the real one.
SUITE_TAIL="$(tail -n "+$((SUITE_LOG_LINES_BEFORE + 1))" "$LOG_FILE")"
log "==> suite exited ${SUITE_EXIT}"

if [ "$SUITE_EXIT" = "3" ]; then
	log "OUTCOME: environment blocker - see the ENVIRONMENT line above; nothing published"
	exit 3
fi
if [ "$SUITE_EXIT" = "1" ]; then
	log "OUTCOME: red - the suite failed; nothing published"
	exit 1
fi
if [ "$SUITE_EXIT" != "0" ]; then
	# Anything other than 0/1/3 (e.g. killed by a signal, or a stray future exit code) isn't a
	# reliable test result either way - never call it "red" (that's what #67 turns into a failure
	# issue for a real game bug) and never publish it as green.
	log "OUTCOME: pipeline error - suite exited ${SUITE_EXIT} (not 0/1/3) - not a reliable test result; nothing published"
	exit 2
fi

# --- green: publish ---
DLL="${WT_DIR}/chextrek.dll"
PDB="${WT_DIR}/chextrek.pdb"
if [ ! -f "$DLL" ] || [ ! -f "$PDB" ]; then
	log "OUTCOME: pipeline error - suite passed but ${DLL} and/or ${PDB} are missing"
	exit 2
fi

# The *last* "=== summary:" line in the suite's own output to end-of-output: tools/run-all-tests.sh
# prints exactly one, as its final block, but a nested self-test (this suite includes
# tools/test-pipeline-process-commit.sh itself) can print its own earlier - `tac`/`tac` takes the
# last match instead of the first so that one is never mistaken for run-all-tests.sh's real one.
SUMMARY="$(printf '%s\n' "$SUITE_TAIL" | tac | sed -n '0,/^=== summary:/p' | tac)"
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

# `gh release create` failed. The per-tag lock above already rules out a race with another run of
# *this* script publishing the same commit first - this is defense in depth for anything else that
# could have created the tag in between (a manual `gh release create`, GitHub-side state this
# script doesn't know about). Re-check before calling it a pipeline error.
if gh release view "$TAG" --repo "$REPO" >>"$LOG_FILE" 2>&1; then
	log "OUTCOME: already published - lost a race with another run of the same commit; nothing to do"
	exit 0
fi

log "OUTCOME: pipeline error - gh release create failed and ${TAG} still doesn't exist on ${REPO}"
exit 2
