#!/usr/bin/env bash
# Regression test: sf_923's bridge "open hangar" cutscene. The bridge console (hbcontrol) runs
# script/map_storage_facility.script's open_hangar(), which opens the hangar door (hbdoor1/hbdoor2)
# and fires "dooroids": four cinematic flemoids (monster_flemoid_13..16) walk out of the hangar,
# through the door and down the hallway on their path_corners while func_cameraview_1 shows it.
# flemoid_16's last corner (path_corner_7, just outside the door) triggers the camera off again.
#
# The scenario runs open_hangar() exactly as the console button does, with the player standing at
# the console on the bridge, and probes the door, the four flemoids and the active camera:
#   AC1: the hangar door opens. (It shuts again on its own - hbdoor1/2 keep the default "wait" 3,
#        as in the original mod - so this checks it opened, not that it stays open.)
#   AC2: func_cameraview_1 is up for at least 5s in one stretch, then ends (flemoid_16 got to
#        path_corner_7 and turned it off).
#   AC3: no "couldn't reach path_corner" warning.
#   AC4: every flemoid ends out of the hangar, past the door (y > -420; the door is at y=-496).
#        Not "on its last path_corner": once the camera is off and the door shut, the player on the
#        bridge is out of their connected areas and they go dormant after 3s mid-hallway - original
#        idAI dormancy, identical in the original gamex86.so.
#
# The regression: the port's idDoor::Show / Event_ClosePortal set a shut door's AAS areas to
# obstacle when IsLocked() || IsNoTouch() (dhewm3); the original gamex86.so tests IsLocked() only.
# hbdoor1/2 are "no_touch" "1", so once open_hangar() unlocked them they still blocked every route
# out of the hangar: each flemoid got "couldn't reach path_corner", path_corner_7's trigger fired on
# flemoid_16's failure and turned the camera on at once, relay's 1s-delayed trigger (meant to turn
# it on) turned it off - under a second of a closed door, the flemoids left in the hangar.
#
# The button is pressed only after level time 1.5s: map_storage_facility::main() turns the hangar's
# ship ($sf) to yaw 225 over the first second, and its hull sweeps anything near it - a flemoid
# shown before then is shoved away from the door and wedged against the ship. In play the button is
# minutes in. PRECONDITION fails loudly if the button came too early.
#
# Timing: probes are stamped with game time (chextrek_test_probe) and assertions use elapsed game
# time since the button, never `wait` counts - see tools/test-flemriser-rise.sh. COVERAGE fails
# loudly if the probes don't span long enough.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRATCH_DIR="$(mktemp -d)"
trap 'rm -rf "$SCRATCH_DIR"' EXIT

# shellcheck source=tools/lib-harness.sh
source "${SCRIPT_DIR}/lib-harness.sh"

echo "=== hangar-cutscene test: build ==="
chextrek_build_or_exit

FAIL=0

# Measured on Unicron/Wine: 300 waited frames ~= 750ms of game time, so 30 probes span ~22s; in
# the fixed run the camera ends ~10s after the button and every flemoid is past the door by ~15s.
PROBE_WAIT=300
PROBES=30
ENTITIES="hbdoor1 monster_flemoid_13 monster_flemoid_14 monster_flemoid_15 monster_flemoid_16"

CONSOLE_SCRIPT="${SCRATCH_DIR}/hangar-cutscene.cfg"
{
	echo "developer 1"
	echo "map sf_923"
	echo "wait 20"
	echo "god"
	echo "notarget"
	# at the bridge console (hbcontrol, -2568 1880 328)
	echo "setviewpos -2500 1880 400"
	# past the ship's 1s turn in main() (~2.5s of game time)
	echo "wait 1000"
	echo "echo chextrek_hangar_phase button"
	echo "script map_storage_facility::open_hangar()"
	for _ in $(seq 1 "$PROBES"); do
		for e in $ENTITIES; do echo "chextrek_test_probe $e"; done
		echo "wait ${PROBE_WAIT}"
	done
	echo "screenshot chextrek_hangar_cutscene"
	echo "wait 10"
	echo "quit"
} > "$CONSOLE_SCRIPT"

echo
echo "=== hangar-cutscene test: scenario run ==="
chextrek_run_scenario chextrek_hangar_cutscene "$CONSOLE_SCRIPT" 400 || FAIL=1

LOCAL_LOG="$CHEXTREK_SCENARIO_LOG"
if [ -z "$LOCAL_LOG" ]; then
	echo "FAIL: couldn't find the archived log to check scenario-specific assertions"
	FAIL=1
else
	chextrek_assert_map_loaded "$LOCAL_LOG" sf_923 || FAIL=1

	AFTER="$(awk '/^chextrek_hangar_phase button/{on=1; next} on' "$LOCAL_LOG")"

	BUTTON_TIME="$(echo "$AFTER" | grep -m1 -oE '^chextrek_test_probe: time=[0-9]+' | sed 's/.*=//')"
	if [ -z "$BUTTON_TIME" ] || [ "$BUTTON_TIME" -lt 1500 ]; then
		echo "FAIL: PRECONDITION - button pressed at level time ${BUTTON_TIME:-?}ms, before 1500ms: the ship is still turning; raise the pre-button wait"
		FAIL=1
	else
		echo "PASS: PRECONDITION - button pressed at level time ${BUTTON_TIME}ms, after the ship's turn"
	fi

	# "elapsed_ms entity x y camera" per probe, elapsed since the first probe after the button
	PROBED="$(echo "$AFTER" | grep -E '^chextrek_test_probe: time=[0-9]+ entity=[^ ]+ health=.* origin=' \
		| sed -E 's/^chextrek_test_probe: time=([0-9]+) entity=([^ ]+) .* origin=(-?[0-9]+),(-?[0-9]+),(-?[0-9]+) camera=([^ ]+)$/\1 \2 \3 \4 \6/' \
		| awk 'NR==1{t0=$1} {print $1-t0, $2, $3, $4, $5}')"
	echo "--- door and camera (elapsed_ms hbdoor1_x camera), on change ---"
	echo "$PROBED" | awk '$2=="hbdoor1" && ($3 != lx || $5 != lc) {print $1, $3, $5; lx=$3; lc=$5}'

	if ! echo "$PROBED" | awk '
		{ last = $1 }
		$2 == "hbdoor1" {
			if ($3 != -1192) opened = 1
			if ($5 == "func_cameraview_1") { if (camstart == "") camstart = $1; camend = $1 }
			else if (camstart != "") { dur = camend - camstart; if (dur > best) best = dur; camstart = "" }
		}
		$2 ~ /^monster_flemoid_1[3-6]$/ { x[$2] = $3; y[$2] = $4 }
		END {
			rc = 0
			if (last < 18000) { print "FAIL: COVERAGE - probes only reach " last+0 "ms after the button, short of 18s; raise PROBE_WAIT/PROBES"; rc = 1 }
			if (!opened) { print "FAIL: AC1 - hbdoor1 never left its closed origin (x=-1192): the hangar door never opened"; rc = 1 }
			else print "PASS: AC1 - the hangar door opened"
			if (camstart != "") { print "FAIL: AC2 - func_cameraview_1 still up at the end: flemoid_16 never reached path_corner_7"; rc = 1 }
			else if (best < 5000) { print "FAIL: AC2 - longest func_cameraview_1 shot was " best+0 "ms (want >= 5000ms): the cutscene was cut short"; rc = 1 }
			else print "PASS: AC2 - func_cameraview_1 was up for " best "ms, then ended"
			split("monster_flemoid_13 monster_flemoid_14 monster_flemoid_15 monster_flemoid_16", ms, " ")
			for (k = 1; k <= 4; k++) {
				m = ms[k]
				if (!(m in x)) { print "FAIL: AC4 - no probe of " m; rc = 1; continue }
				if (y[m] <= -420) { print "FAIL: AC4 - " m " ended at " x[m] "," y[m] ", still in the hangar"; rc = 1 }
				else print "PASS: AC4 - " m " ended at " x[m] "," y[m] ", out of the hangar"
			}
			exit rc
		}'; then
		FAIL=1
	fi

	UNREACHABLE="$(echo "$AFTER" | grep -E "couldn't reach path_corner" || true)"
	if [ -n "$UNREACHABLE" ]; then
		echo "FAIL: AC3 - flemoids couldn't reach their path_corners:"
		echo "$UNREACHABLE"
		FAIL=1
	else
		echo "PASS: AC3 - no \"couldn't reach path_corner\" warning"
	fi
fi

echo
if [ $FAIL -eq 0 ]; then
	echo "PASS: hangar-cutscene scenario - the door opens, the flemoids walk out on camera and down the hallway"
	exit 0
else
	echo "FAIL: hangar-cutscene scenario - see above"
	exit 1
fi
