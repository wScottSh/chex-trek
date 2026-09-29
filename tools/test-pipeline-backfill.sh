#!/usr/bin/env bash
# Self-test for tools/pipeline-backfill.sh. A local scratch repo (no origin, no network) with PR-style
# merge commits; CHEXTREK_PIPELINE_BACKFILL_CMD points at a stub that records each commit it's called
# with and returns a scripted exit code - pipeline-process-commit.sh --backfill's own behavior is
# tools/test-pipeline-process-commit.sh's job (case 9). Covers: a single commit; an A..B range expands
# to B's first-parent commits only (merge commits, never the feature commits they merged in), oldest
# first; a red commit (1) doesn't stop the run but makes it exit 1; an environment blocker (3) or
# pipeline error (2) stops the run there; an unresolvable commit or empty range fails (exit 2)
# before anything is built; no arguments is a usage error.
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

REPO="${SCRATCH}/repo"
mkdir -p "${REPO}/tools"
cp "${SCRIPT_DIR}/pipeline-backfill.sh" "${REPO}/tools/pipeline-backfill.sh"
git -C "$REPO" init -q -b master
git -C "$REPO" config user.email test@example.invalid
git -C "$REPO" config user.name "Pipeline Backfill Test"
git -C "$REPO" commit -q --allow-empty -m "seed"
BASE="$(git -C "$REPO" rev-parse HEAD)"

# merge_pr NAME - a feature branch with two commits, merged into master with --no-ff (this repo's
# PR shape). Prints the merge commit's sha.
merge_pr() {
	git -C "$REPO" checkout -q -b "$1"
	git -C "$REPO" commit -q --allow-empty -m "$1 commit 1"
	git -C "$REPO" commit -q --allow-empty -m "$1 commit 2"
	git -C "$REPO" checkout -q master
	git -C "$REPO" merge -q --no-ff -m "Merge $1" "$1"
	git -C "$REPO" rev-parse HEAD
}
M1="$(merge_pr pr-one)"
M2="$(merge_pr pr-two)"
M3="$(merge_pr pr-three)"

cat >"${SCRATCH}/stub.sh" <<'EOF'
#!/usr/bin/env bash
SHA="${1:?missing sha}"
echo "$SHA" >>"$STUB_CALLS"
CODE="$(awk -v s="$SHA" '$1==s{print $2; exit}' "$STUB_EXITCODES" 2>/dev/null)"
exit "${CODE:-0}"
EOF
export STUB_CALLS="${SCRATCH}/calls.log"
export STUB_EXITCODES="${SCRATCH}/exitcodes.txt"
export CHEXTREK_PIPELINE_BACKFILL_CMD="bash \"${SCRATCH}/stub.sh\""

backfill() {
	: >"$STUB_CALLS"
	OUT="$(cd "$REPO" && bash tools/pipeline-backfill.sh "$@" 2>&1)"
	CODE=$?
	CALLS="$(tr '\n' ' ' <"$STUB_CALLS")"
}

: >"$STUB_EXITCODES"
backfill "$M2"
if [ "$CODE" = "0" ] && [ "$CALLS" = "${M2} " ]; then pass "a single commit is backfilled once, exit 0"; else fail "single commit: exit=$CODE calls='${CALLS}'"; fi

backfill "${BASE}..master"
if [ "$CODE" = "0" ] && [ "$CALLS" = "${M1} ${M2} ${M3} " ]; then
	pass "A..B expands to the merge commits only, oldest first"
else
	fail "range: exit=$CODE calls='${CALLS}' expected '${M1} ${M2} ${M3} '"
fi

printf '%s 1\n' "$M1" >"$STUB_EXITCODES"
backfill "${BASE}..master"
if [ "$CODE" = "1" ] && [ "$CALLS" = "${M1} ${M2} ${M3} " ] && printf '%s' "$OUT" | grep -q "${M1} red - no release"; then
	pass "a red commit doesn't stop the run; it's reported and the run exits 1"
else
	fail "red commit: exit=$CODE calls='${CALLS}'"
fi

printf '%s 3\n' "$M2" >"$STUB_EXITCODES"
backfill "${BASE}..master"
if [ "$CODE" = "3" ] && [ "$CALLS" = "${M1} ${M2} " ] && printf '%s' "$OUT" | grep -q "1 later commit(s) not attempted"; then
	pass "an environment blocker stops the run there (exit 3), later commits not attempted"
else
	fail "environment blocker: exit=$CODE calls='${CALLS}'"
fi

printf '%s 2\n' "$M1" >"$STUB_EXITCODES"
backfill "${BASE}..master"
if [ "$CODE" = "2" ] && [ "$CALLS" = "${M1} " ]; then pass "a pipeline error stops the run there (exit 2)"; else fail "pipeline error: exit=$CODE calls='${CALLS}'"; fi

: >"$STUB_EXITCODES"
backfill "$M1" not-a-commit
if [ "$CODE" = "2" ] && [ -z "$CALLS" ]; then pass "an unresolvable commit fails (exit 2) before anything is built"; else fail "bad commit: exit=$CODE calls='${CALLS}'"; fi

backfill "master..master"
if [ "$CODE" = "2" ] && [ -z "$CALLS" ]; then pass "an empty range fails (exit 2) before anything is built"; else fail "empty range: exit=$CODE calls='${CALLS}'"; fi

backfill
if [ "$CODE" = "2" ] && [ -z "$CALLS" ]; then pass "no arguments is a usage error (exit 2)"; else fail "no args: exit=$CODE calls='${CALLS}'"; fi

echo
if [ "$FAIL" = "0" ]; then
	echo "PASS: whole suite"
	exit 0
fi
echo "FAIL: tools/test-pipeline-backfill.sh"
exit 1
