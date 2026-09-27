#!/usr/bin/env bash
# Regression test for bug #48: on e1m1 the PDA key (impulse 19) only raised the PDA model, whose
# screen is guis/chex/comm_down.gui ("Warning - Communication Systems Status: DOWN"), and never
# opened the PDA gui (guis/pda_chex.gui: stats, objectives, map).
#
# Cause: the mod's item_pda::Idle (script/weapon_pda.script) no longer calls owner.openPDA() - "it's
# in the SDK now" - and the binary's IMPULSE_19 (idPlayer::PerformImpulse, 0x16cc8f-0x16cd99) calls
# TogglePDA after raising weapon_pda. The port kept stock's IMPULSE_19, which only raises the weapon.
#
# The scenario gives the player a PDA the same way tools/test-pda.sh does (spawn + trigger an
# item_pda; the first PDA opens itself in GivePDA), then sends impulse 19 three times through the
# real idPlayer::PerformImpulse (chextrek_test_impulse, ChexTrekDump.cpp): close, open, close.
# TogglePDA runs inside PerformImpulse, so each dump sees the result without waiting on game time.
# The "open" step is the bug: before the fix pda_open stayed 0 there.
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
map e1m1
wait 20

spawn item_pda name chextrek_pda_impulse_1
trigger chextrek_pda_impulse_1
wait 10
chextrek_dump

chextrek_test_impulse 19
wait 10
chextrek_dump

chextrek_test_impulse 19
wait 10
chextrek_dump

chextrek_test_impulse 19
wait 10
chextrek_dump

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

chextrek_assert_map_loaded "$LOCAL_LOG" e1m1 || FAIL=1

# Four dumps: after the pickup, then after each impulse 19.
PDA_OPEN_VALUES="$(grep -oE '^pda_open: [01]$' "$LOCAL_LOG" | grep -oE '[01]$' | tr -d '\n')"
PDA_GUI_OPENED="$(chextrek_line_field_values "$LOCAL_LOG" pda_gui | sed -n '3p')"

if [ "$PDA_OPEN_VALUES" = "1010" ]; then
	echo "PASS: pda_open goes 1 (pickup) -> 0 -> 1 -> 0 across three impulse 19s"
else
	echo "FAIL: expected pda_open 1010 (pickup, then impulse 19 close/open/close), got '${PDA_OPEN_VALUES}'"
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
