#!/usr/bin/env bash
# Automated test for spec #39's acceptance criteria (decomp-so/reference/hud-map.md):
#   AC: walk to reveal part of the map, save, load; dump map state and coverage match the
#       pre-save values
#
# Ported edit-inside-stock-function lead (Player.cpp): idPlayer::Save now writes
# mapScale/mapRadius/unknown1e5c/revealDistance/mapWidth/mapHeight/mapCoords/mapMaterial, then the
# whole hudmap_alpha fog-of-war global, in that exact order (idPlayer::Restore reads them back in
# the same order) - matching decomp-so/reference/hud-map.md's own Save/Restore lead
# (idPlayer::Save @ 0x152d88-0x152e8f writes those fields then the fog-of-war global one byte at a
# time; idPlayer::Restore @ 0x168b19-0x168bdd reads them back the same way - this port uses a
# single bulk savefile->Write/Read for the fog-of-war global instead of one WriteByte/ReadByte per
# byte, same bytes in the same order, matching the SDK's own existing convention for byte-array
# members, e.g. Target.cpp's idTarget_EndLevelGUI::Save/Restore of displayStats). Per that same
# lead, mapControl/mapView/lastRevealOrigin/mapLevels are NOT saved: mapControl/mapView/
# lastRevealOrigin are transient PDA/reveal-tracking state, and mapLevels is normally re-read from
# the world's spawnArgs by initHudMap() every time idPlayer::Spawn runs (a fresh map load) - never
# by a save/load, which restores straight from the savegame's serialized objects
# (idGameLocal::InitFromSaveGame, Game_local.cpp) and never calls Spawn/Init on the player it
# restores into. Found while writing this scenario: without also giving these five fields sane
# defaults in the idPlayer constructor (Player.cpp, #39), a freshly-allocated idPlayer restored
# straight from a savegame held whatever garbage was already in that memory (Mem_Alloc doesn't
# zero it) - confirmed live here, a garbage mapLevels[0] landing above the player's own z fired
# "Location below lowest MapLevel" warnings after every save/load round-trip this scenario ran, so
# the scenario also asserts that warning's absence below (a scenario-revealed gap, filled here and
# recorded in docs/harness-coverage.md, matching #36-#38's own precedent of recording gap-filling
# edits there rather than in the frozen, formally-checked decomp-so/reference/hud-map.md itself -
# per spec #28's gap-filling process. This also answers that reference's own open question,
# "whether idPlayer::Spawn (hence initHudMap) runs on a load was not checked": it doesn't).
#
# This scenario proves two of the newly-saved fields survive a real save/load round-trip:
# - `hud_map`'s `coverage` (chextrek_dump, #36): the fog-of-war global itself, revealed by walking
#   (setviewpos, same technique tools/test-hud-map.sh uses) before the save - the AC's literal
#   subject ("dump ... coverage match the pre-save values").
#
# Review finding fixed here: hudmap_alpha is a single process-wide global, and mapScale lives on
# the one idPlayer object dhewm3 keeps in memory the whole time - savegame/loadgame both run
# inside the same process, without recreating either. So a naive "dump before save, dump after
# load, assert they match" check would pass even if idPlayer::Restore's reads of them
# (Player.cpp) were deleted entirely: both would simply still hold their pre-save values,
# untouched by anything. To actually exercise Restore, the script perturbs both between the
# savegame and the loadgame: the real "showMap" console command (#38) fills every level's
# hudmap_alpha with 0xff (coverage=16384, the full 128x128 image), and another map_zoom_in grows
# mapScale further past its already-zoomed pre-save value - both asserted in one dump below,
# proving the globals did change in between. Only the loadgame that follows can bring coverage and
# mapScale back down to their pre-save values - if idPlayer::Restore's reads were missing or
# broken, the post-load dump would still show the showMap/zoom-perturbed values, not the pre-save
# ones.
# - `map_pda`'s `scale` (chextrek_dump, #37): idPlayer::mapScale, changed away from its default (1)
#   with the PDA's own map_zoom_in GUI command before the save, then frozen with map_stop so no
#   further per-frame change happens between capturing the pre-save value and loading - proving the
#   save/load round-trip, not just standing still, is what carries the value across.
#
# Getting mapScale to actually change needs the PDA open with its own map page active, the same
# "chextrek_test_pda_map_open"/"chextrek_test_map_cmd" dance #37's tools/test-pda-map.sh
# establishes (see that script's own header comment for the full rationale): idPlayer::updateMap
# only applies mapControl's zoom bit to the PDA's map page (idPlayer::updateMapUI's `!isHud`
# branch) while objectiveSystemOpen is true AND the PDA gui's own "HudMap" state variable is true.
# The PDA itself is opened the same way #35's tools/test-pda.sh does: spawn+trigger a fresh
# item_pda (neither e1m1 nor sf_923 places one reachable from spawn), since idPlayer::GivePDA
# (stock, unedited) calls TogglePDA() on the player's first PDA with no impulse/mouse input needed.
#
# Unlike #37's own scenario, this one doesn't need to fight guis/pda_chex.gui's ~400ms
# "hudmap_close" timing quirk (see tools/test-pda-map.sh's header comment for the full story): once
# "map_stop" clears mapControl back to 0 (both zooms set only MAP_ZOOM_IN, no MAP_CENTER, so
# map_stop's "no zoom bit alongside MAP_CENTER" branch applies), idPlayer::mapScale stops changing
# every frame regardless of what the PDA gui's own "HudMap" flag does afterward - updateMapUI's
# zoom step only runs while a zoom bit is actually set in mapControl. So the value captured right
# after "map_stop" is stable through everything that follows (the setviewpos walk, the savegame,
# the loadgame), with no re-send-the-flag dance needed once it's frozen.
#
# savegame/loadgame reused verbatim from #31's tools/test-objectives.sh (developer-only console
# commands, per spec #28's testing decisions).
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRATCH_DIR="$(mktemp -d)"
trap 'rm -rf "$SCRATCH_DIR"' EXIT

# shellcheck source=tools/lib-harness.sh
source "${SCRIPT_DIR}/lib-harness.sh"

echo "=== #39 HUD map save/load test: build ==="
if ! bash "${SCRIPT_DIR}/build-chextrek.sh"; then
	echo "FAIL: build-chextrek.sh failed"
	exit 1
fi

CONSOLE_SCRIPT="${SCRATCH_DIR}/hud_map_saveload.cfg"
cat > "$CONSOLE_SCRIPT" <<'EOF'
developer 1
map e1m1
wait 20
noclip

spawn item_pda name saveload_pda
trigger saveload_pda
wait 10

chextrek_test_pda_map_open 1
chextrek_test_map_cmd map_zoom_in
wait 5
chextrek_test_pda_map_open 1
chextrek_test_map_cmd map_zoom_in
wait 5
chextrek_test_pda_map_open 1
chextrek_test_map_cmd map_stop
wait 5

chextrek_dump

setviewpos 300 -976 8 0
wait 15
chextrek_dump

savegame chextrek_hud_map_saveload_test
wait 5

showMap
chextrek_test_pda_map_open 1
chextrek_test_map_cmd map_zoom_in
wait 5
chextrek_dump

loadgame chextrek_hud_map_saveload_test
wait 20

chextrek_dump

screenshot chextrek_hud_map_saveload
wait 10
quit
EOF

echo
echo "=== #39 HUD map save/load test: scenario run ==="
RUN_OUT="$(bash "${SCRIPT_DIR}/run-scenario.sh" chextrek_hud_map_saveload "$CONSOLE_SCRIPT" 120 2>&1)"
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

# There are 4 chextrek_dump calls: after zooming+map_stop (before the walk), after the setviewpos
# walk (the pre-save state), after showMap (post-save, pre-load - proves hudmap_alpha actually
# changed in between, see the header comment above), and after the savegame/loadgame round-trip
# (the post-load state).
COVERAGE_VALUES="$(chextrek_hud_map_coverage_values "$LOCAL_LOG")"
C0="$(echo "$COVERAGE_VALUES" | sed -n '1p')"
C1="$(echo "$COVERAGE_VALUES" | sed -n '2p')"
C_SHOWMAP="$(echo "$COVERAGE_VALUES" | sed -n '3p')"
C2="$(echo "$COVERAGE_VALUES" | sed -n '4p')"

# "level" (idPlayer::HudMapLevel( NULL )) is asserted too, matching the same pre-save value, even
# though on e1m1 (all level 0) it would happen to read 0 either way (HudMapLevel falls back to 0
# and warns when z lands below mapLevels[0] - see the "Location below lowest MapLevel" check below
# for the assertion that actually would have caught a garbage mapLevels[0], since the "level"
# value alone can't distinguish a correct level 0 from that fallback).
LEVEL_VALUES="$(chextrek_hud_map_level_values "$LOCAL_LOG")"
L1="$(echo "$LEVEL_VALUES" | sed -n '2p')"
L2="$(echo "$LEVEL_VALUES" | sed -n '4p')"

# map_pda: scale=<f> view_x=<f> view_y=<f> control=<N> - only "scale" is asserted here (saved by
# #39); view_x/view_y/control are NOT saved (idPlayer::mapView/mapControl - see the header comment
# above), so they're not expected to match after a load and aren't checked. Regex matches
# tools/test-pda-map.sh's own (scientific notation/sign, even though mapScale itself is never
# negative here) for consistency.
SCALE_VALUES="$(grep -oE '^map_pda: scale=[0-9.eE+-]+' "$LOCAL_LOG" | grep -oE '[0-9.eE+-]+$')"
S0="$(echo "$SCALE_VALUES" | sed -n '1p')"
S1="$(echo "$SCALE_VALUES" | sed -n '2p')"
S2="$(echo "$SCALE_VALUES" | sed -n '4p')"

# --- pre-save setup sanity: zooming actually grew mapScale above its default (1), and it's frozen
# (map_stop) before the walk, so S0 and S1 are the same, pre-save value ---
if [ -n "$S0" ] && awk -v s="$S0" 'BEGIN { exit !(s > 1.0) }'; then
	echo "PASS: map_zoom_in x2 grew mapScale above its default (scale=${S0})"
else
	echo "FAIL: expected mapScale > 1.0 after two map_zoom_in commands, got '${S0}'"
	FAIL=1
fi

if [ -n "$S0" ] && [ -n "$S1" ] && [ "$S0" = "$S1" ]; then
	echo "PASS: mapScale stayed frozen (map_stop) through the setviewpos walk (scale=${S1})"
else
	echo "FAIL: expected mapScale to stay frozen at ${S0} through the walk, got '${S1}'"
	FAIL=1
fi

# --- walking (setviewpos) revealed more of the map before the save ---
if [ -n "$C0" ] && [ "$C0" -gt 0 ]; then
	echo "PASS: baseline coverage is already nonzero (${C0} texels), standing near the spawn point"
else
	echo "FAIL: expected nonzero baseline coverage, got '${C0}'"
	FAIL=1
fi

if [ -n "$C1" ] && [ -n "$C0" ] && [ "$C1" -gt "$C0" ]; then
	echo "PASS: the walk (setviewpos) grew coverage before the save (${C0} -> ${C1})"
else
	echo "FAIL: expected coverage to grow after the setviewpos walk, got ${C0} -> ${C1}"
	FAIL=1
fi

# --- proves hudmap_alpha and mapScale actually changed between the save and the load (see the
# header comment above): without this, a post-load value that merely equals the pre-save value
# would be ambiguous - both could just have sat there untouched the whole time, savegame/loadgame
# running in the same process on the same idPlayer object. ---
FULL_COVERAGE=16384 # 128 x 128 fog-of-war texels
S_PERTURB="$(echo "$SCALE_VALUES" | sed -n '3p')"

if [ -n "$C_SHOWMAP" ] && [ "$C_SHOWMAP" -eq "$FULL_COVERAGE" ]; then
	echo "PASS: showMap (between the savegame and the loadgame) filled coverage to ${FULL_COVERAGE} - proves the global actually changed before the load"
else
	echo "FAIL: expected showMap to raise coverage to ${FULL_COVERAGE}, got '${C_SHOWMAP}'"
	FAIL=1
fi

if [ -n "$S_PERTURB" ] && [ -n "$S1" ] && awk -v a="$S_PERTURB" -v b="$S1" 'BEGIN { exit !(a > b) }'; then
	echo "PASS: another map_zoom_in (between the savegame and the loadgame) grew mapScale past its pre-save value (${S1} -> ${S_PERTURB}) - proves it actually changed before the load"
else
	echo "FAIL: expected mapScale to grow past ${S1} after the extra map_zoom_in, got '${S_PERTURB}'"
	FAIL=1
fi

# --- the AC itself: after save/load, the dump's map state and coverage match the pre-save values,
# not the showMap-filled value the load has to overwrite ---
if [ -n "$C2" ] && [ -n "$C1" ] && [ "$C2" = "$C1" ]; then
	echo "PASS: coverage after save/load matches the pre-save value (${C1} == ${C2}) - the revealed fog of war survived"
else
	echo "FAIL: expected coverage to still be ${C1} after save/load, got '${C2}'"
	FAIL=1
fi

if [ -n "$S2" ] && [ -n "$S1" ] && [ "$S1" = "$S2" ]; then
	echo "PASS: mapScale after save/load matches the pre-save value (${S1} == ${S2})"
else
	echo "FAIL: expected mapScale to still be ${S1} after save/load, got '${S2}'"
	FAIL=1
fi

if [ -n "$L2" ] && [ -n "$L1" ] && [ "$L1" = "$L2" ]; then
	echo "PASS: hud_map's level after save/load matches the pre-save value (${L1} == ${L2})"
else
	echo "FAIL: expected hud_map's level to still be ${L1} after save/load, got '${L2}'"
	FAIL=1
fi

# --- the gap this scenario found and #39's idPlayer constructor edit closes: without sane
# defaults for mapLevels (and mapControl/mapView/lastRevealOrigin/unknown1e5c), a savegame-load
# restores into a freshly-allocated idPlayer that never runs Init()/Spawn()'s initHudMap, leaving
# mapLevels[0] as leftover memory - HudMapLevel then warns and falls back to level 0 whenever the
# player's z lands below that garbage value. "level" alone (checked above) can't tell a real level
# 0 apart from that fallback, so this checks the warning's absence directly instead - the assertion
# that actually would have failed before the constructor fix, since e1m1's own level is 0 either
# way.
if grep -qF "Location below lowest MapLevel" "$LOCAL_LOG"; then
	echo "FAIL: 'Location below lowest MapLevel' warning seen in the log - mapLevels held garbage after the save/load round-trip"
	grep -nF "Location below lowest MapLevel" "$LOCAL_LOG"
	FAIL=1
else
	echo "PASS: no 'Location below lowest MapLevel' warning - mapLevels came back sane after the save/load round-trip"
fi

echo
if [ $FAIL -eq 0 ]; then
	echo "PASS: #39 HUD map save/load scenario - the revealed HUD map (fog-of-war coverage and mapScale) survives save/load"
	exit 0
else
	echo "FAIL: #39 HUD map save/load scenario - see above"
	exit 1
fi
