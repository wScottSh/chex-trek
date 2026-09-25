#!/usr/bin/env bash
# Automated test for spec #37's acceptance criteria (decomp-so/reference/hud-map.md):
#   AC: each map_* command changes the map scale/position shown in the dump as expected
#
# Ported edit-inside-stock-function lead (Player.cpp): idPlayer::HandleSingleGuiCommand now
# recognizes the PDA map's GUI commands - map_zoom_in/map_zoom_out (OR in their mapControl bit),
# map_scroll_center (OR in MAP_CENTER), map_scroll_up/down/left/right (replace mapControl with
# their own bit - updateMapUI's scroll switch compares mapControl with ==, so scrolling only
# applies while no other bit is set), and map_stop (keeps MAP_CENTER only if a zoom bit was set
# alongside it, else clears mapControl to 0) - exactly as decomp-so/reference/hud-map.md's Notes
# describe (idPlayer::HandleSingleGuiCommand, 0x16d96e-0x16db5b). #36 already ported the consumer
# of these bits (updateMapUI, called every frame from updateMap/Think): zoom changes mapScale 1%
# per frame (0.1..9), scroll moves mapView 16 world units per frame (clamped to mapCoords), and
# center snaps mapView to the player's origin.
#
# These GUI commands only ever arrive, in the real game, from a mouse click on the PDA map's
# arrow/zoom/center buttons (guis/pda.gui, guis/pda_chex.gui) - the same class of gap
# chextrek_customui_cmd (#34) closed for the end-level stats screen's buttons. The new test-only
# `chextrek_test_map_cmd <command>` (ChexTrekDump.cpp/.h) closes it here: it calls the local
# player's own idEntity::HandleGuiCommands( player, cmd ) - the exact stock entry point a real GUI
# onAction reaches - so everything downstream is the real, already-ported game code, unchanged.
#
# Separately: idPlayer::updateMap only ever applies mapControl's bits to the PDA's own map page
# (as opposed to the always-centered HUD corner map) while the PDA is open AND the PDA gui's own
# "HudMap" state variable is true - a variable only a mouse click on guis/pda_chex.gui's "Data" tab
# sets in the real game (resetTime "hudmap_open" "0", which sets "gui::HudMap" "1" at its own
# onTime 5), not anything idPlayer's C++ (this sub-issue's scope) drives, and out of the
# console-only harness's reach the same way the map_* commands themselves are. The new test-only
# `chextrek_test_pda_map_open <0|1>` sets that same GUI state variable directly through
# idUserInterface::SetStateBool - the exact call that click's script action ultimately makes -
# without any new C++ decision logic. See both commands' comments in ChexTrekDump.h for the full
# rationale (the same "test-only console command standing in for mouse input" pattern as #34/#35/
# #36).
#
# The PDA itself needs to be open (idPlayer::objectiveSystemOpen) before any of this matters -
# reused verbatim from #35's tools/test-pda.sh: spawn+trigger a fresh item_pda, since neither e1m1
# nor sf_923 places one reachable from spawn, and idPlayer::GivePDA calls TogglePDA() itself on the
# player's first PDA (no impulse/mouse input needed).
#
# guis/pda_chex.gui quirk found while writing this scenario (GUI script only, not a #37 C++ gap):
# its "hudmap_close" window has no "notime 1" the way "hudmap_open" does, so its own onTime 400
# fires ~400ms after the PDA gui is created regardless of any resetTime call - it isn't gated on
# actually having entered the map page. In real play this is presumably masked by the player
# reaching the map page well after that initial 400ms (or by a resetTime this script doesn't show
# a caller for), but under console-driven control it means gui::HudMap flips back to 0 on its own
# well before a scenario's later map_* commands run. Rather than fight that GUI timing detail
# in C++ (out of #37's scope - #37 only ports the mapControl-setting side, not the PDA gui's own
# page-navigation script), this scenario just re-sends chextrek_test_pda_map_open 1 before each
# measured step, keeping the precondition true throughout - the test-only command is documented as
# setting the flag directly, and re-asserting it is no different from a real player staying on the
# map page.
#
# chextrek_dump's new `map_pda: scale=<f> view_x=<f> view_y=<f> control=<N>` line (ChexTrekDump.cpp)
# reads idPlayer::mapScale/mapView/mapControl directly, so this scenario can assert each map_*
# command changed the right value without depending on GUI rendering.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRATCH_DIR="$(mktemp -d)"
trap 'rm -rf "$SCRATCH_DIR"' EXIT

echo "=== #37 PDA map test: build ==="
if ! bash "${SCRIPT_DIR}/build-chextrek.sh"; then
	echo "FAIL: build-chextrek.sh failed"
	exit 1
fi

CONSOLE_SCRIPT="${SCRATCH_DIR}/pda_map.cfg"
cat > "$CONSOLE_SCRIPT" <<'EOF'
developer 1
map e1m1
wait 20

spawn item_pda name chextrek_pdamap_test
trigger chextrek_pdamap_test
wait 10

chextrek_test_pda_map_open 1
wait 5
chextrek_dump

chextrek_test_pda_map_open 1
chextrek_test_map_cmd map_zoom_in
wait 10
chextrek_test_pda_map_open 1
wait 10
chextrek_dump

chextrek_test_pda_map_open 1
chextrek_test_map_cmd map_stop
wait 5
chextrek_test_pda_map_open 1
chextrek_test_map_cmd map_zoom_out
wait 10
chextrek_test_pda_map_open 1
wait 10
chextrek_test_pda_map_open 1
wait 10
chextrek_dump

chextrek_test_pda_map_open 1
chextrek_test_map_cmd map_stop
wait 5
chextrek_test_pda_map_open 1
chextrek_test_map_cmd map_scroll_right
wait 10
chextrek_dump

chextrek_test_pda_map_open 1
chextrek_test_map_cmd map_stop
wait 5
chextrek_test_pda_map_open 1
chextrek_test_map_cmd map_scroll_up
wait 10
chextrek_dump

chextrek_test_pda_map_open 1
chextrek_test_map_cmd map_stop
wait 5
chextrek_test_pda_map_open 1
chextrek_test_map_cmd map_scroll_center
wait 5
chextrek_dump

screenshot chextrek_pda_map
wait 10
quit
EOF

echo
echo "=== #37 PDA map test: scenario run ==="
RUN_OUT="$(bash "${SCRIPT_DIR}/run-scenario.sh" chextrek_pda_map "$CONSOLE_SCRIPT" 120 2>&1)"
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

# There are 6 chextrek_dump calls: baseline (map open, before any map_* command), after zoom_in,
# after zoom_out, after scroll_right, after scroll_up, after scroll_center.
MAP_PDA_LINES="$(grep -oE '^map_pda: scale=[0-9.eE+-]+ view_x=[0-9.eE+-]+ view_y=[0-9.eE+-]+ control=[0-9-]+$' "$LOCAL_LOG")"
LINE_COUNT="$(echo "$MAP_PDA_LINES" | grep -c '^map_pda:' || true)"
if [ "$LINE_COUNT" -lt 6 ]; then
	echo "FAIL: expected 6 'map_pda:' dump lines, saw ${LINE_COUNT}"
	echo "$MAP_PDA_LINES"
	exit 1
fi

field() { # field <line-number> <field-name>
	echo "$MAP_PDA_LINES" | sed -n "${1}p" | grep -oE "${2}=[0-9.eE+-]+" | cut -d= -f2
}

SCALE0="$(field 1 scale)"; CONTROL0="$(field 1 control)"
SCALE1="$(field 2 scale)"; CONTROL1="$(field 2 control)"
SCALE2="$(field 3 scale)"; CONTROL2="$(field 3 control)"
VIEWX3="$(field 4 view_x)"; CONTROL3="$(field 4 control)"
VIEWY3="$(field 4 view_y)"
VIEWX4="$(field 5 view_x)"; VIEWY4="$(field 5 view_y)"; CONTROL4="$(field 5 control)"
VIEWX5="$(field 6 view_x)"; VIEWY5="$(field 6 view_y)"; CONTROL5="$(field 6 control)"

echo "scale0=$SCALE0 control0=$CONTROL0"
echo "scale1=$SCALE1 control1=$CONTROL1"
echo "scale2=$SCALE2 control2=$CONTROL2"
echo "viewx3=$VIEWX3 viewy3=$VIEWY3 control3=$CONTROL3"
echo "viewx4=$VIEWX4 viewy4=$VIEWY4 control4=$CONTROL4"
echo "viewx5=$VIEWX5 viewy5=$VIEWY5 control5=$CONTROL5"

gt() { awk -v a="$1" -v b="$2" 'BEGIN{exit !(a>b)}'; }
lt() { awk -v a="$1" -v b="$2" 'BEGIN{exit !(a<b)}'; }
ne() { awk -v a="$1" -v b="$2" 'BEGIN{exit !(a!=b)}'; }

# --- baseline: no map_* command sent yet ---
if [ "$CONTROL0" = "0" ]; then
	echo "PASS: mapControl starts at 0 (no map_* command sent yet)"
else
	echo "FAIL: expected control=0 at baseline, got ${CONTROL0}"
	FAIL=1
fi

# --- map_zoom_in: mapScale increases, MAP_ZOOM_IN bit (2) set ---
if gt "$SCALE1" "$SCALE0"; then
	echo "PASS: map_zoom_in increased mapScale (${SCALE0} -> ${SCALE1})"
else
	echo "FAIL: expected mapScale to grow after map_zoom_in, got ${SCALE0} -> ${SCALE1}"
	FAIL=1
fi
if [ "$CONTROL1" = "2" ]; then
	echo "PASS: map_zoom_in set mapControl to MAP_ZOOM_IN (2)"
else
	echo "FAIL: expected control=2 after map_zoom_in, got ${CONTROL1}"
	FAIL=1
fi

# --- map_zoom_out: mapScale decreases back down, MAP_ZOOM_OUT bit (4) set ---
if lt "$SCALE2" "$SCALE1"; then
	echo "PASS: map_zoom_out decreased mapScale (${SCALE1} -> ${SCALE2})"
else
	echo "FAIL: expected mapScale to shrink after map_zoom_out, got ${SCALE1} -> ${SCALE2}"
	FAIL=1
fi
if [ "$CONTROL2" = "4" ]; then
	echo "PASS: map_zoom_out set mapControl to MAP_ZOOM_OUT (4)"
else
	echo "FAIL: expected control=4 after map_zoom_out, got ${CONTROL2}"
	FAIL=1
fi

# --- map_scroll_right: mapView.x increases, MAP_SCROLL_RIGHT bit (64) set ---
if gt "$VIEWX3" "0"; then
	echo "PASS: map_scroll_right increased mapView.x from 0 (now ${VIEWX3})"
else
	echo "FAIL: expected mapView.x > 0 after map_scroll_right, got ${VIEWX3}"
	FAIL=1
fi
if [ "$CONTROL3" = "64" ]; then
	echo "PASS: map_scroll_right set mapControl to MAP_SCROLL_RIGHT (64)"
else
	echo "FAIL: expected control=64 after map_scroll_right, got ${CONTROL3}"
	FAIL=1
fi

# --- map_scroll_up: mapView.y increases, MAP_SCROLL_UP bit (8) set; scroll_right's x is untouched ---
if gt "$VIEWY4" "0"; then
	echo "PASS: map_scroll_up increased mapView.y from 0 (now ${VIEWY4})"
else
	echo "FAIL: expected mapView.y > 0 after map_scroll_up, got ${VIEWY4}"
	FAIL=1
fi
if [ "$CONTROL4" = "8" ]; then
	echo "PASS: map_scroll_up set mapControl to MAP_SCROLL_UP (8)"
else
	echo "FAIL: expected control=8 after map_scroll_up, got ${CONTROL4}"
	FAIL=1
fi
if [ "$VIEWX4" = "$VIEWX3" ]; then
	echo "PASS: map_scroll_up left mapView.x unchanged (${VIEWX3})"
else
	echo "FAIL: expected mapView.x to stay ${VIEWX3} during map_scroll_up, got ${VIEWX4}"
	FAIL=1
fi

# --- map_scroll_center: mapView snaps to the player's origin (MAP_CENTER bit 1 set), away from
# the small scroll-accumulated position ---
if [ "$CONTROL5" = "1" ]; then
	echo "PASS: map_scroll_center set mapControl to MAP_CENTER (1)"
else
	echo "FAIL: expected control=1 after map_scroll_center, got ${CONTROL5}"
	FAIL=1
fi
if ne "$VIEWX5" "$VIEWX4" || ne "$VIEWY5" "$VIEWY4"; then
	echo "PASS: map_scroll_center moved mapView away from the scrolled position (${VIEWX4},${VIEWY4} -> ${VIEWX5},${VIEWY5})"
else
	echo "FAIL: expected map_scroll_center to change mapView, stayed at (${VIEWX4},${VIEWY4})"
	FAIL=1
fi

echo
if [ $FAIL -eq 0 ]; then
	echo "PASS: #37 PDA map scenario - each map_* command changed the map scale/position as expected"
	exit 0
else
	echo "FAIL: #37 PDA map scenario - see above"
	exit 1
fi
