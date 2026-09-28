#!/usr/bin/env bash
# Self-test for tools/pipeline-process-commit.sh (spec #58/#66). This never touches the real
# wScottSh/chex-trek repo, a real `gh`, or a real build/game run:
#   - a scratch git repo stands in for "the repo this script lives in" (CHEXTREK_PIPELINE_REPO
#     also pins the --repo every `gh` call gets, as a second, independent belt-and-braces check);
#   - a fake `gh` earlier on PATH (repo convention - see tools/test-run-all-tests-*.sh) records
#     every invocation's argv and simulates `release view`/`release create` against a flat file,
#     instead of ever reaching github.com;
#   - CHEXTREK_PIPELINE_SUITE_CMD points at tiny fake "suite" scripts that stand in for
#     tools/run-all-tests.sh's three outcomes (green/red/environment-blocker) without building or
#     launching anything.
# Covers: a green commit publishes win-<sha> with both assets, Latest, not prerelease, notes
# containing the suite summary; re-processing that commit doesn't create a duplicate; a red commit
# publishes nothing; a simulated environment blocker (exit 3) is reported as such, not a FAIL; a
# suite exit that's neither 0/1/3 (e.g. signal-killed) is a pipeline error, never mistaken for red;
# default --repo parsing from `git remote get-url origin`, both ssh and https forms; a missing
# built asset is a pipeline error, not a false-green publish; an ambient CHEXTREK_SKIP_BUILD=1 in
# the calling shell never reaches the suite command; a `gh release create` failure is a pipeline
# error unless the recheck finds the release was actually made (response lost, not a duplicate
# create); two overlapping runs of the *same* commit never corrupt each other's scratch worktree
# (the per-tag lock); a worktree left over from an earlier crashed run is removed, not mistaken for
# a live one; the worktree it made is cleaned up every time; the caller's own working copy is left
# untouched; logs land outside the repo.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRATCH="$(mktemp -d)"
trap 'rm -rf "$SCRATCH"' EXIT
FAIL=0

pass() { echo "PASS: $*"; }
fail() {
	echo "FAIL: $*"
	FAIL=1
}

# --- fake gh: records argv, simulates `release view`/`release create` against a flat file ---
# Each invocation's full argv (which can include a multi-line --notes value) goes to its own file
# under STUB_GH_ARGV_DIR, one arg per line - safe to grep even though --notes itself may contain
# embedded newlines. STUB_GH_ARGV_LOG is a single-line-per-call index (id, subcommand, tag) for
# finding which of those files belongs to a given call.
mkdir -p "${SCRATCH}/bin"
cat >"${SCRATCH}/bin/gh" <<'STUBEOF'
#!/usr/bin/env bash
# Test double for gh (tools/test-pipeline-process-commit.sh). Never talks to github.com.
set -u
CALL_ID="$(date -u +%s%N)-$$-${RANDOM}"
ARGF="${STUB_GH_ARGV_DIR}/${CALL_ID}.args"
: >"$ARGF"
for a in "$@"; do printf '%s\n' "$a" >>"$ARGF"; done
printf '%s %s %s %s\n' "$CALL_ID" "${1:-}" "${2:-}" "${3:-}" >>"${STUB_GH_ARGV_LOG}"
if [ "${1:-}" = "release" ] && [ "${2:-}" = "view" ]; then
	TAG="${3:-}"
	if [ -n "${STUB_GH_RELEASES:-}" ] && [ -f "${STUB_GH_RELEASES}" ] && grep -qxF "$TAG" "${STUB_GH_RELEASES}"; then
		echo "$TAG"
		exit 0
	fi
	echo "release not found" >&2
	exit 1
fi
if [ "${1:-}" = "release" ] && [ "${2:-}" = "create" ]; then
	TAG="${3:-}"
	if [ "${STUB_GH_CREATE_FAIL:-0}" = "1" ]; then
		echo "stub: simulated create failure" >&2
		exit 1
	fi
	if [ "${STUB_GH_CREATE_FAIL:-0}" = "2" ]; then
		# Simulates a create that actually succeeded server-side but whose success response never
		# reached this call (e.g. a network blip) - the tag exists, but gh still reports failure.
		printf '%s\n' "$TAG" >>"${STUB_GH_RELEASES}"
		echo "stub: simulated create failure after the release was actually made" >&2
		exit 1
	fi
	printf '%s\n' "$TAG" >>"${STUB_GH_RELEASES}"
	echo "https://github.com/stub/stub/releases/tag/${TAG}"
	exit 0
fi
echo "stub gh: unhandled invocation: $*" >&2
exit 1
STUBEOF
chmod +x "${SCRATCH}/bin/gh"
export PATH="${SCRATCH}/bin:${PATH}"

export STUB_GH_ARGV_LOG="${SCRATCH}/gh-argv.log"
export STUB_GH_ARGV_DIR="${SCRATCH}/gh-argv.d"
export STUB_GH_RELEASES="${SCRATCH}/gh-releases.txt"
mkdir -p "$STUB_GH_ARGV_DIR"
: >"$STUB_GH_ARGV_LOG"
: >"$STUB_GH_RELEASES"

# find_create_argv TAG - path to the recorded argv file (one arg per line) of the
# "release create TAG ..." call, or empty if there was no such call.
find_create_argv() {
	local TAG="$1" ID
	ID="$(awk -v tag="$TAG" '$2=="release" && $3=="create" && $4==tag {print $1}' "$STUB_GH_ARGV_LOG" | tail -1)"
	[ -n "$ID" ] && echo "${STUB_GH_ARGV_DIR}/${ID}.args"
}

# count_create_calls TAG - how many "release create TAG ..." calls the stub gh has seen so far.
count_create_calls() {
	local TAG="$1"
	awk -v tag="$TAG" '$2=="release" && $3=="create" && $4==tag' "$STUB_GH_ARGV_LOG" | wc -l | tr -d ' '
}

# --- fake suites: stand-ins for tools/run-all-tests.sh's three outcomes ---
cat >"${SCRATCH}/suite-green.sh" <<'EOF'
#!/usr/bin/env bash
printf 'stub-dll\n' > chextrek.dll
printf 'stub-pdb\n' > chextrek.pdb
echo "=== summary: 3 passed, 0 failed ==="
echo "PASS: whole suite"
exit 0
EOF
cat >"${SCRATCH}/suite-green-noassets.sh" <<'EOF'
#!/usr/bin/env bash
echo "=== summary: 3 passed, 0 failed ==="
echo "PASS: whole suite"
exit 0
EOF
cat >"${SCRATCH}/suite-red.sh" <<'EOF'
#!/usr/bin/env bash
echo "=== summary: 2 passed, 1 failed ==="
echo "FAIL: test-fake.sh"
exit 1
EOF
cat >"${SCRATCH}/suite-env.sh" <<'EOF'
#!/usr/bin/env bash
echo "ENVIRONMENT: fake blocker - wine not found on PATH"
exit 3
EOF
cat >"${SCRATCH}/suite-signal.sh" <<'EOF'
#!/usr/bin/env bash
echo "stub: pretend this got killed by a signal"
exit 137
EOF
cat >"${SCRATCH}/suite-checks-no-skip-build.sh" <<'EOF'
#!/usr/bin/env bash
if [ -n "${CHEXTREK_SKIP_BUILD:-}" ]; then
	echo "FAIL: CHEXTREK_SKIP_BUILD leaked into the suite command (value=${CHEXTREK_SKIP_BUILD})"
	exit 1
fi
printf 'stub-dll\n' > chextrek.dll
printf 'stub-pdb\n' > chextrek.pdb
echo "=== summary: 1 passed, 0 failed ==="
echo "PASS: whole suite"
exit 0
EOF
cat >"${SCRATCH}/suite-green-slow.sh" <<'EOF'
#!/usr/bin/env bash
sleep 1
printf 'stub-dll\n' > chextrek.dll
printf 'stub-pdb\n' > chextrek.pdb
echo "=== summary: 1 passed, 0 failed ==="
echo "PASS: whole suite"
exit 0
EOF

# --- scratch repo standing in for "the repo pipeline-process-commit.sh lives in" ---
REPO="${SCRATCH}/repo"
mkdir -p "${REPO}/tools"
cp "${SCRIPT_DIR}/pipeline-process-commit.sh" "${REPO}/tools/pipeline-process-commit.sh"
git -C "$REPO" init -q -b main
git -C "$REPO" config user.email test@example.invalid
git -C "$REPO" config user.name "Pipeline Test"
git -C "$REPO" remote add origin git@github.com:stub-owner/stub-repo.git
git -C "$REPO" add tools/pipeline-process-commit.sh
git -C "$REPO" commit -q -m "seed"

commit_sha() {
	local MSG="$1"
	git -C "$REPO" commit -q --allow-empty -m "$MSG"
	git -C "$REPO" rev-parse HEAD
}

SHA_GREEN="$(commit_sha "green commit")"
SHA_RED="$(commit_sha "red commit")"
SHA_ENV="$(commit_sha "environment-blocker commit")"
SHA_NOASSETS="$(commit_sha "green-but-no-assets commit")"
SHA_DEFAULT_REPO="$(commit_sha "default-repo-parsing commit")"
SHA_SIGNAL="$(commit_sha "signal-killed-suite commit")"
SHA_SKIP_BUILD="$(commit_sha "ambient-skip-build commit")"
SHA_CREATE_FAIL="$(commit_sha "create-call-fails-cleanly commit")"
SHA_CREATE_RACE="$(commit_sha "create-call-fails-after-succeeding commit")"
SHA_CONCURRENT="$(commit_sha "processed-by-two-overlapping-runs commit")"
SHA_STALE_WORKTREE="$(commit_sha "stale-worktree-from-a-crashed-run commit")"

# A second scratch repo, identical except its origin is an https URL (git@ / ssh:// are covered by
# $REPO's own origin above) - proves default --repo parsing handles both remote URL forms.
REPO_HTTPS="${SCRATCH}/repo-https"
mkdir -p "${REPO_HTTPS}/tools"
cp "${SCRIPT_DIR}/pipeline-process-commit.sh" "${REPO_HTTPS}/tools/pipeline-process-commit.sh"
git -C "$REPO_HTTPS" init -q -b main
git -C "$REPO_HTTPS" config user.email test@example.invalid
git -C "$REPO_HTTPS" config user.name "Pipeline Test"
git -C "$REPO_HTTPS" remote add origin https://github.com/stub-owner-https/stub-repo-https.git
git -C "$REPO_HTTPS" add tools/pipeline-process-commit.sh
git -C "$REPO_HTTPS" commit -q -m "seed"
SHA_HTTPS_REPO="$(git -C "$REPO_HTTPS" commit -q --allow-empty -m "https-repo-parsing commit" && git -C "$REPO_HTTPS" rev-parse HEAD)"

STATE_DIR="${SCRATCH}/state"

run_pipeline() {
	# run_pipeline SHA SUITE_SCRIPT [REPO_OVERRIDE] [REPO_DIR]
	#
	# The empty-REPO_OVERRIDE branch (case 5) proves default --repo parsing, which only works if
	# CHEXTREK_PIPELINE_REPO is actually unset for that call - `env -u` guarantees that regardless
	# of what the ambient shell already has exported (this self-test is itself one of
	# tools/run-all-tests.sh's own tools/test-*.sh scripts, run under a caller that may well have
	# CHEXTREK_PIPELINE_REPO exported for its own outer pipeline run - a plain unset here would
	# silently inherit that and this case would test nothing). Same reasoning for
	# CHEXTREK_PIPELINE_TAG_PREFIX below - none of these fake suites care about it, but this
	# self-test's own tag-computing helpers all hardcode the "win-" default, so a stray ambient
	# override would break their assertions, not the pipeline itself.
	#
	# CHEXTREK_SKIP_BUILD is deliberately *not* scrubbed here - case "ambient CHEXTREK_SKIP_BUILD"
	# below needs it to reach the real pipeline script un-stripped, to prove that script's own
	# internal `unset` (not this test harness) is what protects the suite command from it.
	local SHA="$1" SUITE="$2" REPO_OVERRIDE="${3-stub/testrepo}" REPO_DIR="${4:-$REPO}"
	if [ -n "$REPO_OVERRIDE" ]; then
		env -u CHEXTREK_PIPELINE_TAG_PREFIX \
			CHEXTREK_PIPELINE_REPO="$REPO_OVERRIDE" \
			CHEXTREK_PIPELINE_STATE_DIR="$STATE_DIR" \
			CHEXTREK_PIPELINE_SUITE_CMD="bash \"$SUITE\"" \
			bash "${REPO_DIR}/tools/pipeline-process-commit.sh" "$SHA"
	else
		env -u CHEXTREK_PIPELINE_REPO -u CHEXTREK_PIPELINE_TAG_PREFIX \
			CHEXTREK_PIPELINE_STATE_DIR="$STATE_DIR" \
			CHEXTREK_PIPELINE_SUITE_CMD="bash \"$SUITE\"" \
			bash "${REPO_DIR}/tools/pipeline-process-commit.sh" "$SHA"
	fi
}

echo "=== case 1: a green commit publishes win-<sha> with both assets, Latest, not prerelease, notes with the suite summary ==="
OUT1="$(run_pipeline "$SHA_GREEN" "${SCRATCH}/suite-green.sh")"
CODE1=$?
SHORT_GREEN="$(git -C "$REPO" rev-parse --short=10 "$SHA_GREEN")"
TAG_GREEN="win-${SHORT_GREEN}"
if [ $CODE1 -eq 0 ]; then pass "exits 0 on a green commit"; else fail "exit code $CODE1, want 0"; echo "$OUT1"; fi
if grep -qxF "$TAG_GREEN" "$STUB_GH_RELEASES"; then pass "release ${TAG_GREEN} recorded as created"; else fail "no release recorded for ${TAG_GREEN}"; fi
CREATE_ARGF="$(find_create_argv "$TAG_GREEN")"
if [ -n "$CREATE_ARGF" ] && [ -f "$CREATE_ARGF" ]; then pass "gh release create called for ${TAG_GREEN}"; else fail "no 'gh release create ${TAG_GREEN}' call found"; cat "$STUB_GH_ARGV_LOG"; fi
if grep -A1 -xF -- "--repo" "$CREATE_ARGF" | grep -qxF "stub/testrepo"; then pass "create call carries --repo stub/testrepo"; else fail "create call missing --repo stub/testrepo"; cat "$CREATE_ARGF"; fi
if grep -A1 -xF -- "--target" "$CREATE_ARGF" | grep -qxF "$SHA_GREEN"; then pass "create call targets the exact sha"; else fail "create call missing --target ${SHA_GREEN}"; cat "$CREATE_ARGF"; fi
if grep -qxF -- "--latest" "$CREATE_ARGF"; then pass "create call marks Latest"; else fail "create call missing --latest"; cat "$CREATE_ARGF"; fi
if grep -qxF -- "--prerelease" "$CREATE_ARGF"; then fail "create call wrongly passes --prerelease"; else pass "create call never passes --prerelease"; fi
if grep -qF "chextrek.dll" "$CREATE_ARGF" && grep -qF "chextrek.pdb" "$CREATE_ARGF"; then pass "create call carries both assets"; else fail "create call missing an asset"; cat "$CREATE_ARGF"; fi
if grep -qF "3 passed, 0 failed" "$CREATE_ARGF"; then pass "create call's --notes carries the suite summary"; else fail "expected the suite summary inside the --notes argument"; cat "$CREATE_ARGF"; fi
# The stub only records argv, not stdin - the run's own log file is where --notes' actual content
# (built from the summary text) is provable, since gh accepts --notes as one shell word.
LOG_GREEN="$(find "${STATE_DIR}/logs" -name "*-${TAG_GREEN}-*.log" | head -1)"
if [ -n "$LOG_GREEN" ] && [ -f "$LOG_GREEN" ] && grep -qF "3 passed, 0 failed" "$LOG_GREEN"; then
	pass "the archived log (outside the repo) contains the suite summary that seeded the notes"
else
	fail "expected the archived log to contain the suite summary"
fi

echo
echo "=== case 2: re-processing the same commit doesn't create a duplicate release (idempotent) ==="
CREATE_COUNT_BEFORE="$(count_create_calls "$TAG_GREEN")"
OUT2="$(run_pipeline "$SHA_GREEN" "${SCRATCH}/suite-green.sh")"
CODE2=$?
CREATE_COUNT_AFTER="$(count_create_calls "$TAG_GREEN")"
if [ $CODE2 -eq 0 ]; then pass "exits 0 re-processing an already-published commit"; else fail "exit code $CODE2, want 0"; echo "$OUT2"; fi
if [ "$CREATE_COUNT_BEFORE" = "$CREATE_COUNT_AFTER" ]; then pass "no second 'gh release create' call - no duplicate"; else fail "release create was called again (before=$CREATE_COUNT_BEFORE after=$CREATE_COUNT_AFTER)"; fi
if echo "$OUT2" | grep -qi "already published"; then pass "reports 'already published' rather than re-running the suite silently"; else fail "expected an 'already published' outcome line"; fi

echo
echo "=== case 3: a red commit publishes nothing ==="
OUT3="$(run_pipeline "$SHA_RED" "${SCRATCH}/suite-red.sh")"
CODE3=$?
SHORT_RED="$(git -C "$REPO" rev-parse --short=10 "$SHA_RED")"
TAG_RED="win-${SHORT_RED}"
if [ $CODE3 -eq 1 ]; then pass "exits 1 on a red commit"; else fail "exit code $CODE3, want 1"; echo "$OUT3"; fi
if grep -qxF "$TAG_RED" "$STUB_GH_RELEASES"; then fail "a release was recorded for the red commit"; else pass "no release recorded for the red commit"; fi
if [ "$(count_create_calls "$TAG_RED")" != "0" ]; then fail "gh release create was called for the red commit"; else pass "gh release create was never called for the red commit"; fi

echo
echo "=== case 4: a simulated environment blocker (exit 3) is reported as such, not a test FAIL ==="
OUT4="$(run_pipeline "$SHA_ENV" "${SCRATCH}/suite-env.sh")"
CODE4=$?
SHORT_ENV="$(git -C "$REPO" rev-parse --short=10 "$SHA_ENV")"
TAG_ENV="win-${SHORT_ENV}"
if [ $CODE4 -eq 3 ]; then pass "exits 3 on a simulated environment blocker"; else fail "exit code $CODE4, want 3"; echo "$OUT4"; fi
if echo "$OUT4" | grep -qF "environment blocker"; then pass "outcome line names it an environment blocker"; else fail "expected an 'environment blocker' outcome line"; fi
if grep -qxF "$TAG_ENV" "$STUB_GH_RELEASES"; then fail "a release was recorded for the environment-blocker commit"; else pass "no release recorded for the environment-blocker commit"; fi

echo
echo "=== case 5: default --repo parsing from 'git remote get-url origin' (no override) ==="
OUT5="$(run_pipeline "$SHA_DEFAULT_REPO" "${SCRATCH}/suite-green.sh" "")"
CODE5=$?
SHORT_DEFAULT="$(git -C "$REPO" rev-parse --short=10 "$SHA_DEFAULT_REPO")"
TAG_DEFAULT="win-${SHORT_DEFAULT}"
if [ $CODE5 -eq 0 ]; then pass "exits 0 with the default (parsed) repo"; else fail "exit code $CODE5, want 0"; echo "$OUT5"; fi
DEFAULT_ARGF="$(find_create_argv "$TAG_DEFAULT")"
if [ -n "$DEFAULT_ARGF" ] && grep -A1 -xF -- "--repo" "$DEFAULT_ARGF" | grep -qxF "stub-owner/stub-repo"; then
	pass "parsed 'stub-owner/stub-repo' from the origin remote URL"
else
	fail "expected a create call with --repo stub-owner/stub-repo"
	[ -n "$DEFAULT_ARGF" ] && cat "$DEFAULT_ARGF"
fi

echo
echo "=== case 6: suite reports green but the built assets are missing -> pipeline error, not a false-green publish ==="
OUT6="$(run_pipeline "$SHA_NOASSETS" "${SCRATCH}/suite-green-noassets.sh")"
CODE6=$?
SHORT_NOASSETS="$(git -C "$REPO" rev-parse --short=10 "$SHA_NOASSETS")"
TAG_NOASSETS="win-${SHORT_NOASSETS}"
if [ $CODE6 -eq 2 ]; then pass "exits 2 (pipeline error) when the built assets are missing"; else fail "exit code $CODE6, want 2"; echo "$OUT6"; fi
if grep -qxF "$TAG_NOASSETS" "$STUB_GH_RELEASES"; then fail "a release was wrongly recorded despite missing assets"; else pass "no release recorded when assets are missing"; fi

echo
echo "=== case 6b: a suite exit that's neither 0, 1 nor 3 (e.g. signal-killed) is a pipeline error, never a red test result ==="
OUT6B="$(run_pipeline "$SHA_SIGNAL" "${SCRATCH}/suite-signal.sh")"
CODE6B=$?
SHORT_SIGNAL="$(git -C "$REPO" rev-parse --short=10 "$SHA_SIGNAL")"
TAG_SIGNAL="win-${SHORT_SIGNAL}"
if [ $CODE6B -eq 2 ]; then pass "exits 2 (pipeline error) on a non-0/1/3 suite exit"; else fail "exit code $CODE6B, want 2"; echo "$OUT6B"; fi
if echo "$OUT6B" | grep -qi "\bred\b"; then fail "a non-0/1/3 suite exit was described as red - #67 would wrongly file a failure issue for a non-test result"; else pass "never described as red"; fi
if grep -qxF "$TAG_SIGNAL" "$STUB_GH_RELEASES"; then fail "a release was recorded despite a non-0/1/3 suite exit"; else pass "no release recorded"; fi

echo
echo "=== case 6c: an ambient CHEXTREK_SKIP_BUILD=1 in the calling shell doesn't leak into the suite command ==="
OUT6C="$(CHEXTREK_SKIP_BUILD=1 run_pipeline "$SHA_SKIP_BUILD" "${SCRATCH}/suite-checks-no-skip-build.sh")"
CODE6C=$?
SHORT_SKIP_BUILD="$(git -C "$REPO" rev-parse --short=10 "$SHA_SKIP_BUILD")"
TAG_SKIP_BUILD="win-${SHORT_SKIP_BUILD}"
if [ $CODE6C -eq 0 ]; then pass "exits 0 - the ambient CHEXTREK_SKIP_BUILD=1 didn't reach the suite command"; else fail "exit code $CODE6C, want 0 (suite would have reported the leak as a FAIL)"; echo "$OUT6C"; fi
# The suite command's own stdout/stderr goes only to the pipeline's log file (captured via
# >>"$LOG_FILE" inside pipeline-process-commit.sh), not to this run's own $(...) stdout - so the
# leak check has to read the log file, not OUT6C, or it could never actually fire either way.
LOG_SKIP_BUILD="$(find "${STATE_DIR}/logs" -name "*-${TAG_SKIP_BUILD}-*.log" | head -1)"
if [ -z "$LOG_SKIP_BUILD" ] || [ ! -f "$LOG_SKIP_BUILD" ]; then
	fail "no archived log found for ${TAG_SKIP_BUILD} - can't check for a leak"
elif grep -qF "CHEXTREK_SKIP_BUILD leaked" "$LOG_SKIP_BUILD"; then
	fail "the suite command's own check caught a CHEXTREK_SKIP_BUILD leak"
else
	pass "no leak detected by the suite command's own check"
fi
if grep -qxF "$TAG_SKIP_BUILD" "$STUB_GH_RELEASES"; then pass "still published despite the ambient CHEXTREK_SKIP_BUILD=1"; else fail "expected a release despite the ambient CHEXTREK_SKIP_BUILD=1"; fi

echo
echo "=== case 6d: gh release create fails cleanly (no release actually made) -> pipeline error, not a false green ==="
SHORT_CREATE_FAIL="$(git -C "$REPO" rev-parse --short=10 "$SHA_CREATE_FAIL")"
TAG_CREATE_FAIL="win-${SHORT_CREATE_FAIL}"
OUT6D="$(STUB_GH_CREATE_FAIL=1 run_pipeline "$SHA_CREATE_FAIL" "${SCRATCH}/suite-green.sh")"
CODE6D=$?
if [ $CODE6D -eq 2 ]; then pass "exits 2 (pipeline error) when gh release create fails and no release exists"; else fail "exit code $CODE6D, want 2"; echo "$OUT6D"; fi
if grep -qxF "$TAG_CREATE_FAIL" "$STUB_GH_RELEASES"; then fail "a release was recorded despite the create call failing"; else pass "no release recorded"; fi

echo
echo "=== case 6e: gh release create fails but the release was actually made (its response was lost) -> the recheck finds it, exits 0 ==="
SHORT_CREATE_RACE="$(git -C "$REPO" rev-parse --short=10 "$SHA_CREATE_RACE")"
TAG_CREATE_RACE="win-${SHORT_CREATE_RACE}"
OUT6E="$(STUB_GH_CREATE_FAIL=2 run_pipeline "$SHA_CREATE_RACE" "${SCRATCH}/suite-green.sh")"
CODE6E=$?
if [ $CODE6E -eq 0 ]; then pass "exits 0 - the recheck after the failed create found the release"; else fail "exit code $CODE6E, want 0"; echo "$OUT6E"; fi
if [ "$(count_create_calls "$TAG_CREATE_RACE")" = "1" ]; then pass "the recheck itself never re-attempted a create - one release, not a duplicate"; else fail "expected exactly one create attempt, found $(count_create_calls "$TAG_CREATE_RACE")"; fi

echo
echo "=== case 6f: two overlapping runs of the *same* commit never corrupt each other's scratch worktree (per-tag lock) ==="
SHORT_CONCURRENT="$(git -C "$REPO" rev-parse --short=10 "$SHA_CONCURRENT")"
TAG_CONCURRENT="win-${SHORT_CONCURRENT}"
run_pipeline "$SHA_CONCURRENT" "${SCRATCH}/suite-green-slow.sh" >"${SCRATCH}/concurrent1.out" 2>&1 &
CONCURRENT_PID1=$!
run_pipeline "$SHA_CONCURRENT" "${SCRATCH}/suite-green-slow.sh" >"${SCRATCH}/concurrent2.out" 2>&1 &
CONCURRENT_PID2=$!
wait "$CONCURRENT_PID1"
CONCURRENT_CODE1=$?
wait "$CONCURRENT_PID2"
CONCURRENT_CODE2=$?
if [ $CONCURRENT_CODE1 -eq 0 ] && [ $CONCURRENT_CODE2 -eq 0 ]; then
	pass "both overlapping runs of the same commit exit 0"
else
	fail "expected both overlapping runs to exit 0; got ${CONCURRENT_CODE1} and ${CONCURRENT_CODE2}"
	cat "${SCRATCH}/concurrent1.out" "${SCRATCH}/concurrent2.out"
fi
if [ "$(count_create_calls "$TAG_CONCURRENT")" = "1" ]; then
	pass "exactly one release was created for the commit both runs shared - no duplicate, and the lock serialized them rather than one clobbering the other's worktree"
else
	fail "expected exactly one create call for ${TAG_CONCURRENT}, found $(count_create_calls "$TAG_CONCURRENT")"
	cat "${SCRATCH}/concurrent1.out" "${SCRATCH}/concurrent2.out"
fi
# "already exists"/"already published" is the *expected*, benign idempotency message one of these
# two runs prints when it loses the race to acquire the lock first - not a corruption sign. Only
# `git worktree`'s own fatal-error vocabulary counts here.
if grep -qiE "fatal|not a working tree" "${SCRATCH}/concurrent1.out" "${SCRATCH}/concurrent2.out"; then
	fail "one run's output shows worktree corruption from the other - see above"
else
	pass "neither run's own output shows any worktree corruption from the other"
fi
if echo "$(cat "${SCRATCH}/concurrent1.out" "${SCRATCH}/concurrent2.out")" | grep -qF "waiting for another run"; then
	pass "contention between the two overlapping runs was actually observed"
else
	echo "INFO: no contention observed between these two overlapping runs (both may have finished too fast to overlap) - the shared-tag safety is still proven by the single create call and clean worktree checks above"
fi

echo
echo "=== case 6g: default --repo parsing also handles an https origin remote URL ==="
OUT6G="$(run_pipeline "$SHA_HTTPS_REPO" "${SCRATCH}/suite-green.sh" "" "$REPO_HTTPS")"
CODE6G=$?
SHORT_HTTPS="$(git -C "$REPO_HTTPS" rev-parse --short=10 "$SHA_HTTPS_REPO")"
TAG_HTTPS="win-${SHORT_HTTPS}"
if [ $CODE6G -eq 0 ]; then pass "exits 0 with the default (https-parsed) repo"; else fail "exit code $CODE6G, want 0"; echo "$OUT6G"; fi
HTTPS_ARGF="$(find_create_argv "$TAG_HTTPS")"
if [ -n "$HTTPS_ARGF" ] && grep -A1 -xF -- "--repo" "$HTTPS_ARGF" | grep -qxF "stub-owner-https/stub-repo-https"; then
	pass "parsed 'stub-owner-https/stub-repo-https' from the https origin remote URL"
else
	fail "expected a create call with --repo stub-owner-https/stub-repo-https"
	[ -n "$HTTPS_ARGF" ] && cat "$HTTPS_ARGF"
fi

echo
echo "=== case 6h: a stale scratch worktree left by an earlier crashed run is removed, not mistaken for a live one ==="
SHORT_STALE="$(git -C "$REPO" rev-parse --short=10 "$SHA_STALE_WORKTREE")"
TAG_STALE="win-${SHORT_STALE}"
STALE_WT_DIR="${STATE_DIR}/worktrees/${TAG_STALE}"
mkdir -p "$STALE_WT_DIR"
printf 'leftover from a crashed run\n' >"${STALE_WT_DIR}/leftover-file"
OUT6H="$(run_pipeline "$SHA_STALE_WORKTREE" "${SCRATCH}/suite-green.sh")"
CODE6H=$?
if [ $CODE6H -eq 0 ]; then pass "exits 0 despite a stale worktree directory already sitting at its path"; else fail "exit code $CODE6H, want 0"; echo "$OUT6H"; fi
if [ -f "${STALE_WT_DIR}/leftover-file" ]; then fail "the stale leftover file is still there - the stale worktree wasn't actually replaced"; else pass "the stale worktree (and its leftover file) was removed before this run's real checkout"; fi
if grep -qxF "$TAG_STALE" "$STUB_GH_RELEASES"; then pass "published normally despite the stale worktree"; else fail "expected a release despite the stale worktree"; fi

echo
echo "=== case 7: the worktrees this pipeline made are always cleaned up, and the caller's own working copy is untouched ==="
WT_LIST="$(git -C "$REPO" worktree list --porcelain | grep -c '^worktree ')"
if [ "$WT_LIST" = "1" ]; then pass "no leftover scratch worktrees - only the main checkout remains"; else fail "expected exactly 1 worktree (the main checkout), found ${WT_LIST}"; git -C "$REPO" worktree list; fi
WT_LIST_HTTPS="$(git -C "$REPO_HTTPS" worktree list --porcelain | grep -c '^worktree ')"
if [ "$WT_LIST_HTTPS" = "1" ]; then pass "no leftover scratch worktrees in the https-origin repo either"; else fail "expected exactly 1 worktree in ${REPO_HTTPS}, found ${WT_LIST_HTTPS}"; git -C "$REPO_HTTPS" worktree list; fi
if [ -d "${STATE_DIR}/worktrees" ] && [ -z "$(ls -A "${STATE_DIR}/worktrees" 2>/dev/null)" ]; then pass "the pipeline's own worktree root is empty after every run"; else fail "leftover entries under ${STATE_DIR}/worktrees"; ls -la "${STATE_DIR}/worktrees" 2>&1; fi
STATUS="$(git -C "$REPO" status --porcelain)"
if [ -z "$STATUS" ]; then pass "the caller's own working copy (the scratch 'repo') is clean - untouched by any run"; else fail "the caller's working copy is dirty:"; echo "$STATUS"; fi
if find "$REPO" -name "chextrek.dll" -o -name "chextrek.pdb" 2>/dev/null | grep -q .; then fail "a built DLL/PDB leaked into the caller's own repo"; else pass "no built DLL/PDB ever leaked into the caller's own repo"; fi

echo
echo "=== case 8: pipeline logs are kept outside the repo (CHEXTREK_PIPELINE_STATE_DIR) ==="
LOG_COUNT="$(find "${STATE_DIR}/logs" -name '*.log' 2>/dev/null | wc -l | tr -d ' ')"
if [ "$LOG_COUNT" -ge 14 ]; then pass "one log file per run was kept under ${STATE_DIR}/logs (found ${LOG_COUNT})"; else fail "expected at least 14 log files under ${STATE_DIR}/logs, found ${LOG_COUNT}"; fi
case "$STATE_DIR" in
"$REPO"*) fail "STATE_DIR ($STATE_DIR) is inside the repo - logs would be gitignored plumbing at best, lost worktree cleanup at worst" ;;
*) pass "STATE_DIR is outside the repo" ;;
esac

echo
if [ $FAIL -eq 0 ]; then
	echo "PASS: whole self-test"
	exit 0
else
	echo "FAIL: whole self-test - see above"
	exit 1
fi
