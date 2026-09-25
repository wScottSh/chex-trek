#!/usr/bin/env bash
# Automated test for spec #34's acceptance criteria: on the stats screen, "skip" jumps the current
# line's counters straight to their final values, and "nextmap" loads the map named in the
# entity's "nextmap" spawnArg (idTarget_EndLevelGUI::HandleCustomGUICommand,
# decomp-so/reference/end-level-stats.md, ported by #33). See docs/harness-coverage.md.
#
# Both GUI commands only ever reach the game, in the real game, through a mouse click on
# guis/chex/stats.gui's "skip"/"nextmap" buttons (onAction -> idPlayer::Weapon_GUI's BUTTON_ATTACK
# handling -> idUserInterface::HandleEvent, engine-side). The AFK harness drives the game only
# through console commands (map, script, setviewpos, trigger, spawn, impulse, wait - spec #28), and
# positioning the GUI's cursor over a specific on-screen button needs real mouse-delta input
# (idPlayer::Think reads it from usercmd_t::mx/my), which none of those commands can produce. This
# is the same class of gap the state-dump command already exists to close (state/behavior the
# console's own commands can't observe or drive) - see ChexTrek_CustomUICmd_f's own header comment
# in ChexTrekDump.cpp for the full reasoning. `chextrek_customui_cmd <command>` (spec #34,
# registered by gamesys/SysCmds.cpp) supplies just the command string a click would have produced,
# then calls the exact same virtual method (idCustomUI::HandleCustomGUICommand) a real click
# reaches - everything downstream is the already-ported #33 code, unchanged.
#
# --- AC1: "skip" (e1m1) ---
# Reuses #33's e1m1 setup (spawn+radiusDamage a monster, spawn+pick up an item, trigger a secret
# door) so level_stats' monsters/items/secrets found/total are non-trivial (not 0/0, which would
# make "jumps to the final value" indistinguishable from "shows nothing").
#
# HandleCustomGUICommand's "skip" is a no-op while state is still -1 (idTarget_EndLevelGUI::
# Event_UpdateStats's very first tic, posted by Event_Activate, is what flips state from -1 to 0 -
# nothing else does), so this scenario needs that first tic to have fired, but not much more,
# before it starts sending "skip" (an already-*completed* line, i.e. one whose natural counting
# ran all the way to state++ before the scenario gets to it, would shift every later "skip" onto
# the wrong line). g_statTicTime stays at its default (50ms - overriding it was tried and found to
# race the opposite way: a `set` executed right after `trigger` in the same command-buffer pass,
# before any frame elapses, took effect before idTarget_EndLevelGUI::Event_Activate's own
# PostEventMS ever read it, since `trigger`'s EV_Activate itself doesn't run until the *next*
# server frame - so the override reached Event_Activate too, permanently freezing state at -1
# instead of letting it start). Instead, `wait 10` (~167ms of sim time) sits comfortably above the
# one 50ms tic needed to flip -1 -> 0, but well below the ~4 tics (~200ms) monsters' line here
# needs to finish counting on its own (level_stats monsters 1/22 -> 4%, one percentage point per
# tic) - the fastest of the three percentage lines to complete, so also the tightest margin. If a
# future map/setup ever makes that fastest line's target percentage 1% or less (needing only one
# tic), this wait would need shortening to match.
# Four `chextrek_customui_cmd skip` calls are then chained back to back with no `wait` between them
# (each reads and mutates state instantly, in the same engine frame, so no naturally-scheduled tic
# - which only fires on a later frame boundary - can interleave and change the picture mid-sequence):
# one each for the monsters/items/secrets lines (state 0-2) and one for the level-time line
# (state 3). Each is checked against `chextrek_dump`'s own state (level_stats for the true
# found/total, customui_gui_* for what the screen now shows) rather than a hardcoded number, so the
# assertion holds regardless of the map's real monster/item/secret counts.
#
# --- AC2: "nextmap" (sf_923) ---
# sf_923's own target_endlevelgui entities have no "nextmap" spawnArg (decomp-so/reference/
# end-level-stats.md's Notes: "set on no target_endlevelgui in maps/" - sf_923's own screens fall
# back to ActivateTargets instead), so this scenario spawns its own idTarget_EndLevelGUI entity
# with "nextmap" "e1m1" set (Cmd_Spawn_f supports extra key/value pairs after the classname, the
# same as any other spawnclass), matching the entityDef's own documented "nextmap" var
# (def/endlevelgui.def: "the map name to transfer to"). Triggering it starts the screen; "nextmap"
# has no state guard in HandleCustomGUICommand (it always sets state = 5, even before the first
# tic), so it's sent right after triggering. The next tic (state 5's branch, Event_UpdateStats)
# then runs `gameLocal.sessionCommand = "map e1m1"` on its own, without any further console command
# - the harness only proves that map actually loads (the log's "<N> msec to load e1m1" line), the
# same evidence tools/test-script-events.sh and friends already use for a map finishing loading.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRATCH_DIR="$(mktemp -d)"
trap 'rm -rf "$SCRATCH_DIR"' EXIT

echo "=== #34 end-level-nextmap test: build ==="
if ! bash "${SCRIPT_DIR}/build-chextrek.sh"; then
	echo "FAIL: build-chextrek.sh failed"
	exit 1
fi

FAIL=0

# --- e1m1: AC1 ("skip" jumps the current line's counters to their final values) ---
CONSOLE_SCRIPT="${SCRATCH_DIR}/end-level-nextmap-skip-e1m1.cfg"
cat > "$CONSOLE_SCRIPT" <<'EOF'
developer 1
map e1m1
wait 20
chextrek_dump

spawn monster_flemoid name chextrek_removeme
wait 10
script sys.radiusDamage( sys.getEntity( $chextrek_test_str4 ).getWorldOrigin(), sys.getEntity( $chextrek_test_str6 ), sys.getEntity( $chextrek_test_str6 ), sys.getEntity( $chextrek_test_str6 ), $chextrek_test_str9, 1 )
wait 10

spawn ammo_bullets_small name chextrek_item_test
wait 10
trigger chextrek_item_test
wait 10

trigger func_door_16
wait 10
chextrek_dump

trigger target_endlevelgui_1
wait 10
chextrek_dump

chextrek_customui_cmd skip
chextrek_dump
chextrek_customui_cmd skip
chextrek_dump
chextrek_customui_cmd skip
chextrek_dump
chextrek_customui_cmd skip
chextrek_dump

screenshot chextrek_end_level_skip_e1m1
wait 10
quit
EOF

echo
echo "=== #34 end-level-nextmap test: e1m1 'skip' scenario run ==="
RUN_OUT="$(bash "${SCRIPT_DIR}/run-scenario.sh" chextrek_end_level_skip_e1m1 "$CONSOLE_SCRIPT" 90 2>&1)"
RUN_EXIT=$?
echo "$RUN_OUT"

if [ $RUN_EXIT -ne 0 ]; then
	echo "FAIL: expected the always-on harness checks to pass (chextrek.dll loaded, state-dump header, no ERROR/unknown-event/unknown-spawnclass/script-compile lines), but the run exited ${RUN_EXIT}"
	FAIL=1
fi

LOCAL_LOG="$(echo "$RUN_OUT" | sed -n 's/^CHEXTREK_LOCAL_LOG=//p')"
if [ -z "$LOCAL_LOG" ] || [ ! -f "$LOCAL_LOG" ]; then
	echo "FAIL: couldn't find the archived log to check scenario-specific assertions"
	exit 1
fi

if grep -qE '^ *[0-9]+ msec to load e1m1$' "$LOCAL_LOG"; then
	echo "PASS: e1m1 finished loading"
else
	echo "FAIL: expected to see '<N> msec to load e1m1' in the log"
	FAIL=1
fi

# There are 6 chextrek_dump calls in order: (1) baseline after map load, (2) after the kill/
# pickup/secret setup (the "final" level_stats values skip should reproduce), (3) right after
# triggering target_endlevelgui_1 (the untouched/just-started screen), (4)-(6) after each of the
# first three "skip" calls (monsters, items, secrets). A 4th skip call (level time) follows (6)
# with no further dump index of its own reserved above; its dump is the 7th and last.
LEVEL_STATS_LINES="$(grep -oE '^level_stats: monsters=[0-9]+/[0-9]+ items=[0-9]+/[0-9]+ secrets=[0-9]+/[0-9]+$' "$LOCAL_LOG")"
MONSTERS_FOUND="$(echo "$LEVEL_STATS_LINES" | sed -n 's/^level_stats: monsters=\([0-9]*\)\/.*/\1/p')"
MONSTERS_TOTAL="$(echo "$LEVEL_STATS_LINES" | sed -n 's/^level_stats: monsters=[0-9]*\/\([0-9]*\).*/\1/p')"
ITEMS_FOUND="$(echo "$LEVEL_STATS_LINES" | sed -n 's/.*items=\([0-9]*\)\/.*/\1/p')"
ITEMS_TOTAL="$(echo "$LEVEL_STATS_LINES" | sed -n 's/.*items=[0-9]*\/\([0-9]*\).*/\1/p')"
SECRETS_FOUND="$(echo "$LEVEL_STATS_LINES" | sed -n 's/.*secrets=\([0-9]*\)\/.*/\1/p')"
SECRETS_TOTAL="$(echo "$LEVEL_STATS_LINES" | sed -n 's/.*secrets=[0-9]*\/\([0-9]*\).*/\1/p')"

# Final level_stats (dump #2, after the kill/pickup/secret setup - the last dump before the screen
# starts, so it's what "the final value" means for the rest of the run).
M_FOUND="$(echo "$MONSTERS_FOUND" | sed -n '2p')"
M_TOTAL="$(echo "$MONSTERS_TOTAL" | sed -n '2p')"
I_FOUND="$(echo "$ITEMS_FOUND" | sed -n '2p')"
I_TOTAL="$(echo "$ITEMS_TOTAL" | sed -n '2p')"
S_FOUND="$(echo "$SECRETS_FOUND" | sed -n '2p')"
S_TOTAL="$(echo "$SECRETS_TOTAL" | sed -n '2p')"

expected_percent() {
	# usage: expected_percent found total
	local found="$1" total="$2"
	if [ "$total" -eq 0 ]; then
		echo 100
	else
		echo $(( found * 100 / total ))
	fi
}

M_PERCENT_EXPECTED="$(expected_percent "$M_FOUND" "$M_TOTAL")"
I_PERCENT_EXPECTED="$(expected_percent "$I_FOUND" "$I_TOTAL")"
S_PERCENT_EXPECTED="$(expected_percent "$S_FOUND" "$S_TOTAL")"

# customui_gui_* values after each of the first three skip calls (dumps #4, #5, #6). Every dump
# from #3 (the screen just started) onward has a customui_gui_* section, so the Nth skip's effect
# first shows up at occurrence N+1 of each variable (occurrence 1 is dump #3, before any skip).
AI_KILLED_VALUES="$(grep -oE '^customui_gui_ai_killed: [0-9]+$' "$LOCAL_LOG" | grep -oE '[0-9]+$')"
AI_PERCENT_VALUES="$(grep -oE '^customui_gui_ai_percent: [0-9]+$' "$LOCAL_LOG" | grep -oE '[0-9]+$')"
ITEMS_FOUND_VALUES="$(grep -oE '^customui_gui_items_found: [0-9]+$' "$LOCAL_LOG" | grep -oE '[0-9]+$')"
ITEMS_PERCENT_VALUES="$(grep -oE '^customui_gui_items_percent: [0-9]+$' "$LOCAL_LOG" | grep -oE '[0-9]+$')"
SECRETS_FOUND_VALUES="$(grep -oE '^customui_gui_secrets_found: [0-9]+$' "$LOCAL_LOG" | grep -oE '[0-9]+$')"
SECRETS_PERCENT_VALUES="$(grep -oE '^customui_gui_secrets_percent: [0-9]+$' "$LOCAL_LOG" | grep -oE '[0-9]+$')"
LEVEL_TIME_VALUES="$(grep -oE '^customui_gui_level_time: .*$' "$LOCAL_LOG" | sed 's/^customui_gui_level_time: //')"

AI_KILLED_AFTER_SKIP="$(echo "$AI_KILLED_VALUES" | sed -n '2p')"
AI_PERCENT_AFTER_SKIP="$(echo "$AI_PERCENT_VALUES" | sed -n '2p')"
if [ "$AI_KILLED_AFTER_SKIP" = "$M_FOUND" ] && [ "$AI_PERCENT_AFTER_SKIP" = "$M_PERCENT_EXPECTED" ]; then
	echo "PASS: 'skip' jumped the monsters line straight to its final value (ai_killed=${AI_KILLED_AFTER_SKIP}, ai_percent=${AI_PERCENT_AFTER_SKIP}%, matching level_stats ${M_FOUND}/${M_TOTAL})"
else
	echo "FAIL: expected ai_killed=${M_FOUND} and ai_percent=${M_PERCENT_EXPECTED}% after the first 'skip', got ai_killed='${AI_KILLED_AFTER_SKIP}' ai_percent='${AI_PERCENT_AFTER_SKIP}'"
	FAIL=1
fi

ITEMS_FOUND_AFTER_SKIP="$(echo "$ITEMS_FOUND_VALUES" | sed -n '3p')"
ITEMS_PERCENT_AFTER_SKIP="$(echo "$ITEMS_PERCENT_VALUES" | sed -n '3p')"
if [ "$ITEMS_FOUND_AFTER_SKIP" = "$I_FOUND" ] && [ "$ITEMS_PERCENT_AFTER_SKIP" = "$I_PERCENT_EXPECTED" ]; then
	echo "PASS: 'skip' jumped the items line straight to its final value (items_found=${ITEMS_FOUND_AFTER_SKIP}, items_percent=${ITEMS_PERCENT_AFTER_SKIP}%, matching level_stats ${I_FOUND}/${I_TOTAL})"
else
	echo "FAIL: expected items_found=${I_FOUND} and items_percent=${I_PERCENT_EXPECTED}% after the second 'skip', got items_found='${ITEMS_FOUND_AFTER_SKIP}' items_percent='${ITEMS_PERCENT_AFTER_SKIP}'"
	FAIL=1
fi

SECRETS_FOUND_AFTER_SKIP="$(echo "$SECRETS_FOUND_VALUES" | sed -n '4p')"
SECRETS_PERCENT_AFTER_SKIP="$(echo "$SECRETS_PERCENT_VALUES" | sed -n '4p')"
if [ "$SECRETS_FOUND_AFTER_SKIP" = "$S_FOUND" ] && [ "$SECRETS_PERCENT_AFTER_SKIP" = "$S_PERCENT_EXPECTED" ]; then
	echo "PASS: 'skip' jumped the secrets line straight to its final value (secrets_found=${SECRETS_FOUND_AFTER_SKIP}, secrets_percent=${SECRETS_PERCENT_AFTER_SKIP}%, matching level_stats ${S_FOUND}/${S_TOTAL})"
else
	echo "FAIL: expected secrets_found=${S_FOUND} and secrets_percent=${S_PERCENT_EXPECTED}% after the third 'skip', got secrets_found='${SECRETS_FOUND_AFTER_SKIP}' secrets_percent='${SECRETS_PERCENT_AFTER_SKIP}'"
	FAIL=1
fi

# The 4th skip call (state 3, level time) sets the GUI's level_time state string to
# idStr::FormatTime( "mm:ss:MMM", stats[3].total ) - the level's real elapsed time, not "00:00:000"
# (Event_Activate's own initial value, still showing in dump #3's occurrence).
LEVEL_TIME_AFTER_SKIP="$(echo "$LEVEL_TIME_VALUES" | sed -n '5p')"
if echo "$LEVEL_TIME_AFTER_SKIP" | grep -qE '^[0-9]{2}:[0-9]{2}:[0-9]{3}$' && [ "$LEVEL_TIME_AFTER_SKIP" != "00:00:000" ]; then
	echo "PASS: 'skip' jumped the level-time line straight to its final formatted value (level_time=${LEVEL_TIME_AFTER_SKIP})"
else
	echo "FAIL: expected a real 'mm:ss:MMM' level_time (not the initial '00:00:000') after the fourth 'skip', got '${LEVEL_TIME_AFTER_SKIP}'"
	FAIL=1
fi

# --- sf_923: AC2 ("nextmap" loads e1m1) ---
CONSOLE_SCRIPT2="${SCRATCH_DIR}/end-level-nextmap-nextmap-sf923.cfg"
cat > "$CONSOLE_SCRIPT2" <<'EOF'
developer 1
set g_statTicTime 50
map sf_923
wait 20
chextrek_dump

spawn target_endlevelgui name chextrek_nextmap_test gui guis/chex/stats.gui mapname chextrek_test nextmap e1m1
wait 5

trigger chextrek_nextmap_test
chextrek_customui_cmd nextmap
wait 20
chextrek_dump

screenshot chextrek_end_level_nextmap_sf923
wait 10
quit
EOF

echo
echo "=== #34 end-level-nextmap test: sf_923 'nextmap' scenario run ==="
RUN_OUT2="$(bash "${SCRIPT_DIR}/run-scenario.sh" chextrek_end_level_nextmap_sf923 "$CONSOLE_SCRIPT2" 90 2>&1)"
RUN_EXIT2=$?
echo "$RUN_OUT2"

if [ $RUN_EXIT2 -ne 0 ]; then
	echo "FAIL: expected the always-on harness checks to pass (chextrek.dll loaded, state-dump header, no ERROR/unknown-event/unknown-spawnclass/script-compile lines), but the run exited ${RUN_EXIT2}"
	FAIL=1
fi

LOCAL_LOG2="$(echo "$RUN_OUT2" | sed -n 's/^CHEXTREK_LOCAL_LOG=//p')"
if [ -z "$LOCAL_LOG2" ] || [ ! -f "$LOCAL_LOG2" ]; then
	echo "FAIL: couldn't find the archived log to check scenario-specific assertions"
	exit 1
fi

if grep -qE '^ *[0-9]+ msec to load sf_923$' "$LOCAL_LOG2"; then
	echo "PASS: sf_923 finished loading"
else
	echo "FAIL: expected to see '<N> msec to load sf_923' in the log"
	FAIL=1
fi

if grep -qE '^ *[0-9]+ msec to load e1m1$' "$LOCAL_LOG2"; then
	echo "PASS: 'nextmap' from sf_923's stats screen loaded e1m1"
else
	echo "FAIL: expected to see '<N> msec to load e1m1' in the log after sending 'nextmap' to the stats screen"
	FAIL=1
fi

echo
if [ $FAIL -eq 0 ]; then
	echo "PASS: #34 end-level-nextmap scenario - 'skip' jumps to final values, 'nextmap' loads the next map"
	exit 0
else
	echo "FAIL: #34 end-level-nextmap scenario - see above"
	exit 1
fi
