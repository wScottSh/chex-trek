#!/usr/bin/env bash
# Automated test for spec #35's acceptance criteria:
#   AC1: with g_PDA set, opening the PDA shows the mod's PDA GUI (dump/log shows it's the active one)
#   AC2: g_PDA exists with GUI-name completion
# See docs/harness-coverage.md and decomp-so/reference/custom-ui.md.
#
# --- AC1 ---
# idPlayer::Spawn (Player.cpp) loads idPlayer::objectiveSystem from g_PDA's value instead of stock's
# hardcoded "guis/pda.gui" - the edit-inside-stock-function lead this sub-issue ports. Two things
# need proving, and neither alone is enough:
#   1. idPlayer::Spawn actually reads g_PDA (not a hardcoded literal of any kind).
#   2. With g_PDA at its own default, opening the PDA shows the mod's actual PDA GUI (the AC's
#      literal wording).
# A single map load with g_PDA left at its default ("guis/pda_chex.gui") would only prove (2): it
# can't tell "idPlayer::Spawn reads the cvar" apart from "idPlayer::Spawn still hardcodes that same
# default by coincidence". So this scenario runs `map e1m1` twice in one console script (a fresh
# `map` re-runs idPlayer::Spawn, the only way to see two different g_PDA values take effect without
# two separate harness invocations):
#   - Phase 1 explicitly `set`s g_PDA to a *third*, unrelated existing gui (guis/chex_credits.gui -
#     neither stock's own hardcoded literal guis/pda.gui nor the mod's default guis/pda_chex.gui,
#     so a pass here can't be explained away by either of those matching by coincidence) before
#     `map`, proving (1).
#   - Phase 2 resets g_PDA to its own default and `map`s again, proving (2) with the mod's real,
#     shipped configuration - not just an arbitrary override.
# chextrek_dump's new `pda_gui`/`pda_open` lines (ChexTrekDump.cpp) read
# idPlayer::objectiveSystem->Name() (the gui's own qpath) and idPlayer::objectiveSystemOpen.
#
# "Opening the PDA" (idPlayer::TogglePDA) requires the player to actually own a PDA
# (inventory.pdas.Num() > 0) - it just shows a "no PDA" tip otherwise (Player.cpp). Neither e1m1 nor
# sf_923 places a PDA pickup reachable from spawn, so each phase spawns one directly:
# def/items.def's item_pda (spawnclass idPDAItem) is exactly that - `spawn item_pda` is stock
# behavior (Cmd_Spawn_f, gamesys/SysCmds.cpp; ArgCompletion_Decl<DECL_ENTITYDEF> lists it), not
# anything ported by this sub-issue. It's given an explicit `name` (rather than relying on
# Cmd_Spawn_f's auto-generated numbering, which restarts from the same counter on each fresh `map`
# and would give both phases' item_pda the same auto-generated name) so each phase's `trigger`
# unambiguously names its own phase's entity. `trigger <name>` (Cmd_Trigger_f) sends EV_Activate to
# the named entity with the local
# player as activator, synchronously, in the same frame - idItem::Event_Trigger treats a player
# activator as a pickup (Pickup -> GiveToPlayer -> idPDAItem::GiveToPlayer -> idPlayer::GivePDA).
# idPlayer::GivePDA itself calls TogglePDA() when this is the player's first PDA
# (inventory.pdas.Num() == 1) and the PDA isn't already open - both true in each phase, since each
# `map` respawns a fresh player - so triggering the spawned item_pda both gives the PDA and opens
# it, without needing impulse/mouse input. (GivePDA also gates its "first PDA" behavior on
# gameLocal.GetFrameNum() > 10, hence the `wait 20` after each `map` before spawning/triggering.)
#
# --- AC2 ---
# idCmdSystem::ArgCompletion_GuiName (framework/CmdSystem.h) isn't reachable from a console script -
# it only ever runs from interactive tab-completion, which the console-only harness (spec #28) can't
# drive. Calling ArgCompletion_GuiName directly (with a hardcoded command name) would only prove
# that function exists, not that g_PDA is wired to it. `chextrek_test_gui_completion` (test-only,
# ChexTrekDump.cpp/.h, spec #35) closes that gap the same way chextrek_customui_cmd (#34) does for a
# GUI button click: it looks g_PDA up via cvarSystem->Find, reads its own
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

set g_PDA "guis/chex_credits.gui"
map e1m1
wait 20
chextrek_dump
chextrek_test_gui_completion

spawn item_pda name chextrek_pda_test_1
trigger chextrek_pda_test_1
wait 10
chextrek_dump

set g_PDA "guis/pda_chex.gui"
map e1m1
wait 20
chextrek_dump

spawn item_pda name chextrek_pda_test_2
trigger chextrek_pda_test_2
wait 10
chextrek_dump

screenshot chextrek_pda
wait 10
quit
EOF

echo
echo "=== #35 PDA test: scenario run ==="
RUN_OUT="$(bash "${SCRIPT_DIR}/run-scenario.sh" chextrek_pda "$CONSOLE_SCRIPT" 120 2>&1)"
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

# --- e1m1 finishes loading, both times (spec #28 always-on check) ---
E1M1_LOAD_COUNT="$(grep -cE '^ *[0-9]+ msec to load e1m1$' "$LOCAL_LOG")"
if [ "$E1M1_LOAD_COUNT" -ge 2 ]; then
	echo "PASS: e1m1 finished loading in both phases"
else
	echo "FAIL: expected to see '<N> msec to load e1m1' twice in the log, saw ${E1M1_LOAD_COUNT}"
	FAIL=1
fi

# There are 4 chextrek_dump calls total: phase 1 baseline, phase 1 after opening the PDA, phase 2
# baseline, phase 2 after opening the PDA.
PDA_GUI_VALUES="$(grep -oE '^pda_gui: .*$' "$LOCAL_LOG" | sed 's/^pda_gui: //')"
PDA_OPEN_VALUES="$(grep -oE '^pda_open: [01]$' "$LOCAL_LOG" | grep -oE '[01]$')"
P1_GUI_BASELINE="$(echo "$PDA_GUI_VALUES" | sed -n '1p')"
P1_GUI_AFTER="$(echo "$PDA_GUI_VALUES" | sed -n '2p')"
P2_GUI_BASELINE="$(echo "$PDA_GUI_VALUES" | sed -n '3p')"
P2_GUI_AFTER="$(echo "$PDA_GUI_VALUES" | sed -n '4p')"
P1_OPEN_BASELINE="$(echo "$PDA_OPEN_VALUES" | sed -n '1p')"
P1_OPEN_AFTER="$(echo "$PDA_OPEN_VALUES" | sed -n '2p')"
P2_OPEN_BASELINE="$(echo "$PDA_OPEN_VALUES" | sed -n '3p')"
P2_OPEN_AFTER="$(echo "$PDA_OPEN_VALUES" | sed -n '4p')"

# --- Phase 1: proves idPlayer::Spawn reads g_PDA, not a hardcoded literal ---
if [ "$P1_GUI_BASELINE" = "guis/chex_credits.gui" ]; then
	echo "PASS: phase 1 - idPlayer::objectiveSystem was loaded from g_PDA's explicitly-set third value (guis/chex_credits.gui - neither stock's hardcoded guis/pda.gui nor the mod's own default guis/pda_chex.gui), proving idPlayer::Spawn actually reads the cvar"
else
	echo "FAIL: expected pda_gui=guis/chex_credits.gui at phase 1 baseline, got '${P1_GUI_BASELINE}'"
	FAIL=1
fi

if [ "$P1_OPEN_BASELINE" = "0" ] && [ "$P1_OPEN_AFTER" = "1" ]; then
	echo "PASS: phase 1 - the PDA started closed and opened after the pickup (pda_open 0 -> 1)"
else
	echo "FAIL: expected phase 1 pda_open to go 0 -> 1, got '${P1_OPEN_BASELINE}' -> '${P1_OPEN_AFTER}'"
	FAIL=1
fi

if [ "$P1_GUI_AFTER" = "guis/chex_credits.gui" ]; then
	echo "PASS: phase 1 - the active PDA GUI when opened is still the one g_PDA named"
else
	echo "FAIL: expected pda_gui=guis/chex_credits.gui after opening the PDA in phase 1, got '${P1_GUI_AFTER}'"
	FAIL=1
fi

# --- Phase 2: proves the AC's literal claim with g_PDA at its own default ---
if [ "$P2_GUI_BASELINE" = "guis/pda_chex.gui" ]; then
	echo "PASS: phase 2 - with g_PDA reset to its own default, idPlayer::objectiveSystem is the mod's own PDA GUI (guis/pda_chex.gui), before the PDA is ever opened"
else
	echo "FAIL: expected pda_gui=guis/pda_chex.gui at phase 2 baseline, got '${P2_GUI_BASELINE}'"
	FAIL=1
fi

if [ "$P2_OPEN_BASELINE" = "0" ] && [ "$P2_OPEN_AFTER" = "1" ]; then
	echo "PASS: phase 2 - the PDA started closed and opened after the pickup (pda_open 0 -> 1)"
else
	echo "FAIL: expected phase 2 pda_open to go 0 -> 1, got '${P2_OPEN_BASELINE}' -> '${P2_OPEN_AFTER}'"
	FAIL=1
fi

if [ "$P2_GUI_AFTER" = "guis/pda_chex.gui" ]; then
	echo "PASS: phase 2 - with g_PDA set, opening the PDA shows the mod's PDA GUI (guis/pda_chex.gui) as the active one - spec #35 AC1"
else
	echo "FAIL: expected pda_gui=guis/pda_chex.gui after opening the PDA in phase 2, got '${P2_GUI_AFTER}'"
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
