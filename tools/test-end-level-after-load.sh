#!/usr/bin/env bash
# Regression test for #52 (fixed by PR #56): the end-level stats screen still counts after a
# savegame load. idPlayer::Save/Restore used to skip idPlayer::levelStats, and a load never runs
# idPlayer::Spawn, so a loaded game's levelStats kept the constructor's zeroes: every total and
# found count 0 and NULL GUI variable names. idTarget_EndLevelGUI then set none of the screen's
# counters (idDict::Set drops a NULL key) and the level time came out as all of gameLocal.time.
# See decomp-so/reference/end-level-stats.md's Notes and docs/harness-coverage.md.
#
# On e1m1: pick up a level_item and open the secret func_door_16 (the same pattern as
# tools/test-end-level-stats.sh), save, load, then trigger target_endlevelgui_1 and "skip" each
# of its 4 lines to the final value (tools/test-end-level-nextmap.sh's pattern - deterministic,
# no racing the tic animation). Asserts:
#   1. level_stats after the load equals level_stats before the save (totals and found counts).
#   2. the stats screen's own GUI state (customui_gui_*) shows those counts and percents.
#   3. customui_gui_level_time is a real mm:ss:MMM time, shorter than this run could have lasted.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRATCH_DIR="$(mktemp -d)"
trap 'rm -rf "$SCRATCH_DIR"' EXIT

# shellcheck source=tools/lib-harness.sh
source "${SCRIPT_DIR}/lib-harness.sh"

echo "=== #52 end-level-after-load test: build ==="
chextrek_build_or_exit

FAIL=0

# Same post-load margin as tools/test-objectives.sh (Wine/llvmpipe frames advance game time
# slower than the Windows dev machine's).
POST_LOAD_WAIT=150
chextrek_is_linux && POST_LOAD_WAIT=600
PRE_SKIP_WAIT=10
chextrek_is_linux && PRE_SKIP_WAIT=40

CONSOLE_SCRIPT="${SCRATCH_DIR}/end-level-after-load.cfg"
cat > "$CONSOLE_SCRIPT" <<EOF
developer 1
map e1m1
wait 20

spawn ammo_bullets_small name chextrek_item_test
wait 10
trigger chextrek_item_test
wait 10
trigger func_door_16
wait 10
chextrek_dump

savegame chextrek_end_level_after_load
wait 20
loadgame chextrek_end_level_after_load
wait ${POST_LOAD_WAIT}
chextrek_dump

trigger target_endlevelgui_1
wait ${PRE_SKIP_WAIT}
chextrek_test_customui_cmd skip
chextrek_test_customui_cmd skip
chextrek_test_customui_cmd skip
chextrek_test_customui_cmd skip
chextrek_dump

screenshot chextrek_end_level_after_load
wait 10
quit
EOF

echo
echo "=== #52 end-level-after-load test: e1m1 save/load scenario run ==="
chextrek_run_scenario chextrek_end_level_after_load "$CONSOLE_SCRIPT" 150 || FAIL=1

LOCAL_LOG="$CHEXTREK_SCENARIO_LOG"
if [ -z "$LOCAL_LOG" ]; then
	echo "FAIL: couldn't find the archived log to check scenario-specific assertions"
	exit 1
fi

chextrek_assert_map_loaded "$LOCAL_LOG" e1m1 || FAIL=1

# Three chextrek_dump calls: (1) before the save, (2) after the load, (3) after the 4 skips.
# Read by dump position (a bare header can be flushed early during a map load - see
# docs/harness-coverage.md's harness facts).
LEVEL_STATS="$(chextrek_line_field_values "$LOCAL_LOG" level_stats)"
STATS_BEFORE="$(echo "$LEVEL_STATS" | sed -n '1p')"
STATS_AFTER="$(echo "$LEVEL_STATS" | sed -n '2p')"
STATS_FINAL="$(echo "$LEVEL_STATS" | sed -n '3p')"

if echo "$STATS_BEFORE" | grep -qE '^monsters=[0-9]+/[1-9][0-9]* items=[1-9][0-9]*/[1-9][0-9]* secrets=[1-9][0-9]*/[1-9][0-9]*$'; then
	echo "PASS: before the save, level_stats has real totals and the pickup/secret counted (${STATS_BEFORE})"
else
	echo "FAIL: expected non-zero totals and items/secrets found before the save, got '${STATS_BEFORE}'"
	FAIL=1
fi

if [ -n "$STATS_BEFORE" ] && [ "$STATS_AFTER" = "$STATS_BEFORE" ] && [ "$STATS_FINAL" = "$STATS_BEFORE" ]; then
	echo "PASS: level_stats survives the save/load unchanged (${STATS_AFTER})"
else
	echo "FAIL: expected level_stats '${STATS_BEFORE}' after the load, got '${STATS_AFTER}' (and '${STATS_FINAL}' at the stats screen)"
	FAIL=1
fi

parse_stat() {
	# usage: parse_stat "<level_stats value>" <monsters|items|secrets> <found|total>
	local re='s/.*'"$2"'=\([0-9]*\)\/\([0-9]*\).*/'
	if [ "$3" = found ]; then re="${re}\\1/p"; else re="${re}\\2/p"; fi
	echo "$1" | sed -n "$re"
}

expected_percent() {
	# usage: expected_percent found total (idTarget_EndLevelGUI's "skip": 100 when total is 0)
	if [ -z "$2" ] || [ "$2" -eq 0 ]; then echo 100; else echo $(( $1 * 100 / $2 )); fi
}

gui_value() {
	# The stats screen's own GUI state from the third dump (the only one with the screen up).
	chextrek_line_field_values "$LOCAL_LOG" "customui_gui_$1" | tail -1
}

CUSTOMUI_STATE="$(chextrek_line_field_values "$LOCAL_LOG" customui | sed -n '3p')"
if [ "$CUSTOMUI_STATE" = "active" ]; then
	echo "PASS: target_endlevelgui_1's stats screen is up after the load"
else
	echo "FAIL: expected the third dump's customui 'active', got '${CUSTOMUI_STATE}'"
	FAIL=1
fi

for line in "monsters ai_killed ai_percent" "items items_found items_percent" "secrets secrets_found secrets_percent"; do
	set -- $line
	FOUND="$(parse_stat "$STATS_BEFORE" "$1" found)"
	TOTAL="$(parse_stat "$STATS_BEFORE" "$1" total)"
	PERCENT="$(expected_percent "${FOUND:-0}" "$TOTAL")"
	GOT_FOUND="$(gui_value "$2")"
	GOT_PERCENT="$(gui_value "$3")"
	if [ -n "$FOUND" ] && [ "$GOT_FOUND" = "$FOUND" ] && [ "$GOT_PERCENT" = "$PERCENT" ]; then
		echo "PASS: the stats screen shows ${1} ${GOT_FOUND} (${GOT_PERCENT}%) after the load, matching the pre-save ${FOUND}/${TOTAL}"
	else
		echo "FAIL: expected the stats screen's ${2}/${3} to be '${FOUND}'/'${PERCENT}' after the load, got '${GOT_FOUND}'/'${GOT_PERCENT}'"
		FAIL=1
	fi
done

# levelStats[3].total is the level's start time until the screen turns it into the time the level
# took. Lost on a load, that start time was 0, and the level time came out as all of
# gameLocal.time - and with the NULL "level_time" variable name the screen never showed it at all.
# 150s is the run's own timeout, so a real level time here can't be longer.
LEVEL_TIME="$(gui_value level_time)"
if echo "$LEVEL_TIME" | grep -qE '^[0-9]{2}:[0-9]{2}:[0-9]{3}$'; then
	LT_MS=$(( 10#${LEVEL_TIME:0:2} * 60000 + 10#${LEVEL_TIME:3:2} * 1000 + 10#${LEVEL_TIME:6:3} ))
	if [ "$LT_MS" -gt 0 ] && [ "$LT_MS" -lt 150000 ]; then
		echo "PASS: the stats screen shows a real level time after the load (${LEVEL_TIME})"
	else
		echo "FAIL: expected a level time between 0 and 150s after the load, got '${LEVEL_TIME}'"
		FAIL=1
	fi
else
	echo "FAIL: expected customui_gui_level_time as mm:ss:MMM after the load, got '${LEVEL_TIME}'"
	FAIL=1
fi

echo
if [ $FAIL -eq 0 ]; then
	echo "PASS: #52 end-level-after-load scenario - levelStats survives a save/load and the stats screen counts it"
	exit 0
else
	echo "FAIL: #52 end-level-after-load scenario - see above"
	exit 1
fi
