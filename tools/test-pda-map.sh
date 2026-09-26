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
# This scenario exercises all eight map_* commands (not just a subset): both zooms, all four
# scrolls, scroll_center, and map_stop in both its branches (clearing mapControl to 0 when no zoom
# bit is set alongside MAP_CENTER, and keeping MAP_CENTER when one is).
#
# These GUI commands only ever arrive, in the real game, from a mouse click on the PDA map's
# arrow/zoom/center buttons (guis/pda.gui, guis/pda_chex.gui) - the same class of gap
# chextrek_test_customui_cmd (#34) closed for the end-level stats screen's buttons. The new test-only
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
# idUserInterface::SetStateBool - the same underlying engine call the GUI script's own
# `set "gui::HudMap" "1"` resolves to (not literally the same call site: the real click goes
# through the window-script interpreter, this calls SetStateBool directly) - without any new C++
# decision logic. See both commands' comments in ChexTrekDump.h for the full
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
# fires once, flipping gui::HudMap back to 0 on its own, regardless of whether the map page was
# ever entered; the only other callers that reset that window's timeline
# (resetTime "hudmap_close" "0", guis/pda_chex.gui's Data/Stats tab buttons) are themselves
# mouse-click handlers this harness never fires, so it never refires - it is a one-time event, not
# a recurring one. But that flip is timed off ~400ms of gameLocal.time (idPlayerView::SingleView
# calls player->objectiveSystem->Redraw( gameLocal.time ) every frame the PDA is open,
# PlayerView.cpp) since the PDA gui was created, not off a fixed number of console-script "wait"
# ticks - and the two don't map 1:1: how much gameLocal.time advances per "wait" tick isn't fixed,
# so a fixed frame-count margin can't reliably bound a gameLocal.time-based threshold. Probing
# chextrek_dump's map_pda line at fine grain (5-frame steps, no re-assert after the first) across
# several runs showed the flip lands at
# a different "wait"-tick count almost every time, and once it lands, mapView/mapScale stay frozen
# for the rest of the run (movement never resumes on its own - confirmed by extending a probe well
# past the freeze with no recovery, and consistent with idWindow's own onTime semantics: a timeline
# fires once and only resetTime rearms it, and nothing here ever calls resetTime "hudmap_close"
# again). Two earlier fixes each assumed a fixed frame-count margin was enough to place a single
# re-assert safely past that flip (first, re-sending before every step; then, replaced by a single
# 60-frame wait up front) - both still lost a run's movement intermittently, for exactly that
# reason. Rather than fight that GUI timing detail in C++ (out of #37's scope - #37 only ports the
# mapControl-setting side, not the PDA gui's own page-navigation script), this scenario re-sends
# chextrek_test_pda_map_open 1 immediately before every measured step and after every 5-frame chunk
# of every wait (the last chunk right before a chextrek_dump is the one exception, since nothing
# after it needs the flag true) - keeping the re-assert dense enough that the flip, whenever it
# lands, is always corrected again within a handful of frames, well before the next measured
# dump - the test-only command is documented as setting the flag directly, and re-asserting it
# repeatedly is no different from a real player staying on the map page. In real play, the same
# one-time flip presumably happens too; it is just not disruptive there, since a player is unlikely
# to sit motionless on the map tab for ~400ms of gameLocal.time without also triggering something
# else.
#
# chextrek_dump's new `map_pda: scale=<f> view_x=<f> view_y=<f> control=<N>` line (ChexTrekDump.cpp)
# reads idPlayer::mapScale/mapView/mapControl directly, so this scenario can assert each map_*
# command changed the right value without depending on GUI rendering.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRATCH_DIR="$(mktemp -d)"
trap 'rm -rf "$SCRATCH_DIR"' EXIT

# shellcheck source=tools/lib-harness.sh
source "${SCRIPT_DIR}/lib-harness.sh"

echo "=== #37 PDA map test: build ==="
chextrek_build_or_exit

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
chextrek_test_pda_map_open 1
wait 5
chextrek_dump

chextrek_test_pda_map_open 1
chextrek_test_map_cmd map_zoom_in
wait 5
chextrek_test_pda_map_open 1
wait 5
chextrek_test_pda_map_open 1
wait 5
chextrek_test_pda_map_open 1
wait 5
chextrek_dump

chextrek_test_pda_map_open 1
chextrek_test_map_cmd map_stop
wait 5
chextrek_test_pda_map_open 1
chextrek_test_map_cmd map_zoom_out
wait 5
chextrek_test_pda_map_open 1
wait 5
chextrek_test_pda_map_open 1
wait 5
chextrek_test_pda_map_open 1
wait 5
chextrek_test_pda_map_open 1
wait 5
chextrek_test_pda_map_open 1
wait 5
chextrek_dump

chextrek_test_pda_map_open 1
chextrek_test_map_cmd map_stop
wait 5
chextrek_test_pda_map_open 1
chextrek_test_map_cmd map_scroll_right
wait 5
chextrek_test_pda_map_open 1
wait 5
chextrek_dump

chextrek_test_pda_map_open 1
chextrek_test_map_cmd map_stop
wait 5
chextrek_test_pda_map_open 1
chextrek_test_map_cmd map_scroll_up
wait 5
chextrek_test_pda_map_open 1
wait 5
chextrek_dump

chextrek_test_pda_map_open 1
chextrek_test_map_cmd map_stop
wait 5
chextrek_test_pda_map_open 1
chextrek_test_map_cmd map_scroll_down
wait 5
chextrek_test_pda_map_open 1
wait 5
chextrek_dump

chextrek_test_pda_map_open 1
chextrek_test_map_cmd map_stop
wait 5
chextrek_test_pda_map_open 1
chextrek_test_map_cmd map_scroll_left
wait 5
chextrek_test_pda_map_open 1
wait 5
chextrek_dump

chextrek_test_pda_map_open 1
chextrek_test_map_cmd map_stop
wait 5
chextrek_test_pda_map_open 1
chextrek_test_map_cmd map_scroll_center
wait 5
chextrek_test_pda_map_open 1
wait 5
chextrek_dump

chextrek_test_pda_map_open 1
chextrek_test_map_cmd map_zoom_in
wait 5
chextrek_test_pda_map_open 1
wait 5
chextrek_test_pda_map_open 1
wait 5
chextrek_test_pda_map_open 1
wait 5
chextrek_dump

chextrek_test_pda_map_open 1
chextrek_test_map_cmd map_stop
wait 5
chextrek_dump

chextrek_test_pda_map_open 1
chextrek_test_map_cmd map_stop
wait 5
chextrek_dump

screenshot chextrek_pda_map
wait 10
quit
EOF

echo
echo "=== #37 PDA map test: scenario run ==="

FAIL=0
chextrek_run_scenario chextrek_pda_map "$CONSOLE_SCRIPT" 120 || FAIL=1

LOCAL_LOG="$CHEXTREK_SCENARIO_LOG"
if [ -z "$LOCAL_LOG" ]; then
	echo "FAIL: couldn't find the archived log to check scenario-specific assertions"
	exit 1
fi

# --- e1m1 finishes loading (spec #28 always-on check) ---
chextrek_assert_map_loaded "$LOCAL_LOG" e1m1 || FAIL=1

# There are 11 chextrek_dump calls: baseline (map open, before any map_* command), after zoom_in,
# after stop+zoom_out, after stop+scroll_right, after stop+scroll_up, after stop+scroll_down,
# after stop+scroll_left, after stop+scroll_center, after zoom_in again (center still active),
# after map_stop (keeps MAP_CENTER, since a zoom bit was set alongside it), after a second
# map_stop (clears to 0, since no zoom bit remains).
MAP_PDA_LINES="$(grep -oE '^map_pda: scale=[0-9.eE+-]+ view_x=[0-9.eE+-]+ view_y=[0-9.eE+-]+ control=[0-9-]+$' "$LOCAL_LOG")"
LINE_COUNT="$(echo "$MAP_PDA_LINES" | grep -c '^map_pda:' || true)"
EXPECTED_LINES=11
if [ "$LINE_COUNT" -lt "$EXPECTED_LINES" ]; then
	echo "FAIL: expected ${EXPECTED_LINES} 'map_pda:' dump lines, saw ${LINE_COUNT}"
	echo "$MAP_PDA_LINES"
	FAIL=1
fi

field() { # field <line-number> <field-name>
	echo "$MAP_PDA_LINES" | sed -n "${1}p" | grep -oE "${2}=[0-9.eE+-]+" | cut -d= -f2
}

SCALE0="$(field 1 scale)"; CONTROL0="$(field 1 control)"
SCALE1="$(field 2 scale)"; CONTROL1="$(field 2 control)"
SCALE2="$(field 3 scale)"; CONTROL2="$(field 3 control)"
VIEWX3="$(field 4 view_x)"; VIEWY3="$(field 4 view_y)"; CONTROL3="$(field 4 control)"
VIEWX4="$(field 5 view_x)"; VIEWY4="$(field 5 view_y)"; CONTROL4="$(field 5 control)"
VIEWX5="$(field 6 view_x)"; VIEWY5="$(field 6 view_y)"; CONTROL5="$(field 6 control)"
VIEWX6="$(field 7 view_x)"; VIEWY6="$(field 7 view_y)"; CONTROL6="$(field 7 control)"
VIEWX7="$(field 8 view_x)"; VIEWY7="$(field 8 view_y)"; CONTROL7="$(field 8 control)"
SCALE8="$(field 9 scale)"; CONTROL8="$(field 9 control)"
CONTROL9="$(field 10 control)"
CONTROL10="$(field 11 control)"

echo "scale0=$SCALE0 control0=$CONTROL0"
echo "scale1=$SCALE1 control1=$CONTROL1"
echo "scale2=$SCALE2 control2=$CONTROL2"
echo "viewx3=$VIEWX3 viewy3=$VIEWY3 control3=$CONTROL3"
echo "viewx4=$VIEWX4 viewy4=$VIEWY4 control4=$CONTROL4"
echo "viewx5=$VIEWX5 viewy5=$VIEWY5 control5=$CONTROL5"
echo "viewx6=$VIEWX6 viewy6=$VIEWY6 control6=$CONTROL6"
echo "viewx7=$VIEWX7 viewy7=$VIEWY7 control7=$CONTROL7"
echo "scale8=$SCALE8 control8=$CONTROL8"
echo "control9=$CONTROL9"
echo "control10=$CONTROL10"

gt() { [ -n "$1" ] && [ -n "$2" ] && awk -v a="$1" -v b="$2" 'BEGIN{exit !(a>b)}'; }
lt() { [ -n "$1" ] && [ -n "$2" ] && awk -v a="$1" -v b="$2" 'BEGIN{exit !(a<b)}'; }
feq() { [ -n "$1" ] && [ -n "$2" ] && awk -v a="$1" -v b="$2" 'BEGIN{exit !(a==b)}'; }
fne() { [ -n "$1" ] && [ -n "$2" ] && awk -v a="$1" -v b="$2" 'BEGIN{exit !(a!=b)}'; }

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

# --- map_stop (no MAP_CENTER set) + map_zoom_out: mapScale decreases back down, MAP_ZOOM_OUT bit
# (4) set - also proves map_stop's "clear to 0" branch, since control1 (2, ZOOM_IN only, no
# MAP_CENTER) must have been cleared to 0 before map_zoom_out could OR in a clean MAP_ZOOM_OUT (4,
# not 4|2=6) ---
if lt "$SCALE2" "$SCALE1"; then
	echo "PASS: map_zoom_out decreased mapScale (${SCALE1} -> ${SCALE2})"
else
	echo "FAIL: expected mapScale to shrink after map_zoom_out, got ${SCALE1} -> ${SCALE2}"
	FAIL=1
fi
if [ "$CONTROL2" = "4" ]; then
	echo "PASS: map_stop cleared mapControl to 0 (no MAP_CENTER was set), then map_zoom_out set it to MAP_ZOOM_OUT (4)"
else
	echo "FAIL: expected control=4 after map_stop+map_zoom_out, got ${CONTROL2}"
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
if feq "$VIEWX4" "$VIEWX3"; then
	echo "PASS: map_scroll_up left mapView.x unchanged (${VIEWX3})"
else
	echo "FAIL: expected mapView.x to stay ${VIEWX3} during map_scroll_up, got ${VIEWX4}"
	FAIL=1
fi

# --- map_scroll_down: mapView.y decreases back down, MAP_SCROLL_DOWN bit (16) set; scroll_up's x
# is untouched ---
if lt "$VIEWY5" "$VIEWY4"; then
	echo "PASS: map_scroll_down decreased mapView.y (${VIEWY4} -> ${VIEWY5})"
else
	echo "FAIL: expected mapView.y to shrink after map_scroll_down, got ${VIEWY4} -> ${VIEWY5}"
	FAIL=1
fi
if [ "$CONTROL5" = "16" ]; then
	echo "PASS: map_scroll_down set mapControl to MAP_SCROLL_DOWN (16)"
else
	echo "FAIL: expected control=16 after map_scroll_down, got ${CONTROL5}"
	FAIL=1
fi
if feq "$VIEWX5" "$VIEWX4"; then
	echo "PASS: map_scroll_down left mapView.x unchanged (${VIEWX4})"
else
	echo "FAIL: expected mapView.x to stay ${VIEWX4} during map_scroll_down, got ${VIEWX5}"
	FAIL=1
fi

# --- map_scroll_left: mapView.x decreases, MAP_SCROLL_LEFT bit (32) set; scroll_down's y is
# untouched ---
if lt "$VIEWX6" "$VIEWX5"; then
	echo "PASS: map_scroll_left decreased mapView.x (${VIEWX5} -> ${VIEWX6})"
else
	echo "FAIL: expected mapView.x to shrink after map_scroll_left, got ${VIEWX5} -> ${VIEWX6}"
	FAIL=1
fi
if [ "$CONTROL6" = "32" ]; then
	echo "PASS: map_scroll_left set mapControl to MAP_SCROLL_LEFT (32)"
else
	echo "FAIL: expected control=32 after map_scroll_left, got ${CONTROL6}"
	FAIL=1
fi
if feq "$VIEWY6" "$VIEWY5"; then
	echo "PASS: map_scroll_left left mapView.y unchanged (${VIEWY5})"
else
	echo "FAIL: expected mapView.y to stay ${VIEWY5} during map_scroll_left, got ${VIEWY6}"
	FAIL=1
fi

# --- map_scroll_center: mapView snaps to the player's origin (MAP_CENTER bit 1 set), away from
# the small scroll-accumulated position ---
if [ "$CONTROL7" = "1" ]; then
	echo "PASS: map_scroll_center set mapControl to MAP_CENTER (1)"
else
	echo "FAIL: expected control=1 after map_scroll_center, got ${CONTROL7}"
	FAIL=1
fi
if fne "$VIEWX7" "$VIEWX6" || fne "$VIEWY7" "$VIEWY6"; then
	echo "PASS: map_scroll_center moved mapView away from the scrolled position (${VIEWX6},${VIEWY6} -> ${VIEWX7},${VIEWY7})"
else
	echo "FAIL: expected map_scroll_center to change mapView, stayed at (${VIEWX6},${VIEWY6})"
	FAIL=1
fi

# --- map_zoom_in while MAP_CENTER is still active: mapScale grows again, mapControl combines
# MAP_CENTER|MAP_ZOOM_IN (1|2=3) - zoom and center OR together instead of replacing each other ---
if gt "$SCALE8" "$SCALE2"; then
	echo "PASS: map_zoom_in grew mapScale again while centered (${SCALE2} -> ${SCALE8})"
else
	echo "FAIL: expected mapScale to grow again after the second map_zoom_in, got ${SCALE2} -> ${SCALE8}"
	FAIL=1
fi
if [ "$CONTROL8" = "3" ]; then
	echo "PASS: map_zoom_in OR'd MAP_ZOOM_IN into the still-set MAP_CENTER (control=3)"
else
	echo "FAIL: expected control=3 (MAP_CENTER|MAP_ZOOM_IN) after map_zoom_in while centered, got ${CONTROL8}"
	FAIL=1
fi

# --- map_stop's OTHER branch: with both a zoom bit (MAP_ZOOM_IN) and MAP_CENTER set, map_stop
# keeps only MAP_CENTER (1), instead of clearing to 0 ---
if [ "$CONTROL9" = "1" ]; then
	echo "PASS: map_stop kept MAP_CENTER (1) because a zoom bit was set alongside it"
else
	echo "FAIL: expected control=1 (MAP_CENTER kept) after map_stop with a zoom bit set, got ${CONTROL9}"
	FAIL=1
fi

# --- A second map_stop, now with only MAP_CENTER set (no zoom bit): falls into the other branch
# and clears mapControl to 0 ---
if [ "$CONTROL10" = "0" ]; then
	echo "PASS: a second map_stop (no zoom bit left) cleared mapControl to 0"
else
	echo "FAIL: expected control=0 after the second map_stop, got ${CONTROL10}"
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
