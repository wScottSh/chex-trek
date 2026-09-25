#!/usr/bin/env bash
# Automated test for spec #31's acceptance criteria: triggering a trigger_objective (mkObjective)
# shows it in the dump's objective slots, a second trigger empties the slot, the state survives
# save/load, and sf_923 spawns both of its trigger_objective entities with no errors. See
# docs/harness-coverage.md.
#
# Drives sf_923 (spec #28's real second map, the only map with trigger_objective entities per
# decomp-so/reference/objectives.md's Notes) through console commands only (map, trigger,
# savegame, loadgame, wait, chextrek_dump, screenshot), per spec #28's testing decisions.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRATCH_DIR="$(mktemp -d)"
trap 'rm -rf "$SCRATCH_DIR"' EXIT

echo "=== #31 objectives test: build ==="
if ! bash "${SCRIPT_DIR}/build-chextrek.sh"; then
	echo "FAIL: build-chextrek.sh failed"
	exit 1
fi

# sf_923's two trigger_objective entities (maps/sf_923.map): trigger_objective_1 ("Acquire a
# weapon", addmsg+rmmsg+remove) and trigger_objective_2 ("Investigate", addmsg+remove, no rmmsg).
# Triggering _1 fills objective_slot_1 (addObjective hands out slots in order, starting at
# nextObjective); triggering _2 next fills objective_slot_2. Triggering _1 again removes it
# (Event_Activate's "on the list" branch): freeObjective empties its slot without disturbing _2's.
# A save/load round-trip after that must show the same two slots (mkObjective::Restore
# re-attaches anything left `active` half a second after load - see the comment on `wait 150`
# below for why the scenario waits that long past the load).
CONSOLE_SCRIPT="${SCRATCH_DIR}/objectives.cfg"
cat > "$CONSOLE_SCRIPT" <<'EOF'
developer 1
map sf_923
wait 20
chextrek_dump

trigger trigger_objective_1
wait 10
chextrek_dump

trigger trigger_objective_2
wait 10
chextrek_dump

trigger trigger_objective_1
wait 10
chextrek_dump

savegame chextrek_objectives_test
wait 20
loadgame chextrek_objectives_test
wait 150
chextrek_dump

screenshot chextrek_objectives
wait 10
quit
EOF

echo
echo "=== #31 objectives test: scenario run ==="
RUN_OUT="$(bash "${SCRIPT_DIR}/run-scenario.sh" chextrek_objectives "$CONSOLE_SCRIPT" 120 2>&1)"
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

# --- sf_923 spawns both trigger_objective entities with no errors ---
# The always-on unknown-spawnclass/ERROR checks above already fail the run if either entity
# couldn't spawn (mkObjective not found), or a script/data error printed. Belt-and-suspenders: the
# map's own load-complete line, confirming sf_923 (not some other map) is what actually loaded.
if grep -qE '^ *[0-9]+ msec to load sf_923$' "$LOCAL_LOG"; then
	echo "PASS: sf_923 finished loading (both trigger_objective entities spawned - see the always-on checks above)"
else
	echo "FAIL: expected to see '<N> msec to load sf_923' in the log"
	FAIL=1
fi

# There are 5 chextrek_dump calls (see the console script above): baseline, after triggering _1,
# after triggering _2, after triggering _1 again (the removal), and after the save/load round-trip.
SLOT1_VALUES="$(grep -oE '^objective_slot_1: .*$' "$LOCAL_LOG" | sed 's/^objective_slot_1: //')"
SLOT2_VALUES="$(grep -oE '^objective_slot_2: .*$' "$LOCAL_LOG" | sed 's/^objective_slot_2: //')"
S1_BASELINE="$(echo "$SLOT1_VALUES" | sed -n '1p')"
S1_AFTER_TRIGGER1="$(echo "$SLOT1_VALUES" | sed -n '2p')"
S1_AFTER_TRIGGER2="$(echo "$SLOT1_VALUES" | sed -n '3p')"
S1_AFTER_REMOVE="$(echo "$SLOT1_VALUES" | sed -n '4p')"
S2_BASELINE="$(echo "$SLOT2_VALUES" | sed -n '1p')"
S2_AFTER_TRIGGER2="$(echo "$SLOT2_VALUES" | sed -n '3p')"
S2_AFTER_REMOVE="$(echo "$SLOT2_VALUES" | sed -n '4p')"

# For each numbered chextrek_dump call, the sorted set of non-empty objective titles across all
# MAX_OBJS slots (not just slot_1/slot_2 above) - used for the save/load check below, because
# decomp-so/reference/objectives.md's Notes record that reattachment after a load is NOT
# slot-stable: "Objectives are re-added in the order their Restore events fire" against a
# nextObjective that Init() resets to 0, so a lone active objective can come back in a different
# slot than it had before the save (confirmed live: trigger_objective_2, the only one still
# active going into the save below, comes back as objective_slot_1, not _2). That is the
# reconstructed mod's actual (if surprising) behavior, not a harness bug - spec #28 targets the
# original behavior, not an enhancement. AC2 ("the dump shows the same objective slots") is
# checked as "the same set of active objectives", which is what the log can actually prove.
dump_active_set() {
	# Counts dump blocks by "objective_slot_1:" (always the first of the 5 objective lines a
	# given chextrek_dump call prints), not by the "CHEXTREK-STATE-DUMP v1" header - the header
	# also prints once, alone, at idGameLocal::Init (ChexTrekDump.h), which would otherwise
	# throw off a header-based count by one.
	awk -v n="$1" '
		/^objective_slot_1: / { c++ }
		c==n && /^objective_slot_[0-9]+: / {
			sub( /^objective_slot_[0-9]+: /, "" );
			if ( $0 != "empty" ) print;
		}
	' "$LOCAL_LOG" | sort
}
DUMP4_ACTIVE="$(dump_active_set 4)"
DUMP5_ACTIVE="$(dump_active_set 5)"

# --- triggering an objective shows it in the dump's slots (spec #31 AC1, part 1) ---
if [ "$S1_BASELINE" = "empty" ] && [ "$S1_AFTER_TRIGGER1" = "Acquire a weapon" ]; then
	echo "PASS: triggering trigger_objective_1 filled objective_slot_1 with its title"
else
	echo "FAIL: expected objective_slot_1 to go from 'empty' to 'Acquire a weapon' after triggering trigger_objective_1, got '${S1_BASELINE}' then '${S1_AFTER_TRIGGER1}'"
	FAIL=1
fi

if [ "$S2_BASELINE" = "empty" ] && [ "$S2_AFTER_TRIGGER2" = "Investigate" ]; then
	echo "PASS: triggering trigger_objective_2 filled objective_slot_2 with its title (both trigger_objective entities are independently wired)"
else
	echo "FAIL: expected objective_slot_2 to go from 'empty' to 'Investigate' after triggering trigger_objective_2, got '${S2_BASELINE}' then '${S2_AFTER_TRIGGER2}'"
	FAIL=1
fi

# --- a second trigger removes it (spec #31 AC1, part 2) - and does not disturb the other slot ---
if [ "$S1_AFTER_REMOVE" = "empty" ] && [ "$S2_AFTER_REMOVE" = "Investigate" ]; then
	echo "PASS: triggering trigger_objective_1 a second time emptied objective_slot_1, leaving objective_slot_2 untouched"
else
	echo "FAIL: expected objective_slot_1 empty and objective_slot_2 still 'Investigate' after the second trigger, got '${S1_AFTER_REMOVE}' and '${S2_AFTER_REMOVE}'"
	FAIL=1
fi

# --- save, load; the dump shows the same objective slots (spec #31 AC2) ---
if [ -n "$DUMP4_ACTIVE" ] && [ "$DUMP4_ACTIVE" = "$DUMP5_ACTIVE" ]; then
	echo "PASS: save/load round-trip - the same active objective(s) ('$(echo "$DUMP4_ACTIVE" | tr '\n' ',')') are present after loading as before saving"
else
	echo "FAIL: expected the same active objectives after load as before save ('$(echo "$DUMP4_ACTIVE" | tr '\n' ',')'), got '$(echo "$DUMP5_ACTIVE" | tr '\n' ',')'"
	FAIL=1
fi

echo
if [ $FAIL -eq 0 ]; then
	echo "PASS: #31 objectives scenario - trigger/re-trigger, save/load, and both sf_923 trigger_objective entities all show their observable effect"
	exit 0
else
	echo "FAIL: #31 objectives scenario - see above"
	exit 1
fi
