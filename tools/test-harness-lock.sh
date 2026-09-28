#!/usr/bin/env bash
# Automated test for #62 (blocked by #60): on Unicron (Linux/Wine), two harness runs started at
# the same time on the same machine never collide - a single-run flock (tools/lib-harness.sh,
# _chextrek_acquire_lock/_chextrek_release_lock) serializes them instead. Windows is out of scope
# for #62 (still just the documented "one at a time" rule, unenforced - see docs/dev-setup.md), so
# this test is a no-op there.
#
# Uses a private CHEXTREK_LOCK_FILE (not the machine-wide default) throughout, so this test can
# neither be blocked by, nor interfere with, a real harness run already using the default lock -
# same idea as tools/test-harness-no-display.sh's curated PATH keeping that self-test isolated from
# the real environment while exercising the exact same code paths.
#
# Case 1 and 3 prove AC2 (the second run prints that it's waiting) deterministically, by holding
# the lock with a plain `flock FILE sleep N` for a known duration and timing the acquirer against
# it, rather than hoping two independent real runs happen to race within the same few hundred
# milliseconds. Case 2 proves AC3 (a killed lock holder leaves no stale lock). Case 4 proves AC1
# (two real runs started at once both complete, correctly, without touching each other's log/save
# dir) with two genuinely concurrent real harness invocations.
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

export CHEXTREK_LOCK_FILE="${SCRATCH}/test-harness.lock"

echo "=== #62 lock test: case 1 - a held lock blocks the second acquirer, which prints it's waiting (AC2) ==="
flock "$CHEXTREK_LOCK_FILE" sleep 3 &
HOLDER_PID=$!
sleep 0.5 # give the holder a head start so it reliably wins the lock first

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
echo "=== #62 lock test: case 2 - a killed lock holder leaves no stale lock (AC3) ==="
# Holds the lock the same way a real run does: _chextrek_acquire_lock opens the lock file on an
# fd owned by *this* process (bash auto-closes such fds on exec, so a forked/exec'd child like
# `sleep` below never gets a copy of it - only this process's own fd matters). Killing this single
# process with SIGKILL is what "a crashed or killed run" means (#62 AC3): the kernel closes its fd
# and drops the lock right along with it. (A plain `flock FILE sleep N &` isn't equivalent here -
# flock(1) deliberately leaves the lock fd open across its own exec of the command, so killing just
# the wrapper process would leave the `sleep` child still holding it for the rest of its run.)
bash -c '
	source "$1/lib-harness.sh"
	_chextrek_acquire_lock
	sleep 60
' _ "$SCRIPT_DIR" &
KILL_PID=$!
sleep 0.5 # give it time to actually take the lock before it's killed out from under it
kill -9 "$KILL_PID" 2>/dev/null
wait "$KILL_PID" 2>/dev/null

START2=$(date +%s%N)
OUT2="$(bash -c '
	source "$1/lib-harness.sh"
	_chextrek_acquire_lock
	echo "acquired-after-kill"
	_chextrek_release_lock
' _ "$SCRIPT_DIR" 2>&1)"
ELAPSED2_MS=$(( ($(date +%s%N) - START2) / 1000000 ))

if echo "$OUT2" | grep -qF "acquired-after-kill"; then
	echo "PASS: acquired the lock after its holder was killed"
else
	echo "FAIL: never acquired the lock after its holder was killed; got:"
	echo "$OUT2"
	FAIL=1
fi
if [ "$ELAPSED2_MS" -le 2000 ]; then
	echo "PASS: no stale lock - acquired promptly (${ELAPSED2_MS}ms), not stuck behind the killed holder"
else
	echo "FAIL: took ${ELAPSED2_MS}ms to acquire - looks like a stale lock blocked it"
	FAIL=1
fi

echo
echo "=== #62 lock test: case 3 - a real harness run really waits for a held lock, then still passes (AC1+AC2) ==="
chextrek_build_or_exit

flock "$CHEXTREK_LOCK_FILE" sleep 3 &
HOLDER3_PID=$!
sleep 0.5

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
