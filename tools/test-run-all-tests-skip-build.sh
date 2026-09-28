#!/usr/bin/env bash
# Self-test for tools/run-all-tests.sh's build step (spec #58/#61): on Unicron there is no Linux
# build step yet, so a caller pre-sets CHEXTREK_SKIP_BUILD=1 and copies a prebuilt chextrek.dll to
# the repo root themselves before calling tools/run-all-tests.sh, which must then skip
# build-chextrek.sh and run the suite against that prebuilt DLL as-is - see docs/dev-setup.md's
# "Unicron (Linux/Wine)" section. This never launches the game: it copies run-all-tests.sh into a
# scratch dir alongside a fake build-chextrek.sh (touches a marker instead of building) and fake
# test-*.sh scripts (just exit 0), so it exercises only the build-skipping logic itself.
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
touch "$(dirname "${BASH_SOURCE[0]}")/../build-was-called"
printf 'built\n' > "$(dirname "${BASH_SOURCE[0]}")/../chextrek.dll"
exit 0
EOF
	chmod +x "${SCRATCH}/tools/build-chextrek.sh"
	cat > "${SCRATCH}/tools/test-fake.sh" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
	chmod +x "${SCRATCH}/tools/test-fake.sh"
}

# --- case 1: CHEXTREK_SKIP_BUILD unset -> always builds, regardless of a prebuilt DLL already
# sitting there (a stale env var must never silently skip a build on the Windows dev machine) ---
setup_scratch
printf 'stale\n' > "${SCRATCH}/chextrek.dll"
OUT="$(cd "$SCRATCH" && env -u CHEXTREK_SKIP_BUILD bash tools/run-all-tests.sh 2>&1)"
CODE=$?
if [ -f "${SCRATCH}/build-was-called" ]; then echo "PASS: build-chextrek.sh runs when CHEXTREK_SKIP_BUILD is unset"; else echo "FAIL: build-chextrek.sh was not called with CHEXTREK_SKIP_BUILD unset"; FAIL=1; fi
if [ $CODE -eq 0 ]; then echo "PASS: exits 0 (fake scenario passed)"; else echo "FAIL: exit code $CODE, want 0"; echo "$OUT"; FAIL=1; fi

# --- case 2: CHEXTREK_SKIP_BUILD=1 preset and a prebuilt DLL exists -> build is skipped, suite
# still runs against that DLL ---
setup_scratch
printf 'prebuilt\n' > "${SCRATCH}/chextrek.dll"
OUT="$(cd "$SCRATCH" && CHEXTREK_SKIP_BUILD=1 bash tools/run-all-tests.sh 2>&1)"
CODE=$?
if [ ! -f "${SCRATCH}/build-was-called" ]; then echo "PASS: build-chextrek.sh not called when CHEXTREK_SKIP_BUILD=1 is preset"; else echo "FAIL: build-chextrek.sh was called anyway"; FAIL=1; fi
if [ "$(cat "${SCRATCH}/chextrek.dll")" = "prebuilt" ]; then echo "PASS: prebuilt chextrek.dll left untouched"; else echo "FAIL: chextrek.dll was overwritten"; FAIL=1; fi
if [ $CODE -eq 0 ]; then echo "PASS: exits 0 against the prebuilt DLL"; else echo "FAIL: exit code $CODE, want 0"; echo "$OUT"; FAIL=1; fi

# --- case 3: CHEXTREK_SKIP_BUILD=1 preset but no chextrek.dll at the repo root -> fails fast with
# a clear error, never runs any test-*.sh ---
setup_scratch
OUT="$(cd "$SCRATCH" && CHEXTREK_SKIP_BUILD=1 bash tools/run-all-tests.sh 2>&1)"
CODE=$?
if [ $CODE -eq 1 ]; then echo "PASS: exits 1 when the prebuilt DLL is missing"; else echo "FAIL: exit code $CODE, want 1"; FAIL=1; fi
if echo "$OUT" | grep -qi "chextrek.dll"; then echo "PASS: error mentions chextrek.dll"; else echo "FAIL: expected an error mentioning chextrek.dll"; echo "$OUT"; FAIL=1; fi
if [ -f "${SCRATCH}/build-was-called" ]; then echo "FAIL: build-chextrek.sh was called anyway"; FAIL=1; else echo "PASS: build-chextrek.sh not called"; fi

[ $FAIL -eq 0 ] && { echo "PASS: whole self-test"; exit 0; }
echo "FAIL: whole self-test"
exit 1
