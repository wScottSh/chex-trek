#!/usr/bin/env bash
# systemd-dependent self-test for the AFK trigger (spec #58/#68): proves the *systemd mechanics*
# tools/test-pipeline-poll.sh can't (it has no systemd dependency on purpose) - that a real oneshot
# service runs tools/pipeline-poll.sh -> a stubbed tools/pipeline-process-commit.sh end to end
# (stubbed gh, stubbed suite, a local bare repo as "origin"), processes a newly-pushed commit
# exactly once, skips it on a later fire with nothing new, and is never joined by a second
# concurrent invocation while a run is slow - the last of these via an explicit second
# `systemctl --user start` while a run is confirmed mid-flight (see phase D's own comment for why
# not by waiting on the real timer to happen to re-elapse during a busy window - that turned out to
# be too timing-dependent to assert reliably).
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
	# no trace at all, per spec #58/#68's hard rule (docs/dev-setup.md).
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
	# Bounded wait (never unbounded) for the oneshot service to leave "activating"/"reloading" -
	# i.e. this run of it has finished, one way or another. NOT `systemctl is-active --quiet`: for
	# a oneshot service, `--quiet` only treats "active" as success - but a oneshot's *entire* run
	# (main process still running) is reported as "activating", not "active", and its steady state
	# once the process exits is "inactive". So `is-active --quiet` is already false for the whole
	# duration of a run - a `while is-active --quiet; do ...; done` loop is therefore a no-op: it
	# never actually waits. `ActiveState` read directly is unambiguous instead.
	timeout 30 bash -c "
		while true; do
			state=\$(systemctl --user show -p ActiveState --value '${SERVICE_UNIT}' 2>/dev/null)
			case \"\$state\" in
				activating | reloading) sleep 0.2 ;;
				*) break ;;
			esac
		done
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

# === D: no overlap - a slow run in progress is never joined by a second concurrent run. Proven
# via an *explicit* second `systemctl --user start` while the first is confirmed mid-run (marker
# present), rather than by waiting for the real timer to happen to re-elapse during the busy
# window: empirically (probed by hand while writing this test, against this same systemd/kernel),
# a timer's periodic OnUnitActiveSec elapse while its target unit is still active does not
# reliably produce a second observable trigger attempt within any bounded, test-friendly window -
# systemd defers/coalesces it rather than firing on a fixed schedule regardless of unit state, so
# asserting "the timer fires again during the busy window" would be a flaky, environment-timing-
# dependent test. `systemctl start` on an already-active unit instead goes through the same
# general systemd job-control machinery a timer's own elapse would use to start its target service
# (starting an active unit merges into the in-flight job rather than launching a second execution -
# see the second-start check below for exactly what that means operationally). What this phase
# actually proves is that the *deployed system as a whole* (the unit plus
# tools/pipeline-poll.sh's own non-blocking flock) never lets the suite command run twice at once -
# it does not, on its own, isolate which of those two layers is the one stopping any particular
# concurrent attempt (the poll script's own flock would just as well stop a second poll tick before
# it ever reached the suite command, even if systemd itself allowed a second execution through).
# Both layers are part of the documented no-overlap design (see docs/dev-setup.md's "AFK trigger"
# section), so proving the combined guarantee holds is what matters operationally. ===
OVERLAP_MARKER="${SCRATCH}/slow-run.marker"
OVERLAP_SENTINEL="${SCRATCH}/overlap-detected.sentinel"
CALL_LOG="${SCRATCH}/slow-call.log"
rm -f "$OVERLAP_MARKER" "$OVERLAP_SENTINEL"
: >"$CALL_LOG"
cat >"${SCRATCH}/suite-slow.sh" <<EOF
#!/usr/bin/env bash
echo "call" >> "${CALL_LOG}"
if [ -f "${OVERLAP_MARKER}" ]; then
	touch "${OVERLAP_SENTINEL}"
	echo "FAIL: overlapping run detected"
	exit 1
fi
touch "${OVERLAP_MARKER}"
sleep 4
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
# issue a second, explicit start while it's still going.
systemctl --user start --no-block "$SERVICE_UNIT"
if ! timeout 10 bash -c "until [ -f '${OVERLAP_MARKER}' ]; do sleep 0.1; done"; then
	fail "no-overlap setup: the slow run never signaled it had started"
else
	CALLS_BEFORE_SECOND_START="$(wc -l <"$CALL_LOG")"
	# `systemctl start` against an already-active unit merges into the in-flight job rather than
	# queuing a second execution - but that merge means this call *blocks* until the running
	# instance finishes (confirmed live: it does not return early), not "returns at once" as an
	# earlier version of this comment wrongly claimed. The timeout here is generous (well past the
	# stub's own `sleep 4`) precisely because this call is expected to legitimately take nearly
	# that long - a short timeout here would be a false FAIL on a loaded machine, not a hang caused
	# by a real bug.
	timeout 20 systemctl --user start "$SERVICE_UNIT" >/dev/null 2>&1
	SECOND_START_STATUS=$?
	CALLS_AFTER_SECOND_START="$(wc -l <"$CALL_LOG")"
	if [ "$SECOND_START_STATUS" = "0" ] && [ "$CALLS_AFTER_SECOND_START" = "$CALLS_BEFORE_SECOND_START" ]; then
		pass "no-overlap: an explicit second start while the first run is still in progress merges into it (blocks until it finishes) and never re-invokes the suite command"
	else
		fail "no-overlap: second start status=${SECOND_START_STATUS} (expected 0), calls before=${CALLS_BEFORE_SECOND_START} after=${CALLS_AFTER_SECOND_START} (expected unchanged)"
	fi
	wait_for_service_idle
	if [ -f "$OVERLAP_SENTINEL" ] || [ "$(cat "$CALL_LOG" | wc -l)" != "1" ]; then
		fail "no-overlap: the suite command was invoked more than once, or overlap was directly detected (calls: $(wc -l <"$CALL_LOG"), sentinel present: $([ -f "$OVERLAP_SENTINEL" ] && echo yes || echo no))"
	else
		pass "no-overlap: the suite command was invoked exactly once for the whole busy window"
	fi
fi

# === E: once the slow-run phase settles, the backlog it left behind (commit B) still gets picked
# up on a later poll - proving the concurrent-start attempt above didn't silently drop it ===
systemctl --user start "$SERVICE_UNIT"
wait_for_service_idle
if [ "$(cat "$STATE_FILE" 2>/dev/null)" = "$SHA_B" ]; then
	pass "systemd: commit B is eventually processed once the slow-run phase settles"
else
	fail "systemd: after the slow-run phase, state='$(cat "$STATE_FILE" 2>/dev/null)' expected '${SHA_B}'"
fi

echo
if [ "$FAIL" = "0" ]; then
	echo "PASS: whole suite"
	exit 0
fi
echo "FAIL: tools/test-pipeline-poll-systemd.sh"
exit 1
