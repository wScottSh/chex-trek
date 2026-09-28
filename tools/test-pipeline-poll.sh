#!/usr/bin/env bash
# Self-test for tools/pipeline-poll.sh (spec #58/#68). No systemd dependency (that's
# tools/test-pipeline-poll-systemd.sh, which skips cleanly when systemctl --user isn't usable) -
# this covers the poll/state/ordering/no-overlap logic directly:
#   - a local bare repo stands in for the real GitHub "origin";
#   - CHEXTREK_PIPELINE_PROCESS_CMD points at a fake process-commit stub (records every commit it
#     was called with, in order, and returns a scripted exit code per commit) instead of the real
#     tools/pipeline-process-commit.sh - that script's own behavior is
#     tools/test-pipeline-process-commit.sh's job, not this one's.
# Covers: first-ever poll bootstraps the baseline without processing anything; a single new commit
# is processed and the baseline advances; several commits landing between polls are processed in
# order, oldest first, one at a time; a commit that already processed is never processed again; a
# poll-level error (exit 2) from the process command stops that tick without advancing past the
# failing commit, and a later poll retries exactly that commit first; red/environment-blocked
# results (exit 1/3) still count as "processed" and advance the baseline; two overlapping poll
# ticks never both process the same commit (the poll lock); history divergence (a force-push past
# the last-processed commit) resets the baseline without processing and is reported distinctly.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRATCH="$(mktemp -d)"
trap 'rm -rf "$SCRATCH"' EXIT
FAIL=0

pass() { echo "PASS: $*"; }
fail() {
	echo "FAIL: $*"
	FAIL=1
}

# --- bare "origin" + a separate pusher clone that simulates commits landing on master from
# elsewhere (never the poller's own checkout) ---
ORIGIN="${SCRATCH}/origin.git"
git init -q --bare -b master "$ORIGIN"

PUSHER="${SCRATCH}/pusher"
git clone -q "$ORIGIN" "$PUSHER"
git -C "$PUSHER" config user.email test@example.invalid
git -C "$PUSHER" config user.name "Pipeline Poll Test"
git -C "$PUSHER" commit -q --allow-empty -m "seed"
git -C "$PUSHER" push -q origin master

push_commit() {
	local MSG="$1"
	git -C "$PUSHER" commit -q --allow-empty -m "$MSG"
	git -C "$PUSHER" push -q origin master
	git -C "$PUSHER" rev-parse HEAD
}

force_reset_origin_to_orphan() {
	# Simulates a force-push that rewrites master to a commit with no relation to the current tip.
	local ORPHAN_CLONE="${SCRATCH}/orphan-pusher"
	rm -rf "$ORPHAN_CLONE"
	git init -q "$ORPHAN_CLONE"
	git -C "$ORPHAN_CLONE" config user.email test@example.invalid
	git -C "$ORPHAN_CLONE" config user.name "Pipeline Poll Test"
	git -C "$ORPHAN_CLONE" checkout -q --orphan master
	git -C "$ORPHAN_CLONE" commit -q --allow-empty -m "orphan history"
	git -C "$ORPHAN_CLONE" push -q -f "$ORIGIN" master
	git -C "$ORPHAN_CLONE" rev-parse HEAD
}

# --- poller checkout: what tools/pipeline-poll.sh treats as "the repo it lives in" (REPO_ROOT =
# its own script dir's parent) - a clone of $ORIGIN with the real script copied in, never mutated
# by the script itself beyond fetching ---
REPO="${SCRATCH}/poller-repo"
mkdir -p "${REPO}/tools"
cp "${SCRIPT_DIR}/pipeline-poll.sh" "${REPO}/tools/pipeline-poll.sh"
git init -q "$REPO"
git -C "$REPO" remote add origin "$ORIGIN"
git -C "$REPO" fetch -q origin master

# --- fake process-commit: records each SHA it's called with (in call order) to
# STUB_PROCESS_CALLS, and exits with whatever STUB_PROCESS_EXITCODES maps that SHA to (default 0) ---
cat >"${SCRATCH}/fake-process-commit.sh" <<'STUBEOF'
#!/usr/bin/env bash
SHA="${1:?missing sha arg}"
echo "$SHA" >>"$STUB_PROCESS_CALLS"
CODE="$(awk -v s="$SHA" '$1==s{print $2; exit}' "$STUB_PROCESS_EXITCODES" 2>/dev/null)"
exit "${CODE:-0}"
STUBEOF
chmod +x "${SCRATCH}/fake-process-commit.sh"

export STUB_PROCESS_CALLS="${SCRATCH}/process-calls.log"
export STUB_PROCESS_EXITCODES="${SCRATCH}/process-exitcodes.txt"
: >"$STUB_PROCESS_CALLS"
: >"$STUB_PROCESS_EXITCODES"

export CHEXTREK_PIPELINE_PROCESS_CMD="bash \"${SCRATCH}/fake-process-commit.sh\""
export CHEXTREK_PIPELINE_STATE_DIR="${SCRATCH}/state"
export CHEXTREK_PIPELINE_POLL_BRANCH="master"

STATE_FILE="${CHEXTREK_PIPELINE_STATE_DIR}/poller-last-processed"

poll() {
	(cd "$REPO" && bash tools/pipeline-poll.sh)
}

calls_since() {
	# All recorded calls (one sha per line, in call order) since the last time this helper (or the
	# test) reset the log - tests call reset_calls() between assertions instead.
	cat "$STUB_PROCESS_CALLS"
}

reset_calls() { : >"$STUB_PROCESS_CALLS"; }

# === 1. bootstrap: first-ever poll sets the baseline without processing anything ===
OUT="$(poll)"
CODE=$?
if [ "$CODE" = "0" ] && [ -f "$STATE_FILE" ] && [ "$(wc -l <"$STUB_PROCESS_CALLS")" = "0" ]; then
	pass "bootstrap: first poll exits 0, writes a baseline, processes nothing"
else
	fail "bootstrap: exit=$CODE state_file_exists=$([ -f "$STATE_FILE" ] && echo yes || echo no) calls=$(wc -l <"$STUB_PROCESS_CALLS")"
fi
BASELINE_AFTER_BOOTSTRAP="$(cat "$STATE_FILE" 2>/dev/null)"
SEED_SHA="$(git -C "$PUSHER" rev-parse HEAD)"
if [ "$BASELINE_AFTER_BOOTSTRAP" = "$SEED_SHA" ]; then
	pass "bootstrap: baseline equals the current origin/master tip"
else
	fail "bootstrap: baseline='${BASELINE_AFTER_BOOTSTRAP}' expected '${SEED_SHA}'"
fi

# === 2. up to date: a second poll with nothing new processes nothing ===
reset_calls
OUT="$(poll)"
CODE=$?
if [ "$CODE" = "0" ] && [ "$(wc -l <"$STUB_PROCESS_CALLS")" = "0" ]; then
	pass "up-to-date: repeat poll with nothing new processes nothing"
else
	fail "up-to-date: exit=$CODE calls=$(wc -l <"$STUB_PROCESS_CALLS")"
fi

# === 3. a single new commit is processed, baseline advances ===
reset_calls
SHA_A="$(push_commit "commit A")"
OUT="$(poll)"
CODE=$?
GOT_CALLS="$(calls_since | tr '\n' ' ')"
if [ "$CODE" = "0" ] && [ "$GOT_CALLS" = "${SHA_A} " ] && [ "$(cat "$STATE_FILE")" = "$SHA_A" ]; then
	pass "single new commit: processed once, baseline advances to it"
else
	fail "single new commit: exit=$CODE calls='${GOT_CALLS}' state='$(cat "$STATE_FILE")' expected '${SHA_A}'"
fi

# === 4. already-processed commit is never processed again ===
reset_calls
OUT="$(poll)"
if [ "$(wc -l <"$STUB_PROCESS_CALLS")" = "0" ]; then
	pass "already-processed commit is not reprocessed"
else
	fail "already-processed commit was reprocessed: $(calls_since)"
fi

# === 5. several commits land between polls: processed in order, oldest first, one poll run ===
reset_calls
SHA_B="$(push_commit "commit B")"
SHA_C="$(push_commit "commit C")"
SHA_D="$(push_commit "commit D")"
OUT="$(poll)"
CODE=$?
GOT_CALLS="$(calls_since | tr '\n' ' ')"
EXPECTED="${SHA_B} ${SHA_C} ${SHA_D} "
if [ "$CODE" = "0" ] && [ "$GOT_CALLS" = "$EXPECTED" ] && [ "$(cat "$STATE_FILE")" = "$SHA_D" ]; then
	pass "backlog of several commits processed in order, oldest first, baseline lands on the newest"
else
	fail "backlog ordering: exit=$CODE calls='${GOT_CALLS}' expected='${EXPECTED}' state='$(cat "$STATE_FILE")'"
fi

# === 6. red/environment-blocked results (exit 1/3) still count as processed ===
reset_calls
SHA_RED="$(push_commit "commit red")"
printf '%s 1\n' "$SHA_RED" >>"$STUB_PROCESS_EXITCODES"
OUT="$(poll)"
CODE=$?
if [ "$CODE" = "0" ] && [ "$(cat "$STATE_FILE")" = "$SHA_RED" ]; then
	pass "a red result (exit 1) from the process command still advances the baseline"
else
	fail "red result handling: exit=$CODE state='$(cat "$STATE_FILE")' expected '${SHA_RED}'"
fi

reset_calls
SHA_ENV="$(push_commit "commit env-blocked")"
printf '%s 3\n' "$SHA_ENV" >>"$STUB_PROCESS_EXITCODES"
OUT="$(poll)"
CODE=$?
if [ "$CODE" = "0" ] && [ "$(cat "$STATE_FILE")" = "$SHA_ENV" ]; then
	pass "an environment-blocked result (exit 3) from the process command still advances the baseline"
else
	fail "environment-blocked result handling: exit=$CODE state='$(cat "$STATE_FILE")' expected '${SHA_ENV}'"
fi

# === 7. a poll-level error (exit 2) stops the tick without advancing past the failing commit, and
# a later poll retries exactly that commit first (not skipping it, not re-running earlier ones) ===
reset_calls
BASELINE_BEFORE="$(cat "$STATE_FILE")"
SHA_ERR="$(push_commit "commit pipeline-error")"
SHA_AFTER_ERR="$(push_commit "commit after the error")"
printf '%s 2\n' "$SHA_ERR" >>"$STUB_PROCESS_EXITCODES"
OUT="$(poll)"
CODE=$?
GOT_CALLS="$(calls_since | tr '\n' ' ')"
if [ "$CODE" = "2" ] && [ "$GOT_CALLS" = "${SHA_ERR} " ] && [ "$(cat "$STATE_FILE")" = "$BASELINE_BEFORE" ]; then
	pass "poll-level error (exit 2) stops the tick, doesn't advance the baseline, doesn't process the commit after it"
else
	fail "poll-level error handling: exit=$CODE calls='${GOT_CALLS}' state='$(cat "$STATE_FILE")' expected_unchanged='${BASELINE_BEFORE}'"
fi

# Fix the stub so the previously-failing commit now succeeds, and poll again - it must be retried
# first (not skipped), and the commit after it must then also be processed in the same or a
# subsequent tick.
sed -i "\|^${SHA_ERR} |d" "$STUB_PROCESS_EXITCODES"
reset_calls
OUT="$(poll)"
CODE=$?
GOT_CALLS="$(calls_since | tr '\n' ' ')"
EXPECTED="${SHA_ERR} ${SHA_AFTER_ERR} "
if [ "$CODE" = "0" ] && [ "$GOT_CALLS" = "$EXPECTED" ] && [ "$(cat "$STATE_FILE")" = "$SHA_AFTER_ERR" ]; then
	pass "once fixed, the previously-erroring commit is retried first, then the one after it"
else
	fail "retry-after-error ordering: exit=$CODE calls='${GOT_CALLS}' expected='${EXPECTED}' state='$(cat "$STATE_FILE")'"
fi

# === 8. no-overlap: a poll tick that finds the lock already held skips cleanly (exit 0, no calls) ===
reset_calls
push_commit "commit during overlap" >/dev/null
LOCK_FILE="${CHEXTREK_PIPELINE_STATE_DIR}/locks/poll.lock"
mkdir -p "$(dirname "$LOCK_FILE")"
MARKER="${SCRATCH}/lock-held.marker"
rm -f "$MARKER"
(
	exec 8>"$LOCK_FILE"
	flock 8
	touch "$MARKER"
	sleep 5
) &
HOLDER_PID=$!
if ! timeout 5 bash -c "until [ -f '$MARKER' ]; do sleep 0.1; done"; then
	fail "no-overlap setup: lock holder never signaled it had the lock"
else
	OUT="$(poll)"
	CODE=$?
	if [ "$CODE" = "0" ] && [ "$(wc -l <"$STUB_PROCESS_CALLS")" = "0" ]; then
		pass "no-overlap: a poll tick finding the lock already held skips cleanly, processes nothing"
	else
		fail "no-overlap: exit=$CODE calls=$(wc -l <"$STUB_PROCESS_CALLS")"
	fi
fi
wait "$HOLDER_PID" 2>/dev/null || true

# Now that the holder released the lock, the backlog (the commit pushed during the overlap window)
# is picked up on the next tick, proving nothing was silently lost.
reset_calls
OUT="$(poll)"
CODE=$?
if [ "$CODE" = "0" ] && [ "$(wc -l <"$STUB_PROCESS_CALLS")" = "1" ]; then
	pass "no-overlap: the commit skipped during the overlap window is picked up on the next tick"
else
	fail "no-overlap follow-up: exit=$CODE calls=$(wc -l <"$STUB_PROCESS_CALLS")"
fi

# === 9. history divergence (force-push past the last-processed commit): baseline resets to the
# new tip, nothing is processed, reported distinctly (exit 2) ===
reset_calls
NEW_TIP="$(force_reset_origin_to_orphan)"
OUT="$(poll)"
CODE=$?
if [ "$CODE" = "2" ] && [ "$(wc -l <"$STUB_PROCESS_CALLS")" = "0" ] && [ "$(cat "$STATE_FILE")" = "$NEW_TIP" ] && printf '%s' "$OUT" | grep -q "diverged"; then
	pass "history divergence: baseline resets to the new tip, nothing processed, exit 2, warning logged"
else
	fail "history divergence: exit=$CODE calls=$(wc -l <"$STUB_PROCESS_CALLS") state='$(cat "$STATE_FILE")' expected='${NEW_TIP}'"
fi

# A poll right after the divergence reset is now the ordinary "up to date" case.
reset_calls
OUT="$(poll)"
CODE=$?
if [ "$CODE" = "0" ] && [ "$(wc -l <"$STUB_PROCESS_CALLS")" = "0" ]; then
	pass "post-divergence poll is an ordinary up-to-date tick"
else
	fail "post-divergence follow-up: exit=$CODE calls=$(wc -l <"$STUB_PROCESS_CALLS")"
fi

# === 10. a merge commit lands on master (a PR-style merge, same shape as this repo's own
# history): only the merge commit itself is processed - --first-parent must skip the individual
# feature-branch commits it merged in, never process them out of master's own order ===
reset_calls
# PUSHER's own local master can be stale after test 9's force-push (done via a separate throwaway
# clone, never through PUSHER) - resync it to origin/master first, same as any real contributor
# would after a force-push, so this push isn't rejected as non-fast-forward.
git -C "$PUSHER" fetch -q origin master
git -C "$PUSHER" checkout -q -B master origin/master
git -C "$PUSHER" checkout -q -b feature-x
git -C "$PUSHER" commit -q --allow-empty -m "feature commit 1"
FEATURE_SHA1="$(git -C "$PUSHER" rev-parse HEAD)"
git -C "$PUSHER" commit -q --allow-empty -m "feature commit 2"
FEATURE_SHA2="$(git -C "$PUSHER" rev-parse HEAD)"
git -C "$PUSHER" checkout -q master
git -C "$PUSHER" merge -q --no-ff -m "Merge feature-x" feature-x
MERGE_SHA="$(git -C "$PUSHER" rev-parse HEAD)"
git -C "$PUSHER" push -q origin master
git -C "$PUSHER" branch -q -D feature-x
OUT="$(poll)"
CODE=$?
GOT_CALLS="$(calls_since | tr '\n' ' ')"
if [ "$CODE" = "0" ] && [ "$GOT_CALLS" = "${MERGE_SHA} " ] && [ "$(cat "$STATE_FILE")" = "$MERGE_SHA" ]; then
	pass "a merge commit is processed exactly once, as itself - the merged-in feature commits are never individually processed"
else
	fail "merge commit handling: exit=$CODE calls='${GOT_CALLS}' expected only '${MERGE_SHA}' (never ${FEATURE_SHA1} or ${FEATURE_SHA2}) state='$(cat "$STATE_FILE")'"
fi

# === 11. a merge-base error that isn't a real divergence (e.g. the state file naming an object
# this repo doesn't have) is a poll-level error, not a false "force-push" reset - the baseline is
# left exactly as it was, not clobbered with the current tip ===
reset_calls
cp "$STATE_FILE" "${STATE_FILE}.bak"
BOGUS_SHA="0000000000000000000000000000000000000000"
printf '%s\n' "$BOGUS_SHA" >"$STATE_FILE"
OUT="$(poll)"
CODE=$?
if [ "$CODE" = "2" ] && [ "$(wc -l <"$STUB_PROCESS_CALLS")" = "0" ] && [ "$(cat "$STATE_FILE")" = "$BOGUS_SHA" ] && ! printf '%s' "$OUT" | grep -q "diverged"; then
	pass "a merge-base error (bad object, not a real divergence) is a poll-level error - baseline left untouched, never falsely reset"
else
	fail "merge-base-error handling: exit=$CODE calls=$(wc -l <"$STUB_PROCESS_CALLS") state='$(cat "$STATE_FILE")' expected_unchanged='${BOGUS_SHA}'"
fi
mv "${STATE_FILE}.bak" "$STATE_FILE"

echo
if [ "$FAIL" = "0" ]; then
	echo "PASS: whole suite"
	exit 0
fi
echo "FAIL: tools/test-pipeline-poll.sh"
exit 1
