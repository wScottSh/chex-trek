#!/usr/bin/env bash
# One-time Unicron setup: builds the pinned native-Linux toolchain image (Ubuntu 22.04, gcc 11)
# that tools/build-chextrek.sh (CHEXTREK_PLATFORM=native), tools/linux-native/build-engine.sh and
# tools/package-linux.sh build in. Only needs to run again if tools/linux-native/Dockerfile
# changes. See docs/dev-setup.md's "Native Linux" section.
#
# Usage: bash tools/linux-native/build-image.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Keep this tag in sync with CHEXTREK_NATIVE_IMAGE in tools/build-chextrek.sh and
# tools/linux-native/build-engine.sh.
IMAGE="chextrek-linux-native:jammy-2"

echo "==> Building ${IMAGE} from ${SCRIPT_DIR}/Dockerfile"
docker build -t "$IMAGE" "$SCRIPT_DIR"
echo "==> Built ${IMAGE}"
