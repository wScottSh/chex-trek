# chextrek: shared AFK-harness plumbing (spec #28). Sourced by tools/run-harness.sh,
# tools/run-scenario.sh and the tools/test-*.sh scenario scripts - not meant to be run directly.
#
# Harness core:
#   chextrek_run_console_script - one game run: mounts this checkout as the "chextrek" fs_game
#     folder, wipes the scratch save path, writes and execs a console script, launches dhewm3 with
#     a timeout, archives the run's log/screenshots/cfg outside the repo, and asserts the spec #28
#     always-on checks (chextrek.dll loaded, state-dump header present, no ERROR/unknown-event/
#     unknown-spawnclass/script-compile lines, no timeout kill).
#   chextrek_ensure_mount - just the "chextrek" mount step on its own (#69): shared by
#     chextrek_run_console_script and tools/fetch-and-play.sh, which needs the mount but not a
#     console script, a timeout or the display/lock machinery.
#   chextrek_apply_engine_defaults / chextrek_parse_github_repo - small, standalone helpers (#69)
#     also shared with tools/fetch-and-play.sh: per-platform DHEWM3_HOME/DOOM3_BASEPATH/WINEPREFIX
#     defaults, and parsing `owner/repo` out of a github.com remote URL.
#   chextrek_log_has_no_display / chextrek_exit_no_display - the no-display environment stop
#     (exit 3) the run makes when there's no way to open a window (Windows: this session has no
#     active desktop; Linux/Wine: the display this run had died mid-run).
#   _chextrek_check_engine_or_exit / _chextrek_linux_preflight_or_exit - the other broken-
#     environment stops (exit 3, one ENVIRONMENT line), Linux/Wine-only (#63): a missing dhewm3
#     engine, missing Wine/winepath on PATH, an uninitialized Wine prefix, or missing Doom 3 data.
#     Windows keeps its pre-#63 behavior for all of these unchanged.
#
# Scenario-script helpers (tools/test-*.sh):
#   chextrek_build_or_exit      - builds chextrek.dll once (skipped under CHEXTREK_SKIP_BUILD=1).
#   chextrek_run_scenario       - runs one console script via tools/run-scenario.sh and finds its
#                                 archived log; propagates any environment-blocker exit 3.
#   chextrek_assert_map_loaded  - the always-on "map finishes loading" check.
#   chextrek_line_field_values  - values of a `<field>: <rest of line>` chextrek_dump line.
#   chextrek_hud_map_*_values   - fields of the dump's `hud_map:` line.
#
# Linux/Wine platform layer (spec #58/#60): chextrek_run_console_script's interface, and every
# scenario helper above it, is identical on both platforms - only the plumbing behind it branches
# on `chextrek_is_linux`:
#   chextrek_is_linux           - true on Unicron (Linux/Wine), false on the Windows dev machine.
#   chextrek_to_engine_path     - `winepath -w` (Linux) vs `cygpath -w` (Windows) path conversion.
#   chextrek_ensure_display_or_exit - starts this run's own Xvfb display when none is usable
#                                 (Linux), instead of the Windows qwinsta active-session check.
#   chextrek_lock_file / _chextrek_acquire_lock / _chextrek_release_lock - the single-run lock
#                                 (spec #62) serializing concurrent runs on Unicron.
# See docs/dev-setup.md's "Unicron (Linux/Wine)" section for the one-time setup this assumes
# (Wine, the VC++ x86 redist in the prefix, Xvfb) and for the environment variables this reads
# (DHEWM3_HOME, DOOM3_BASEPATH, DHEWM3_DOCUMENTS_DIR, WINEPREFIX) and why the mount/save-path/
# timeout handling works the way it does.

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
# Prints a FAIL line when the always-on checks failed. If the run stopped on an environment
# blocker (exit 3 - no display, or, Linux only, missing Wine/winepath, an uninitialized Wine
# prefix, missing Doom 3 data or a missing dhewm3 engine, #63), exits the calling script with 3
# too, so that blocker is never reported as an ordinary test FAIL. Returns CHEXTREK_SCENARIO_EXIT.
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
# Prints each chextrek_dump `hud_map:` line's `level` field, in log order, one per line.
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

# chextrek_is_linux
#
# True on Unicron (Linux/Wine, spec #58/#60), false on the Windows dev machine (MSYS/Git Bash).
# Every OS-specific branch in this file tests this instead of guessing from which tools happen to
# be on PATH, so the two platforms' code paths stay easy to find and can't accidentally blend.
chextrek_is_linux() {
	case "$(uname -s)" in
	Linux*) return 0 ;;
	*) return 1 ;;
	esac
}

# chextrek_to_engine_path UNIX_PATH
#
# dhewm3 is a native Windows binary; every `+set fs_*` path it's given on the command line has to
# be a Windows-style path. Windows dev machine (Git Bash): `cygpath -w`. Unicron (Linux/Wine):
# `winepath -w`, resolved against $WINEPREFIX the same way the run itself is.
#
# `winepath` can itself start a wineserver (#62): closes this call's copy of the single-run lock fd
# first (see _chextrek_acquire_lock) so that wineserver - which can outlive this whole call - never
# gets a copy of it either.
chextrek_to_engine_path() {
	if chextrek_is_linux; then
		if [ -n "${CHEXTREK_LOCK_FD:-}" ]; then
			winepath -w "$1" {CHEXTREK_LOCK_FD}>&-
		else
			winepath -w "$1"
		fi
	else
		cygpath -w "$1"
	fi
}

# _chextrek_stop_xvfb
#
# Stops and reaps the Xvfb this call started, if any (CHEXTREK_XVFB_PID), removes its scratch log
# (CHEXTREK_XVFB_LOG), and clears both. A no-op when there's no PID (nothing to stop, or
# `chextrek_ensure_display_or_exit` reused an existing display rather than starting one) - shared
# by every place that needs to make sure this call's own Xvfb doesn't leak: a failed candidate
# display, a mid-run display loss (chextrek_exit_no_display), and the normal end of a run
# (chextrek_run_console_script).
_chextrek_stop_xvfb() {
	[ -n "${CHEXTREK_XVFB_PID:-}" ] || return 0
	kill "$CHEXTREK_XVFB_PID" 2>/dev/null
	wait "$CHEXTREK_XVFB_PID" 2>/dev/null
	CHEXTREK_XVFB_PID=""
	[ -n "${CHEXTREK_XVFB_LOG:-}" ] && rm -f "$CHEXTREK_XVFB_LOG"
	CHEXTREK_XVFB_LOG=""
}

# chextrek_ensure_display_or_exit
#
# Windows: dhewm3 needs an active interactive desktop; that check stays in
# chextrek_run_console_script (qwinsta), unchanged.
#
# Unicron (Linux/Wine, #60): dhewm3 still needs *some* X display to open a window on, but nobody
# is ever logged in to Unicron, so "no display" here is the normal case, not a rare disconnect -
# the harness brings its own. If $DISPLAY already names a live X server (e.g. a wrapping script
# exported one for several calls, or a real X session), reuse it - checked by its own lock file
# rather than a tool like `xdpyinfo`, which isn't part of the one-time Unicron setup. Otherwise
# start a fresh Xvfb on the first free display number and export DISPLAY for this run;
# CHEXTREK_XVFB_PID is set so the caller can stop it again once the run finishes (see
# chextrek_run_console_script). Xvfb itself being unavailable or refusing to start is the actual
# environment stop (exit 3) - the same class of blocker the Windows branch reports for a
# disconnected session, just with a different cause.
chextrek_ensure_display_or_exit() {
	CHEXTREK_XVFB_PID=""
	local CUR_NUM="${DISPLAY-}"
	CUR_NUM="${CUR_NUM#:}"
	if [ -n "${DISPLAY-}" ] && [[ "$CUR_NUM" =~ ^[0-9]+$ ]] && [ -e "/tmp/.X${CUR_NUM}-lock" ]; then
		return 0
	fi
	if ! command -v Xvfb >/dev/null 2>&1; then
		echo "ENVIRONMENT: no display - DISPLAY is unset (or unusable) and Xvfb isn't installed to start one."
		echo "ENVIRONMENT: this is not a test failure. Install Xvfb on this host; do not wait or retry."
		exit 3
	fi
	# The free-display-number search can skip many candidates cheaply (another run's Xvfb already
	# holding that number), but an actual spawn failure (missing library, no permission, ...) fails
	# the same way on every number, so real spawn *attempts* are capped separately and small.
	local N ATTEMPTS=0
	for N in $(seq 90 199); do
		[ -e "/tmp/.X${N}-lock" ] && continue
		ATTEMPTS=$((ATTEMPTS + 1))
		CHEXTREK_XVFB_LOG="/tmp/chextrek-xvfb-${N}.log"
		# Xvfb outlives this call by design (stopped explicitly later, see _chextrek_stop_xvfb) - if
		# this process were killed first, an inherited copy of the single-run lock fd (#62) would
		# keep that orphaned Xvfb holding the lock forever. `{CHEXTREK_LOCK_FD}>&-` closes this
		# fork's copy of it before Xvfb itself execs, so only this function's own fd matters for the
		# lock (see _chextrek_acquire_lock; same reasoning as the wine launch below).
		if [ -n "${CHEXTREK_LOCK_FD:-}" ]; then
			Xvfb ":${N}" -screen 0 1280x1024x24 -nolisten tcp >"$CHEXTREK_XVFB_LOG" 2>&1 {CHEXTREK_LOCK_FD}>&- &
		else
			Xvfb ":${N}" -screen 0 1280x1024x24 -nolisten tcp >"$CHEXTREK_XVFB_LOG" 2>&1 &
		fi
		CHEXTREK_XVFB_PID=$!
		local WAITED=0
		while [ $WAITED -lt 10 ] && [ ! -e "/tmp/.X${N}-lock" ]; do
			sleep 0.1
			WAITED=$((WAITED + 1))
		done
		if [ -e "/tmp/.X${N}-lock" ]; then
			export DISPLAY=":${N}"
			return 0
		fi
		_chextrek_stop_xvfb
		[ $ATTEMPTS -ge 3 ] && break
	done
	echo "ENVIRONMENT: no display - couldn't start Xvfb (tried ${ATTEMPTS} free display number(s))."
	echo "ENVIRONMENT: this is not a test failure. Fix Xvfb on this host; do not wait or retry."
	exit 3
}

# chextrek_exit_no_display
#
# dhewm3 needs an active interactive desktop. When this Windows user session is disconnected
# (another user switched in on the console, or an RDP session dropped), SDL can't open a window
# and every run fails. That is an environment problem, not a test result, and it won't clear
# until a human reconnects - so exit the whole calling script with code 3 instead of returning
# a normal FAIL that reads like a code bug. Also stops this call's own Xvfb (#60), if it started
# one, so a display dying mid-run never leaks it.
chextrek_exit_no_display() {
	if chextrek_is_linux; then
		_chextrek_exit_environment \
			"ENVIRONMENT: no display - the X display this run started or was given died before dhewm3 could open a window." \
			"ENVIRONMENT: this is not a test failure. Fix Xvfb/Wine on this host; do not wait or retry."
	else
		_chextrek_exit_environment \
			"ENVIRONMENT: no display - this Windows session is not the active console session, so dhewm3 can't open a window." \
			"ENVIRONMENT: this is not a test failure. Stop and tell the human to reconnect to this session; do not wait or retry."
	fi
}

# _chextrek_exit_environment ENV_LINE...
#
# Shared plumbing for every environment stop (#28's chextrek_exit_no_display and #63's Wine/
# Wine-prefix/Doom-3-data/dhewm3-engine checks below): prints each argument as its own line, stops
# this call's own Xvfb if one had already been started (defensive - most #63 checks run before
# Xvfb is ever started, but this keeps the contract identical regardless of check order, same as
# chextrek_exit_no_display already needed), and exits the whole calling script with 3 - never a
# plain FAIL that reads like a code bug (#58 story 16/29, #63 AC).
_chextrek_exit_environment() {
	local LINE
	for LINE in "$@"; do
		echo "$LINE"
	done
	_chextrek_stop_xvfb
	# #62: #63's preflight exits run before the lock is taken (a no-op here); a later stop (display
	# died mid-run) would have the kernel drop the lock at exit anyway - releasing explicitly just
	# makes that not depend on nothing else still holding the fd.
	_chextrek_release_lock
	exit 3
}

# _chextrek_check_engine_or_exit
#
# Unicron-only (#63): dhewm3 itself - unlike chextrek.dll, which every scenario (re)builds - is a
# fixed, one-time install (docs/dev-setup.md: DHEWM3_HOME). Missing it on Linux means this
# machine's environment isn't set up, not that the game library has a bug, so it gets the same
# ENVIRONMENT/exit-3 treatment as a missing display, Wine/Wine-prefix or Doom 3 data (#63's four
# broken-environment cases). Checked before the display check, before Xvfb ever starts, so a
# missing engine is reported without paying for a display first. Windows keeps its pre-#63
# behavior unchanged (#63 AC): a missing dhewm3.exe there still falls through to the ordinary
# FAIL/exit-1 check next to chextrek.dll's, further down.
_chextrek_check_engine_or_exit() {
	local EXE="${DHEWM3_HOME}/dhewm3.exe"
	if [ ! -f "$EXE" ]; then
		_chextrek_exit_environment \
			"ENVIRONMENT: dhewm3 engine not found at ${EXE}." \
			"ENVIRONMENT: this is not a test failure. Install dhewm3 1.5.5 win32 or point DHEWM3_HOME at it (see docs/dev-setup.md); do not wait or retry."
	fi
}

# _chextrek_linux_preflight_or_exit
#
# Unicron-only checks (#58/#63) for the resources dhewm3-under-Wine needs before it can even
# attempt to open a display: Wine itself (`wine`, `winepath`), an initialized $WINEPREFIX, and the
# classic Doom 3 data. Without these, a run previously either silently limped on with an empty
# converted path (winepath missing - a plain "command not found" on stderr, swallowed by the
# `$(...)` capture) or failed downstream with a generic "no engine log was produced at all" FAIL
# once `wine` itself turned out missing - neither of which named the actual missing piece or
# stopped with exit 3 (#63's bug report: a missing Wine/winepath on PATH made the harness FAIL
# instead of exit 3). Each of these is a #63 "broken environment" case: exit 3, one ENVIRONMENT
# line naming what's missing, dhewm3 never launched. Run before chextrek_ensure_display_or_exit so
# a broken Wine setup doesn't pay for starting Xvfb first.
_chextrek_linux_preflight_or_exit() {
	if ! command -v wine >/dev/null 2>&1; then
		_chextrek_exit_environment \
			"ENVIRONMENT: wine not found on PATH - dhewm3 runs under Wine on Unicron." \
			"ENVIRONMENT: this is not a test failure. Put Wine's bin dir on PATH (see docs/dev-setup.md); do not wait or retry."
	fi
	if ! command -v winepath >/dev/null 2>&1; then
		_chextrek_exit_environment \
			"ENVIRONMENT: winepath not found on PATH - needed to convert paths for dhewm3 under Wine." \
			"ENVIRONMENT: this is not a test failure. Put Wine's bin dir on PATH (see docs/dev-setup.md); do not wait or retry."
	fi
	if [ ! -f "${WINEPREFIX}/system.reg" ]; then
		_chextrek_exit_environment \
			"ENVIRONMENT: Wine prefix not set up at ${WINEPREFIX} (no system.reg)." \
			"ENVIRONMENT: this is not a test failure. Initialize \$WINEPREFIX, including the VC++ x86 redist (see docs/dev-setup.md); do not wait or retry."
	fi
	if [ ! -f "${DOOM3_BASEPATH}/base/pak000.pk4" ]; then
		_chextrek_exit_environment \
			"ENVIRONMENT: classic Doom 3 data not found at ${DOOM3_BASEPATH} (no base/pak000.pk4)." \
			"ENVIRONMENT: this is not a test failure. Copy the Doom 3 1.3.1 data there (see docs/dev-setup.md); do not wait or retry."
	fi
}

# chextrek_lock_file
#
# Path to the single-run lock file (#62). Every chextrek_run_console_script call on Unicron
# (Linux/Wine) takes an exclusive flock on this file for its whole run - mount, save-dir wipe,
# launch, cleanup - so two concurrent runs on this machine (two worktrees, an agent plus the
# pipeline, whatever) serialize instead of racing on the shared DOOM3_BASEPATH/chextrek mount and
# the shared per-mod save dir; today that's just a documented "one at a time" rule (see
# docs/dev-setup.md), not something enforced. A fixed path (not `$TMPDIR`, which can differ between
# sessions/users and would silently split them onto different, non-serializing lock files) outside
# the repo and outside any worktree, so every worktree on this machine shares the same lock file by
# default. CHEXTREK_LOCK_FILE overrides it - a test that wants to prove the locking itself, without
# colliding with a real run on the machine, sets its own private path.
# Windows is out of scope for #62 (the Windows branch still just kills every dhewm3.exe by image
# name on timeout, unchanged) - only the Linux/Wine call sites below take this lock.
chextrek_lock_file() {
	echo "${CHEXTREK_LOCK_FILE:-/tmp/chextrek-harness.lock}"
}

# _chextrek_acquire_lock
#
# Opens chextrek_lock_file on fd CHEXTREK_LOCK_FD and takes an exclusive flock on it, printing a
# "waiting" line (#62 AC2) once if another run already holds it, then blocking until it's free.
# Exits the calling script with 1 if the lock file itself can't even be opened (e.g. permissions) -
# proceeding unlocked would defeat the whole point.
#
# flock's lock lives on the open file descriptor, not on the file's contents or a pid recorded in
# it, so a run that dies while holding it - crash, SIGKILL, whatever - has the kernel close that fd
# and drop the lock, with nothing left to clean up (#62 AC3) - *provided* nothing else still has a
# copy of that fd open. A plain fork (every external command this script runs, including Xvfb and
# the wine launch) inherits it regardless of what the child later execs into, so a harness process
# killed while such a child is still running would otherwise leave the lock held by that orphan
# indefinitely. chextrek_ensure_display_or_exit's Xvfb spawn, the winepath call in
# chextrek_to_engine_path, and the wine launch in _chextrek_run_console_script_impl - the places
# that can start something able to outlive this call (Xvfb itself; a wineserver `winepath` or
# `wine` may spawn, which does not exit with the command that started it) - each attach
# `{CHEXTREK_LOCK_FD}>&-` directly to that command, so the fd is closed in *that fork*, before it
# execs into anything, and nothing it or its own children (wineserver, winedevice.exe) start ever
# gets a copy. Only this process's own fd, closed by _chextrek_release_lock, matters for the lock.
_chextrek_acquire_lock() {
	local LOCK_FILE
	LOCK_FILE="$(chextrek_lock_file)"
	if ! exec {CHEXTREK_LOCK_FD}>"$LOCK_FILE"; then
		echo "error: couldn't open the harness lock file ${LOCK_FILE}. See docs/dev-setup.md." >&2
		exit 1
	fi
	if ! flock -n "$CHEXTREK_LOCK_FD"; then
		echo "==> Waiting for the harness lock (another run holds ${LOCK_FILE}) ..."
		if ! flock "$CHEXTREK_LOCK_FD"; then
			echo "error: couldn't take the harness lock on ${LOCK_FILE} (is 'flock' installed?). See docs/dev-setup.md." >&2
			exit 1
		fi
	fi
}

# _chextrek_release_lock
#
# Releases the lock _chextrek_acquire_lock took and closes its fd. A no-op if no lock is currently
# held (CHEXTREK_LOCK_FD unset or already closed).
_chextrek_release_lock() {
	[ -n "${CHEXTREK_LOCK_FD:-}" ] || return 0
	flock -u "$CHEXTREK_LOCK_FD" 2>/dev/null || true
	exec {CHEXTREK_LOCK_FD}>&- 2>/dev/null || true
	CHEXTREK_LOCK_FD=""
}

# chextrek_parse_github_repo REMOTE_URL
#
# Parses an `owner/repo` string out of a git remote URL pointing at github.com, in any of its usual
# forms (`git@github.com:owner/repo.git`, `https://github.com/owner/repo.git`,
# `ssh://git@github.com/owner/repo`, with or without the trailing `.git`). Used by
# tools/fetch-and-play.sh (#69) to default `--repo` for every `gh` call to the same remote this
# checkout's own `origin` points at, without hardcoding a repo name anywhere.
chextrek_parse_github_repo() {
	printf '%s' "$1" | sed -E 's#^(https?://|git\+ssh://|ssh://)?(git@)?github\.com[:/]##; s#\.git$##'
}

# chextrek_apply_engine_defaults
#
# Sets DHEWM3_HOME/DOOM3_BASEPATH (and, on Linux, WINEPREFIX) to their per-platform defaults
# (docs/dev-setup.md) whenever the environment doesn't already set them - never overrides an
# explicit override. Shared by chextrek_run_console_script and tools/fetch-and-play.sh (#69), so
# the two default paths can't drift apart.
chextrek_apply_engine_defaults() {
	if chextrek_is_linux; then
		DHEWM3_HOME="${DHEWM3_HOME:-$HOME/games/dhewm3/1.5.5-win32/dhewm3}"
		DOOM3_BASEPATH="${DOOM3_BASEPATH:-$HOME/games/doom3}"
		export WINEPREFIX="${WINEPREFIX:-$HOME/games/wineprefix-chextrek}"
	else
		DHEWM3_HOME="${DHEWM3_HOME:-/c/Users/Scott/dhewm3/1.5.5-win32/dhewm3}"
		DOOM3_BASEPATH="${DOOM3_BASEPATH:-/c/Program Files (x86)/Steam/steamapps/common/Doom 3}"
	fi
}

# chextrek_ensure_mount REPO_ROOT
#
# Points the ${DOOM3_BASEPATH}/chextrek mount at REPO_ROOT, creating or repointing the symlink as
# needed. On Windows this must be a real NTFS symlink (`MSYS=winsymlinks:nativestrict ln -s`) -
# plain `ln -s` on a directory silently falls back to a full recursive copy on this toolchain when
# it can't get symlink privilege, which would test stale content instead of failing loudly; Unicron
# (Linux/Wine, #60) has no such privilege quirk, a plain `ln -s` creates a real symlink outright.
# Either way the result is verified with `readlink` before it's trusted, so a silent fallback is
# caught the same way on both platforms. See docs/dev-setup.md's "Why none of this lives in the
# repo" for the full story.
#
# Shared by chextrek_run_console_script (every scenario run) and tools/fetch-and-play.sh (#69) -
# the owner's play command needs exactly this same mount, not a scenario run, so it calls this
# directly rather than going through the console-script/timeout/display machinery below, which it
# doesn't want (interactive play has no console script and no timeout).
#
# Never exits: prints an `error:` line and returns 1 on failure so each caller decides what "the
# mount failed" becomes (the harness turns it into CHEXTREK_RUN_STATUS=1; fetch-and-play into its
# own exit 1). Returns 0 (no-op, nothing printed) when the mount already points at REPO_ROOT.
chextrek_ensure_mount() {
	local REPO_ROOT="$1"
	local MOD_LINK="${DOOM3_BASEPATH}/chextrek"
	local CURRENT_TARGET=""
	if [ -L "$MOD_LINK" ]; then
		CURRENT_TARGET="$(readlink "$MOD_LINK" 2>/dev/null || true)"
	fi
	local WANT_TARGET
	WANT_TARGET="$(cd "$REPO_ROOT" && pwd -P)"
	if [ "$CURRENT_TARGET" = "$WANT_TARGET" ]; then
		return 0
	fi
	if [ -e "$MOD_LINK" ] && [ ! -L "$MOD_LINK" ]; then
		echo "error: ${MOD_LINK} exists and is a real directory, not a symlink. Refusing to touch it - remove it by hand (see docs/dev-setup.md) and re-run." >&2
		return 1
	fi
	echo "==> Pointing ${MOD_LINK} at ${WANT_TARGET}"
	rm -f "$MOD_LINK"
	if chextrek_is_linux; then
		ln -s "$WANT_TARGET" "$MOD_LINK"
	else
		MSYS=winsymlinks:nativestrict ln -s "$WANT_TARGET" "$MOD_LINK"
	fi
	if [ "$(readlink "$MOD_LINK" 2>/dev/null)" != "$WANT_TARGET" ]; then
		echo "error: couldn't create a real symlink at ${MOD_LINK} (no symlink privilege?). See docs/dev-setup.md." >&2
		return 1
	fi
	return 0
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
# launched). On an early-return failure (missing chextrek.dll, can't create the mount symlink, or -
# Windows only, #63 AC: Linux exits instead, see below - a missing dhewm3.exe) all three are left
# unset, so callers that echo them should use "${CHEXTREK_LOCAL_LOG:-}" under `set -u`.
# CHEXTREK_MOD_SAVE_DIR is the scratch save dir itself
# (Documents/My Games/dhewm3/chextrek/) -
# callers that need to inspect something the archiving loop below doesn't copy out (e.g. #44's
# nested env/ subfolder) should read it from there rather than recomputing the path, so the two
# can't drift. It isn't wiped until the *next* run, so it's still valid to read right after this
# call returns. Does not exit the shell - callers decide what to do with a non-zero
# CHEXTREK_RUN_STATUS - except for an environment stop (no display, or - Linux only, #63 - missing
# Wine/winepath, an uninitialized Wine prefix, missing Doom 3 data or a missing dhewm3 engine; see
# chextrek_exit_no_display and _chextrek_exit_environment), which exits the calling script with
# code 3.
#
# This is a thin wrapper around _chextrek_run_console_script_impl so that an Xvfb this call
# started on Linux/Wine (#60, see chextrek_ensure_display_or_exit) always gets stopped again on
# every return path out of the impl - without having to remember a cleanup call at each of the
# impl's several early returns. A no-display exit (chextrek_exit_no_display) bypasses this wrapper
# entirely (exit, not return), so it does its own Xvfb cleanup inline.
#
# On Unicron (Linux/Wine, #62) it also takes the single-run lock (_chextrek_acquire_lock) before
# calling the impl and releases it (_chextrek_release_lock) on every return path, for the same
# reason: the impl's early returns would otherwise each need to remember to release it. A
# no-display exit bypasses this wrapper, but _chextrek_exit_environment releases the lock itself,
# and since it terminates the whole process anyway, the kernel would close CHEXTREK_LOCK_FD and drop
# the lock regardless - see _chextrek_acquire_lock.
#
# #63's Linux environment preflight (Wine/winepath on PATH, an initialized $WINEPREFIX, Doom 3
# data, the dhewm3 engine) runs here, *before* the lock is taken: a broken environment stops with
# exit 3 at once instead of first queueing behind another run's lock, and never holds the lock at
# all. None of those checks fork anything (`command -v` and `[ -f ]` are builtins), so there's no
# child that could inherit the lock fd either way.
chextrek_run_console_script() {
	CHEXTREK_XVFB_PID=""
	chextrek_apply_engine_defaults
	if chextrek_is_linux; then
		# #63: Wine, the Wine prefix, the Doom 3 data and the dhewm3 engine are all fixed, one-time
		# resources (docs/dev-setup.md) - check the cheap ones before waiting on the lock (#62) or
		# paying for an Xvfb start.
		_chextrek_linux_preflight_or_exit
		_chextrek_check_engine_or_exit
		_chextrek_acquire_lock
	fi
	_chextrek_run_console_script_impl "$@"
	local RC=$?
	_chextrek_stop_xvfb
	chextrek_is_linux && _chextrek_release_lock
	return $RC
}

_chextrek_run_console_script_impl() {
	local REPO_ROOT="$1"
	local CONSOLE_SCRIPT_BODY="$2"
	local TIMEOUT_SECS="$3"
	local RUN_LABEL="${4:-chextrek_harness}"

	if chextrek_is_linux; then
		# DHEWM3_HOME/DOOM3_BASEPATH/WINEPREFIX defaults and #63's environment preflight were
		# already applied by chextrek_run_console_script, before it took the lock (#62).
		# Unicron has nobody logged in, ever (#60 AC: "works over SSH with no DISPLAY set") - bring
		# our own display instead of treating "no display" as the environment stop qwinsta is for on
		# Windows below.
		chextrek_ensure_display_or_exit
	else
		# qwinsta marks this process's own session with ">"; anything but Active means no display.
		# Windows behavior here is unchanged by #63 (its AC): a missing dhewm3.exe still falls
		# through to the ordinary FAIL/exit-1 check just below, not the Linux-only ENVIRONMENT/
		# exit-3 treatment _chextrek_check_engine_or_exit gives it above.
		if command -v qwinsta >/dev/null 2>&1 && ! qwinsta 2>/dev/null | grep -E '^>' | grep -qw Active; then
			chextrek_exit_no_display
		fi
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

	# --- keep the basepath's "chextrek" mount pointed at *this* checkout (worktrees change this) -
	# see chextrek_ensure_mount's own header above for why it must be a real symlink on both
	# platforms and how a silent fallback is caught ---
	if ! chextrek_ensure_mount "$REPO_ROOT"; then
		CHEXTREK_RUN_STATUS=1
		return 1
	fi

	# --- dhewm3 hardcodes its per-user save folder (Documents/My Games/dhewm3); that's our
	# scratch save path - it can't be redirected via fs_savepath (see docs/dev-setup.md), but it
	# already lives outside this repo, which is what the "never write into the repo" AC is about.
	# On Unicron (#60) "Documents" is the one inside the Wine prefix dhewm3 actually runs in, not
	# this Linux user's own $HOME/Documents.
	local DOCUMENTS_DIR
	if [ -n "${DHEWM3_DOCUMENTS_DIR:-}" ]; then
		DOCUMENTS_DIR="$DHEWM3_DOCUMENTS_DIR"
	elif chextrek_is_linux; then
		DOCUMENTS_DIR="${WINEPREFIX}/drive_c/users/$(id -un)/Documents"
	else
		DOCUMENTS_DIR="${HOME}/Documents"
	fi
	local SAVE_ROOT="${DOCUMENTS_DIR}/My Games/dhewm3"
	local MOD_SAVE_DIR="${SAVE_ROOT}/chextrek"

	# A leftover dhewm.cfg/config.spec from a previous partial/hung run can change how far this
	# run gets before it even reaches the mod's scripts. Wiping the per-mod save dir before every
	# run keeps each run's behavior deterministic; it's also just "start from a clean scratch
	# save path".
	rm -rf "$MOD_SAVE_DIR"
	mkdir -p "$MOD_SAVE_DIR"
	CHEXTREK_MOD_SAVE_DIR="$MOD_SAVE_DIR"

	# Test-only data files (e.g. a fixture entityDef) a scenario needs: copied into the scratch save
	# path, which dhewm3 searches ahead of the mod folder, so they never live in the shipped mod
	# data. CHEXTREK_FIXTURE_DIR is a directory laid out like the mod folder (e.g. def/x.def).
	if [ -n "${CHEXTREK_FIXTURE_DIR:-}" ]; then
		if ! cp -R "${CHEXTREK_FIXTURE_DIR}/." "$MOD_SAVE_DIR/"; then
			echo "error: couldn't copy scenario fixtures from ${CHEXTREK_FIXTURE_DIR}" >&2
			CHEXTREK_RUN_STATUS=1
			return 1
		fi
	fi

	local RUN_ID
	RUN_ID="$(date +%Y%m%d-%H%M%S%N)"
	local CFG_NAME="${RUN_LABEL}_${RUN_ID}.cfg"

	printf '%s\n' "$CONSOLE_SCRIPT_BODY" > "${MOD_SAVE_DIR}/${CFG_NAME}"

	# Start from a clean log for this run so this run's output isn't mixed with a previous one.
	local LOG_FILE="${SAVE_ROOT}/dhewm3log.txt"
	rm -f "$LOG_FILE"

	local -a ENGINE_ARGS=(
		+set fs_basepath "$(chextrek_to_engine_path "$DOOM3_BASEPATH")"
		+set fs_game chextrek
		+set fs_gameDllPath "$(chextrek_to_engine_path "$REPO_ROOT")"
		+set developer 1
		+set in_nograb 1
		+set r_fullscreen 0
		+exec "$CFG_NAME"
	)

	# NOTE: this must run *in the foreground*, not backgrounded with `&`. Backgrounding it under
	# this shell was observed to change how/when dhewm3 flushes its log to disk, even though the
	# process is a native, independent Windows GUI app either way. `timeout` wraps it in the
	# foreground and still delivers a clean kill when the ceiling is hit.
	echo "==> Launching dhewm3 (mod=chextrek, timeout=${TIMEOUT_SECS}s, scenario=${RUN_LABEL})"
	local RUN_EXIT
	if chextrek_is_linux; then
		# `bash -c '... && exec wine ...'` cds into the engine's own dir first (it looks for
		# SDL2.dll/OpenAL32.dll next to itself, spike #59) and then `exec`s into wine, so `timeout`
		# is still tracking exactly one PID - the wine process itself, not a wrapper shell around
		# it. `--kill-after` guarantees that PID actually dies on timeout instead of just being
		# asked to (#60 AC: "a timeout kills only the dhewm3 process the harness started" - not
		# Windows' machine-wide taskkill-by-image-name below). This runs in the foreground and
		# normally exits with `timeout`/wine well before this call returns - but if *this* harness
		# process itself were killed first, wine/dhewm3 and everything it in turn forks (wineserver,
		# winedevice.exe) would keep running and, having inherited the single-run lock fd (#62)
		# across the fork chain, would keep holding the lock indefinitely. `{CHEXTREK_LOCK_FD}>&-`
		# closes this call's own copy of it in *timeout's* fork, before timeout execs into anything -
		# so bash -c, wine, and every process wine goes on to start never have a copy in the first
		# place, and only this function's own fd matters for the lock.
		if [ -n "${CHEXTREK_LOCK_FD:-}" ]; then
			timeout --kill-after=10 "$TIMEOUT_SECS" bash -c 'cd "$1" && shift && exec wine "$@"' _ \
				"$DHEWM3_HOME" "$DHEWM3_EXE" "${ENGINE_ARGS[@]}" {CHEXTREK_LOCK_FD}>&-
		else
			timeout --kill-after=10 "$TIMEOUT_SECS" bash -c 'cd "$1" && shift && exec wine "$@"' _ \
				"$DHEWM3_HOME" "$DHEWM3_EXE" "${ENGINE_ARGS[@]}"
		fi
	else
		timeout "$TIMEOUT_SECS" "$DHEWM3_EXE" "${ENGINE_ARGS[@]}"
	fi
	RUN_EXIT=$?

	# wineserver and the winedevice.exe helpers it starts daemonize without closing the fds they
	# inherited from this wine invocation - including this function's own stdout/stderr - so a
	# fresh wineserver left running after dhewm3 exits can hold a caller's `$(...)` capture open
	# indefinitely, well past this run actually finishing (spike #59 finding 4). `-k` (not `-w`:
	# the spike saw *that* hang instead, when winedevice.exe outlives its display) stops this run's
	# own $WINEPREFIX server so those fds close; it's scoped to this one prefix, so it can't touch
	# a concurrent run's wine processes in a different prefix.
	if chextrek_is_linux && command -v wineserver >/dev/null 2>&1; then
		wineserver -k >/dev/null 2>&1 || true
	fi

	local TIMED_OUT=0
	if [ $RUN_EXIT -eq 124 ] || [ $RUN_EXIT -eq 137 ]; then
		TIMED_OUT=1
		echo "==> Timed out after ${TIMEOUT_SECS}s - an error dialog likely hung the game. Killed it."
		if ! chextrek_is_linux; then
			# Belt-and-braces: `timeout` already sent the kill, but make sure nothing lingers. This
			# kills *every* dhewm3.exe on the machine (image-name match, not PID) - see the "one
			# run at a time" note in docs/dev-setup.md. On Linux, `timeout --kill-after` above
			# already killed exactly the PID this call started - no machine-wide fallback needed.
			taskkill //F //IM dhewm3.exe >/dev/null 2>&1
		fi
	fi

	# The win32 engine writes its log with CRLF line endings. Git Bash's grep on Windows ignores
	# the trailing CR; Linux grep doesn't, so every `...$`-anchored always-on check below would
	# silently fail even though the value is right there (spike #59 finding 1). Normalize before
	# archiving/asserting, on the log this run wrote to, before it's ever grepped.
	if chextrek_is_linux && [ -f "$LOG_FILE" ]; then
		sed -i 's/\r$//' "$LOG_FILE"
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
		if [ -n "$LAST_LINE" ]; then
			echo "FAIL: last error line in the log: ${LAST_LINE}"
		else
			echo "FAIL: no error line in the log; its last line: $(grep -v '^[[:space:]]*$' "$CHEXTREK_LOCAL_LOG" | tail -1)"
		fi
		CHEXTREK_RUN_STATUS=1
	fi

	echo "==> Full log: ${CHEXTREK_LOCAL_LOG}"
	return $CHEXTREK_RUN_STATUS
}
