#!/usr/bin/env bash
# Automated test for spec #38's acceptance criteria (decomp-so/reference/hud-map.md):
#   AC: after showMap, the dump shows full fog-of-war coverage
#
# Ported from decomp-so/reference/hud-map.md: idPlayer::Cmd_ShowMap_f and its registration as the
# "showMap" console command (idGameLocal::InitConsoleCommands, gamesys/SysCmds.cpp) - a real game
# command, not test-only harness plumbing (unlike chextrek_test_impulse/chextrek_test_map_cmd from
# #36/#37). "showMap [level]" memsets one level's (or, with no argument, every level's)
# hudmap_alpha image to 0xff and returns; the reference's own Notes call out that the change isn't
# uploaded to the render texture there - it "shows on screen at the next reveal
# (updateHudMapAlpha), and only for the level the player is on." That doesn't affect this scenario:
# chextrek_dump's `hud_map: level=<N> visible=<0|1> coverage=<N>` line (#36, ChexTrekDump.cpp)
# counts alpha-revealed texels straight out of hudmap_alpha itself, not the uploaded texture, so
# the full coverage left by showMap is visible in the dump immediately, with no wait for a reveal
# to re-run.
#
# No wiring gap needed: showMap is a self-contained console command (decomp-so/reference/
# hud-map.md's own Notes: "the registration's strings are read by the stock
# idGameLocal::InitConsoleCommands ... they were read from the disassembly"), not one of a stock
# function's edits-inside-stock-functions leads - so there is no "edit inside a stock function"
# lead to record here, unlike #36/#37.
#
# Scenario: on e1m1, a baseline chextrek_dump (standing at the spawn point, some but not all of
# the map already revealed by the initial wait - the same partial-coverage baseline #36's own
# scenario asserts) is followed by a plain "showMap" (no level argument, filling every level -
# e1m1 is level 0, the only one occupied) and a second chextrek_dump, which must show
# coverage=16384 (the full 128x128 fog-of-war image, spec #28's always-on "no ERROR" check plus
# this scenario's own count). A third dump after "showMap 0" (the single-level argument form)
# confirms that path too, still full.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRATCH_DIR="$(mktemp -d)"
trap 'rm -rf "$SCRATCH_DIR"' EXIT

echo "=== #38 showMap test: build ==="
if ! bash "${SCRIPT_DIR}/build-chextrek.sh"; then
	echo "FAIL: build-chextrek.sh failed"
	exit 1
fi

CONSOLE_SCRIPT="${SCRATCH_DIR}/show_map.cfg"
cat > "$CONSOLE_SCRIPT" <<'EOF'
developer 1
map e1m1
wait 20

chextrek_dump

showMap
wait 5
chextrek_dump

showMap 0
wait 5
chextrek_dump

screenshot chextrek_show_map
wait 10
quit
EOF

echo
echo "=== #38 showMap test: scenario run ==="
RUN_OUT="$(bash "${SCRIPT_DIR}/run-scenario.sh" chextrek_show_map "$CONSOLE_SCRIPT" 120 2>&1)"
RUN_EXIT=$?
echo "$RUN_OUT"

FAIL=0
if [ $RUN_EXIT -ne 0 ]; then
	echo "FAIL: expected the always-on harness checks to pass (chextrek.dll loaded, state-dump header, no ERROR/unknown-event/unknown-spawnclass/script-compile lines), but the run exited ${RUN_EXIT}"
	FAIL=1
fi

LOCAL_LOG="$(echo "$RUN_OUT" | sed -n 's/^CHEXTREK_LOCAL_LOG=//p')"
if [ -z "$LOCAL_LOG" ] || [ ! -f "$LOCAL_LOG" ]; then
	echo "FAIL: couldn't find the archived log to check scenario-specific assertions"
	exit 1
fi

# --- e1m1 finishes loading (spec #28 always-on check) ---
if grep -qE '^ *[0-9]+ msec to load e1m1$' "$LOCAL_LOG"; then
	echo "PASS: e1m1 finished loading"
else
	echo "FAIL: expected to see '<N> msec to load e1m1' in the log"
	FAIL=1
fi

# There are 3 chextrek_dump calls: baseline, after "showMap", after "showMap 0".
COVERAGE_VALUES="$(grep -oE '^hud_map: level=[0-9]+ visible=[01] coverage=[0-9]+$' "$LOCAL_LOG" | grep -oE 'coverage=[0-9]+' | grep -oE '[0-9]+$')"
C0="$(echo "$COVERAGE_VALUES" | sed -n '1p')"
C1="$(echo "$COVERAGE_VALUES" | sed -n '2p')"
C2="$(echo "$COVERAGE_VALUES" | sed -n '3p')"

FULL_COVERAGE=16384 # 128 x 128 fog-of-war texels

if [ -n "$C0" ] && [ "$C0" -gt 0 ] && [ "$C0" -lt "$FULL_COVERAGE" ]; then
	echo "PASS: baseline coverage is partial (${C0} of ${FULL_COVERAGE} texels), standing at the spawn point"
else
	echo "FAIL: expected a partial baseline coverage strictly between 0 and ${FULL_COVERAGE}, got '${C0}'"
	FAIL=1
fi

if [ -n "$C1" ] && [ "$C1" -eq "$FULL_COVERAGE" ]; then
	echo "PASS: showMap (no level argument) revealed full coverage (${C1} of ${FULL_COVERAGE} texels)"
else
	echo "FAIL: expected coverage=${FULL_COVERAGE} after showMap, got '${C1}'"
	FAIL=1
fi

if [ -n "$C2" ] && [ "$C2" -eq "$FULL_COVERAGE" ]; then
	echo "PASS: showMap 0 (single-level argument) still shows full coverage (${C2} of ${FULL_COVERAGE} texels)"
else
	echo "FAIL: expected coverage=${FULL_COVERAGE} after showMap 0, got '${C2}'"
	FAIL=1
fi

echo
if [ $FAIL -eq 0 ]; then
	echo "PASS: #38 showMap scenario - showMap reveals full fog-of-war coverage"
	exit 0
else
	echo "FAIL: #38 showMap scenario - see above"
	exit 1
fi
