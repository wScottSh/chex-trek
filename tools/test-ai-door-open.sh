#!/usr/bin/env bash
# Automated test for spec #42's acceptance criteria (decomp-so/reference/door-opening.md's
# idAI::OpenDoors Notes: idAI::Spawn's "canopendoors" spawnArg (default 1) and the
# AnimMove/FlyMove/SlideMove wiring that calls OpenDoors( GetSlideMoveEntity() ) whenever a
# monster's own movement is blocked by something, ported in #42). See
# docs/harness-coverage.md.
#   AC1: a spawned monster pathing through a closed door opens it (log/dump)
#   AC2: same with canopendoors 0; the door stays shut
#
# idAI::OpenDoors/Event_OpenDoors and the "openDoors" script event themselves already landed with
# spec #30 (tools/test-script-events.sh exercises them via an explicit
# monster.openDoors(doorEnt) script call) - this scenario never calls that script event. The only
# thing that can open the door here is the automatic C++ wiring #42 adds (the identical
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
#      `if ( canOpenDoors ) { OpenDoors( blockEnt ); } ` #42 added to AnimMove/FlyMove
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
#      returning the door and #42's wiring firing - confirmed directly via
#      `ai_blocked_last` on an actual run, in both the open (AC1, where `ai_opendoor_count`/
#      `_last` confirm it too) and blocked (AC2, where `canopendoors 0` keeps `ai_opendoor_count`/
#      `_last` from ever moving, so `ai_blocked_last` is AC2's only such proof) cases, with both
#      ending at essentially the same final `distanceToPoint()` reading (~67 units from the
#      -256 184 64 target, down from ~76 at spawn) either way - asserted below, not just observed
#      manually.
#
# `chextrek_test_str14` (ChexTrekDump.cpp, #42) holds the spawned monster's own name,
# quoted, for the same reason `chextrek_test_str10`/`_11`/etc. hold door names - see
# tools/test-door-open.sh's header for the full "console tokenizer strips quotes"/"$name is cvar
# expansion, not doom-script's $entityName" story.
#
# `chextrek_test_str15` (ChexTrekDump.cpp, #42) holds a whole single-quoted doom-script
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
# `ai_opendoor_count`/`ai_opendoor_last` (ChexTrekDump.cpp, #42) record every time
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
# closed->opening->open->closing->closed all inside a few seconds). So AC1 below polls isOpen()
# repeatedly (14 checks, `wait 400` apart - the console's own `wait` argument is in engine frames,
# not ms; `tools/test-end-level-nextmap.sh`'s header measured `wait 10` at ~167ms of sim time, so
# `wait 400` here is closer to ~6.7s per poll, several times longer than the door's own ~3-second
# open window - comfortably enough margin that at least one poll should land inside it regardless
# of exactly when the walk itself finishes), markers 44100/44200/.../45400 each plus isOpen()) and
# passes if *any* of them ever reads open - proof the door genuinely opened, independent of exactly
# when that open window lands relative to the poll cadence. AC2 polls on the same schedule (markers
# 46100/46200/.../47400) and requires *every* one of them to read closed.
#
# canopendoors 0 blocking the door and a monster sitting still both read as "every poll closed" on
# the isOpen() checks alone, so both ACs also print distanceToPoint() against the same
# moveToPosition target - once right after spawn (baseline, ~76 units: the monster spawns at
# "-180 184 64", the target is "-256 184 64") and once after the last poll - proving the monster
# actually walked toward the door rather than holding still. distanceToPoint() is 3D, and the
# monster's z can change as it settles onto the floor after spawning, so the measured drop (an
# actual run saw baseline ~76 down to final ~67) isn't simply "horizontal units of progress" - only
# that some net movement toward the target happened. AC1 uses markers 90000 (baseline)/91000
# (final); AC2 uses 93000/94000 - all four ranges sit well clear of the 43000/44100-45400/
# 46100-47400 isOpen() marker ranges above (distanceToPoint returns double-digit-to-low-hundreds
# units here, so none of these can collide).
#
# Neither isOpen() nor distanceToPoint() can tell whether func_door_1 *specifically* is what
# stopped the monster (as opposed to something else in its path), which matters most for AC2:
# canopendoors 0 means idAI::OpenDoors - and so ai_opendoor_count/_last - never runs at all, so
# AC2's own acceptance criterion ("the monster is blocked and the door stays shut") needs a signal
# independent of that gating. `idAI::moveStatus()` looked like a candidate but doesn't work: an
# actual run showed it's driven by SlideMove's own AAS-level CheckObstacleAvoidance call, a
# different subsystem from the direct physics collision this scenario exercises, and it never left
# MOVE_STATUS_MOVING/_DONE here. `ai_blocked_last` (ChexTrekDump.cpp, #42) is what
# actually closes this: it reads `physicsObj.GetSlideMoveEntity()` unconditionally, before the
# `if ( canOpenDoors )` check, so it fires the same way regardless of canopendoors.
#
# What distanceToPoint() alone can't prove is that func_door_1 *specifically* is what stopped the
# monster short of the target, as opposed to something else in the way: `idAI::MoveToPosition`'s
# own AAS-reachability refusal (see point 3 above) rules out "it just stopped because the AAS said
# so", but no script event exposes `physicsObj.GetSlideMoveEntity()` (the actual blocking-entity
# accessor #42's C++ wiring reads) or an equivalent signal that reliably reads back the
# blocking entity from the console independent of ai_opendoor_count/_last (which AC2, by
# definition, can't rely on - canopendoors 0 means idAI::OpenDoors, and therefore
# ai_opendoor_count/_last, never runs at all). idAI::moveStatus() looked promising but doesn't
# help: it's set by SlideMove's own GetMovePos -> CheckObstacleAvoidance call, a separate AAS-level
# obstacle-avoidance system from the direct physics collision AC1/AC2 actually exercise, and an
# actual run confirmed it never leaves MOVE_STATUS_MOVING/_DONE here. AC1 is still fully proven -
# ai_opendoor_count/_last name func_door_1 directly - but AC2's proof rests on distanceToPoint()
# plus the map geometry (func_door_1 is the only solid thing between the spawn point and the
# target; see point 3 above), not on a second, independent contact signal. Recorded here rather
# than left silent.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRATCH_DIR="$(mktemp -d)"
trap 'rm -rf "$SCRATCH_DIR"' EXIT

# shellcheck source=tools/lib-harness.sh
source "${SCRIPT_DIR}/lib-harness.sh"

echo "=== #42 ai-door-open test: build ==="
chextrek_build_or_exit

FAIL=0

# --- AC1: canopendoors defaults to 1 - the monster opens the door it walks into ---
CONSOLE_SCRIPT_AC1="${SCRATCH_DIR}/ai-door-open-ac1.cfg"
cat > "$CONSOLE_SCRIPT_AC1" <<'EOF'
developer 1
map sf_923
wait 20
chextrek_dump
script sys.println( 43000 + sys.getEntity( $chextrek_test_str10 ).isOpen() )

spawn monster_chex_biped name chextrek_test_ai_monster origin "-180 184 64" angle "180" neverDormant "1"
wait 30
set chextrek_test_str15 "'-256 184 64'"
script sys.println( 90000 + sys.getEntity( $chextrek_test_str14 ).distanceToPoint( $chextrek_test_str15 ) )
script sys.getEntity( $chextrek_test_str14 ).setMoveType( 2 )
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
script sys.println( 91000 + sys.getEntity( $chextrek_test_str14 ).distanceToPoint( $chextrek_test_str15 ) )

chextrek_dump
screenshot chextrek_ai_door_open_ac1
wait 10
quit
EOF

echo
echo "=== #42 ai-door-open test: AC1 scenario run ==="
chextrek_run_scenario chextrek_ai_door_open_ac1 "$CONSOLE_SCRIPT_AC1" 150 || FAIL=1

LOCAL_LOG_AC1="$CHEXTREK_SCENARIO_LOG"
if [ -z "$LOCAL_LOG_AC1" ]; then
	echo "FAIL: couldn't find the archived AC1 log to check scenario-specific assertions"
	FAIL=1
else
	chextrek_assert_map_loaded "$LOCAL_LOG_AC1" sf_923 || FAIL=1

	COUNT_43000="$(grep -c '^43000$' "$LOCAL_LOG_AC1")"
	if [ "$COUNT_43000" -ge 1 ]; then
		echo "PASS: AC1 - func_door_1.isOpen() reports closed (43000) before the monster moves"
	else
		echo "FAIL: expected to see '43000' in the AC1 log before the monster moves"
		FAIL=1
	fi

	AI_OPENDOOR_COUNT_VALUES="$(chextrek_line_field_values "$LOCAL_LOG_AC1" ai_opendoor_count)"
	AI_OPENDOOR_COUNT_BASELINE="$(echo "$AI_OPENDOOR_COUNT_VALUES" | sed -n '1p')"
	AI_OPENDOOR_COUNT_AFTER="$(echo "$AI_OPENDOOR_COUNT_VALUES" | sed -n '2p')"
	AI_OPENDOOR_LAST_AFTER="$(chextrek_line_field_values "$LOCAL_LOG_AC1" ai_opendoor_last | sed -n '2p')"
	if [ "$AI_OPENDOOR_COUNT_BASELINE" = "0" ] \
		&& [ -n "$AI_OPENDOOR_COUNT_AFTER" ] && [ "$AI_OPENDOOR_COUNT_AFTER" -ge $(( AI_OPENDOOR_COUNT_BASELINE + 1 )) ] \
		&& [ "$AI_OPENDOOR_LAST_AFTER" = "func_door_1" ]; then
		echo "PASS: AC1 - idAI::OpenDoors' automatic wiring opened func_door_1 (ai_opendoor_count ${AI_OPENDOOR_COUNT_BASELINE} -> ${AI_OPENDOOR_COUNT_AFTER}, last=func_door_1)"
	else
		# -ge, not -eq baseline+1: func_door_1 auto-closes after ~3s (no "wait"/"toggle"), so if the
		# monster is still pressed against it when it re-closes, OpenDoors can fire a second time
		# across this scenario's ~5.6s poll window - a real re-trigger, not a bug, and AC1 only
		# needs "opened at least once".
		echo "FAIL: expected ai_opendoor_count to go from 0 to at least 1 and ai_opendoor_last=func_door_1, got count='${AI_OPENDOOR_COUNT_BASELINE}'->'${AI_OPENDOOR_COUNT_AFTER}' last='${AI_OPENDOOR_LAST_AFTER}'"
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

	# An already-open-door reading and a never-moved monster would look identical on the isOpen()
	# checks above, so distanceToPoint() against the moveToPosition target proves actual movement
	# too: it must start far (>50 units - confirmed ~76 on an actual run) and then drop by a
	# meaningful margin (>5 units) once blocked at the door - a relative check rather than a fixed
	# final distance, since an actual run measured the SlideMove-blocked resting distance at ~67
	# units (~9 unit net progress before the monster's own bounding volume is stopped by the door's
	# solid brush) - see the header's "canopendoors 0" note above for what this check does and
	# doesn't prove.
	DIST_BASELINE_AC1="$(grep -E '^90[0-9]+(\.[0-9]+)?$' "$LOCAL_LOG_AC1" | head -1)"
	DIST_FINAL_AC1="$(grep -E '^91[0-9]+(\.[0-9]+)?$' "$LOCAL_LOG_AC1" | head -1)"
	if [ -n "$DIST_BASELINE_AC1" ] && [ -n "$DIST_FINAL_AC1" ] \
		&& awk -v b="$DIST_BASELINE_AC1" -v f="$DIST_FINAL_AC1" 'BEGIN{exit !((b-90000)>50 && ((b-90000)-(f-91000))>5)}'; then
		echo "PASS: AC1 - the monster actually walked toward func_door_1 (distanceToPoint ${DIST_BASELINE_AC1} -> ${DIST_FINAL_AC1})"
	else
		echo "FAIL: expected distanceToPoint to start >50 and drop by >5, got baseline='${DIST_BASELINE_AC1}' final='${DIST_FINAL_AC1}'"
		FAIL=1
	fi

	# ai_blocked_last (ChexTrek_NoteAIBlocked, ChexTrekDump.cpp) reads GetSlideMoveEntity()
	# unconditionally, before the canOpenDoors check - independent proof (alongside
	# ai_opendoor_count/_last above) that func_door_1 itself is what the monster's own physics
	# bumped into.
	AI_BLOCKED_LAST_AC1="$(chextrek_line_field_values "$LOCAL_LOG_AC1" ai_blocked_last | sed -n '2p')"
	if [ "$AI_BLOCKED_LAST_AC1" = "func_door_1" ]; then
		echo "PASS: AC1 - ai_blocked_last=func_door_1, proving the monster's own blocked-movement physics bumped into that specific door"
	else
		echo "FAIL: expected ai_blocked_last=func_door_1, got '${AI_BLOCKED_LAST_AC1}'"
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
set chextrek_test_str15 "'-256 184 64'"
script sys.println( 93000 + sys.getEntity( $chextrek_test_str14 ).distanceToPoint( $chextrek_test_str15 ) )
script sys.getEntity( $chextrek_test_str14 ).setMoveType( 2 )
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
script sys.println( 94000 + sys.getEntity( $chextrek_test_str14 ).distanceToPoint( $chextrek_test_str15 ) )

chextrek_dump
screenshot chextrek_ai_door_open_ac2
wait 10
quit
EOF

echo
echo "=== #42 ai-door-open test: AC2 scenario run ==="
chextrek_run_scenario chextrek_ai_door_open_ac2 "$CONSOLE_SCRIPT_AC2" 150 || FAIL=1

LOCAL_LOG_AC2="$CHEXTREK_SCENARIO_LOG"
if [ -z "$LOCAL_LOG_AC2" ]; then
	echo "FAIL: couldn't find the archived AC2 log to check scenario-specific assertions"
	FAIL=1
else
	chextrek_assert_map_loaded "$LOCAL_LOG_AC2" sf_923 || FAIL=1

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

	# Same rationale and thresholds as AC1's distance check above: without this, "canopendoors 0
	# blocked the door" and "the monster never moved" both read as "every poll closed" above. Prove
	# the monster still walked toward func_door_1 even with door-opening disabled (a relative drop,
	# not a fixed final distance - see the AC1 comment for why).
	DIST_BASELINE_AC2="$(grep -E '^93[0-9]+(\.[0-9]+)?$' "$LOCAL_LOG_AC2" | head -1)"
	DIST_FINAL_AC2="$(grep -E '^94[0-9]+(\.[0-9]+)?$' "$LOCAL_LOG_AC2" | head -1)"
	if [ -n "$DIST_BASELINE_AC2" ] && [ -n "$DIST_FINAL_AC2" ] \
		&& awk -v b="$DIST_BASELINE_AC2" -v f="$DIST_FINAL_AC2" 'BEGIN{exit !((b-93000)>50 && ((b-93000)-(f-94000))>5)}'; then
		echo "PASS: AC2 - the monster still walked toward func_door_1 (distanceToPoint ${DIST_BASELINE_AC2} -> ${DIST_FINAL_AC2})"
	else
		echo "FAIL: expected distanceToPoint to start >50 and drop by >5, got baseline='${DIST_BASELINE_AC2}' final='${DIST_FINAL_AC2}'"
		FAIL=1
	fi

	# canopendoors 0 means idAI::OpenDoors (and so ai_opendoor_count/_last) never runs at all, so
	# the distance check above only proves the monster moved, not that func_door_1 specifically is
	# what stopped it. ai_blocked_last (ChexTrek_NoteAIBlocked) closes that gap: it reads
	# GetSlideMoveEntity() unconditionally, before the canOpenDoors check, so it still fires here.
	AI_BLOCKED_LAST_AC2="$(chextrek_line_field_values "$LOCAL_LOG_AC2" ai_blocked_last | sed -n '2p')"
	if [ "$AI_BLOCKED_LAST_AC2" = "func_door_1" ]; then
		echo "PASS: AC2 - ai_blocked_last=func_door_1 even with canopendoors 0, proving func_door_1 itself is what stopped the monster"
	else
		echo "FAIL: expected ai_blocked_last=func_door_1, got '${AI_BLOCKED_LAST_AC2}'"
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
