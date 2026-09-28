#!/usr/bin/env bash
# One command to build chextrek.dll (32-bit x86) from the vendored dhewm3-sdk import
# (engine/dhewm3-sdk, pinned at ad837f9b1b - see engine/dhewm3-sdk/UPSTREAM.md). Spec #28/#29
# (Windows, MSVC via the installed VS 18 Build Tools), extended by spec #58/#64 (Unicron/Linux,
# the same MSVC version - 14.50.35717 - run under Wine in a pinned container, see
# tools/msvc-wine/Dockerfile and docs/dev-setup.md's "Unicron (Linux/Wine)" section).
#
# Usage: bash tools/build-chextrek.sh [Debug|RelWithDebInfo|Release]
#
# Exit status: 0 built; non-zero on a build failure; 3 (Linux only) on an environment blocker -
# docker or the pinned toolchain image missing - with an ENVIRONMENT line, not a build result.
#
# Output: <repo-root>/chextrek.dll (and matching .pdb), placed at the repo root because that's
# the mod's fs_game folder the engine searches for "<fs_game>.dll" - see docs/dev-setup.md.
set -euo pipefail

# Exit 3 means "environment blocker" (see Exit status above) and only the checks that print an
# ENVIRONMENT line may use it: they set ENVIRONMENT_EXIT=1 first. Any other exit 3 (a docker/cmake/
# ninja/wine failure that happens to return 3) is a build failure, so it's remapped to 1 here.
ENVIRONMENT_EXIT=0
trap 'RC=$?; if [ "$RC" -eq 3 ] && [ "$ENVIRONMENT_EXIT" != "1" ]; then exit 1; fi' EXIT

CONFIG="${1:-RelWithDebInfo}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SDK_DIR="${REPO_ROOT}/engine/dhewm3-sdk"
BUILD_DIR="${REPO_ROOT}/engine/build"

case "$(uname -s)" in
Linux*)
	# Unicron (Linux/Wine, spec #58/#64): same CMake project options as Windows
	# (BASE=ON, BASE_NAME=chextrek, D3XP=OFF, 32-bit), built with Ninja against the pinned
	# MSVC-14.50.35717-x86-under-Wine toolchain, packaged as a container image so a rebuild
	# months later reproduces the same MSVC toolset. One-time setup: tools/msvc-wine/build-image.sh
	# (see docs/dev-setup.md). Keep this tag in sync with tools/msvc-wine/build-image.sh.
	CHEXTREK_MSVC_IMAGE="chextrek-msvc-wine:14.50.35717-x86"

	# A missing docker or toolchain image is a machine-setup problem, not a build failure of this
	# commit: exit 3 with an ENVIRONMENT line, the harness's environment-blocker contract (see
	# tools/run-all-tests.sh), so the pipeline never files it as a red game result.
	if ! command -v docker >/dev/null 2>&1; then
		echo "ENVIRONMENT: docker not found on PATH - needed for the Linux (msvc-wine) build."
		echo "ENVIRONMENT: this is not a test failure. See docs/dev-setup.md; do not wait or retry."
		ENVIRONMENT_EXIT=1
		exit 3
	fi
	if ! docker image inspect "$CHEXTREK_MSVC_IMAGE" >/dev/null 2>&1; then
		echo "ENVIRONMENT: docker image '${CHEXTREK_MSVC_IMAGE}' not found (or docker isn't reachable)."
		echo "ENVIRONMENT: this is not a test failure. One-time setup: bash tools/msvc-wine/build-image.sh (see docs/dev-setup.md); do not wait or retry."
		ENVIRONMENT_EXIT=1
		exit 3
	fi

	echo "==> Configuring (Win32/MSVC-under-Wine, BASE_NAME=chextrek, D3XP=OFF) into ${BUILD_DIR}"
	mkdir -p "$BUILD_DIR"
	# CMAKE_*_LINKER_FLAGS=/MANIFEST:NO: this MSVC-under-Wine link.exe doesn't produce the
	# side-car manifest CMake's default Ninja/MSVC rules expect to hand to mt.exe afterwards
	# (mt then fails with "File not found") - chextrek.dll doesn't need a manifest embedded.
	# HOST_UID/HOST_GID: the container runs as root (it needs root's own baked-in wine prefix
	# from the image build, see tools/msvc-wine/Dockerfile), so hand ownership of what it wrote
	# under engine/build back to the invoking user before exiting.
	# `timeout 1800`: a wedged cl/link/ninja under Wine must not hang an AFK run forever - 1800s
	# (30 min) is generous next to the ~10s a normal build takes post-mspdbsrv-fix (see
	# docs/dev-setup.md), but still bounded. `--init`: bash runs as the container's PID 1, which
	# ignores SIGTERM by default, so without an init process `timeout`'s SIGTERM (and then SIGKILL)
	# wouldn't reliably stop it or reap the wine processes underneath it.
	timeout 1800 docker run --rm -i --init \
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

# Pre-start mspdbsrv.exe detached, stdio pointed at /dev/null, before any cl.exe invocation.
# Without this, whichever cl.exe invocation is first to need it (a CMake ABI-detection probe,
# or the first /Zi compile) spawns it itself and it inherits *that* cl invocation's stdout/stderr
# pipe - the one msvc-wine's `sed` output filter reads from. mspdbsrv is a long-lived background
# daemon, so it holds that pipe's write end open long after the cl.exe that spawned it has exited,
# and `sed` (and so that one ninja/cmake step) blocks waiting for EOF until mspdbsrv's own ~10-minute
# idle-shutdown timer closes it - paying that ~10 minutes on every from-scratch build. Starting it
# ourselves first, with stdio that isn't any build step's pipe, means every later cl.exe just
# connects to the already-running instance instead of spawning (and stalling on) a new one.
MSPDBSRV="$(find /opt/msvc -iname mspdbsrv.exe -print -quit || true)"
if [ -n "$MSPDBSRV" ]; then
	wine "$MSPDBSRV" -start -spawn < /dev/null > /dev/null 2>&1 &
fi

# CMAKE_POLICY_DEFAULT_CMP0141=NEW + CMAKE_MSVC_DEBUG_INFORMATION_FORMAT: makes CMake's own
# compiler-identification/ABI-detection try_compile probes use /Z7 instead of their default /Zi
# (see mstorsjo/msvc-wine's README) - those probes run before the pre-started mspdbsrv above would
# otherwise help, cutting configure time dramatically. For Debug/RelWithDebInfo it also ends up
# overriding dhewm3-sdk's own explicit /Zi for real source compiles (engine/dhewm3-sdk/CMakeLists.txt
# sets that directly in CMAKE_CXX_FLAGS_DEBUG/_RELWITHDEBINFO, not through this CMake abstraction) -
# CMake appends this flag's /Z7 after it on every compile command line, and cl takes the last
# debug-format switch, printing a harmless `D9025: overriding '/Zi' with '/Z7'` warning per file.
# The generator expression limits this to Debug/RelWithDebInfo (the only configs dhewm3-sdk's own
# flags put /Zi in to begin with) so Release/MinSizeRel keep the same no-embedded-debug-info
# behavior as the Windows/MSBuild build, not silently pick up debug info they didn't ask for. Real
# source compiles mostly don't need mspdbsrv either way now; the pre-started instance above is the
# backstop for whatever still triggers it (e.g. /FS, still present on the command line by CMake's
# own default RelWithDebInfo flags).
CC=cl CXX=cl cmake -S engine/dhewm3-sdk -B engine/build -G Ninja \
	-DCMAKE_SYSTEM_NAME=Windows -DCMAKE_SYSTEM_PROCESSOR=x86 \
	-DCMAKE_EXE_LINKER_FLAGS=/MANIFEST:NO -DCMAKE_SHARED_LINKER_FLAGS=/MANIFEST:NO \
	-DCMAKE_POLICY_DEFAULT_CMP0141=NEW \
	"-DCMAKE_MSVC_DEBUG_INFORMATION_FORMAT=\$<\$<CONFIG:Debug,RelWithDebInfo>:Embedded>" \
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
