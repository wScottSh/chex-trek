#!/usr/bin/env bash
# Regression test for bug #49: sf_923's "flemriser" (the flemoid that rises out of the puddle,
# script/map_storage_facility.script's riseflem()) can't be killed while rising, and can be -
# zorcher included - once it's out. See docs/harness-coverage.md.
#   AC1: during the rise, damage doesn't hurt it (health stays full)
#   AC2: once the rise ends (~7s), the zorcher fires its damaging projectile again
#   AC3: once the rise ends, damage kills it (health drops to 0 or below)
#
# Before the fix, the zorcher stayed on projectile_minizorchblast_nodamage until trigger_relay_3's
# weap_enable ~22s after the rise started, and nothing stopped a grenade killing it mid-rise.
#
# Timing: the console's `wait` is in engine frames (~60 per second - see
# tools/test-end-level-nextmap.sh's header). `trigger trigger_relay_1` starts the scene exactly as
# the map's own trigger_once does (riseflem + flemriser + the tip relays). `damage` is the stock
# console command (world-inflicted damage_moverCrush), a stand-in for any weapon: riseflem's
# ignoreDamage() gates all damage, not one weapon. chextrek_test_str16 holds "flemriser" quoted
# (see ChexTrekDump.cpp for why names go through cvars). `chextrek_test_impulse 1` selects the
# zorcher (weapon slot 1) after `give` so weapon_projectile reports it, not the fists.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRATCH_DIR="$(mktemp -d)"
trap 'rm -rf "$SCRATCH_DIR"' EXIT

# shellcheck source=tools/lib-harness.sh
source "${SCRIPT_DIR}/lib-harness.sh"

echo "=== #49 flemriser-rise test: build ==="
chextrek_build_or_exit

FAIL=0

CONSOLE_SCRIPT="${SCRATCH_DIR}/flemriser-rise.cfg"
cat > "$CONSOLE_SCRIPT" <<'EOF'
developer 1
map sf_923
wait 20
give weapon_pistol
wait 30
chextrek_test_impulse 1
wait 120
chextrek_dump
trigger trigger_relay_1
wait 120
damage flemriser 500
wait 5
script sys.println( 71000 + sys.getEntity( $chextrek_test_str16 ).getHealth() )
wait 420
chextrek_dump
damage flemriser 500
wait 5
script sys.println( 72000 + ( sys.getEntity( $chextrek_test_str16 ).getHealth() <= 0 ) )
screenshot chextrek_flemriser_rise
wait 10
quit
EOF

echo
echo "=== #49 flemriser-rise test: scenario run ==="
chextrek_run_scenario chextrek_flemriser_rise "$CONSOLE_SCRIPT" 120 || FAIL=1

LOCAL_LOG="$CHEXTREK_SCENARIO_LOG"
if [ -z "$LOCAL_LOG" ]; then
	echo "FAIL: couldn't find the archived log to check scenario-specific assertions"
	FAIL=1
else
	chextrek_assert_map_loaded "$LOCAL_LOG" sf_923 || FAIL=1

	# flemoid "health" is 80 (def/chex_monster_flemoid.def), so 71080 = untouched by the 500 damage.
	if grep -q '^71080$' "$LOCAL_LOG"; then
		echo "PASS: AC1 - flemriser took no damage while rising (health 80)"
	else
		echo "FAIL: AC1 - expected '71080' (full health mid-rise), got '$(grep -E '^710[0-9]+' "$LOCAL_LOG" | head -1)'"
		FAIL=1
	fi

	PROJ_VALUES="$(chextrek_line_field_values "$LOCAL_LOG" weapon_projectile)"
	PROJ_BEFORE="$(echo "$PROJ_VALUES" | sed -n '1p')"
	PROJ_AFTER="$(echo "$PROJ_VALUES" | sed -n '2p')"
	if [ "$PROJ_BEFORE" = "projectile_minizorchblast_nodamage" ] && [ "$PROJ_AFTER" = "projectile_minizorchblast" ]; then
		echo "PASS: AC2 - zorcher went from ${PROJ_BEFORE} to ${PROJ_AFTER} once the rise ended"
	else
		echo "FAIL: AC2 - expected projectile_minizorchblast_nodamage -> projectile_minizorchblast, got '${PROJ_BEFORE}' -> '${PROJ_AFTER}'"
		FAIL=1
	fi

	# 72001 = getHealth() <= 0 (dead). Not level_stats: idAI::Killed only counts player kills, and
	# console `damage` is inflicted by the world.
	if grep -q '^72001$' "$LOCAL_LOG"; then
		echo "PASS: AC3 - flemriser died once out of the puddle"
	else
		echo "FAIL: AC3 - expected '72001' (dead after the rise), got '$(grep -E '^7200[0-9]$' "$LOCAL_LOG" | head -1)'"
		FAIL=1
	fi
fi

echo
if [ $FAIL -eq 0 ]; then
	echo "PASS: #49 flemriser-rise scenario - can't die while rising, killable (zorcher included) once out"
	exit 0
else
	echo "FAIL: #49 flemriser-rise scenario - see above"
	exit 1
fi
