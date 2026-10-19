#!/usr/bin/env bash
# One command to run the whole AFK test suite (spec #28, user story 38): builds chextrek.dll once,
# then runs the harness self-test, the main-menu smoke check and every feature scenario
# (tools/test-*.sh) in turn, and prints a pass/fail summary. See docs/harness-coverage.md for which
# scenario covers which feature.
#
# Usage: bash tools/run-all-tests.sh
#
# To run the whole suite against a prebuilt chextrek.dll instead of building (either machine -
# tools/build-chextrek.sh builds on Unicron too since spec #64), copy it to the repo root and set
# CHEXTREK_SKIP_BUILD=1 *before* calling this script (see docs/dev-setup.md's "Unicron (Linux/Wine)"
# section); it then skips the build step and runs every script against that DLL as-is. Left unset
# (the default), this always builds first.
#
# Exit status: 0 if every script passed, 1 if any failed, 3 if a run stopped on a broken-
# environment blocker - not a test result - the suite stops at once (no display; Linux-only:
# missing wine/winepath/wineserver/flock, an uninitialized Wine prefix, missing Doom 3 data, a
# missing dhewm3 engine, an unopenable lock file, or docker/the msvc-wine image missing for the
# build); see docs/dev-setup.md.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# tools/lib-harness.sh's chextrek_platform/chextrek_game_lib_name, repeated here so this script
# stays standalone (its self-tests run a copy of it with nothing else alongside): the game library
# a build drops at the repo root is chextrek.so for the native platform, else chextrek.dll.
PLATFORM=windows
case "$(uname -s)" in
Linux*) PLATFORM="${CHEXTREK_PLATFORM:-wine}" ;;
esac
GAME_LIB=chextrek.dll
[ "$PLATFORM" = native ] && GAME_LIB=chextrek.so

if [ "$PLATFORM" = appimage ]; then
	# The appimage platform tests the packaged artifact's own chextrek.so; there's nothing in this
	# checkout to build (tools/package-linux.sh builds the artifact).
	echo "=== build (skipped: CHEXTREK_PLATFORM=appimage tests the packaged artifact) ==="
elif [ "${CHEXTREK_SKIP_BUILD:-0}" = "1" ]; then
	echo "=== build (skipped: CHEXTREK_SKIP_BUILD=1) ==="
	if [ ! -f "${REPO_ROOT}/${GAME_LIB}" ]; then
		echo "FAIL: CHEXTREK_SKIP_BUILD=1 but ${REPO_ROOT}/${GAME_LIB} doesn't exist. Copy a prebuilt ${GAME_LIB} to the repo root first - see docs/dev-setup.md."
		exit 1
	fi
	echo "==> Using prebuilt ${REPO_ROOT}/${GAME_LIB}"
else
	echo "=== build ==="
	bash "${SCRIPT_DIR}/build-chextrek.sh"
	BUILD_EXIT=$?
	if [ $BUILD_EXIT -eq 3 ]; then
		echo "ENVIRONMENT: build-chextrek.sh stopped with exit 3 (broken environment, see its own ENVIRONMENT line above) - stopping the suite."
		exit 3
	fi
	if [ $BUILD_EXIT -ne 0 ]; then
		echo "FAIL: build-chextrek.sh failed"
		exit 1
	fi
fi
export CHEXTREK_SKIP_BUILD=1

PASSED=()
FAILED=()
for t in "${SCRIPT_DIR}"/test-*.sh; do
	NAME="$(basename "$t")"
	echo
	echo "=== ${NAME} ==="
	bash "$t"
	CODE=$?
	if [ $CODE -eq 3 ]; then
		echo "ENVIRONMENT: ${NAME} stopped with exit 3 (broken environment, see its own ENVIRONMENT line above) - stopping the suite."
		exit 3
	fi
	if [ $CODE -eq 0 ]; then PASSED+=("$NAME"); else FAILED+=("$NAME"); fi
done

echo
echo "=== summary: ${#PASSED[@]} passed, ${#FAILED[@]} failed ==="
for n in "${FAILED[@]}"; do echo "FAIL: ${n}"; done
[ ${#FAILED[@]} -eq 0 ] && { echo "PASS: whole suite"; exit 0; }
exit 1
