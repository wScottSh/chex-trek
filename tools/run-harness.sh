#!/usr/bin/env bash
# One command to run the AFK test harness (spec #28/#29): launches the official dhewm3 1.5.5
# win32 engine with this checkout mounted as the chextrek mod, drives it with a console script
# ending in "quit", kills it after a timeout if an error dialog hangs it, and reports pass/fail
# from the engine log plus the chextrek_dump state-dump header.
#
# Usage: tools/run-harness.sh [timeout-seconds]
#
# Environment overrides (see docs/dev-setup.md for the documented dev-machine defaults):
#   DHEWM3_HOME     - the dhewm3 1.5.5 win32 engine's install dir (has dhewm3.exe in it).
#   DOOM3_BASEPATH  - the classic Doom 3 1.3.1 install (fs_basepath); has base/pak000.pk4 etc.
#                     This is also where the "chextrek" junction/symlink to this repo lives.
#
# Never writes into this repo: the mod's data is only ever read (via fs_gameDllPath for the
# freshly built chextrek.dll, and via the basepath junction for the data files already in this
# repo). All configs/logs/saves/screenshots go to dhewm3's own per-mod save folder, which lives
# under the user's Documents folder, not in this repo - see docs/dev-setup.md for why that's the
# "scratch save path" the ACs mean (dhewm3 hardcodes it on Windows; it can't be redirected into
# the repo even if we wanted to). This run's artifacts (log + screenshot) are copied from there
# into a folder next to that same save path - still outside the repo - for convenience.
#
# Only one harness run at a time per machine: it kills *all* dhewm3.exe processes on timeout, and
# concurrent runs (e.g. from two worktrees) would race on the shared basepath symlink and the
# shared per-mod save dir.
set -uo pipefail

TIMEOUT_SECS="${1:-60}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

DHEWM3_HOME="${DHEWM3_HOME:-/c/Users/Scott/dhewm3/1.5.5-win32/dhewm3}"
DOOM3_BASEPATH="${DOOM3_BASEPATH:-/c/Program Files (x86)/Steam/steamapps/common/Doom 3}"

DHEWM3_EXE="${DHEWM3_HOME}/dhewm3.exe"
if [ ! -f "$DHEWM3_EXE" ]; then
	echo "error: dhewm3.exe not found at ${DHEWM3_EXE}. See docs/dev-setup.md (DHEWM3_HOME)." >&2
	exit 1
fi

if [ ! -f "${REPO_ROOT}/chextrek.dll" ]; then
	echo "error: ${REPO_ROOT}/chextrek.dll not found. Run tools/build-chextrek.sh first." >&2
	exit 1
fi

# --- keep the basepath's "chextrek" mount pointed at *this* checkout (worktrees change this) ---
# IMPORTANT: this must be a real NTFS symlink (readlink resolves it, `fsutil reparsepoint query`
# shows a "Symbolic Link" tag). Plain `ln -s` on a directory falls back to a full recursive copy
# on this toolchain when it can't get symlink privilege - that would silently test a stale copy
# instead of this checkout, and `rm -rf` on a *copy* is safe but on a real reparse point it must
# never be used (it would recurse through the link and could delete the checkout it points at).
# `MSYS=winsymlinks:nativestrict` forces the real symlink; if that ever stops being permitted on
# a dev machine, fix the privilege (Developer Mode) rather than loosening this.
MOD_LINK="${DOOM3_BASEPATH}/chextrek"
CURRENT_TARGET=""
if [ -L "$MOD_LINK" ]; then
	CURRENT_TARGET="$(readlink "$MOD_LINK" 2>/dev/null || true)"
fi
WANT_TARGET="$(cd "$REPO_ROOT" && pwd -P)"
if [ "$CURRENT_TARGET" != "$WANT_TARGET" ]; then
	if [ -e "$MOD_LINK" ] && [ ! -L "$MOD_LINK" ]; then
		echo "error: ${MOD_LINK} exists and is a real directory, not a symlink. Refusing to touch it - remove it by hand (see docs/dev-setup.md) and re-run." >&2
		exit 1
	fi
	echo "==> Pointing ${MOD_LINK} at ${WANT_TARGET}"
	rm -f "$MOD_LINK"
	MSYS=winsymlinks:nativestrict ln -s "$WANT_TARGET" "$MOD_LINK"
	if [ "$(readlink "$MOD_LINK" 2>/dev/null)" != "$WANT_TARGET" ]; then
		echo "error: couldn't create a real symlink at ${MOD_LINK} (no symlink privilege?). See docs/dev-setup.md." >&2
		exit 1
	fi
fi

# --- dhewm3 hardcodes its per-user save folder on Windows (Documents/My Games/dhewm3); that's
# our scratch save path - it can't be redirected via fs_savepath (see docs/dev-setup.md), but it
# already lives outside this repo, which is what the "never write into the repo" AC is about.
DOCUMENTS_DIR="${DHEWM3_DOCUMENTS_DIR:-${HOME}/Documents}"
SAVE_ROOT="${DOCUMENTS_DIR}/My Games/dhewm3"
MOD_SAVE_DIR="${SAVE_ROOT}/chextrek"

# A leftover dhewm.cfg/config.spec from a previous partial/hung run can change how far this run
# gets before it even reaches the mod's scripts (observed: a stale video-mode confirmation cached
# from an earlier run pops its own modal dialog and hangs init long before the known script-
# compile failure, making the run non-reproducible). Wiping the per-mod save dir before every run
# keeps each run's behavior deterministic; it's also just "start from a clean scratch save path".
rm -rf "$MOD_SAVE_DIR"
mkdir -p "$MOD_SAVE_DIR"

RUN_ID="$(date +%Y%m%d-%H%M%S)"
CFG_NAME="chextrek_harness_${RUN_ID}.cfg"
SHOT_NAME="chextrek_harness_${RUN_ID}"

cat > "${MOD_SAVE_DIR}/${CFG_NAME}" <<EOF
developer 1
chextrek_dump
wait
screenshot ${SHOT_NAME}
wait
quit
EOF

# Start from a clean log for this run so this run's output isn't mixed with a previous one.
LOG_FILE="${SAVE_ROOT}/dhewm3log.txt"
rm -f "$LOG_FILE"

# NOTE: this must run *in the foreground*, not backgrounded with `&`. Backgrounding it under
# this shell was observed to change how/when dhewm3 flushes its log to disk (a hung run's last
# lines - e.g. the crash's ERROR line - never reliably reached disk before the process was
# killed), even though the process is a native, independent Windows GUI app either way. `timeout`
# wraps it in the foreground and still delivers a clean kill when the ceiling is hit.
echo "==> Launching dhewm3 (mod=chextrek, timeout=${TIMEOUT_SECS}s)"
timeout "$TIMEOUT_SECS" "$DHEWM3_EXE" \
	+set fs_basepath "$(cygpath -w "$DOOM3_BASEPATH")" \
	+set fs_game chextrek \
	+set fs_gameDllPath "$(cygpath -w "$REPO_ROOT")" \
	+set developer 1 \
	+set in_nograb 1 \
	+set r_fullscreen 0 \
	+exec "$CFG_NAME"
RUN_EXIT=$?

if [ $RUN_EXIT -eq 124 ] || [ $RUN_EXIT -eq 137 ]; then
	echo "==> Timed out after ${TIMEOUT_SECS}s - an error dialog likely hung the game. Killed it."
	# Belt-and-braces: `timeout` already sent the kill, but make sure nothing lingers. This kills
	# *every* dhewm3.exe on the machine (image-name match, not PID) - see the "one run at a time"
	# note above.
	taskkill //F //IM dhewm3.exe >/dev/null 2>&1
fi

# --- archive this run's artifacts (log + any screenshot), still outside the repo ---
# `screenshot <name>` writes "<name>" (no extension, no subfolder) straight into the save dir -
# confirmed by running it manually against fs_game base - not into a "screenshots/" subfolder.
ARTIFACT_DIR="${SAVE_ROOT}/chextrek-harness-artifacts/${RUN_ID}"
mkdir -p "$ARTIFACT_DIR"
[ -f "$LOG_FILE" ] && cp -f "$LOG_FILE" "${ARTIFACT_DIR}/dhewm3log.txt"
for shot in "${MOD_SAVE_DIR}/${SHOT_NAME}"*; do
	[ -f "$shot" ] && cp -f "$shot" "$ARTIFACT_DIR/"
done
cp -f "${MOD_SAVE_DIR}/${CFG_NAME}" "$ARTIFACT_DIR/" 2>/dev/null
rm -f "${MOD_SAVE_DIR}/${CFG_NAME}"

echo "==> Artifacts: ${ARTIFACT_DIR}"

# --- assert the always-on checks from spec #28 plus this run's log-based checks ---
LOCAL_LOG="${ARTIFACT_DIR}/dhewm3log.txt"
if [ ! -f "$LOCAL_LOG" ]; then
	echo "FAIL: no engine log was produced at all"
	exit 1
fi

STATUS=0

if grep -qE "loaded game library '[^']*[Cc]hextrek\.dll'" "$LOCAL_LOG"; then
	echo "PASS: chextrek.dll loaded (not base.dll)"
else
	echo "FAIL: chextrek.dll was not the game library that loaded"
	grep -F "loaded game library" "$LOCAL_LOG" | tail -1
	STATUS=1
fi

if grep -qF "CHEXTREK-STATE-DUMP v1" "$LOCAL_LOG"; then
	echo "PASS: state-dump header present"
else
	echo "FAIL: state-dump header ('CHEXTREK-STATE-DUMP v1') not found in log"
	STATUS=1
fi

# Always-on checks (spec #28): no ERROR, no unknown event/spawnclass/script-compile lines.
ERROR_LINES="$(grep -nE "^ERROR:|Unknown event|Unknown spawnclass|Error: file .*\.script" "$LOCAL_LOG" || true)"
if [ -n "$ERROR_LINES" ]; then
	echo "RED: engine log reports an error:"
	echo "$ERROR_LINES" | tail -5
	STATUS=1
else
	echo "PASS: no ERROR / unknown-event / unknown-spawnclass / script-compile lines"
fi

echo "==> Full log: ${LOCAL_LOG}"
exit $STATUS
