#!/usr/bin/env bash
# Automated test for spec #29 (the tracer bullet). Builds chextrek.dll and runs the harness, then
# checks the harness reported exactly what #29's acceptance criteria expect *right now*, before
# #30 ports the mod's script events:
#
#   - chextrek.dll (not base.dll) loaded
#   - the state-dump header ("CHEXTREK-STATE-DUMP v1") is in the log
#   - the run is red, specifically because of the known script\chex_events.script line 2 "Unknown
#     event 'openDoors'" failure - not some other, unrelated error
#   - the harness had to kill the game after the timeout (an error dialog hung it)
#
# This is a point-in-time test for #29's tracer bullet only. Once #30 ports the script events,
# this scenario's expected result flips to green; #30 (or whichever sub-issue lands after it)
# should replace this script's expectations accordingly rather than leaving it asserting red
# forever - see docs/harness-coverage.md.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "=== #29 tracer-bullet test: build ==="
if ! bash "${SCRIPT_DIR}/build-chextrek.sh"; then
	echo "FAIL: build-chextrek.sh failed"
	exit 1
fi

echo
echo "=== #29 tracer-bullet test: harness run ==="
HARNESS_OUT="$(bash "${SCRIPT_DIR}/run-harness.sh" 60 2>&1)"
HARNESS_EXIT=$?
echo "$HARNESS_OUT"

FAIL=0

if [ $HARNESS_EXIT -eq 0 ]; then
	echo "FAIL: expected the harness to report red (known script-compile failure still unfixed until #30), but it exited 0"
	FAIL=1
fi

if ! echo "$HARNESS_OUT" | grep -qF "==> Timed out"; then
	echo "FAIL: expected the harness to report a timeout kill (the error dialog hanging the game)"
	FAIL=1
fi

if ! echo "$HARNESS_OUT" | grep -qF "PASS: chextrek.dll loaded (not base.dll)"; then
	echo "FAIL: expected chextrek.dll (not base.dll) to have loaded"
	FAIL=1
fi

if ! echo "$HARNESS_OUT" | grep -qF "PASS: state-dump header present"; then
	echo "FAIL: expected the CHEXTREK-STATE-DUMP v1 header to be present"
	FAIL=1
fi

# The red reason must be the known failure, not some other regression. The engine's log write can
# truncate the line mid-word when killed (see docs/dev-setup.md), so match a safely-short prefix.
ARTIFACT_DIR="$(ls -td "${REPO_ROOT}/.harness-artifacts"/*/ 2>/dev/null | head -1)"
if [ -z "$ARTIFACT_DIR" ] || ! grep -qE "ERROR: Error: fi" "${ARTIFACT_DIR}dhewm3log.txt" 2>/dev/null; then
	echo "FAIL: expected the log to report the known chex_events.script compile failure"
	FAIL=1
fi

echo
if [ $FAIL -eq 0 ]; then
	echo "PASS: #29 tracer bullet behaves as expected (red on the known failure, dll+header proven)"
	exit 0
else
	echo "FAIL: #29 tracer bullet did not behave as expected - see above"
	exit 1
fi
