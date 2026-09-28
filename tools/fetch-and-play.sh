#!/usr/bin/env bash
# Fetch-and-play (spec #58/#69/#70): the owner's one command, run in Git Bash on the Windows PC
# from the checkout the Doom 3\chextrek symlink points at, to play a green Unicron-built
# chextrek.dll - the latest one by default, or (#70) an older one to play/bisect a specific
# release. This is spec #58's final piece and its final acceptance check: "the owner plays it and
# confirms it's the Unicron-built DLL" - only the owner, on real Windows, can actually do that (see
# tools/test-fetch-and-play.sh's header for what this self-test proves instead).
#
# 1. Refuses on a dirty working tree, before anything else - fetch-and-play never destroys local
#    work. This is also #70's own acceptance criterion ("refuses to touch a dirty tree"), which #69
#    ships and proves here (tools/test-fetch-and-play.sh's dirty-tree case).
# 2. Checks the engine (`dhewm3.exe`) is actually installed. Then resolves which release to play:
#      - no argument: the release marked Latest (`gh release view`, no tag - the newest non-draft,
#        non-prerelease release; spec #66's pipeline always marks a green release Latest).
#      - a commit argument (#70): fetches origin (so a commit only just released is locally known),
#        resolves it to a full 40-hex sha (`git rev-parse --verify <commit-ish>^{commit}`), derives
#        that commit's own release tag (`win-<10-char short sha>`, the exact scheme spec #66's
#        pipeline uses - tools/pipeline-process-commit.sh), looks that release up by tag, and
#        confirms its targetCommitish is exactly the resolved sha (never trusts the tag alone - a
#        renamed/retargeted release would otherwise play the wrong commit's DLL against this
#        commit's mod data). No release for that commit fails clearly, naming the commit, with HEAD
#        untouched - this is #70's own "no release" acceptance criterion.
#    Either way, confirms both `chextrek.dll` and `chextrek.pdb` are attached to the resolved
#    release - all before touching HEAD at all.
# 3. Downloads `chextrek.dll` + `chextrek.pdb` from that release into a scratch directory (not the
#    checkout root yet) - everything that can still fail here does, before HEAD ever moves.
# 4. Checks out that release's target commit, detached, so mod data (maps/scripts/defs) matches the
#    DLL about to be played.
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
# Self-rewrite hazard (#70, flagged in #69's review): step 4's `git checkout --detach` can rewrite
# this very file, tools/fetch-and-play.sh, on disk while bash is still executing it (a checkout of
# any commit whose tools/fetch-and-play.sh differs from the one currently running does this every
# time, not just occasionally). bash normally reads a plain script incrementally, off disk, as it
# runs each command - so a rewrite mid-run is a real hazard: on Git for Windows this is reported to
# surface as "Unlink of file ... failed", and more generally, if the file's bytes on disk change out
# from under bash's read, bash can resume reading from the old byte offset into whatever new bytes
# now sit there and execute garbage. This script's whole body below is wrapped in one
# `main() { ...; }` function, called only at the very end (`main "$@"`). A function body is a single
# parse unit: bash must read all the way through main's closing `}` before it can execute anything
# inside it, so by the time `git checkout` ever runs, this entire script (including everything after
# the checkout) is already fully parsed and held in memory - nothing past that point is ever read
# from disk again, checkout or not. This directly closes the "resume reading into new/garbage bytes"
# failure mode. It does NOT touch a separate possible failure mode - `git checkout` itself refusing
# to replace an open file on Windows (an "Unlink of file ... failed" abort, which would be a git/
# filesystem-level failure, not a bash-parsing one) - that's unverified here (see "Exit status"
# below for how such a checkout failure is still handled safely either way: this script always
# checks the checkout's own exit status and refuses cleanly if it fails, rather than assuming it
# succeeded). (Re-executing from a self-copy, or a temp-file copy guarded by an env var, would also
# work for the parsing hazard, but both add a process spawn or an extra file on *every* run for a
# hazard this fully covers for free.) tools/test-fetch-and-play.sh's "self-rewriting checkout" case
# proves the parsing hazard directly: a `git` wrapper simulates the exact race (an in-place,
# same-inode overwrite of the running script's *not-yet-read* remainder - specifically injecting an
# `exit 91` right after the checkout line that only exists in the on-disk bytes, not in whatever
# bash already has buffered - the way a real concurrent replace would look to bash's already-open
# read handle) and the run still completes correctly (exit 0, engine launched) using the original,
# already-parsed script. This is a real mutation-tested guarantee, not just a plausible-looking
# assertion: with the `main()` wrap temporarily removed, this same case genuinely fails (exit 91,
# no engine launch) - confirmed directly while writing this fix, in this exact environment (a
# plain, unguarded Linux `git checkout` of a changed tracked file replaces it via unlink+recreate,
# which bash's open read handle on the old, now-unlinked inode never observes on its own - so this
# case's `git` wrapper performs the same-inode overwrite itself, rather than relying on a plain
# checkout to reproduce it).
#
# Usage: tools/fetch-and-play.sh [COMMIT]
#   COMMIT - a commit-ish with a green release; plays/bisects that build instead of Latest.
#
# Exit status:
#   0 - dhewm3 was launched. Once launched, this script's own exit status is whatever dhewm3 itself
#       (a real, interactive process, not a pass/fail check) exits with - not necessarily 0.
#   1 - refused before ever launching anything. Up through and including everything before the
#       checkout itself (a dirty working tree, COMMIT not resolving to a commit, no release for
#       COMMIT (or no Latest release), a release whose target doesn't match the resolved commit, one
#       missing an asset, a missing gh/dhewm3.exe, or a git/gh failure), the working tree, HEAD, and
#       chextrek.dll/chextrek.pdb are all left exactly as they were. The checkout itself failing is
#       the one case in this group without that guarantee: ordinarily a refused checkout (e.g. one
#       that would overwrite local changes) also leaves the tree/HEAD untouched, but a checkout that
#       fails partway through (e.g. a file-replace failure) can leave both partially updated - that
#       error message says to check 'git status'/'git rev-parse HEAD' rather than assuming either is
#       unchanged. Every failure *after* the checkout succeeds (moving the already-downloaded DLL/PDB
#       into place, pointing the mount, converting a path for the engine, or launching it) can leave
#       HEAD at the release's target commit with the DLL/PDB, the mount, or both only partially
#       updated, and dhewm3 never launched - each of those error messages says exactly what state
#       HEAD and the DLL/PDB are left in.
#
# Injectable for tools/test-fetch-and-play.sh (never point these at the real repo/game on Unicron -
# see that script's own header):
#   CHEXTREK_FETCH_REPO - owner/repo for every `gh` call (default: parsed from this checkout's own
#                         `origin` remote via chextrek_parse_github_repo, tools/lib-harness.sh).
set -uo pipefail

main() {
	SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
	REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
	# shellcheck source=tools/lib-harness.sh
	source "${SCRIPT_DIR}/lib-harness.sh"

	if [ $# -gt 1 ]; then
		usage
		exit 1
	fi
	# An explicitly-given empty string ($# -eq 1, "$1" empty) is also a usage error, not "no
	# argument" - silently falling through to the Latest path there would be surprising.
	if [ $# -eq 1 ] && [ -z "$1" ]; then
		usage
		exit 1
	fi
	COMMIT_ARG="${1:-}"

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

	if [ -n "$COMMIT_ARG" ]; then
		# --- #70: a specific commit. Fetch origin first (COMMIT_ARG may name a commit this checkout
		# has never heard of yet - e.g. one only just released), then resolve it to a full sha before
		# doing anything else with it: every later step (the release tag, the "target matches" check,
		# the checkout itself) depends on having the *one* exact commit the owner meant, not a
		# possibly-ambiguous short form. ---
		FETCH_OUT="$(git -C "$REPO_ROOT" fetch origin 2>&1)"
		if [ $? -ne 0 ]; then
			echo "error: 'git fetch origin' failed in ${REPO_ROOT}: ${FETCH_OUT}. Nothing was checked out or launched." >&2
			exit 1
		fi
		RESOLVE_OUT="$(git -C "$REPO_ROOT" rev-parse --verify "${COMMIT_ARG}^{commit}" 2>&1)"
		RESOLVE_RC=$?
		FULL_SHA="$RESOLVE_OUT"
		if [ $RESOLVE_RC -ne 0 ] || [ -z "$FULL_SHA" ]; then
			echo "error: '${COMMIT_ARG}' doesn't resolve to a single commit in ${REPO_ROOT} (even after 'git fetch origin'): ${RESOLVE_OUT}. Nothing was checked out or launched." >&2
			exit 1
		fi
		# Same fixed length as tools/pipeline-process-commit.sh's own tag scheme (spec #66) - a
		# release is always tagged win-<10-char short sha> of the exact commit it targets.
		SHORT_SHA="$(git -C "$REPO_ROOT" rev-parse --short=10 "$FULL_SHA")"
		TAG="win-${SHORT_SHA}"
		RELEASE_OUT="$(gh release view "$TAG" --repo "$REPO" --json tagName,targetCommitish,assets \
			--jq '[.tagName, .targetCommitish, ([.assets[].name] | join(","))] | join("\u001f")' 2>&1)"
		RELEASE_RC=$?
		if [ $RELEASE_RC -ne 0 ]; then
			echo "error: no release for commit ${COMMIT_ARG} (resolved to ${FULL_SHA}, looked up as ${TAG} on ${REPO} - gh release view failed): ${RELEASE_OUT}. Nothing was checked out or launched." >&2
			exit 1
		fi
	else
		# --- no argument: resolve the Latest release: tag, target commit and asset names in one
		# call, using gh's own built-in --jq (gh vendors its own JSON query engine - no external jq
		# needed on the owner's machine). \x1f (a control character no asset filename or commit sha
		# can contain) separates the three fields so a comma-joined asset-name list can never be
		# mistaken for a field boundary. ---
		RELEASE_OUT="$(gh release view --repo "$REPO" --json tagName,targetCommitish,assets \
			--jq '[.tagName, .targetCommitish, ([.assets[].name] | join(","))] | join("\u001f")' 2>&1)"
		RELEASE_RC=$?
		if [ $RELEASE_RC -ne 0 ]; then
			echo "error: no Latest release found on ${REPO} (gh release view failed): ${RELEASE_OUT}" >&2
			exit 1
		fi
	fi
	IFS=$'\x1f' read -r TAG TARGET ASSET_NAMES <<<"$RELEASE_OUT"
	if [ -z "$TAG" ] || [ -z "$TARGET" ]; then
		echo "error: couldn't parse a tag/target commit from the release on ${REPO}: ${RELEASE_OUT}" >&2
		exit 1
	fi
	if [ -n "$COMMIT_ARG" ] && [ "$TARGET" != "$FULL_SHA" ]; then
		echo "error: release ${TAG} on ${REPO} targets ${TARGET}, not the resolved commit ${FULL_SHA} - refusing (its DLL wouldn't match this commit's mod data). Nothing was checked out or launched." >&2
		exit 1
	fi
	for ASSET in chextrek.dll chextrek.pdb; do
		case ",${ASSET_NAMES}," in
		*",${ASSET},"*) ;;
		*)
			echo "error: the release (${TAG} on ${REPO}) has no ${ASSET} asset - assets: ${ASSET_NAMES:-<none>}" >&2
			exit 1
			;;
		esac
	done
	echo "==> Release: ${TAG} (target ${TARGET})"

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
	DOWNLOAD_OUT="$(gh release download "$TAG" --repo "$REPO" --dir "$DOWNLOAD_DIR" --clobber \
		--pattern "chextrek.dll" --pattern "chextrek.pdb" 2>&1)"
	if [ $? -ne 0 ]; then
		echo "error: 'gh release download ${TAG}' failed - chextrek.dll/chextrek.pdb weren't fetched: ${DOWNLOAD_OUT}. Nothing was checked out or launched." >&2
		exit 1
	fi
	if [ ! -f "${DOWNLOAD_DIR}/chextrek.dll" ] || [ ! -f "${DOWNLOAD_DIR}/chextrek.pdb" ]; then
		echo "error: ${TAG}'s download reported success but chextrek.dll and/or chextrek.pdb are missing. Nothing was checked out or launched." >&2
		exit 1
	fi
	echo "==> Downloaded chextrek.dll + chextrek.pdb from ${TAG}"

	# --- fetch (again, harmless if COMMIT_ARG already did) and land (detached) on that exact
	# commit, so mod data matches the DLL about to be played. A plain `git fetch origin` (not a
	# targeted by-sha fetch): TARGET is always a full sha reachable from a branch tip (spec #66
	# always passes `git rev-parse --verify <ref>^{commit}` to `gh release create --target`), so an
	# ordinary fetch of the usual refs already brings it in - no dependency on the server allowing
	# an unadvertised-object fetch by sha. ---
	FETCH_OUT="$(git -C "$REPO_ROOT" fetch origin 2>&1)"
	if [ $? -ne 0 ]; then
		echo "error: 'git fetch origin' failed in ${REPO_ROOT}: ${FETCH_OUT}. Nothing was checked out or launched." >&2
		exit 1
	fi
	if ! git -C "$REPO_ROOT" rev-parse --verify "${TARGET}^{commit}" >/dev/null 2>&1; then
		echo "error: ${TARGET} (the ${TAG} release's target commit) isn't reachable from ${REPO}'s origin - can't check it out. Nothing was checked out or launched." >&2
		exit 1
	fi
	CHECKOUT_OUT="$(git -C "$REPO_ROOT" checkout --detach "$TARGET" 2>&1)"
	if [ $? -ne 0 ]; then
		echo "error: couldn't check out ${TARGET} (detached) in ${REPO_ROOT}: ${CHECKOUT_OUT}. Nothing was launched. In the ordinary case (the checkout was refused outright, e.g. it would overwrite local changes) the working tree and HEAD are untouched; but a checkout that failed partway through (e.g. a file-replace failure) can leave both partially updated - check 'git status' and 'git rev-parse HEAD' in ${REPO_ROOT} before re-running." >&2
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
		echo "error: couldn't point the chextrek mount at ${REPO_ROOT} (see above - it may now be missing rather than pointed anywhere). HEAD is at ${TARGET} and chextrek.dll/chextrek.pdb are already in place; nothing was launched." >&2
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
}

usage() {
	echo "Usage: tools/fetch-and-play.sh [COMMIT]" >&2
}

main "$@"
