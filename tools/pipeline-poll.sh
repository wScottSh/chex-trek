#!/usr/bin/env bash
# AFK trigger (spec #58/#68): one poll tick. Fetches origin/<branch> (default "master") and, if its
# tip is newer than the last commit this poller handed to tools/pipeline-process-commit.sh,
# processes that tip - and only the tip. Commits that landed on master in between are skipped, not
# queued: they're named in the log, and tools/pipeline-backfill.sh builds any of them on demand
# (e.g. to bisect with tools/fetch-and-play.sh <commit>). Meant to be invoked by a systemd user
# timer (tools/systemd/) - see docs/dev-setup.md's "AFK trigger" section for
# install/enable/disable/status/logs - but has no systemd dependency itself: it's a plain script a
# human (or cron, or anything else) can run by hand, which is also what makes it self-testable
# without systemd (tools/test-pipeline-poll.sh).
#
# Usage: bash tools/pipeline-poll.sh
#
# Why only the tip: the release worth playing is the newest green one, and every processed commit
# is a full build + suite run (a few minutes on Unicron - docs/dev-setup.md's "Running the tests"),
# so walking a backlog of several merges one by one delayed the newest commit's result for no
# benefit to that result. Processing only the tip keeps #67's red/green issue tracking correct: it
# still only ever sees commits in master's own order (each tick's tip is newer than the last), so a
# green run can never close an issue a later, still-red commit opened. What's given up: a skipped
# commit gets no release and no red/green verdict of its own. That's what
# tools/pipeline-backfill.sh is for - it publishes older commits without marking them Latest and
# without touching the red issue, so building an old commit can never disturb either.
#
# State: a single file, STATE_DIR/poller-last-processed (see CHEXTREK_PIPELINE_STATE_DIR below),
# holding the full SHA of the newest commit this poller has already handed to
# pipeline-process-commit.sh.
#
# First run ever (no state file yet): bootstraps to the current origin/<branch> tip *without*
# processing anything - establishing "now" as the baseline and only reacting to commits pushed
# *after* that, matching spec #58/#68's hard rule against any real, unintended release.
#
# History divergence (a force-push to the polled branch, rewriting history past the last-processed
# commit): detected via `git merge-base --is-ancestor` before anything is processed. This resets the
# baseline to the new tip (same as the bootstrap case) without processing anything, logs a WARNING,
# and exits 2 so the condition is visible (systemd/journalctl) rather than silently swallowed - a
# force-push to master isn't expected in normal operation and is left for a human to look at.
#
# Exit status:
#   0 - poll tick completed with no poll-level error. This covers "nothing new", "bootstrapped",
#       and "processed the tip" alike, *including* when the tip came back red or
#       environment-blocked - that's an expected, already-reported (via #67's issue tracker)
#       outcome of processing a commit, not a poll-level failure.
#   2 - a poll-level error: couldn't fetch, couldn't resolve the polled ref, history diverged (see
#       above), the poll lock couldn't be taken for any reason other than "already held" (e.g.
#       flock missing from PATH - never mistaken for another tick running), the state file couldn't
#       be read/written, or pipeline-process-commit.sh itself exited something other than 0/1/3 for
#       the tip (its own "not a reliable result" exit 2, or a signal). In that last case the state
#       file is left pointing at the last commit that *did* fully process, so the next poll tick
#       retries - whatever the tip is by then.
#
# No-overlap: this script is meant to run as a systemd oneshot service, which already refuses to
# start a second instance of the same unit while one is still active - the primary guarantee (see
# docs/dev-setup.md). This script *also* takes its own non-blocking flock (STATE_DIR/locks/
# poll.lock) as defense in depth against anything invoking it outside systemd (a human running it
# by hand while the timer also fires, two differently-named units pointed at the same state dir by
# mistake, etc.): a poll tick that finds the lock already held logs that and exits 0 at once - not
# an error, just "another poll is already in flight, the next tick will pick up anything newer".
# Unlike pipeline-process-commit.sh's own per-tag lock (which waits), this one never blocks - a
# poll tick is meant to be quick to dispatch, not queue up.
#
# Injectable for testing (tools/test-pipeline-poll.sh stubs every one of these):
#   - CHEXTREK_PIPELINE_POLL_BRANCH  - the branch on `origin` to poll (default: "master").
#   - CHEXTREK_PIPELINE_STATE_DIR    - same meaning/default as pipeline-process-commit.sh: state
#                                      root, outside every repo/worktree.
#   - CHEXTREK_PIPELINE_PROCESS_CMD  - the command run for the tip, `eval`'d with the commit's full
#                                      SHA appended as its final argument (default:
#                                      "bash \"${SCRIPT_DIR}/pipeline-process-commit.sh\"").
#                                      Overriding this to a stub is how
#                                      tools/test-pipeline-poll.sh tests the poll/state logic itself
#                                      without a real suite, gh, or built assets -
#                                      pipeline-process-commit.sh's own behavior is covered by
#                                      tools/test-pipeline-process-commit.sh instead.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=tools/lib-harness.sh
source "${SCRIPT_DIR}/lib-harness.sh"

BRANCH="${CHEXTREK_PIPELINE_POLL_BRANCH:-master}"

STATE_DIR="$(chextrek_pipeline_state_dir)"
LOCK_DIR="${STATE_DIR}/locks"
mkdir -p "$STATE_DIR" "$LOCK_DIR" || {
	echo "error: couldn't create state dir ${STATE_DIR}" >&2
	exit 2
}
STATE_FILE="${STATE_DIR}/poller-last-processed"

log() {
	printf '%s\n' "$*"
}

log "=== pipeline-poll: $(date -u +%Y-%m-%dT%H:%M:%SZ) - polling origin/${BRANCH} ==="

# --- no-overlap (defense in depth - see header): a non-blocking flock, separate from
# pipeline-process-commit.sh's own per-tag lock, held for this whole poll tick including the
# process-commit.sh call it makes below (so two poll ticks can never both decide "nothing new yet,
# I'll process it" for the same commit) ---
POLL_LOCK_FILE="${LOCK_DIR}/poll.lock"
exec 8>"$POLL_LOCK_FILE"
# Only flock's own "already held" exit (1) means another tick is running. Anything else - 127 (flock
# not on PATH) or a flock that can't lock this shell's fd at all (e.g. MSYS2's flock.exe under Git
# Bash exits 65) - is a poll-level error: treating it as "held" would silently skip every tick.
flock -n 8
FLOCK_RC=$?
if [ $FLOCK_RC -eq 1 ]; then
	log "==> another poll tick is already running (lock: ${POLL_LOCK_FILE}) - skipping this tick, anything newer will be picked up next time"
	exit 0
elif [ $FLOCK_RC -ne 0 ]; then
	log "==> error: couldn't take the poll lock at ${POLL_LOCK_FILE} - flock exited ${FLOCK_RC} (127: flock not on PATH - see docs/dev-setup.md)"
	exit 2
fi

# --- fetch: updates the local origin/<branch> remote-tracking ref only - never touches this
# checkout's own HEAD or working tree, so this script is safe to run from the same checkout its
# own tools/ scripts live in ---
if ! git -C "$REPO_ROOT" fetch --quiet origin "$BRANCH" 2>&1; then
	log "==> error: 'git fetch origin ${BRANCH}' failed"
	exit 2
fi

TIP="$(git -C "$REPO_ROOT" rev-parse "origin/${BRANCH}" 2>/dev/null)"
if [ -z "$TIP" ]; then
	log "==> error: couldn't resolve origin/${BRANCH} after fetching"
	exit 2
fi

# write_state SHA - atomically writes SHA as the new "last processed" marker. Exits 2 at once on
# any failure (the header's own promised exit 2 for "the state file couldn't be ... written") -
# never silently continues past a marker that didn't actually get written.
write_state() {
	if ! printf '%s\n' "$1" >"${STATE_FILE}.tmp" || ! mv "${STATE_FILE}.tmp" "$STATE_FILE"; then
		log "==> error: couldn't write the state file ${STATE_FILE}"
		exit 2
	fi
}

# --- bootstrap: first poll tick ever (no state file) sets the baseline to the current tip without
# processing anything - see header for why ---
if [ ! -f "$STATE_FILE" ]; then
	log "==> no state file at ${STATE_FILE} yet - bootstrapping baseline to ${TIP} (origin/${BRANCH}) without processing any history"
	write_state "$TIP"
	log "==> bootstrap complete"
	exit 0
fi

LAST="$(tr -d ' \t\r\n' <"$STATE_FILE")"
if [ -z "$LAST" ]; then
	log "==> error: state file ${STATE_FILE} exists but is empty/unreadable"
	exit 2
fi

if [ "$LAST" = "$TIP" ]; then
	log "==> up to date: origin/${BRANCH} is still at ${TIP} (last processed)"
	exit 0
fi

# --- divergence check: LAST must still be an ancestor of TIP, or origin/<branch> was rewritten
# (force-push) past a commit this poller already handed off - see header. `--is-ancestor`'s exit
# status is 3-way, not boolean: 0 = is an ancestor, 1 = confirmed *not* an ancestor (the real
# divergence case), anything else (128 for an unresolvable/bad object - e.g. a corrupted or
# manually-edited state file - or a signal) = git itself couldn't answer the question at all - that's
# a poll-level error, not a divergence finding, and must never be treated as one. ---
git -C "$REPO_ROOT" merge-base --is-ancestor "$LAST" "$TIP" 2>/dev/null
ANCESTOR_STATUS=$?
if [ "$ANCESTOR_STATUS" = "1" ]; then
	log "==> WARNING: origin/${BRANCH} has diverged from the last-processed commit ${LAST} (force-push?) - resetting baseline to ${TIP} without processing anything; investigate manually"
	write_state "$TIP"
	exit 2
elif [ "$ANCESTOR_STATUS" != "0" ]; then
	log "==> error: 'git merge-base --is-ancestor' couldn't determine whether ${LAST} is an ancestor of ${TIP} (exit ${ANCESTOR_STATUS}) - not treating this as a force-push; leaving the baseline untouched"
	exit 2
fi

# --- only the tip (see header). Older commits since LAST are named in the log so a human can build
# any of them later with tools/pipeline-backfill.sh. --first-parent: master's own merge commits (every
# PR here lands via one), not the individual feature-branch commits each merge brought in. LAST is a
# confirmed ancestor of TIP and LAST != TIP above, so TIP always has a parent here. ---
SKIPPED_RAW="$(git -C "$REPO_ROOT" rev-list --first-parent --reverse "${LAST}..${TIP}~1" 2>/dev/null)"
if [ -n "$SKIPPED_RAW" ]; then
	mapfile -t SKIPPED <<<"$SKIPPED_RAW"
	log "==> skipping ${#SKIPPED[@]} older commit(s) since ${LAST}, processing only the tip - build any of them with tools/pipeline-backfill.sh: ${SKIPPED[*]}"
fi

PROCESS_CMD="${CHEXTREK_PIPELINE_PROCESS_CMD:-bash \"${SCRIPT_DIR}/pipeline-process-commit.sh\"}"

POLL_EXIT=0
log "==> processing ${TIP}"
# `eval` runs the reconstructed command line ("$PROCESS_CMD" + a literal `"$TIP"` that only expands
# once eval re-parses it + `8>&-`) directly in *this* shell, with `8>&-` as a redirection scoped to
# that one command - it closes fd 8 for the process command (and anything it execs) without
# touching this shell's own copy, which stays locked for the rest of this tick. Same reasoning as
# pipeline-process-commit.sh's own `9>&-` around its suite invocation: a process the command starts
# that outlives the command itself (wine/Xvfb daemonizing past a killed run, etc.) must never be
# able to hold this poll lock open forever.
eval "$PROCESS_CMD" '"$TIP"' 8>&-
CODE=$?
log "==> ${TIP} exited ${CODE}"
case "$CODE" in
0 | 1 | 3)
	# A real, reported result either way (published / red / environment-blocked - #67's issue
	# tracker already handled it inside process-commit.sh itself) - advance the baseline to the tip.
	# This deliberately includes exit 3 (environment blocker): the thing that's broken is the
	# *environment*, not this commit, and it's already been reported in the pipeline:red issue. Not
	# advancing would retry the same commit every tick until someone fixes the environment -
	# commenting on the issue each time. The cost: the poller never retests a blocked commit on its
	# own. Once the environment is fixed, the next commit pushed to master is processed normally; to
	# get a result for the blocked commit itself (e.g. it is still the tip), run
	# `bash tools/pipeline-process-commit.sh <sha>` by hand (docs/dev-setup.md's "AFK trigger").
	write_state "$TIP"
	;;
*)
	# 2 (pipeline-level error) or anything else unexpected: not a reliable result for this commit
	# either way - don't advance the baseline, so the next poll tick retries (whatever the tip is by
	# then - this same commit, unless something newer has landed since).
	log "==> ${TIP} didn't produce a reliable result (exit ${CODE}) - the state file still points at ${LAST}; the next tick retries the tip"
	POLL_EXIT=2
	;;
esac

log "=== pipeline-poll: done (exit ${POLL_EXIT}) ==="
exit "$POLL_EXIT"
