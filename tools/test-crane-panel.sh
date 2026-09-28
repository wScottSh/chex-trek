#!/usr/bin/env bash
# Regression test for #50: clicking sf_923's crane panel (the in-world GUI near the Chex Quest
# intro TV) dropped the level. See docs/harness-coverage.md.
#
# The panel is `crane_panel` (maps/sf_923.map), gui guis/storage_facility/crane.gui. Its two arrow
# buttons' onAction scripts `runScript "gui::gui_parm7"` (left, first click), `"gui::gui_parm8"`
# (right, first click) and `"gui::gui_parm12"` (either arrow, second click), and the entity sets
# those parms to map_storage_facility::crane_left / crane_right / crane_stop. idEntity::
# HandleGuiCommands (Entity.cpp) turns a `runScript` whose function doesn't exist into
# gameLocal.Error( "Can't find function ..." ), which drops the level.
#
# The click itself (crosshair on the panel + attack button) isn't producible from a console script,
# so `chextrek_test_gui_click <entity> <x> <y>` (ChexTrekDump.cpp) stands in for it: it moves the
# panel gui's own cursor to (x, y) and sends a mouse-1 press/release through
# idUserInterface::HandleEvent, handing each returned command string to the local player's
# idEntity::HandleGuiCommands( crane_panel, command ) - the same calls idPlayer::UpdateFocus/
# Weapon_GUI make for a real click. So crane.gui's own window scripts pick which gui_parm to run
# and HandleGuiCommands' real runScript lookup runs it. Not covered: UpdateFocus's crosshair trace
# choosing the cursor point (the hook sets it explicitly), and the usercmd attack-button edge.
#
# Click points are the centers of crane.gui's TriggerButtonLeft (rect 21,227,150,241) and
# TriggerButtonRight (rect 296,227,151,240). crane.gui's "desktop::active" flag alternates the
# action, so left, left, right, right sends crane_left, crane_stop, crane_right, crane_stop.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRATCH_DIR="$(mktemp -d)"
trap 'rm -rf "$SCRATCH_DIR"' EXIT

# shellcheck source=tools/lib-harness.sh
source "${SCRIPT_DIR}/lib-harness.sh"

echo "=== #50 crane-panel test: build ==="
chextrek_build_or_exit

# The player is noclipped to stand in front of the panel, facing it (setviewpos, yaw 270 - the
# screen faces +Y), so the panel is on screen as for a real player. That matters: crane.gui's
# `Noclick` window covers the whole gui for 1000 ms of gui time after every arrow click, and a
# world gui's time only advances while the renderer draws it - off screen, only the first click
# ever lands (seen while writing this test). Each click is followed by `wait 1500` so well over
# 1000 ms of game time passes (~3-4 ms per wait tick on Unicron); the hook prints gameLocal.time
# and the gaps are checked below. `focus=1` in the hook's output is idPlayer::GuiActive(): the
# player's own crosshair trace (UpdateFocus) has a gui in focus, as it would for a real click.
#
# 50000 is printed before any click, 50999 after all four clicks and a settle wait (the runScript
# threads start on the next frame, DelayedStart( 0 )). `script` needs a running map, so 50999 plus
# the final dump's entity count show sf_923 is still loaded after the clicks.
CONSOLE_SCRIPT="${SCRATCH_DIR}/crane-panel.cfg"
cat > "$CONSOLE_SCRIPT" <<'EOF'
developer 1
map sf_923
wait 20
noclip
setviewpos -1048 2012 427 270
wait 30
chextrek_dump
script sys.println( 50000 )

chextrek_test_gui_click crane_panel 96 347
wait 1500
chextrek_test_gui_click crane_panel 96 347
wait 1500
chextrek_test_gui_click crane_panel 371 347
wait 1500
chextrek_test_gui_click crane_panel 371 347
wait 60

chextrek_dump
script sys.println( 50999 )
screenshot chextrek_crane_panel
wait 10
quit
EOF

echo
echo "=== #50 crane-panel test: scenario run ==="

FAIL=0
chextrek_run_scenario chextrek_crane_panel "$CONSOLE_SCRIPT" 180 || FAIL=1

LOCAL_LOG="$CHEXTREK_SCENARIO_LOG"
if [ -z "$LOCAL_LOG" ]; then
	echo "FAIL: couldn't find the archived log to check scenario-specific assertions"
	exit 1
fi

chextrek_assert_map_loaded "$LOCAL_LOG" sf_923 || FAIL=1

if grep -q '^50000$' "$LOCAL_LOG"; then
	echo "PASS: sf_923 running before the clicks (50000)"
else
	echo "FAIL: expected '50000' in the log before the clicks"
	FAIL=1
fi

# The runScript targets crane.gui actually sent, in order - proves the click reached the arrows'
# onAction and went through HandleGuiCommands' runScript path, not just that nothing happened.
SENT="$(grep -oE "^chextrek_test_gui_click: crane_panel [0-9]+ [0-9]+ (down|up) cmd='.*'$" "$LOCAL_LOG" \
	| grep -oE 'runScript [A-Za-z_:]+' | sed 's/^runScript //' | paste -sd' ' -)"
EXPECTED="map_storage_facility::crane_left map_storage_facility::crane_stop map_storage_facility::crane_right map_storage_facility::crane_stop"
if [ "$SENT" = "$EXPECTED" ]; then
	echo "PASS: the four clicks sent runScript ${EXPECTED}"
else
	echo "FAIL: expected the clicks to send runScript '${EXPECTED}', got '${SENT}'"
	FAIL=1
fi

DONE_LINES="$(grep -E '^chextrek_test_gui_click: done crane_panel [0-9]+ [0-9]+ map=maps/sf_923\.map time=[0-9]+ focus=[01]$' "$LOCAL_LOG")"
DONE_COUNT="$(printf '%s' "$DONE_LINES" | grep -c 'done')"
if [ "$DONE_COUNT" -eq 4 ]; then
	echo "PASS: HandleGuiCommands returned normally for all 4 clicks, still in sf_923"
else
	echo "FAIL: expected 4 completed clicks in sf_923, got ${DONE_COUNT}"
	FAIL=1
fi

FOCUS_VALUES="$(printf '%s\n' "$DONE_LINES" | grep -oE 'focus=[01]$' | sed 's/focus=//' | paste -sd' ' -)"
if [ "$FOCUS_VALUES" = "1 1 1 1" ]; then
	echo "PASS: the player's own crosshair had a gui in focus at every click (focus=1 x4)"
else
	echo "FAIL: expected focus=1 at all 4 clicks (player standing at the panel), got '${FOCUS_VALUES}'"
	FAIL=1
fi

# Informational: game time between clicks must exceed crane.gui's 1000 ms Noclick window, or a
# click is swallowed (it would show up above as a missing runScript).
CLICK_TIMES="$(printf '%s\n' "$DONE_LINES" | grep -oE 'time=[0-9]+' | sed 's/time=//' | paste -sd' ' -)"
echo "INFO: gameLocal.time at each click: ${CLICK_TIMES}"

MISSING="$(grep -F "Can't find function" "$LOCAL_LOG" | head -3)"
if [ -z "$MISSING" ]; then
	echo "PASS: no \"Can't find function\" error"
else
	echo "FAIL: a gui runScript target is missing:"
	echo "$MISSING"
	FAIL=1
fi

ENTITIES_AFTER="$(grep -oE '^entities: [0-9]+$' "$LOCAL_LOG" | grep -oE '[0-9]+$' | tail -1)"
if grep -q '^50999$' "$LOCAL_LOG" && [ -n "$ENTITIES_AFTER" ] && [ "$ENTITIES_AFTER" -gt 0 ]; then
	echo "PASS: sf_923 still running after the clicks (50999, entities=${ENTITIES_AFTER})"
else
	echo "FAIL: expected '50999' and a non-zero entity count after the clicks (level dropped?), got entities='${ENTITIES_AFTER}'"
	FAIL=1
fi

echo
if [ $FAIL -eq 0 ]; then
	echo "PASS: #50 crane-panel scenario - clicking both crane arrows keeps sf_923 running"
	exit 0
else
	echo "FAIL: #50 crane-panel scenario - see above"
	exit 1
fi
