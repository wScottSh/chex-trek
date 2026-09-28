#!/usr/bin/env bash
# Self-test for tools/run-all-tests.sh's failure reporting (spec #58/#65): a deliberately broken
# change - e.g. a scenario's expected value altered on a branch, which shows up as that scenario's
# own tools/test-*.sh exiting non-zero - must make tools/run-all-tests.sh exit 1 with that scenario
# listed as FAIL in the summary, while every passing scenario still runs and is listed as passed.
# Same scratch-dir/stub pattern as tools/test-run-all-tests-skip-build.sh: this never launches the
# game, it copies run-all-tests.sh into a scratch dir alongside a fake build-chextrek.sh (touches a
# marker instead of building) and fake test-*.sh scripts, one of which deliberately fails, so it
# exercises only run-all-tests.sh's own pass/fail bookkeeping.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRATCH="$(mktemp -d)"
trap 'rm -rf "$SCRATCH"' EXIT
FAIL=0

setup_scratch() {
	rm -rf "${SCRATCH:?}"/*
	mkdir -p "${SCRATCH}/tools"
	cp "${SCRIPT_DIR}/run-all-tests.sh" "${SCRATCH}/tools/run-all-tests.sh"
	cat > "${SCRATCH}/tools/build-chextrek.sh" <<'EOF'
#!/usr/bin/env bash
printf 'built\n' > "$(dirname "${BASH_SOURCE[0]}")/../chextrek.dll"
exit 0
EOF
	chmod +x "${SCRATCH}/tools/build-chextrek.sh"
	cat > "${SCRATCH}/tools/test-a-passing-scenario.sh" <<'EOF'
#!/usr/bin/env bash
echo "PASS: a-passing-scenario"
exit 0
EOF
	chmod +x "${SCRATCH}/tools/test-a-passing-scenario.sh"
	# Stands in for a real scenario whose expected value was deliberately altered on a branch:
	# the scenario script itself is the thing that fails, same shape as a real assertion mismatch.
	cat > "${SCRATCH}/tools/test-b-broken-scenario.sh" <<'EOF'
#!/usr/bin/env bash
echo "FAIL: b-broken-scenario: expected 'Investigate', got 'empty' (deliberately broken for this self-test)"
exit 1
EOF
	chmod +x "${SCRATCH}/tools/test-b-broken-scenario.sh"
	cat > "${SCRATCH}/tools/test-c-passing-scenario.sh" <<'EOF'
#!/usr/bin/env bash
echo "PASS: c-passing-scenario"
exit 0
EOF
	chmod +x "${SCRATCH}/tools/test-c-passing-scenario.sh"
}

setup_scratch
OUT="$(cd "$SCRATCH" && env -u CHEXTREK_SKIP_BUILD bash tools/run-all-tests.sh 2>&1)"
CODE=$?

if [ $CODE -eq 1 ]; then echo "PASS: exits 1 when one scenario fails"; else echo "FAIL: exit code $CODE, want 1"; echo "$OUT"; FAIL=1; fi
if echo "$OUT" | grep -qx "FAIL: test-b-broken-scenario.sh"; then echo "PASS: broken scenario listed as FAIL in the summary"; else echo "FAIL: expected 'FAIL: test-b-broken-scenario.sh' in the summary"; echo "$OUT"; FAIL=1; fi
if echo "$OUT" | grep -q "test-a-passing-scenario.sh" && echo "$OUT" | grep -q "test-c-passing-scenario.sh"; then
	echo "PASS: passing scenarios before and after the broken one still ran"
else
	echo "FAIL: expected both passing scenarios to still run around the broken one"
	echo "$OUT"
	FAIL=1
fi
if ! echo "$OUT" | grep -qx "FAIL: test-a-passing-scenario.sh"; then echo "PASS: passing scenario a not listed as FAIL"; else echo "FAIL: test-a-passing-scenario.sh wrongly listed as FAIL"; FAIL=1; fi
if ! echo "$OUT" | grep -qx "FAIL: test-c-passing-scenario.sh"; then echo "PASS: passing scenario c not listed as FAIL"; else echo "FAIL: test-c-passing-scenario.sh wrongly listed as FAIL"; FAIL=1; fi
if echo "$OUT" | grep -q "1 failed"; then echo "PASS: summary line counts exactly one failure"; else echo "FAIL: expected the summary to count exactly one failure"; echo "$OUT"; FAIL=1; fi

[ $FAIL -eq 0 ] && { echo "PASS: whole self-test"; exit 0; }
echo "FAIL: whole self-test"
exit 1
