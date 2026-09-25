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
# No wiring gap needed: unlike #36/#37, showMap is a self-contained console command, not one of a
# stock function's edits-inside-stock-functions leads, so there is no such lead to record here.
#
# Scenario: on e1m1, a baseline chextrek_dump (standing at the spawn point, some but not all of
# the map already revealed by the initial wait - a partial, nonzero coverage, same as #36's own
# baseline) is followed by "showMap 1" (the single-level argument form, targeting level 1 - e1m1's
# own player is on level 0) and a second chextrek_dump, which must still show the same coverage as
# the baseline - proving the argument form doesn't spill onto the player's own level when given a
# different one (not a full proof that it fills only the level it names and nothing else - see
# below). A third dump, after a plain "showMap" (no level argument, filling every level), must
# show coverage=16384 (the full 128x128 fog-of-war image) for the player's own level - the AC this
# scenario exists to prove. chextrek_dump's `hud_map` line only ever reports the *current* level
# (idPlayer::HudMapLevel), so there's no way for this harness to directly inspect level 1's own
# coverage after "showMap 1" and confirm it, specifically, went to 16384 (a "showMap 1" that
# quietly did nothing at all would pass the same assertion) - the two assertions above (unaffected
# level 0, then full level 0 after the no-argument form) are what's actually observable, and are
# what's checked below.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRATCH_DIR="$(mktemp -d)"
trap 'rm -rf "$SCRATCH_DIR"' EXIT

# shellcheck source=tools/lib-harness.sh
source "${SCRIPT_DIR}/lib-harness.sh"

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

showMap 1
wait 5
chextrek_dump

showMap
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

# There are 3 chextrek_dump calls: baseline, after "showMap 1", after "showMap" (no argument).
COVERAGE_VALUES="$(chextrek_hud_map_coverage_values "$LOCAL_LOG")"
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

# showMap 1 targets a level the player isn't on (e1m1's player is on level 0), so the player's own
# level must be untouched - proving the single-level argument form doesn't spill onto every level.
if [ -n "$C1" ] && [ "$C1" -eq "$C0" ]; then
	echo "PASS: showMap 1 left the player's own level (0) coverage unchanged (${C1} of ${FULL_COVERAGE} texels)"
else
	echo "FAIL: expected showMap 1 to leave coverage at ${C0}, got '${C1}'"
	FAIL=1
fi

if [ -n "$C2" ] && [ "$C2" -eq "$FULL_COVERAGE" ]; then
	echo "PASS: showMap (no level argument) revealed full coverage (${C2} of ${FULL_COVERAGE} texels)"
else
	echo "FAIL: expected coverage=${FULL_COVERAGE} after showMap, got '${C2}'"
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
