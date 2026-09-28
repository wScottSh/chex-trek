#!/usr/bin/env bash
# Self-test for tools/fetch-and-play.sh (spec #58/#69). This never touches the real
# wScottSh/chex-trek repo, a real `gh`, or a real dhewm3/Wine install, and never launches the real
# game:
#   - a local bare git repo stands in for the real GitHub remote ("origin") - fetch-and-play's own
#     `git fetch`/`git checkout` run for real against it, over a plain filesystem path, so the
#     checkout/detach behavior itself is proven, not stubbed;
#   - a fake `gh` earlier on PATH (repo convention - see tools/test-pipeline-process-commit.sh)
#     answers `gh release view`/`gh release download` from a few env vars, instead of ever reaching
#     github.com;
#   - fake `wine`/`winepath`/`dhewm3.exe` earlier on PATH stand in for the engine: `winepath -w`
#     echoes its argument back unchanged (this self-test only needs to see which path was passed,
#     not a real Windows-style conversion) and `wine` records its full argv to a file and exits at
#     once - so "launched" here means "the engine was invoked with the right arguments", not that
#     any window ever opened.
#
# tools/fetch-and-play.sh's own chextrek_is_linux (tools/lib-harness.sh) branches on the real
# `uname`, not on anything this self-test can override - run on Unicron, this always exercises the
# Linux/Wine launch branch (wine, winepath). It's a no-op on Windows (see below), since there the
# script takes the direct-dhewm3.exe/cygpath branch instead, which this self-test's `wine` stub
# would never see - proving that branch is the "pending owner on Windows" part; see
# docs/dev-setup.md's "Playing the latest green build" section for the exact command and what to
# look for in the engine log.
#
# Covers: a clean tree with a real Latest release lands (detached) on that release's target commit,
# with chextrek.dll/chextrek.pdb downloaded into the checkout root and the mount pointed at it, and
# the engine is launched with fs_basepath/fs_game/fs_gameDllPath naming this checkout; a dirty tree
# refuses before any gh/git-remote call and leaves the tree, HEAD and any prior chextrek.dll
# untouched (also #70's own dirty-tree acceptance criterion - #69 ships and proves the refusal,
# #70's own job is the commit argument); no Latest release (or one missing an asset) refuses with a
# clear message and leaves HEAD untouched; a `gh release download` failure refuses with a clear
# message and leaves HEAD untouched (download happens before checkout); the release's target commit
# not resolving in this checkout refuses with a clear message and leaves HEAD/the checkout root
# untouched; no positional argument is accepted (usage error) - #70's commit argument isn't
# implemented yet.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=tools/lib-harness.sh
source "${SCRIPT_DIR}/lib-harness.sh"
if ! chextrek_is_linux; then
	echo "SKIP: fetch-and-play self-test only exercises the Linux/Wine launch branch on Unicron - see this file's own header"
	exit 0
fi

SCRATCH="$(mktemp -d)"
trap 'rm -rf "$SCRATCH"' EXIT
FAIL=0

pass() { echo "PASS: $*"; }
fail() {
	echo "FAIL: $*"
	FAIL=1
}

# --- fake gh: answers release view/download from a few env vars, never talks to github.com ---
mkdir -p "${SCRATCH}/bin"
cat >"${SCRATCH}/bin/gh" <<'STUBEOF'
#!/usr/bin/env bash
# Test double for gh (tools/test-fetch-and-play.sh). Never talks to github.com.
set -u
CALL_ID="$(date -u +%s%N)-$$-${RANDOM}"
: >"${STUB_GH_ARGV_DIR}/${CALL_ID}.args"
for a in "$@"; do printf '%s\n' "$a" >>"${STUB_GH_ARGV_DIR}/${CALL_ID}.args"; done
printf '%s %s %s\n' "$CALL_ID" "${1:-}" "${2:-}" >>"${STUB_GH_ARGV_LOG}"

if [ "${1:-}" = "release" ] && [ "${2:-}" = "view" ]; then
	if [ "${STUB_GH_NO_RELEASE:-0}" = "1" ]; then
		echo "stub: no releases found" >&2
		exit 1
	fi
	# fetch-and-play.sh's own --jq expression joins tagName/targetCommitish/asset-names with a
	# literal U+001F - this stub reproduces exactly that output rather than interpreting the
	# expression itself, so it never needs a real jq.
	printf '%s\x1f%s\x1f%s\n' "${STUB_GH_TAG}" "${STUB_GH_TARGET}" "${STUB_GH_ASSET_NAMES}"
	exit 0
fi
if [ "${1:-}" = "release" ] && [ "${2:-}" = "download" ]; then
	if [ "${STUB_GH_DOWNLOAD_FAIL:-0}" = "1" ]; then
		echo "stub: simulated download failure" >&2
		exit 1
	fi
	DIR=""
	PREV=""
	for a in "$@"; do
		[ "$PREV" = "--dir" ] && DIR="$a"
		PREV="$a"
	done
	if [ -z "$DIR" ]; then
		echo "stub gh: release download missing --dir" >&2
		exit 1
	fi
	mkdir -p "$DIR"
	printf 'stub-dll\n' >"${DIR}/chextrek.dll"
	printf 'stub-pdb\n' >"${DIR}/chextrek.pdb"
	exit 0
fi
echo "stub gh: unhandled invocation: $*" >&2
exit 1
STUBEOF
chmod +x "${SCRATCH}/bin/gh"

# --- fake wine/winepath/dhewm3.exe: stand in for the engine, never launch anything real ---
mkdir -p "${SCRATCH}/dhewm3-home"
cat >"${SCRATCH}/dhewm3-home/dhewm3.exe" <<'EOF'
#!/usr/bin/env bash
# Never invoked directly by tools/fetch-and-play.sh on the Linux branch (wine is), but must exist
# and be a file so the "dhewm3.exe not found" check passes.
exit 0
EOF
chmod +x "${SCRATCH}/dhewm3-home/dhewm3.exe"
cat >"${SCRATCH}/bin/winepath" <<'EOF'
#!/usr/bin/env bash
# -w PATH -> echoes PATH back unchanged. This self-test only needs to see which path was passed
# through to the engine args, not a real Windows-style conversion.
if [ "${1:-}" = "-w" ]; then
	printf '%s\n' "$2"
else
	printf '%s\n' "$1"
fi
EOF
chmod +x "${SCRATCH}/bin/winepath"
cat >"${SCRATCH}/bin/wine" <<EOF
#!/usr/bin/env bash
# Records this call's full argv (one arg per line) instead of launching anything, and exits at
# once - "launched" in this self-test means "invoked with the right arguments".
: >"${SCRATCH}/wine-invocations/\$\$.args"
for a in "\$@"; do printf '%s\n' "\$a" >>"${SCRATCH}/wine-invocations/\$\$.args"; done
printf '1\n' >>"${SCRATCH}/wine-invoked-count"
exit 0
EOF
chmod +x "${SCRATCH}/bin/wine"
mkdir -p "${SCRATCH}/wine-invocations"
: >"${SCRATCH}/wine-invoked-count"

wine_call_count() {
	wc -l <"${SCRATCH}/wine-invoked-count" | tr -d ' '
}
last_wine_argv() {
	# Every case that calls this clears/recreates ${SCRATCH}/wine-invocations first and expects at
	# most one engine launch, so "the" argv file (not sorted by mtime - avoids relying on `ls -t`
	# for this) is whichever single *.args file the glob below finds.
	local f
	for f in "${SCRATCH}/wine-invocations"/*.args; do
		[ -f "$f" ] && printf '%s\n' "$f"
	done
}

# --- bare "origin" repo standing in for the real GitHub remote ---
BARE="${SCRATCH}/origin.git"
git init -q --bare -b main "$BARE"

SEED="${SCRATCH}/seed"
git init -q -b main "$SEED"
git -C "$SEED" config user.email test@example.invalid
git -C "$SEED" config user.name "Fetch-and-play Test"
mkdir -p "${SEED}/tools"
cp "${SCRIPT_DIR}/fetch-and-play.sh" "${SEED}/tools/fetch-and-play.sh"
cp "${SCRIPT_DIR}/lib-harness.sh" "${SEED}/tools/lib-harness.sh"
# Same as the real repo: the downloaded DLL/PDB are gitignored, never committed - without this, a
# case later in this self-test would find its own checkout "dirty" just because an earlier case's
# download left untracked files sitting there.
printf 'chextrek.dll\nchextrek.pdb\n' >"${SEED}/.gitignore"
git -C "$SEED" add tools/fetch-and-play.sh tools/lib-harness.sh .gitignore
git -C "$SEED" commit -q -m "seed"
git -C "$SEED" remote add origin "$BARE"
git -C "$SEED" push -q origin main

RELEASE_SHA="$(git -C "$SEED" rev-parse HEAD)"

# A later commit on the same branch, so the release's target is an older commit, not the branch
# tip - proves fetch-and-play lands on the *release's* commit, not just "whatever origin/main is".
git -C "$SEED" commit -q --allow-empty -m "a later commit, not part of the release"
git -C "$SEED" push -q origin main
NEWER_SHA="$(git -C "$SEED" rev-parse HEAD)"

# --- the owner's checkout under test: a fresh clone of the bare origin, at the older (release)
# commit already checked out on a branch - so a real run has real work to detach away from ---
CHECKOUT="${SCRATCH}/checkout"
git clone -q "$BARE" "$CHECKOUT"
git -C "$CHECKOUT" config user.email test@example.invalid
git -C "$CHECKOUT" config user.name "Fetch-and-play Test"
git -C "$CHECKOUT" checkout -q "$RELEASE_SHA"
git -C "$CHECKOUT" checkout -q -B main-local

DOOM3_BASEPATH="${SCRATCH}/doom3"
mkdir -p "$DOOM3_BASEPATH"

run_fetch_and_play() {
	# run_fetch_and_play [ARGS...] - fresh gh-argv dirs each call, everything else shared.
	rm -rf "${SCRATCH}/gh-argv.d"
	mkdir -p "${SCRATCH}/gh-argv.d"
	: >"${SCRATCH}/gh-argv.log"
	env -i PATH="${SCRATCH}/bin:${PATH}" HOME="$HOME" \
		STUB_GH_ARGV_DIR="${SCRATCH}/gh-argv.d" \
		STUB_GH_ARGV_LOG="${SCRATCH}/gh-argv.log" \
		STUB_GH_TAG="${STUB_GH_TAG:-win-0000000000}" \
		STUB_GH_TARGET="${STUB_GH_TARGET:-$RELEASE_SHA}" \
		STUB_GH_ASSET_NAMES="${STUB_GH_ASSET_NAMES:-chextrek.dll,chextrek.pdb}" \
		STUB_GH_NO_RELEASE="${STUB_GH_NO_RELEASE:-0}" \
		STUB_GH_DOWNLOAD_FAIL="${STUB_GH_DOWNLOAD_FAIL:-0}" \
		DHEWM3_HOME="${SCRATCH}/dhewm3-home" \
		DOOM3_BASEPATH="$DOOM3_BASEPATH" \
		bash "${CHECKOUT}/tools/fetch-and-play.sh" "$@"
}

echo "=== case 1: clean tree, a real Latest release -> lands detached on the release commit, downloads both assets, mounts, launches ==="
: >"${SCRATCH}/wine-invoked-count"
rm -rf "${SCRATCH}/wine-invocations"
mkdir -p "${SCRATCH}/wine-invocations"
OUT1="$(STUB_GH_TAG="win-1234567890" STUB_GH_TARGET="$RELEASE_SHA" STUB_GH_ASSET_NAMES="chextrek.dll,chextrek.pdb" \
	run_fetch_and_play 2>&1)"
CODE1=$?
if [ $CODE1 -eq 0 ]; then pass "exits 0 on a clean tree with a real Latest release"; else fail "exit code $CODE1, want 0"; echo "$OUT1"; fi
CUR_SHA="$(git -C "$CHECKOUT" rev-parse HEAD)"
if [ "$CUR_SHA" = "$RELEASE_SHA" ]; then pass "HEAD is at the release's target commit"; else fail "HEAD is ${CUR_SHA}, want the release commit ${RELEASE_SHA}"; fi
if [ "$(git -C "$CHECKOUT" symbolic-ref -q HEAD)" ]; then fail "HEAD is still on a branch - expected detached"; else pass "HEAD is detached"; fi
if [ -f "${CHECKOUT}/chextrek.dll" ] && [ -f "${CHECKOUT}/chextrek.pdb" ]; then pass "chextrek.dll and chextrek.pdb were downloaded into the checkout root"; else fail "chextrek.dll/chextrek.pdb missing from ${CHECKOUT}"; fi
if [ -L "${DOOM3_BASEPATH}/chextrek" ] && [ "$(readlink "${DOOM3_BASEPATH}/chextrek")" = "$(cd "$CHECKOUT" && pwd -P)" ]; then
	pass "the chextrek mount points at this checkout"
else
	fail "the chextrek mount doesn't point at ${CHECKOUT}"
fi
if [ "$(wine_call_count)" = "1" ]; then pass "the engine was launched exactly once"; else fail "expected exactly one engine launch, found $(wine_call_count)"; fi
ARGF="$(last_wine_argv)"
if [ -n "$ARGF" ] && grep -qF "$(cd "$CHECKOUT" && pwd -P)" "$ARGF"; then
	pass "fs_gameDllPath/fs_basepath in the launch argv name this checkout"
else
	fail "expected the launch argv to name ${CHECKOUT}"
	[ -n "$ARGF" ] && cat "$ARGF"
fi
if [ -n "$ARGF" ] && grep -qxF "fs_game" "$ARGF" && grep -qxF "chextrek" "$ARGF"; then
	pass "fs_game is set to chextrek"
else
	fail "expected fs_game chextrek in the launch argv"
	[ -n "$ARGF" ] && cat "$ARGF"
fi

echo
echo "=== case 2: a dirty tree refuses before any gh/git-remote call, and changes nothing ==="
git -C "$CHECKOUT" checkout -q main-local
PRE_DIRTY_SHA="$(git -C "$CHECKOUT" rev-parse HEAD)"
PRE_DIRTY_WINE_COUNT="$(wine_call_count)"
echo "local uncommitted change" >"${CHECKOUT}/dirty-marker.txt"
rm -f "${CHECKOUT}/chextrek.dll" "${CHECKOUT}/chextrek.pdb"
OUT2="$(run_fetch_and_play 2>&1)"
CODE2=$?
if [ $CODE2 -ne 0 ]; then pass "exits non-zero on a dirty tree"; else fail "exit code 0 on a dirty tree, want non-zero"; fi
if echo "$OUT2" | grep -qi "uncommitted"; then pass "reports the uncommitted-changes reason clearly"; else fail "expected a clear 'uncommitted changes' message"; echo "$OUT2"; fi
POST_DIRTY_SHA="$(git -C "$CHECKOUT" rev-parse HEAD)"
if [ "$POST_DIRTY_SHA" = "$PRE_DIRTY_SHA" ]; then pass "HEAD unchanged on a dirty tree"; else fail "HEAD moved from ${PRE_DIRTY_SHA} to ${POST_DIRTY_SHA} despite the dirty tree"; fi
if [ -f "${CHECKOUT}/dirty-marker.txt" ]; then pass "the uncommitted local file is still there"; else fail "the uncommitted local file was removed"; fi
if [ -f "${CHECKOUT}/chextrek.dll" ] || [ -f "${CHECKOUT}/chextrek.pdb" ]; then fail "a DLL/PDB was downloaded despite the dirty tree"; else pass "no DLL/PDB was downloaded"; fi
if [ -s "${SCRATCH}/gh-argv.log" ]; then fail "gh was called despite the dirty tree - the dirty check must run first"; else pass "gh was never called - the dirty-tree check ran before any gh call"; fi
if [ "$(wine_call_count)" = "$PRE_DIRTY_WINE_COUNT" ]; then pass "the engine was never launched on a dirty tree"; else fail "the engine was launched despite the dirty tree"; fi
rm -f "${CHECKOUT}/dirty-marker.txt"

echo
echo "=== case 3: no Latest release -> refuses with a clear message, HEAD unchanged ==="
git -C "$CHECKOUT" checkout -q "$NEWER_SHA"
PRE_NOREL_SHA="$(git -C "$CHECKOUT" rev-parse HEAD)"
PRE_NOREL_WINE_COUNT="$(wine_call_count)"
OUT3="$(STUB_GH_NO_RELEASE=1 run_fetch_and_play 2>&1)"
CODE3=$?
if [ $CODE3 -ne 0 ]; then pass "exits non-zero when there's no Latest release"; else fail "exit code 0, want non-zero"; fi
if echo "$OUT3" | grep -qi "no Latest release"; then pass "names the reason: no Latest release"; else fail "expected a 'no Latest release' message"; echo "$OUT3"; fi
POST_NOREL_SHA="$(git -C "$CHECKOUT" rev-parse HEAD)"
if [ "$POST_NOREL_SHA" = "$PRE_NOREL_SHA" ]; then pass "HEAD unchanged when there's no Latest release"; else fail "HEAD moved despite no Latest release"; fi
if [ "$(wine_call_count)" = "$PRE_NOREL_WINE_COUNT" ]; then pass "the engine was never launched"; else fail "the engine was launched despite no Latest release"; fi

echo
echo "=== case 3b: a Latest release missing the chextrek.pdb asset -> refuses with a clear message, HEAD unchanged ==="
PRE_MISSING_SHA="$(git -C "$CHECKOUT" rev-parse HEAD)"
OUT3B="$(STUB_GH_TAG="win-missingasset" STUB_GH_TARGET="$RELEASE_SHA" STUB_GH_ASSET_NAMES="chextrek.dll" run_fetch_and_play 2>&1)"
CODE3B=$?
if [ $CODE3B -ne 0 ]; then pass "exits non-zero when the release is missing chextrek.pdb"; else fail "exit code 0, want non-zero"; fi
if echo "$OUT3B" | grep -qF "chextrek.pdb"; then pass "names the missing asset"; else fail "expected the message to name chextrek.pdb"; echo "$OUT3B"; fi
POST_MISSING_SHA="$(git -C "$CHECKOUT" rev-parse HEAD)"
if [ "$POST_MISSING_SHA" = "$PRE_MISSING_SHA" ]; then pass "HEAD unchanged when an asset is missing"; else fail "HEAD moved despite the missing asset"; fi

echo
echo "=== case 4: gh release download fails -> refuses with a clear message, HEAD unchanged (download happens before checkout) ==="
rm -f "${CHECKOUT}/chextrek.dll" "${CHECKOUT}/chextrek.pdb"
PRE_DLFAIL_SHA="$(git -C "$CHECKOUT" rev-parse HEAD)"
OUT4="$(STUB_GH_TAG="win-dlfail" STUB_GH_TARGET="$RELEASE_SHA" STUB_GH_DOWNLOAD_FAIL=1 run_fetch_and_play 2>&1)"
CODE4=$?
if [ $CODE4 -ne 0 ]; then pass "exits non-zero when gh release download fails"; else fail "exit code 0, want non-zero"; fi
if echo "$OUT4" | grep -qi "release download"; then pass "names the reason: the download failed"; else fail "expected a message naming the failed download"; echo "$OUT4"; fi
if [ -f "${CHECKOUT}/chextrek.dll" ] || [ -f "${CHECKOUT}/chextrek.pdb" ]; then fail "a DLL/PDB exists despite the simulated download failure"; else pass "no DLL/PDB left behind by the failed download"; fi
POST_DLFAIL_SHA="$(git -C "$CHECKOUT" rev-parse HEAD)"
if [ "$POST_DLFAIL_SHA" = "$PRE_DLFAIL_SHA" ]; then pass "HEAD unchanged when the download fails (download happens before checkout)"; else fail "HEAD moved despite the failed download"; fi

echo
echo "=== case 4b: gh release download succeeds but the release's target commit doesn't resolve in this checkout (bad target) -> refuses before checkout, HEAD unchanged, no DLL/PDB left in the checkout root ==="
# The download-before-checkout ordering means this download itself succeeds (the stub gh doesn't
# care what STUB_GH_TARGET is) - it's the *next* step, resolving TARGET as a real commit in this
# checkout (the `git rev-parse --verify ...^{commit}` guard, before `git checkout` is ever called),
# that fails here. This is deliberately a 40-hex-digit sha that was never pushed to $BARE, not a
# malformed one, so it's this reachability check that fails, not argument parsing.
PRE_BADTARGET_SHA="$(git -C "$CHECKOUT" rev-parse HEAD)"
OUT4B="$(STUB_GH_TAG="win-badtarget" STUB_GH_TARGET="000000000000000000000000000000000000dead" run_fetch_and_play 2>&1)"
CODE4B=$?
if [ $CODE4B -ne 0 ]; then pass "exits non-zero when the release's target commit isn't reachable"; else fail "exit code 0, want non-zero"; fi
if echo "$OUT4B" | grep -qi "isn't reachable"; then pass "names the reason: the target commit isn't reachable"; else fail "expected an 'isn't reachable' message"; echo "$OUT4B"; fi
POST_BADTARGET_SHA="$(git -C "$CHECKOUT" rev-parse HEAD)"
if [ "$POST_BADTARGET_SHA" = "$PRE_BADTARGET_SHA" ]; then pass "HEAD unchanged when the target commit doesn't resolve"; else fail "HEAD moved despite the target commit not resolving"; fi
if [ -f "${CHECKOUT}/chextrek.dll" ] || [ -f "${CHECKOUT}/chextrek.pdb" ]; then fail "a DLL/PDB was left in the checkout root despite never checking out"; else pass "no DLL/PDB left in the checkout root - the scratch download dir, not the checkout root, held them"; fi

echo
echo "=== case 5: a positional argument is rejected (usage error) - #70's commit argument isn't implemented here ==="
OUT5="$(run_fetch_and_play deadbeef 2>&1)"
CODE5=$?
if [ $CODE5 -ne 0 ]; then pass "exits non-zero when given an argument"; else fail "exit code 0 with an argument, want non-zero"; fi
if echo "$OUT5" | grep -qi "usage"; then pass "prints a usage message"; else fail "expected a usage message"; echo "$OUT5"; fi

echo
if [ $FAIL -eq 0 ]; then
	echo "PASS: whole self-test"
	exit 0
else
	echo "FAIL: whole self-test - see above"
	exit 1
fi
