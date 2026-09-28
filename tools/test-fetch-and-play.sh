#!/usr/bin/env bash
# Self-test for tools/fetch-and-play.sh (spec #58/#69/#70). This never touches the real
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
# untouched (spec #58/#69's own acceptance criterion, and #70's - a dirty tree is refused whether or
# not a commit argument is given); no Latest release (or one missing an asset) refuses with a clear
# message and leaves HEAD untouched; a `gh release download` failure refuses with a clear message
# and leaves HEAD untouched (download happens before checkout); the release's target commit not
# resolving in this checkout refuses with a clear message and leaves HEAD/the checkout root
# untouched; too many positional arguments is a usage error.
#
# #70's commit argument: given a commit with a green release, it's resolved to a full sha (after a
# `git fetch origin`, so a commit only just released is locally known), the release is looked up by
# that commit's own win-<short sha> tag (spec #66's exact scheme -
# tools/pipeline-process-commit.sh), and its target is confirmed to match that exact sha before
# anything downloads - then it checks out, downloads and launches exactly as the Latest path does; a
# dirty tree refuses before any gh/git-remote call on the commit-arg path too; a commit with no
# release refuses naming the commit, HEAD untouched; a release whose target doesn't match the
# resolved commit refuses naming both, HEAD untouched; a commit whose own tools/fetch-and-play.sh
# differs from the copy currently running (the checkout rewrites this very script mid-run) still
# completes correctly - proving the main()-wrap self-rewrite guard (see fetch-and-play.sh's header);
# and at checkout time no process in the run's ancestry holds the checkout's own
# tools/fetch-and-play.sh open (the temp-copy re-exec guard against Git for Windows' "Unlink of
# file ... failed"), with the temp copy itself already deleted.
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
	# $3, if present and not a flag, is an explicit tag (#70's commit-arg path: `gh release view
	# <tag> --repo ...`). Its absence (next arg starts with "--", or there is no $3) means the
	# no-tag/Latest form fetch-and-play.sh's own no-argument path uses.
	TAG_ARG=""
	case "${3:-}" in
	"" | --*) TAG_ARG="" ;;
	*) TAG_ARG="$3" ;;
	esac
	if [ -z "$TAG_ARG" ]; then
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
	# Explicit-tag lookup (#70's commit-arg path): STUB_GH_RELEASES holds zero or more
	# "TAG<US>TARGET<US>ASSETS" lines (US = the same literal U+001F) - each one release a test case
	# wants `gh release view <tag>` to find. No matching line reproduces a real `gh release view
	# <bad-tag>` failure: no release by that name.
	FOUND=0
	while IFS=$'\x1f' read -r RTAG RTARGET RASSETS; do
		[ -z "$RTAG" ] && continue
		if [ "$RTAG" = "$TAG_ARG" ]; then
			printf '%s\x1f%s\x1f%s\n' "$RTAG" "$RTARGET" "$RASSETS"
			FOUND=1
			break
		fi
	done <<<"${STUB_GH_RELEASES:-}"
	if [ "$FOUND" = "0" ]; then
		echo "stub: release not found: ${TAG_ARG}" >&2
		exit 1
	fi
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

# --- git passthrough shim, used only by cases 10 and 11 below: forwards every call to the real git
# unchanged, EXCEPT when armed. Case 10 arms STUB_GIT_REWRITE_TARGET/STUB_GIT_REWRITE_CONTENT (an
# exact "checkout --detach <STUB_GIT_REWRITE_TARGET>" with "-C <dir>"). Case 11 arms
# STUB_GIT_OPENCHECK_OUT: at any "checkout --detach", before the real checkout, it walks this
# shim's process ancestry (the fetch-and-play run) and records, per ancestor, any open fd on the
# checkout's own tools/fetch-and-play.sh ("OPEN") or on a fetch-and-play temp copy ("COPY").
# For every other case (those env vars unset), this is a pure passthrough - it changes nothing
# about how any other case's real git calls behave. See case 10 below for why this exists: a plain
# Linux `git checkout` replaces a changed tracked file via unlink+recreate (a new inode), which
# bash's already-open read handle on the old (now-unlinked) inode never observes - so it can't
# exercise the same-inode-overwrite hazard fetch-and-play.sh's header describes on its own. This
# shim reproduces that hazard directly instead. ---
REAL_GIT_BIN="$(command -v git)"
cat >"${SCRATCH}/bin/git" <<EOF
#!/usr/bin/env bash
REAL_GIT="${REAL_GIT_BIN}"
DIR=""
DETACH_SHA=""
PREV=""
for a in "\$@"; do
	[ "\$PREV" = "-C" ] && DIR="\$a"
	[ "\$PREV" = "--detach" ] && DETACH_SHA="\$a"
	PREV="\$a"
done
if [ -n "\$DETACH_SHA" ] && [ -n "\${STUB_GIT_OPENCHECK_OUT:-}" ] && [ -n "\$DIR" ]; then
	TARGET_FILE="\$(cd "\$DIR" && pwd -P)/tools/fetch-and-play.sh"
	P="\$PPID"
	# Bounded walk: the run is only a few processes deep (the \$(...) subshell, then the script).
	for _ in 1 2 3 4 5 6 7 8; do
		{ [ -n "\$P" ] && [ "\$P" -gt 1 ]; } || break
		for FD in /proc/"\$P"/fd/*; do
			L="\$(readlink "\$FD" 2>/dev/null)" || continue
			case "\$L" in
			"\$TARGET_FILE" | "\$TARGET_FILE (deleted)") echo "OPEN \$P \$FD \$L" >>"\$STUB_GIT_OPENCHECK_OUT" ;;
			*chextrek-fetch-and-play-self.*) echo "COPY \$P \$FD \$L" >>"\$STUB_GIT_OPENCHECK_OUT" ;;
			esac
		done
		P="\$(awk '{print \$4}' /proc/"\$P"/stat 2>/dev/null)"
	done
	echo "CHECKED" >>"\$STUB_GIT_OPENCHECK_OUT"
fi
if [ -n "\$DETACH_SHA" ] && [ -n "\${STUB_GIT_REWRITE_TARGET:-}" ] && [ "\$DETACH_SHA" = "\${STUB_GIT_REWRITE_TARGET}" ] && [ -n "\$DIR" ] && [ -f "\${STUB_GIT_REWRITE_CONTENT:-}" ]; then
	# Same-inode sabotage: a plain \`>\` redirection to an *existing* file truncates and rewrites
	# it in place (open(2) with O_TRUNC, no unlink/recreate) - exactly what would let a
	# currently-open read handle observe the new bytes mid-read. This intentionally makes the
	# working tree "dirty" from git's point of view (an untracked-looking local change to a
	# tracked file) before the real checkout below runs, so that checkout is forced (-f) - an
	# unguarded real run's own checkout would end up at the same final, correct content for this
	# file regardless of exactly how it got there.
	cat "\${STUB_GIT_REWRITE_CONTENT}" >"\${DIR}/tools/fetch-and-play.sh"
	exec "\$REAL_GIT" -C "\$DIR" checkout -f --detach "\$DETACH_SHA"
fi
exec "\$REAL_GIT" "\$@"
EOF
chmod +x "${SCRATCH}/bin/git"

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

# A commit pushed to $BARE only *after* $CHECKOUT was cloned - $CHECKOUT has never heard of it, so
# landing on it in case 1 below is only possible because fetch-and-play.sh's own `git fetch origin`
# actually ran and actually worked, not because the commit happened to already be local.
LATE_SHA="$(git -C "$SEED" commit -q --allow-empty -m "pushed after \$CHECKOUT was cloned - proves git fetch origin is exercised" && git -C "$SEED" rev-parse HEAD)"
git -C "$SEED" push -q origin main

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
		STUB_GH_RELEASES="${STUB_GH_RELEASES:-}" \
		STUB_GIT_REWRITE_TARGET="${STUB_GIT_REWRITE_TARGET:-}" \
		STUB_GIT_REWRITE_CONTENT="${STUB_GIT_REWRITE_CONTENT:-}" \
		STUB_GIT_OPENCHECK_OUT="${STUB_GIT_OPENCHECK_OUT:-}" \
		${CHEXTREK_FETCH_AND_PLAY_SELF:+CHEXTREK_FETCH_AND_PLAY_SELF="$CHEXTREK_FETCH_AND_PLAY_SELF"} \
		DHEWM3_HOME="${SCRATCH}/dhewm3-home" \
		DOOM3_BASEPATH="$DOOM3_BASEPATH" \
		bash "${CHECKOUT}/tools/fetch-and-play.sh" "$@"
}

echo "=== case 1: clean tree, a real Latest release -> lands detached on the release commit, downloads both assets, mounts, launches ==="
: >"${SCRATCH}/wine-invoked-count"
rm -rf "${SCRATCH}/wine-invocations"
mkdir -p "${SCRATCH}/wine-invocations"
OUT1="$(STUB_GH_TAG="win-1234567890" STUB_GH_TARGET="$LATE_SHA" STUB_GH_ASSET_NAMES="chextrek.dll,chextrek.pdb" \
	run_fetch_and_play 2>&1)"
CODE1=$?
if [ $CODE1 -eq 0 ]; then pass "exits 0 on a clean tree with a real Latest release"; else fail "exit code $CODE1, want 0"; echo "$OUT1"; fi
CUR_SHA="$(git -C "$CHECKOUT" rev-parse HEAD)"
# LATE_SHA (not RELEASE_SHA) was pushed to $BARE only after $CHECKOUT was cloned - landing on it
# here is only possible if fetch-and-play.sh's own `git fetch origin` actually ran and worked.
if [ "$CUR_SHA" = "$LATE_SHA" ]; then pass "HEAD is at the release's target commit (only reachable via this run's own git fetch)"; else fail "HEAD is ${CUR_SHA}, want the release commit ${LATE_SHA}"; fi
if [ "$(git -C "$CHECKOUT" symbolic-ref -q HEAD)" ]; then fail "HEAD is still on a branch - expected detached"; else pass "HEAD is detached"; fi
if [ -f "${CHECKOUT}/chextrek.dll" ] && [ -f "${CHECKOUT}/chextrek.pdb" ]; then pass "chextrek.dll and chextrek.pdb were downloaded into the checkout root"; else fail "chextrek.dll/chextrek.pdb missing from ${CHECKOUT}"; fi
if [ -L "${DOOM3_BASEPATH}/chextrek" ] && [ "$(readlink "${DOOM3_BASEPATH}/chextrek")" = "$(cd "$CHECKOUT" && pwd -P)" ]; then
	pass "the chextrek mount points at this checkout"
else
	fail "the chextrek mount doesn't point at ${CHECKOUT}"
fi
if [ "$(wine_call_count)" = "1" ]; then pass "the engine was launched exactly once"; else fail "expected exactly one engine launch, found $(wine_call_count)"; fi
ARGF="$(last_wine_argv)"
# The stub winepath (-w PATH -> PATH unchanged) means each +set value in ARGF is exactly the raw
# path fetch-and-play.sh passed in, one arg per line - so the value paired with each +set key can
# be checked precisely (which key got which value), not just "this string appears somewhere".
arg_value_after() {
	local KEY="$1" FILE="$2"
	awk -v key="$KEY" '$0==key{getline; print; exit}' "$FILE"
}
CHECKOUT_REAL="$(cd "$CHECKOUT" && pwd -P)"
if [ -n "$ARGF" ] && [ "$(arg_value_after fs_gameDllPath "$ARGF")" = "$CHECKOUT_REAL" ]; then
	pass "fs_gameDllPath is set to this checkout"
else
	fail "expected fs_gameDllPath's value to be ${CHECKOUT_REAL}, got '$([ -n "$ARGF" ] && arg_value_after fs_gameDllPath "$ARGF")'"
	[ -n "$ARGF" ] && cat "$ARGF"
fi
if [ -n "$ARGF" ] && [ "$(arg_value_after fs_basepath "$ARGF")" = "$DOOM3_BASEPATH" ]; then
	pass "fs_basepath is set to DOOM3_BASEPATH (not the checkout)"
else
	fail "expected fs_basepath's value to be ${DOOM3_BASEPATH}, got '$([ -n "$ARGF" ] && arg_value_after fs_basepath "$ARGF")'"
	[ -n "$ARGF" ] && cat "$ARGF"
fi
if [ -n "$ARGF" ] && [ "$(arg_value_after fs_game "$ARGF")" = "chextrek" ]; then
	pass "fs_game is set to chextrek"
else
	fail "expected fs_game's value to be chextrek, got '$([ -n "$ARGF" ] && arg_value_after fs_game "$ARGF")'"
	[ -n "$ARGF" ] && cat "$ARGF"
fi

echo
echo "=== case 2: a dirty tree refuses before any gh/git-remote call, and changes nothing (including a prior chextrek.dll/pdb already sitting there) ==="
git -C "$CHECKOUT" checkout -q main-local
PRE_DIRTY_SHA="$(git -C "$CHECKOUT" rev-parse HEAD)"
PRE_DIRTY_WINE_COUNT="$(wine_call_count)"
echo "local uncommitted change" >"${CHECKOUT}/dirty-marker.txt"
# A prior build's DLL/PDB, gitignored and already sitting in the checkout root (the normal state
# before ever running fetch-and-play) - proves the dirty-tree refusal leaves *these* untouched too,
# not just that it skips downloading new ones.
printf 'prior-dll-content\n' >"${CHECKOUT}/chextrek.dll"
printf 'prior-pdb-content\n' >"${CHECKOUT}/chextrek.pdb"
OUT2="$(run_fetch_and_play 2>&1)"
CODE2=$?
if [ $CODE2 -ne 0 ]; then pass "exits non-zero on a dirty tree"; else fail "exit code 0 on a dirty tree, want non-zero"; fi
if echo "$OUT2" | grep -qi "uncommitted"; then pass "reports the uncommitted-changes reason clearly"; else fail "expected a clear 'uncommitted changes' message"; echo "$OUT2"; fi
POST_DIRTY_SHA="$(git -C "$CHECKOUT" rev-parse HEAD)"
if [ "$POST_DIRTY_SHA" = "$PRE_DIRTY_SHA" ]; then pass "HEAD unchanged on a dirty tree"; else fail "HEAD moved from ${PRE_DIRTY_SHA} to ${POST_DIRTY_SHA} despite the dirty tree"; fi
if [ -f "${CHECKOUT}/dirty-marker.txt" ]; then pass "the uncommitted local file is still there"; else fail "the uncommitted local file was removed"; fi
if [ "$(cat "${CHECKOUT}/chextrek.dll" 2>/dev/null)" = "prior-dll-content" ] && [ "$(cat "${CHECKOUT}/chextrek.pdb" 2>/dev/null)" = "prior-pdb-content" ]; then
	pass "a prior chextrek.dll/chextrek.pdb already in the checkout root are left byte-for-byte untouched"
else
	fail "the prior chextrek.dll/chextrek.pdb were changed or removed despite the dirty tree"
fi
if [ -s "${SCRATCH}/gh-argv.log" ]; then fail "gh was called despite the dirty tree - the dirty check must run first"; else pass "gh was never called - the dirty-tree check ran before any gh call"; fi
if [ "$(wine_call_count)" = "$PRE_DIRTY_WINE_COUNT" ]; then pass "the engine was never launched on a dirty tree"; else fail "the engine was launched despite the dirty tree"; fi
rm -f "${CHECKOUT}/dirty-marker.txt" "${CHECKOUT}/chextrek.dll" "${CHECKOUT}/chextrek.pdb"

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
echo "=== case 5: too many positional arguments is a usage error ==="
OUT5="$(run_fetch_and_play deadbeef extra-arg 2>&1)"
CODE5=$?
if [ $CODE5 -ne 0 ]; then pass "exits non-zero when given two arguments"; else fail "exit code 0 with two arguments, want non-zero"; fi
if echo "$OUT5" | grep -qi "usage"; then pass "prints a usage message"; else fail "expected a usage message"; echo "$OUT5"; fi

# RELEASE_SHA's own real win-<short sha> tag (spec #66's exact scheme) - #70's commit-arg path
# derives this same tag from the commit it's given, so these self-test releases must use it too.
RELEASE_TAG="win-$(git -C "$SEED" rev-parse --short=10 "$RELEASE_SHA")"

echo
echo "=== case 6: commit argument with a green release -> resolves to a full sha, looks up THAT commit's own win-<short> release (not Latest), lands detached on it, downloads, launches ==="
# Start from LATE_SHA (not RELEASE_SHA) and point the Latest stub at LATE_SHA too, both
# deliberately different from the commit argument (RELEASE_SHA) - if the commit argument were ever
# ignored and the run silently fell back to the Latest path, it would land back on LATE_SHA (a
# no-op from this starting point) instead of moving to RELEASE_SHA, and the gh-argv assertion below
# would see a no-tag "release view" call instead of one naming RELEASE_TAG.
git -C "$CHECKOUT" checkout -q "$LATE_SHA"
: >"${SCRATCH}/wine-invoked-count"
rm -rf "${SCRATCH}/wine-invocations"
mkdir -p "${SCRATCH}/wine-invocations"
OUT6="$(STUB_GH_TAG="win-latest-should-not-be-used" STUB_GH_TARGET="$LATE_SHA" STUB_GH_ASSET_NAMES="chextrek.dll,chextrek.pdb" \
	STUB_GH_RELEASES="$(printf '%s\x1f%s\x1fchextrek.dll,chextrek.pdb' "$RELEASE_TAG" "$RELEASE_SHA")" \
	run_fetch_and_play "$RELEASE_SHA" 2>&1)"
CODE6=$?
if [ $CODE6 -eq 0 ]; then pass "exits 0 given a commit with a green release"; else fail "exit code $CODE6, want 0"; echo "$OUT6"; fi
CUR6_SHA="$(git -C "$CHECKOUT" rev-parse HEAD)"
if [ "$CUR6_SHA" = "$RELEASE_SHA" ]; then pass "HEAD is at the given commit ${RELEASE_SHA} - not ${LATE_SHA}, the deliberately-different Latest stub target"; else fail "HEAD is ${CUR6_SHA}, want ${RELEASE_SHA} (landing on ${LATE_SHA} would mean the commit argument was silently ignored in favor of Latest)"; fi
if [ "$(git -C "$CHECKOUT" symbolic-ref -q HEAD)" ]; then fail "HEAD is still on a branch - expected detached"; else pass "HEAD is detached (commit-arg path)"; fi
if grep -qF "$RELEASE_TAG" "${SCRATCH}/gh-argv.d"/*.args 2>/dev/null; then pass "gh was called with the commit's own release tag (${RELEASE_TAG}), not a no-tag Latest lookup"; else fail "expected some gh call's argv to name ${RELEASE_TAG}"; fi
if [ -f "${CHECKOUT}/chextrek.dll" ] && [ -f "${CHECKOUT}/chextrek.pdb" ]; then pass "chextrek.dll/chextrek.pdb were downloaded for the given commit"; else fail "chextrek.dll/chextrek.pdb missing from ${CHECKOUT}"; fi
if [ "$(wine_call_count)" = "1" ]; then pass "the engine was launched exactly once for the given commit"; else fail "expected exactly one engine launch, found $(wine_call_count)"; fi
rm -f "${CHECKOUT}/chextrek.dll" "${CHECKOUT}/chextrek.pdb"

echo
echo "=== case 7: a dirty tree refuses on the commit-arg path too, before any gh/git-remote call, and changes nothing ==="
git -C "$CHECKOUT" checkout -q "$RELEASE_SHA"
PRE_DIRTY2_SHA="$(git -C "$CHECKOUT" rev-parse HEAD)"
PRE_DIRTY2_WINE_COUNT="$(wine_call_count)"
echo "local uncommitted change" >"${CHECKOUT}/dirty-marker.txt"
OUT7="$(STUB_GH_RELEASES="$(printf '%s\x1f%s\x1fchextrek.dll,chextrek.pdb' "$RELEASE_TAG" "$RELEASE_SHA")" \
	run_fetch_and_play "$RELEASE_SHA" 2>&1)"
CODE7=$?
if [ $CODE7 -ne 0 ]; then pass "exits non-zero on a dirty tree with a commit argument"; else fail "exit code 0 on a dirty tree with a commit argument, want non-zero"; fi
if echo "$OUT7" | grep -qi "uncommitted"; then pass "reports the uncommitted-changes reason clearly (commit-arg path)"; else fail "expected a clear 'uncommitted changes' message"; echo "$OUT7"; fi
POST_DIRTY2_SHA="$(git -C "$CHECKOUT" rev-parse HEAD)"
if [ "$POST_DIRTY2_SHA" = "$PRE_DIRTY2_SHA" ]; then pass "HEAD unchanged on a dirty tree with a commit argument"; else fail "HEAD moved from ${PRE_DIRTY2_SHA} to ${POST_DIRTY2_SHA} despite the dirty tree"; fi
if [ -s "${SCRATCH}/gh-argv.log" ]; then fail "gh was called despite the dirty tree (commit-arg path) - the dirty check must run first"; else pass "gh was never called on the commit-arg path either - the dirty-tree check ran first"; fi
if [ "$(wine_call_count)" = "$PRE_DIRTY2_WINE_COUNT" ]; then pass "the engine was never launched on a dirty tree (commit-arg path)"; else fail "the engine was launched despite the dirty tree"; fi
rm -f "${CHECKOUT}/dirty-marker.txt"

echo
echo "=== case 8: a commit with no release -> exits non-zero naming the commit, HEAD unchanged ==="
git -C "$CHECKOUT" checkout -q main-local
PRE_NOREL2_SHA="$(git -C "$CHECKOUT" rev-parse HEAD)"
PRE_NOREL2_BRANCH="$(git -C "$CHECKOUT" symbolic-ref -q HEAD || true)"
OUT8="$(STUB_GH_RELEASES="" run_fetch_and_play "$NEWER_SHA" 2>&1)"
CODE8=$?
if [ $CODE8 -ne 0 ]; then pass "exits non-zero for a commit with no release"; else fail "exit code 0, want non-zero"; fi
if echo "$OUT8" | grep -qF "$NEWER_SHA"; then pass "names the commit in the error message"; else fail "expected the error to name ${NEWER_SHA}"; echo "$OUT8"; fi
POST_NOREL2_SHA="$(git -C "$CHECKOUT" rev-parse HEAD)"
POST_NOREL2_BRANCH="$(git -C "$CHECKOUT" symbolic-ref -q HEAD || true)"
if [ "$POST_NOREL2_SHA" = "$PRE_NOREL2_SHA" ] && [ "$POST_NOREL2_BRANCH" = "$PRE_NOREL2_BRANCH" ]; then pass "HEAD unchanged (still on main-local, not detached) for a commit with no release"; else fail "HEAD moved (sha ${PRE_NOREL2_SHA}->${POST_NOREL2_SHA}, branch '${PRE_NOREL2_BRANCH}'->'${POST_NOREL2_BRANCH}') despite no release for the commit"; fi
if [ -f "${CHECKOUT}/chextrek.dll" ] || [ -f "${CHECKOUT}/chextrek.pdb" ]; then fail "a DLL/PDB exists despite no release for the commit"; else pass "no DLL/PDB downloaded - there's no release for the commit"; fi

echo
echo "=== case 9: a release found by the commit's own tag but targeting a different commit -> refuses (never trusts the tag alone), HEAD unchanged ==="
git -C "$CHECKOUT" checkout -q main-local
PRE_MISMATCH_SHA="$(git -C "$CHECKOUT" rev-parse HEAD)"
PRE_MISMATCH_BRANCH="$(git -C "$CHECKOUT" symbolic-ref -q HEAD || true)"
OUT9="$(STUB_GH_RELEASES="$(printf '%s\x1f%s\x1fchextrek.dll,chextrek.pdb' "$RELEASE_TAG" "$NEWER_SHA")" \
	run_fetch_and_play "$RELEASE_SHA" 2>&1)"
CODE9=$?
if [ $CODE9 -ne 0 ]; then pass "exits non-zero when the release's target doesn't match the resolved commit"; else fail "exit code 0, want non-zero"; fi
if echo "$OUT9" | grep -qF "$RELEASE_SHA" && echo "$OUT9" | grep -qF "$NEWER_SHA"; then pass "names both the resolved commit and the release's actual target"; else fail "expected the message to name both ${RELEASE_SHA} and ${NEWER_SHA}"; echo "$OUT9"; fi
POST_MISMATCH_SHA="$(git -C "$CHECKOUT" rev-parse HEAD)"
POST_MISMATCH_BRANCH="$(git -C "$CHECKOUT" symbolic-ref -q HEAD || true)"
if [ "$POST_MISMATCH_SHA" = "$PRE_MISMATCH_SHA" ] && [ "$POST_MISMATCH_BRANCH" = "$PRE_MISMATCH_BRANCH" ]; then pass "HEAD unchanged (still on main-local, not detached) when the release's target doesn't match"; else fail "HEAD moved (sha ${PRE_MISMATCH_SHA}->${POST_MISMATCH_SHA}, branch '${PRE_MISMATCH_BRANCH}'->'${POST_MISMATCH_BRANCH}') despite the target mismatch"; fi
if [ -f "${CHECKOUT}/chextrek.dll" ] || [ -f "${CHECKOUT}/chextrek.pdb" ]; then fail "a DLL/PDB exists despite the target mismatch"; else pass "no DLL/PDB downloaded - the release's target didn't match"; fi

echo
echo "=== case 10: self-rewriting checkout - a git wrapper simulates the exact same-inode, mid-file overwrite of tools/fetch-and-play.sh that a real Windows checkout race would cause; the run still completes correctly (main()-wrap guard, see fetch-and-play.sh's header and the git shim above) ==="
# A real Linux `git checkout` replaces a changed tracked file via unlink+recreate (a new inode) -
# bash's already-open read handle, pinned to the old (now-unlinked) inode, never observes that, so
# a plain checkout of a commit with a differing tools/fetch-and-play.sh can't exercise the same
# hazard on its own - confirmed directly while writing this test (an earlier, weaker version of
# this case, whose injected difference sat in a region bash had already read by sabotage time,
# passed with main() removed too; it didn't actually prove anything). REWRITE_CONTENT_FILE holds a
# version of tools/fetch-and-play.sh with an `exit 91` spliced in right after the checkout's own
# "Checked out ... (detached)" line - i.e. into the *not-yet-executed remainder* of the file at the
# moment the checkout runs, not appended at the tail and not placed somewhere already read: only
# content bash hasn't consumed yet can distinguish "read the old, already-buffered bytes" (this
# case passes) from "read the new, sabotaged bytes" (exit 91, this case would fail). The "git" shim
# above, armed via STUB_GIT_REWRITE_TARGET/STUB_GIT_REWRITE_CONTENT below, performs the actual
# same-inode overwrite (a plain `>` redirection to the existing file) when it sees
# fetch-and-play.sh's own `checkout --detach` call, simulating the race directly rather than hoping
# a real checkout reproduces it. This case sets CHEXTREK_FETCH_AND_PLAY_SELF to the checkout's own
# script, which skips fetch-and-play.sh's temp-copy re-exec - so bash really is reading the file the
# shim overwrites, and the main() wrap is the only guard in play (case 11 covers the temp copy).
# Mutation-tested: with the main() wrap temporarily removed (a local, uncommitted edit), this case
# genuinely fails - exit 91, zero engine launches - and with the wrap restored it passes.
REWRITE_CONTENT_FILE="${SCRATCH}/rewrite-fetch-and-play.sh"
awk '/^\techo "==> Checked out \${TARGET} \(detached\)"$/{print; print "\texit 91  # case-10 marker: only in bytes the currently-running script has not read yet at sabotage time"; next} {print}' \
	"${SCRIPT_DIR}/fetch-and-play.sh" >"$REWRITE_CONTENT_FILE"
cp "$REWRITE_CONTENT_FILE" "${SEED}/tools/fetch-and-play.sh"
git -C "$SEED" add tools/fetch-and-play.sh
git -C "$SEED" commit -q -m "case 10: a differing tools/fetch-and-play.sh (mid-file change)"
REWRITE_SHA="$(git -C "$SEED" rev-parse HEAD)"
git -C "$SEED" push -q origin main
REWRITE_TAG="win-$(git -C "$SEED" rev-parse --short=10 "$REWRITE_SHA")"
# Restore the seed's tools/fetch-and-play.sh to the unmodified copy for any case after this one.
cp "${SCRIPT_DIR}/fetch-and-play.sh" "${SEED}/tools/fetch-and-play.sh"
git -C "$SEED" add tools/fetch-and-play.sh
git -C "$SEED" commit -q -m "case 10: restore tools/fetch-and-play.sh"
git -C "$SEED" push -q origin main

git -C "$CHECKOUT" fetch -q origin
git -C "$CHECKOUT" checkout -q main-local
: >"${SCRATCH}/wine-invoked-count"
rm -rf "${SCRATCH}/wine-invocations"
mkdir -p "${SCRATCH}/wine-invocations"
PRE10_INODE="$(stat -c %i "${CHECKOUT}/tools/fetch-and-play.sh")"
OUT10="$(STUB_GH_RELEASES="$(printf '%s\x1f%s\x1fchextrek.dll,chextrek.pdb' "$REWRITE_TAG" "$REWRITE_SHA")" \
	STUB_GIT_REWRITE_TARGET="$REWRITE_SHA" \
	STUB_GIT_REWRITE_CONTENT="$REWRITE_CONTENT_FILE" \
	CHEXTREK_FETCH_AND_PLAY_SELF="${CHECKOUT}/tools/fetch-and-play.sh" \
	run_fetch_and_play "$REWRITE_SHA" 2>&1)"
CODE10=$?
if [ $CODE10 -eq 0 ]; then pass "the run completes even though its own checkout overwrites tools/fetch-and-play.sh in place, mid-run"; else fail "exit code $CODE10, want 0"; echo "$OUT10"; fi
CUR10_SHA="$(git -C "$CHECKOUT" rev-parse HEAD)"
if [ "$CUR10_SHA" = "$REWRITE_SHA" ]; then pass "HEAD landed on the differing commit"; else fail "HEAD is ${CUR10_SHA}, want ${REWRITE_SHA}"; fi
POST10_INODE="$(stat -c %i "${CHECKOUT}/tools/fetch-and-play.sh" 2>/dev/null || echo "<missing>")"
if grep -q "case-10 marker" "${CHECKOUT}/tools/fetch-and-play.sh" 2>/dev/null; then pass "the on-disk tools/fetch-and-play.sh now matches the checked-out commit (the sabotage write and the real checkout both landed)"; else fail "expected ${CHECKOUT}/tools/fetch-and-play.sh to contain the case-10 marker after checkout"; fi
# Note on what this inode check does and doesn't show: the shim's own same-inode sabotage write
# happens on the *original* inode (that's the whole point - it's what makes the hazard real for
# whatever already has that inode open), but the real `checkout -f` the shim runs right after it
# still does its own ordinary unlink+recreate for every file, this one included - so by the end of
# the run the final inode has almost certainly changed again. That's expected, not a sign the
# sabotage didn't happen; it only confirms the real checkout ran to completion afterward. The actual
# proof that the same-inode sabotage was observed mid-run is the exit-91 mutation test described
# above (main() wrap removed -> this case fails), not this inode comparison.
if [ "$PRE10_INODE" != "$POST10_INODE" ]; then pass "tools/fetch-and-play.sh's inode changed by the end of the run (inode ${PRE10_INODE} -> ${POST10_INODE}) - the real checkout ran to completion after the sabotage write"; else fail "expected tools/fetch-and-play.sh's inode to change (still ${PRE10_INODE}) - the checkout may not have completed"; fi
if [ "$(wine_call_count)" = "1" ]; then pass "the engine was still launched exactly once despite the mid-run rewrite"; else fail "expected exactly one engine launch, found $(wine_call_count)"; fi

echo
echo "=== case 11: temp-copy re-exec - at checkout time nothing in the run holds the checkout's own tools/fetch-and-play.sh open (Git for Windows' \"Unlink of file ... failed\" guard), and the temp copy is already deleted ==="
# The git shim (armed via STUB_GIT_OPENCHECK_OUT) inspects /proc/<pid>/fd of every process in the
# run's ancestry at the moment of `checkout --detach`. "COPY" lines are the positive control: they
# prove the walk does see bash's own open script fd, so "no OPEN line" is a real finding, not a
# blind spot. Mutation-tested: with the re-exec block removed from fetch-and-play.sh, this case
# fails (an OPEN line, no COPY line). The same scan can't be done on Windows from here - whether
# Git for Windows then replaces the file cleanly is owner-pending.
git -C "$CHECKOUT" checkout -q -f main-local
rm -f "${CHECKOUT}/chextrek.dll" "${CHECKOUT}/chextrek.pdb"
: >"${SCRATCH}/wine-invoked-count"
rm -rf "${SCRATCH}/wine-invocations"
mkdir -p "${SCRATCH}/wine-invocations"
OPENCHECK_FILE="${SCRATCH}/openfd-check.txt"
: >"$OPENCHECK_FILE"
OUT11="$(STUB_GH_RELEASES="$(printf '%s\x1f%s\x1fchextrek.dll,chextrek.pdb' "$RELEASE_TAG" "$RELEASE_SHA")" \
	STUB_GIT_OPENCHECK_OUT="$OPENCHECK_FILE" \
	run_fetch_and_play "$RELEASE_SHA" 2>&1)"
CODE11=$?
if [ $CODE11 -eq 0 ]; then pass "exits 0 running from its temp copy"; else fail "exit code $CODE11, want 0"; echo "$OUT11"; fi
if grep -q "^CHECKED" "$OPENCHECK_FILE"; then pass "the git shim inspected open fds at checkout time"; else fail "the git shim never ran its open-fd check"; fi
if grep -q "^OPEN " "$OPENCHECK_FILE"; then
	fail "a process in the run held ${CHECKOUT}/tools/fetch-and-play.sh open during the checkout:"
	grep "^OPEN " "$OPENCHECK_FILE"
else
	pass "nothing in the run held the checkout's own tools/fetch-and-play.sh open during the checkout"
fi
if grep -q "^COPY " "$OPENCHECK_FILE"; then pass "positive control: bash's open fd on its temp copy was visible to the same scan"; else fail "no temp-copy fd seen - the scan can't be trusted (or the re-exec didn't happen)"; cat "$OPENCHECK_FILE"; fi
COPY_PATH="$(sed -n 's/^COPY [0-9]* [^ ]* \(.*\)$/\1/p' "$OPENCHECK_FILE" | head -1)"
COPY_PATH="${COPY_PATH% (deleted)}"
if [ -n "$COPY_PATH" ] && [ ! -e "$COPY_PATH" ]; then pass "the temp copy (${COPY_PATH}) was already deleted by checkout time"; else fail "the temp copy '${COPY_PATH}' still exists (or wasn't found)"; fi
if [ "$(git -C "$CHECKOUT" rev-parse HEAD)" = "$RELEASE_SHA" ]; then pass "HEAD landed on the release commit"; else fail "HEAD is $(git -C "$CHECKOUT" rev-parse HEAD), want ${RELEASE_SHA}"; fi
if [ "$(wine_call_count)" = "1" ]; then pass "the engine was launched exactly once"; else fail "expected exactly one engine launch, found $(wine_call_count)"; fi

echo
if [ $FAIL -eq 0 ]; then
	echo "PASS: whole self-test"
	exit 0
else
	echo "FAIL: whole self-test - see above"
	exit 1
fi
