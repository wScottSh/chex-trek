#!/usr/bin/env bash
# Automated test for spec #35's acceptance criteria:
#   AC1: with g_PDA set, opening the PDA shows the mod's PDA GUI (dump/log shows it's the active one)
#   AC2: g_PDA exists with GUI-name completion
# See docs/harness-coverage.md and decomp-so/reference/custom-ui.md.
#
# --- AC1 ---
# idPlayer::Spawn (Player.cpp) loads idPlayer::objectiveSystem from g_PDA's value instead of stock's
# hardcoded "guis/pda.gui" - the edit-inside-stock-function lead this sub-issue ports. g_PDA's
# default is "guis/pda_chex.gui" (guis/pda_chex.gui exists in this repo's data), so a fresh spawn
# should already have the mod's own PDA GUI loaded as objectiveSystem, whether or not the PDA is
# ever opened. chextrek_dump's new `pda_gui`/`pda_open` lines (ChexTrekDump.cpp) read
# idPlayer::objectiveSystem->Name() (the gui's own qpath) and idPlayer::objectiveSystemOpen.
#
# "Opening the PDA" (idPlayer::TogglePDA) requires the player to actually own a PDA
# (inventory.pdas.Num() > 0) - it just shows a "no PDA" tip otherwise (Player.cpp). Neither e1m1 nor
# sf_923 places a PDA pickup reachable from spawn, so this scenario spawns one directly:
# def/items.def's item_pda (spawnclass idPDAItem) is exactly that - `spawn item_pda` is stock
# behavior (Cmd_Spawn_f, gamesys/SysCmds.cpp; ArgCompletion_Decl<DECL_ENTITYDEF> lists it), not
# anything ported by this sub-issue. `trigger <name>` (Cmd_Trigger_f) sends EV_Activate to the named
# entity with the local player as activator, synchronously, in the same frame - idItem::Event_Trigger
# treats a player activator as a pickup (Pickup -> GiveToPlayer -> idPDAItem::GiveToPlayer ->
# idPlayer::GivePDA). idPlayer::GivePDA itself calls TogglePDA() when this is the player's first PDA
# (inventory.pdas.Num() == 1) and the PDA isn't already open - both true here - so triggering the
# spawned item_pda both gives the PDA and opens it, without needing impulse/mouse input. (GivePDA
# also gates its "first PDA" behavior on gameLocal.GetFrameNum() > 10, hence the `wait 20` before
# spawning/triggering it.)
#
# --- AC2 ---
# idCmdSystem::ArgCompletion_GuiName (framework/CmdSystem.h) isn't reachable from a console script -
# it only ever runs from interactive tab-completion, which the console-only harness (spec #28) can't
# drive. `chextrek_test_gui_completion` (test-only, ChexTrekDump.cpp/.h, spec #35) closes that gap
# the same way chextrek_customui_cmd (#34) does for a GUI button click: it calls
# idCmdSystem::ArgCompletion_GuiName directly with "g_PDA" as the completed command name and dumps
# every result. A scenario can then assert the callback actually ran and that one of its results
# names guis/pda_chex.gui (g_PDA's own default value, proving the completion function that's wired
# to the cvar really does look at guis/*.gui, not just that *some* function got called).
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRATCH_DIR="$(mktemp -d)"
trap 'rm -rf "$SCRATCH_DIR"' EXIT

echo "=== #35 PDA test: build ==="
if ! bash "${SCRIPT_DIR}/build-chextrek.sh"; then
	echo "FAIL: build-chextrek.sh failed"
	exit 1
fi

CONSOLE_SCRIPT="${SCRATCH_DIR}/pda.cfg"
cat > "$CONSOLE_SCRIPT" <<'EOF'
developer 1
map e1m1
wait 20
chextrek_dump
chextrek_test_gui_completion

spawn item_pda pda_name chex_intro
trigger item_pda_1
wait 10
chextrek_dump

screenshot chextrek_pda
wait 10
quit
EOF

echo
echo "=== #35 PDA test: scenario run ==="
RUN_OUT="$(bash "${SCRIPT_DIR}/run-scenario.sh" chextrek_pda "$CONSOLE_SCRIPT" 90 2>&1)"
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

# --- AC1a: idPlayer::Spawn already loaded the mod's PDA GUI from g_PDA, before the PDA is opened ---
PDA_GUI_VALUES="$(grep -oE '^pda_gui: .*$' "$LOCAL_LOG" | sed 's/^pda_gui: //')"
PDA_OPEN_VALUES="$(grep -oE '^pda_open: [01]$' "$LOCAL_LOG" | grep -oE '[01]$')"
PDA_GUI_BASELINE="$(echo "$PDA_GUI_VALUES" | sed -n '1p')"
PDA_GUI_AFTER="$(echo "$PDA_GUI_VALUES" | sed -n '2p')"
PDA_OPEN_BASELINE="$(echo "$PDA_OPEN_VALUES" | sed -n '1p')"
PDA_OPEN_AFTER="$(echo "$PDA_OPEN_VALUES" | sed -n '2p')"

if [ "$PDA_GUI_BASELINE" = "guis/pda_chex.gui" ]; then
	echo "PASS: idPlayer::objectiveSystem is already loaded from g_PDA's default (guis/pda_chex.gui) right after spawn, before the PDA is ever opened"
else
	echo "FAIL: expected pda_gui=guis/pda_chex.gui at baseline, got '${PDA_GUI_BASELINE}'"
	FAIL=1
fi

if [ "$PDA_OPEN_BASELINE" = "0" ]; then
	echo "PASS: the PDA starts closed (pda_open=0)"
else
	echo "FAIL: expected pda_open=0 at baseline, got '${PDA_OPEN_BASELINE}'"
	FAIL=1
fi

# --- AC1b: giving the player a PDA opens it, still showing the mod's own PDA GUI ---
if [ "$PDA_OPEN_AFTER" = "1" ]; then
	echo "PASS: triggering the spawned item_pda opened the PDA (pda_open=0 -> 1)"
else
	echo "FAIL: expected pda_open=1 after the pickup, got '${PDA_OPEN_AFTER}'"
	FAIL=1
fi

if [ "$PDA_GUI_AFTER" = "guis/pda_chex.gui" ]; then
	echo "PASS: the active PDA GUI is still the mod's own (guis/pda_chex.gui), not stock's guis/pda.gui"
else
	echo "FAIL: expected pda_gui=guis/pda_chex.gui after opening the PDA, got '${PDA_GUI_AFTER}'"
	FAIL=1
fi

# --- AC2: g_PDA has GUI-name completion wired up ---
COMPLETION_COUNT="$(grep -oE '^gui_completion_count: [0-9]+$' "$LOCAL_LOG" | grep -oE '[0-9]+$' | sed -n '1p')"
if [ -n "$COMPLETION_COUNT" ] && [ "$COMPLETION_COUNT" -gt 0 ]; then
	echo "PASS: idCmdSystem::ArgCompletion_GuiName produced ${COMPLETION_COUNT} completion(s) for g_PDA"
else
	echo "FAIL: expected gui_completion_count > 0, got '${COMPLETION_COUNT}'"
	FAIL=1
fi

if grep -qE '^gui_completion_[0-9]+: .*pda_chex\.gui$' "$LOCAL_LOG"; then
	echo "PASS: g_PDA's completion list includes the mod's own default PDA gui (guis/pda_chex.gui)"
else
	echo "FAIL: expected a gui_completion_N line ending in pda_chex.gui"
	FAIL=1
fi

echo
if [ $FAIL -eq 0 ]; then
	echo "PASS: #35 PDA scenario - g_PDA loads and shows the mod's PDA GUI, with GUI-name completion"
	exit 0
else
	echo "FAIL: #35 PDA scenario - see above"
	exit 1
fi
