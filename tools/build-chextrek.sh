#!/usr/bin/env bash
# One command to build chextrek.dll (32-bit x86) from the vendored dhewm3-sdk import
# (engine/dhewm3-sdk, pinned at ad837f9b1b - see engine/dhewm3-sdk/UPSTREAM.md) using the
# installed VS 18 Build Tools (x86) and bundled CMake. Spec #28/#29.
#
# Usage: tools/build-chextrek.sh [Debug|RelWithDebInfo|Release]
#
# Output: <repo-root>/chextrek.dll (and matching .pdb), placed at the repo root because that's
# the mod's fs_game folder the engine searches for "<fs_game>.dll" - see docs/dev-setup.md.
set -euo pipefail

CONFIG="${1:-RelWithDebInfo}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SDK_DIR="${REPO_ROOT}/engine/dhewm3-sdk"
BUILD_DIR="${REPO_ROOT}/engine/build"

# CMake ships inside the VS 18 Build Tools install, which lives outside this repo/worktree.
CMAKE_CANDIDATES=(
	"/c/Program Files (x86)/Microsoft Visual Studio/18/BuildTools/Common7/IDE/CommonExtensions/Microsoft/CMake/CMake/bin/cmake.exe"
	"/c/Program Files/Microsoft Visual Studio/18/BuildTools/Common7/IDE/CommonExtensions/Microsoft/CMake/CMake/bin/cmake.exe"
)
CMAKE=""
for c in "${CMAKE_CANDIDATES[@]}"; do
	if [ -x "$c" ]; then
		CMAKE="$c"
		break
	fi
done
if [ -z "$CMAKE" ]; then
	echo "error: couldn't find cmake.exe under the VS 18 Build Tools install. See docs/dev-setup.md." >&2
	exit 1
fi

echo "==> Configuring (Win32, BASE_NAME=chextrek, D3XP=OFF) into ${BUILD_DIR}"
"$CMAKE" -S "$SDK_DIR" -B "$BUILD_DIR" \
	-G "Visual Studio 18 2026" -A Win32 \
	-DBASE=ON -DBASE_NAME=chextrek -DD3XP=OFF

echo "==> Building (${CONFIG})"
"$CMAKE" --build "$BUILD_DIR" --config "$CONFIG" --target base -- -m

BUILT_DLL="${BUILD_DIR}/${CONFIG}/chextrek.dll"
if [ ! -f "$BUILT_DLL" ]; then
	# Single-config generators (Ninja/NMake) put it straight in BUILD_DIR.
	BUILT_DLL="${BUILD_DIR}/chextrek.dll"
fi
if [ ! -f "$BUILT_DLL" ]; then
	echo "error: build finished but chextrek.dll wasn't found under ${BUILD_DIR}" >&2
	exit 1
fi

echo "==> Copying $(basename "$BUILT_DLL") -> ${REPO_ROOT}/chextrek.dll"
cp -f "$BUILT_DLL" "${REPO_ROOT}/chextrek.dll"
PDB="${BUILT_DLL%.dll}.pdb"
[ -f "$PDB" ] && cp -f "$PDB" "${REPO_ROOT}/chextrek.pdb"

echo "==> Built ${REPO_ROOT}/chextrek.dll ($CONFIG)"
