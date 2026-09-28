#!/usr/bin/env bash
# Fetch-and-play (spec #58/#69): the owner's one command, run in Git Bash on the Windows PC from
# the checkout the Doom 3\chextrek symlink points at, to play the latest green Unicron-built
# chextrek.dll. This is spec #58's final piece and its final acceptance check: "the owner plays it
# and confirms it's the Unicron-built DLL" - only the owner, on real Windows, can actually do that
# (see tools/test-fetch-and-play.sh's header for what this self-test proves instead).
#
# 1. Refuses on a dirty working tree, before anything else - fetch-and-play never destroys local
#    work. This is also #70's own acceptance criterion ("refuses to touch a dirty tree"), which #69
#    ships and proves here (tools/test-fetch-and-play.sh's dirty-tree case) rather than leaving it
#    for #70 - shipping this command without it in the meantime would mean every run silently
#    discarded whatever the owner had checked out and hadn't committed yet, which is actively
#    unsafe, not just incomplete. #70's own job on top of this is the commit argument (play/bisect
#    a specific release, not just Latest), not implemented here.
# 2. Resolves the release marked Latest (`gh release view`, no tag - the newest non-draft,
#    non-prerelease release; spec #66's pipeline always marks a green release Latest) and confirms
#    both `chextrek.dll` and `chextrek.pdb` are attached, before touching HEAD at all.
# 3. Checks the engine (`dhewm3.exe`) is actually installed, and downloads `chextrek.dll` +
#    `chextrek.pdb` from that release into a scratch directory (not the checkout root yet) -
#    everything that can still fail here does, before HEAD ever moves.
# 4. Fetches and checks out that release's target commit, detached, so mod data (maps/scripts/defs)
#    matches the DLL about to be played.
# 5. Moves the already-downloaded DLL/PDB into the checkout root and points the `chextrek` mount at
#    this checkout (`tools/lib-harness.sh`'s `chextrek_ensure_mount` - the same mount every harness
#    run uses), then launches dhewm3 with `+set fs_gameDllPath` pointed at this checkout, the same
#    basepath/engine conventions as `tools/run-harness.sh` - but interactively: no console script,
#    no timeout. The owner plays until they quit.
#
# This order means every refusal up through and including step 4 (checkout) leaves the working
# tree, HEAD, and chextrek.dll/chextrek.pdb exactly as they were - see "Exit status" below for the
# one narrow exception (moving the already-downloaded files into place, or pointing the mount,
# after HEAD has already moved).
#
# Usage: tools/fetch-and-play.sh
#
# Exit status:
#   0 - dhewm3 was launched. Once launched, this script's own exit status is whatever dhewm3 itself
#       (a real, interactive process, not a pass/fail check) exits with - not necessarily 0.
#   1 - refused before ever launching anything. In every case except the one below, the working
#       tree, HEAD, and chextrek.dll/chextrek.pdb are all left exactly as they were: a dirty working
#       tree, no Latest release (or one missing an asset), a missing gh/dhewm3.exe, a git/gh
#       failure, or the checkout itself failing. The one exception: once HEAD has moved to the
#       release's target commit, a failure moving the already-downloaded chextrek.dll/chextrek.pdb
#       into the checkout root, or pointing the mount, can leave HEAD at that commit with the DLL/
#       PDB only partially in place (e.g. the disk fills up between the two files) or the mount
#       unchanged, and dhewm3 was never launched - the error message says so explicitly, and names
#       exactly what state each file/HEAD is in, whenever this happens.
#
# Injectable for tools/test-fetch-and-play.sh (never point these at the real repo/game on Unicron -
# see that script's own header):
#   CHEXTREK_FETCH_REPO - owner/repo for every `gh` call (default: parsed from this checkout's own
#                         `origin` remote via chextrek_parse_github_repo, tools/lib-harness.sh).
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=tools/lib-harness.sh
source "${SCRIPT_DIR}/lib-harness.sh"

usage() {
	echo "Usage: tools/fetch-and-play.sh" >&2
}

if [ $# -ne 0 ]; then
	usage
	exit 1
fi

# --- refuse on a dirty tree first, before anything else touches this checkout (see header) ---
GIT_STATUS_OUT="$(git -C "$REPO_ROOT" status --porcelain 2>&1)"
GIT_STATUS_RC=$?
if [ $GIT_STATUS_RC -ne 0 ]; then
	echo "error: 'git status' failed in ${REPO_ROOT}: ${GIT_STATUS_OUT}" >&2
	exit 1
fi
if [ -n "$GIT_STATUS_OUT" ]; then
	echo "error: ${REPO_ROOT} has uncommitted changes - refusing to touch it. Commit, stash, or discard them first, then re-run." >&2
	exit 1
fi

# --- repo: explicit override for tests, else parsed from this checkout's own origin remote ---
if [ -n "${CHEXTREK_FETCH_REPO:-}" ]; then
	REPO="$CHEXTREK_FETCH_REPO"
else
	REMOTE_URL="$(git -C "$REPO_ROOT" remote get-url origin 2>/dev/null)"
	if [ -z "$REMOTE_URL" ]; then
		echo "error: no 'origin' remote in ${REPO_ROOT} and CHEXTREK_FETCH_REPO isn't set" >&2
		exit 1
	fi
	REPO="$(chextrek_parse_github_repo "$REMOTE_URL")"
fi

if ! command -v gh >/dev/null 2>&1; then
	echo "error: gh not found on PATH" >&2
	exit 1
fi

# --- engine home / basepath: same defaults and override env vars as tools/lib-harness.sh (see
# docs/dev-setup.md); check the engine is actually installed now, before touching HEAD ---
chextrek_apply_engine_defaults
DHEWM3_EXE="${DHEWM3_HOME}/dhewm3.exe"
if [ ! -f "$DHEWM3_EXE" ]; then
	echo "error: dhewm3.exe not found at ${DHEWM3_EXE}. See docs/dev-setup.md (DHEWM3_HOME)." >&2
	exit 1
fi

# --- resolve the Latest release: tag, target commit and asset names in one call, using gh's own
# built-in --jq (gh vendors its own JSON query engine - no external jq needed on the owner's
# machine). \x1f (a control character no asset filename or commit sha can contain) separates the
# three fields so a comma-joined asset-name list can never be mistaken for a field boundary. ---
RELEASE_OUT="$(gh release view --repo "$REPO" --json tagName,targetCommitish,assets \
	--jq '[.tagName, .targetCommitish, ([.assets[].name] | join(","))] | join("\u001f")' 2>&1)"
RELEASE_RC=$?
if [ $RELEASE_RC -ne 0 ]; then
	echo "error: no Latest release found on ${REPO} (gh release view failed): ${RELEASE_OUT}" >&2
	exit 1
fi
IFS=$'\x1f' read -r TAG TARGET ASSET_NAMES <<<"$RELEASE_OUT"
if [ -z "$TAG" ] || [ -z "$TARGET" ]; then
	echo "error: couldn't parse a tag/target commit from the Latest release on ${REPO}: ${RELEASE_OUT}" >&2
	exit 1
fi
for ASSET in chextrek.dll chextrek.pdb; do
	case ",${ASSET_NAMES}," in
	*",${ASSET},"*) ;;
	*)
		echo "error: the Latest release (${TAG} on ${REPO}) has no ${ASSET} asset - assets: ${ASSET_NAMES:-<none>}" >&2
		exit 1
		;;
	esac
done
echo "==> Latest release: ${TAG} (target ${TARGET})"

# --- download the DLL/PDB into a scratch directory first, not the checkout root - so a download
# failure (network, a missing/renamed asset server-side) leaves HEAD and the checkout untouched.
# They're moved into the checkout root only after the checkout below succeeds. ---
DOWNLOAD_DIR="$(mktemp -d "${TMPDIR:-/tmp}/chextrek-fetch-and-play.XXXXXX")"
if [ -z "$DOWNLOAD_DIR" ] || [ ! -d "$DOWNLOAD_DIR" ]; then
	echo "error: couldn't create a scratch download directory (mktemp failed). Nothing was checked out or launched." >&2
	exit 1
fi
cleanup_download_dir() { rm -rf "$DOWNLOAD_DIR"; }
trap cleanup_download_dir EXIT
if ! gh release download "$TAG" --repo "$REPO" --dir "$DOWNLOAD_DIR" --clobber \
	--pattern "chextrek.dll" --pattern "chextrek.pdb" >/dev/null 2>&1; then
	echo "error: 'gh release download ${TAG}' failed - chextrek.dll/chextrek.pdb weren't fetched. Nothing was checked out or launched." >&2
	exit 1
fi
if [ ! -f "${DOWNLOAD_DIR}/chextrek.dll" ] || [ ! -f "${DOWNLOAD_DIR}/chextrek.pdb" ]; then
	echo "error: ${TAG}'s download reported success but chextrek.dll and/or chextrek.pdb are missing. Nothing was checked out or launched." >&2
	exit 1
fi
echo "==> Downloaded chextrek.dll + chextrek.pdb from ${TAG}"

# --- fetch and land (detached) on that exact commit, so mod data matches the DLL about to be
# played. A plain `git fetch origin` (not a targeted by-sha fetch): TARGET is always a full sha
# reachable from a branch tip (spec #66 always passes `git rev-parse --verify <ref>^{commit}` to
# `gh release create --target`), so an ordinary fetch of the usual refs already brings it in -
# no dependency on the server allowing an unadvertised-object fetch by sha. ---
if ! git -C "$REPO_ROOT" fetch origin >/dev/null 2>&1; then
	echo "error: 'git fetch origin' failed in ${REPO_ROOT}. Nothing was checked out or launched." >&2
	exit 1
fi
if ! git -C "$REPO_ROOT" rev-parse --verify "${TARGET}^{commit}" >/dev/null 2>&1; then
	echo "error: ${TARGET} (the ${TAG} release's target commit) isn't reachable from ${REPO}'s origin - can't check it out. Nothing was checked out or launched." >&2
	exit 1
fi
if ! git -C "$REPO_ROOT" checkout --detach "$TARGET" >/dev/null 2>&1; then
	echo "error: couldn't check out ${TARGET} (detached) in ${REPO_ROOT}. Nothing was checked out or launched." >&2
	exit 1
fi
echo "==> Checked out ${TARGET} (detached)"

# --- from here on, HEAD has already moved: a failure below leaves it at the release commit even
# though nothing was launched - each message names that explicitly (see "Exit status" above). The
# DLL and PDB are moved one at a time (not a single two-argument `mv`) so a failure between them
# says exactly which file did or didn't make it, instead of leaving that ambiguous. ---
if ! mv -f "${DOWNLOAD_DIR}/chextrek.dll" "${REPO_ROOT}/chextrek.dll" 2>/dev/null; then
	echo "error: couldn't move the downloaded chextrek.dll into ${REPO_ROOT}. HEAD is at ${TARGET}; chextrek.pdb wasn't touched; nothing was launched." >&2
	exit 1
fi
if ! mv -f "${DOWNLOAD_DIR}/chextrek.pdb" "${REPO_ROOT}/chextrek.pdb" 2>/dev/null; then
	echo "error: couldn't move the downloaded chextrek.pdb into ${REPO_ROOT}. HEAD is at ${TARGET}; chextrek.dll is already in place but chextrek.pdb isn't; nothing was launched." >&2
	exit 1
fi
echo "==> chextrek.dll + chextrek.pdb are in ${REPO_ROOT}"
# The scratch download dir is already empty (both files were just moved out of it) - clean it up
# and disarm the EXIT trap now, rather than relying on it: the launch below `exec`s into dhewm3/
# wine on every remaining path, which replaces this process image outright and would never run an
# EXIT trap at all.
cleanup_download_dir
trap - EXIT

if ! chextrek_ensure_mount "$REPO_ROOT"; then
	echo "error: couldn't point the chextrek mount at ${REPO_ROOT} (see above). HEAD is at ${TARGET} and chextrek.dll/chextrek.pdb are already in place; nothing was launched." >&2
	exit 1
fi

FS_BASEPATH="$(chextrek_to_engine_path "$DOOM3_BASEPATH")"
FS_GAMEDLLPATH="$(chextrek_to_engine_path "$REPO_ROOT")"
if [ -z "$FS_BASEPATH" ] || [ -z "$FS_GAMEDLLPATH" ]; then
	echo "error: converting a path for the engine (winepath/cygpath) produced an empty result - DOOM3_BASEPATH=${DOOM3_BASEPATH}, checkout=${REPO_ROOT}. HEAD is at ${TARGET} and chextrek.dll/chextrek.pdb are already in place; nothing was launched." >&2
	exit 1
fi
ENGINE_ARGS=(
	+set fs_basepath "$FS_BASEPATH"
	+set fs_game chextrek
	+set fs_gameDllPath "$FS_GAMEDLLPATH"
)

echo "==> Launching dhewm3 (mod=chextrek, DLL from ${REPO_ROOT})"
echo "==> Once it's running, check its log (dhewm3log.txt - see docs/dev-setup.md's save/config path) for a line like:"
echo "==>   loaded game library '...chextrek.dll'"
echo "==> naming chextrek.dll, not base.dll - that confirms this is the Unicron-built DLL (spec #58's final acceptance check)."
if chextrek_is_linux; then
	# Same reasoning as tools/lib-harness.sh's own Linux launch: cd into the engine's own dir first
	# (it looks for SDL2.dll/OpenAL32.dll next to itself) then exec into wine, so this shell becomes
	# exactly the wine process - nothing to wait on or clean up separately. This is interactive play,
	# not a scenario run: no timeout, no console script, no Xvfb/lock/preflight (those are the
	# harness's, for unattended scenario runs on Unicron - fetch-and-play targets the owner's own,
	# already-logged-in Windows desktop).
	if ! cd "$DHEWM3_HOME"; then
		echo "error: couldn't cd into ${DHEWM3_HOME}. HEAD is at ${TARGET} and chextrek.dll/chextrek.pdb are already in place; nothing was launched." >&2
		exit 1
	fi
	exec wine "$DHEWM3_EXE" "${ENGINE_ARGS[@]}"
else
	exec "$DHEWM3_EXE" "${ENGINE_ARGS[@]}"
fi
