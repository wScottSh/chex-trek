#!/usr/bin/env bash
# One command to package Chex Trek for native Linux players: a single x86_64 AppImage holding the
# stock dhewm3 1.5.5 engine, this checkout's chextrek.so and its mod data packed as one pk4, plus
# SDL2 and OpenAL Soft - and none of id Software's Doom 3 data, which the player supplies from
# their own install (tools/linux-native/AppRun finds it at launch). See docs/dev-setup.md's
# "Packaging for Linux players" section.
#
# Usage: bash tools/package-linux.sh
#
# Output (dist/, gitignored):
#   dist/ChexTrek-x86_64.AppImage - the artifact to send.
#   dist/README.md                - the player-facing README (tools/linux-native/README-player.md),
#                                   also inside the AppImage.
#
# Everything is built fresh each run: chextrek.so via tools/build-chextrek.sh (CHEXTREK_PLATFORM=
# native, the same build the harness tests), the engine via tools/linux-native/build-engine.sh,
# both in the pinned tools/linux-native/ image, which also supplies the two bundled libraries.
# The mod data is the *tracked* files (git ls-files) of the runtime data dirs, so untracked junk
# in a working copy never ships; their working-tree content is what's packed. The pk4 is
# byte-reproducible for a given commit (tools/linux-native/make-pk4.py stamps every entry with the
# commit's time). To prove the artifact itself, run the suite against it:
#   CHEXTREK_PLATFORM=appimage bash tools/run-all-tests.sh
#
# Before building the AppImage it refuses (exit 1) if:
#   - any packaged ELF needs glibc newer than GLIBC_FLOOR below (the floor README-player.md
#     promises);
#   - the pk4 contains any file byte-identical to one in the Doom 3 base paks at
#     $DOOM3_BASEPATH/base (default $HOME/games/doom3) - i.e. id's own data. The mod tracks a few
#     verbatim copies of id files; make-pk4.py leaves those out (the engine loads the same bytes
#     from the player's install instead - see its header), and this check is the independent guard.
#
# Environment:
#   DOOM3_BASEPATH       - classic Doom 3 install whose base/*.pk4 the id-data steps read.
#   CHEXTREK_TOOLS_DIR   - where the pinned appimagetool and AppImage runtime are cached
#                          (downloaded and checksummed on first use). Default
#                          $HOME/games/tools/appimage.
#
# Exit status: 0 packaged; 1 a build, check or packaging failure; 3 an environment blocker (docker
# or the toolchain image missing), passed through from the build scripts.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
NATIVE_DIR="${SCRIPT_DIR}/linux-native"
DIST="${REPO_ROOT}/dist"
WORK="${DIST}/.work"
APPDIR="${WORK}/ChexTrek.AppDir"
OUT="${DIST}/ChexTrek-x86_64.AppImage"
DOOM3_BASEPATH="${DOOM3_BASEPATH:-$HOME/games/doom3}"
TOOLS_DIR="${CHEXTREK_TOOLS_DIR:-$HOME/games/tools/appimage}"
# Keep in sync with tools/linux-native/build-image.sh.
CHEXTREK_NATIVE_IMAGE="chextrek-linux-native:jammy-2"
# The toolchain image's own glibc (Ubuntu 22.04); README-player.md promises it.
GLIBC_FLOOR="2.35"

APPIMAGETOOL_URL="https://github.com/AppImage/appimagetool/releases/download/1.9.1/appimagetool-x86_64.AppImage"
APPIMAGETOOL_SHA256="ed4ce84f0d9caff66f50bcca6ff6f35aae54ce8135408b3fa33abfc3cb384eb0"
RUNTIME_URL="https://github.com/AppImage/type2-runtime/releases/download/20251108/runtime-x86_64"
RUNTIME_SHA256="2fca8b443c92510f1483a883f60061ad09b46b978b2631c807cd873a47ec260d"

# The engine's runtime data dirs; everything else at the repo root (tools/, docs/, engine/,
# decomp-so/, the old gamex86.dll/.so and game.dylib, notes, personal cfgs) is dev material.
DATA_DIRS='af|dds|def|env|guis|maps|materials|models|newpdas|particles|script|skins|sound|strings|textures|video'
# Dev cruft tracked inside those dirs: editor backups and autosaves, MFC temp files, Windows tools
# and batch files, notes, GIMP/GUI-editor sources, and a .gif the engine can't load anyway.
EXCLUDE_RE='\.(bak|tmp|exe|bat|txt|xcf|guied|gif)$|(^|/|\.)autosave\.map$'

# fetch_pinned URL DEST SHA256 - downloads URL to DEST unless already there, then verifies it.
fetch_pinned() {
	if [ ! -f "$2" ]; then
		echo "==> Downloading $(basename "$2")"
		mkdir -p "$(dirname "$2")"
		curl -fsSLo "$2.part" "$1"
		mv "$2.part" "$2"
	fi
	echo "$3  $2" | sha256sum -c --quiet - || { echo "error: $2 doesn't match its pinned sha256" >&2; exit 1; }
	chmod +x "$2"
}

# max_glibc FILE... - the newest GLIBC_x.y symbol version any of FILE needs.
max_glibc() {
	objdump -T "$@" | grep -oE 'GLIBC_[0-9]+\.[0-9]+(\.[0-9]+)?' | sed 's/GLIBC_//' | sort -uV | tail -1
}

rm -rf "$WORK"
mkdir -p "$WORK"

echo "=== chextrek.so (CHEXTREK_PLATFORM=native) ==="
CHEXTREK_PLATFORM=native bash "${REPO_ROOT}/tools/build-chextrek.sh"
echo "=== dhewm3 1.5.5 engine ==="
bash "${NATIVE_DIR}/build-engine.sh" "${WORK}/engine"
echo "=== bundled libraries ==="
mkdir -p "${WORK}/libs"
docker run --rm --user "$(id -u):$(id -g)" -v "${WORK}/libs:/out" "$CHEXTREK_NATIVE_IMAGE" \
	cp -R /opt/chextrek-libs/. /out/

echo "=== AppDir ==="
VERSION="$(git -C "$REPO_ROOT" describe --always --dirty --abbrev=10)"
EPOCH="$(git -C "$REPO_ROOT" log -1 --format=%ct)"
mkdir -p "${APPDIR}/usr/bin" "${APPDIR}/usr/lib/chextrek" "${APPDIR}/usr/share/chextrek/chextrek" \
	"${APPDIR}/usr/share/doc/chextrek"
install -m 755 "${NATIVE_DIR}/AppRun" "${APPDIR}/AppRun"
install -m 644 "${NATIVE_DIR}/chextrek.desktop" "${NATIVE_DIR}/chextrek.png" "${APPDIR}/"
cp "${NATIVE_DIR}/chextrek.png" "${APPDIR}/.DirIcon"
install -m 755 "${WORK}/engine/dhewm3" "${APPDIR}/usr/bin/dhewm3"
install -m 755 "${REPO_ROOT}/chextrek.so" "${APPDIR}/usr/lib/chextrek/chextrek.so"
install -m 755 "${WORK}/libs/libSDL2-2.0.so.0" "${WORK}/libs/libopenal.so.1" "${APPDIR}/usr/lib/"
# Debug info only: the code is exactly what the harness ran.
strip --strip-debug "${APPDIR}/usr/bin/dhewm3" "${APPDIR}/usr/lib/chextrek/chextrek.so"
install -m 644 "${NATIVE_DIR}/README-player.md" "${APPDIR}/usr/share/doc/chextrek/README.md"
install -m 644 "${REPO_ROOT}/engine/dhewm3-sdk/COPYING.txt" "${APPDIR}/usr/share/doc/chextrek/COPYING.txt"
install -m 644 "${WORK}/libs/LICENSE.SDL2.txt" "${WORK}/libs/LICENSE.openal-soft.txt" "${APPDIR}/usr/share/doc/chextrek/"
printf 'chex-trek %s\ndhewm3 1.5.5\n' "$VERSION" >"${APPDIR}/usr/share/doc/chextrek/VERSION"

PK4="${APPDIR}/usr/share/chextrek/chextrek/chextrek.pk4"
git -C "$REPO_ROOT" ls-files | grep -E "^(${DATA_DIRS})/|^autoexec\.cfg\$" | grep -viE "$EXCLUDE_RE" \
	>"${WORK}/pk4-files.txt"
# script/doom_events.script is the mod's verbatim copy of Doom 3 1.0's (pak000); 1.3.1's pak008
# copy, which loads once it's left out, differs only by declaring one more script event,
# getIdealWeapon - which the chextrek game library defines (engine/dhewm3-sdk/game/Player.cpp,
# EV_Player_GetIdealWeapon), so the scripts compile and behave the same.
python3 -I "${NATIVE_DIR}/make-pk4.py" "$REPO_ROOT" "$PK4" "$EPOCH" "${DOOM3_BASEPATH}/base" \
	script/doom_events.script <"${WORK}/pk4-files.txt"

echo "=== checks ==="
FLOOR="$(max_glibc "${APPDIR}/usr/bin/dhewm3" "${APPDIR}/usr/lib/chextrek/chextrek.so" "${APPDIR}"/usr/lib/*.so.*)"
if [ "$(printf '%s\n%s\n' "$FLOOR" "$GLIBC_FLOOR" | sort -V | tail -1)" != "$GLIBC_FLOOR" ]; then
	echo "error: the packaged binaries need glibc ${FLOOR}, newer than the promised floor ${GLIBC_FLOOR}" >&2
	exit 1
fi
echo "glibc floor: ${FLOOR} (promised: <= ${GLIBC_FLOOR})"
python3 -I "${NATIVE_DIR}/check-no-id-data.py" "$PK4" "${DOOM3_BASEPATH}/base"

echo "=== AppImage ==="
fetch_pinned "$APPIMAGETOOL_URL" "${TOOLS_DIR}/appimagetool-1.9.1/appimagetool-x86_64.AppImage" "$APPIMAGETOOL_SHA256"
fetch_pinned "$RUNTIME_URL" "${TOOLS_DIR}/type2-runtime-20251108/runtime-x86_64" "$RUNTIME_SHA256"
rm -f "$OUT"
# APPIMAGE_EXTRACT_AND_RUN: appimagetool is itself an AppImage; this runs it without needing FUSE
# on the packaging host. SOURCE_DATE_EPOCH makes its mksquashfs stamp the commit's time.
APPIMAGE_EXTRACT_AND_RUN=1 SOURCE_DATE_EPOCH="$EPOCH" ARCH=x86_64 \
	"${TOOLS_DIR}/appimagetool-1.9.1/appimagetool-x86_64.AppImage" --no-appstream \
	--runtime-file "${TOOLS_DIR}/type2-runtime-20251108/runtime-x86_64" "$APPDIR" "$OUT"
install -m 644 "${NATIVE_DIR}/README-player.md" "${DIST}/README.md"
rm -rf "$WORK"

echo "==> Packaged ${OUT} ($(du -h "$OUT" | cut -f1), chex-trek ${VERSION})"
sha256sum "$OUT"
