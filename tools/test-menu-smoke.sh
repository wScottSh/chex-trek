#!/usr/bin/env bash
# Automated test for spec #30's first acceptance criterion: "Harness run to the main menu is
# green (turns ticket 1's known failure green)". Builds chextrek.dll and runs the harness, then
# checks the run is green and that the specific #29 failure (chex_events.script line 2, Unknown
# event 'openDoors') is gone - not just that *some* different error stopped showing up.
#
# This replaces tools/test-tracer-bullet.sh (spec #29), which asserted the opposite: that the
# harness reproduced that same failure as expected-red before the script events were ported. See
# docs/harness-coverage.md.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== #30 menu-smoke test: build ==="
if ! bash "${SCRIPT_DIR}/build-chextrek.sh"; then
	echo "FAIL: build-chextrek.sh failed"
	exit 1
fi

echo
echo "=== #30 menu-smoke test: harness run ==="
HARNESS_OUT="$(bash "${SCRIPT_DIR}/run-harness.sh" 60 2>&1)"
HARNESS_EXIT=$?
echo "$HARNESS_OUT"

FAIL=0

if [ $HARNESS_EXIT -ne 0 ]; then
	echo "FAIL: expected the harness to report green (script compile passes, main menu loads) now that #30 ports the script events, but it exited ${HARNESS_EXIT}"
	FAIL=1
fi

if echo "$HARNESS_OUT" | grep -qF "==> Timed out"; then
	echo "FAIL: expected no timeout kill (that meant an error dialog hung the game on the known #29 failure)"
	FAIL=1
fi

for marker in "PASS: chextrek.dll loaded (not base.dll)" "PASS: state-dump header present" "PASS: no ERROR / unknown-event / unknown-spawnclass / script-compile lines"; do
	if ! echo "$HARNESS_OUT" | grep -qF "$marker"; then
		echo "FAIL: expected to see '${marker}'"
		FAIL=1
	fi
done

# Use the log path run-harness.sh just printed (not a "most recently modified artifact dir"
# guess, which could pick up a stale run from a concurrent/previous invocation) and prove the
# specific known #29 failure is gone (not just that no error happens to show up right now) and
# that the main menu's own GUI actually loaded (a stronger signal than "no error" that the menu
# map itself was reached).
LOCAL_LOG="$(echo "$HARNESS_OUT" | sed -n 's/^CHEXTREK_LOCAL_LOG=//p')"

if [ -z "$LOCAL_LOG" ] || [ ! -f "$LOCAL_LOG" ]; then
	echo "FAIL: couldn't find this run's archived log to check further"
	FAIL=1
else
	if grep -qF "chex_events.script, line 2: Unknown event 'openDoors'" "$LOCAL_LOG"; then
		echo "FAIL: the known #29 script-compile failure ('openDoors' unknown event) is still present"
		FAIL=1
	else
		echo "PASS: the known #29 'openDoors' unknown-event failure is gone"
	fi

	# guis/assets/splash/launch is the main menu's own splash background image, reloaded via
	# idImageManager's own asset caching whenever the main menu GUI is active - a stable, cvar-
	# independent signal that the main menu's own GUI assets were actually reached.
	if grep -qF "reloading guis/assets/splash/launch." "$LOCAL_LOG"; then
		echo "PASS: the main menu's own GUI assets (guis/assets/splash/launch) were reached"
	else
		echo "FAIL: expected to see guis/assets/splash/launch reloaded in the log (the main menu's own splash background)"
		FAIL=1
	fi
fi

echo
if [ $FAIL -eq 0 ]; then
	echo "PASS: #30 menu smoke test - script compile passes, main menu loads, harness is green"
	exit 0
else
	echo "FAIL: #30 menu smoke test - see above"
	exit 1
fi
