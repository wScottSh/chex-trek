#!/usr/bin/env bash
# Automated test for #62 (blocked by #60): on Unicron (Linux/Wine), two harness runs started at
# the same time on the same machine never collide - a single-run flock (tools/lib-harness.sh,
# _chextrek_acquire_lock/_chextrek_release_lock) serializes them instead. Windows is out of scope
# for #62 (still just the documented "one at a time" rule, unenforced - see docs/dev-setup.md), so
# this test is a no-op there.
#
# Case 1 and 2 use a private CHEXTREK_LOCK_FILE so they can't be blocked by a real harness run
# already using the default lock - same idea as tools/test-harness-no-display.sh's curated PATH
# keeping that self-test isolated from the real environment while exercising the exact same code
# paths. Case 3 and 4 launch the *real* harness scripts and deliberately leave CHEXTREK_LOCK_FILE
# unset, so they exercise the actual default lock (`/tmp/chextrek-harness.lock`) two real, unrelated
# invocations would use - the scenario #62 exists for.
#
# Case 1 proves AC2 (the second run prints that it's waiting) deterministically, by holding the
# lock with a plain `flock FILE sleep N` for a known duration and timing the acquirer against it,
# rather than hoping two independent real runs happen to race within the same few hundred
# milliseconds. Case 2 proves AC3 (a harness run killed while a child it started - Xvfb, or the wine
# launch - is still running leaves no stale lock): it mirrors those two call sites' actual shape
# (acquire the lock, background a child that closes its own inherited copy of the lock fd before
# exec'ing into a long-running process, get killed itself while that child is still alive) rather
# than a generic "kill -9 a process holding a lock" case, which a naive fix (e.g. relying on
# close-on-exec) could pass without actually covering Xvfb/wine. Case 3 proves AC1+AC2 against a
# real harness run. Case 4 proves AC1 (two real runs started at once both complete, correctly,
# without touching each other's log/save dir) with two genuinely concurrent real harness
# invocations.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=tools/lib-harness.sh
source "${SCRIPT_DIR}/lib-harness.sh"

if ! chextrek_is_linux; then
	echo "SKIP: #62's single-run lock is Unicron (Linux/Wine)-only; nothing to test on Windows yet"
	exit 0
fi

FAIL=0
SCRATCH="$(mktemp -d)"
trap 'rm -rf "$SCRATCH"' EXIT

# _wait_until_locked LOCK_FILE - polls until LOCK_FILE is actually held by someone else, instead of
# a fixed sleep guessing how long a just-backgrounded `flock`/holder takes to actually take the
# lock (thin on a loaded machine). Gives up after 2s so a genuinely broken case still fails fast.
_wait_until_locked() {
	local LOCK_FILE="$1" WAITED=0
	while [ $WAITED -lt 20 ]; do
		flock -n "$LOCK_FILE" -c true 2>/dev/null || return 0
		sleep 0.1
		WAITED=$((WAITED + 1))
	done
	return 1
}

export CHEXTREK_LOCK_FILE="${SCRATCH}/test-harness.lock"

echo "=== #62 lock test: case 1 - a held lock blocks the second acquirer, which prints it's waiting (AC2) ==="
flock "$CHEXTREK_LOCK_FILE" sleep 3 &
HOLDER_PID=$!
_wait_until_locked "$CHEXTREK_LOCK_FILE" || { echo "FAIL: holder never actually took the lock"; FAIL=1; }

START=$(date +%s%N)
OUT="$(bash -c '
	source "$1/lib-harness.sh"
	_chextrek_acquire_lock
	echo "acquired"
	_chextrek_release_lock
' _ "$SCRIPT_DIR" 2>&1)"
ELAPSED_MS=$(( ($(date +%s%N) - START) / 1000000 ))
wait "$HOLDER_PID" 2>/dev/null

if echo "$OUT" | grep -qF "Waiting for the harness lock"; then
	echo "PASS: waiting line printed while the lock was held"
else
	echo "FAIL: expected a 'Waiting for the harness lock' line; got:"
	echo "$OUT"
	FAIL=1
fi
if echo "$OUT" | grep -qF "acquired"; then
	echo "PASS: eventually acquired the lock once the holder released it"
else
	echo "FAIL: never acquired the lock"
	FAIL=1
fi
if [ "$ELAPSED_MS" -ge 2000 ]; then
	echo "PASS: waited roughly as long as the holder held the lock (${ELAPSED_MS}ms)"
else
	echo "FAIL: acquired too fast (${ELAPSED_MS}ms) - the lock doesn't seem to be blocking at all"
	FAIL=1
fi

echo
echo "=== #62 lock test: case 2 - killing a run while its own long-lived child (Xvfb/wine) is still alive leaves no stale lock (AC3) ==="
# Mirrors the actual shape of chextrek_ensure_display_or_exit's Xvfb spawn and the wine launch in
# _chextrek_run_console_script_impl: acquire the lock, background a child that closes its own
# inherited copy of the lock fd before exec'ing into something long-running, then (simulating this
# whole "run" getting killed, e.g. an operator's Ctrl-C or an OOM kill) SIGKILL only the top-level
# process while that child is still alive. If the lock were still held by the child afterwards (the
# bug a naive fix could leave in - e.g. trusting exec's close-on-exec instead of closing the fd by
# hand), the next acquire below would block for the child's whole remaining sleep.
bash -c '
	source "$1/lib-harness.sh"
	_chextrek_acquire_lock
	( [ -n "${CHEXTREK_LOCK_FD:-}" ] && eval "exec ${CHEXTREK_LOCK_FD}>&-"
	  exec sleep 60 ) &
	echo "child-pid=$!"
	wait
' _ "$SCRIPT_DIR" > "${SCRATCH}/case2-holder.out" 2>&1 &
HOLDER_PID=$!

CHILD_PID=""
for _ in $(seq 1 50); do
	CHILD_PID="$(sed -n 's/^child-pid=//p' "${SCRATCH}/case2-holder.out" 2>/dev/null)"
	[ -n "$CHILD_PID" ] && break
	sleep 0.1
done
if [ -z "$CHILD_PID" ]; then
	echo "FAIL: the simulated run never reported its child's pid; can't run this case"
	FAIL=1
else
	kill -9 "$HOLDER_PID" 2>/dev/null # kill only the "run" - its child (the orphan) keeps running
	wait "$HOLDER_PID" 2>/dev/null
	if ! kill -0 "$CHILD_PID" 2>/dev/null; then
		echo "FAIL: the simulated child didn't survive its parent - this case didn't test what it meant to"
		FAIL=1
	fi

	START2=$(date +%s%N)
	OUT2="$(bash -c '
		source "$1/lib-harness.sh"
		_chextrek_acquire_lock
		echo "acquired-after-kill"
		_chextrek_release_lock
	' _ "$SCRIPT_DIR" 2>&1)"
	ELAPSED2_MS=$(( ($(date +%s%N) - START2) / 1000000 ))

	kill -9 "$CHILD_PID" 2>/dev/null # clean up the orphaned sleep, its job here is done
	wait "$CHILD_PID" 2>/dev/null

	if echo "$OUT2" | grep -qF "acquired-after-kill"; then
		echo "PASS: acquired the lock while the orphaned child was still alive"
	else
		echo "FAIL: never acquired the lock; got:"
		echo "$OUT2"
		FAIL=1
	fi
	if [ "$ELAPSED2_MS" -le 2000 ]; then
		echo "PASS: no stale lock - acquired promptly (${ELAPSED2_MS}ms) despite the surviving orphan"
	else
		echo "FAIL: took ${ELAPSED2_MS}ms to acquire - the orphaned child is still holding the lock"
		FAIL=1
	fi
fi

echo
echo "=== #62 lock test: case 2b - the real Xvfb chextrek_ensure_display_or_exit starts doesn't inherit the lock fd (AC3) ==="
# Case 2 proves the *mechanism* (a child that closes its inherited fd survives its parent without
# holding the lock); this ties that directly to the real production code path instead of the test's
# own stand-in, by starting a real Xvfb through the real function and checking its own /proc fd
# table doesn't list the lock file - i.e. this isn't testing a copy of the fix, it's testing the fix.
if command -v Xvfb >/dev/null 2>&1; then
	OUT2B="$(env -u DISPLAY bash -c '
		source "$1/lib-harness.sh"
		_chextrek_acquire_lock
		chextrek_ensure_display_or_exit
		echo "xvfb-pid=${CHEXTREK_XVFB_PID}"
		echo "lock-fd=${CHEXTREK_LOCK_FD}"
		sleep 1
	' _ "$SCRIPT_DIR" 2>&1)"
	XVFB_PID="$(echo "$OUT2B" | sed -n 's/^xvfb-pid=//p')"
	LOCK_FD_NUM="$(echo "$OUT2B" | sed -n 's/^lock-fd=//p')"
	if [ -n "$XVFB_PID" ] && [ -n "$LOCK_FD_NUM" ] && [ -e "/proc/${XVFB_PID}/fd" ]; then
		if [ -e "/proc/${XVFB_PID}/fd/${LOCK_FD_NUM}" ]; then
			echo "FAIL: the real Xvfb process still has the lock fd (${LOCK_FD_NUM}) open"
			FAIL=1
		else
			echo "PASS: the real Xvfb process doesn't have the lock fd open"
		fi
	else
		echo "SKIP: couldn't find the Xvfb pid/fd table to check (got xvfb-pid='${XVFB_PID}' lock-fd='${LOCK_FD_NUM}')"
	fi
	# chextrek_ensure_display_or_exit doesn't stop its own Xvfb (only the run wrapper does, via
	# _chextrek_stop_xvfb) - this check called it directly, so clean up the Xvfb it started by hand.
	# It's not a direct child of this shell (it was started by the now-exited bash -c above), so
	# `wait` doesn't apply - just kill it.
	[ -n "$XVFB_PID" ] && kill "$XVFB_PID" 2>/dev/null
else
	echo "SKIP: Xvfb not installed on this host"
fi

echo
echo "=== #62 lock test: case 3 - a real harness run really waits for a held lock, then still passes (AC1+AC2) ==="
chextrek_build_or_exit
unset CHEXTREK_LOCK_FILE # exercise the real default lock - the one two unrelated real runs would share

flock "$(chextrek_lock_file)" sleep 3 &
HOLDER3_PID=$!
_wait_until_locked "$(chextrek_lock_file)" || { echo "FAIL: holder never actually took the lock"; FAIL=1; }

START3=$(date +%s%N)
HARNESS_OUT="$(bash "${SCRIPT_DIR}/run-harness.sh" 60 2>&1)"
HARNESS_EXIT=$?
ELAPSED3_MS=$(( ($(date +%s%N) - START3) / 1000000 ))
wait "$HOLDER3_PID" 2>/dev/null

if [ $HARNESS_EXIT -eq 3 ]; then
	echo "$HARNESS_OUT"
	exit 3
fi

if echo "$HARNESS_OUT" | grep -qF "Waiting for the harness lock"; then
	echo "PASS: the real run printed that it's waiting for the harness lock"
else
	echo "FAIL: expected the real run's own output to include 'Waiting for the harness lock'"
	FAIL=1
fi
if [ "$ELAPSED3_MS" -ge 2000 ]; then
	echo "PASS: the real run actually waited for the held lock (${ELAPSED3_MS}ms) instead of racing it"
else
	echo "FAIL: the real run finished in ${ELAPSED3_MS}ms - it doesn't look like it waited at all"
	FAIL=1
fi
if [ $HARNESS_EXIT -eq 0 ]; then
	echo "PASS: the real run still passed its always-on checks after waiting for the lock"
else
	echo "FAIL: expected the real run to pass after waiting for the lock, but it exited ${HARNESS_EXIT}"
	FAIL=1
fi

echo
echo "=== #62 lock test: case 4 - two real harness runs started at once both complete correctly, without touching each other's log/save dir (AC1) ==="
printf '%s\n' "developer 1" "chextrek_dump" "wait" "quit" > "${SCRATCH}/menu.cfg"
printf '%s\n' "developer 1" "map e1m1" "chextrek_dump" "wait" "quit" > "${SCRATCH}/e1m1.cfg"

bash "${SCRIPT_DIR}/run-scenario.sh" chextrek_lock_test_menu "${SCRATCH}/menu.cfg" 90 > "${SCRATCH}/run1.out" 2>&1 &
RUN1_PID=$!
bash "${SCRIPT_DIR}/run-scenario.sh" chextrek_lock_test_e1m1 "${SCRATCH}/e1m1.cfg" 90 > "${SCRATCH}/run2.out" 2>&1 &
RUN2_PID=$!

wait "$RUN1_PID"
RUN1_EXIT=$?
wait "$RUN2_PID"
RUN2_EXIT=$?

RUN1_OUT="$(cat "${SCRATCH}/run1.out")"
RUN2_OUT="$(cat "${SCRATCH}/run2.out")"

if [ $RUN1_EXIT -eq 3 ]; then
	echo "$RUN1_OUT"
	exit 3
fi
if [ $RUN2_EXIT -eq 3 ]; then
	echo "$RUN2_OUT"
	exit 3
fi

echo "--- run1 (menu, no map) ---"
echo "$RUN1_OUT"
echo "--- run2 (e1m1) ---"
echo "$RUN2_OUT"

if [ $RUN1_EXIT -eq 0 ] && [ $RUN2_EXIT -eq 0 ]; then
	echo "PASS: both concurrent runs passed their always-on checks"
else
	echo "FAIL: expected both concurrent runs to pass; run1 exit=${RUN1_EXIT} run2 exit=${RUN2_EXIT}"
	FAIL=1
fi

LOG1="$(echo "$RUN1_OUT" | sed -n 's/^CHEXTREK_LOCAL_LOG=//p')"
LOG2="$(echo "$RUN2_OUT" | sed -n 's/^CHEXTREK_LOCAL_LOG=//p')"

if [ -n "$LOG1" ] && [ -f "$LOG1" ] && [ -n "$LOG2" ] && [ -f "$LOG2" ] && [ "$LOG1" != "$LOG2" ]; then
	echo "PASS: each run archived its own, distinct log"
else
	echo "FAIL: expected two distinct archived logs; got LOG1='${LOG1}' LOG2='${LOG2}'"
	FAIL=1
fi

if [ -n "${LOG2:-}" ] && [ -f "$LOG2" ]; then
	chextrek_assert_map_loaded "$LOG2" e1m1 || FAIL=1
else
	echo "FAIL: no e1m1 run log to check"
	FAIL=1
fi

if [ -n "${LOG1:-}" ] && [ -f "$LOG1" ]; then
	if grep -qE "msec to load" "$LOG1"; then
		echo "FAIL: the menu-smoke run's log shows a map load - it looks crossed with the e1m1 run"
		FAIL=1
	else
		echo "PASS: the menu-smoke run's log has no map load - not crossed with the e1m1 run"
	fi
else
	echo "FAIL: no menu-smoke run log to check"
	FAIL=1
fi

if echo "${RUN1_OUT}${RUN2_OUT}" | grep -qF "Waiting for the harness lock"; then
	echo "PASS: contention was observed between the two concurrent real runs"
else
	echo "INFO: no contention observed between these two concurrent real runs (both may have run too fast to overlap) - AC2 is proven deterministically in case 1 and case 3 above"
fi

echo
if [ $FAIL -eq 0 ]; then
	echo "PASS: #62 single-run lock test"
	exit 0
else
	echo "FAIL: #62 single-run lock test - see above"
	exit 1
fi
