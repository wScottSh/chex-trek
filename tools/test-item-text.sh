#!/usr/bin/env bash
# Automated test for spec #32's acceptance criteria: picking up an item shows its item text
# (idPlayer::addItemText, decomp-so/reference/objectives.md, ported #31). See docs/harness-coverage.md.
#
# addItemText's only callers in the reconstructed binary are mkObjective::AttachToLocalPlayer /
# RemoveFromLocalPlayer (objectives.md's Notes: "In the binary, these three are called only from
# mkObjective::AttachToLocalPlayer / RemoveFromLocalPlayer"), so "picking up an item" that shows
# item text means picking up an item that *targets* a trigger_objective with an "addmsg" - exactly
# what sf_923's own map data already wires up (maps/sf_923.map): "moveable_item_pistol_1" targets
# "trigger_objective_1" ("Acquire a weapon", addmsg "New Objective") via its "target1" key. Picking
# the pistol up (idItem::Pickup -> ActivateTargets) triggers the objective, which calls
# addItemText("New Objective"). This reuses real map wiring rather than a synthetic fixture, per
# spec #28's testing decisions and the pattern in tools/test-objectives.sh.
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
# the local player as activator - idItem's event table maps EV_Activate to Event_Trigger, which
# calls Pickup(player) when the activator is a player and the item isn't triggerFirst-gated
# (moveable_item_pistol_1 isn't). Pickup() -> GiveToPlayer() -> player->GiveItem() (a weapon, not
# inv_carry) plus ActivateTargets(player), which fires trigger_objective_1
# (mkObjective::Event_Activate -> AttachToLocalPlayer(true) -> addItemText, since its addmsg is
# set). So one "trigger moveable_item_pistol_1" exercises the whole pickup -> item-text chain.
CONSOLE_SCRIPT="${SCRATCH_DIR}/item-text.cfg"
cat > "$CONSOLE_SCRIPT" <<'EOF'
developer 1
map sf_923
wait 20
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
# There are 2 chextrek_dump calls (see the console script above): baseline (before the pickup) and
# after triggering moveable_item_pistol_1. item_text_count/item_text_last (ChexTrekDump.cpp)
# record every idPlayer::addItemText call - baseline must be 0/"none" (nothing has called it yet
# this run), and the count must rise by exactly 1 with "New Objective" (trigger_objective_1's
# addmsg, maps/sf_923.map) as the last name shown, proving the pickup is what triggered it.
COUNT_VALUES="$(grep -oE '^item_text_count: [0-9]+$' "$LOCAL_LOG" | grep -oE '[0-9]+$')"
LAST_VALUES="$(grep -oE '^item_text_last: .*$' "$LOCAL_LOG" | sed 's/^item_text_last: //')"
COUNT_BASELINE="$(echo "$COUNT_VALUES" | sed -n '1p')"
COUNT_AFTER="$(echo "$COUNT_VALUES" | sed -n '2p')"
LAST_BASELINE="$(echo "$LAST_VALUES" | sed -n '1p')"
LAST_AFTER="$(echo "$LAST_VALUES" | sed -n '2p')"

if [ "$COUNT_BASELINE" = "0" ] && [ "$LAST_BASELINE" = "none" ]; then
	echo "PASS: baseline - item_text_count is 0 and item_text_last is 'none' before the pickup"
else
	echo "FAIL: expected item_text_count=0 and item_text_last=none before the pickup, got count='${COUNT_BASELINE}' last='${LAST_BASELINE}'"
	FAIL=1
fi

if [ -n "$COUNT_BASELINE" ] && [ -n "$COUNT_AFTER" ] && [ "$COUNT_AFTER" -eq $(( COUNT_BASELINE + 1 )) ] && [ "$LAST_AFTER" = "New Objective" ]; then
	echo "PASS: picking up moveable_item_pistol_1 (which targets trigger_objective_1) called idPlayer::addItemText with 'New Objective' (item_text_count ${COUNT_BASELINE} -> ${COUNT_AFTER})"
else
	echo "FAIL: expected item_text_count to rise by exactly 1 and item_text_last='New Objective' after the pickup, got count='${COUNT_BASELINE}'->'${COUNT_AFTER}' last='${LAST_AFTER}'"
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
