#!/usr/bin/env bash
# Harness self-test: when there is no display (this Windows user session is disconnected, e.g.
# another user took the console), tools/lib-harness.sh must stop the whole run at once with exit
# code 3 and one ENVIRONMENT line - not launch dhewm3, and not report a pile of ordinary test
# FAILs that look like a code bug. Needs no display itself: it stubs `qwinsta` and never gets as
# far as launching the game.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SCRATCH="$(mktemp -d)"
trap 'rm -rf "$SCRATCH"' EXIT
FAIL=0

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

# --- case 2: the engine log's own no-display line is recognized (the post-run check) ---
printf '%s\r\n' "Opened this log at 2026-09-25 15:02:13" \
	"Error while initializing SDL: No displays available" > "${SCRATCH}/nodisplay.log"
printf '%s\r\n' "Opened this log at 2026-09-25 15:02:13" "CHEXTREK-STATE-DUMP v1" > "${SCRATCH}/ok.log"
source "${REPO_ROOT}/tools/lib-harness.sh"
if chextrek_log_has_no_display "${SCRATCH}/nodisplay.log"; then echo "PASS: no-display log recognized"; else echo "FAIL: no-display log not recognized"; FAIL=1; fi
if chextrek_log_has_no_display "${SCRATCH}/ok.log"; then echo "FAIL: normal log flagged as no-display"; FAIL=1; else echo "PASS: normal log not flagged"; fi

echo
[ $FAIL -eq 0 ] && echo "PASS: harness no-display self-test" || echo "FAIL: harness no-display self-test"
exit $FAIL
