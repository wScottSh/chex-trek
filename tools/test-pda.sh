#!/usr/bin/env bash
# Automated test for spec #35's acceptance criteria:
#   AC1: with g_PDA set, opening the PDA shows the mod's PDA GUI (dump/log shows it's the active one)
#   AC2: g_PDA exists with GUI-name completion
# See docs/harness-coverage.md and decomp-so/reference/custom-ui.md.
#
# --- AC1 ---
# idPlayer::Spawn (Player.cpp) loads idPlayer::objectiveSystem from g_PDA's value instead of stock's
# hardcoded "guis/pda.gui" - the edit-inside-stock-function lead this sub-issue ports. g_PDA's
# default already happens to be "guis/pda_chex.gui" (the mod's own PDA GUI, which exists in this
# repo's data), so asserting the dump shows that value after a plain `map` wouldn't distinguish
# "idPlayer::Spawn reads g_PDA" from "idPlayer::Spawn still hardcodes guis/pda_chex.gui" - both
# would produce the same log line. To actually prove the cvar drives it, this scenario explicitly
# `set`s g_PDA to a *different* existing gui (stock's own guis/pda.gui, also present in this repo's
# data, guis/pda.gui) before `map`, and asserts idPlayer::objectiveSystem loads *that* value, not
# the mod's default - the AC's literal "with g_PDA set" wording, and the only way to tell the edit
# apart from a coincidental hardcoded match. chextrek_dump's new `pda_gui`/`pda_open` lines
# (ChexTrekDump.cpp) read idPlayer::objectiveSystem->Name() (the gui's own qpath) and
# idPlayer::objectiveSystemOpen.
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
# drive. Calling ArgCompletion_GuiName directly (with a hardcoded command name) would only prove
# that function exists, not that g_PDA is actually wired to it. `chextrek_test_gui_completion`
# (test-only, ChexTrekDump.cpp/.h, spec #35) closes that gap the same way chextrek_customui_cmd
# (#34) does for a GUI button click: it looks g_PDA up via cvarSystem->Find, reads its own
# idCVar::GetValueCompletion() - the exact function pointer real tab-completion would call - and
# prints whether the cvar was found, whether that pointer equals idCmdSystem::ArgCompletion_GuiName
# by address, and (calling it through that pointer) every result it produces. A scenario can then
# assert the cvar exists, is really wired to that function (not just some non-NULL one), and that
# one of the results names guis/pda_chex.gui (the mod's own default PDA gui).
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
set g_PDA "guis/pda.gui"
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

# --- AC1a: idPlayer::Spawn loaded objectiveSystem from g_PDA's explicitly-set value (not the
# mod's own default and not stock's hardcoded literal), proving the cvar - not a coincidental
# match - drives it ---
PDA_GUI_VALUES="$(grep -oE '^pda_gui: .*$' "$LOCAL_LOG" | sed 's/^pda_gui: //')"
PDA_OPEN_VALUES="$(grep -oE '^pda_open: [01]$' "$LOCAL_LOG" | grep -oE '[01]$')"
PDA_GUI_BASELINE="$(echo "$PDA_GUI_VALUES" | sed -n '1p')"
PDA_GUI_AFTER="$(echo "$PDA_GUI_VALUES" | sed -n '2p')"
PDA_OPEN_BASELINE="$(echo "$PDA_OPEN_VALUES" | sed -n '1p')"
PDA_OPEN_AFTER="$(echo "$PDA_OPEN_VALUES" | sed -n '2p')"

if [ "$PDA_GUI_BASELINE" = "guis/pda.gui" ]; then
	echo "PASS: idPlayer::objectiveSystem was loaded from g_PDA's explicitly-set value (guis/pda.gui, not the mod's own default guis/pda_chex.gui), right after spawn and before the PDA is ever opened - proving idPlayer::Spawn actually reads the cvar"
else
	echo "FAIL: expected pda_gui=guis/pda.gui (the value 'set g_PDA' was given) at baseline, got '${PDA_GUI_BASELINE}'"
	FAIL=1
fi

if [ "$PDA_OPEN_BASELINE" = "0" ]; then
	echo "PASS: the PDA starts closed (pda_open=0)"
else
	echo "FAIL: expected pda_open=0 at baseline, got '${PDA_OPEN_BASELINE}'"
	FAIL=1
fi

# --- AC1b: giving the player a PDA opens it, still showing the g_PDA-driven GUI ---
if [ "$PDA_OPEN_AFTER" = "1" ]; then
	echo "PASS: triggering the spawned item_pda opened the PDA (pda_open=0 -> 1)"
else
	echo "FAIL: expected pda_open=1 after the pickup, got '${PDA_OPEN_AFTER}'"
	FAIL=1
fi

if [ "$PDA_GUI_AFTER" = "guis/pda.gui" ]; then
	echo "PASS: the active PDA GUI when opened is still the one g_PDA named (guis/pda.gui)"
else
	echo "FAIL: expected pda_gui=guis/pda.gui after opening the PDA, got '${PDA_GUI_AFTER}'"
	FAIL=1
fi

# --- AC2: g_PDA exists and its value-completion is actually idCmdSystem::ArgCompletion_GuiName ---
if grep -qE '^g_pda_found: 1$' "$LOCAL_LOG"; then
	echo "PASS: g_PDA is a registered cvar (cvarSystem->Find succeeded)"
else
	echo "FAIL: expected g_pda_found: 1"
	FAIL=1
fi

if grep -qE '^g_pda_completion_wired: 1$' "$LOCAL_LOG"; then
	echo "PASS: g_PDA's own idCVar::GetValueCompletion() is idCmdSystem::ArgCompletion_GuiName"
else
	echo "FAIL: expected g_pda_completion_wired: 1 (g_PDA's registered completion function should be idCmdSystem::ArgCompletion_GuiName)"
	FAIL=1
fi

COMPLETION_COUNT="$(grep -oE '^gui_completion_count: [0-9]+$' "$LOCAL_LOG" | grep -oE '[0-9]+$' | sed -n '1p')"
if [ -n "$COMPLETION_COUNT" ] && [ "$COMPLETION_COUNT" -gt 0 ]; then
	echo "PASS: calling g_PDA's own completion function produced ${COMPLETION_COUNT} result(s)"
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
	echo "PASS: #35 PDA scenario - g_PDA drives which PDA GUI is loaded and shown when opened, with GUI-name completion actually wired to it"
	exit 0
else
	echo "FAIL: #35 PDA scenario - see above"
	exit 1
fi
