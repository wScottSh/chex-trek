#!/usr/bin/env bash
# Automated test for spec #44's acceptance criterion (decomp-so/reference/env-shots.md, ported
# this sub-issue into a new game/func_envshot.h/.cpp, matching the game/Trail.h/.cpp pattern #43
# used for a mod-added file not in stock dhewm3-sdk):
#   AC: spawn a func_envshot, run takeEnvShots; the log shows its envShot commands and the images
#       are written
#
# matt_func_envshot (entityDef func_envshot, def/func_envshot.def) is a point entity that takes an
# environment cubemap shot (the stock renderer's "envShot" command, six faces) from its own
# origin, either 250ms after spawn (spawnArg "atSpawn" "1") or, for every matt_func_envshot on the
# map at once, via the new "takeEnvShots" console command (registered right after the mod's
# "showMap", gamesys/SysCmds.cpp - decomp-so/reference/env-shots.md's Notes cite the binary's own
# registration order). Neither shipped map places a func_envshot (env-shots.md's own Notes: no
# .map file here has one), so this scenario spawns one itself.
#
# No wiring gap to close: unlike several other sub-issues (#34/#35/#36/#37), this is a
# self-contained new class plus a real, self-registering console command, not an
# edit-inside-a-stock-function lead - decomp-so/reference/env-shots.md records no such lead.
#
# Scenario, on e1m1: spawns a func_envshot at a known-good playable point (the same origin
# tools/test-ai-door-open.sh's monster uses, "-180 184 64", well inside e1m1's geometry - not load
# bearing for the shot's own content, just somewhere sane to render from), giving it an explicit
# "name" (used both as the entity's own name, for Cmd_Spawn_f's bookkeeping, and, since matt_
# func_envshot::Event_envShot reads spawnArgs' own "name" key for the shots' file basename, as
# env/<name>_px.tga etc.'s basename too - the same key serves both purposes) plus a small "size"
# (32, not the 256 default, to keep each of the six faces' render/write fast) and an explicit
# "blends" (1, matching R_EnvShot_f's own default so a missing key can't silently shift it - see
# env-shots.md's Notes on the "empty positional argument" open question). Since neither spawnArg
# includes "atSpawn", the fixture only ever takes a shot when "takeEnvShots" is run, proving that
# command's own path (not just Spawn's 250ms-later PostEventMS branch).
#
# Asserts, straight from the log: matt_func_envshot::takeEnvShots_f's own count line ("1 envShots
# taken" - proving exactly the one spawned fixture was found and shot, via
# idGameLocal::entities[]/IsType, not zero and not more), and separately - since the images
# themselves are the AC's other half - that dhewm3's "envShot" command actually wrote all six cube
# faces (_px/_nx/_py/_ny/_pz/_nz.tga) into the mod's scratch save dir at
# "Documents/My Games/dhewm3/chextrek/env/", the same directory "screenshot" and "savegame" write
# into (docs/dev-setup.md: fs_savepath can't be redirected on this engine build, and already lives
# outside the repo) - not this repo's own tracked env/ directory (whose files use a different
# naming convention, _back/_forward/_up/_down/_left/_right, so a collision would be obvious either
# way). tools/lib-harness.sh's own artifact-archiving loop only copies files directly inside the
# scratch save dir (plus its screenshots/ subfolder), not a nested env/ subfolder, so this script
# reads the scratch save dir directly, right after the run, before any later harness invocation
# wipes it.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRATCH_DIR="$(mktemp -d)"
trap 'rm -rf "$SCRATCH_DIR"' EXIT

# shellcheck source=tools/lib-harness.sh
source "${SCRIPT_DIR}/lib-harness.sh"

echo "=== #44 env-shots test: build ==="
chextrek_build_or_exit

CONSOLE_SCRIPT="${SCRATCH_DIR}/env_shots.cfg"
cat > "$CONSOLE_SCRIPT" <<'EOF'
developer 1
map e1m1
wait 20

spawn func_envshot name chextrek_test_envshot origin "-180 184 64" size "32" blends "1"
wait 5

takeEnvShots
wait 30

chextrek_dump
screenshot chextrek_env_shots
wait 10
quit
EOF

echo
echo "=== #44 env-shots test: scenario run ==="

FAIL=0
chextrek_run_scenario chextrek_env_shots "$CONSOLE_SCRIPT" 120 || FAIL=1

LOCAL_LOG="$CHEXTREK_SCENARIO_LOG"
if [ -z "$LOCAL_LOG" ]; then
	echo "FAIL: couldn't find the archived log to check scenario-specific assertions"
	exit 1
fi

# --- e1m1 finishes loading (spec #28 always-on check) ---
chextrek_assert_map_loaded "$LOCAL_LOG" e1m1 || FAIL=1

# --- the log shows takeEnvShots' own envShots-taken count line ---
if grep -qE '^1 envShots taken$' "$LOCAL_LOG"; then
	echo "PASS: log shows 'takeEnvShots' found and shot exactly the one spawned func_envshot"
else
	echo "FAIL: expected '1 envShots taken' in the log"
	FAIL=1
	echo "--- envShots-taken lines seen ---"
	grep -E 'envShots taken' "$LOCAL_LOG" || echo "(none)"
fi

# --- the log itself shows the images were written (the stock engine's own "envShot" command's
# write-confirmation line, one per invocation - not something this sub-issue's code prints) ---
if grep -qE '^Wrote env/chextrek_test_envshot_[a-z]+\.tga, etc$' "$LOCAL_LOG"; then
	echo "PASS: log shows the engine's own 'Wrote env/...' confirmation that the cube faces were written"
else
	echo "FAIL: expected a 'Wrote env/chextrek_test_envshot_*.tga, etc' line in the log"
	FAIL=1
	echo "--- 'Wrote' lines seen ---"
	grep -E '^Wrote ' "$LOCAL_LOG" || echo "(none)"
fi

# --- the images are written ---
# CHEXTREK_SCENARIO_SAVE_DIR (tools/lib-harness.sh) is the scratch save dir itself - reading it
# from there (rather than recomputing DHEWM3_DOCUMENTS_DIR's default here too) keeps this path in
# one place. It isn't wiped until the *next* harness invocation, so it's still valid to read now.
MOD_SAVE_DIR="$CHEXTREK_SCENARIO_SAVE_DIR"
if [ -z "$MOD_SAVE_DIR" ]; then
	echo "FAIL: couldn't find the scratch save dir to check the written env-shot images"
	exit 1
fi
ENV_DIR="${MOD_SAVE_DIR}/env"

FOUND_FACES=0
for FACE in px nx py ny pz nz; do
	F="${ENV_DIR}/chextrek_test_envshot_${FACE}.tga"
	if [ -s "$F" ]; then
		FOUND_FACES=$((FOUND_FACES + 1))
	else
		echo "FAIL: expected a nonempty ${F}"
	fi
done

if [ "$FOUND_FACES" -eq 6 ]; then
	echo "PASS: all six env-shot cube faces were written to ${ENV_DIR}"
else
	echo "FAIL: only ${FOUND_FACES}/6 env-shot cube faces were written to ${ENV_DIR}"
	FAIL=1
fi

# --- the "size" spawnArg actually reached the engine, not just "some size" ---
# A TGA's uncompressed 18-byte header stores width as a little-endian uint16 at offset 12. Reading
# it directly off one of the six faces confirms Event_envShot's "size" spawnArg (32, set on the
# fixture above, not R_EnvShot_f's own 256 default) actually reached the "envShot" command text,
# not just that *some* image of *some* size was written.
PX_FACE="${ENV_DIR}/chextrek_test_envshot_px.tga"
if [ -f "$PX_FACE" ]; then
	WIDTH="$(od -An -tu2 -j 12 -N 2 --endian=little "$PX_FACE" 2>/dev/null | tr -d ' ')"
	if [ "$WIDTH" = "32" ]; then
		echo "PASS: the written cube face is 32px wide, matching the fixture's own 'size' spawnArg"
	else
		echo "FAIL: expected the written cube face to be 32px wide (the fixture's 'size' spawnArg), got '${WIDTH}'"
		FAIL=1
	fi
else
	echo "FAIL: expected ${PX_FACE} to check its width"
	FAIL=1
fi

echo
if [ $FAIL -eq 0 ]; then
	echo "PASS: #44 env-shots scenario - takeEnvShots renders func_envshot cubemaps"
	exit 0
else
	echo "FAIL: #44 env-shots scenario - see above"
	exit 1
fi
