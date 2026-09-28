#!/usr/bin/env bash
# One command to build chextrek.dll (32-bit x86) from the vendored dhewm3-sdk import
# (engine/dhewm3-sdk, pinned at ad837f9b1b - see engine/dhewm3-sdk/UPSTREAM.md). Spec #28/#29
# (Windows, MSVC via the installed VS 18 Build Tools), extended by spec #58/#64 (Unicron/Linux,
# the same MSVC version - 14.50.18.0 - run under Wine in a pinned container, see
# tools/msvc-wine/Dockerfile and docs/dev-setup.md's "Unicron (Linux/Wine)" section).
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

case "$(uname -s)" in
Linux*)
	# Unicron (Linux/Wine, spec #58/#64): same CMake project options as Windows
	# (BASE=ON, BASE_NAME=chextrek, D3XP=OFF, 32-bit), built with Ninja against the pinned
	# MSVC-14.50.18.0-x86-under-Wine toolchain, packaged as a container image so a rebuild
	# months later reproduces the same compiler. One-time setup: tools/msvc-wine/build-image.sh
	# (see docs/dev-setup.md). Keep this tag in sync with tools/msvc-wine/build-image.sh.
	CHEXTREK_MSVC_IMAGE="chextrek-msvc-wine:14.50.18.0-x86"

	if ! command -v docker >/dev/null 2>&1; then
		echo "error: docker not found on PATH - needed for the Linux (msvc-wine) build. See docs/dev-setup.md." >&2
		exit 1
	fi
	if ! docker image inspect "$CHEXTREK_MSVC_IMAGE" >/dev/null 2>&1; then
		echo "error: docker image '${CHEXTREK_MSVC_IMAGE}' not found. One-time setup: tools/msvc-wine/build-image.sh. See docs/dev-setup.md." >&2
		exit 1
	fi

	echo "==> Configuring (Win32/MSVC-under-Wine, BASE_NAME=chextrek, D3XP=OFF) into ${BUILD_DIR}"
	mkdir -p "$BUILD_DIR"
	# CMAKE_*_LINKER_FLAGS=/MANIFEST:NO: this MSVC-under-Wine link.exe doesn't produce the
	# side-car manifest CMake's default Ninja/MSVC rules expect to hand to mt.exe afterwards
	# (mt then fails with "File not found") - chextrek.dll doesn't need a manifest embedded.
	# HOST_UID/HOST_GID: the container runs as root (it needs root's own baked-in wine prefix
	# from the image build, see tools/msvc-wine/Dockerfile), so hand ownership of what it wrote
	# under engine/build back to the invoking user before exiting.
	docker run --rm -i \
		-v "${REPO_ROOT}:/src" \
		-w /src \
		-e CONFIG="$CONFIG" \
		-e HOST_UID="$(id -u)" \
		-e HOST_GID="$(id -g)" \
		"$CHEXTREK_MSVC_IMAGE" \
		bash -s <<'DOCKER_BUILD_EOF'
set -euo pipefail
# Run even if a step below fails, so a failed configure/build never leaves engine/build owned by
# root (unwritable/undeletable by the invoking user, and in the way of the next attempt).
trap 'chown -R "${HOST_UID}:${HOST_GID}" engine/build 2>/dev/null || true' EXIT
CC=cl CXX=cl cmake -S engine/dhewm3-sdk -B engine/build -G Ninja \
	-DCMAKE_SYSTEM_NAME=Windows -DCMAKE_SYSTEM_PROCESSOR=x86 \
	-DCMAKE_EXE_LINKER_FLAGS=/MANIFEST:NO -DCMAKE_SHARED_LINKER_FLAGS=/MANIFEST:NO \
	-DBASE=ON -DBASE_NAME=chextrek -DD3XP=OFF -DCMAKE_BUILD_TYPE="${CONFIG}"
echo "==> Building (${CONFIG})"
cmake --build engine/build --target base
DOCKER_BUILD_EOF
	;;
*)
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
	;;
esac

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
