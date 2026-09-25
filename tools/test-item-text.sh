#!/usr/bin/env bash
# Automated test for spec #32's acceptance criteria: picking up an item shows its item text
# (idPlayer::addItemText, decomp-so/reference/objectives.md, ported #31). See docs/harness-coverage.md.
#
# addItemText's only callers in the reconstructed binary are mkObjective::AttachToLocalPlayer /
# RemoveFromLocalPlayer (objectives.md's Notes: "In the binary, these three are called only from
# mkObjective::AttachToLocalPlayer / RemoveFromLocalPlayer"), so "picking up an item" that shows
# item text means picking up an item that *targets* a trigger_objective. sf_923's own map data
# (maps/sf_923.map) wires this up, in this order:
#   1. trigger_once_6 (target3/target4) attaches BOTH trigger_objective_1 ("Acquire a weapon") and
#      trigger_objective_2 ("Investigate") - each shows its "addmsg", "New Objective".
#   2. moveable_item_pistol_1 (target1: trigger_objective_1) is picked up, which is trigger_objective_1's
#      SECOND trigger (mkObjective::Event_Activate's "on the list" branch): it removes the objective
#      and shows its "rmmsg", "Objective Complete" - not another "New Objective".
# This scenario reproduces that order (trigger_once_6 first, then the pickup) rather than picking
# the pistol up in isolation on a fresh map, so the item text it asserts ("Objective Complete") is
# the one an actual playthrough would see, not an order the map itself never produces. Picking the
# pistol up (idItem::Pickup -> ActivateTargets) is still what triggers the objective and calls
# addItemText - this reuses real map wiring rather than a synthetic fixture, per spec #28's testing
# decisions and the pattern in tools/test-objectives.sh.
#
# Drives sf_923 (spec #28's real second map) through console commands only (map, trigger, wait,
# chextrek_dump, screenshot), per spec #28's testing decisions.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRATCH_DIR="$(mktemp -d)"
trap 'rm -rf "$SCRATCH_DIR"' EXIT

echo "=== #32 item-text test: build ==="
if ! bash "${SCRIPT_DIR}/build-chextrek.sh"; then
	echo "FAIL: build-chextrek.sh failed"
	exit 1
fi

# "trigger <name>" (Cmd_Trigger_f, gamesys/SysCmds.cpp) sends EV_Activate to the named entity with
# the local player as activator. trigger_once_6 targets trigger_objective_1 and _2 directly
# (mkObjective::Event_Activate -> AttachToLocalPlayer(true) -> addItemText("New Objective") for
# each, since both set "addmsg"). moveable_item_pistol_1's event table maps EV_Activate to the
# inherited idItem::Event_Trigger, which calls Pickup(player) when the activator is a player and
# the item isn't triggerFirst-gated (it isn't): Pickup() -> GiveToPlayer() -> player->GiveItem()
# (a weapon, not inv_carry) plus ActivateTargets(player), which re-triggers trigger_objective_1 -
# now its SECOND activation, so mkObjective::Event_Activate's "on the list" branch runs
# RemoveFromLocalPlayer(true) -> addItemText("Objective Complete"), trigger_objective_1's "rmmsg".
CONSOLE_SCRIPT="${SCRATCH_DIR}/item-text.cfg"
cat > "$CONSOLE_SCRIPT" <<'EOF'
developer 1
map sf_923
wait 20
chextrek_dump

trigger trigger_once_6
wait 10
chextrek_dump

trigger moveable_item_pistol_1
wait 10
chextrek_dump

screenshot chextrek_item_text
wait 10
quit
EOF

echo
echo "=== #32 item-text test: scenario run ==="
RUN_OUT="$(bash "${SCRIPT_DIR}/run-scenario.sh" chextrek_item_text "$CONSOLE_SCRIPT" 90 2>&1)"
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

# --- sf_923 finishes loading (spec #28 always-on check) ---
if grep -qE '^ *[0-9]+ msec to load sf_923$' "$LOCAL_LOG"; then
	echo "PASS: sf_923 finished loading"
else
	echo "FAIL: expected to see '<N> msec to load sf_923' in the log"
	FAIL=1
fi

# --- picking up an item shows its item text (spec #32 AC) ---
# There are 3 chextrek_dump calls (see the console script above): baseline (before anything is
# triggered), after trigger_once_6 (attaches both objectives), and after picking up the pistol
# (removes trigger_objective_1). item_text_count/item_text_last (ChexTrekDump.cpp) record every
# idPlayer::addItemText call - baseline must be 0/"none", trigger_once_6 must raise the count by
# exactly 2 (one "New Objective" per objective it attaches) ending on "New Objective", and the
# pickup must raise the count by exactly 1 more, ending on "Objective Complete"
# (trigger_objective_1's "rmmsg") - proving the pickup, not the earlier trigger, is what produced
# that specific text.
COUNT_VALUES="$(grep -oE '^item_text_count: [0-9]+$' "$LOCAL_LOG" | grep -oE '[0-9]+$')"
LAST_VALUES="$(grep -oE '^item_text_last: .*$' "$LOCAL_LOG" | sed 's/^item_text_last: //')"
COUNT_BASELINE="$(echo "$COUNT_VALUES" | sed -n '1p')"
COUNT_AFTER_SETUP="$(echo "$COUNT_VALUES" | sed -n '2p')"
COUNT_AFTER_PICKUP="$(echo "$COUNT_VALUES" | sed -n '3p')"
LAST_BASELINE="$(echo "$LAST_VALUES" | sed -n '1p')"
LAST_AFTER_SETUP="$(echo "$LAST_VALUES" | sed -n '2p')"
LAST_AFTER_PICKUP="$(echo "$LAST_VALUES" | sed -n '3p')"

if [ "$COUNT_BASELINE" = "0" ] && [ "$LAST_BASELINE" = "none" ]; then
	echo "PASS: baseline - item_text_count is 0 and item_text_last is 'none' before anything is triggered"
else
	echo "FAIL: expected item_text_count=0 and item_text_last=none at baseline, got count='${COUNT_BASELINE}' last='${LAST_BASELINE}'"
	FAIL=1
fi

if [ -n "$COUNT_BASELINE" ] && [ -n "$COUNT_AFTER_SETUP" ] && [ "$COUNT_AFTER_SETUP" -eq $(( COUNT_BASELINE + 2 )) ] && [ "$LAST_AFTER_SETUP" = "New Objective" ]; then
	echo "PASS: trigger_once_6 attached both objectives, calling addItemText twice with 'New Objective' (item_text_count ${COUNT_BASELINE} -> ${COUNT_AFTER_SETUP})"
else
	echo "FAIL: expected item_text_count to rise by exactly 2 and item_text_last='New Objective' after trigger_once_6, got count='${COUNT_BASELINE}'->'${COUNT_AFTER_SETUP}' last='${LAST_AFTER_SETUP}'"
	FAIL=1
fi

if [ -n "$COUNT_AFTER_SETUP" ] && [ -n "$COUNT_AFTER_PICKUP" ] && [ "$COUNT_AFTER_PICKUP" -eq $(( COUNT_AFTER_SETUP + 1 )) ] && [ "$LAST_AFTER_PICKUP" = "Objective Complete" ]; then
	echo "PASS: picking up moveable_item_pistol_1 (which re-triggers trigger_objective_1) called idPlayer::addItemText with 'Objective Complete' (item_text_count ${COUNT_AFTER_SETUP} -> ${COUNT_AFTER_PICKUP})"
else
	echo "FAIL: expected item_text_count to rise by exactly 1 more and item_text_last='Objective Complete' after the pickup, got count='${COUNT_AFTER_SETUP}'->'${COUNT_AFTER_PICKUP}' last='${LAST_AFTER_PICKUP}'"
	FAIL=1
fi

echo
if [ $FAIL -eq 0 ]; then
	echo "PASS: #32 item-text scenario - picking up an item shows its item text"
	exit 0
else
	echo "FAIL: #32 item-text scenario - see above"
	exit 1
fi
