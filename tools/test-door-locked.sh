#!/usr/bin/env bash
# Automated test for spec #41's acceptance criteria (decomp-so/reference/door-opening.md,
# idPlayer::tryOpen's locked-door branches, ported as part of #40's whole-function port; #41 is
# the scenario coverage for those branches - see docs/harness-coverage.md).
#   AC1 (sf_923): use a door with lockedtext (no "requires"); the text is shown (log)
#   AC2 (e1m1): use a Blue Key door without the key; tip shown, door stays shut; give the key,
#     use again; the door opens
#
# tryOpen's unlocked-door branch (the use key opening an already-unlocked door, plus the
# g_doorTraceDist range check) is #40's own scenario (tools/test-door-open.sh) - not repeated
# here. Monster/AI door-opening (canopendoors, spec #42) is out of scope here too.
#
# `chextrek_test_impulse 16` (ChexTrekDump.cpp, spec #40) stands in for a real, currently-held
# bind key the same way tools/test-door-open.sh already uses it - see that script's header
# comment for why (no plain "impulse" console command, and "_impulse16" isn't recognized from a
# typed console line).
#
# `chextrek_line_field_values()` (tools/lib-harness.sh) is a shared helper for
# reading any `<field>: <rest of line>` chextrek_dump line's value, so the assertions below don't
# each repeat the same grep/sed pipeline - see lib-harness.sh's own header comment.
#
# `hud_tip_up`/`hud_tip_title`/`hud_tip_text` (ChexTrekDump.cpp, #41) read
# idPlayer::ShowTip's own HUD gui state directly (idPlayer::IsTipVisible(), hud->GetStateString
# "tiptitle"/"tip") - tryOpen's locked branches call the already-stock ShowTip, which logs
# nothing itself, so this is the only way a scenario can see the tip text/title from the log,
# without a new hook into already-ported code. `door_tryopen_count`/`door_tryopen_last` (#40)
# double-check the use-key trace actually reached the door in question each time, same technique
# tools/test-door-open.sh uses.
#
# Both doors used here are real, already-locked doors from the shipped maps (no synthetic
# fixture): sf_923's "hbdoor1" (locked "1", no "requires", "lockedtext" "This door is locked.  It
# can be opened at a console on the bridge.") and e1m1's "func_door_13" (locked "1", "requires"
# "Blue Key"). Neither is targeted by any *map* entity ("target<N>" key) in its own map data (grep
# confirms) - a "map_storage_facility.script" thread does reference hbdoor1/hbdoor2 by name
# (setKey/trigger calls), but nothing in this scenario's console script fires whatever triggers
# that thread, so it never runs here. Both doors have "no_touch" "1", so nothing but tryOpen's own
# EV_Activate can start them moving - both start closed and unmoved, and setviewpos/noclip
# teleporting near them can't itself trigger anything.
#
# sf_923 also has a second "lockedtext" door, "brokendoor" (maps/sf_923.map, entity 74) - not used
# here: it sits immediately adjacent to a second, unlocked "unbrokendoor" (entity 178, no
# "locked"/"lockedtext" keys) at essentially the same origin, one behind the other along their
# shared thin axis. Both are spawned and solid by default (script/map_storage_facility.script
# only hides one and shows the other on a separate, unrelated trigger this scenario doesn't fire),
# and probing this pair (several tried approach points/angles) kept landing tryOpen's trace on
# "unbrokendoor" - a `door_tryopen_last` mismatch is the direct proof, not merely inferred. Using
# "hbdoor1" instead sidesteps that overlap entirely: it has no unlocked twin standing in its own
# doorway, confirmed by an actual harness run showing `door_tryopen_last: hbdoor1` and the exact
# lockedtext go through.
#
# Approach points: func_door_13's brush primitive has two axis-aligned "door1"-textured planes a
# few units off the entity's own origin along one axis (the door's thin/thickness axis) - see the
# brush primitive in maps/e1m1.map (entity 55), not restated here since only this harness run
# proves the geometry; it's thin along world X, so the e1m1 view position below stands off on the
# +X side of the door's origin, facing -X (yaw 180), the same technique tools/test-door-open.sh
# uses for sf_923's own func_door_1/func_door_24. hbdoor1/hbdoor2 use a mesh model (no brush
# primitive in the .map to read plane offsets from), so their approach point/facing below was
# found the same way the brokendoor/unbrokendoor probing above was - an actual harness run,
# checked against `door_tryopen_last` - rather than derived from the map text alone.
#
# "noclip" (stock, CMD_FL_CHEAT) is set once up front so each `setviewpos` teleport can't be
# blocked or corrected by collision; it doesn't affect tryOpen's own world trace
# (gameLocal.clip.Translation), same reasoning as tools/test-door-open.sh.
#
# For AC2's "give the key": e1m1 has no reachable Blue Key pickup positioned for a synthetic
# no-walk scenario, and there's no "give <item>" console path for a def named outside
# weapon_/item_/ammo_ prefixes (Cmd_Give_f, gamesys/SysCmds.cpp - def/chex.def's key is
# "chex_key_blue", which doesn't match any of those). Instead, same technique as tools/test-pda.sh
# (spawning+triggering item_pda): `spawn chex_key_blue name <n> origin "<x> <y> <z>"` spawns one
# (Cmd_Spawn_f, gamesys/SysCmds.cpp, lets any extra key/value pair - including "origin" - override
# its own computed default, so the key lands at a known-open point next to the door's approach
# spot rather than 80 units along the player's view forward, which would land past the door's own
# brush), then `trigger <n>` sends it idItem::Event_Trigger with the player as activator, picking
# it up synchronously (idItem::Pickup -> idPlayer::GiveItem, which records "Blue Key" into
# inventory.items' "inv_name" - the same field idGameLocal::RequirementMet's
# idPlayer::FindInventoryItem checks against tryOpen's door "requires" key). No impulse/mouse
# input needed for the pickup itself.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRATCH_DIR="$(mktemp -d)"
trap 'rm -rf "$SCRATCH_DIR"' EXIT

# shellcheck source=tools/lib-harness.sh
source "${SCRIPT_DIR}/lib-harness.sh"

echo "=== #41 locked-door test: build ==="
chextrek_build_or_exit

FAIL=0

# --- AC1 (sf_923): lockedtext, no "requires" ---
CONSOLE_SCRIPT_SF923="${SCRATCH_DIR}/door-locked-sf923.cfg"
cat > "$CONSOLE_SCRIPT_SF923" <<'EOF'
developer 1
map sf_923
wait 20
noclip
chextrek_dump
script sys.println( 41000 + sys.getEntity( $chextrek_test_str12 ).isOpen() )

setviewpos -1192 -446 40 270
wait 10
chextrek_test_impulse 16
wait 15
chextrek_dump
script sys.println( 41100 + sys.getEntity( $chextrek_test_str12 ).isOpen() )

screenshot chextrek_door_locked_sf923
wait 10
quit
EOF

echo
echo "=== #41 locked-door test: sf_923 scenario run ==="
chextrek_run_scenario chextrek_door_locked_sf923 "$CONSOLE_SCRIPT_SF923" 90 || FAIL=1

LOCAL_LOG_SF923="$CHEXTREK_SCENARIO_LOG"
if [ -z "$LOCAL_LOG_SF923" ]; then
	echo "FAIL: couldn't find the archived sf_923 log to check scenario-specific assertions"
	FAIL=1
else
	chextrek_assert_map_loaded "$LOCAL_LOG_SF923" sf_923 || FAIL=1

	COUNT_41000_SF923="$(grep -c '^41000$' "$LOCAL_LOG_SF923")"
	if [ "$COUNT_41000_SF923" -ge 1 ]; then
		echo "PASS: hbdoor1.isOpen() reports closed (41000) before the use impulse"
	else
		echo "FAIL: expected to see '41000' in the log before the use impulse"
		FAIL=1
	fi

	TIPUP_SF923_VALUES="$(chextrek_line_field_values "$LOCAL_LOG_SF923" hud_tip_up)"
	TIPUP_SF923_BASELINE="$(echo "$TIPUP_SF923_VALUES" | sed -n '1p')"
	TIPUP_SF923_AFTER="$(echo "$TIPUP_SF923_VALUES" | sed -n '2p')"
	if [ "$TIPUP_SF923_BASELINE" = "0" ] && [ "$TIPUP_SF923_AFTER" = "1" ]; then
		echo "PASS: hud_tip_up went from 0 to 1 after using the locked hbdoor1"
	else
		echo "FAIL: expected hud_tip_up 0 then 1, got '${TIPUP_SF923_BASELINE}' then '${TIPUP_SF923_AFTER}'"
		FAIL=1
	fi

	TIPTITLE_SF923="$(chextrek_line_field_values "$LOCAL_LOG_SF923" hud_tip_title | sed -n '2p')"
	if [ "$TIPTITLE_SF923" = "Door Locked" ]; then
		echo "PASS: hud_tip_title reads 'Door Locked'"
	else
		echo "FAIL: expected hud_tip_title 'Door Locked', got '${TIPTITLE_SF923}'"
		FAIL=1
	fi

	TIPTEXT_SF923="$(chextrek_line_field_values "$LOCAL_LOG_SF923" hud_tip_text | sed -n '2p')"
	if [ "$TIPTEXT_SF923" = "This door is locked.  It can be opened at a console on the bridge." ]; then
		echo "PASS: AC1 - hud_tip_text shows hbdoor1's own lockedtext"
	else
		echo "FAIL: expected hud_tip_text 'This door is locked.  It can be opened at a console on the bridge.', got '${TIPTEXT_SF923}'"
		FAIL=1
	fi

	TRYOPEN_COUNT_VALUES_SF923="$(chextrek_line_field_values "$LOCAL_LOG_SF923" door_tryopen_count)"
	TRYOPEN_COUNT_BASELINE_SF923="$(echo "$TRYOPEN_COUNT_VALUES_SF923" | sed -n '1p')"
	TRYOPEN_COUNT_AFTER_SF923="$(echo "$TRYOPEN_COUNT_VALUES_SF923" | sed -n '2p')"
	TRYOPEN_LAST_SF923="$(chextrek_line_field_values "$LOCAL_LOG_SF923" door_tryopen_last | sed -n '2p')"
	if [ -n "$TRYOPEN_COUNT_BASELINE_SF923" ] && [ -n "$TRYOPEN_COUNT_AFTER_SF923" ] \
		&& [ "$TRYOPEN_COUNT_AFTER_SF923" -eq $(( TRYOPEN_COUNT_BASELINE_SF923 + 1 )) ] \
		&& [ "$TRYOPEN_LAST_SF923" = "hbdoor1" ]; then
		echo "PASS: the use-key trace reached hbdoor1 (door_tryopen_count ${TRYOPEN_COUNT_BASELINE_SF923} -> ${TRYOPEN_COUNT_AFTER_SF923}, last=hbdoor1)"
	else
		echo "FAIL: expected door_tryopen_count to rise by exactly 1 and door_tryopen_last=hbdoor1, got count='${TRYOPEN_COUNT_BASELINE_SF923}'->'${TRYOPEN_COUNT_AFTER_SF923}' last='${TRYOPEN_LAST_SF923}'"
		FAIL=1
	fi

	COUNT_41100_SF923="$(grep -c '^41100$' "$LOCAL_LOG_SF923")"
	if [ "$COUNT_41100_SF923" -ge 1 ]; then
		echo "PASS: AC1 - hbdoor1 stays closed (41100) after the locked use"
	else
		echo "FAIL: expected to see '41100' in the log after the locked use"
		FAIL=1
	fi
fi

# --- AC2 (e1m1): "requires" "Blue Key" ---
CONSOLE_SCRIPT_E1M1="${SCRATCH_DIR}/door-locked-e1m1.cfg"
cat > "$CONSOLE_SCRIPT_E1M1" <<'EOF'
developer 1
map e1m1
wait 20
noclip
chextrek_dump
script sys.println( 42000 + sys.getEntity( $chextrek_test_str13 ).isOpen() )

setviewpos 514 1216 96 180
wait 10
chextrek_test_impulse 16
wait 15
chextrek_dump
script sys.println( 42100 + sys.getEntity( $chextrek_test_str13 ).isOpen() )

spawn chex_key_blue name chextrek_test_bluekey origin "500 1216 40"
trigger chextrek_test_bluekey
wait 10

chextrek_test_impulse 16
wait 15
chextrek_dump
script sys.println( 42200 + sys.getEntity( $chextrek_test_str13 ).isOpen() )

screenshot chextrek_door_locked_e1m1
wait 10
quit
EOF

echo
echo "=== #41 locked-door test: e1m1 scenario run ==="
chextrek_run_scenario chextrek_door_locked_e1m1 "$CONSOLE_SCRIPT_E1M1" 90 || FAIL=1

LOCAL_LOG_E1M1="$CHEXTREK_SCENARIO_LOG"
if [ -z "$LOCAL_LOG_E1M1" ]; then
	echo "FAIL: couldn't find the archived e1m1 log to check scenario-specific assertions"
	FAIL=1
else
	chextrek_assert_map_loaded "$LOCAL_LOG_E1M1" e1m1 || FAIL=1

	COUNT_42000_E1M1="$(grep -c '^42000$' "$LOCAL_LOG_E1M1")"
	if [ "$COUNT_42000_E1M1" -ge 1 ]; then
		echo "PASS: func_door_13.isOpen() reports closed (42000) before the use impulse"
	else
		echo "FAIL: expected to see '42000' in the log before the use impulse"
		FAIL=1
	fi

	TIPUP_E1M1_VALUES="$(chextrek_line_field_values "$LOCAL_LOG_E1M1" hud_tip_up)"
	TIPUP_E1M1_BASELINE="$(echo "$TIPUP_E1M1_VALUES" | sed -n '1p')"
	TIPUP_E1M1_AFTER="$(echo "$TIPUP_E1M1_VALUES" | sed -n '2p')"
	if [ "$TIPUP_E1M1_BASELINE" = "0" ] && [ "$TIPUP_E1M1_AFTER" = "1" ]; then
		echo "PASS: hud_tip_up went from 0 to 1 after using func_door_13 without the Blue Key"
	else
		echo "FAIL: expected hud_tip_up 0 then 1, got '${TIPUP_E1M1_BASELINE}' then '${TIPUP_E1M1_AFTER}'"
		FAIL=1
	fi

	TIPTITLE_E1M1="$(chextrek_line_field_values "$LOCAL_LOG_E1M1" hud_tip_title | sed -n '2p')"
	if [ "$TIPTITLE_E1M1" = "Door Locked" ]; then
		echo "PASS: hud_tip_title reads 'Door Locked' for the no-key use too"
	else
		echo "FAIL: expected hud_tip_title 'Door Locked', got '${TIPTITLE_E1M1}'"
		FAIL=1
	fi

	TIPTEXT_E1M1="$(chextrek_line_field_values "$LOCAL_LOG_E1M1" hud_tip_text | sed -n '2p')"
	if [ "$TIPTEXT_E1M1" = "You need a Blue Key to open this door." ]; then
		echo "PASS: AC2 - hud_tip_text names the required item (Blue Key)"
	else
		echo "FAIL: expected hud_tip_text 'You need a Blue Key to open this door.', got '${TIPTEXT_E1M1}'"
		FAIL=1
	fi

	TRYOPEN_COUNT_VALUES_E1M1="$(chextrek_line_field_values "$LOCAL_LOG_E1M1" door_tryopen_count)"
	TRYOPEN_COUNT_BASELINE_E1M1="$(echo "$TRYOPEN_COUNT_VALUES_E1M1" | sed -n '1p')"
	TRYOPEN_COUNT_AFTER_NOKEY_E1M1="$(echo "$TRYOPEN_COUNT_VALUES_E1M1" | sed -n '2p')"
	TRYOPEN_COUNT_AFTER_KEY_E1M1="$(echo "$TRYOPEN_COUNT_VALUES_E1M1" | sed -n '3p')"

	TRYOPEN_LAST_VALUES_E1M1="$(chextrek_line_field_values "$LOCAL_LOG_E1M1" door_tryopen_last)"
	TRYOPEN_LAST_AFTER_NOKEY="$(echo "$TRYOPEN_LAST_VALUES_E1M1" | sed -n '2p')"
	if [ -n "$TRYOPEN_COUNT_BASELINE_E1M1" ] && [ -n "$TRYOPEN_COUNT_AFTER_NOKEY_E1M1" ] \
		&& [ "$TRYOPEN_COUNT_AFTER_NOKEY_E1M1" -eq $(( TRYOPEN_COUNT_BASELINE_E1M1 + 1 )) ] \
		&& [ "$TRYOPEN_LAST_AFTER_NOKEY" = "func_door_13" ]; then
		echo "PASS: the use-key trace reached func_door_13 without the key too (door_tryopen_count ${TRYOPEN_COUNT_BASELINE_E1M1} -> ${TRYOPEN_COUNT_AFTER_NOKEY_E1M1}, last=func_door_13)"
	else
		echo "FAIL: expected door_tryopen_count to rise by exactly 1 and door_tryopen_last=func_door_13 after the no-key use, got count='${TRYOPEN_COUNT_BASELINE_E1M1}'->'${TRYOPEN_COUNT_AFTER_NOKEY_E1M1}' last='${TRYOPEN_LAST_AFTER_NOKEY}'"
		FAIL=1
	fi

	COUNT_42100_E1M1="$(grep -c '^42100$' "$LOCAL_LOG_E1M1")"
	if [ "$COUNT_42100_E1M1" -ge 1 ]; then
		echo "PASS: AC2 - func_door_13 stays shut (42100) after the use without the key"
	else
		echo "FAIL: expected to see '42100' in the log after the no-key use"
		FAIL=1
	fi

	TRYOPEN_LAST_AFTER_KEY="$(echo "$TRYOPEN_LAST_VALUES_E1M1" | sed -n '3p')"
	if [ -n "$TRYOPEN_COUNT_AFTER_NOKEY_E1M1" ] && [ -n "$TRYOPEN_COUNT_AFTER_KEY_E1M1" ] \
		&& [ "$TRYOPEN_COUNT_AFTER_KEY_E1M1" -eq $(( TRYOPEN_COUNT_AFTER_NOKEY_E1M1 + 1 )) ] \
		&& [ "$TRYOPEN_LAST_AFTER_KEY" = "func_door_13" ]; then
		echo "PASS: the use-key trace reached func_door_13 again after giving the key (door_tryopen_count ${TRYOPEN_COUNT_AFTER_NOKEY_E1M1} -> ${TRYOPEN_COUNT_AFTER_KEY_E1M1}, last=func_door_13)"
	else
		echo "FAIL: expected door_tryopen_count to rise by exactly 1 more and door_tryopen_last=func_door_13 after giving the key, got count='${TRYOPEN_COUNT_AFTER_NOKEY_E1M1}'->'${TRYOPEN_COUNT_AFTER_KEY_E1M1}' last='${TRYOPEN_LAST_AFTER_KEY}'"
		FAIL=1
	fi

	COUNT_42201_E1M1="$(grep -c '^42201$' "$LOCAL_LOG_E1M1")"
	if [ "$COUNT_42201_E1M1" -ge 1 ]; then
		echo "PASS: AC2 - func_door_13 opens (42201) once the Blue Key is given and the door is used again"
	else
		echo "FAIL: expected to see '42201' in the log after giving the key and using the door again"
		FAIL=1
	fi
fi

echo
if [ $FAIL -eq 0 ]; then
	echo "PASS: #41 locked-door scenario - lockedtext/requires tips show, and the door opens once the required item is given"
	exit 0
else
	echo "FAIL: #41 locked-door scenario - see above"
	exit 1
fi
