#!/usr/bin/env bash
# Pipeline entry point (spec #58/#66/#67): "process commit X". Checks X out into its own clean
# worktree - never the owner's or an agent's working copy - builds chextrek.dll and runs the full
# suite (tools/run-all-tests.sh) against that worktree. On green, publishes X as a GitHub Release
# tagged win-<sha>, targeting X, with chextrek.dll and chextrek.pdb as assets, marked Latest (not
# prerelease), notes containing the suite summary, and closes the single open pipeline:red issue
# (if any) with a comment linking that release. Idempotent: re-processing an already-published
# commit publishes nothing new, but still closes a still-open red issue.
#
# On red (an ordinary FAIL) or an environment blocker (exit 3), opens the single pipeline:red
# issue (fixed title, label pipeline:red - creating the label first if it doesn't exist yet) if
# none is open, or comments on the existing one otherwise - never a second issue. The comment/body
# names the commit, the failing scenarios (red) or the ENVIRONMENT line (blocker - worded distinct
# from a test failure), and this run's own archive log path.
#
# Invoked by hand for now (#66/#67) - the poller trigger is #68. This script's exit codes are the
# seam #67's red-issue handling hangs off of: 1 (red), 3 (environment blocker) and 2 (pipeline
# error - not a game result either way) are always kept distinct, the same 0/1/3 contract
# tools/run-all-tests.sh already makes, plus 2 for this script's own failure modes. Only 0 (green)
# and 1/3 (red/blocker) ever touch the red issue - 2 never does, since it isn't a game result
# either way and filing it as "red" would be a false report of a game bug. A per-commit lock (see
# below) makes two runs of the same commit safe to overlap - #68's poller and a by-hand run, or two
# by-hand runs, can never corrupt each other's scratch worktree.
#
# Usage: tools/pipeline-process-commit.sh <commit-ish>
#
# Exit status:
#   0 - the commit is published: either a new release was created just now, or one already existed
#       for this commit (idempotent no-op - AC "re-processing doesn't create a duplicate release").
#       Either way, a still-open pipeline:red issue is closed with a comment linking the release.
#   1 - the suite ran and reported an ordinary FAIL (exit 1) - nothing published; the pipeline:red
#       issue is opened or commented on with the failing scenarios.
#   2 - a pipeline-level error: bad commit-ish, missing built assets, a worktree/gh failure, or the
#       suite exited with anything other than 0/1/3 (e.g. killed by a signal) - never treated as a
#       red test result, since it isn't one. Not a game result; the red issue is left untouched.
#   3 - an environment blocker, propagated verbatim from tools/run-all-tests.sh's own exit 3 (e.g.
#       Wine not on PATH, missing Doom 3 data) - not a test result; the pipeline:red issue is opened
#       or commented on, worded as an environment blocker, never as a test failure.
#
# Logs: one file per run under CHEXTREK_PIPELINE_STATE_DIR's logs/ subdirectory (see below) -
# outside every repo and worktree, so they survive worktree cleanup and are readable without a
# checkout. Every run's outcome (published/red/environment/error) is on its own "OUTCOME: ..."
# line, followed only by this run's own red-issue-tracking lines (open/comment/close), if any. The
# red issue's body/comment cites this same log path as the run's archive location.
#
# Injectable for testing (tools/test-pipeline-process-commit.sh stubs every one of these - a test
# must never point any of them at the real wScottSh/chex-trek repo or a real `gh`):
#   - gh                            - put a fake `gh` earlier on PATH (repo convention - see
#                                     tools/test-run-all-tests-*.sh). This script only ever calls
#                                     `gh release view` / `gh release create` / `gh label create` /
#                                     `gh issue list` / `gh issue create` / `gh issue comment` /
#                                     `gh issue close`, always with an explicit --repo, so a test's
#                                     fake repo name is enough to keep a broken stub from ever
#                                     reaching a real repo even if PATH leaks.
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
#   - CHEXTREK_PIPELINE_RED_LABEL   - label on the single red-tracking issue (default:
#                                     "pipeline:red"). Created via `gh label create ... --force` the
#                                     first time it's needed - safe to re-run even if it already
#                                     exists.
#   - CHEXTREK_PIPELINE_RED_TITLE   - fixed title of that issue (default: "Pipeline: chex-trek build
#                                     is red"). Only one open issue with CHEXTREK_PIPELINE_RED_LABEL
#                                     is ever assumed live at a time - see find_red_issue below.
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

# --- red-issue tracking (#67): a single open issue, fixed title/label, that a red or
# environment-blocked run opens or comments on, and a later green run closes. ---
RED_LABEL="${CHEXTREK_PIPELINE_RED_LABEL:-pipeline:red}"
RED_TITLE="${CHEXTREK_PIPELINE_RED_TITLE:-Pipeline: chex-trek build is red}"

# find_red_issue - prints the number of the single open issue carrying RED_LABEL, prints nothing
# if none is open, or prints _LIST_FAILED and logs a WARNING if `gh issue list` itself failed (an
# auth/network/rate-limit error looks like "no output" otherwise, which callers must never treat
# the same as "confirmed no issue open" - doing so risks opening a duplicate issue on a red run, or
# silently skipping a close on a green run). Only label + state are checked (not the title): this
# pipeline is the only thing that ever applies RED_LABEL, so at most one open issue can ever carry
# it in normal operation.
find_red_issue() {
	local OUT
	OUT="$(gh issue list --repo "$REPO" --label "$RED_LABEL" --state open --json number --jq '.[0].number // empty' 2>>"$LOG_FILE")"
	if [ $? -ne 0 ]; then
		# Written straight to LOG_FILE, never via log() (which also writes to stdout): every caller
		# of find_red_issue reads its stdout via command substitution as the return value, so any
		# extra stdout output here would silently corrupt that value (e.g. turn a clean
		# "_LIST_FAILED" into a multi-line string that then fails every caller's `[ "$NUM" =
		# "_LIST_FAILED" ]` check and gets passed straight to `gh issue comment`/`close` as a bogus
		# issue number instead).
		printf '%s\n' "==> WARNING: 'gh issue list --label ${RED_LABEL}' failed - can't tell whether one is already open (see the log above for gh's own error)" >>"$LOG_FILE"
		printf '_LIST_FAILED'
		return
	fi
	printf '%s' "$OUT"
}

# open_or_update_red_issue BODY - comments on the existing open red issue if there is one,
# otherwise creates RED_LABEL (idempotent - `--force` is a no-op if it already exists) and opens a
# new issue with the fixed title. Never opens a second issue while one is already open. If
# find_red_issue couldn't tell (see above), does nothing rather than risk a duplicate.
open_or_update_red_issue() {
	local BODY="$1" NUM
	NUM="$(find_red_issue)"
	if [ "$NUM" = "_LIST_FAILED" ]; then
		log "==> not opening/commenting on a ${RED_LABEL} issue this run - couldn't confirm whether one is already open (see the WARNING above)"
		return
	fi
	if [ -n "$NUM" ]; then
		log "==> commenting on the existing open ${RED_LABEL} issue #${NUM}"
		if ! gh issue comment "$NUM" --repo "$REPO" --body "$BODY" >>"$LOG_FILE" 2>&1; then
			log "==> WARNING: 'gh issue comment' on #${NUM} failed - see the log above"
		fi
		return
	fi
	log "==> no open ${RED_LABEL} issue - ensuring the label exists"
	if ! gh label create "$RED_LABEL" --repo "$REPO" --color b60205 \
		--description "tools/pipeline-process-commit.sh: the build/test pipeline is currently red or environment-blocked" \
		--force >>"$LOG_FILE" 2>&1; then
		log "==> WARNING: 'gh label create ${RED_LABEL}' failed - see the log above; still attempting the issue create"
	fi
	log "==> opening a new ${RED_LABEL} issue: ${RED_TITLE}"
	if ! gh issue create --repo "$REPO" --title "$RED_TITLE" --label "$RED_LABEL" --body "$BODY" >>"$LOG_FILE" 2>&1; then
		log "==> WARNING: 'gh issue create' failed - see the log above"
	fi
}

# close_red_issue RELEASE_URL - closes the open red issue (if any) with a comment naming this
# green commit and linking RELEASE_URL. A no-op (not an error) when no red issue is open, which is
# the common case - most green runs never touch the issue tracker at all. If find_red_issue
# couldn't tell (see above), does nothing rather than guess - a still-open issue, if any, is closed
# on a later green run instead.
close_red_issue() {
	local RELEASE_URL="${1:-}" NUM BODY
	NUM="$(find_red_issue)"
	if [ "$NUM" = "_LIST_FAILED" ]; then
		log "==> couldn't check for an open ${RED_LABEL} issue to close (see the WARNING above)"
		return 0
	fi
	if [ -z "$NUM" ]; then
		return 0
	fi
	BODY="$(printf 'Commit %s (%s) is green.\n\nRelease: %s\n' "$FULL_SHA" "$TAG" "${RELEASE_URL:-(release URL unavailable)}")"
	log "==> closing ${RED_LABEL} issue #${NUM} - commit ${FULL_SHA} is green"
	if ! gh issue close "$NUM" --repo "$REPO" --comment "$BODY" >>"$LOG_FILE" 2>&1; then
		log "==> WARNING: 'gh issue close' on #${NUM} failed - see the log above"
	fi
}

# release_url_or_empty TAG - TAG's release URL (`gh release view --json url --jq .url`), or empty
# if that lookup itself fails. Shared by both places that close the red issue against a release
# this run didn't just create with `gh release create` (the idempotent fast path below, and the
# "lost the race but the release exists" recheck near the bottom).
release_url_or_empty() {
	gh release view "$1" --repo "$REPO" --json url --jq .url 2>>"$LOG_FILE"
}

# suite_summary_block - the *last* "=== summary: ..." block in SUITE_TAIL to end-of-output (i.e.
# tools/run-all-tests.sh's own final block - see its own header). A nested self-test (this suite
# includes tools/test-pipeline-process-commit.sh itself) can print its own summary/FAIL: lines
# earlier in the output; `tac`/`tac` takes the *last* match so those are never mistaken for the
# real, final summary. Shared by the red-issue body's failing-scenario list and the green release
# notes, so both cite the same, single block instead of the whole (possibly huge, possibly noisy)
# suite output.
suite_summary_block() {
	printf '%s\n' "$SUITE_TAIL" | tac | sed -n '0,/^=== summary:/p' | tac
}

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
	# Deliberately does NOT touch the red issue here: this fast path can be hit by re-processing
	# ANY already-published commit, including an old one from well before the current HEAD - e.g.
	# a caller re-checks a commit that went green a while ago, while a *later* commit has since
	# gone red and left the issue open. Closing the issue on this old commit's idempotent re-check
	# would falsely report "green" while the real, current HEAD is still broken. Only a run whose
	# own suite just genuinely passed (the fresh-publish and lost-the-race paths below) closes it.
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
fi
# Unconditional, even when $WT_DIR itself is already gone (e.g. someone `rm -rf`'d it by hand
# without telling git): git still has that path registered from an earlier run, and refuses to
# `worktree add` onto a path it already tracks. Without this, every future run of this exact
# commit would exit 2 until someone happened to prune by hand.
git -C "$REPO_ROOT" worktree prune >>"$LOG_FILE" 2>&1 || true

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
	ENV_LINES="$(printf '%s\n' "$SUITE_TAIL" | grep '^ENVIRONMENT:' || true)"
	RED_BODY="$(printf 'Commit %s (%s) hit an **environment blocker** while processing - not a test failure.\n\n%s\n\nRun archive: %s\n' \
		"$FULL_SHA" "$TAG" "${ENV_LINES:-(no ENVIRONMENT line captured - see the full run archive)}" "$LOG_FILE")"
	open_or_update_red_issue "$RED_BODY"
	exit 3
fi
if [ "$SUITE_EXIT" = "1" ]; then
	log "OUTCOME: red - the suite failed; nothing published"
	# Only the *final* summary block's own FAIL: lines (see suite_summary_block above) - not every
	# FAIL:-prefixed line anywhere in the suite's output, which would also pick up individual
	# scenario scripts' own per-assertion FAIL: lines and (since this suite includes
	# tools/test-pipeline-process-commit.sh itself) a nested self-test's FAIL: lines too, bloating
	# and duplicating the issue body for no reason.
	FAIL_LINES="$(suite_summary_block | grep '^FAIL: ' || true)"
	RED_BODY="$(printf 'Commit %s (%s) is red.\n\nFailing scenarios:\n%s\n\nRun archive: %s\n' \
		"$FULL_SHA" "$TAG" "${FAIL_LINES:-(no FAIL: lines captured - see the full run archive)}" "$LOG_FILE")"
	open_or_update_red_issue "$RED_BODY"
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

SUMMARY="$(suite_summary_block)"
NOTES="$(printf 'Pipeline build of %s (%s).\n\n%s\n' "$FULL_SHA" "$TAG" "$SUMMARY")"

log "==> publishing ${TAG} (target ${FULL_SHA}) with chextrek.dll + chextrek.pdb, marked Latest"
# stdout and stderr captured separately (rather than `>>"$LOG_FILE" 2>&1` like every other `gh`
# call here): on success, `gh release create`'s *stdout* is exactly one line, the release's own
# URL - the link the red issue's closing comment cites (AC "closes with a comment linking its
# release"). Mixing stderr in (e.g. via a combined 2>&1 capture) risks a trailing warning line
# being mistaken for that URL; here, only CREATE_STDOUT ever feeds close_red_issue.
CREATE_STDERR_FILE="$(mktemp)"
CREATE_STDOUT="$(gh release create "$TAG" \
	--repo "$REPO" \
	--target "$FULL_SHA" \
	--title "$TAG" \
	--notes "$NOTES" \
	--latest \
	"$DLL" "$PDB" 2>"$CREATE_STDERR_FILE")"
CREATE_STATUS=$?
cat "$CREATE_STDERR_FILE" >>"$LOG_FILE"
rm -f "$CREATE_STDERR_FILE"
printf '%s\n' "$CREATE_STDOUT" >>"$LOG_FILE"
if [ "$CREATE_STATUS" = "0" ]; then
	log "OUTCOME: published - ${TAG} created on ${REPO}, marked Latest"
	close_red_issue "$(printf '%s\n' "$CREATE_STDOUT" | tail -1)"
	exit 0
fi

# `gh release create` failed. The per-tag lock above already rules out a race with another run of
# *this* script publishing the same commit first - this is defense in depth for anything else that
# could have created the tag in between (a manual `gh release create`, GitHub-side state this
# script doesn't know about). Re-check before calling it a pipeline error.
if gh release view "$TAG" --repo "$REPO" >>"$LOG_FILE" 2>&1; then
	log "OUTCOME: already published - lost a race with another run of the same commit; nothing to do"
	close_red_issue "$(release_url_or_empty "$TAG")"
	exit 0
fi

log "OUTCOME: pipeline error - gh release create failed and ${TAG} still doesn't exist on ${REPO}"
exit 2
