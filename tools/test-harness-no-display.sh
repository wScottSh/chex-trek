#!/usr/bin/env bash
# Harness self-test: when there is no way to open a display, tools/lib-harness.sh must stop the
# whole run at once with exit code 3 and one ENVIRONMENT line - not launch dhewm3, and not report
# a pile of ordinary test FAILs that look like a code bug. What "no way to open a display" means
# is platform-specific (Windows dev machine: no active desktop session; Unicron/Wine, #60: no
# usable DISPLAY and no Xvfb to start one), so this exercises whichever branch matches the machine
# it runs on - the contract callers see (exit 3, one ENVIRONMENT line, no launch) is identical on
# both. Needs no display itself either way.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=tools/lib-harness.sh
source "${SCRIPT_DIR}/lib-harness.sh"
SCRATCH="$(mktemp -d)"
trap 'rm -rf "$SCRATCH"' EXIT
FAIL=0

if chextrek_is_linux; then
	# A curated PATH with only the ordinary tools the test itself, chextrek_is_linux and the
	# harness's early checks need (symlinked from wherever they really live) - and deliberately no
	# `Xvfb` - so "Xvfb isn't installed" (case 1a) is the real `command -v Xvfb` miss, not a stand-in.
	mkdir -p "${SCRATCH}/no-xvfb-bin"
	for TOOL in bash uname date cat mkdir rm printf sed grep id readlink basename dirname cp \
		mktemp kill sleep seq ln tr chmod true env; do
		T="$(command -v "$TOOL" 2>/dev/null)" && ln -sf "$T" "${SCRATCH}/no-xvfb-bin/${TOOL}"
	done

	# --- case 1a: Xvfb genuinely isn't on PATH -> exit 3 before launching dhewm3 (#60) ---
	START=$(date +%s)
	OUT="$(PATH="${SCRATCH}/no-xvfb-bin" bash -c '
		unset DISPLAY
		source "$1/tools/lib-harness.sh"
		chextrek_run_console_script "$1" "quit" 60 chextrek_no_display_selftest
		echo "UNREACHED: harness returned instead of exiting"
	' _ "$REPO_ROOT" 2>&1)"
	CODE=$?
	ELAPSED=$(( $(date +%s) - START ))

	if [ $CODE -eq 3 ]; then echo "PASS: Xvfb not on PATH exits 3"; else echo "FAIL: Xvfb not on PATH exit code $CODE, want 3"; FAIL=1; fi
	if echo "$OUT" | grep -q "^ENVIRONMENT: no display"; then echo "PASS: ENVIRONMENT line printed"; else echo "FAIL: no 'ENVIRONMENT: no display' line"; FAIL=1; fi
	if echo "$OUT" | grep -q "Launching dhewm3"; then echo "FAIL: dhewm3 was launched anyway"; FAIL=1; else echo "PASS: dhewm3 not launched"; fi
	if [ $ELAPSED -le 5 ]; then echo "PASS: stopped in ${ELAPSED}s"; else echo "FAIL: took ${ELAPSED}s to stop"; FAIL=1; fi
	if echo "$OUT" | grep -qi "isn't installed"; then echo "PASS: mentions Xvfb isn't installed"; else echo "FAIL: expected the ENVIRONMENT line to say Xvfb isn't installed"; FAIL=1; fi

	# --- case 1b: Xvfb is on PATH but every attempt to start it fails -> exit 3 the same way ---
	# A stub `Xvfb` (first on the real PATH) that always exits immediately, standing in for a
	# broken install (missing library, no permission, ...) rather than a missing binary.
	mkdir -p "${SCRATCH}/bin"
	cat > "${SCRATCH}/bin/Xvfb" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
	chmod +x "${SCRATCH}/bin/Xvfb"
	START=$(date +%s)
	OUT="$(PATH="${SCRATCH}/bin:${PATH}" bash -c '
		unset DISPLAY
		source "$1/tools/lib-harness.sh"
		chextrek_run_console_script "$1" "quit" 60 chextrek_no_display_selftest
		echo "UNREACHED: harness returned instead of exiting"
	' _ "$REPO_ROOT" 2>&1)"
	CODE=$?
	ELAPSED=$(( $(date +%s) - START ))

	if [ $CODE -eq 3 ]; then echo "PASS: Xvfb failing to start exits 3"; else echo "FAIL: Xvfb failing to start exit code $CODE, want 3"; FAIL=1; fi
	if echo "$OUT" | grep -q "^ENVIRONMENT: no display"; then echo "PASS: ENVIRONMENT line printed"; else echo "FAIL: no 'ENVIRONMENT: no display' line"; FAIL=1; fi
	if echo "$OUT" | grep -q "Launching dhewm3"; then echo "FAIL: dhewm3 was launched anyway"; FAIL=1; else echo "PASS: dhewm3 not launched"; fi
	if [ $ELAPSED -le 5 ]; then echo "PASS: stopped in ${ELAPSED}s"; else echo "FAIL: took ${ELAPSED}s to stop"; FAIL=1; fi
	if echo "$OUT" | grep -qi "couldn't start Xvfb"; then echo "PASS: mentions Xvfb couldn't be started"; else echo "FAIL: expected the ENVIRONMENT line to say Xvfb couldn't be started"; FAIL=1; fi

	# --- case 2: no DISPLAY but Xvfb is available -> the harness starts its own and gets past the
	# display check (SSH with no DISPLAY set, #60 AC2). It still won't reach dhewm3 (this checkout
	# has no dhewm3.exe/chextrek.dll wired up in this stripped-down environment), but that's an
	# ordinary, different failure - not an environment stop - proving the display check itself
	# isn't what's blocking once a display is available.
	if command -v Xvfb >/dev/null 2>&1; then
		NOENGINE="${SCRATCH}/no-engine"
		mkdir -p "$NOENGINE"
		OUT2="$(env -i PATH="$PATH" HOME="$HOME" DHEWM3_HOME="$NOENGINE" bash -c '
			unset DISPLAY
			source "$1/tools/lib-harness.sh"
			chextrek_run_console_script "$2" "quit" 60 chextrek_no_display_selftest
			echo "harness returned: $?"
		' _ "$REPO_ROOT" "$SCRATCH" 2>&1)"
		CODE2=$?
		if echo "$OUT2" | grep -qF "dhewm3.exe not found"; then
			echo "PASS: with Xvfb available, the harness starts its own display and gets past the display check"
		else
			echo "FAIL: expected to get past the display check and fail on the missing engine instead; got:"
			echo "$OUT2" | tail -5
			FAIL=1
		fi
		if [ $CODE2 -eq 3 ]; then
			echo "FAIL: exited 3 (no display) even though Xvfb is available"
			FAIL=1
		else
			echo "PASS: did not exit 3 once a display was available"
		fi
	else
		echo "SKIP: Xvfb not installed on this host - can't prove the harness starts its own display"
	fi
else
	# `qwinsta` output captured while this user's session was disconnected and another user held the
	# console - the state that made dhewm3 die with "Error while initializing SDL: No displays available".
	mkdir -p "${SCRATCH}/bin"
	cat > "${SCRATCH}/bin/qwinsta" <<'EOF'
#!/usr/bin/env bash
cat <<'OUT'
 SESSIONNAME               USERNAME                 ID  STATE   TYPE        DEVICE
 services                                            0  Disc
>                          Scott                     1  Disc
 console                   Paige                     2  Active
OUT
EOF
	chmod +x "${SCRATCH}/bin/qwinsta"

	# --- case 1: disconnected session -> exit 3 before launching dhewm3 ---
	START=$(date +%s)
	OUT="$(PATH="${SCRATCH}/bin:${PATH}" bash -c '
		source "$1/tools/lib-harness.sh"
		chextrek_run_console_script "$1" "quit" 60 chextrek_no_display_selftest
		echo "UNREACHED: harness returned instead of exiting"
	' _ "$REPO_ROOT" 2>&1)"
	CODE=$?
	ELAPSED=$(( $(date +%s) - START ))

	if [ $CODE -eq 3 ]; then echo "PASS: disconnected session exits 3"; else echo "FAIL: disconnected session exit code $CODE, want 3"; FAIL=1; fi
	if echo "$OUT" | grep -q "^ENVIRONMENT: no display"; then echo "PASS: ENVIRONMENT line printed"; else echo "FAIL: no 'ENVIRONMENT: no display' line"; FAIL=1; fi
	if echo "$OUT" | grep -q "Launching dhewm3"; then echo "FAIL: dhewm3 was launched anyway"; FAIL=1; else echo "PASS: dhewm3 not launched"; fi
	if [ $ELAPSED -le 5 ]; then echo "PASS: stopped in ${ELAPSED}s"; else echo "FAIL: took ${ELAPSED}s to stop"; FAIL=1; fi
fi

# --- case: the engine log's own no-display line is recognized (the post-run check) - same on
# both platforms ---
printf '%s\r\n' "Opened this log at 2026-09-25 15:02:13" \
	"Error while initializing SDL: No displays available" > "${SCRATCH}/nodisplay.log"
printf '%s\r\n' "Opened this log at 2026-09-25 15:02:13" "CHEXTREK-STATE-DUMP v1" > "${SCRATCH}/ok.log"
if chextrek_log_has_no_display "${SCRATCH}/nodisplay.log"; then echo "PASS: no-display log recognized"; else echo "FAIL: no-display log not recognized"; FAIL=1; fi
if chextrek_log_has_no_display "${SCRATCH}/ok.log"; then echo "FAIL: normal log flagged as no-display"; FAIL=1; else echo "PASS: normal log not flagged"; fi

echo
[ $FAIL -eq 0 ] && echo "PASS: harness no-display self-test" || echo "FAIL: harness no-display self-test"
exit $FAIL
