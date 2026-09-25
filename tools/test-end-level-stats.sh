#!/usr/bin/env bash
# Automated test for spec #33's acceptance criteria: killing a spawned monster, picking up an
# item and triggering a secret each raise idPlayer::levelStats by exactly one; triggering a
# target_endlevelgui shows the stats custom UI active with the counted values; both e1m1 and
# sf_923 spawn their target_endlevelgui entities with no errors. See docs/harness-coverage.md.
#
# Drives e1m1 (spec #28's real first map) for AC1/AC2, plus a second, shorter sf_923 run for the
# "both maps" half of AC3 (e1m1's own run already proves its half via the always-on
# unknown-spawnclass check, now that idTarget_EndLevelGUI is ported and #30/#31/#32's allowlist for
# it is gone - tools/lib-harness.sh), through console commands only (map, spawn, script, trigger,
# wait, chextrek_dump, screenshot), per spec #28's testing decisions.
#
# g_statTicTime (decomp-so/reference/end-level-stats.md's cvar, default 50ms between stats-screen
# tics) is set to 1 up front so the counting animation catches up in well under a second of engine
# time instead of needing up to ~100 tics * 50ms per line - the AC only needs the screen to show
# the counted values, not to watch the real default pacing.
#
# "Kill a spawned monster" needs the kill credited to the *player* (idAI::Killed only calls
# idPlayer::AddAIKill when attacker->IsType(idPlayer::Type) - see the edits-inside-stock-functions
# lead in Player.cpp/AddAIKill). The "kill" script event (idAI::Event_Kill) doesn't do that: it
# calls Killed(this, this, ...) with the AI itself as attacker. sys.radiusDamage(origin, inflictor,
# attacker, ignore, damageDefName, dmgPower) (idThread::Event_RadiusDamage -> idGameLocal::
# RadiusDamage) lets a script pick the attacker explicitly, so this scenario spawns a monster,
# then radius-damages it (damage_rocketSplash, def/weapon_rocketlauncher.def: damage 150, radius
# 175 - comfortably lethal and comfortably reaching a monster spawned 80 units from the player, per
# Cmd_Spawn_f) with both inflictor and attacker set to the player entity, and the player itself
# passed as the "ignore" entity so the player isn't hit by its own splash.
#
# "Pick up an item" and "trigger a secret" reuse the pattern tools/test-item-text.sh already
# proved: "trigger <name>" (Cmd_Trigger_f) sends EV_Activate to a named entity with the local
# player as activator, which is enough to run idItem::Event_Trigger's Pickup(player) path for an
# item and idDoor::Event_Activate's open path for a secret-flagged mover (e1m1's func_door_16,
# secret "1", not locked) - no physical movement needed. The item is a freshly *spawned*
# ammo_bullets_small (def/ammo.def, level_item "1"), not one of e1m1's own placed items (e.g.
# chex_fruit_bowl_3, inv_health "25"): idPlayer::GiveItem(idItem*) only counts a pickup
# (levelStats[1].found++) when it both actually "gave" something (Give() returned true for at
# least one attribute - Player.cpp) AND the item's own spawnArgs has "level_item" "1" (checked
# against the binary disassembly - see docs/harness-coverage.md's Custom UI row). A health-only
# item like chex_fruit_bowl_3 fails the first condition too (the player spawns at full health, so
# Give() fails silently), but even a health item that did give something would still need
# "level_item" to count. A freshly spawned ammo item the player can't already be maxed out on
# (inv_ammo_bullets "12") always satisfies both.
#
# The usual test-only cvar workaround (chextrek_test_str1..9, ChexTrekDump.cpp) is needed for the
# "script" line's string-literal/entity-name arguments - see its comment there, and
# tools/test-script-events.sh's file header, for why.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRATCH_DIR="$(mktemp -d)"
trap 'rm -rf "$SCRATCH_DIR"' EXIT

echo "=== #33 end-level-stats test: build ==="
if ! bash "${SCRIPT_DIR}/build-chextrek.sh"; then
	echo "FAIL: build-chextrek.sh failed"
	exit 1
fi

FAIL=0

# --- e1m1: AC1 (kill/pickup/secret each raise levelStats by one) and AC2 (triggering
# target_endlevelgui_1 shows the custom UI active with the counted values) ---
CONSOLE_SCRIPT="${SCRATCH_DIR}/end-level-stats-e1m1.cfg"
cat > "$CONSOLE_SCRIPT" <<'EOF'
developer 1
set g_statTicTime 1
map e1m1
wait 20
chextrek_dump

spawn monster_flemoid name chextrek_removeme
wait 10
chextrek_dump

script sys.radiusDamage( sys.getEntity( $chextrek_test_str4 ).getWorldOrigin(), sys.getEntity( $chextrek_test_str6 ), sys.getEntity( $chextrek_test_str6 ), sys.getEntity( $chextrek_test_str6 ), $chextrek_test_str9, 1 )
wait 10
chextrek_dump

spawn ammo_bullets_small name chextrek_item_test
wait 10
chextrek_dump

trigger chextrek_item_test
wait 10
chextrek_dump

trigger func_door_16
wait 10
chextrek_dump

trigger target_endlevelgui_1
wait 80
chextrek_dump

screenshot chextrek_end_level_stats_e1m1
wait 10
quit
EOF

echo
echo "=== #33 end-level-stats test: e1m1 scenario run ==="
RUN_OUT="$(bash "${SCRIPT_DIR}/run-scenario.sh" chextrek_end_level_stats_e1m1 "$CONSOLE_SCRIPT" 90 2>&1)"
RUN_EXIT=$?
echo "$RUN_OUT"

if [ $RUN_EXIT -ne 0 ]; then
	echo "FAIL: expected the always-on harness checks to pass (chextrek.dll loaded, state-dump header, no ERROR/unknown-event/unknown-spawnclass/script-compile lines - including e1m1's target_endlevelgui_1 spawning with no error, AC3), but the run exited ${RUN_EXIT}"
	FAIL=1
fi

LOCAL_LOG="$(echo "$RUN_OUT" | sed -n 's/^CHEXTREK_LOCAL_LOG=//p')"
if [ -z "$LOCAL_LOG" ] || [ ! -f "$LOCAL_LOG" ]; then
	echo "FAIL: couldn't find the archived log to check scenario-specific assertions"
	exit 1
fi

if grep -qE "^Error: |Unknown command|Unknown punctuation" "$LOCAL_LOG"; then
	echo "FAIL: a 'script' console line failed to compile/run - see the log for 'Error:'/'Unknown command'/'Unknown punctuation' lines"
	echo "$(grep -nE "^Error: |Unknown command|Unknown punctuation" "$LOCAL_LOG")"
	FAIL=1
fi

# There are 7 chextrek_dump calls in order: (1) baseline after map load, (2) after spawning the
# monster, (3) after radius-damaging it, (4) after spawning the ammo item, (5) after picking it up,
# (6) after triggering the secret door, (7) after triggering target_endlevelgui_1 and letting it
# count up.
LEVEL_STATS_LINES="$(grep -oE '^level_stats: monsters=[0-9]+/[0-9]+ items=[0-9]+/[0-9]+ secrets=[0-9]+/[0-9]+$' "$LOCAL_LOG")"
MONSTERS_FOUND="$(echo "$LEVEL_STATS_LINES" | sed -n 's/^level_stats: monsters=\([0-9]*\)\/.*/\1/p')"
ITEMS_FOUND="$(echo "$LEVEL_STATS_LINES" | sed -n 's/.*items=\([0-9]*\)\/.*/\1/p')"
SECRETS_FOUND="$(echo "$LEVEL_STATS_LINES" | sed -n 's/.*secrets=\([0-9]*\)\/.*/\1/p')"

MONSTERS_BEFORE="$(echo "$MONSTERS_FOUND" | sed -n '2p')"
MONSTERS_AFTER="$(echo "$MONSTERS_FOUND" | sed -n '3p')"
if [ -n "$MONSTERS_BEFORE" ] && [ -n "$MONSTERS_AFTER" ] && [ "$MONSTERS_AFTER" -eq $(( MONSTERS_BEFORE + 1 )) ]; then
	echo "PASS: killing chextrek_removeme raised level_stats' monsters-found by exactly one (${MONSTERS_BEFORE} -> ${MONSTERS_AFTER})"
else
	echo "FAIL: expected monsters-found to rise by exactly 1 across the kill, got '${MONSTERS_BEFORE}' then '${MONSTERS_AFTER}' (all: ${MONSTERS_FOUND})"
	FAIL=1
fi

ITEMS_BEFORE="$(echo "$ITEMS_FOUND" | sed -n '4p')"
ITEMS_AFTER="$(echo "$ITEMS_FOUND" | sed -n '5p')"
if [ -n "$ITEMS_BEFORE" ] && [ -n "$ITEMS_AFTER" ] && [ "$ITEMS_AFTER" -eq $(( ITEMS_BEFORE + 1 )) ]; then
	echo "PASS: picking up chextrek_item_test raised level_stats' items-found by exactly one (${ITEMS_BEFORE} -> ${ITEMS_AFTER})"
else
	echo "FAIL: expected items-found to rise by exactly 1 across the pickup, got '${ITEMS_BEFORE}' then '${ITEMS_AFTER}' (all: ${ITEMS_FOUND})"
	FAIL=1
fi

SECRETS_BEFORE="$(echo "$SECRETS_FOUND" | sed -n '5p')"
SECRETS_AFTER="$(echo "$SECRETS_FOUND" | sed -n '6p')"
if [ -n "$SECRETS_BEFORE" ] && [ -n "$SECRETS_AFTER" ] && [ "$SECRETS_AFTER" -eq $(( SECRETS_BEFORE + 1 )) ]; then
	echo "PASS: triggering the secret func_door_16 raised level_stats' secrets-found by exactly one (${SECRETS_BEFORE} -> ${SECRETS_AFTER})"
else
	echo "FAIL: expected secrets-found to rise by exactly 1 across the secret door, got '${SECRETS_BEFORE}' then '${SECRETS_AFTER}' (all: ${SECRETS_FOUND})"
	FAIL=1
fi

CUSTOMUI_LINES="$(grep -oE '^customui: [a-z]+$' "$LOCAL_LOG" | grep -oE '[a-z]+$')"
CUSTOMUI_BEFORE="$(echo "$CUSTOMUI_LINES" | sed -n '6p')"
CUSTOMUI_AFTER="$(echo "$CUSTOMUI_LINES" | sed -n '7p')"
if [ "$CUSTOMUI_BEFORE" = "none" ] && [ "$CUSTOMUI_AFTER" = "active" ]; then
	echo "PASS: customui went from 'none' to 'active' after triggering target_endlevelgui_1"
else
	echo "FAIL: expected customui 'none' then 'active', got '${CUSTOMUI_BEFORE}' then '${CUSTOMUI_AFTER}'"
	FAIL=1
fi

# With g_statTicTime set to 1, the stats screen's counting animation (idTarget_EndLevelGUI::
# Event_UpdateStats/updateStats) needs only a handful of tics to catch the monsters/items/secrets
# lines (0-2) up to their actual small counts - reaching 100% for each takes at most a couple-dozen
# tics even in the worst case, since e1m1 has a few dozen monsters/items/secrets total and this
# scenario only raises one of each. This deliberately checks right after those first few tics (the
# "wait 80" above, right after triggering target_endlevelgui_1), not after the full ~4-line
# animation (which also counts level_time, up to ~100 more tics, then a fixed 3000ms pause before
# the screen unregisters itself and leaves via ActivateTargets - waiting that long risks the dump
# landing after the screen has already closed and gone back to "customui: none"). This checks
# against the actual level_stats value read from the log (MONSTERS_AFTER/ITEMS_AFTER/
# SECRETS_AFTER, all 1 as of the idPlayer::GiveItem level_item fix - e1m1's baseline items-found is
# 0 before this scenario does anything) rather than assuming a hardcoded expected count.
LAST_AI_KILLED="$(grep -oE '^customui_gui_ai_killed: [0-9]+$' "$LOCAL_LOG" | tail -1 | grep -oE '[0-9]+$')"
LAST_ITEMS_FOUND="$(grep -oE '^customui_gui_items_found: [0-9]+$' "$LOCAL_LOG" | tail -1 | grep -oE '[0-9]+$')"
LAST_SECRETS_FOUND="$(grep -oE '^customui_gui_secrets_found: [0-9]+$' "$LOCAL_LOG" | tail -1 | grep -oE '[0-9]+$')"
if [ -n "$MONSTERS_AFTER" ] && [ -n "$ITEMS_AFTER" ] && [ -n "$SECRETS_AFTER" ] \
	&& [ "$LAST_AI_KILLED" = "$MONSTERS_AFTER" ] && [ "$LAST_ITEMS_FOUND" = "$ITEMS_AFTER" ] && [ "$LAST_SECRETS_FOUND" = "$SECRETS_AFTER" ]; then
	echo "PASS: the stats screen's own GUI state (customui_gui_ai_killed/items_found/secrets_found) shows the counted values (${LAST_AI_KILLED}/${LAST_ITEMS_FOUND}/${LAST_SECRETS_FOUND}, matching level_stats)"
else
	echo "FAIL: expected the stats screen's ai_killed/items_found/secrets_found GUI vars to match level_stats (${MONSTERS_AFTER}/${ITEMS_AFTER}/${SECRETS_AFTER}), got '${LAST_AI_KILLED}'/'${LAST_ITEMS_FOUND}'/'${LAST_SECRETS_FOUND}'"
	FAIL=1
fi

if grep -qE '^ *[0-9]+ msec to load e1m1$' "$LOCAL_LOG"; then
	echo "PASS: e1m1 finished loading"
else
	echo "FAIL: expected to see '<N> msec to load e1m1' in the log"
	FAIL=1
fi

# --- sf_923: the other half of AC3 (its own target_endlevelgui_1/_2 spawn with no errors - the
# always-on check above, now that the #30/#31/#32 allowlist for idTarget_EndLevelGUI is gone) ---
CONSOLE_SCRIPT_SF923="${SCRATCH_DIR}/end-level-stats-sf923.cfg"
cat > "$CONSOLE_SCRIPT_SF923" <<'EOF'
developer 1
set g_statTicTime 1
map sf_923
wait 20
chextrek_dump

trigger target_endlevelgui_1
wait 100
chextrek_dump

screenshot chextrek_end_level_stats_sf923
wait 10
quit
EOF

echo
echo "=== #33 end-level-stats test: sf_923 scenario run ==="
RUN_OUT_SF923="$(bash "${SCRIPT_DIR}/run-scenario.sh" chextrek_end_level_stats_sf923 "$CONSOLE_SCRIPT_SF923" 90 2>&1)"
RUN_EXIT_SF923=$?
echo "$RUN_OUT_SF923"

if [ $RUN_EXIT_SF923 -ne 0 ]; then
	echo "FAIL: expected the always-on harness checks to pass on sf_923 too (including target_endlevelgui_1/_2 spawning with no error, AC3), but the run exited ${RUN_EXIT_SF923}"
	FAIL=1
fi

LOCAL_LOG_SF923="$(echo "$RUN_OUT_SF923" | sed -n 's/^CHEXTREK_LOCAL_LOG=//p')"
if [ -z "$LOCAL_LOG_SF923" ] || [ ! -f "$LOCAL_LOG_SF923" ]; then
	echo "FAIL: couldn't find the archived sf_923 log to check scenario-specific assertions"
	exit 1
fi

SF923_CUSTOMUI="$(grep -oE '^customui: [a-z]+$' "$LOCAL_LOG_SF923" | grep -oE '[a-z]+$')"
SF923_CUSTOMUI_BEFORE="$(echo "$SF923_CUSTOMUI" | sed -n '1p')"
SF923_CUSTOMUI_AFTER="$(echo "$SF923_CUSTOMUI" | sed -n '2p')"
if [ "$SF923_CUSTOMUI_BEFORE" = "none" ] && [ "$SF923_CUSTOMUI_AFTER" = "active" ]; then
	echo "PASS: sf_923's target_endlevelgui_1 also spawns cleanly and shows its custom UI active when triggered"
else
	echo "FAIL: expected sf_923 customui 'none' then 'active', got '${SF923_CUSTOMUI_BEFORE}' then '${SF923_CUSTOMUI_AFTER}'"
	FAIL=1
fi

if grep -qE '^ *[0-9]+ msec to load sf_923$' "$LOCAL_LOG_SF923"; then
	echo "PASS: sf_923 finished loading"
else
	echo "FAIL: expected to see '<N> msec to load sf_923' in the log"
	FAIL=1
fi

echo
if [ $FAIL -eq 0 ]; then
	echo "PASS: #33 end-level-stats scenario - kill/pickup/secret each raise levelStats by one, triggering target_endlevelgui shows the custom UI active with the counted values, and both maps spawn their target_endlevelgui entities with no errors"
	exit 0
else
	echo "FAIL: #33 end-level-stats scenario - see above"
	exit 1
fi
