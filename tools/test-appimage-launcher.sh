#!/usr/bin/env bash
# Self-test for the Linux AppImage's launcher (tools/linux-native/AppRun, packaged by
# tools/package-linux.sh): how it finds the player's classic Doom 3 install and what it hands the
# engine. Runs AppRun from a scratch AppDir whose usr/bin/dhewm3 is a stub recording its arguments,
# with a scratch HOME/XDG dirs, so it needs no game, no display and no packaged AppImage. If the
# packaged AppImage exists (CHEXTREK_APPIMAGE, default dist/ChexTrek-x86_64.AppImage), the
# "not found" case is also run against it, proving the shipped artifact prints the same line.
# Linux-only (a no-op on Windows).
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=tools/lib-harness.sh
source "${SCRIPT_DIR}/lib-harness.sh"

if ! chextrek_is_linux; then
	echo "SKIP: the AppImage launcher is Linux-only"
	exit 0
fi

SCRATCH="$(mktemp -d)"
trap 'rm -rf "$SCRATCH"' EXIT
FAIL=0
APPDIR="${SCRATCH}/AppDir"
mkdir -p "${APPDIR}/usr/bin"
cp "${SCRIPT_DIR}/linux-native/AppRun" "${APPDIR}/AppRun"
cat >"${APPDIR}/usr/bin/dhewm3" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$@" >"$CHEXTREK_TEST_ARGS"
EOF
chmod +x "${APPDIR}/AppRun" "${APPDIR}/usr/bin/dhewm3"

# make_doom3 DIR - a stand-in classic Doom 3 install.
make_doom3() { mkdir -p "$1/base" && : >"$1/base/pak000.pk4"; }

# launch [ARG...] - runs AppRun (or LAUNCHER, if set) with a clean environment rooted at
# $SCRATCH/home. Sets OUT (stdout+stderr), CODE, and ARGS (the stub engine's argv, one per line,
# or empty if the engine was never started). EXTRA_ENV adds NAME=VALUE pairs.
launch() {
	rm -f "${SCRATCH}/args"
	OUT="$(env -i PATH="$PATH" HOME="${SCRATCH}/home" APPDIR="$APPDIR" \
		CHEXTREK_TEST_ARGS="${SCRATCH}/args" ${EXTRA_ENV:-} \
		"${LAUNCHER:-${APPDIR}/AppRun}" "$@" </dev/null 2>&1)"
	CODE=$?
	ARGS="$(cat "${SCRATCH}/args" 2>/dev/null)"
}

check() {
	if eval "$2"; then echo "PASS: $1"; else echo "FAIL: $1"; echo "  output: ${OUT}"; FAIL=1; fi
}

# arg_after NAME - the value following `+set NAME` in the stub engine's argv.
arg_after() { printf '%s\n' "$ARGS" | grep -A1 -x -- "$1" | sed -n 2p; }

echo "=== case 1: no Doom 3 anywhere -> one clear line naming --doom3, exit 2, engine not started ==="
mkdir -p "${SCRATCH}/home"
launch
check "exits 2" '[ "$CODE" -eq 2 ]'
check "prints exactly one line" '[ "$(printf "%s\n" "$OUT" | wc -l)" -eq 1 ]'
check "the line says what to pass" 'printf "%s" "$OUT" | grep -qF "chextrek: classic Doom 3 not found - run with --doom3 /path/to/Doom3 (the folder containing base/pak000.pk4), or set CHEXTREK_DOOM3_DIR."'
check "engine not started" '[ -z "$ARGS" ]'

echo "=== case 2: --doom3 at a missing dir, and at a BFG Edition dir -> exit 2 with the reason ==="
launch --doom3 "${SCRATCH}/nope"
check "missing dir: exit 2, says it doesn't exist" '[ "$CODE" -eq 2 ] && printf "%s" "$OUT" | grep -qF "doesn'"'"'t exist"'
mkdir -p "${SCRATCH}/bfg/base" && : >"${SCRATCH}/bfg/base/_common.resources"
launch --doom3 "${SCRATCH}/bfg"
check "BFG dir: exit 2, names BFG Edition" '[ "$CODE" -eq 2 ] && printf "%s" "$OUT" | grep -qF "BFG Edition"'
check "engine not started" '[ -z "$ARGS" ]'

echo "=== case 3: --doom3 at a real install -> engine gets the bundled paths, only base/ of the install, extra args, and the dir is remembered ==="
make_doom3 "${SCRATCH}/Doom 3"
mkdir -p "${SCRATCH}/Doom 3/chextrek"
launch --doom3 "${SCRATCH}/Doom 3" +set r_fullscreen 0
check "exit 0" '[ "$CODE" -eq 0 ]'
check "fs_basepath is the AppImage's own mod data dir" '[ "$(arg_after fs_basepath)" = "${APPDIR}/usr/share/chextrek" ]'
check "fs_game is chextrek" '[ "$(arg_after fs_game)" = chextrek ]'
check "fs_gameDllPath is the AppImage's own lib dir" '[ "$(arg_after fs_gameDllPath)" = "${APPDIR}/usr/lib/chextrek" ]'
CDPATH_ARG="$(arg_after fs_cdpath)"
check "fs_cdpath holds a base symlink to the install's base/" '[ "$(readlink "${CDPATH_ARG}/base")" = "${SCRATCH}/Doom 3/base" ]'
check "fs_cdpath holds nothing else (an old <Doom 3>/chextrek can't leak in)" '[ "$(ls -A "$CDPATH_ARG")" = base ]'
check "extra arguments reach the engine" 'printf "%s\n" "$ARGS" | grep -qx r_fullscreen'
check "the dir is remembered" '[ "$(cat "${SCRATCH}/home/.config/chextrek/doom3-dir")" = "${SCRATCH}/Doom 3" ]'

echo "=== case 4: a later launch with no arguments uses the remembered dir ==="
launch
check "exit 0, same install" '[ "$CODE" -eq 0 ] && [ "$(readlink "$(arg_after fs_cdpath)/base")" = "${SCRATCH}/Doom 3/base" ]'

echo "=== case 5: CHEXTREK_DOOM3_DIR wins for one launch, and isn't remembered ==="
make_doom3 "${SCRATCH}/other"
EXTRA_ENV="CHEXTREK_DOOM3_DIR=${SCRATCH}/other" launch
check "exit 0, uses CHEXTREK_DOOM3_DIR" '[ "$CODE" -eq 0 ] && [ "$(readlink "$(arg_after fs_cdpath)/base")" = "${SCRATCH}/other/base" ]'
check "remembered dir unchanged" '[ "$(cat "${SCRATCH}/home/.config/chextrek/doom3-dir")" = "${SCRATCH}/Doom 3" ]'

echo "=== case 6: nothing remembered -> found in a second Steam library listed in libraryfolders.vdf ==="
rm -rf "${SCRATCH}/home"
mkdir -p "${SCRATCH}/home/.local/share/Steam/steamapps"
make_doom3 "${SCRATCH}/SteamLib2/steamapps/common/Doom 3"
cat >"${SCRATCH}/home/.local/share/Steam/steamapps/libraryfolders.vdf" <<EOF
"libraryfolders"
{
	"0"
	{
		"path"		"${SCRATCH}/home/.local/share/Steam"
	}
	"1"
	{
		"path"		"${SCRATCH}/SteamLib2"
	}
}
EOF
launch
check "exit 0, found in the second library" '[ "$CODE" -eq 0 ] && [ "$(readlink "$(arg_after fs_cdpath)/base")" = "${SCRATCH}/SteamLib2/steamapps/common/Doom 3/base" ]'

APPIMAGE="${CHEXTREK_APPIMAGE:-${REPO_ROOT}/dist/ChexTrek-x86_64.AppImage}"
if [ -x "$APPIMAGE" ]; then
	echo "=== case 7: the packaged AppImage itself, no Doom 3 anywhere -> the same one clear line, exit 2 ==="
	rm -rf "${SCRATCH}/home"
	mkdir -p "${SCRATCH}/home"
	LAUNCHER="$APPIMAGE" launch
	check "exits 2" '[ "$CODE" -eq 2 ]'
	check "the line says what to pass" 'printf "%s" "$OUT" | grep -qxF "chextrek: classic Doom 3 not found - run with --doom3 /path/to/Doom3 (the folder containing base/pak000.pk4), or set CHEXTREK_DOOM3_DIR."'
else
	echo "SKIP: case 7 - no packaged AppImage at ${APPIMAGE} (bash tools/package-linux.sh builds it)"
fi

echo
if [ $FAIL -eq 0 ]; then
	echo "PASS: AppImage launcher self-test"
	exit 0
else
	echo "FAIL: AppImage launcher self-test - see above"
	exit 1
fi
