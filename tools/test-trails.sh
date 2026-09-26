#!/usr/bin/env bash
# Automated test for spec #43's acceptance criteria (decomp-so/reference/trails.md, ported in
# #43 into game/Trail.h/.cpp plus the "edits inside stock functions" leads spliced into
# Actor.cpp's Spawn/~idActor and Game_local.cpp's RunFrame/BabySitTrail/RemoveTrail):
#   AC1: spawn a flemoid and let it move; the dump trail count rises, then returns to zero after
#        the fade (tested as "returns to its pre-existing baseline", not literally 0 - see below,
#        real content's own pre-placed flemoids already have live trails at map load)
#   AC2: no pointer-to-int casts in the ported trail code (checked statically below, not by the
#        harness run - see the end of this script)
#
# Drives sf_923 (spec #28's real second map, whose entityDef is actually named "monster_flemoid" -
# def/chex_monster_flemoid.def's filename doesn't match its own "entityDef monster_flemoid { ...
# "hasTrail" "1" "trailDef" "trail" ... }" declaration) through console commands only (map, spawn,
# script, remove, wait, chextrek_dump), per spec #28's testing decisions.
#
# sf_923 already places 19 "monster_flemoid" entities directly, one of which ("monster_flemoid_5")
# overrides "hasTrail" "0" - so the baseline is 18 live trails, not 19 (confirmed: `chextrek_dump`
# right after map load already shows a nonzero `trails:` count - there is no flemoid-free real map
# to use as a clean 0 baseline). e1m1 also places 19 "monster_flemoid" entities with no such
# override, but this scenario only runs on sf_923 - #43's AC needs proof on one map, not both, same
# as several other rows in docs/harness-coverage.md. Every assertion below is a *delta* against a
# baseline dump taken right after load, not an absolute 0/1 - this also means "the dump trail count
# rises" is proven by spawning one more on top of whatever the map already placed, exactly like a
# scenario would with any other pre-populated map state.
#
# Real content only ever uses def/slime_trail.def's "trail" entityDef, whose "fadeTime" "-1" means
# (decomp-so/reference/trails.md's Notes) a trail never deletes itself - it lasts the whole level
# by design, which makes AC1's "returns to zero after the fade" unobservable with unmodified content.
# So this scenario spawns its own flemoid with a test-only fixture as its "trailDef" override
# (idActor::Spawn reads that spawnArg to pick the entityDef it copies into the new mkTrail): an
# entityDef that inherits everything from "trail" and only shortens fadeDelay/fadeTime. The fixture
# is written to a scratch dir and handed to the harness as CHEXTREK_FIXTURE_DIR, which copies it
# into the scratch save path - it never lives in the shipped mod data.
#
# `neverDormant "1"` keeps the console-spawned flemoid's idAI::Think running so it can move; it
# spawns at sf_923's own info_player_start_1 ("16 -224 0"/"135"). `setMoveType( 2 )`/
# `moveToPosition( ... )` (stock idAI script events) drive a real walk, proven via
# distanceToPoint(). `remove` (Cmd_Remove_f) deletes it synchronously, so ~idActor calls
# trail->FadeTrail() at once; with the fixture's "fadeTime" "2" the trail deletes itself (and
# RemoveTrail drops it from gameLocal.trails) 2 s of game time later. The "script" lines reach the
# monster through $chextrek_test_str14, whose compiled-in value is its name (see ChexTrekDump.cpp).
#
# "Trails appear where they should" is asserted on the map's own flemoids, as a nonzero baseline
# `anchors` count: mkTrail::addNewAnchor only adds an anchor where its trace down from the actor's
# position hits ground within maxSurfDist, so every counted anchor sits on the ground under the
# actor. (The count, not each anchor's position, is what the dump exposes.) This scenario's own
# spawned trail is NOT asserted to lay anchors: mkTrail::lastPos is never initialized (reference
# Notes; an original-mod bug spec #28 leaves alone since it doesn't crash). An in-game check (a
# temporary log line in mkTrail::addNewAnchor) showed about half of sf_923's trails start with a
# garbage lastPos (NaN, or values ~1e38 whose squared length overflows): Think's `LengthFast() >
# updateDist` test is then always false, so those trails never update or anchor for the whole level.
# Whether the spawned one does depends on heap contents, so its anchor count is reported as INFO
# only.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SCRATCH_DIR="$(mktemp -d)"
trap 'rm -rf "$SCRATCH_DIR"' EXIT

# shellcheck source=tools/lib-harness.sh
source "${SCRIPT_DIR}/lib-harness.sh"

echo "=== #43 trails test: build ==="
chextrek_build_or_exit

mkdir -p "${SCRATCH_DIR}/fixture/def"
cat > "${SCRATCH_DIR}/fixture/def/chextrek_test_trail.def" <<'EOF'
// Test-only fixture for tools/test-trails.sh: "trail" with a 2-second fade.
entityDef chextrek_test_trail_fastfade {
	"inherit"					"trail"
	"fadeDelay"					"0"
	"fadeTime"					"2"
}
EOF
export CHEXTREK_FIXTURE_DIR="${SCRATCH_DIR}/fixture"

FAIL=0

# --- AC1: a moving flemoid's trail rises, then is fully cleaned up after the fade ---
CONSOLE_SCRIPT="${SCRATCH_DIR}/trails-ac1.cfg"
cat > "$CONSOLE_SCRIPT" <<'EOF'
developer 1
map sf_923
wait 20
chextrek_dump

spawn monster_flemoid name chextrek_test_ai_monster origin "16 -224 0" angle "135" trailDef "chextrek_test_trail_fastfade" neverDormant "1"
wait 30
chextrek_dump

set chextrek_test_str15 "'-12 -196 0'"
script sys.println( 90000 + sys.getEntity( $chextrek_test_str14 ).distanceToPoint( $chextrek_test_str15 ) )
script sys.getEntity( $chextrek_test_str14 ).setMoveType( 2 )
script sys.getEntity( $chextrek_test_str14 ).moveToPosition( $chextrek_test_str15 )
wait 500
script sys.println( 91000 + sys.getEntity( $chextrek_test_str14 ).distanceToPoint( $chextrek_test_str15 ) )
chextrek_dump

remove chextrek_test_ai_monster
wait 20
chextrek_dump
wait 300
chextrek_dump
wait 300
chextrek_dump
wait 300
chextrek_dump
wait 300
chextrek_dump
wait 300
chextrek_dump

screenshot chextrek_trails_ac1
wait 10
quit
EOF

echo
echo "=== #43 trails test: AC1 scenario run ==="
chextrek_run_scenario chextrek_trails_ac1 "$CONSOLE_SCRIPT" 150 || FAIL=1
LOCAL_LOG="$CHEXTREK_SCENARIO_LOG"
if [ -z "$LOCAL_LOG" ]; then
	echo "FAIL: couldn't find the archived log to check scenario-specific assertions"
	FAIL=1
else
	chextrek_assert_map_loaded "$LOCAL_LOG" sf_923 || FAIL=1

	# Nine chextrek_dump calls in the script above, in order: (1) baseline, right after map load
	# (already nonzero - see the header comment above), (2) right after spawn, (3) after the walk,
	# (4) right after remove, (5)-(9) five more polls, ~300 wait-ticks apart, well past the
	# fixture's 2-second fadeTime by the last one (a "wait" tick is one rendered frame, a few ms of
	# game time that varies by run - see docs/harness-coverage.md - so staggered dumps give margin).
	# chextrek_line_field_values returns one value per dump, in order; the LAST one is what "once
	# the fade finished" checks. Every check below is a delta against the baseline, since the map's
	# own pre-placed flemoids' trails are part of every one of these counts too.
	TRAILS_VALUES="$(chextrek_line_field_values "$LOCAL_LOG" trails)"
	ANCHORS_VALUES="$(chextrek_line_field_values "$LOCAL_LOG" anchors)"
	TRAILS_BASELINE="$(echo "$TRAILS_VALUES" | sed -n '1p')"
	TRAILS_AFTER_SPAWN="$(echo "$TRAILS_VALUES" | sed -n '2p')"
	TRAILS_AFTER_WALK="$(echo "$TRAILS_VALUES" | sed -n '3p')"
	TRAILS_AFTER_REMOVE="$(echo "$TRAILS_VALUES" | sed -n '4p')"
	TRAILS_FINAL="$(echo "$TRAILS_VALUES" | tail -1)"
	ANCHORS_BASELINE="$(echo "$ANCHORS_VALUES" | sed -n '1p')"
	ANCHORS_AFTER_WALK="$(echo "$ANCHORS_VALUES" | sed -n '3p')"

	echo "trails: baseline=${TRAILS_BASELINE} after_spawn=${TRAILS_AFTER_SPAWN} after_walk=${TRAILS_AFTER_WALK} after_remove=${TRAILS_AFTER_REMOVE} final=${TRAILS_FINAL}"
	echo "anchors: baseline=${ANCHORS_BASELINE} after_walk=${ANCHORS_AFTER_WALK}"

	if [ -n "$TRAILS_BASELINE" ] && [ -n "$TRAILS_AFTER_SPAWN" ] && [ -n "$TRAILS_AFTER_WALK" ] \
		&& [ "$TRAILS_AFTER_SPAWN" -eq $(( TRAILS_BASELINE + 1 )) ] \
		&& [ "$TRAILS_AFTER_WALK" = "$TRAILS_AFTER_SPAWN" ]; then
		echo "PASS: the flemoid's mkTrail exists right after spawn and through its walk (trails: baseline ${TRAILS_BASELINE} -> ${TRAILS_AFTER_SPAWN}, rises by exactly 1)"
	else
		echo "FAIL: expected trails to rise by exactly 1 after spawn and hold through the walk, got baseline='${TRAILS_BASELINE}' after_spawn='${TRAILS_AFTER_SPAWN}' after_walk='${TRAILS_AFTER_WALK}'"
		FAIL=1
	fi

	# AC1 says "let it move" - proving that directly (not just that a trail object exists) the same
	# way tools/test-ai-door-open.sh does: distanceToPoint() against the moveToPosition target,
	# once right after spawn (before setMoveType/moveToPosition run) and once after the wait. This
	# gates on real movement happening, independent of the anchors question below.
	DIST_BASELINE="$(grep -E '^90[0-9]+(\.[0-9]+)?$' "$LOCAL_LOG" | head -1)"
	DIST_FINAL="$(grep -E '^91[0-9]+(\.[0-9]+)?$' "$LOCAL_LOG" | head -1)"
	if [ -n "$DIST_BASELINE" ] && [ -n "$DIST_FINAL" ] \
		&& awk -v b="$DIST_BASELINE" -v f="$DIST_FINAL" 'BEGIN{exit !((b-90000)>10 && ((b-90000)-(f-91000))>5)}'; then
		echo "PASS: the flemoid actually walked toward the target (distanceToPoint ${DIST_BASELINE} -> ${DIST_FINAL})"
	else
		echo "FAIL: expected distanceToPoint to start >10 and drop by >5, got baseline='${DIST_BASELINE}' final='${DIST_FINAL}'"
		FAIL=1
	fi

	# Trails appear where they should: the map's own flemoids' trails anchored on the ground below
	# them (see the header for why the spawned trail's anchors are INFO only).
	if [ -n "$ANCHORS_BASELINE" ] && [ "$ANCHORS_BASELINE" -ge 1 ]; then
		echo "PASS: the map's own flemoids' trails laid anchors on the ground below them (anchors: ${ANCHORS_BASELINE} at load)"
	else
		echo "FAIL: expected the map's own flemoid trails to have laid at least one anchor at load, got anchors='${ANCHORS_BASELINE}'"
		FAIL=1
	fi
	if [ -n "$ANCHORS_AFTER_WALK" ] && [ -n "$ANCHORS_BASELINE" ] && [ "$ANCHORS_AFTER_WALK" -gt "$ANCHORS_BASELINE" ]; then
		echo "INFO: the spawned flemoid's trail laid anchors while it walked (anchors: ${ANCHORS_BASELINE} -> ${ANCHORS_AFTER_WALK})"
	else
		echo "INFO: the spawned flemoid's trail laid no anchor (anchors stayed at ${ANCHORS_AFTER_WALK}) - uninitialized mkTrail::lastPos, see the header"
	fi

	# Right after remove: the trail is still in gameLocal.trails (FadeTrail only detaches it and
	# starts the fade timer - Think() doesn't delete it until real time passes the fixture's
	# 2-second fadeTime), so this proves FadeTrail alone doesn't instantly free it.
	if [ -n "$TRAILS_AFTER_REMOVE" ] && [ -n "$TRAILS_AFTER_SPAWN" ] && [ "$TRAILS_AFTER_REMOVE" = "$TRAILS_AFTER_SPAWN" ]; then
		echo "PASS: the trail survives the flemoid's removal, mid-fade (trails: still ${TRAILS_AFTER_REMOVE})"
	else
		echo "FAIL: expected trails to still be ${TRAILS_AFTER_SPAWN} right after remove (still fading), got '${TRAILS_AFTER_REMOVE}'"
		FAIL=1
	fi

	if [ -n "$TRAILS_FINAL" ] && [ -n "$TRAILS_BASELINE" ] && [ "$TRAILS_FINAL" = "$TRAILS_BASELINE" ]; then
		echo "PASS: the trail is fully cleaned up once the fade finishes (trails: back down to baseline ${TRAILS_BASELINE})"
	else
		echo "FAIL: expected trails to return to baseline (${TRAILS_BASELINE}) once the fade finished, got '${TRAILS_FINAL}'"
		FAIL=1
	fi
fi

# --- AC2: no pointer-to-int casts in the ported trail code ---
# A static source check, not a harness run - the same class of check spec #28's Implementation
# Decisions describe ("Replace pointer-to-int casts with pointer-size-safe forms"). The reference
# (decomp-so/reference/trails.md) reads `reinterpret_cast<int>( this )` twice (Spawn, Restore) to
# stash the trail pointer in `renderEntity.entityNum` for ModelCallback to recover; the ported
# game/Trail.cpp instead uses `renderEntity.callbackData` (a `void *` field renderer/RenderWorld.h
# already documents as "used for whatever the callback wants") - no cast at all going in, and a
# plain `void *` to `mkTrail *` cast (never through `int`) coming back out in ModelCallback. grep
# for the reference's own pattern, other direct pointer<->int casts, and an int-narrowed round-trip
# through another integer type (e.g. `static_cast<int>( reinterpret_cast<intptr_t>(...) )`), in
# case a future change reintroduces the same shape a different way.
echo
echo "=== #43 trails test: AC2 static check (no pointer-to-int casts) ==="
TRAIL_CPP="${REPO_ROOT}/engine/dhewm3-sdk/game/Trail.cpp"
if [ ! -f "$TRAIL_CPP" ]; then
	echo "FAIL: ${TRAIL_CPP} not found"
	FAIL=1
else
	# `grep -n` on the real file first (so any reported line numbers point at the actual file),
	# then drop "//" line-comment matches: the file's own comments quote the reference's
	# `reinterpret_cast<int>( this )` verbatim (documenting what was replaced), which would
	# otherwise false-positive this check. Matches a direct pointer-to-int cast in either
	# direction, plus a round-trip through another integer type (e.g. intptr_t) narrowed with
	# `static_cast<int>` - not just the literal reference pattern.
	CAST_HITS="$(grep -nE 'reinterpret_cast\s*<\s*(const\s+)?int\s*>|\(\s*int\s*\)\s*this\b|static_cast\s*<\s*int\s*>\s*\(\s*reinterpret_cast' "$TRAIL_CPP" \
		| grep -vE '^[0-9]+:[[:space:]]*//')"
	if [ -n "$CAST_HITS" ]; then
		echo "FAIL: found a pointer-to-int cast pattern in game/Trail.cpp:"
		echo "$CAST_HITS"
		FAIL=1
	else
		echo "PASS: no pointer-to-int cast pattern found in game/Trail.cpp"
	fi
fi

echo
if [ $FAIL -eq 0 ]; then
	echo "PASS: #43 trails scenario - a flemoid's mkTrail is created while it genuinely moves, and is fully cleaned up (back to baseline) after its fade; no pointer-to-int casts remain"
	exit 0
else
	echo "FAIL: #43 trails scenario - see above"
	exit 1
fi
