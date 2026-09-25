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
# the wrong line - each `chextrek_customui_cmd skip` would still be "handled", but on the wrong
# line, and the assertions below would need to catch that, not silently reinterpret it).
# g_statTicTime stays at its default (50ms). An earlier attempt overrode it (set to 1 right before
# `trigger`, then back to a huge value right after, all in the same command-buffer pass before any
# `wait`) to try to force the -1 -> 0 transition on a precise, timing-independent frame; that was
# reverted after it empirically left state stuck at -1 for the rest of the run every time it was
# tried, for a reason not tracked down (Cmd_Trigger_f's `ent->ProcessEvent(&EV_Activate, player)`
# runs synchronously, in the same frame as the `trigger` line itself - gamesys/SysCmds.cpp - so the
# override reaching Event_Activate before it ran isn't, on its own, an adequate explanation; treat
# that reasoning as unconfirmed if this is ever revisited). `wait 10` (~167ms of sim time) with the
# default 50ms tic was verified instead, empirically, across multiple consecutive full runs: it
# reliably leaves state at 0, part-way through (not yet finished) counting the monsters line - the
# fastest of the three percentage lines here to finish on its own (level_stats monsters 1/22 -> 4%,
# one percentage point per tic, so ~4 tics/~200ms to complete - comfortably above this wait's
# ~167ms). If a future map/setup ever makes that fastest line's target percentage 1% or less
# (needing only one tic), this wait would need shortening to match, and the ASSERTION_BELOW check
# would start failing loudly instead of silently mis-attributing which line each skip landed on.
# Four `chextrek_customui_cmd skip` calls are then chained back to back with no `wait` between them
# (each reads and mutates state instantly, in the same engine frame, so no naturally-scheduled tic
# - which only fires on a later frame boundary - can interleave and change the picture mid-sequence):
# one each for the monsters/items/secrets lines (state 0-2) and one for the level-time line
# (state 3). Each is checked against `chextrek_dump`'s own state (level_stats for the true
# found/total, customui_gui_* for what the screen now shows) rather than a hardcoded number, so the
# assertion holds regardless of the map's real monster/item/secret counts. Before sending any
# "skip", the scenario also asserts the *before* dump's `ai_percent` is strictly below its final
# value (ASSERTION_BELOW) - if natural counting had already finished the monsters line by then
# (the failure mode the wait margin above is meant to prevent), this catches it directly instead of
# letting every later "skip" quietly test the wrong line while still reporting PASS.
#
# --- AC2: "nextmap" (sf_923) ---
# What #34's AC actually needs: "nextmap" (the GUI command idTarget_EndLevelGUI::
# HandleCustomGUICommand handles) makes state 5's branch of Event_UpdateStats read the entity's own
# "nextmap" spawnArg and load that map (`gameLocal.sessionCommand = "map " + nextMap` - Target.cpp,
# ported #33). That is NOT sf_923's real, shipped end-of-level path to e1m1: neither of sf_923's own
# target_endlevelgui entities has a "nextmap" spawnArg set (decomp-so/reference/end-level-stats.md's
# Notes: "set on no target_endlevelgui in maps/"), and `maps/sf_923.map:35103-35106`'s actual
# "nextMap" "e1m1" key lives on `target_endlevel_3`, a plain stock `idTarget_EndLevel` entity that
# a separate script (`script/map_storage_facility.script`, reached from `target_endlevelgui_2`'s
# `end_trek.gui`, which `target_endlevelgui_1`'s own state 5 reaches only via `ActivateTargets`
# with no "nextmap" set) triggers - none of that chain is idTarget_EndLevelGUI's "nextmap" GUI
# command or anything #33/#34 ported; it's stock idTarget_EndLevel behavior plus a different GUI's
# "runScript" commands, out of both sub-issues' scope. Since no shipped map ever gives
# idTarget_EndLevelGUI's own "nextmap" spawnArg a value, this scenario spawns a fresh
# idTarget_EndLevelGUI entity that does (Cmd_Spawn_f supports extra key/value pairs after the
# classname, the same as any other spawnclass; "nextmap" is the entityDef's own documented var -
# def/endlevelgui.def: "the map name to transfer to") - the only way to exercise that specific,
# ported mechanism at all, and a direct reading of AC2's literal wording ("nextmap ... loads e1m1").
# Triggering it starts the screen; "nextmap" has no state guard in HandleCustomGUICommand (it
# always sets state = 5, even before the first tic), so it's sent right after triggering. The next
# tic (state 5's branch, Event_UpdateStats) then runs `gameLocal.sessionCommand = "map e1m1"` on
# its own, without any further console command - the harness only proves that map actually loads
# (the log's "<N> msec to load e1m1" line), the same evidence tools/test-script-events.sh and
# friends already use for a map finishing loading.
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

# There are 7 chextrek_dump calls in order: (1) baseline after map load, (2) after the kill/
# pickup/secret setup (the "final" level_stats values skip should reproduce), (3) right after
# triggering target_endlevelgui_1 (the untouched/just-started screen), (4)-(7) after each of the
# four "skip" calls (monsters, items, secrets, level time).
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

# Guard against the failure mode the wait-timing comment above describes: if natural counting had
# already finished the monsters line (state advanced past 0) by dump #3 - before any "skip" - every
# "skip" below would silently test the wrong line while still reporting PASS (each is still
# "handled", just for a different stat). Dump #3's ai_percent (occurrence 1, before any skip) must
# be strictly below the final target percent; if it isn't, that's caught here directly instead of
# masquerading as a pass below.
AI_PERCENT_BEFORE_SKIP="$(echo "$AI_PERCENT_VALUES" | sed -n '1p')"
if [ -n "$AI_PERCENT_BEFORE_SKIP" ] && [ "$AI_PERCENT_BEFORE_SKIP" -lt "$M_PERCENT_EXPECTED" ]; then
	echo "PASS: before any 'skip', the monsters line hadn't finished counting on its own yet (ai_percent=${AI_PERCENT_BEFORE_SKIP}%, final is ${M_PERCENT_EXPECTED}%) - the 'skip' calls below are exercising the line they're expected to"
else
	echo "FAIL: expected the monsters line to still be short of its final ${M_PERCENT_EXPECTED}% before any 'skip' (so the four 'skip' calls below land on the intended lines in order), got ai_percent='${AI_PERCENT_BEFORE_SKIP}' - the wait before the first 'skip' may need shortening"
	FAIL=1
fi

AI_KILLED_AFTER_SKIP="$(echo "$AI_KILLED_VALUES" | sed -n '2p')"
AI_PERCENT_AFTER_SKIP="$(echo "$AI_PERCENT_VALUES" | sed -n '2p')"
if [ "$AI_KILLED_AFTER_SKIP" = "$M_FOUND" ] && [ "$AI_PERCENT_AFTER_SKIP" = "$M_PERCENT_EXPECTED" ]; then
	echo "PASS: 'skip' jumped the monsters line straight to its final value (ai_killed=${AI_KILLED_AFTER_SKIP}, ai_percent=${AI_PERCENT_AFTER_SKIP}%, matching level_stats ${M_FOUND}/${M_TOTAL})"
else
	echo "FAIL: expected ai_killed=${M_FOUND} and ai_percent=${M_PERCENT_EXPECTED}% after the first 'skip', got ai_killed='${AI_KILLED_AFTER_SKIP}' ai_percent='${AI_PERCENT_AFTER_SKIP}'"
	FAIL=1
fi

# I_FOUND/S_FOUND > 0 is asserted explicitly (not just left implicit in the equality checks
# below): if the earlier pickup/secret-trigger setup silently failed to raise level_stats (a
# regression in #33's own code, not #34's), I_FOUND/S_FOUND would be "0", ITEMS_FOUND_AFTER_SKIP/
# SECRETS_FOUND_AFTER_SKIP would also read "0" (skip jumping to a level_stats value of 0 is still
# "jumping to the final value" mechanically), and the equality checks below would pass trivially
# without actually having exercised a nonzero jump.
if [ -n "$I_FOUND" ] && [ "$I_FOUND" -gt 0 ]; then
	echo "PASS: the item pickup actually raised level_stats' items-found above zero (${I_FOUND}/${I_TOTAL}) before 'skip' is asked to jump to it"
else
	echo "FAIL: expected level_stats items-found > 0 after #33's pickup setup, got '${I_FOUND}' - the 'skip' check below would pass trivially on 0"
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

if [ -n "$S_FOUND" ] && [ "$S_FOUND" -gt 0 ]; then
	echo "PASS: the secret door trigger actually raised level_stats' secrets-found above zero (${S_FOUND}/${S_TOTAL}) before 'skip' is asked to jump to it"
else
	echo "FAIL: expected level_stats secrets-found > 0 after #33's secret-door setup, got '${S_FOUND}' - the 'skip' check below would pass trivially on 0"
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
# (Event_Activate's own initial value, still showing in dump #3's occurrence). There's no separate
# dump line exposing stats[3].total in raw milliseconds to compare against exactly, so this checks
# the format and a sanity range instead of an exact value: given the console script's own `wait`
# budget up to this point (well under 2 real-time seconds of sim time), a real elapsed time here
# is on the order of 1-2 seconds, comfortably inside a generous [1ms, 30000ms) bound - the initial
# "00:00:000" (0ms) and any absurdly large value (e.g. a units bug) both fall outside it.
LEVEL_TIME_AFTER_SKIP="$(echo "$LEVEL_TIME_VALUES" | sed -n '5p')"
if echo "$LEVEL_TIME_AFTER_SKIP" | grep -qE '^[0-9]{2}:[0-9]{2}:[0-9]{3}$'; then
	LT_MIN="${LEVEL_TIME_AFTER_SKIP:0:2}"
	LT_SEC="${LEVEL_TIME_AFTER_SKIP:3:2}"
	LT_MS="${LEVEL_TIME_AFTER_SKIP:6:3}"
	LT_TOTAL_MS=$(( 10#$LT_MIN * 60000 + 10#$LT_SEC * 1000 + 10#$LT_MS ))
else
	LT_TOTAL_MS=-1
fi
if [ "$LT_TOTAL_MS" -gt 0 ] && [ "$LT_TOTAL_MS" -lt 30000 ]; then
	echo "PASS: 'skip' jumped the level-time line straight to its final formatted value (level_time=${LEVEL_TIME_AFTER_SKIP}, ${LT_TOTAL_MS}ms)"
else
	echo "FAIL: expected a real 'mm:ss:MMM' level_time between 1ms and 30000ms (not the initial '00:00:000', and not some implausibly large value) after the fourth 'skip', got '${LEVEL_TIME_AFTER_SKIP}'"
	FAIL=1
fi

# --- sf_923: AC2 ("nextmap" loads e1m1) ---
CONSOLE_SCRIPT2="${SCRATCH_DIR}/end-level-nextmap-nextmap-sf923.cfg"
cat > "$CONSOLE_SCRIPT2" <<'EOF'
developer 1
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

if grep -qF "chextrek_customui_cmd: 'nextmap' handled" "$LOCAL_LOG2"; then
	echo "PASS: chextrek_customui_cmd actually reached HandleCustomGUICommand with 'nextmap' (not just timed out into some other path)"
else
	echo "FAIL: expected \"chextrek_customui_cmd: 'nextmap' handled\" in the log - e1m1 loading below could otherwise be coincidental (e.g. a hung/late run reaching state 5 on its own after the 3s pause)"
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
