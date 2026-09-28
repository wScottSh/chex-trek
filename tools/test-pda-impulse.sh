#!/usr/bin/env bash
# Regression test for bug #48: on e1m1 the PDA key (impulse 19) only raised the PDA model, whose
# screen is guis/chex/comm_down.gui ("Warning - Communication Systems Status: DOWN"), and never
# opened the PDA gui (guis/pda_chex.gui: stats, objectives, map).
#
# Cause: the mod's item_pda::Idle (script/weapon_pda.script) no longer calls owner.openPDA() - "it's
# in the SDK now" - and the binary's IMPULSE_19 (idPlayer::PerformImpulse, 0x16cc8f-0x16cd99) calls
# TogglePDA after raising weapon_pda. The port kept stock's IMPULSE_19, which only raises the weapon.
#
# e1m1's info_player_start targets item_pda_1, so the player already owns a PDA when the map starts
# (given during the load, so GivePDA doesn't open it) - the exact state the bug was reported in.
# The scenario sends impulse 19 through the real idPlayer::PerformImpulse (chextrek_test_impulse,
# ChexTrekDump.cpp) four times: open, close, open, close. TogglePDA runs inside PerformImpulse, so
# each dump sees the result without waiting on game time. Every "open" step is the bug: before the
# fix pda_open stayed 0 there, with only the PDA model (comm_down.gui) raised.
#
# Also checked: after the first open, the PDA is still open 100 waits later, so item_pda's Idle
# loop (which lowers the model once owner.inPDA() goes false) doesn't close it on its own; and on
# office (a map with no item_pda, so no PDA owned) impulse 19 leaves the PDA closed, as the binary's
# IMPULSE_19 skips everything when inventory.pdas.Num() is 0. Screenshots are taken while the PDA
# is open and after it's closed (archived as artifacts, never asserted).
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRATCH_DIR="$(mktemp -d)"
trap 'rm -rf "$SCRATCH_DIR"' EXIT

# shellcheck source=tools/lib-harness.sh
source "${SCRIPT_DIR}/lib-harness.sh"

echo "=== #48 PDA impulse test: build ==="
chextrek_build_or_exit

CONSOLE_SCRIPT="${SCRATCH_DIR}/pda_impulse.cfg"
cat > "$CONSOLE_SCRIPT" <<'EOF'
developer 1
map office
wait 20
chextrek_test_impulse 19
wait 10
chextrek_dump

map e1m1
wait 20
chextrek_dump

chextrek_test_impulse 19
wait 10
chextrek_dump
wait 100
chextrek_dump
screenshot chextrek_pda_impulse_open

chextrek_test_impulse 19
wait 10
chextrek_dump
wait 30
screenshot chextrek_pda_impulse_closed

chextrek_test_impulse 19
wait 10
chextrek_dump

chextrek_test_impulse 19
wait 10
chextrek_dump
wait 10

quit
EOF

echo
echo "=== #48 PDA impulse test: scenario run ==="

FAIL=0
chextrek_run_scenario chextrek_pda_impulse "$CONSOLE_SCRIPT" 120 || FAIL=1

LOCAL_LOG="$CHEXTREK_SCENARIO_LOG"
if [ -z "$LOCAL_LOG" ]; then
	echo "FAIL: couldn't find the archived log to check scenario-specific assertions"
	exit 1
fi

chextrek_assert_map_loaded "$LOCAL_LOG" office || FAIL=1
chextrek_assert_map_loaded "$LOCAL_LOG" e1m1 || FAIL=1

# Seven dumps: office after impulse 19 (no PDA owned); e1m1 at start; after impulse 19 (open);
# 100 waits later; after impulse 19 (close); after impulse 19 (open); after impulse 19 (close).
PDA_OPEN_VALUES="$(grep -oE '^pda_open: [01]$' "$LOCAL_LOG" | grep -oE '[01]$' | tr -d '\n')"
PDA_GUI_OPENED="$(chextrek_line_field_values "$LOCAL_LOG" pda_gui | sed -n '3p')"
IMPULSES_SENT="$(grep -c '^chextrek_test_impulse: sent impulse 19$' "$LOCAL_LOG")"

if [ "$IMPULSES_SENT" = "5" ]; then
	echo "PASS: all five impulse 19s reached idPlayer::PerformImpulse"
else
	echo "FAIL: expected 5 'chextrek_test_impulse: sent impulse 19' lines, got ${IMPULSES_SENT}"
	FAIL=1
fi

if [ "$PDA_OPEN_VALUES" = "0011010" ]; then
	echo "PASS: pda_open 0 (office, no PDA) | e1m1: 0 -> 1 -> 1 (still open) -> 0 -> 1 -> 0"
else
	echo "FAIL: expected pda_open 0011010 (office no-PDA impulse 19; e1m1 start, open, still open, close, open, close), got '${PDA_OPEN_VALUES}'"
	FAIL=1
fi

if [ "$PDA_GUI_OPENED" = "guis/pda_chex.gui" ]; then
	echo "PASS: the PDA impulse 19 opens is the mod's PDA gui (guis/pda_chex.gui)"
else
	echo "FAIL: expected pda_gui=guis/pda_chex.gui when impulse 19 opens the PDA, got '${PDA_GUI_OPENED}'"
	FAIL=1
fi

echo
if [ $FAIL -eq 0 ]; then
	echo "PASS: #48 PDA impulse scenario - impulse 19 opens and closes the mod's PDA gui"
	exit 0
else
	echo "FAIL: #48 PDA impulse scenario - see above"
	exit 1
fi
