#!/usr/bin/env bash
# Automated test for spec #42's acceptance criteria (decomp-so/reference/door-opening.md's
# idAI::OpenDoors Notes: idAI::Spawn's "canopendoors" spawnArg (default 1) and the
# AnimMove/FlyMove/SlideMove wiring that calls OpenDoors( GetSlideMoveEntity() ) whenever a
# monster's own movement is blocked by something, ported this sub-issue). See
# docs/harness-coverage.md.
#   AC1: a spawned monster pathing through a closed door opens it (log/dump)
#   AC2: same with canopendoors 0; the door stays shut
#
# idAI::OpenDoors/Event_OpenDoors and the "openDoors" script event themselves already landed with
# spec #30 (tools/test-script-events.sh exercises them via an explicit
# monster.openDoors(doorEnt) script call) - this scenario never calls that script event. The only
# thing that can open the door here is the automatic C++ wiring this sub-issue adds (the identical
# `if ( canOpenDoors ) { OpenDoors( blockEnt ); }` block spliced into AnimMove, FlyMove and
# SlideMove), so any observed open is proof of that wiring, not of the already-covered script
# event.
#
# Drives sf_923 (spec #28's real second map) through console commands only (map, spawn, script,
# set, wait, chextrek_dump), per spec #28's testing decisions. Reuses the same real,
# already-unlocked, "no_touch" func_door_1 (origin -264 184 64) tools/test-door-open.sh uses for
# the player's own use-key scenario (a direct idDoor::Use() call, which is what idAI::OpenDoors
# makes, is unaffected by "no_touch" - that key only blocks stock touch-triggering).
#
# Getting a *console-spawned* monster to physically walk into that door - as opposed to a
# map-placed one already mid-patrol - turned out to need several deliberate choices, each found by
# running the actual harness and reading chextrek_dump/getOrigin()/canReachPosition() back (no
# guessing):
#
#   1. `neverDormant "1"` on the spawn command (stock idEntity spawnArg, Entity.cpp). A freshly
#      spawned AI (fl.hasAwakened false) stays fully dormant - idAI::Think() never runs at all,
#      so it can't move even one unit - until the local player has actually *seen* it once
#      (idEntity::DoDormantTests' InPlayerPVS check). The player's own far-away spawn point never
#      satisfies that, so a plain spawn here would just sit there forever.
#
#   2. The AI's own script state machine (script/ai_monster_base.script) starts by waiting on
#      `AI_ACTIVATED || AI_PAIN` and only chases/paths on its own once it notices an enemy - which
#      needs either a scripted trigger or a live, visible player nearby. Rather than fight that
#      (teleporting the player into view, hoping it aggros, hoping its combat-chase movement
#      happens to route through the door), this scenario drives the *same* C++ movement idAI
#      itself uses directly via already-ported, stock script events: `setMoveType( 2 )`
#      (MOVETYPE_SLIDE - stock idAI::Event_SetMoveType) then `moveToPosition` (idAI::MoveToPosition,
#      also stock). This is not a synthetic path: SlideMove contains the exact same
#      `if ( canOpenDoors ) { OpenDoors( blockEnt ); } ` this sub-issue added to AnimMove/FlyMove
#      too, so exercising it through SlideMove proves the ported wiring, just via a movement type a
#      console script can reliably drive without needing the AI's own combat AI to spontaneously
#      engage.
#
#   3. `idAI::MoveToPosition` (unlike the AAS-agnostic DirectMoveToPosition variants) refuses a
#      target whose area isn't `PathToGoal`-reachable from the AI's own area (StopMove(
#      MOVE_STATUS_DEST_UNREACHABLE), no movement at all - confirmed directly via
#      `canReachPosition()`/`moveStatus()` on an actual run). Every point *past* func_door_1 that
#      was tried (several, at multiple x/y/z combinations, including well inside the room beyond
#      it, and even after manually opening the door first) came back unreachable: this sf_923
#      AAS's "func_door_1" room and its far side are simply two disconnected clusters, door state
#      notwithstanding - not something spec #42 needs to fix (a decompiled-content bug or a stale
#      compiled .aas file "the ~14 uncompiled .map files" out-of-scope note doesn't cover, since
#      sf_923 itself *is* compiled). So the target used below, -256 184 64, is the *closest
#      reachable point on the door's own (near) side* - just short of the door's own face-plane
#      brush a few units off its origin (see tools/test-door-open.sh's header for those exact brush
#      offsets) - not a synthetic fixture, just a deliberately short walk. `idAI::SlideMove`'s
#      velocity-seeking movement (a damped spring toward the goal, not an instant snap) reliably
#      carries the AI's own bounding volume into the closed door's solid brush well before it
#      "reaches" that nominal target point, which is exactly what triggers `GetSlideMoveEntity()`
#      returning the door and this sub-issue's wiring firing - confirmed directly via
#      `ai_opendoor_count`/`ai_opendoor_last` on an actual run, in both the open (AC1) and blocked
#      (AC2) cases, with both ending at essentially the same final position (~-237 182) either way.
#
# `chextrek_test_str14` (ChexTrekDump.cpp, this sub-issue) holds the spawned monster's own name,
# quoted, for the same reason `chextrek_test_str10`/`_11`/etc. hold door names - see
# tools/test-door-open.sh's header for the full "console tokenizer strips quotes"/"$name is cvar
# expansion, not doom-script's $entityName" story.
#
# `chextrek_test_str15` (ChexTrekDump.cpp, this sub-issue) holds a whole single-quoted doom-script
# vector literal as its cvar *value*, set at runtime via the stock `set` console command
# (`set chextrek_test_str15 "'-256 184 64'"` - the outer double quotes are the console's own
# argument grouping, stripped during tokenization same as any other console argument; the inner
# single quotes are literal cvar-value content, untouched). A vector literal typed directly on a
# "script" console line hits a *different* quoting gap from the double-quote/`$name` one above: the
# console's own tokenizer's lexer isn't configured with LEXFL_ALLOWMULTICHARLITERALS
# (idlib/CmdArgs.cpp), so it doesn't treat a single quote as a vector-literal delimiter the way
# game/script/Script_Compiler.cpp's lexer does, and re-lexing/reassembling it through
# Cmd_Script_f's args.Args() produces something that fails to compile as a vector ("Error: type
# mismatch on parm 1 of call to 'moveToPosition'", confirmed on an actual run). Substituting a cvar
# whose value is already the complete "'x y z'" text sidesteps that: cvar expansion splices the
# stored string in as one already-formed token, so the console tokenizer's lexer never re-parses
# those quote characters at all - see ChexTrekDump.cpp's comment above chextrek_test_str15 for the
# fuller story.
#
# `ai_opendoor_count`/`ai_opendoor_last` (ChexTrekDump.cpp, this sub-issue) record every time
# idAI::OpenDoors actually activated a door (the unlocked-and-at-rest branch), independent of the
# door's own isOpen() state - the only way this scenario can tell "the AI's own blocked-movement
# wiring opened this door" from "the door happened to already be open for some other reason",
# mirroring `door_tryopen_count`/`_last`'s role for the player's tryOpen (spec #40).
#
# func_door_1 has no "wait"/"toggle" override, so it uses idMover_Binary's own stock default
# behavior once `door->Use()` (idDoor::Use -> Use_BinaryMover) starts it: open, sit at rest for
# `wait` seconds (stock default 3), then close itself again automatically - the same auto-close
# every plain, non-toggle func_door in this mod already has. A single isOpen() check some fixed
# time after the walk can land on either side of that ~3-second open window and wrongly read as
# "never opened" (confirmed on an actual run: `SetMoverState` traced the real sequence
# closed->opening->open->closing->closed all inside about 5.5 seconds). So AC1 below polls
# isOpen() repeatedly (14 checks, `wait 400` apart, markers 44100/44200/.../45400 each plus
# isOpen()) across a window wide enough to cover both the walk itself and the door's own
# open/close cycle, and passes if *any* of them ever reads open - proof the door genuinely opened,
# independent of exactly when that 3-second window lands relative to the poll cadence. AC2 polls
# on the same schedule (markers 46100/46200/.../47400) and requires *every* one of them to read
# closed.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRATCH_DIR="$(mktemp -d)"
trap 'rm -rf "$SCRATCH_DIR"' EXIT

# shellcheck source=tools/lib-harness.sh
source "${SCRIPT_DIR}/lib-harness.sh"

echo "=== #42 ai-door-open test: build ==="
if ! bash "${SCRIPT_DIR}/build-chextrek.sh"; then
	echo "FAIL: build-chextrek.sh failed"
	exit 1
fi

FAIL=0

# --- AC1: canopendoors defaults to 1 - the monster opens the door it walks into ---
CONSOLE_SCRIPT_AC1="${SCRATCH_DIR}/ai-door-open-ac1.cfg"
cat > "$CONSOLE_SCRIPT_AC1" <<'EOF'
developer 1
map sf_923
wait 20
chextrek_dump
script sys.println( 44000 + sys.getEntity( $chextrek_test_str10 ).isOpen() )

spawn monster_chex_biped name chextrek_test_ai_monster origin "-180 184 64" angle "180" neverDormant "1"
wait 30
script sys.getEntity( $chextrek_test_str14 ).setMoveType( 2 )
set chextrek_test_str15 "'-256 184 64'"
script sys.getEntity( $chextrek_test_str14 ).moveToPosition( $chextrek_test_str15 )

wait 400
script sys.println( 44100 + sys.getEntity( $chextrek_test_str10 ).isOpen() )
wait 400
script sys.println( 44200 + sys.getEntity( $chextrek_test_str10 ).isOpen() )
wait 400
script sys.println( 44300 + sys.getEntity( $chextrek_test_str10 ).isOpen() )
wait 400
script sys.println( 44400 + sys.getEntity( $chextrek_test_str10 ).isOpen() )
wait 400
script sys.println( 44500 + sys.getEntity( $chextrek_test_str10 ).isOpen() )
wait 400
script sys.println( 44600 + sys.getEntity( $chextrek_test_str10 ).isOpen() )
wait 400
script sys.println( 44700 + sys.getEntity( $chextrek_test_str10 ).isOpen() )
wait 400
script sys.println( 44800 + sys.getEntity( $chextrek_test_str10 ).isOpen() )
wait 400
script sys.println( 44900 + sys.getEntity( $chextrek_test_str10 ).isOpen() )
wait 400
script sys.println( 45000 + sys.getEntity( $chextrek_test_str10 ).isOpen() )
wait 400
script sys.println( 45100 + sys.getEntity( $chextrek_test_str10 ).isOpen() )
wait 400
script sys.println( 45200 + sys.getEntity( $chextrek_test_str10 ).isOpen() )
wait 400
script sys.println( 45300 + sys.getEntity( $chextrek_test_str10 ).isOpen() )
wait 400
script sys.println( 45400 + sys.getEntity( $chextrek_test_str10 ).isOpen() )

chextrek_dump
screenshot chextrek_ai_door_open_ac1
wait 10
quit
EOF

echo
echo "=== #42 ai-door-open test: AC1 scenario run ==="
RUN_OUT_AC1="$(bash "${SCRIPT_DIR}/run-scenario.sh" chextrek_ai_door_open_ac1 "$CONSOLE_SCRIPT_AC1" 150 2>&1)"
RUN_EXIT_AC1=$?
echo "$RUN_OUT_AC1"

if [ $RUN_EXIT_AC1 -ne 0 ]; then
	echo "FAIL: expected the always-on harness checks to pass on AC1, but the run exited ${RUN_EXIT_AC1}"
	FAIL=1
fi

LOCAL_LOG_AC1="$(echo "$RUN_OUT_AC1" | sed -n 's/^CHEXTREK_LOCAL_LOG=//p')"
if [ -z "$LOCAL_LOG_AC1" ] || [ ! -f "$LOCAL_LOG_AC1" ]; then
	echo "FAIL: couldn't find the archived AC1 log to check scenario-specific assertions"
	FAIL=1
else
	if grep -qE '^ *[0-9]+ msec to load sf_923$' "$LOCAL_LOG_AC1"; then
		echo "PASS: sf_923 finished loading (AC1)"
	else
		echo "FAIL: expected to see '<N> msec to load sf_923' in the AC1 log"
		FAIL=1
	fi

	COUNT_44000="$(grep -c '^44000$' "$LOCAL_LOG_AC1")"
	if [ "$COUNT_44000" -ge 1 ]; then
		echo "PASS: AC1 - func_door_1.isOpen() reports closed (44000) before the monster moves"
	else
		echo "FAIL: expected to see '44000' in the AC1 log before the monster moves"
		FAIL=1
	fi

	AI_OPENDOOR_COUNT_VALUES="$(chextrek_line_field_values "$LOCAL_LOG_AC1" ai_opendoor_count)"
	AI_OPENDOOR_COUNT_BASELINE="$(echo "$AI_OPENDOOR_COUNT_VALUES" | sed -n '1p')"
	AI_OPENDOOR_COUNT_AFTER="$(echo "$AI_OPENDOOR_COUNT_VALUES" | sed -n '2p')"
	AI_OPENDOOR_LAST_AFTER="$(chextrek_line_field_values "$LOCAL_LOG_AC1" ai_opendoor_last | sed -n '2p')"
	if [ "$AI_OPENDOOR_COUNT_BASELINE" = "0" ] \
		&& [ -n "$AI_OPENDOOR_COUNT_AFTER" ] && [ "$AI_OPENDOOR_COUNT_AFTER" -eq $(( AI_OPENDOOR_COUNT_BASELINE + 1 )) ] \
		&& [ "$AI_OPENDOOR_LAST_AFTER" = "func_door_1" ]; then
		echo "PASS: AC1 - idAI::OpenDoors' automatic wiring opened func_door_1 (ai_opendoor_count ${AI_OPENDOOR_COUNT_BASELINE} -> ${AI_OPENDOOR_COUNT_AFTER}, last=func_door_1)"
	else
		echo "FAIL: expected ai_opendoor_count to go 0 -> 1 and ai_opendoor_last=func_door_1, got count='${AI_OPENDOOR_COUNT_BASELINE}'->'${AI_OPENDOOR_COUNT_AFTER}' last='${AI_OPENDOOR_LAST_AFTER}'"
		FAIL=1
	fi

	# Any one of the 14 polls (44101/44201/.../45401, spaced 400 wait ticks apart across the walk
	# and the door's own ~3-second open window) reading with a trailing "1" proves isOpen() was
	# true at that poll - see the header comment above for why a single fixed-time check isn't
	# reliable here.
	OPEN_POLL_COUNT="$(grep -cE '^4[45][0-9]01$' "$LOCAL_LOG_AC1")"
	if [ "$OPEN_POLL_COUNT" -ge 1 ]; then
		echo "PASS: AC1 - func_door_1.isOpen() read open on at least one of the polls after the monster walked into it (${OPEN_POLL_COUNT} of 14 polls)"
	else
		echo "FAIL: expected at least one of the 14 isOpen() polls after the walk to read open, got none"
		FAIL=1
	fi
fi

# --- AC2: canopendoors 0 - the monster is blocked and the door stays shut ---
CONSOLE_SCRIPT_AC2="${SCRATCH_DIR}/ai-door-open-ac2.cfg"
cat > "$CONSOLE_SCRIPT_AC2" <<'EOF'
developer 1
map sf_923
wait 20
chextrek_dump
script sys.println( 45000 + sys.getEntity( $chextrek_test_str10 ).isOpen() )

spawn monster_chex_biped name chextrek_test_ai_monster origin "-180 184 64" angle "180" canopendoors "0" neverDormant "1"
wait 30
script sys.getEntity( $chextrek_test_str14 ).setMoveType( 2 )
set chextrek_test_str15 "'-256 184 64'"
script sys.getEntity( $chextrek_test_str14 ).moveToPosition( $chextrek_test_str15 )

wait 400
script sys.println( 46100 + sys.getEntity( $chextrek_test_str10 ).isOpen() )
wait 400
script sys.println( 46200 + sys.getEntity( $chextrek_test_str10 ).isOpen() )
wait 400
script sys.println( 46300 + sys.getEntity( $chextrek_test_str10 ).isOpen() )
wait 400
script sys.println( 46400 + sys.getEntity( $chextrek_test_str10 ).isOpen() )
wait 400
script sys.println( 46500 + sys.getEntity( $chextrek_test_str10 ).isOpen() )
wait 400
script sys.println( 46600 + sys.getEntity( $chextrek_test_str10 ).isOpen() )
wait 400
script sys.println( 46700 + sys.getEntity( $chextrek_test_str10 ).isOpen() )
wait 400
script sys.println( 46800 + sys.getEntity( $chextrek_test_str10 ).isOpen() )
wait 400
script sys.println( 46900 + sys.getEntity( $chextrek_test_str10 ).isOpen() )
wait 400
script sys.println( 47000 + sys.getEntity( $chextrek_test_str10 ).isOpen() )
wait 400
script sys.println( 47100 + sys.getEntity( $chextrek_test_str10 ).isOpen() )
wait 400
script sys.println( 47200 + sys.getEntity( $chextrek_test_str10 ).isOpen() )
wait 400
script sys.println( 47300 + sys.getEntity( $chextrek_test_str10 ).isOpen() )
wait 400
script sys.println( 47400 + sys.getEntity( $chextrek_test_str10 ).isOpen() )

chextrek_dump
screenshot chextrek_ai_door_open_ac2
wait 10
quit
EOF

echo
echo "=== #42 ai-door-open test: AC2 scenario run ==="
RUN_OUT_AC2="$(bash "${SCRIPT_DIR}/run-scenario.sh" chextrek_ai_door_open_ac2 "$CONSOLE_SCRIPT_AC2" 150 2>&1)"
RUN_EXIT_AC2=$?
echo "$RUN_OUT_AC2"

if [ $RUN_EXIT_AC2 -ne 0 ]; then
	echo "FAIL: expected the always-on harness checks to pass on AC2, but the run exited ${RUN_EXIT_AC2}"
	FAIL=1
fi

LOCAL_LOG_AC2="$(echo "$RUN_OUT_AC2" | sed -n 's/^CHEXTREK_LOCAL_LOG=//p')"
if [ -z "$LOCAL_LOG_AC2" ] || [ ! -f "$LOCAL_LOG_AC2" ]; then
	echo "FAIL: couldn't find the archived AC2 log to check scenario-specific assertions"
	FAIL=1
else
	if grep -qE '^ *[0-9]+ msec to load sf_923$' "$LOCAL_LOG_AC2"; then
		echo "PASS: sf_923 finished loading (AC2)"
	else
		echo "FAIL: expected to see '<N> msec to load sf_923' in the AC2 log"
		FAIL=1
	fi

	COUNT_45000="$(grep -c '^45000$' "$LOCAL_LOG_AC2")"
	if [ "$COUNT_45000" -ge 1 ]; then
		echo "PASS: AC2 - func_door_1.isOpen() reports closed (45000) before the monster moves"
	else
		echo "FAIL: expected to see '45000' in the AC2 log before the monster moves"
		FAIL=1
	fi

	AI_OPENDOOR_COUNT_VALUES_AC2="$(chextrek_line_field_values "$LOCAL_LOG_AC2" ai_opendoor_count)"
	AI_OPENDOOR_COUNT_BASELINE_AC2="$(echo "$AI_OPENDOOR_COUNT_VALUES_AC2" | sed -n '1p')"
	AI_OPENDOOR_COUNT_AFTER_AC2="$(echo "$AI_OPENDOOR_COUNT_VALUES_AC2" | sed -n '2p')"
	if [ "$AI_OPENDOOR_COUNT_BASELINE_AC2" = "0" ] && [ "$AI_OPENDOOR_COUNT_AFTER_AC2" = "0" ]; then
		echo "PASS: AC2 - canopendoors 0 kept idAI::OpenDoors from ever running (ai_opendoor_count stayed 0)"
	else
		echo "FAIL: expected ai_opendoor_count to stay 0, got '${AI_OPENDOOR_COUNT_BASELINE_AC2}' then '${AI_OPENDOOR_COUNT_AFTER_AC2}'"
		FAIL=1
	fi

	# Same 14-poll schedule as AC1 (markers 46100/46200/.../47400, each base+isOpen()), but here
	# every single poll must read closed - canopendoors 0 means idAI::OpenDoors never even runs
	# (confirmed above via ai_opendoor_count), so the door has no way to start its own open/close
	# cycle at any point across the same walk-plus-settle window AC1 uses.
	OPEN_POLL_COUNT_AC2="$(grep -cE '^4[67][0-9]01$' "$LOCAL_LOG_AC2")"
	CLOSED_POLL_COUNT_AC2="$(grep -cE '^4[67][0-9]00$' "$LOCAL_LOG_AC2")"
	if [ "$OPEN_POLL_COUNT_AC2" = "0" ] && [ "$CLOSED_POLL_COUNT_AC2" = "14" ]; then
		echo "PASS: AC2 - func_door_1.isOpen() read closed on all 14 polls across the blocked monster's attempt"
	else
		echo "FAIL: expected all 14 isOpen() polls to read closed and none open, got ${CLOSED_POLL_COUNT_AC2} closed / ${OPEN_POLL_COUNT_AC2} open"
		FAIL=1
	fi
fi

echo
if [ $FAIL -eq 0 ]; then
	echo "PASS: #42 ai-door-open scenario - a monster with canopendoors opens a door it bumps into; canopendoors 0 blocks it"
	exit 0
else
	echo "FAIL: #42 ai-door-open scenario - see above"
	exit 1
fi
