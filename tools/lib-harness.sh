# chextrek: shared AFK-harness plumbing (spec #28). Sourced by tools/run-harness.sh,
# tools/run-scenario.sh and the tools/test-*.sh scenario scripts - not meant to be run directly.
#
# Harness core:
#   chextrek_run_console_script - one game run: mounts this checkout as the "chextrek" fs_game
#     folder, wipes the scratch save path, writes and execs a console script, launches dhewm3 with
#     a timeout, archives the run's log/screenshots/cfg outside the repo, and asserts the spec #28
#     always-on checks (chextrek.dll loaded, state-dump header present, no ERROR/unknown-event/
#     unknown-spawnclass/script-compile lines, no timeout kill).
#
# Scenario-script helpers (tools/test-*.sh):
#   chextrek_build_or_exit      - builds chextrek.dll once (skipped under CHEXTREK_SKIP_BUILD=1).
#   chextrek_run_scenario       - runs one console script via tools/run-scenario.sh and finds its
#                                 archived log; propagates the no-display exit 3.
#   chextrek_assert_map_loaded  - the always-on "map finishes loading" check.
#   chextrek_line_field_values  - values of a `<field>: <rest of line>` chextrek_dump line.
#   chextrek_hud_map_*_values   - fields of the dump's `hud_map:` line.
#
# See docs/dev-setup.md for the environment variables this reads (DHEWM3_HOME, DOOM3_BASEPATH,
# DHEWM3_DOCUMENTS_DIR) and for why the mount/save-path/timeout handling works the way it does.

# chextrek_build_or_exit
#
# Builds chextrek.dll with tools/build-chextrek.sh, exiting the calling script with 1 if the build
# fails. A no-op when CHEXTREK_SKIP_BUILD=1 (set by tools/run-all-tests.sh, which builds once
# up front instead of once per scenario).
chextrek_build_or_exit() {
	[ "${CHEXTREK_SKIP_BUILD:-0}" = "1" ] && return 0
	local LIB_DIR
	LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
	if ! bash "${LIB_DIR}/build-chextrek.sh"; then
		echo "FAIL: build-chextrek.sh failed"
		exit 1
	fi
}

# chextrek_run_scenario SCENARIO_NAME CONSOLE_SCRIPT_FILE TIMEOUT_SECS
#
# Runs tools/run-scenario.sh in a subshell and echoes its output. Sets:
#   CHEXTREK_SCENARIO_OUT   - that output (for callers that grep the harness's own PASS/FAIL lines);
#   CHEXTREK_SCENARIO_EXIT  - its exit status (0 = always-on checks passed);
#   CHEXTREK_SCENARIO_LOG   - the archived engine log's path, or "" if the run produced none;
#   CHEXTREK_SCENARIO_SAVE_DIR - the scratch save dir (see chextrek_run_console_script).
# Prints a FAIL line when the always-on checks failed. If the run stopped because there is no
# display (exit 3), exits the calling script with 3 too, so that environment blocker is never
# reported as an ordinary test FAIL. Returns CHEXTREK_SCENARIO_EXIT.
chextrek_run_scenario() {
	local LIB_DIR
	LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
	CHEXTREK_SCENARIO_OUT="$(bash "${LIB_DIR}/run-scenario.sh" "$1" "$2" "$3" 2>&1)"
	CHEXTREK_SCENARIO_EXIT=$?
	echo "$CHEXTREK_SCENARIO_OUT"
	[ $CHEXTREK_SCENARIO_EXIT -eq 3 ] && exit 3
	if [ $CHEXTREK_SCENARIO_EXIT -ne 0 ]; then
		echo "FAIL: expected the always-on harness checks to pass for '$1', but the run exited ${CHEXTREK_SCENARIO_EXIT}"
	fi
	CHEXTREK_SCENARIO_LOG="$(echo "$CHEXTREK_SCENARIO_OUT" | sed -n 's/^CHEXTREK_LOCAL_LOG=//p')"
	CHEXTREK_SCENARIO_SAVE_DIR="$(echo "$CHEXTREK_SCENARIO_OUT" | sed -n 's/^CHEXTREK_MOD_SAVE_DIR=//p')"
	if [ -n "$CHEXTREK_SCENARIO_LOG" ] && [ ! -f "$CHEXTREK_SCENARIO_LOG" ]; then
		CHEXTREK_SCENARIO_LOG=""
	fi
	return $CHEXTREK_SCENARIO_EXIT
}

# chextrek_assert_map_loaded LOG_FILE MAP_NAME
#
# Spec #28 always-on check: the map finished loading (the engine's "<N> msec to load <map>" line).
# Prints PASS/FAIL; returns 0/1.
chextrek_assert_map_loaded() {
	if grep -qE "^ *[0-9]+ msec to load $2\$" "$1"; then
		echo "PASS: $2 finished loading"
		return 0
	fi
	echo "FAIL: expected to see '<N> msec to load $2' in the log"
	return 1
}

# chextrek_hud_map_visible_values LOG_FILE
#
# Prints each chextrek_dump `hud_map:` line's `visible` field, in log order, one per line.
chextrek_hud_map_visible_values() {
	grep -oE '^hud_map: level=[0-9]+ visible=[01] coverage=[0-9]+$' "$1" | grep -oE 'visible=[01]' | grep -oE '[01]$'
}

# chextrek_hud_map_coverage_values LOG_FILE
#
# Prints each chextrek_dump `hud_map:` line's `coverage` field, in log order, one per line.
chextrek_hud_map_coverage_values() {
	grep -oE '^hud_map: level=[0-9]+ visible=[01] coverage=[0-9]+$' "$1" | grep -oE 'coverage=[0-9]+' | grep -oE '[0-9]+$'
}

# chextrek_hud_map_level_values LOG_FILE
#
# Prints each chextrek_dump `hud_map:` line's `level` field, in log order, one per line. (#39)
chextrek_hud_map_level_values() {
	grep -oE '^hud_map: level=[0-9]+ visible=[01] coverage=[0-9]+$' "$1" | grep -oE '^hud_map: level=[0-9]+' | grep -oE '[0-9]+$'
}

# chextrek_line_field_values LOG_FILE FIELD_NAME
#
# Prints each `<FIELD_NAME>: <rest of line>` chextrek_dump line's value (everything after
# "<FIELD_NAME>: "), in log order, one per line. FIELD_NAME must be a plain field name (no regex
# metacharacters - every field this is used for is a fixed identifier like "door_tryopen_last" or
# "hud_tip_title", never user input).
chextrek_line_field_values() {
	local LOG_FILE="$1"
	local FIELD_NAME="$2"
	grep -oE "^${FIELD_NAME}: .*\$" "$LOG_FILE" | sed "s/^${FIELD_NAME}: //"
}

# chextrek_log_has_no_display LOG_FILE
#
# True if dhewm3's log shows it died because there was no display to open a window on.
chextrek_log_has_no_display() {
	grep -qF "No displays available" "$1"
}

# chextrek_exit_no_display
#
# dhewm3 needs an active interactive desktop. When this Windows user session is disconnected
# (another user switched in on the console, or an RDP session dropped), SDL can't open a window
# and every run fails. That is an environment problem, not a test result, and it won't clear
# until a human reconnects - so exit the whole calling script with code 3 instead of returning
# a normal FAIL that reads like a code bug.
chextrek_exit_no_display() {
	echo "ENVIRONMENT: no display - this Windows session is not the active console session, so dhewm3 can't open a window."
	echo "ENVIRONMENT: this is not a test failure. Stop and tell the human to reconnect to this session; do not wait or retry."
	exit 3
}

# chextrek_run_console_script REPO_ROOT CONSOLE_SCRIPT_BODY TIMEOUT_SECS RUN_LABEL
#
# CONSOLE_SCRIPT_BODY is the full text written to the .cfg file dhewm3 execs (including
# "developer 1" and a trailing "quit" - callers own the whole script, not just a snippet, since
# scenarios need to interleave "wait"s with their own commands).
#
# On return: CHEXTREK_RUN_STATUS is always set (0 pass, 1 fail; a timeout kill is a fail). CHEXTREK_ARTIFACT_DIR and
# CHEXTREK_LOCAL_LOG are set once the run actually launches dhewm3; CHEXTREK_MOD_SAVE_DIR is set a
# little earlier (as soon as the scratch save dir itself is resolved and wiped, before dhewm3 is
# launched). On an early-return failure (missing dhewm3.exe/chextrek.dll, can't create the mount
# symlink) all three are left unset, so callers that echo them should use
# "${CHEXTREK_LOCAL_LOG:-}" under `set -u`. CHEXTREK_MOD_SAVE_DIR is the scratch save dir itself
# (Documents/My Games/dhewm3/chextrek/) -
# callers that need to inspect something the archiving loop below doesn't copy out (e.g. #44's
# nested env/ subfolder) should read it from there rather than recomputing the path, so the two
# can't drift. It isn't wiped until the *next* run, so it's still valid to read right after this
# call returns. Does not exit the shell - callers decide what to do with a non-zero
# CHEXTREK_RUN_STATUS - except when there is no display (see chextrek_exit_no_display), which
# exits the calling script with code 3.
chextrek_run_console_script() {
	local REPO_ROOT="$1"
	local CONSOLE_SCRIPT_BODY="$2"
	local TIMEOUT_SECS="$3"
	local RUN_LABEL="${4:-chextrek_harness}"

	DHEWM3_HOME="${DHEWM3_HOME:-/c/Users/Scott/dhewm3/1.5.5-win32/dhewm3}"
	DOOM3_BASEPATH="${DOOM3_BASEPATH:-/c/Program Files (x86)/Steam/steamapps/common/Doom 3}"

	# qwinsta marks this process's own session with ">"; anything but Active means no display.
	if command -v qwinsta >/dev/null 2>&1 && ! qwinsta 2>/dev/null | grep -E '^>' | grep -qw Active; then
		chextrek_exit_no_display
	fi

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
	CHEXTREK_MOD_SAVE_DIR="$MOD_SAVE_DIR"

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

	local TIMED_OUT=0
	if [ $RUN_EXIT -eq 124 ] || [ $RUN_EXIT -eq 137 ]; then
		TIMED_OUT=1
		echo "==> Timed out after ${TIMEOUT_SECS}s - an error dialog likely hung the game. Killed it."
		# Belt-and-braces: `timeout` already sent the kill, but make sure nothing lingers. This
		# kills *every* dhewm3.exe on the machine (image-name match, not PID) - see the "one run
		# at a time" note in docs/dev-setup.md.
		taskkill //F //IM dhewm3.exe >/dev/null 2>&1
	fi

	# --- archive this run's artifacts (log + any screenshot), still outside the repo ---
	# `screenshot <name>` writes an extensionless file named exactly <name> into MOD_SAVE_DIR.
	# Since MOD_SAVE_DIR is wiped before every run, everything left in it (or in a screenshots/
	# subfolder) other than our own cfg is this run's output, so archive all of it rather than track
	# each caller's screenshot names. Never asserted on (spec #28: "saved as artifacts, never
	# asserted").
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

	# The session can drop mid-run (between the preflight check above and launch).
	if chextrek_log_has_no_display "$CHEXTREK_LOCAL_LOG"; then
		chextrek_exit_no_display
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

	# Always-on checks (spec #28): no ERROR, no unknown event/spawnclass/script-compile lines. This
	# engine reports an unknown spawnclass as "Could not spawn '<classname>'.  Class '<spawnclass>'
	# not found..." (Game_local.cpp), not with the words "unknown spawnclass".
	local ERROR_LINES
	ERROR_LINES="$(grep -nE "^ERROR:|Unknown event|Could not spawn|Error: file .*\.script" "$CHEXTREK_LOCAL_LOG" || true)"
	if [ -n "$ERROR_LINES" ]; then
		echo "RED: engine log reports an error:"
		echo "$ERROR_LINES" | tail -5
		CHEXTREK_RUN_STATUS=1
	else
		echo "PASS: no ERROR / unknown-event / unknown-spawnclass / script-compile lines"
	fi

	# Spec #28: a run the harness had to kill is a failure, whatever the log says, and the report
	# names the log's last error line (or, if there is none, its last line).
	if [ $TIMED_OUT -eq 1 ]; then
		echo "FAIL: the game didn't exit within ${TIMEOUT_SECS}s and was killed"
		local LAST_LINE
		LAST_LINE="$(grep -E "^ERROR:|Unknown event|Could not spawn|Error: file .*\.script|[Ee]rror" "$CHEXTREK_LOCAL_LOG" | tail -1)"
		[ -z "$LAST_LINE" ] && LAST_LINE="$(grep -v '^[[:space:]]*$' "$CHEXTREK_LOCAL_LOG" | tail -1)"
		echo "FAIL: last error line in the log: ${LAST_LINE}"
		CHEXTREK_RUN_STATUS=1
	fi

	echo "==> Full log: ${CHEXTREK_LOCAL_LOG}"
	return $CHEXTREK_RUN_STATUS
}
