#!/usr/bin/env bash
# Runs an arbitrary console script through the AFK harness plumbing (tools/lib-harness.sh) and
# prints the archived log's path. Used by feature scenario tests (tools/test-*.sh, spec #30
# onward) that need to drive the game with map/spawn/script/wait commands beyond the fixed
# smoke-check script tools/run-harness.sh runs. See docs/dev-setup.md.
#
# Usage: tools/run-scenario.sh <scenario-name> <console-script-file> [timeout-seconds]
#
# <console-script-file> must be the *complete* console script (including "developer 1" and a
# trailing "quit") - see tools/lib-harness.sh's chextrek_run_console_script.
#
# Exits with the always-on checks' status (spec #28: chextrek.dll loaded, state-dump header
# present, no ERROR/unknown-event/unknown-spawnclass/script-compile lines). Prints
# "CHEXTREK_LOCAL_LOG=<path>" on its own line so callers can grep the archived log for their own
# scenario-specific assertions.
set -uo pipefail

if [ $# -lt 2 ]; then
	echo "usage: tools/run-scenario.sh <scenario-name> <console-script-file> [timeout-seconds]" >&2
	exit 1
fi

SCENARIO_NAME="$1"
SCRIPT_FILE="$2"
TIMEOUT_SECS="${3:-90}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# shellcheck source=tools/lib-harness.sh
source "${SCRIPT_DIR}/lib-harness.sh"

if [ ! -f "$SCRIPT_FILE" ]; then
	echo "error: console-script file not found: ${SCRIPT_FILE}" >&2
	exit 1
fi

CONSOLE_SCRIPT="$(cat "$SCRIPT_FILE")"

chextrek_run_console_script "$REPO_ROOT" "$CONSOLE_SCRIPT" "$TIMEOUT_SECS" "$SCENARIO_NAME"
STATUS=$CHEXTREK_RUN_STATUS

echo "CHEXTREK_LOCAL_LOG=${CHEXTREK_LOCAL_LOG:-}"

exit $STATUS
