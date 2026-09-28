#!/usr/bin/env bash
# Regression test for #51/#52 (PR #53): the end-level stats screen is drawn full screen, the
# player can't switch weapons while it's up, and once it finishes it rolls the FarceWare credits
# through to their endGame.
#
# #33's tests passed without the screen ever being drawn: the stats screen's counting runs as
# posted events whatever is on screen, and every earlier check read GUI state from chextrek_dump.
# What was missing was idPlayerView::SingleView's customUI draw (decomp-so/reference/custom-ui.md,
# 0x1764c6-0x1764e9). chextrek_dump's `customui_draw_count` (ChexTrek_NoteCustomUIDrawn, called
# from that draw) is the assertable proof the draw ran; each run's screenshots are archived as
# artifacts (never asserted on - spec #28), for a human to look at: chextrek_end_level_draw_stats
# should show the stats screen, not the frozen world.
#
# Run 1 (e1m1): fires the exit monitor's three targets the way its GUI does (func_static_1:
# target_endlevelgui_1, target_setinfluence_1, func_remove_1), screenshots the stats screen at the
# default g_statTicTime, then speeds the count up (g_statTicTime 1) and time (timescale) so the
# screen finishes on its own: state 5 unregisters it and fires its target, trigger_credits
# (func_cameraview_3 + the credits GUI, chex_credits.gui), which plays to its "endGame"
# (onTime 87000).
#
# Run 2 (e1m1): the weapon lock (idPlayer::SelectWeapon, 0x161374). With only the stats screen up
# (no target_setinfluence, which doesn't block weapon switching either way), a weapon impulse
# (chextrek_test_impulse, the stand-in for a held bind key) must not change the player's weapon;
# the same impulse before the screen is up does.
#
# Not covered: the view-angle and movement locks (UpdateViewAngles, Think, ClientPredictionThink).
# A console script can't produce mouse or movement input, and in e1m1's real exit
# target_setinfluence_1 (influence level 2) already blocks both.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRATCH_DIR="$(mktemp -d)"
trap 'rm -rf "$SCRATCH_DIR"' EXIT

# shellcheck source=tools/lib-harness.sh
source "${SCRIPT_DIR}/lib-harness.sh"

echo "=== #51/#52 end-level-draw test: build ==="
chextrek_build_or_exit

FAIL=0

CONSOLE_SCRIPT="${SCRATCH_DIR}/end-level-draw.cfg"
cat > "$CONSOLE_SCRIPT" <<'EOF'
developer 1
set g_nightmare 0
map e1m1
wait 20
chextrek_dump

trigger target_endlevelgui_1
trigger target_setinfluence_1
trigger func_remove_1
wait 30
chextrek_dump
screenshot chextrek_end_level_draw_stats
wait 5

set g_statTicTime 1
set timescale 10
wait 600
set timescale 1
chextrek_dump
screenshot chextrek_end_level_draw_credits
wait 5

set timescale 10
wait 9000
set timescale 1
wait 20
g_nightmare
chextrek_dump
screenshot chextrek_end_level_draw_after_credits
wait 10
quit
EOF

echo
echo "=== #51/#52 end-level-draw test: e1m1 exit -> stats screen -> credits run ==="
chextrek_run_scenario chextrek_end_level_draw "$CONSOLE_SCRIPT" 300 || FAIL=1

LOCAL_LOG="$CHEXTREK_SCENARIO_LOG"
if [ -z "$LOCAL_LOG" ]; then
	echo "FAIL: couldn't find the archived log to check scenario-specific assertions"
	exit 1
fi
chextrek_assert_map_loaded "$LOCAL_LOG" e1m1 || FAIL=1

# Four dumps: (1) baseline, (2) stats screen up, (3) after it finished, (4) after the credits.
CUSTOMUI="$(chextrek_line_field_values "$LOCAL_LOG" customui)"
DRAWS="$(chextrek_line_field_values "$LOCAL_LOG" customui_draw_count)"
CAMERA="$(chextrek_line_field_values "$LOCAL_LOG" camera)"

DRAWS_BEFORE="$(echo "$DRAWS" | sed -n '1p')"
DRAWS_UP="$(echo "$DRAWS" | sed -n '2p')"
if [ "$(echo "$CUSTOMUI" | sed -n '2p')" = "active" ] && [ -n "$DRAWS_BEFORE" ] && [ -n "$DRAWS_UP" ] && [ "$DRAWS_UP" -gt "$DRAWS_BEFORE" ]; then
	echo "PASS: the stats screen is drawn full screen while it's up (customui_draw_count ${DRAWS_BEFORE} -> ${DRAWS_UP}; see the chextrek_end_level_draw_stats screenshot)"
else
	echo "FAIL: expected customui 'active' and customui_draw_count to rise while the stats screen is up, got '$(echo "$CUSTOMUI" | sed -n '2p')', '${DRAWS_BEFORE}' -> '${DRAWS_UP}'"
	FAIL=1
fi

if [ "$(echo "$CUSTOMUI" | sed -n '3p')" = "none" ] && [ "$(echo "$CAMERA" | sed -n '3p')" = "func_cameraview_3" ]; then
	echo "PASS: the finished stats screen closed itself and fired trigger_credits (camera func_cameraview_3; see chextrek_end_level_draw_credits)"
else
	echo "FAIL: expected customui 'none' and camera 'func_cameraview_3' once the stats screen finished, got '$(echo "$CUSTOMUI" | sed -n '3p')', '$(echo "$CAMERA" | sed -n '3p')'"
	FAIL=1
fi

# chex_credits.gui's last timeline event (onTime 87000) is "endGame", which sets g_nightmare and
# appends "disconnect" to the command buffer. That disconnect lands behind the rest of this console
# script (its own waits and the final quit), so it never gets to run here; g_nightmare flipping to 1
# is the observable proof the credits played to the end and ran endGame.
if grep -qE '^"g_nightmare" is:"1"' "$LOCAL_LOG"; then
	echo "PASS: the credits played to the end and ran endGame (g_nightmare is 1; see chextrek_end_level_draw_after_credits)"
else
	echo "FAIL: expected the credits' endGame to set g_nightmare 1, got: $(grep -E '^"g_nightmare"' "$LOCAL_LOG" | tail -1)"
	FAIL=1
fi

# --- run 2: weapon lock ---
CONSOLE_SCRIPT_WEAPON="${SCRATCH_DIR}/end-level-draw-weapon.cfg"
cat > "$CONSOLE_SCRIPT_WEAPON" <<'EOF'
developer 1
map e1m1
wait 20
give all
wait 20
chextrek_test_impulse 1
wait 30
chextrek_dump

chextrek_test_impulse 2
wait 30
chextrek_dump

trigger target_endlevelgui_1
wait 10
chextrek_test_impulse 1
wait 30
chextrek_dump
wait 5
quit
EOF

echo
echo "=== #51/#52 end-level-draw test: e1m1 weapon-lock run ==="
chextrek_run_scenario chextrek_end_level_draw_weapon "$CONSOLE_SCRIPT_WEAPON" 90 || FAIL=1
LOCAL_LOG_WEAPON="$CHEXTREK_SCENARIO_LOG"
if [ -z "$LOCAL_LOG_WEAPON" ]; then
	echo "FAIL: couldn't find the archived weapon-lock log"
	exit 1
fi

WEAPONS="$(chextrek_line_field_values "$LOCAL_LOG_WEAPON" player_weapon)"
W1="$(echo "$WEAPONS" | sed -n '1p')"
W2="$(echo "$WEAPONS" | sed -n '2p')"
W3="$(echo "$WEAPONS" | sed -n '3p')"
UI3="$(chextrek_line_field_values "$LOCAL_LOG_WEAPON" customui | sed -n '3p')"
if [ -n "$W1" ] && [ -n "$W2" ] && [ "$W1" != "$W2" ]; then
	echo "PASS: with no stats screen up, a weapon impulse switches weapons ('${W1}' -> '${W2}')"
else
	echo "FAIL: expected a weapon impulse to switch weapons with no stats screen up, got '${W1}' -> '${W2}'"
	FAIL=1
fi
if [ "$UI3" = "active" ] && [ -n "$W3" ] && [ "$W3" = "$W2" ]; then
	echo "PASS: with the stats screen up, a weapon impulse doesn't switch weapons (stays '${W3}')"
else
	echo "FAIL: expected no weapon switch with the stats screen up (customui 'active', weapon '${W2}'), got '${UI3}', '${W3}'"
	FAIL=1
fi

echo
if [ $FAIL -eq 0 ]; then
	echo "PASS: #51/#52 end-level-draw scenario - the stats screen is drawn, locks weapon switching, and plays the credits to their endGame"
	exit 0
else
	echo "FAIL: #51/#52 end-level-draw scenario - see above"
	exit 1
fi
