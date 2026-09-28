#!/usr/bin/env bash
# Harness self-test (#63): every broken-Unicron-environment case besides "no display" (that one's
# tools/test-harness-no-display.sh) must stop the whole run at once with exit code 3 and one
# ENVIRONMENT line naming the missing piece - not launch dhewm3, and not report an ordinary FAIL
# (or a bare "command not found") that reads like a code bug. The four cases from #58/#63: no
# display, missing Doom 3 data, missing dhewm3 engine, missing Wine or its prefix. This covers the
# latter three, each in isolation, with every other resource stubbed present so only the one
# case's check can fire. Linux/Wine-only (Windows keeps its own qwinsta/no-display path unchanged,
# #63 AC3); this self-test is a no-op there. Needs no display itself either way.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=tools/lib-harness.sh
source "${SCRIPT_DIR}/lib-harness.sh"

if ! chextrek_is_linux; then
	echo "SKIP: broken-environment self-test only covers the Linux/Wine platform layer (#63)"
	exit 0
fi

SCRATCH="$(mktemp -d)"
trap 'rm -rf "$SCRATCH"' EXIT
FAIL=0

# A curated PATH with only the ordinary tools chextrek_is_linux and the harness's checks need
# (symlinked from wherever they really live), same technique as
# tools/test-harness-no-display.sh - so "wine isn't on PATH" is a real `command -v wine` miss, not
# a stand-in, and no real Wine/Xvfb/dhewm3 install on this host is required to run this test.
mkdir -p "${SCRATCH}/base-bin"
for TOOL in bash uname date cat mkdir rm printf sed grep id readlink basename dirname cp \
	mktemp kill sleep seq ln tr chmod true env; do
	T="$(command -v "$TOOL" 2>/dev/null)" && ln -sf "$T" "${SCRATCH}/base-bin/${TOOL}"
done

# Fixture layout every case starts from fully valid, then breaks exactly one thing:
#   $SCRATCH/wineprefix/system.reg   - a stand-in initialized Wine prefix
#   $SCRATCH/doom3/base/pak000.pk4   - a stand-in Doom 3 data install
#   $SCRATCH/dhewm3/dhewm3.exe       - a stand-in dhewm3 engine install
setup_good_fixtures() {
	rm -rf "${SCRATCH}/wineprefix" "${SCRATCH}/doom3" "${SCRATCH}/dhewm3"
	mkdir -p "${SCRATCH}/wineprefix" "${SCRATCH}/doom3/base" "${SCRATCH}/dhewm3"
	: > "${SCRATCH}/wineprefix/system.reg"
	: > "${SCRATCH}/doom3/base/pak000.pk4"
	: > "${SCRATCH}/dhewm3/dhewm3.exe"
}

# stub_wine_tools BIN_DIR
#
# Fake `wine`/`winepath` that exist on PATH and exit 0 (this test never needs them to actually do
# anything - the checks under test are only `command -v`, not behavior).
stub_wine_tools() {
	local BIN_DIR="$1"
	mkdir -p "$BIN_DIR"
	for TOOL in wine winepath; do
		cat > "${BIN_DIR}/${TOOL}" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
		chmod +x "${BIN_DIR}/${TOOL}"
	done
}

# run_case PATH_DIRS DHEWM3_HOME DOOM3_BASEPATH WINEPREFIX
#
# Runs chextrek_run_console_script with the given fixtures and PATH, in a subshell so `exit 3`
# doesn't kill this script. Sets OUT/CODE/ELAPSED.
run_case() {
	local CASE_PATH="$1" CASE_HOME="$2" CASE_DOOM3="$3" CASE_PREFIX="$4"
	local START
	START=$(date +%s)
	OUT="$(env -i PATH="$CASE_PATH" HOME="$SCRATCH" \
		DHEWM3_HOME="$CASE_HOME" DOOM3_BASEPATH="$CASE_DOOM3" WINEPREFIX="$CASE_PREFIX" \
		bash -c '
			unset DISPLAY
			source "$1/tools/lib-harness.sh"
			chextrek_run_console_script "$1" "quit" 60 chextrek_broken_env_selftest
			echo "UNREACHED: harness returned instead of exiting"
		' _ "$REPO_ROOT" 2>&1)"
	CODE=$?
	ELAPSED=$(( $(date +%s) - START ))
}

assert_environment_exit() {
	local LABEL="$1" WANT_SUBSTR="$2"
	if [ "$CODE" -eq 3 ]; then echo "PASS: ${LABEL} exits 3"; else echo "FAIL: ${LABEL} exit code $CODE, want 3"; FAIL=1; fi
	if echo "$OUT" | grep -q "^ENVIRONMENT:"; then echo "PASS: ${LABEL} prints an ENVIRONMENT line"; else echo "FAIL: ${LABEL}: no ENVIRONMENT line"; FAIL=1; fi
	if echo "$OUT" | grep -qi "$WANT_SUBSTR"; then echo "PASS: ${LABEL} names the missing piece"; else echo "FAIL: ${LABEL}: expected an ENVIRONMENT line mentioning '${WANT_SUBSTR}'"; FAIL=1; fi
	if echo "$OUT" | grep -q "Launching dhewm3"; then echo "FAIL: ${LABEL}: dhewm3 was launched anyway"; FAIL=1; else echo "PASS: ${LABEL}: dhewm3 not launched"; fi
	if [ "$ELAPSED" -le 5 ]; then echo "PASS: ${LABEL}: stopped in ${ELAPSED}s"; else echo "FAIL: ${LABEL}: took ${ELAPSED}s to stop"; FAIL=1; fi
}

# --- case: wine not on PATH -> exit 3, ENVIRONMENT names wine ---
setup_good_fixtures
run_case "${SCRATCH}/base-bin" "${SCRATCH}/dhewm3" "${SCRATCH}/doom3" "${SCRATCH}/wineprefix"
assert_environment_exit "wine missing" "wine not found"

# --- case: wine present, winepath missing -> exit 3, ENVIRONMENT names winepath ---
setup_good_fixtures
mkdir -p "${SCRATCH}/wine-only-bin"
cat > "${SCRATCH}/wine-only-bin/wine" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "${SCRATCH}/wine-only-bin/wine"
run_case "${SCRATCH}/wine-only-bin:${SCRATCH}/base-bin" "${SCRATCH}/dhewm3" "${SCRATCH}/doom3" "${SCRATCH}/wineprefix"
assert_environment_exit "winepath missing" "winepath not found"

# --- case: wine+winepath present, Wine prefix not initialized -> exit 3, ENVIRONMENT names the prefix ---
setup_good_fixtures
stub_wine_tools "${SCRATCH}/wine-bin"
run_case "${SCRATCH}/wine-bin:${SCRATCH}/base-bin" "${SCRATCH}/dhewm3" "${SCRATCH}/doom3" "${SCRATCH}/missing-wineprefix"
assert_environment_exit "Wine prefix not set up" "wine prefix"

# --- case: Wine OK, Doom 3 data missing -> exit 3, ENVIRONMENT names the Doom 3 data ---
setup_good_fixtures
run_case "${SCRATCH}/wine-bin:${SCRATCH}/base-bin" "${SCRATCH}/dhewm3" "${SCRATCH}/missing-doom3" "${SCRATCH}/wineprefix"
assert_environment_exit "Doom 3 data missing" "doom 3 data"

# --- case: Wine + Doom 3 data OK, dhewm3 engine missing -> exit 3, ENVIRONMENT names the engine ---
setup_good_fixtures
run_case "${SCRATCH}/wine-bin:${SCRATCH}/base-bin" "${SCRATCH}/missing-dhewm3" "${SCRATCH}/doom3" "${SCRATCH}/wineprefix"
assert_environment_exit "dhewm3 engine missing" "dhewm3 engine"

# --- case: every resource present -> gets past every #63 preflight check (no ENVIRONMENT line),
# and reaches the ordinary (non-environment) ensure-a-display step, whose only remaining way to
# stop in this stripped-down environment is Xvfb genuinely not being installed - proving the
# preflight checks above don't false-positive once everything they check for is actually there. ---
setup_good_fixtures
run_case "${SCRATCH}/wine-bin:${SCRATCH}/base-bin" "${SCRATCH}/dhewm3" "${SCRATCH}/doom3" "${SCRATCH}/wineprefix"
if [ "$CODE" -eq 3 ] && echo "$OUT" | grep -q "^ENVIRONMENT: no display"; then
	echo "PASS: with every #63 resource present, only the (unrelated) missing-Xvfb display check stops the run"
else
	echo "FAIL: expected to get past every #63 preflight check and stop only on the missing-Xvfb display check; got (exit $CODE):"
	echo "$OUT" | tail -8
	FAIL=1
fi
if echo "$OUT" | grep -qi "wine not found\|winepath not found\|wine prefix\|doom 3 data\|dhewm3 engine"; then
	echo "FAIL: a #63 preflight check false-positived even though its resource was present:"
	echo "$OUT" | grep -i "wine not found\|winepath not found\|wine prefix\|doom 3 data\|dhewm3 engine"
	FAIL=1
else
	echo "PASS: no #63 preflight check false-positived"
fi

echo
[ $FAIL -eq 0 ] && echo "PASS: harness broken-environment self-test" || echo "FAIL: harness broken-environment self-test"
exit $FAIL
