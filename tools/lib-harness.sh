# chextrek: shared AFK-harness plumbing (spec #28/#29/#30). Sourced by tools/run-harness.sh and
# tools/test-*.sh scenario scripts - not meant to be run directly.
#
# Provides chextrek_run_console_script(), which does everything common to every harness run:
# mounts this checkout as the "chextrek" fs_game folder, wipes the scratch save path, writes and
# execs a given console script, launches dhewm3 with a timeout, archives the run's log/screenshot/
# cfg outside the repo, and asserts the spec #28 always-on checks (chextrek.dll loaded, state-dump
# header present, no ERROR/unknown-event/unknown-spawnclass/script-compile lines). Callers add
# their own scenario-specific assertions on top of $CHEXTREK_LOCAL_LOG; the always-on checks alone
# set $CHEXTREK_RUN_STATUS (0 pass, 1 fail).
#
# See docs/dev-setup.md for the environment variables this reads (DHEWM3_HOME, DOOM3_BASEPATH,
# DHEWM3_DOCUMENTS_DIR) and for why the mount/save-path/timeout handling works the way it does.

# chextrek_run_console_script REPO_ROOT CONSOLE_SCRIPT_BODY TIMEOUT_SECS RUN_LABEL
#
# CONSOLE_SCRIPT_BODY is the full text written to the .cfg file dhewm3 execs (including
# "developer 1" and a trailing "quit" - callers own the whole script, not just a snippet, since
# scenarios need to interleave "wait"s with their own commands).
#
# On return: CHEXTREK_RUN_STATUS is always set (0 pass, 1 fail). CHEXTREK_ARTIFACT_DIR and
# CHEXTREK_LOCAL_LOG are set once the run actually launches dhewm3; on an early-return failure
# (missing dhewm3.exe/chextrek.dll, can't create the mount symlink) they're left unset, so callers
# that echo them should use "${CHEXTREK_LOCAL_LOG:-}" under `set -u`. Does not exit the shell -
# callers decide what to do with a non-zero CHEXTREK_RUN_STATUS.
chextrek_run_console_script() {
	local REPO_ROOT="$1"
	local CONSOLE_SCRIPT_BODY="$2"
	local TIMEOUT_SECS="$3"
	local RUN_LABEL="${4:-chextrek_harness}"

	DHEWM3_HOME="${DHEWM3_HOME:-/c/Users/Scott/dhewm3/1.5.5-win32/dhewm3}"
	DOOM3_BASEPATH="${DOOM3_BASEPATH:-/c/Program Files (x86)/Steam/steamapps/common/Doom 3}"

	local DHEWM3_EXE="${DHEWM3_HOME}/dhewm3.exe"
	if [ ! -f "$DHEWM3_EXE" ]; then
		echo "error: dhewm3.exe not found at ${DHEWM3_EXE}. See docs/dev-setup.md (DHEWM3_HOME)." >&2
		CHEXTREK_RUN_STATUS=1
		return 1
	fi

	if [ ! -f "${REPO_ROOT}/chextrek.dll" ]; then
		echo "error: ${REPO_ROOT}/chextrek.dll not found. Run tools/build-chextrek.sh first." >&2
		CHEXTREK_RUN_STATUS=1
		return 1
	fi

	# --- keep the basepath's "chextrek" mount pointed at *this* checkout (worktrees change this) ---
	# IMPORTANT: this must be a real NTFS symlink (readlink resolves it, `fsutil reparsepoint
	# query` shows a "Symbolic Link" tag). Plain `ln -s` on a directory falls back to a full
	# recursive copy on this toolchain when it can't get symlink privilege - that would silently
	# test a stale copy instead of this checkout, and `rm -rf` on a *copy* is safe but on a real
	# reparse point it must never be used (it would recurse through the link and could delete the
	# checkout it points at). `MSYS=winsymlinks:nativestrict` forces the real symlink; if that
	# ever stops being permitted on a dev machine, fix the privilege (Developer Mode) rather than
	# loosening this.
	local MOD_LINK="${DOOM3_BASEPATH}/chextrek"
	local CURRENT_TARGET=""
	if [ -L "$MOD_LINK" ]; then
		CURRENT_TARGET="$(readlink "$MOD_LINK" 2>/dev/null || true)"
	fi
	local WANT_TARGET
	WANT_TARGET="$(cd "$REPO_ROOT" && pwd -P)"
	if [ "$CURRENT_TARGET" != "$WANT_TARGET" ]; then
		if [ -e "$MOD_LINK" ] && [ ! -L "$MOD_LINK" ]; then
			echo "error: ${MOD_LINK} exists and is a real directory, not a symlink. Refusing to touch it - remove it by hand (see docs/dev-setup.md) and re-run." >&2
			CHEXTREK_RUN_STATUS=1
			return 1
		fi
		echo "==> Pointing ${MOD_LINK} at ${WANT_TARGET}"
		rm -f "$MOD_LINK"
		MSYS=winsymlinks:nativestrict ln -s "$WANT_TARGET" "$MOD_LINK"
		if [ "$(readlink "$MOD_LINK" 2>/dev/null)" != "$WANT_TARGET" ]; then
			echo "error: couldn't create a real symlink at ${MOD_LINK} (no symlink privilege?). See docs/dev-setup.md." >&2
			CHEXTREK_RUN_STATUS=1
			return 1
		fi
	fi

	# --- dhewm3 hardcodes its per-user save folder on Windows (Documents/My Games/dhewm3);
	# that's our scratch save path - it can't be redirected via fs_savepath (see
	# docs/dev-setup.md), but it already lives outside this repo, which is what the "never write
	# into the repo" AC is about.
	local DOCUMENTS_DIR="${DHEWM3_DOCUMENTS_DIR:-${HOME}/Documents}"
	local SAVE_ROOT="${DOCUMENTS_DIR}/My Games/dhewm3"
	local MOD_SAVE_DIR="${SAVE_ROOT}/chextrek"

	# A leftover dhewm.cfg/config.spec from a previous partial/hung run can change how far this
	# run gets before it even reaches the mod's scripts. Wiping the per-mod save dir before every
	# run keeps each run's behavior deterministic; it's also just "start from a clean scratch
	# save path".
	rm -rf "$MOD_SAVE_DIR"
	mkdir -p "$MOD_SAVE_DIR"

	local RUN_ID
	RUN_ID="$(date +%Y%m%d-%H%M%S%N)"
	local CFG_NAME="${RUN_LABEL}_${RUN_ID}.cfg"

	printf '%s\n' "$CONSOLE_SCRIPT_BODY" > "${MOD_SAVE_DIR}/${CFG_NAME}"

	# Start from a clean log for this run so this run's output isn't mixed with a previous one.
	local LOG_FILE="${SAVE_ROOT}/dhewm3log.txt"
	rm -f "$LOG_FILE"

	# NOTE: this must run *in the foreground*, not backgrounded with `&`. Backgrounding it under
	# this shell was observed to change how/when dhewm3 flushes its log to disk, even though the
	# process is a native, independent Windows GUI app either way. `timeout` wraps it in the
	# foreground and still delivers a clean kill when the ceiling is hit.
	echo "==> Launching dhewm3 (mod=chextrek, timeout=${TIMEOUT_SECS}s, scenario=${RUN_LABEL})"
	timeout "$TIMEOUT_SECS" "$DHEWM3_EXE" \
		+set fs_basepath "$(cygpath -w "$DOOM3_BASEPATH")" \
		+set fs_game chextrek \
		+set fs_gameDllPath "$(cygpath -w "$REPO_ROOT")" \
		+set developer 1 \
		+set in_nograb 1 \
		+set r_fullscreen 0 \
		+exec "$CFG_NAME"
	local RUN_EXIT=$?

	if [ $RUN_EXIT -eq 124 ] || [ $RUN_EXIT -eq 137 ]; then
		echo "==> Timed out after ${TIMEOUT_SECS}s - an error dialog likely hung the game. Killed it."
		# Belt-and-braces: `timeout` already sent the kill, but make sure nothing lingers. This
		# kills *every* dhewm3.exe on the machine (image-name match, not PID) - see the "one run
		# at a time" note in docs/dev-setup.md.
		taskkill //F //IM dhewm3.exe >/dev/null 2>&1
	fi

	# --- archive this run's artifacts (log + any screenshot), still outside the repo ---
	# `screenshot <name>` writes a plain, extensionless file named exactly <name> straight into
	# MOD_SAVE_DIR (confirmed on #30's scenario runs: "screenshot chextrek_script_events" writes
	# "chextrek_script_events" - this is what #29 originally found too; see docs/dev-setup.md for
	# where a stale claim to the contrary, that the name is ignored in favor of an auto-numbered
	# "screenshots/shot00001.tga", briefly crept in and was corrected). Rather than hardcode a name
	# pattern here - which would have to track whatever name each caller's console script happens
	# to pick - archive everything: since
	# MOD_SAVE_DIR is wiped to empty before every run (above), anything left in it (or under a
	# screenshots/ subfolder, just in case) afterward, other than our own cfg, is this run's own
	# output. Never asserted on (spec #28: "saved as artifacts, never asserted"), so this stays
	# best-effort.
	CHEXTREK_ARTIFACT_DIR="${SAVE_ROOT}/chextrek-harness-artifacts/${RUN_ID}"
	mkdir -p "$CHEXTREK_ARTIFACT_DIR"
	[ -f "$LOG_FILE" ] && cp -f "$LOG_FILE" "${CHEXTREK_ARTIFACT_DIR}/dhewm3log.txt"
	for f in "${MOD_SAVE_DIR}"/* "${MOD_SAVE_DIR}"/screenshots/*; do
		[ -f "$f" ] || continue
		[ "$(basename "$f")" = "$CFG_NAME" ] && continue
		cp -f "$f" "${CHEXTREK_ARTIFACT_DIR}/"
	done
	cp -f "${MOD_SAVE_DIR}/${CFG_NAME}" "${CHEXTREK_ARTIFACT_DIR}/console-script.cfg" 2>/dev/null
	rm -f "${MOD_SAVE_DIR}/${CFG_NAME}"

	echo "==> Artifacts: ${CHEXTREK_ARTIFACT_DIR}"

	# --- assert the always-on checks from spec #28 ---
	CHEXTREK_LOCAL_LOG="${CHEXTREK_ARTIFACT_DIR}/dhewm3log.txt"
	if [ ! -f "$CHEXTREK_LOCAL_LOG" ]; then
		echo "FAIL: no engine log was produced at all"
		CHEXTREK_RUN_STATUS=1
		return 1
	fi

	CHEXTREK_RUN_STATUS=0

	if grep -qE "loaded game library '[^']*[Cc]hextrek\.dll'" "$CHEXTREK_LOCAL_LOG"; then
		echo "PASS: chextrek.dll loaded (not base.dll)"
	else
		echo "FAIL: chextrek.dll was not the game library that loaded"
		grep -F "loaded game library" "$CHEXTREK_LOCAL_LOG" | tail -1
		CHEXTREK_RUN_STATUS=1
	fi

	if grep -qF "CHEXTREK-STATE-DUMP v1" "$CHEXTREK_LOCAL_LOG"; then
		echo "PASS: state-dump header present"
	else
		echo "FAIL: state-dump header ('CHEXTREK-STATE-DUMP v1') not found in log"
		CHEXTREK_RUN_STATUS=1
	fi

	# Always-on checks (spec #28): no ERROR, no unknown event/spawnclass/script-compile lines.
	# "Unknown spawnclass" was the #29 guess at how the engine reports this; it never actually
	# matches anything (Game_local.cpp warns "Could not spawn '<classname>'.  Class '<spawnclass>' not
	# found..." instead - grep confirms "Unknown spawnclass" isn't a string this engine build ever
	# prints), so this check was silently unable to fire before now. Matching the real message
	# turns up one pre-existing, out-of-scope-for-#30 gap on `e1m1`: `idTarget_EndLevelGUI` isn't
	# implemented yet (spec #28's own step 3, "Custom UI and end-level stats" - a later sub-issue's
	# job, not #30's). Narrowly allowlisting that one class (not spawn failures in general) keeps
	# the check able to catch a real regression without blocking on a documented, tracked gap.
	local ERROR_LINES
	ERROR_LINES="$(grep -nE "^ERROR:|Unknown event|Could not spawn|Error: file .*\.script" "$CHEXTREK_LOCAL_LOG" | grep -v "Class 'idTarget_EndLevelGUI' not found" || true)"
	if [ -n "$ERROR_LINES" ]; then
		echo "RED: engine log reports an error:"
		echo "$ERROR_LINES" | tail -5
		CHEXTREK_RUN_STATUS=1
	else
		echo "PASS: no ERROR / unknown-event / unknown-spawnclass / script-compile lines"
	fi

	echo "==> Full log: ${CHEXTREK_LOCAL_LOG}"
	return $CHEXTREK_RUN_STATUS
}
