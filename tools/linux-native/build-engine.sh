#!/usr/bin/env bash
# Builds the native x86_64 Linux dhewm3 1.5.5 engine from upstream source
# (https://github.com/dhewm/dhewm3, tag 1.5.5, pinned by commit below) inside the
# tools/linux-native/ toolchain image, and installs the `dhewm3` binary into OUT_DIR. The engine
# itself is stock - nothing in this repo patches it; GAME_API_VERSION (9) matches the vendored
# engine/dhewm3-sdk pin (engine/dhewm3-sdk/UPSTREAM.md), which this script checks.
#
# Usage: bash tools/linux-native/build-engine.sh OUT_DIR
#   OUT_DIR - where `dhewm3` lands. The harness's native mode defaults DHEWM3_HOME to
#             $HOME/games/dhewm3/1.5.5-linux-x86_64; tools/package-linux.sh passes its own.
#
# Environment:
#   DHEWM3_SRC - the dhewm3 source checkout. Defaults to $HOME/games/src/dhewm3, cloned there
#                (shallow, tag 1.5.5) if it doesn't exist yet. Must be at the pinned commit.
#
# Exit status: 0 built; 1 build failure or a source checkout at the wrong commit; 3 docker or the
# toolchain image missing (an ENVIRONMENT line, same contract as tools/build-chextrek.sh).
set -euo pipefail

OUT_DIR="${1:?usage: build-engine.sh OUT_DIR}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

DHEWM3_TAG="1.5.5"
DHEWM3_COMMIT="455b88e8dff2be822f08eb498f51b383e851fa38"
DHEWM3_SRC="${DHEWM3_SRC:-$HOME/games/src/dhewm3}"
# Keep in sync with tools/linux-native/build-image.sh.
CHEXTREK_NATIVE_IMAGE="chextrek-linux-native:jammy-2"

if ! command -v docker >/dev/null 2>&1 || ! docker image inspect "$CHEXTREK_NATIVE_IMAGE" >/dev/null 2>&1; then
	echo "ENVIRONMENT: docker or the '${CHEXTREK_NATIVE_IMAGE}' image is missing - needed for the native Linux build."
	echo "ENVIRONMENT: this is not a test failure. One-time setup: bash tools/linux-native/build-image.sh (see docs/dev-setup.md); do not wait or retry."
	exit 3
fi

if [ ! -d "$DHEWM3_SRC" ]; then
	echo "==> Cloning dhewm3 ${DHEWM3_TAG} into ${DHEWM3_SRC}"
	git clone --depth 1 --branch "$DHEWM3_TAG" https://github.com/dhewm/dhewm3.git "$DHEWM3_SRC"
fi
HEAD_COMMIT="$(git -C "$DHEWM3_SRC" rev-parse HEAD)"
if [ "$HEAD_COMMIT" != "$DHEWM3_COMMIT" ]; then
	echo "error: ${DHEWM3_SRC} is at ${HEAD_COMMIT}, expected dhewm3 ${DHEWM3_TAG} (${DHEWM3_COMMIT})." >&2
	exit 1
fi

api_version() { sed -n 's/^const int GAME_API_VERSION[[:space:]]*=[[:space:]]*\([0-9]*\);.*/\1/p' "$1"; }
ENGINE_API="$(api_version "${DHEWM3_SRC}/neo/framework/Game.h")"
SDK_API="$(api_version "${REPO_ROOT}/engine/dhewm3-sdk/framework/Game.h")"
if [ -z "$ENGINE_API" ] || [ "$ENGINE_API" != "$SDK_API" ]; then
	echo "error: engine GAME_API_VERSION '${ENGINE_API}' != engine/dhewm3-sdk's '${SDK_API}'." >&2
	exit 1
fi

mkdir -p "$OUT_DIR"
OUT_DIR="$(cd "$OUT_DIR" && pwd)"
BUILD_DIR="${OUT_DIR}/.build"

# BASE=OFF/D3XP=OFF: only the engine executable - the game library is chextrek.so. CURL disabled:
# it's only used to download pk4s from multiplayer servers, and skipping it keeps libcurl (and its
# TLS stack) out of the shipped binary's dependencies. REPRODUCIBLE_BUILD replaces __DATE__/
# __TIME__ so two builds of the same commit are byte-comparable. The source is mounted read-only;
# --user keeps everything written into OUT_DIR owned by the invoking user.
echo "==> Building dhewm3 ${DHEWM3_TAG} (native x86_64, Release) into ${OUT_DIR}"
timeout 1800 docker run --rm -i --init \
	--user "$(id -u):$(id -g)" \
	-v "${DHEWM3_SRC}:/dhewm3:ro" \
	-v "${OUT_DIR}:/out" \
	"$CHEXTREK_NATIVE_IMAGE" \
	bash -s <<'DOCKER_BUILD_EOF'
set -euo pipefail
cmake -S /dhewm3/neo -B /out/.build -G Ninja -DCMAKE_BUILD_TYPE=Release \
	-DBASE=OFF -DD3XP=OFF -DREPRODUCIBLE_BUILD=ON -DCMAKE_DISABLE_FIND_PACKAGE_CURL=ON
cmake --build /out/.build --target dhewm3
cp -f /out/.build/dhewm3 /out/dhewm3
DOCKER_BUILD_EOF
rm -rf "$BUILD_DIR"
echo "==> Built ${OUT_DIR}/dhewm3"
