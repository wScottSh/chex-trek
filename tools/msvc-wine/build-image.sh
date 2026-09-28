#!/usr/bin/env bash
# One-time Unicron setup (spec #58/#64): builds the pinned MSVC-14.50.18.0-x86-under-Wine
# container image tools/build-chextrek.sh's Linux branch uses. Downloads ~1GB from Microsoft
# (accepting the VS Build Tools license terms, see tools/msvc-wine/Dockerfile) and takes several
# minutes; only needs to run again if the pin in that Dockerfile changes. See docs/dev-setup.md's
# "Unicron (Linux/Wine)" section.
#
# Usage: tools/msvc-wine/build-image.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Keep this tag in sync with CHEXTREK_MSVC_IMAGE in tools/build-chextrek.sh.
IMAGE="chextrek-msvc-wine:14.50.18.0-x86"

echo "==> Building ${IMAGE} from ${SCRIPT_DIR}/Dockerfile (pinned MSVC 14.50.18.0, x86)"
docker build -t "$IMAGE" "$SCRIPT_DIR"
echo "==> Built ${IMAGE}"
