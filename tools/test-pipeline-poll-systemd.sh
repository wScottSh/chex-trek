#!/usr/bin/env bash
# systemd-dependent self-test for the AFK trigger (spec #58/#68): proves the *systemd mechanics*
# tools/test-pipeline-poll.sh can't (it has no systemd dependency on purpose) - that a real timer
# fires a real oneshot service, that service runs tools/pipeline-poll.sh -> a stubbed
# tools/pipeline-process-commit.sh end to end (stubbed gh, stubbed suite, a local bare repo as
# "origin"), processes a newly-pushed commit exactly once, skips it on the next fire, and never
# runs two instances of the service concurrently even when a run is slow.
#
# Skips cleanly (exit 0, prints SKIP) if `systemctl --user` isn't usable in this environment (no
# user session/lingering/D-Bus reachable) - this is a live-mechanics proof, not something CI or a
# bare container should be expected to provide.
#
# Uses a throwaway, uniquely-named unit ("chextrek-pipeline-test-<pid>-<random>") for the whole
# run, and unconditionally disables + removes it (and runs `systemctl --user daemon-reload`) on
# every exit path, success or failure - this must never leave a real-looking unit installed. Never
# touches the real "chextrek-pipeline-poll" unit name, never points at the real
# wScottSh/chex-trek repo, never uses a real `gh`.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! timeout 5 systemctl --user list-units >/dev/null 2>&1; then
	echo "SKIP: systemctl --user isn't usable in this environment - skipping the systemd-dependent live-mechanics test"
	exit 0
fi

UNIT_NAME="chextrek-pipeline-test-$$-${RANDOM}"
SERVICE_UNIT="${UNIT_NAME}.service"
TIMER_UNIT="${UNIT_NAME}.timer"
UNIT_DIR="${HOME}/.config/systemd/user"

SCRATCH="$(mktemp -d)"
FAIL=0

pass() { echo "PASS: $*"; }
fail() {
	echo "FAIL: $*"
	FAIL=1
}

cleanup() {
	systemctl --user disable --now "$TIMER_UNIT" >/dev/null 2>&1 || true
	systemctl --user stop "$SERVICE_UNIT" >/dev/null 2>&1 || true
	rm -f "${UNIT_DIR}/${SERVICE_UNIT}" "${UNIT_DIR}/${TIMER_UNIT}"
	systemctl --user daemon-reload >/dev/null 2>&1 || true
	# A oneshot run that failed (e.g. the no-overlap check's rejected second start) can otherwise
	# leave a "not-found/failed" ghost entry in `systemctl --user list-units --all` even after its
	# unit file is gone - reset-failed clears that transient record so this throwaway unit leaves
	# no trace at all, per this ticket's hard rule.
	systemctl --user reset-failed "$SERVICE_UNIT" "$TIMER_UNIT" >/dev/null 2>&1 || true
	rm -rf "$SCRATCH"
}
trap cleanup EXIT

# --- bare "origin" + a separate pusher clone ---
ORIGIN="${SCRATCH}/origin.git"
git init -q --bare -b master "$ORIGIN"
PUSHER="${SCRATCH}/pusher"
git clone -q "$ORIGIN" "$PUSHER"
git -C "$PUSHER" config user.email test@example.invalid
git -C "$PUSHER" config user.name "Pipeline Poll Systemd Test"
git -C "$PUSHER" commit -q --allow-empty -m "seed"
git -C "$PUSHER" push -q origin master

# --- the unit's own repo checkout: a real clone with the real poll/process scripts copied in ---
REPO_DIR="${SCRATCH}/repo"
git clone -q "$ORIGIN" "$REPO_DIR"
mkdir -p "${REPO_DIR}/tools"
cp "${SCRIPT_DIR}/pipeline-poll.sh" "${REPO_DIR}/tools/pipeline-poll.sh"
cp "${SCRIPT_DIR}/pipeline-process-commit.sh" "${REPO_DIR}/tools/pipeline-process-commit.sh"

# --- stub gh: release view/create only (green-path publish + idempotent skip is all this test
# needs - the red/green issue-tracking logic is tools/test-pipeline-process-commit.sh's job) ---
mkdir -p "${SCRATCH}/bin"
export STUB_GH_RELEASES="${SCRATCH}/gh-releases.txt"
: >"$STUB_GH_RELEASES"
cat >"${SCRATCH}/bin/gh" <<'STUBEOF'
#!/usr/bin/env bash
set -u
if [ "${1:-}" = "release" ] && [ "${2:-}" = "view" ]; then
	TAG="${3:-}"
	if grep -qxF "$TAG" "${STUB_GH_RELEASES}" 2>/dev/null; then
		echo "https://example.invalid/releases/${TAG}"
		exit 0
	fi
	echo "release not found" >&2
	exit 1
fi
if [ "${1:-}" = "release" ] && [ "${2:-}" = "create" ]; then
	TAG="${3:-}"
	printf '%s\n' "$TAG" >>"${STUB_GH_RELEASES}"
	echo "https://example.invalid/releases/${TAG}"
	exit 0
fi
if [ "${1:-}" = "label" ] || [ "${1:-}" = "issue" ]; then
	exit 0
fi
echo "stub gh: unhandled invocation: $*" >&2
exit 1
STUBEOF
chmod +x "${SCRATCH}/bin/gh"

# --- stub suite: green in ~1s, writes the expected DLL/PDB assets. A separate "slow" variant for
# the no-overlap check below records concurrent-invocation evidence via a marker file. ---
cat >"${SCRATCH}/suite-green.sh" <<'EOF'
#!/usr/bin/env bash
printf 'stub-dll\n' > chextrek.dll
printf 'stub-pdb\n' > chextrek.pdb
echo "=== summary: 1 passed, 0 failed ==="
echo "PASS: whole suite"
exit 0
EOF
chmod +x "${SCRATCH}/suite-green.sh"

STATE_DIR="${SCRATCH}/state"
mkdir -p "$STATE_DIR"

# --- install via the real setup script (exercises tools/setup-pipeline-poll-timer.sh's own
# install path: template rendering + daemon-reload), then append the pipeline-specific
# overrides (stub gh on PATH, stub suite, isolated state dir, stub --repo) the fixed template
# doesn't know about, and daemon-reload once more to pick them up ---
bash "${SCRIPT_DIR}/setup-pipeline-poll-timer.sh" install \
	--repo-dir "$REPO_DIR" --branch master --interval 3s --unit-name "$UNIT_NAME" >/dev/null

{
	printf 'Environment=PATH=%s/bin:%s\n' "$SCRATCH" "$PATH"
	printf 'Environment=CHEXTREK_PIPELINE_STATE_DIR=%s\n' "$STATE_DIR"
	printf 'Environment=CHEXTREK_PIPELINE_REPO=stub-owner/stub-repo\n'
	# Quoted: an unquoted systemd Environment= value containing a space (the suite command has one
	# between "bash" and its script path) is invalid syntax - systemd splits it into multiple
	# bogus assignments and logs "Invalid environment assignment, ignoring" instead of setting the
	# variable at all, which silently left CHEXTREK_PIPELINE_SUITE_CMD unset the first time this
	# test was written.
	printf 'Environment="CHEXTREK_PIPELINE_SUITE_CMD=bash %s/suite-green.sh"\n' "$SCRATCH"
	printf 'Environment=STUB_GH_RELEASES=%s\n' "$STUB_GH_RELEASES"
} >>"${UNIT_DIR}/${SERVICE_UNIT}"
systemctl --user daemon-reload

STATE_FILE="${STATE_DIR}/poller-last-processed"

wait_for_service_idle() {
	# Bounded wait (never unbounded) for the oneshot service to leave "activating"/"active" -
	# i.e. this run of it has finished, one way or another.
	timeout 30 bash -c "
		while systemctl --user is-active --quiet '${SERVICE_UNIT}'; do sleep 0.2; done
	"
}

# === A: a manual run bootstraps the baseline (first-ever run) without publishing anything ===
systemctl --user start "$SERVICE_UNIT"
wait_for_service_idle
if [ -f "$STATE_FILE" ]; then
	pass "systemd: first service run bootstraps the state file"
else
	fail "systemd: first service run didn't create ${STATE_FILE}"
fi

# === B: pushing a new commit and firing the service once processes it exactly once and publishes
# a release for it ===
SHA_A="$(git -C "$PUSHER" commit -q --allow-empty -m "commit A" && git -C "$PUSHER" rev-parse HEAD)"
git -C "$PUSHER" push -q origin master
systemctl --user start "$SERVICE_UNIT"
wait_for_service_idle
TAG_A="win-$(git -C "$REPO_DIR" rev-parse --short=10 "$SHA_A")"
if [ "$(cat "$STATE_FILE" 2>/dev/null)" = "$SHA_A" ] && grep -qxF "$TAG_A" "$STUB_GH_RELEASES"; then
	pass "systemd: a real service run processes a newly-pushed commit and publishes its release"
else
	fail "systemd: after processing, state='$(cat "$STATE_FILE" 2>/dev/null)' expected '${SHA_A}'; releases='$(cat "$STUB_GH_RELEASES")' expected to contain '${TAG_A}'"
fi

# === C: firing again with nothing new is a clean no-op (no duplicate release attempt) ===
RELEASES_BEFORE="$(cat "$STUB_GH_RELEASES")"
systemctl --user start "$SERVICE_UNIT"
wait_for_service_idle
if [ "$(cat "$STUB_GH_RELEASES")" = "$RELEASES_BEFORE" ]; then
	pass "systemd: firing again with nothing new changes nothing"
else
	fail "systemd: an idle fire changed releases: before='${RELEASES_BEFORE}' after='$(cat "$STUB_GH_RELEASES")'"
fi

# === D: no overlap - a slow run in progress is never joined by a second concurrent run, even when
# the timer's own interval (3s) is shorter than the run itself ===
OVERLAP_MARKER="${SCRATCH}/slow-run.marker"
OVERLAP_SENTINEL="${SCRATCH}/overlap-detected.sentinel"
rm -f "$OVERLAP_MARKER" "$OVERLAP_SENTINEL"
cat >"${SCRATCH}/suite-slow.sh" <<EOF
#!/usr/bin/env bash
if [ -f "${OVERLAP_MARKER}" ]; then
	touch "${OVERLAP_SENTINEL}"
	echo "FAIL: overlapping run detected"
	exit 1
fi
touch "${OVERLAP_MARKER}"
sleep 6
rm -f "${OVERLAP_MARKER}"
printf 'stub-dll\n' > chextrek.dll
printf 'stub-pdb\n' > chextrek.pdb
echo "=== summary: 1 passed, 0 failed ==="
echo "PASS: whole suite"
exit 0
EOF
chmod +x "${SCRATCH}/suite-slow.sh"
sed -i "s#^Environment=\"CHEXTREK_PIPELINE_SUITE_CMD=.*#Environment=\"CHEXTREK_PIPELINE_SUITE_CMD=bash ${SCRATCH}/suite-slow.sh\"#" "${UNIT_DIR}/${SERVICE_UNIT}"
systemctl --user daemon-reload

SHA_B="$(git -C "$PUSHER" commit -q --allow-empty -m "commit B" && git -C "$PUSHER" rev-parse HEAD)"
git -C "$PUSHER" push -q origin master

# Start the slow run without blocking, wait for it to actually be mid-run (marker present), then
# rely on the timer (3s interval, shorter than the 6s sleep) to attempt to fire again while it's
# still going, and also try an explicit second manual start - both must not run concurrently with
# the first. Enable the timer only for this phase.
systemctl --user start --no-block "$SERVICE_UNIT"
if ! timeout 10 bash -c "until [ -f '${OVERLAP_MARKER}' ]; do sleep 0.1; done"; then
	fail "no-overlap setup: the slow run never signaled it had started"
else
	systemctl --user enable --now "$TIMER_UNIT" >/dev/null
	# A second explicit manual start while the first is still running: systemd's own singleton
	# semantics for a unit that's already active means this either no-ops or queues behind it -
	# either way it must never let the stub suite see two concurrent invocations.
	systemctl --user start "$SERVICE_UNIT" >/dev/null 2>&1 || true
	wait_for_service_idle
	systemctl --user disable --now "$TIMER_UNIT" >/dev/null 2>&1 || true
	if [ -f "$OVERLAP_SENTINEL" ]; then
		fail "no-overlap: an overlapping run was detected while the first run was still in progress"
	else
		pass "no-overlap: the timer and a manual start during a slow run never produced a concurrent invocation"
	fi
fi

echo
if [ "$FAIL" = "0" ]; then
	echo "PASS: whole suite"
	exit 0
fi
echo "FAIL: tools/test-pipeline-poll-systemd.sh"
exit 1
