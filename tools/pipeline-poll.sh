#!/usr/bin/env bash
# AFK trigger (spec #58/#68): one poll tick. Fetches origin/<branch> (default "master"), finds
# every commit newer than the last one this poller has already handed to
# tools/pipeline-process-commit.sh via `git rev-list --first-parent` (master's own linear
# merge-commit history - see "the actual backlog" below for why not a plain `rev-list`, which
# would also walk every individual commit on each merged-in feature branch), and processes each of
# them, oldest first, one at a time, in a single call to this script. Meant to be invoked by a
# systemd user timer (tools/systemd/) - see docs/dev-setup.md's "AFK trigger" section for
# install/enable/disable/status/logs - but has no systemd dependency itself: it's a plain script a
# human (or cron, or anything else) can run by hand, which is also what makes it self-testable
# without systemd (tools/test-pipeline-poll.sh).
#
# Usage: bash tools/pipeline-poll.sh
#
# Why "each new commit, oldest first, one full run before the next is picked up" rather than
# "skip straight to the newest": #67's red/green issue tracking is explicitly documented as only
# safe for in-order, one-commit-at-a-time processing - re-processing an old commit can't be told
# apart from the real current state, and a stale green publish for an old commit could wrongly
# close an issue a genuinely later, still-red commit opened (see docs/dev-setup.md's "Red/green
# issue tracking" section, and #67's own closing comment: "This all assumes commits are processed
# in order, one at a time ... and for #68's poller (one commit fully processed before the next is
# picked up)"). Skipping ahead to the newest commit when several land between polls would violate
# that assumption the moment any of the skipped commits was red: the red issue #67 would have
# opened for it just never gets opened, and a later green run would silently look like the first
# and only outcome. Processing every commit in order costs more wall-clock time when a backlog
# piles up (each commit is a full build + suite run - a few minutes on Unicron, see
# docs/dev-setup.md's "Running the tests"), which delays the newest commit's own release/issue
# update until every older one in the backlog has been processed - an accepted, documented
# trade-off in favor of never producing a wrong answer.
#
# State: a single file, STATE_DIR/poller-last-processed (see CHEXTREK_PIPELINE_STATE_DIR below),
# holding the full SHA of the newest commit this poller has already handed to
# pipeline-process-commit.sh. Updated after each commit's own process-commit.sh call returns (not
# once at the end) so a poll tick that's interrupted partway through a backlog (killed, machine
# power loss) resumes from exactly where it left off next time - never re-processing a commit
# already handed off, never skipping one that wasn't.
#
# First run ever (no state file yet): bootstraps to the current origin/<branch> tip *without*
# processing anything - it would otherwise try to process this repo's entire history the first
# time the timer ever fires, publishing a release for every past commit. Establishing "now" as the
# baseline and only reacting to commits pushed *after* that matches the AFK trigger's own framing
# ("each new origin/master commit") and spec #58/#68's hard rule against any real, unintended
# release.
#
# History divergence (a force-push to the polled branch, rewriting history past the last-processed
# commit): detected via `git merge-base --is-ancestor` before computing the new-commit list. Rather
# than guess which of the now-orphaned commits still matter, this resets the baseline to the new
# tip (same as the bootstrap case) without processing anything, logs a WARNING, and exits 2 so the
# condition is visible (systemd/journalctl) rather than silently swallowed - a force-push to
# master isn't expected in normal operation and is left for a human to look at.
#
# Exit status:
#   0 - poll tick completed with no poll-level error. This covers "nothing new", "bootstrapped",
#       and "processed N commits" alike, *including* when one or more of those commits came back
#       red or environment-blocked - that's an expected, already-reported (via #67's issue tracker)
#       outcome of processing a commit, not a poll-level failure.
#   2 - a poll-level error: couldn't fetch, couldn't resolve the polled ref, history diverged (see
#       above), the state file couldn't be read/written, or pipeline-process-commit.sh itself
#       exited something other than 0/1/3 for one of the commits (its own "not a reliable result"
#       exit 2, or a signal). Processing stops at the first such commit - the state file is left
#       pointing at the last commit that *did* fully process, so the next poll tick retries the
#       failing commit rather than skipping past it. This is also why a poll tick can leave a
#       backlog only partially processed even on "success": if commit N fails with a poll-level
#       error, commits after N are deliberately left unprocessed until N is resolved, to preserve
#       the in-order guarantee above.
#
# No-overlap: this script is meant to run as a systemd oneshot service, which already refuses to
# start a second instance of the same unit while one is still active - the primary guarantee (see
# docs/dev-setup.md). This script *also* takes its own non-blocking flock (STATE_DIR/locks/
# poll.lock) as defense in depth against anything invoking it outside systemd (a human running it
# by hand while the timer also fires, two differently-named units pointed at the same state dir by
# mistake, etc.): a poll tick that finds the lock already held logs that and exits 0 at once - not
# an error, just "another poll is already in flight, the next tick will pick up any backlog this
# one didn't get to". Unlike pipeline-process-commit.sh's own per-tag lock (which waits), this one
# never blocks - a poll tick is meant to be quick to dispatch, not queue up.
#
# Injectable for testing (tools/test-pipeline-poll.sh stubs every one of these):
#   - CHEXTREK_PIPELINE_POLL_BRANCH  - the branch on `origin` to poll (default: "master").
#   - CHEXTREK_PIPELINE_STATE_DIR    - same meaning/default as pipeline-process-commit.sh: state
#                                      root, outside every repo/worktree.
#   - CHEXTREK_PIPELINE_PROCESS_CMD  - the command run once per new commit, `eval`'d with the
#                                      commit's full SHA appended as its final argument (default:
#                                      "bash \"${SCRIPT_DIR}/pipeline-process-commit.sh\"").
#                                      Overriding this to a stub is how
#                                      tools/test-pipeline-poll.sh tests the poll/state/ordering
#                                      logic itself without a real suite, gh, or built assets -
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
# pipeline-process-commit.sh's own per-tag lock, held for this whole poll tick including every
# process-commit.sh call it makes below (so two poll ticks can never both decide "nothing new yet,
# I'll process it" for the same commit) ---
POLL_LOCK_FILE="${LOCK_DIR}/poll.lock"
exec 8>"$POLL_LOCK_FILE"
if ! flock -n 8; then
	log "==> another poll tick is already running (lock: ${POLL_LOCK_FILE}) - skipping this tick, the backlog (if any) will be picked up next time"
	exit 0
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
# never silently continues past a marker that didn't actually get written, which would let a
# commit be reprocessed (harmless but wasteful) or, worse, be silently skipped depending on where
# in the loop the failure happened.
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
# a poll-level error, not a divergence finding, and must never be treated as one: doing so would
# permanently reset the baseline past commits that were never actually processed, silently skipping
# them for good. ---
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

# --- the actual backlog, oldest first (see header for why not "just the newest"), --first-parent
# only: LAST is confirmed an ancestor of TIP and LAST != TIP above, so a *linear* first-parent walk
# from TIP back to LAST can never be empty - master takes merge commits (every PR here lands via
# one), and without --first-parent, rev-list would also yield every individual commit *on* each
# merged-in feature branch, interleaved by date across branches rather than in master's own merge
# order - exactly the out-of-order processing the in-order design above exists to avoid (a stale
# green re-publish of an old feature-branch commit could close a red issue a genuinely later
# master commit opened; WIP commits from a branch would each get their own suite run/release).
# --first-parent walks only the commits actually reachable via master's own first-parent chain -
# each merge commit itself (which already carries the merged branch's full diff) plus any commit
# pushed to master directly, in true master order. ---
if ! NEW_COMMITS_RAW="$(git -C "$REPO_ROOT" rev-list --first-parent --reverse "${LAST}..${TIP}")"; then
	log "==> error: 'git rev-list --first-parent ${LAST}..${TIP}' failed"
	exit 2
fi
mapfile -t NEW_COMMITS <<<"$NEW_COMMITS_RAW"
# mapfile on empty input yields one empty-string element, not zero elements - filter it out. An
# empty backlog here is otherwise unreachable (LAST is a confirmed ancestor of TIP, and LAST !=
# TIP, so TIP itself is always in range) - if it ever happens anyway, treat it as "nothing to do"
# rather than guess.
if [ "${#NEW_COMMITS[@]}" -eq 1 ] && [ -z "${NEW_COMMITS[0]}" ]; then
	NEW_COMMITS=()
fi
if [ "${#NEW_COMMITS[@]}" -eq 0 ]; then
	log "==> ${LAST}..${TIP} contains no new first-parent commits - nothing to do"
	exit 0
fi

log "==> ${#NEW_COMMITS[@]} new commit(s) since ${LAST}: ${NEW_COMMITS[*]}"

PROCESS_CMD="${CHEXTREK_PIPELINE_PROCESS_CMD:-bash \"${SCRIPT_DIR}/pipeline-process-commit.sh\"}"

POLL_EXIT=0
for SHA in "${NEW_COMMITS[@]}"; do
	log "==> processing ${SHA}"
	# `eval` runs the reconstructed command line ("$PROCESS_CMD" + a literal `"$SHA"` that only
	# expands once eval re-parses it + `8>&-`) directly in *this* shell, with `8>&-` as a
	# redirection scoped to that one command - it closes fd 8 for the process command (and
	# anything it execs) without touching this shell's own copy, which stays open and locked for
	# the rest of this loop and every later iteration. Same reasoning as
	# pipeline-process-commit.sh's own `9>&-` around its suite invocation: a process the command
	# starts that outlives the command itself (wine/Xvfb daemonizing past a killed run, etc.) must
	# never be able to hold this poll lock open forever.
	eval "$PROCESS_CMD" '"$SHA"' 8>&-
	CODE=$?
	log "==> ${SHA} exited ${CODE}"
	case "$CODE" in
	0 | 1 | 3)
		# A real, reported result either way (published / red / environment-blocked - #67's issue
		# tracker already handled it inside process-commit.sh itself) - advance the baseline past
		# this commit and move on to the next one in the backlog. This deliberately includes exit
		# 3 (environment blocker): the thing that's broken is the *environment*, not this specific
		# commit, and it's already been reported in the pipeline:red issue. Not advancing would
		# retry the same commit every tick until someone fixes the environment - commenting on the
		# issue each time, and holding up every newer commit behind it. The cost: the poller never
		# retests a blocked commit on its own. Once the environment is fixed, the next commit pushed
		# to master is processed normally; to get a result for the blocked commit itself (e.g. it
		# is still the tip), run `bash tools/pipeline-process-commit.sh <sha>` by hand
		# (docs/dev-setup.md's "AFK trigger" section).
		write_state "$SHA"
		;;
	*)
		# 2 (pipeline-level error) or anything else unexpected: not a reliable result for this
		# commit either way - don't advance past it, and don't process anything newer than it this
		# tick, so the in-order guarantee holds. The next poll tick retries this same commit first.
		log "==> stopping this poll tick: ${SHA} didn't produce a reliable result (exit ${CODE}) - the state file still points at the last commit that did; this commit will be retried next tick"
		POLL_EXIT=2
		break
		;;
	esac
done

log "=== pipeline-poll: done (exit ${POLL_EXIT}) ==="
exit "$POLL_EXIT"
