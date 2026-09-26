#!/usr/bin/env bash
# Automated test for spec #36's acceptance criteria (decomp-so/reference/hud-map.md):
#   AC1: impulse 23 toggles the map (dump shows visible/hidden)
#   AC2: setviewpos to several points; dump coverage grows after each move
#
# Ported from decomp-so/reference/hud-map.md: idPlayer::initHudMap/updateMap/updateMapUI/
# updateHudMapAlpha/MapImageCoords, plus HudMapLevel's real body (spec #16/#31 left it a stub).
# Wiring (edits-inside-stock-functions leads, all in Player.cpp):
#   - idPlayer::Spawn calls initHudMap() right after loading objectiveSystem.
#   - idPlayer::Think calls updateMap() every frame (just before UpdateHud()).
#   - idPlayer::Init zeroes mapControl/mapView/lastRevealOrigin, sets unknown1e5c to -1, and
#     memsets the fog-of-war global hudmap_alpha.
#   - impulse 23 (idPlayer::PerformImpulse) toggles the HUD gui's own "HudMap" state flag via the
#     "openMap"/"closeMap" named events hud.gui's hudmap_open/hudmap_close windows handle.
# Explicitly NOT ported here (separate sub-issues, per spec #28's order list):
#   - #37: the PDA's map_scroll_*/map_zoom_*/map_scroll_center GUI commands that drive
#     idPlayer::mapControl (idPlayer::HandleSingleGuiCommand) - mapControl stays 0 in this scenario.
#   - #38: the "showMap" console command.
#   - #39: saving/restoring the HUD map's state across a save/load.
#
# --- AC1 ---
# "Visible/hidden" isn't a new idPlayer member - it's the HUD gui's own "HudMap" state flag
# (hud.gui's hudmap_open/hudmap_close windows set it on the "openMap"/"closeMap" named events
# impulse 23 sends). chextrek_dump's new `hud_map: level=<N> visible=<0|1> coverage=<N>` line
# (ChexTrekDump.cpp) reads it straight from idPlayer::hud->GetStateBool( "HudMap", "0" ), so a
# scenario can assert impulse 23 flips it without depending on GUI rendering.
#
# There's no way to send an impulse from a console script directly: neither a plain "impulse 23"
# command nor typing the bind-target token itself ("_impulse23", what autoexec.cfg/matt.cfg/
# scott.cfg actually bind keys to per decomp-so/reference/hud-map.md's Notes) exists as a real
# console command (both confirmed rejected as "Unknown command" against this engine build) -
# "_impulseN" strings are recognized by idUsercmdGenLocal only from a real, currently-held bound
# key, which a console script can't simulate. `chextrek_test_impulse <N>` (test-only, spec #36,
# ChexTrekDump.cpp/.h) closes that gap the same way chextrek_test_customui_cmd (#34) does for a GUI
# button click: it calls idPlayer::PerformImpulse(N) directly - everything downstream (the switch
# in PerformImpulse itself, HandleNamedEvent, hud.gui's own onNamedEvent blocks) is the real,
# already-ported game code, unchanged. guis/hud.gui's hudmap_open window flips "gui::HudMap" to 1
# at its own onTime 5 (5ms in) - a short wait is enough - but hudmap_close only flips it back to 0
# at its onTime 400 (400ms in, after a fade-out transition finishes), timed off gameLocal.time
# (idPlayerView::SingleView calls the HUD gui's Redraw( gameLocal.time ) every frame, PlayerView.cpp),
# not off a fixed number of console-script "wait" ticks - and the two don't map 1:1 (#37's
# tools/test-pda-map.sh hit the exact same gap for guis/pda_chex.gui's own onTime 400: "how much
# gameLocal.time advances per 'wait' tick isn't fixed, so a fixed frame-count margin can't reliably
# bound a gameLocal.time-based threshold"). A single fixed-length wait followed by one dump
# was observed to land on either side of the flip across runs - sometimes
# still 1, sometimes already 0. Rather than guess a bigger fixed margin (liable to the same
# intermittent failure, just at lower odds), this scenario samples repeatedly: eight chextrek_dumps,
# 20 frames apart (160 frames of total margin), and the assertion
# below passes if *any* of the eight shows visible=0 - the flip is one-time and monotonic (hud.gui's
# own onTime semantics: a timeline fires once and only resetTime rearms it, and nothing here calls
# resetTime "hudmap_close" again), so once one sample sees 0, every later sample would too. The
# last of the eight is also reused as AC2's pre-setviewpos coverage baseline (still standing at the
# spawn point throughout - see AC2 below).
#
# --- AC2 ---
# `coverage` is the number of alpha-revealed texels (hudmap_alpha[level][...][3] > 0) out of the
# level's 128x128 fog-of-war image (idPlayer::updateHudMapAlpha, called every frame from
# idPlayer::Think via updateMap). e1m1's info_player_start_3 sits at -1032 -976 8; e1m1's own
# worldspawn map_coords ("-1768 1840 1752 -2120") make one texel ~27.5 world units, and the
# default map_radius (8 texels - e1m1's own worldspawn overrides it to 12, "map_radius" "12" in
# maps/e1m1.map) reveals a square roughly 660 world units on a side (at e1m1's actual 12-texel
# radius) around each reveal point - so each scenario setviewpos jumps by 1300+ world units in at
# least one axis from the *previous* point to guarantee it lands well outside that point's
# fully-revealed square (a jump too close to that could land entirely inside ground already maxed
# out to alpha 255, showing no growth even though the feature works - this was seen while writing
# this scenario with smaller jumps, and with a first move that landed back on the player's own
# spawn point, already revealed by the time the player stood there through the earlier "wait 20"/
# impulse waits). `noclip` (stock, CMD_FL_CHEAT) is set first so `setviewpos`'s teleport can't be
# blocked or immediately corrected by collision against the level geometry - irrelevant to
# fog-of-war, which only reads the player's origin, not whether the player physically fits there.
# The baseline dump (before any setviewpos, still standing at the spawn point) is itself the first
# comparison point, so all 3 setviewpos moves - not just the 2nd and 3rd - are checked for growth.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRATCH_DIR="$(mktemp -d)"
trap 'rm -rf "$SCRATCH_DIR"' EXIT

# shellcheck source=tools/lib-harness.sh
source "${SCRIPT_DIR}/lib-harness.sh"

echo "=== #36 HUD map test: build ==="
chextrek_build_or_exit

CONSOLE_SCRIPT="${SCRATCH_DIR}/hud_map.cfg"
cat > "$CONSOLE_SCRIPT" <<'EOF'
developer 1
map e1m1
wait 20
noclip

chextrek_dump

chextrek_test_impulse 23
wait 10
chextrek_dump

chextrek_test_impulse 23
wait 20
chextrek_dump
wait 20
chextrek_dump
wait 20
chextrek_dump
wait 20
chextrek_dump
wait 20
chextrek_dump
wait 20
chextrek_dump
wait 20
chextrek_dump
wait 20
chextrek_dump

setviewpos 300 -976 8 0
wait 15
chextrek_dump

setviewpos 300 700 8 0
wait 15
chextrek_dump

setviewpos -1300 700 8 0
wait 15
chextrek_dump

screenshot chextrek_hud_map
wait 10
quit
EOF

echo
echo "=== #36 HUD map test: scenario run ==="

FAIL=0
chextrek_run_scenario chextrek_hud_map "$CONSOLE_SCRIPT" 120 || FAIL=1

LOCAL_LOG="$CHEXTREK_SCENARIO_LOG"
if [ -z "$LOCAL_LOG" ]; then
	echo "FAIL: couldn't find the archived log to check scenario-specific assertions"
	exit 1
fi

# --- e1m1 finishes loading (spec #28 always-on check) ---
chextrek_assert_map_loaded "$LOCAL_LOG" e1m1 || FAIL=1

# There are 13 chextrek_dump calls total: baseline, after the first impulse 23 (open), eight
# samples taken 20 frames apart after the second impulse 23 (close - see the comment above the
# console script for why eight samples instead of one), then after each of the 3 setviewpos moves.
VISIBLE_VALUES="$(chextrek_hud_map_visible_values "$LOCAL_LOG")"
COVERAGE_VALUES="$(chextrek_hud_map_coverage_values "$LOCAL_LOG")"

V0="$(echo "$VISIBLE_VALUES" | sed -n '1p')"
V1="$(echo "$VISIBLE_VALUES" | sed -n '2p')"
# Eight close samples, dumps 3-10 (1-indexed).
CLOSE_SAMPLES="$(echo "$VISIBLE_VALUES" | sed -n '3,10p')"

# --- AC1: impulse 23 toggles the map (dump shows visible/hidden) ---
if [ "$V0" = "0" ]; then
	echo "PASS: hud_map starts hidden (visible=0)"
else
	echo "FAIL: expected hud_map baseline visible=0, got '${V0}'"
	FAIL=1
fi

if [ "$V1" = "1" ]; then
	echo "PASS: impulse 23 showed the HUD map (visible 0 -> 1)"
else
	echo "FAIL: expected visible=1 after the first impulse 23, got '${V1}'"
	FAIL=1
fi

# The close transition (hud.gui's hudmap_close, onTime 400) is one-time and monotonic once it
# fires, so it's enough for any of the eight samples to already show 0 - see the console-script
# comment above for why a single fixed-length wait isn't reliable here. The *last* sample must
# also be 0 (not just any of them): once closed, nothing in this scenario reopens the map, so a
# last sample that somehow read back 1 (e.g. a regression that reopens or double-toggles the map)
# would mean the map didn't actually stay closed, even if an earlier sample happened to catch it
# mid-transition at 0.
LAST_CLOSE_SAMPLE="$(echo "$CLOSE_SAMPLES" | tail -n1)"
if echo "$CLOSE_SAMPLES" | grep -qx '0'; then
	echo "PASS: a second impulse 23 hid the HUD map again (visible 1 -> 0, seen in: $(echo "$CLOSE_SAMPLES" | tr '\n' ' '))"
else
	echo "FAIL: expected visible=0 in at least one of the eight post-close samples, got: $(echo "$CLOSE_SAMPLES" | tr '\n' ' ')"
	FAIL=1
fi

if [ "$LAST_CLOSE_SAMPLE" = "0" ]; then
	echo "PASS: the HUD map is still hidden at the last post-close sample (stayed closed)"
else
	echo "FAIL: expected the last post-close sample to be visible=0 (stayed closed), got '${LAST_CLOSE_SAMPLE}'"
	FAIL=1
fi

# --- AC2: setviewpos to several points; dump coverage grows after each move ---
# Dump 10 (1-indexed, the last of the eight post-close samples, still standing at the spawn point
# throughout) is the "before" value for the first move; dumps 11-13 are taken after each
# setviewpos.
C0="$(echo "$COVERAGE_VALUES" | sed -n '10p')"
C1="$(echo "$COVERAGE_VALUES" | sed -n '11p')"
C2="$(echo "$COVERAGE_VALUES" | sed -n '12p')"
C3="$(echo "$COVERAGE_VALUES" | sed -n '13p')"

if [ -n "$C0" ] && [ "$C0" -gt 0 ]; then
	echo "PASS: coverage is already nonzero at the spawn-point baseline (${C0} texels revealed)"
else
	echo "FAIL: expected baseline coverage > 0 (standing at the spawn point), got '${C0}'"
	FAIL=1
fi

if [ -n "$C1" ] && [ -n "$C0" ] && [ "$C1" -gt "$C0" ]; then
	echo "PASS: coverage grew after the first setviewpos (${C0} -> ${C1})"
else
	echo "FAIL: expected coverage to grow after the first setviewpos, got ${C0} -> ${C1}"
	FAIL=1
fi

if [ -n "$C2" ] && [ -n "$C1" ] && [ "$C2" -gt "$C1" ]; then
	echo "PASS: coverage grew after the second setviewpos (${C1} -> ${C2})"
else
	echo "FAIL: expected coverage to grow after the second setviewpos, got ${C1} -> ${C2}"
	FAIL=1
fi

if [ -n "$C3" ] && [ -n "$C2" ] && [ "$C3" -gt "$C2" ]; then
	echo "PASS: coverage grew after the third setviewpos (${C2} -> ${C3})"
else
	echo "FAIL: expected coverage to grow after the third setviewpos, got ${C2} -> ${C3}"
	FAIL=1
fi

echo
if [ $FAIL -eq 0 ]; then
	echo "PASS: #36 HUD map scenario - impulse 23 toggles the map and fog of war grows as the player moves"
	exit 0
else
	echo "FAIL: #36 HUD map scenario - see above"
	exit 1
fi
