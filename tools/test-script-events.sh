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

script sys.println( 100 + sys.getEntity( $chextrek_test_str2 ).isOpen() )
script sys.getEntity( $chextrek_test_str3 ).openDoors( sys.getEntity( $chextrek_test_str2 ) )
wait 10
script sys.println( 200 + sys.getEntity( $chextrek_test_str2 ).isOpen() )

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
# isOpen() before/after are printed as 100+isOpen() and 200+isOpen() (expect 100, then 201 once
# idAI::OpenDoors's door->Use() has had a few frames to start the door moving) instead of bare 0/1,
# so this can't be confused with an unrelated bare-number line landing anywhere else in the log.
ISOPEN_BEFORE="$(grep -oE '^10[01]$' "$LOCAL_LOG" | head -1)"
ISOPEN_AFTER="$(grep -oE '^20[01]$' "$LOCAL_LOG" | head -1)"
if [ "$ISOPEN_BEFORE" = "100" ] && [ "$ISOPEN_AFTER" = "201" ]; then
	echo "PASS: openDoors - func_door_17.isOpen() went from 0 to 1 after monster_chex_cly_2.openDoors(func_door_17)"
else
	echo "FAIL: openDoors - expected isOpen() markers 100 then 201, got '${ISOPEN_BEFORE}' then '${ISOPEN_AFTER}'"
	FAIL=1
fi

# --- setProj: the weapon's createProjectile() classname changes to the def passed to setProj ---
# Exact-line (not substring) matches, in order: "projectile_minizorchblast_nodamage" is NOT a
# substring match away from also satisfying a plain "projectile_minizorchblast" check, so this
# proves both the before value and that the swap actually happened in the right order.
SETPROJ_LINES="$(grep -nE '^projectile_minizorchblast(_nodamage)?$' "$LOCAL_LOG")"
SETPROJ_BEFORE_LINE="$(echo "$SETPROJ_LINES" | grep ':projectile_minizorchblast$' | head -1 | cut -d: -f1)"
SETPROJ_AFTER_LINE="$(echo "$SETPROJ_LINES" | grep ':projectile_minizorchblast_nodamage$' | head -1 | cut -d: -f1)"
if [ -n "$SETPROJ_BEFORE_LINE" ] && [ -n "$SETPROJ_AFTER_LINE" ] && [ "$SETPROJ_AFTER_LINE" -gt "$SETPROJ_BEFORE_LINE" ]; then
	echo "PASS: setProj - createProjectile()'s classname changed from projectile_minizorchblast to projectile_minizorchblast_nodamage after setProj"
else
	echo "FAIL: setProj - expected 'projectile_minizorchblast' then, later, 'projectile_minizorchblast_nodamage' as exact lines - got lines '${SETPROJ_BEFORE_LINE}' and '${SETPROJ_AFTER_LINE}'"
	FAIL=1
fi

# --- spawnDict: sys.spawnDict(...) actually spawns an entity of the given def ---
if grep -qE '^idMoveableItem_moveable_item_shotgun_[0-9]+$' "$LOCAL_LOG"; then
	echo "PASS: spawnDict - spawned an idMoveableItem from moveable_item_shotgun's dict"
else
	echo "FAIL: spawnDict - expected to see a spawned idMoveableItem_moveable_item_shotgun_* entity name in the log"
	FAIL=1
fi

# --- footPrint: the footprints counter (ChexTrekDump.cpp) rises across the trigger, not just
# "ends up above zero" (which the AI's own idle behavior could satisfy on its own without proving
# our leftFoot() call did anything). The scenario's 5th and 6th chextrek_dump calls are,
# respectively, the baseline right before chextrek_footprint_actor is even spawned and the
# reading right after triggering its leftFoot() - see the console script above.
FOOTPRINTS_COUNTS="$(grep -oE '^footprints: [0-9]+' "$LOCAL_LOG" | grep -oE '[0-9]+$')"
FOOTPRINTS_BASELINE="$(echo "$FOOTPRINTS_COUNTS" | sed -n '3p')"
FOOTPRINTS_AFTER="$(echo "$FOOTPRINTS_COUNTS" | sed -n '4p')"
if [ -n "$FOOTPRINTS_BASELINE" ] && [ -n "$FOOTPRINTS_AFTER" ] && [ "$FOOTPRINTS_AFTER" -gt "$FOOTPRINTS_BASELINE" ]; then
	echo "PASS: footPrint - a decal was projected (chextrek_dump's footprints counter went from ${FOOTPRINTS_BASELINE} to ${FOOTPRINTS_AFTER})"
else
	echo "FAIL: footPrint - expected chextrek_dump's footprints counter to rise across the trigger, got '${FOOTPRINTS_BASELINE}' then '${FOOTPRINTS_AFTER}'"
	FAIL=1
fi

# --- remove: a script's remove() call actually shrinks the live entity count ---
# Same 5 chextrek_dump calls as above: the 4th is right before chextrek_removeme.remove(), the
# 5th right after.
ENTITY_COUNTS="$(grep -oE '^entities: [0-9]+' "$LOCAL_LOG" | grep -oE '[0-9]+$')"
BEFORE_REMOVE="$(echo "$ENTITY_COUNTS" | sed -n '4p')"
AFTER_REMOVE="$(echo "$ENTITY_COUNTS" | sed -n '5p')"
if [ -n "$BEFORE_REMOVE" ] && [ -n "$AFTER_REMOVE" ] && [ "$AFTER_REMOVE" -eq $(( BEFORE_REMOVE - 1 )) ]; then
	echo "PASS: remove - entities went from ${BEFORE_REMOVE} to ${AFTER_REMOVE} after chextrek_removeme.remove()"
else
	echo "FAIL: remove - expected the 5th entity count to be exactly one less than the 4th, got '${BEFORE_REMOVE}' then '${AFTER_REMOVE}'"
	FAIL=1
fi

# --- map finishes loading (spec #28 always-on check): e1m1's own load-complete log line ---
if grep -qE '^ *[0-9]+ msec to load e1m1$' "$LOCAL_LOG"; then
	echo "PASS: e1m1 finished loading"
else
	echo "FAIL: expected to see '<N> msec to load e1m1' in the log"
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
