#!/usr/bin/env bash
# Automated test for spec #45's acceptance criterion (decomp-so/reference/worldspawn.md, ported
# this sub-issue into the existing stock game/WorldSpawn.h/.cpp: idWorldspawn::Save/Think plus the
# "edit inside the stock Spawn" lead that sets g_MusicVolume modified and turns thinking on):
#   AC: change g_MusicVolume; log/dump shows the music volume follows it
#
# g_MusicVolume (WorldSpawn.cpp) is a menu-slider cvar (guis/mainmenu.gui's "Ingame Music" slider)
# idWorldspawn::Think applies to the map's own music sound each time the cvar is modified. Think
# itself, and the stock StopSound/StartSoundShader/Event_FadeSound calls it makes, log nothing an
# AFK harness can read - the sound engine's actual playback dB isn't observable from the log at
# all - so #45 adds a test-only hook (ChexTrek_NoteMusicVolume, ChexTrekDump.cpp) Think calls right
# after each apply, and three new chextrek_dump lines: `music_volume_applied_count` (proves Think
# actually re-ran, not just that the cvar's stored value changed), `music_volume_last` (the cvar's
# own value at that apply), `music_volume_stopped` (whether that apply stopped the music,
# g_MusicVolume < 1).
#
# e1m1's worldspawn sets s_shader/s_volume/s_looping/s_global, so it's the map to use for a
# scenario that needs Think to actually reach its "start/fade the sound" branch (a map with no
# s_shader never starts one - refSound.shader stays NULL there).
#
# Scenario: one `map e1m1`, then three `set g_MusicVolume <N>` console commands in the same live
# session - 80 (still audible), 0 (the "stop the music" branch), 45 (audible again) - each followed
# by a `wait` and a `chextrek_dump`, directly exercising the AC's own path: the slider changing the
# cvar while already in a map, with idWorldspawn::Think (already active from map start via the
# "edit inside stock Spawn" lead) reacting live. `wait 30` between each `set` and its
# `chextrek_dump`: per #43/#44's own findings, a console-script "wait" tick is one real rendered
# frame (a few ms each on this build), not a fixed server-tick count, so a thinner margin (e.g.
# `wait 5`) can land short of even one real game/server frame - `wait 30` is comfortably past that,
# the same order of margin #42's own AC1 scenario uses after a spawn.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRATCH_DIR="$(mktemp -d)"
trap 'rm -rf "$SCRATCH_DIR"' EXIT

# shellcheck source=tools/lib-harness.sh
source "${SCRIPT_DIR}/lib-harness.sh"

echo "=== #45 music-volume test: build ==="
chextrek_build_or_exit

CONSOLE_SCRIPT="${SCRATCH_DIR}/music_volume.cfg"
cat > "$CONSOLE_SCRIPT" <<'EOF'
developer 1
map e1m1
wait 20
chextrek_dump

set g_MusicVolume 80
wait 30
chextrek_dump

set g_MusicVolume 0
wait 30
chextrek_dump

set g_MusicVolume 45
wait 30
chextrek_dump

screenshot chextrek_music_volume
wait 10
quit
EOF

echo
echo "=== #45 music-volume test: scenario run ==="

FAIL=0
chextrek_run_scenario chextrek_music_volume "$CONSOLE_SCRIPT" 120 || FAIL=1

LOCAL_LOG="$CHEXTREK_SCENARIO_LOG"
if [ -z "$LOCAL_LOG" ]; then
	echo "FAIL: couldn't find the archived log to check scenario-specific assertions"
	exit 1
fi

# --- e1m1 finishes loading (spec #28 always-on check) ---
chextrek_assert_map_loaded "$LOCAL_LOG" e1m1 || FAIL=1

# Four chextrek_dump calls in the script above, in order: (1) baseline (map start, no `set` yet -
# the cvar's own compiled-in default, 50), (2) after `set g_MusicVolume 80`, (3) after
# `set g_MusicVolume 0`, (4) after `set g_MusicVolume 45` - all three `set`s live, in the same map
# session, each proving idWorldspawn::Think reacted to that specific change.
COUNT_VALUES="$(chextrek_line_field_values "$LOCAL_LOG" music_volume_applied_count)"
LAST_VALUES="$(chextrek_line_field_values "$LOCAL_LOG" music_volume_last)"
STOPPED_VALUES="$(chextrek_line_field_values "$LOCAL_LOG" music_volume_stopped)"

# expect_dump N EXPECTED_LAST EXPECTED_STOPPED LABEL
# Asserts dump #N's music_volume_last/_stopped match, and its music_volume_applied_count is
# strictly greater than the previous dump's (proving Think actually re-ran for this change, not
# just that the cvar's stored value happened to already read back correctly).
PREV_COUNT=0
expect_dump() {
	local N="$1" EXP_LAST="$2" EXP_STOPPED="$3" LABEL="$4"
	local COUNT LAST STOPPED
	COUNT="$(echo "$COUNT_VALUES" | sed -n "${N}p")"
	LAST="$(echo "$LAST_VALUES" | sed -n "${N}p")"
	STOPPED="$(echo "$STOPPED_VALUES" | sed -n "${N}p")"
	echo "dump #${N} (${LABEL}): applied_count=${COUNT} last=${LAST} stopped=${STOPPED}"
	if [ -n "$COUNT" ] && [ "$COUNT" -gt "$PREV_COUNT" ] && [ "$LAST" = "$EXP_LAST" ] && [ "$STOPPED" = "$EXP_STOPPED" ]; then
		echo "PASS: ${LABEL} (music_volume_last=${LAST}, stopped=${STOPPED}, applied_count ${PREV_COUNT} -> ${COUNT})"
	else
		echo "FAIL: expected ${LABEL} - music_volume_last=${EXP_LAST} stopped=${EXP_STOPPED} applied_count>${PREV_COUNT}; got count='${COUNT}' last='${LAST}' stopped='${STOPPED}'"
		FAIL=1
	fi
	PREV_COUNT="$COUNT"
}

expect_dump 1 "50.000000" "0" "Think already applied the default g_MusicVolume (50) at map start, not stopped"
expect_dump 2 "80.000000" "0" "the music volume follows a live 'set g_MusicVolume 80'"
expect_dump 3 "0.000000" "1" "the music volume follows a live 'set g_MusicVolume 0' (stops the music)"
expect_dump 4 "45.000000" "0" "the music volume follows a live 'set g_MusicVolume 45' (resumes, not stopped)"

echo
if [ $FAIL -eq 0 ]; then
	echo "PASS: #45 music-volume scenario - g_MusicVolume changes follow live through idWorldspawn::Think, including the stop-the-music branch below 1"
	exit 0
else
	echo "FAIL: #45 music-volume scenario - see above"
	exit 1
fi
