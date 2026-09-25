#!/usr/bin/env bash
# One command to run the AFK test harness (spec #28/#29): launches the official dhewm3 1.5.5
# win32 engine with this checkout mounted as the chextrek mod, drives it with a console script
# ending in "quit", kills it after a timeout if an error dialog hangs it, and reports pass/fail
# from the engine log plus the chextrek_dump state-dump header.
#
# This is the always-on smoke check: does the main menu load clean. Feature scenarios (spec #30
# onward) are separate tools/test-*.sh scripts built on the same tools/lib-harness.sh plumbing -
# see docs/harness-coverage.md for which scenario covers which feature.
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

# shellcheck source=tools/lib-harness.sh
source "${SCRIPT_DIR}/lib-harness.sh"

CONSOLE_SCRIPT="developer 1
chextrek_dump
wait
screenshot chextrek_harness
wait
quit"

chextrek_run_console_script "$REPO_ROOT" "$CONSOLE_SCRIPT" "$TIMEOUT_SECS" "chextrek_harness"
echo "CHEXTREK_LOCAL_LOG=${CHEXTREK_LOCAL_LOG:-}"
exit $CHEXTREK_RUN_STATUS
