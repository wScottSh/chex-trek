#!/usr/bin/env bash
# Regression test for bug #49: sf_923's "flemriser" (the flemoid that rises out of the puddle,
# script/map_storage_facility.script's riseflem()) can't be killed while rising, and can be -
# by the zorcher - once it's out. See docs/harness-coverage.md.
#
# Two runs of the scene (sf_923 loaded twice), each started exactly as the map's own pickup does
# (`trigger trigger_relay_1`: riseflem + flemriser + the tip relays):
#   Splash run - a damage_rocketSplash (grenade-class splash, 150 damage) goes off on the flemriser
#     repeatedly through the rise and just past it.
#     AC1: every blast before the rise ends (7s) leaves it at full health (80), including blasts
#          after the 3.5s camera cut, when the player can shoot it.
#     AC1 control: the first blast after the rise ends kills it - the same blast is lethal, so
#          AC1's "no damage" is the rise's doing.
#   Zorcher run - the player's zorcher "hits" the flemriser repeatedly through the rise and after
#     (chextrek_test_projectile_hit: applies the current weapon projectile's def_damage exactly as
#     idProjectile::Collide does, honoring weap_disable's "_nodamage" swap).
#     AC2: mid-rise the zorcher fires projectile_minizorchblast_nodamage and does no damage;
#          every hit after the rise ends fires projectile_minizorchblast.
#     AC3: the zorcher kills it after the rise ends and before trigger_relay_3's weap_enable (15s
#          after the trigger) - i.e. riseflem's own enable is what makes the zorcher work.
#
# Before the fix, the zorcher stayed on _nodamage until trigger_relay_3's weap_enable ~22s after
# the trigger (so AC2/AC3 fail), and nothing stopped a splash killing it mid-rise (AC1 fails).
#
# Timing: every probe is stamped with game time (gameLocal.time, via chextrek_test_probe /
# chextrek_test_projectile_hit) and assertions are made on elapsed game time since the trigger,
# never on `wait` counts. Under Wine the console's frame-counted `wait` doesn't map to a fixed
# amount of game time (docs/dev-setup.md, #61), so the waits below only need to be long enough
# to span the windows; COVERAGE checks fail loudly if they don't.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRATCH_DIR="$(mktemp -d)"
trap 'rm -rf "$SCRATCH_DIR"' EXIT

# shellcheck source=tools/lib-harness.sh
source "${SCRIPT_DIR}/lib-harness.sh"

echo "=== #49 flemriser-rise test: build ==="
chextrek_build_or_exit

FAIL=0

# Frames between probes, and probe counts per run. Probes are stamped with game time, so these
# only control coverage (see the COVERAGE checks below), not what's asserted.
# Measured on Unicron/Wine: ~3.3ms of game time per waited frame (15 frames ~= 50ms), so 30 frames
# ~= 100ms per probe -> splash ~10s, zorcher ~25s of game time. At 60fps (~16.7ms/frame) the same
# counts span ~50s/~125s.
PROBE_WAIT=30
SPLASH_PROBES=100
ZORCH_PROBES=250

CONSOLE_SCRIPT="${SCRATCH_DIR}/flemriser-rise.cfg"
{
	# Shared prelude: load, zorcher selected, weap_disable's 1s loop has had time to swap it.
	prelude() {
		cat <<'EOF'
map sf_923
wait 20
god
give weapon_pistol
wait 30
chextrek_test_impulse 1
wait 180
EOF
	}
	echo "developer 1"
	prelude
	echo "echo chextrek49_phase splash"
	echo "trigger trigger_relay_1"
	echo "chextrek_test_probe flemriser"
	for _ in $(seq 1 "$SPLASH_PROBES"); do
		echo "wait ${PROBE_WAIT}"
		# chextrek_test_str16 = "flemriser", str6 = "player1" (attacker/inflictor, ignored by the
		# blast), str9 = "damage_rocketSplash" - see ChexTrekDump.cpp for why names go via cvars.
		echo 'script sys.radiusDamage( sys.getEntity( $chextrek_test_str16 ).getWorldOrigin(), sys.getEntity( $chextrek_test_str6 ), sys.getEntity( $chextrek_test_str6 ), sys.getEntity( $chextrek_test_str6 ), $chextrek_test_str9, 1 )'
		echo "chextrek_test_probe flemriser"
	done
	prelude
	echo "echo chextrek49_phase zorch"
	echo "trigger trigger_relay_1"
	echo "chextrek_test_probe flemriser"
	for _ in $(seq 1 "$ZORCH_PROBES"); do
		echo "wait ${PROBE_WAIT}"
		echo "chextrek_test_projectile_hit flemriser"
	done
	echo "screenshot chextrek_flemriser_rise"
	echo "wait 10"
	echo "quit"
} > "$CONSOLE_SCRIPT"

echo
echo "=== #49 flemriser-rise test: scenario run ==="
chextrek_run_scenario chextrek_flemriser_rise "$CONSOLE_SCRIPT" 400 || FAIL=1

LOCAL_LOG="$CHEXTREK_SCENARIO_LOG"
if [ -z "$LOCAL_LOG" ]; then
	echo "FAIL: couldn't find the archived log to check scenario-specific assertions"
	FAIL=1
else
	chextrek_assert_map_loaded "$LOCAL_LOG" sf_923 || FAIL=1

	# Lines of the given phase, from its "chextrek49_phase" marker to the next marker.
	phase_lines() {
		awk -v p="$1" '/^chextrek49_phase /{on=($2==p); next} on' "$LOCAL_LOG"
	}

	# --- splash run -> "elapsed_ms health" per blast, elapsed since the trigger ---
	SPLASH="$(phase_lines splash | grep -E '^chextrek_test_probe: time=[0-9]+ entity=flemriser health=' \
		| sed -E 's/^chextrek_test_probe: time=([0-9]+) entity=flemriser health=(-?[0-9]+).*/\1 \2/' \
		| awk 'NR==1{t0=$1; next} {print $1-t0, $2}')"
	echo "--- splash run (elapsed_ms health), one line per blast ---"
	echo "$SPLASH"
	# awk prints PASS/FAIL lines itself; exit 1 on any FAIL.
	if ! echo "$SPLASH" | awk '
		$1 < 6900 { n++; if ($2 != 80) bad = bad " " $1 "ms:" $2; if ($1 >= 3600) late++ }
		$1 >= 6900 && $1 < 7000 { next }
		$1 >= 7000 && first == "" { first = $1; firsthp = $2 }
		END {
			rc = 0
			if (late < 3) { print "FAIL: COVERAGE splash - only " late+0 " blasts in the 3.6-6.9s window (want >=3); raise PROBE_WAIT/SPLASH_PROBES"; rc = 1 }
			if (bad != "") { print "FAIL: AC1 - splash damaged the flemriser mid-rise (elapsed:health):" bad; rc = 1 }
			else if (n > 0) print "PASS: AC1 - " n " splash blasts before the rise ended (" late+0 " after the camera cut) all left it at 80"
			if (first == "") { print "FAIL: COVERAGE splash - no blast after the rise ended (7s); raise PROBE_WAIT/SPLASH_PROBES"; rc = 1 }
			else if (firsthp > 0) { print "FAIL: AC1 control - first blast after the rise (" first "ms) left health " firsthp ", expected <= 0"; rc = 1 }
			else print "PASS: AC1 control - first blast after the rise (" first "ms) killed it (health " firsthp ")"
			exit rc
		}'; then
		FAIL=1
	fi

	# --- zorcher run -> "elapsed_ms projectile before after" per hit ---
	ZT0="$(phase_lines zorch | grep -E '^chextrek_test_probe: time=' | head -1 | sed -E 's/^chextrek_test_probe: time=([0-9]+).*/\1/')"
	ZORCH="$(phase_lines zorch | grep -E '^chextrek_test_projectile_hit: time=[0-9]+ projectile=' \
		| sed -E 's/^chextrek_test_projectile_hit: time=([0-9]+) projectile=([^ ]+) def_damage=([^ ]+) health=(-?[0-9]+)->(-?[0-9]+)$/\1 \2 \4 \5/' \
		| awk -v t0="${ZT0:-0}" '{print $1-t0, $2, $3, $4}')"
	echo "--- zorcher run (elapsed_ms projectile health_before health_after), one line per hit ---"
	echo "$ZORCH"
	if [ -z "$ZT0" ]; then
		echo "FAIL: zorcher run - no trigger-time probe in the log"
		FAIL=1
	elif ! echo "$ZORCH" | awk '
		$1 < 6900 {
			if ($1 >= 3600) { mid++; if ($2 != "projectile_minizorchblast_nodamage") badproj = badproj " " $1 "ms:" $2 }
			if ($4 != 80) bad = bad " " $1 "ms:" $3 "->" $4
		}
		$1 >= 7100 && $3 > 0 { post++; if ($2 != "projectile_minizorchblast") badpost = badpost " " $1 "ms:" $2 }
		$1 >= 7000 && $4 <= 0 && dead == "" { dead = $1 }
		{ last = $1 }
		END {
			rc = 0
			if (dead == "" && last < 15000) { print "FAIL: COVERAGE zorcher - hits only reach " last+0 "ms, short of 15s; raise PROBE_WAIT/ZORCH_PROBES"; rc = 1 }
			if (mid < 3) { print "FAIL: COVERAGE zorcher - only " mid+0 " hits in the 3.6-6.9s window (want >=3); raise PROBE_WAIT/ZORCH_PROBES"; rc = 1 }
			if (badproj != "") { print "FAIL: AC2 - zorcher was not on _nodamage mid-rise:" badproj; rc = 1 }
			if (bad != "") { print "FAIL: AC2 - zorcher damaged the flemriser mid-rise (elapsed:before->after):" bad; rc = 1 }
			if (badproj == "" && bad == "" && mid >= 3) print "PASS: AC2 (mid-rise) - " mid " zorcher hits after the camera cut fired projectile_minizorchblast_nodamage and did no damage"
			if (post == 0) { print "FAIL: AC2 - no zorcher hit on a living flemriser after the rise ended"; rc = 1 }
			else if (badpost != "") { print "FAIL: AC2 - zorcher not back to projectile_minizorchblast after the rise:" badpost; rc = 1 }
			else print "PASS: AC2 (post-rise) - all " post " zorcher hits after the rise fired projectile_minizorchblast"
			if (dead == "") { print "FAIL: AC3 - the zorcher never killed the flemriser"; rc = 1 }
			else if (dead >= 15000) { print "FAIL: AC3 - zorcher only killed it at " dead "ms, not before trigger_relay_3 (15s) - riseflem did not enable it"; rc = 1 }
			else print "PASS: AC3 - zorcher killed the flemriser at " dead "ms after the trigger (rise ends at 7s, trigger_relay_3 at 15s)"
			exit rc
		}'; then
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
