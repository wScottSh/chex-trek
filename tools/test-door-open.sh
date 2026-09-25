#!/usr/bin/env bash
# Automated test for spec #40's acceptance criteria (decomp-so/reference/door-opening.md,
# idPlayer::tryOpen, ported this sub-issue): the player opens an unlocked door with the use key
# (impulse 16), within g_doorTraceDist. See docs/harness-coverage.md.
#   AC1: face an unlocked door within range, use impulse; log/dump shows it opened
#   AC2: out of g_doorTraceDist range the door doesn't open; raising the cvar makes it open
#
# Locked doors, the "requires"/item-gate behavior and the locked-text tip (spec #41) are
# explicitly NOT this scenario's concern, even though tryOpen's ported body includes those
# branches (the reference function is one whole; #41 still needs its own scenario for them).
# AI/monster door opening via canopendoors (spec #42) is also out of scope: idAI::OpenDoors/
# Event_OpenDoors/the openDoors script event already landed with #30 (it's also a script event -
# see tools/test-script-events.sh), but the canOpenDoors member and the idAI::Spawn/AnimMove/
# FlyMove/SlideMove wiring leads (decomp-so/reference/door-opening.md's Notes) aren't ported yet.
#
# Drives sf_923 (spec #28's real second map) through console commands only (map, setviewpos,
# noclip, chextrek_test_impulse, wait, chextrek_dump, script, screenshot), per spec #28's testing
# decisions. Uses two of sf_923's own unlocked func_door entities (no synthetic fixture), each an
# axis-aligned brush approached head-on along its thin (thickness) axis:
#   - func_door_1 (origin -264 184 64) for AC1, approached from the +X side (its face plane sits
#     a few units off the entity's own X origin - the brush's own "door1"-textured planes, not
#     just its origin, define the exact face; see the brush primitive in maps/sf_923.map for the
#     precise offsets, not restated here since only the harness run below proves the geometry).
#   - func_door_24 (origin -440 -264 192) for AC2, approached from the +Y side. It also has
#     "secret" "1" set (sf_923's own map data - unrelated to spec #40): opening it credits one of
#     the level's secrets (spec #33's counter), a harmless side effect of picking a real,
#     already-unlocked door rather than a synthetic fixture.
# Both doors have "no_touch" "1" (so nothing but tryOpen's own EV_Activate can start them moving)
# and neither is targeted by any other entity in sf_923's own map data, so both start closed and
# unmoved, and setviewpos/noclip teleporting near them can't itself trigger anything. Both are
# unlocked (no "requires"/"locked" keys), so idPlayer::tryOpen's unlocked branch (ProcessEvent
# EV_Activate) is the one exercised here.
#
# There's no way to send a real key-bound impulse from a console script (autoexec.cfg/matt.cfg/
# scott.cfg bind "e" to _impulse16, decomp-so/reference/door-opening.md's Notes) - "_impulse16"
# is recognized by idUsercmdGenLocal only from a real, currently-held bound key, and there's no
# plain "impulse" console command either (same gap tools/test-hud-map.sh hit for impulse 23).
# `chextrek_test_impulse 16` (ChexTrekDump.cpp) closes it the same way: it calls
# idPlayer::PerformImpulse(16) directly, so everything downstream (the new IMPULSE_16 case,
# tryOpen itself) is the real, already-ported game code, unchanged.
#
# `noclip` (stock, CMD_FL_CHEAT) is set once up front so each `setviewpos` teleport can't be
# blocked or corrected by collision. It changes nothing about whether a door opens:
# idPlayer::tryOpen's own trace (gameLocal.clip.Translation) is a world trace independent of the
# player's own noclip flag, and both doors' "no_touch" "1" (sf_923's own map data) means walking
# or teleporting near them can't start them moving through stock touch-triggering either - the
# use-key impulse below is the only thing that can.
#
# `door_tryopen_count`/`door_tryopen_last` (ChexTrekDump.cpp, this sub-issue) record every time
# tryOpen's trace actually resolved to an idDoor, independent of that door's lock/open state -
# the only way this scenario can tell "the trace reached the door" from "it didn't reach
# anything" (AC2's range check) rather than inferring it from some other coincidence. Whether a
# reached door actually opened is checked directly via its own script `isOpen()` (idDoor,
# Mover.cpp), the same technique tools/test-script-events.sh uses for idAI::OpenDoors. The
# console's own tokenizer strips quotes from a typed string literal before doom-script's compiler
# sees it (same gap tools/test-script-events.sh documents), so `chextrek_test_str10`/`_str11`
# (ChexTrekDump.cpp) hold the two door names quoted, substituted in via `$chextrek_test_strN`.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRATCH_DIR="$(mktemp -d)"
trap 'rm -rf "$SCRATCH_DIR"' EXIT

echo "=== #40 door-open test: build ==="
if ! bash "${SCRIPT_DIR}/build-chextrek.sh"; then
	echo "FAIL: build-chextrek.sh failed"
	exit 1
fi

# 4 chextrek_dump calls: baseline, after the AC1 near-range attempt (func_door_1, well within the
# default g_doorTraceDist of 100), after the AC2 far-range attempt (func_door_24, well outside the
# default 100 - expected to NOT reach the door), and after raising g_doorTraceDist to 200 and
# retrying from the same far spot (well within 200 - expected to now reach and open it). Each
# isOpen() check below prints a scenario-specific base (40100/40200/40300) plus the 0/1 result, so
# a stray "0"/"1" elsewhere in the log can't be mistaken for one of these checks.
CONSOLE_SCRIPT="${SCRATCH_DIR}/door-open.cfg"
cat > "$CONSOLE_SCRIPT" <<'EOF'
developer 1
map sf_923
wait 20
noclip
chextrek_dump

setviewpos -214 180 64 180
wait 10
chextrek_test_impulse 16
wait 15
chextrek_dump
script sys.println( 40100 + sys.getEntity( $chextrek_test_str10 ).isOpen() )

setviewpos -440 -118 192 270
wait 10
chextrek_test_impulse 16
wait 15
chextrek_dump
script sys.println( 40200 + sys.getEntity( $chextrek_test_str11 ).isOpen() )

g_doorTraceDist 200
wait 5
chextrek_test_impulse 16
wait 15
chextrek_dump
script sys.println( 40300 + sys.getEntity( $chextrek_test_str11 ).isOpen() )

screenshot chextrek_door_open
wait 10
quit
EOF

echo
echo "=== #40 door-open test: scenario run ==="
RUN_OUT="$(bash "${SCRIPT_DIR}/run-scenario.sh" chextrek_door_open "$CONSOLE_SCRIPT" 90 2>&1)"
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

TRYOPEN_COUNT_VALUES="$(grep -oE '^door_tryopen_count: [0-9]+$' "$LOCAL_LOG" | grep -oE '[0-9]+$')"
TRYOPEN_LAST_VALUES="$(grep -oE '^door_tryopen_last: .*$' "$LOCAL_LOG" | sed 's/^door_tryopen_last: //')"
COUNT_BASELINE="$(echo "$TRYOPEN_COUNT_VALUES" | sed -n '1p')"
COUNT_AFTER_NEAR="$(echo "$TRYOPEN_COUNT_VALUES" | sed -n '2p')"
COUNT_AFTER_FAR="$(echo "$TRYOPEN_COUNT_VALUES" | sed -n '3p')"
COUNT_AFTER_RAISED="$(echo "$TRYOPEN_COUNT_VALUES" | sed -n '4p')"
LAST_AFTER_NEAR="$(echo "$TRYOPEN_LAST_VALUES" | sed -n '2p')"
LAST_AFTER_RAISED="$(echo "$TRYOPEN_LAST_VALUES" | sed -n '4p')"

if [ "$COUNT_BASELINE" = "0" ]; then
	echo "PASS: baseline - door_tryopen_count is 0 before any use-key impulse"
else
	echo "FAIL: expected door_tryopen_count=0 at baseline, got '${COUNT_BASELINE}'"
	FAIL=1
fi

# --- AC1: face an unlocked door within range, use impulse; log/dump shows it opened ---
if [ -n "$COUNT_BASELINE" ] && [ -n "$COUNT_AFTER_NEAR" ] && [ "$COUNT_AFTER_NEAR" -eq $(( COUNT_BASELINE + 1 )) ] && [ "$LAST_AFTER_NEAR" = "func_door_1" ]; then
	echo "PASS: AC1 - the use-key trace reached func_door_1 within range (door_tryopen_count ${COUNT_BASELINE} -> ${COUNT_AFTER_NEAR}, last=${LAST_AFTER_NEAR})"
else
	echo "FAIL: expected door_tryopen_count to rise by exactly 1 and door_tryopen_last=func_door_1 after the near-range use, got count='${COUNT_BASELINE}'->'${COUNT_AFTER_NEAR}' last='${LAST_AFTER_NEAR}'"
	FAIL=1
fi

ISOPEN_40101="$(grep -c '^40101$' "$LOCAL_LOG")"
if [ "$ISOPEN_40101" -ge 1 ]; then
	echo "PASS: AC1 - func_door_1.isOpen() reports open (40101) after the in-range use impulse"
else
	echo "FAIL: expected to see '40101' in the log (40100 + func_door_1.isOpen()) after the in-range use impulse"
	FAIL=1
fi

# --- AC2: out of g_doorTraceDist range the door doesn't open ---
if [ -n "$COUNT_AFTER_NEAR" ] && [ -n "$COUNT_AFTER_FAR" ] && [ "$COUNT_AFTER_FAR" -eq "$COUNT_AFTER_NEAR" ]; then
	echo "PASS: AC2 - the use-key trace did NOT reach func_door_24 out of range (door_tryopen_count stayed ${COUNT_AFTER_NEAR})"
else
	echo "FAIL: expected door_tryopen_count to stay unchanged (out of range) after the far use, got '${COUNT_AFTER_NEAR}'->'${COUNT_AFTER_FAR}'"
	FAIL=1
fi

ISOPEN_40200="$(grep -c '^40200$' "$LOCAL_LOG")"
if [ "$ISOPEN_40200" -ge 1 ]; then
	echo "PASS: AC2 - func_door_24.isOpen() reports closed (40200) after the out-of-range use impulse"
else
	echo "FAIL: expected to see '40200' in the log (40200 + func_door_24.isOpen()) after the out-of-range use impulse"
	FAIL=1
fi

# --- AC2: raising the cvar makes it open ---
if [ -n "$COUNT_AFTER_FAR" ] && [ -n "$COUNT_AFTER_RAISED" ] && [ "$COUNT_AFTER_RAISED" -eq $(( COUNT_AFTER_FAR + 1 )) ] && [ "$LAST_AFTER_RAISED" = "func_door_24" ]; then
	echo "PASS: AC2 - raising g_doorTraceDist let the use-key trace reach func_door_24 (door_tryopen_count ${COUNT_AFTER_FAR} -> ${COUNT_AFTER_RAISED}, last=${LAST_AFTER_RAISED})"
else
	echo "FAIL: expected door_tryopen_count to rise by exactly 1 more and door_tryopen_last=func_door_24 after raising g_doorTraceDist, got count='${COUNT_AFTER_FAR}'->'${COUNT_AFTER_RAISED}' last='${LAST_AFTER_RAISED}'"
	FAIL=1
fi

ISOPEN_40301="$(grep -c '^40301$' "$LOCAL_LOG")"
if [ "$ISOPEN_40301" -ge 1 ]; then
	echo "PASS: AC2 - func_door_24.isOpen() reports open (40301) after raising g_doorTraceDist and retrying"
else
	echo "FAIL: expected to see '40301' in the log (40300 + func_door_24.isOpen()) after raising g_doorTraceDist and retrying"
	FAIL=1
fi

echo
if [ $FAIL -eq 0 ]; then
	echo "PASS: #40 door-open scenario - the player opens an unlocked door with the use key within g_doorTraceDist"
	exit 0
else
	echo "FAIL: #40 door-open scenario - see above"
	exit 1
fi
