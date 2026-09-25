#!/usr/bin/env bash
# Automated test for spec #30's per-feature acceptance criteria: a scripted scenario per event
# (openDoors, setProj, spawnDict, footPrint) showing its observable effect, a script removing an
# actor via `remove`, and a footprint decal being projected (log evidence + screenshot artifact).
# See docs/harness-coverage.md.
#
# Drives e1m1 (spec #28's real first map) through console commands only (map, spawn, script,
# wait, chextrek_dump, screenshot), per spec #28's testing decisions. The scenario needs a few
# test-only cvars (chextrek_test_str1..8, ChexTrekDump.cpp) to get doom-script string literals and
# named-entity lookups through the "script" console command at all: the engine's own console
# tokenizer (idCmdArgs::TokenizeString) strips quotes from a typed string literal before the
# script compiler ever sees it, and separately intercepts a bare "$name" token as *cvar*
# expansion - which collides with doom-script's own "$entityName" syntax. Both are worked around
# by giving the tokenizer's "$name" cvar-substitution a cvar to substitute: one whose *value*
# already contains the quote characters we need (for string literals), and using
# `sys.getEntity( $cvar )` instead of `$entityName` (a runtime name lookup, not compile-time
# syntax) for named entities. See the comment above those cvars in ChexTrekDump.cpp for the full
# story - this is why the scenario script below never types a literal quote or a bare `$name`.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRATCH_DIR="$(mktemp -d)"
trap 'rm -rf "$SCRATCH_DIR"' EXIT

echo "=== #30 script-events test: build ==="
if ! bash "${SCRIPT_DIR}/build-chextrek.sh"; then
	echo "FAIL: build-chextrek.sh failed"
	exit 1
fi

# e1m1 already has what this scenario needs (spec #28's real first map, not a synthetic fixture):
# an unlocked, at-rest door (func_door_17) and an idAI (monster_chex_cly_2) to open it, per
# decomp-so/reference/door-opening.md. chextrek_test_str1..8 (ChexTrekDump.cpp) hold the literal
# strings/entity names this scenario needs - see the file header above for why.
CONSOLE_SCRIPT="${SCRATCH_DIR}/script-events.cfg"
cat > "$CONSOLE_SCRIPT" <<'EOF'
developer 1
map e1m1
wait 10
chextrek_dump

spawn monster_flemoid name chextrek_removeme
wait 10
chextrek_dump

script sys.println( sys.getEntity( $chextrek_test_str2 ).isOpen() )
script sys.getEntity( $chextrek_test_str3 ).openDoors( sys.getEntity( $chextrek_test_str2 ) )
wait 10
script sys.println( sys.getEntity( $chextrek_test_str2 ).isOpen() )

script sys.println( sys.getEntity( $chextrek_test_str6 ).getWeaponEntity().createProjectile().getKey( $chextrek_test_str8 ) )
script sys.getEntity( $chextrek_test_str6 ).getWeaponEntity().setProj( $chextrek_test_str7 )
script sys.println( sys.getEntity( $chextrek_test_str6 ).getWeaponEntity().createProjectile().getKey( $chextrek_test_str8 ) )
wait 5

script sys.println( sys.spawnDict( $chextrek_test_str1 ).getName() )
wait 5
chextrek_dump

spawn monster_chex_biped name chextrek_footprint_actor footprint_on_sound 1
wait 30
script sys.getEntity( $chextrek_test_str5 ).leftFoot()
wait 10
chextrek_dump

script sys.getEntity( $chextrek_test_str4 ).remove()
wait 10
chextrek_dump

screenshot chextrek_script_events
wait 10
quit
EOF

echo
echo "=== #30 script-events test: scenario run ==="
RUN_OUT="$(bash "${SCRIPT_DIR}/run-scenario.sh" chextrek_script_events "$CONSOLE_SCRIPT" 90 2>&1)"
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

# Fail loudly on any doom-script compile error from a "script" line (e.g. a future engine/data
# change breaking one of the cvar-based workarounds above) - these wouldn't otherwise show up as
# "ERROR:" lines the always-on checks catch.
if grep -qE "^Error: |Unknown command|Unknown punctuation" "$LOCAL_LOG"; then
	echo "FAIL: a 'script' console line failed to compile/run - see the log for 'Error:'/'Unknown command'/'Unknown punctuation' lines"
	echo "$(grep -nE "^Error: |Unknown command|Unknown punctuation" "$LOCAL_LOG")"
	FAIL=1
fi

# --- openDoors: monster_chex_cly_2.openDoors(func_door_17) opens the unlocked, at-rest door ---
# isOpen() is printed twice, in order: before (expect 0, unlocked-but-closed) and after (expect a
# nonzero value once idAI::OpenDoors's door->Use() has had a few frames to start the door moving).
ISOPEN_VALUES="$(grep -oE '^[0-9]+(\.[0-9]+)?$' "$LOCAL_LOG" | head -2)"
ISOPEN_BEFORE="$(echo "$ISOPEN_VALUES" | sed -n '1p')"
ISOPEN_AFTER="$(echo "$ISOPEN_VALUES" | sed -n '2p')"
if [ "$ISOPEN_BEFORE" = "0" ] && [ -n "$ISOPEN_AFTER" ] && [ "$ISOPEN_AFTER" != "0" ]; then
	echo "PASS: openDoors - func_door_17.isOpen() went from ${ISOPEN_BEFORE} to ${ISOPEN_AFTER} after monster_chex_cly_2.openDoors(func_door_17)"
else
	echo "FAIL: openDoors - expected isOpen() to go from 0 to nonzero, got '${ISOPEN_BEFORE}' then '${ISOPEN_AFTER}'"
	FAIL=1
fi

# --- setProj: the weapon's createProjectile() classname changes to the def passed to setProj ---
if grep -qF "projectile_minizorchblast" "$LOCAL_LOG" && grep -qF "projectile_minizorchblast_nodamage" "$LOCAL_LOG"; then
	echo "PASS: setProj - createProjectile()'s classname changed to projectile_minizorchblast_nodamage after setProj"
else
	echo "FAIL: setProj - expected to see both the default and the swapped-to projectile classname in the log"
	FAIL=1
fi

# --- spawnDict: sys.spawnDict(...) actually spawns an entity of the given def ---
if grep -qF "idMoveableItem_moveable_item_shotgun" "$LOCAL_LOG"; then
	echo "PASS: spawnDict - spawned an idMoveableItem from moveable_item_shotgun's dict"
else
	echo "FAIL: spawnDict - expected to see a spawned idMoveableItem_moveable_item_shotgun_* entity name in the log"
	FAIL=1
fi

# --- footPrint: the footprints counter (ChexTrekDump.cpp) goes above zero once triggered ---
LAST_FOOTPRINTS="$(grep -oE '^footprints: [0-9]+' "$LOCAL_LOG" | tail -1 | grep -oE '[0-9]+')"
if [ -n "$LAST_FOOTPRINTS" ] && [ "$LAST_FOOTPRINTS" -gt 0 ]; then
	echo "PASS: footPrint - a decal was projected (chextrek_dump reports footprints: ${LAST_FOOTPRINTS})"
else
	echo "FAIL: footPrint - expected chextrek_dump's footprints counter to be above zero, got '${LAST_FOOTPRINTS}'"
	FAIL=1
fi

# --- remove: a script's remove() call actually shrinks the live entity count ---
ENTITY_COUNTS="$(grep -oE '^entities: [0-9]+' "$LOCAL_LOG" | grep -oE '[0-9]+')"
BEFORE_REMOVE="$(echo "$ENTITY_COUNTS" | tail -2 | head -1)"
AFTER_REMOVE="$(echo "$ENTITY_COUNTS" | tail -1)"
if [ -n "$BEFORE_REMOVE" ] && [ -n "$AFTER_REMOVE" ] && [ "$AFTER_REMOVE" -eq $(( BEFORE_REMOVE - 1 )) ]; then
	echo "PASS: remove - entities went from ${BEFORE_REMOVE} to ${AFTER_REMOVE} after chextrek_removeme.remove()"
else
	echo "FAIL: remove - expected the last entity count to be exactly one less than the previous one, got '${BEFORE_REMOVE}' then '${AFTER_REMOVE}'"
	FAIL=1
fi

echo
if [ $FAIL -eq 0 ]; then
	echo "PASS: #30 script-events scenario - openDoors, setProj, spawnDict, footPrint and remove all show their observable effect"
	exit 0
else
	echo "FAIL: #30 script-events scenario - see above"
	exit 1
fi
