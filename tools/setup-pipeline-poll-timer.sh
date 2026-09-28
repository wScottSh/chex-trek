#!/usr/bin/env bash
# Install/enable/disable/status/logs for the AFK trigger (spec #58/#68): a systemd --user oneshot
# service + timer that runs tools/pipeline-poll.sh on a schedule. This script only ever touches
# ~/.config/systemd/user/<unit-name>.{service,timer} and (via systemctl --user) this user's own
# systemd user manager - never system-wide systemd, never root.
#
# Usage:
#   bash tools/setup-pipeline-poll-timer.sh install [--repo-dir DIR] [--interval DURATION] [--branch BRANCH] [--unit-name NAME]
#   bash tools/setup-pipeline-poll-timer.sh enable [--unit-name NAME]
#   bash tools/setup-pipeline-poll-timer.sh disable [--unit-name NAME]
#   bash tools/setup-pipeline-poll-timer.sh status [--unit-name NAME]
#   bash tools/setup-pipeline-poll-timer.sh logs [--unit-name NAME] [--follow]
#   bash tools/setup-pipeline-poll-timer.sh uninstall [--unit-name NAME]
#
# install:   renders tools/systemd/*.tmpl into ~/.config/systemd/user/<unit-name>.{service,timer}
#            (substituting @@REPO_DIR@@/@@INTERVAL@@/@@BRANCH@@) and runs `systemctl --user
#            daemon-reload`. Does NOT enable or start anything - see "enable" below. --repo-dir
#            defaults to this checkout's own root (the one this script lives in); --interval
#            defaults to 10min; --branch defaults to master.
# enable:    `systemctl --user enable --now <unit-name>.timer` - the AC "survives a reboot" step:
#            combined with lingering (already enabled for this user - see docs/dev-setup.md, this
#            script never touches it) this is what makes the timer come back after a reboot with
#            nobody logged in.
# disable:   `systemctl --user disable --now <unit-name>.timer`.
# status:    `systemctl --user status <unit-name>.timer <unit-name>.service` plus the next/last
#            scheduled fire time (`systemctl --user list-timers <unit-name>.timer`).
# logs:      `journalctl --user -u <unit-name>.service` (add --follow to tail -f it).
# uninstall: stops the service if it's currently running, disables the timer (if enabled), removes
#            the two unit files, and runs `systemctl --user daemon-reload` - leaves no trace in
#            `systemctl --user list-units --all`/`list-timers --all`. Use --unit-name to target a
#            throwaway test unit specifically - see spec #58/#68's hard rule (docs/dev-setup.md)
#            about never leaving a live real one installed.
#
# --unit-name lets a throwaway live-test use a name distinct from the real
# "chextrek-pipeline-poll" (e.g. "chextrek-pipeline-test-<random>") so proving the systemd
# mechanics never risks colliding with, or being mistaken for, the real unit.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

UNIT_DIR="${HOME}/.config/systemd/user"
UNIT_NAME="chextrek-pipeline-poll"
REPO_DIR="$REPO_ROOT"
INTERVAL="10min"
BRANCH="master"
FOLLOW=0

usage() {
	cat >&2 <<'EOF'
Usage: bash tools/setup-pipeline-poll-timer.sh <install|enable|disable|status|logs|uninstall> [options]
  install   [--repo-dir DIR] [--interval DURATION] [--branch BRANCH] [--unit-name NAME]
  enable    [--unit-name NAME]
  disable   [--unit-name NAME]
  status    [--unit-name NAME]
  logs      [--unit-name NAME] [--follow]
  uninstall [--unit-name NAME]
EOF
}

CMD="${1:-}"
[ -n "$CMD" ] && shift || true
case "$CMD" in
install | enable | disable | status | logs | uninstall) ;;
*)
	usage
	exit 2
	;;
esac

# require_arg NAME - errors and exits (in *this* shell, not a subshell - see below) unless a value
# follows option NAME ($1, the option itself, already consumed by the caller's `case`). Deliberately
# not called via `$(require_arg "$@")`: `exit` inside a command substitution only ends that
# subshell, not the script - the caller would see an empty captured value and fall through to
# `shift 2`, which silently no-ops when only 1 positional argument is left (shift count out of
# range), leaving $1 unchanged forever and spinning the `while [ $# -gt 0 ]` loop indefinitely.
# Called directly instead, so a missing value's `exit 2` actually ends the script.
require_arg() {
	if [ $# -lt 2 ]; then
		echo "error: ${1} requires a value" >&2
		exit 2
	fi
}

while [ $# -gt 0 ]; do
	case "$1" in
	--repo-dir)
		require_arg "$@"
		REPO_DIR="$2"
		shift 2
		;;
	--interval)
		require_arg "$@"
		INTERVAL="$2"
		shift 2
		;;
	--branch)
		require_arg "$@"
		BRANCH="$2"
		shift 2
		;;
	--unit-name)
		require_arg "$@"
		UNIT_NAME="$2"
		shift 2
		;;
	--follow)
		FOLLOW=1
		shift
		;;
	*)
		echo "error: unknown option '$1'" >&2
		usage
		exit 2
		;;
	esac
done

if ! command -v systemctl >/dev/null 2>&1; then
	echo "error: systemctl not found - this script only supports systemd user services" >&2
	exit 2
fi

SERVICE_UNIT="${UNIT_NAME}.service"
TIMER_UNIT="${UNIT_NAME}.timer"

# sed_escape STR - STR with every sed replacement-side special character (\, &, and this script's
# own #-delimiter) backslash-escaped, so it's safe to drop into a `s#@@X@@#STR#g` replacement no
# matter what characters STR itself contains (a repo checked out under a path containing '#' or
# '&' would otherwise corrupt the substitution or silently insert the wrong text).
sed_escape() {
	printf '%s' "$1" | sed -e 's/[\&#]/\\&/g'
}

case "$CMD" in
install)
	# WorkingDirectory= in the rendered unit must be absolute - systemd rejects a relative one
	# outright, and a relative --repo-dir would otherwise render some path relative to wherever
	# this script happened to be invoked from, not what the caller meant.
	if [ ! -d "$REPO_DIR" ]; then
		echo "error: --repo-dir '${REPO_DIR}' isn't a directory" >&2
		exit 2
	fi
	REPO_DIR="$(cd "$REPO_DIR" && pwd)"
	if [ ! -f "${REPO_DIR}/tools/pipeline-poll.sh" ]; then
		echo "error: ${REPO_DIR}/tools/pipeline-poll.sh not found - --repo-dir must be a checkout of this repo with tools/pipeline-poll.sh in it" >&2
		exit 2
	fi
	mkdir -p "$UNIT_DIR"
	sed \
		-e "s#@@REPO_DIR@@#$(sed_escape "$REPO_DIR")#g" \
		-e "s#@@BRANCH@@#$(sed_escape "$BRANCH")#g" \
		"${SCRIPT_DIR}/systemd/chextrek-pipeline-poll.service.tmpl" >"${UNIT_DIR}/${SERVICE_UNIT}"
	sed \
		-e "s#@@INTERVAL@@#$(sed_escape "$INTERVAL")#g" \
		"${SCRIPT_DIR}/systemd/chextrek-pipeline-poll.timer.tmpl" >"${UNIT_DIR}/${TIMER_UNIT}"
	# The timer's [Service]-adjacent unit name must match the service being timed - systemd infers
	# "<name>.service" from "<name>.timer" by default (no explicit Unit= needed in [Timer]), which
	# is exactly why the two files share $UNIT_NAME here.
	systemctl --user daemon-reload
	echo "installed ${UNIT_DIR}/${SERVICE_UNIT} and ${UNIT_DIR}/${TIMER_UNIT} (repo-dir=${REPO_DIR}, branch=${BRANCH}, interval=${INTERVAL})"
	echo "not enabled yet - run: tools/setup-pipeline-poll-timer.sh enable --unit-name ${UNIT_NAME}"
	;;
enable)
	systemctl --user enable --now "$TIMER_UNIT"
	echo "enabled and started ${TIMER_UNIT}"
	;;
disable)
	systemctl --user disable --now "$TIMER_UNIT"
	echo "disabled ${TIMER_UNIT}"
	;;
status)
	systemctl --user status "$TIMER_UNIT" "$SERVICE_UNIT" --no-pager || true
	echo
	systemctl --user list-timers "$TIMER_UNIT" --all --no-pager || true
	;;
logs)
	if [ "$FOLLOW" = "1" ]; then
		journalctl --user -u "$SERVICE_UNIT" --follow
	else
		journalctl --user -u "$SERVICE_UNIT" --no-pager
	fi
	;;
uninstall)
	systemctl --user disable --now "$TIMER_UNIT" 2>/dev/null || true
	systemctl --user stop "$SERVICE_UNIT" 2>/dev/null || true
	rm -f "${UNIT_DIR}/${SERVICE_UNIT}" "${UNIT_DIR}/${TIMER_UNIT}"
	systemctl --user daemon-reload
	systemctl --user reset-failed "$SERVICE_UNIT" "$TIMER_UNIT" 2>/dev/null || true
	echo "removed ${UNIT_DIR}/${SERVICE_UNIT} and ${UNIT_DIR}/${TIMER_UNIT}"
	;;
esac
