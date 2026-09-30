#!/usr/bin/env bash
# Regression test: sf_923's bridge "open hangar" cutscene. The bridge console (hbcontrol) runs
# script/map_storage_facility.script's open_hangar(), which opens the hangar door (hbdoor1/hbdoor2)
# and fires "dooroids": four cinematic flemoids (monster_flemoid_13..16) walk out of the hangar,
# through the door and down the hallway on their path_corners while func_cameraview_1 shows it.
# flemoid_16's last corner (path_corner_7, just outside the door) triggers the camera off again.
#
# The scenario runs open_hangar() exactly as the console button does, with the player standing at
# the console on the bridge, and probes the door, the four flemoids and the active camera:
#   AC1: the hangar door opens and is still open at the end.
#   AC2: func_cameraview_1 is up for at least 5s in one stretch, then ends (flemoid_16 got to
#        path_corner_7 and turned it off).
#   AC3: no "couldn't reach path_corner" warning.
#   AC4: every flemoid ends on its last path_corner, out in the hallway - none left in the hangar.
#
# Before the fix, open_hangar() triggered both team doors in one frame, so the second trigger sent
# the door straight back (idMover_Binary::Use_BinaryMover, MOVER_1TO2 -> GotoPosition1) and it never
# opened. Every flemoid then failed to reach its corner; path_corner_7's trigger still fired on the
# failure, which turned the camera on at once, and relay's 1s-delayed trigger (meant to turn it on)
# turned it off - under a second of a closed door. The flemoids stayed in the hangar.
# The fix also needed, each found by this scenario: the door staying open ("wait" "-1" - with the
# default 3s it shut on them mid-cutscene), the flemoids never going dormant ("neverDormant" - they
# froze 3s after the camera ended, the player being out of their connected areas), and open_hangar()
# waiting for the door before firing dooroids (started with it, 14 and 15 jammed at the ramp).
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

# Measured on Unicron/Wine: 300 waited frames ~= 750ms of game time, so 45 probes span ~34s; the
# fixed run has every flemoid at its last corner by ~21s.
PROBE_WAIT=300
PROBES=45
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
	echo "wait 60"
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
			doorx = $3
			if ($5 == "func_cameraview_1") { if (camstart == "") camstart = $1; camend = $1 }
			else if (camstart != "") { dur = camend - camstart; if (dur > best) best = dur; camstart = "" }
		}
		$2 ~ /^monster_flemoid_1[3-6]$/ { x[$2] = $3; y[$2] = $4 }
		END {
			rc = 0
			if (last < 25000) { print "FAIL: COVERAGE - probes only reach " last+0 "ms after the button, short of 25s; raise PROBE_WAIT/PROBES"; rc = 1 }
			if (!opened) { print "FAIL: AC1 - hbdoor1 never left its closed origin (x=-1192): the hangar door never opened"; rc = 1 }
			else if (doorx == -1192) { print "FAIL: AC1 - hbdoor1 opened but was shut again by the end"; rc = 1 }
			else print "PASS: AC1 - the hangar door opened and stayed open (hbdoor1 x=" doorx ")"
			if (camstart != "") { print "FAIL: AC2 - func_cameraview_1 still up at the end: flemoid_16 never reached path_corner_7"; rc = 1 }
			else if (best < 5000) { print "FAIL: AC2 - longest func_cameraview_1 shot was " best+0 "ms (want >= 5000ms): the cutscene was cut short"; rc = 1 }
			else print "PASS: AC2 - func_cameraview_1 was up for " best "ms, then ended"
			# last corners: 13 -> path_corner_4 (-664 240), 14 -> path_corner_5 (-1760 -88),
			# 15 -> path_corner_6 (-1768 528), 16 -> path_corner_7 (-1192 -344)
			cx["monster_flemoid_13"] = -664;  cy["monster_flemoid_13"] = 240
			cx["monster_flemoid_14"] = -1760; cy["monster_flemoid_14"] = -88
			cx["monster_flemoid_15"] = -1768; cy["monster_flemoid_15"] = 528
			cx["monster_flemoid_16"] = -1192; cy["monster_flemoid_16"] = -344
			for (m in cx) {
				if (!(m in x)) { print "FAIL: AC4 - no probe of " m; rc = 1; continue }
				dx = x[m] - cx[m]; dy = y[m] - cy[m]; d = sqrt(dx*dx + dy*dy)
				where = (y[m] < -496) ? " (still in the hangar)" : ""
				if (d > 96) { print "FAIL: AC4 - " m " ended at " x[m] "," y[m] where ", " int(d) " units from its last path_corner"; rc = 1 }
				else print "PASS: AC4 - " m " ended at its last path_corner (" int(d) " units off)"
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
