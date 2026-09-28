#!/usr/bin/env bash
# Automated test for bug #73: the HUD's ammo battery (hud.gui's ammocharge/chargepercent windows)
# and spare-clip pips (clip1-7) track the current weapon's ammo.
#
# hud.gui reads four HUD gui state vars idPlayer::UpdateHudAmmo sets:
#   - ammocharge's matcolor: "player_ammo" / "player_clipsize" (the meter's fill)
#   - chargepercent's text: "player_ammopercent"
#   - updateAmmo's clip1-7 lighting: "player_clips" (spare clips, not counting the loaded one)
# The original DLL's UpdateHudAmmo (gamex86.so 0x14dbb0) sets, in its ammo-shown branch:
#   player_clipsize    = ClipSize()                                  (SetStateInt)
#   player_ammopercent = ClipSize() ? va( "%.0f%%", inclip * 100.0f / ClipSize() ) : va( "%i", ammo )
#   player_clips       = ClipSize() ? va( "%i", ( ammo - inclip ) / ClipSize() ) : "--"
# chextrek_dump's hud_ammo/weapon_ammo lines (ChexTrekDump.cpp) give the HUD's values next to the
# weapon's own, so this checks them against those formulas without depending on GUI rendering.
#
# Three samples: right after selecting the pistol (clipSize 12, def/weapon_pistol.def); after the
# weapon uses 3 rounds from its clip (inclip drops, so the meter/percent must follow); and after
# another ammo pickup (ammo_bullets_large, +50 - the spare-clip count must rise). The rounds are used with idWeapon's own
# "useAmmo" script event (what weapon scripts call when they fire) because a console script can't
# hold +attack: its tokenizer splits "+attack" into an unknown "+" command.
# chextrek_test_str6 holds "player1" (ChexTrekDump.cpp).
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRATCH_DIR="$(mktemp -d)"
trap 'rm -rf "$SCRATCH_DIR"' EXIT

# shellcheck source=tools/lib-harness.sh
source "${SCRIPT_DIR}/lib-harness.sh"

echo "=== #73 hud-ammo test: build ==="
chextrek_build_or_exit

# chextrek_test_impulse 1 (ChexTrekDump.cpp) is idPlayer::PerformImpulse( 1 ): select weapon slot 1,
# def_weapon1 = weapon_pistol (def/player.def).
CONSOLE_SCRIPT="${SCRATCH_DIR}/hud-ammo.cfg"
cat > "$CONSOLE_SCRIPT" <<'EOF'
developer 1
map e1m1
wait 20
god
give weapon_pistol
wait 5
chextrek_test_impulse 1
wait 60
chextrek_dump
screenshot chextrek_hud_ammo_selected

script sys.getEntity( $chextrek_test_str6 ).getWeaponEntity().useAmmo( 3 )
wait 10
chextrek_dump

give ammo_bullets_large
wait 10
chextrek_dump

screenshot chextrek_hud_ammo
wait 10
quit
EOF

echo
echo "=== #73 hud-ammo test: scenario run ==="

FAIL=0
chextrek_run_scenario chextrek_hud_ammo "$CONSOLE_SCRIPT" 90 || FAIL=1

LOCAL_LOG="$CHEXTREK_SCENARIO_LOG"
if [ -z "$LOCAL_LOG" ]; then
	echo "FAIL: couldn't find the archived log to check scenario-specific assertions"
	exit 1
fi

chextrek_assert_map_loaded "$LOCAL_LOG" e1m1 || FAIL=1

# Pull "<key>=<value>" out of the Nth line starting with "<prefix>: ".
field() { # <prefix> <n> <key>
	grep -E "^$1: " "$LOCAL_LOG" | sed -n "$2p" | tr -d '\r' | grep -oE "(^| )$3=[^ ]*" | sed "s/^ *$3=//"
}

check_sample() { # <n> <label>
	local n="$1" label="$2"
	local inclip avail clipsize hud_ammo hud_clipsize hud_clips hud_percent
	inclip="$(field weapon_ammo "$n" inclip)"
	avail="$(field weapon_ammo "$n" available)"
	clipsize="$(field weapon_ammo "$n" clipsize)"
	hud_ammo="$(field hud_ammo "$n" ammo)"
	hud_clipsize="$(field hud_ammo "$n" clipsize)"
	hud_clips="$(field hud_ammo "$n" clips)"
	hud_percent="$(field hud_ammo "$n" percent)"
	echo "INFO: ${label}: weapon inclip=${inclip} available=${avail} clipsize=${clipsize};" \
		"hud ammo='${hud_ammo}' clipsize='${hud_clipsize}' clips='${hud_clips}' percent='${hud_percent}'"
	if [ -z "$clipsize" ] || [ "$clipsize" -le 0 ]; then
		echo "FAIL: ${label}: expected the pistol (a clip weapon) selected, got weapon clipsize='${clipsize}'"
		FAIL=1
		return
	fi
	local want_percent want_clips
	want_percent="$(awk -v i="$inclip" -v c="$clipsize" 'BEGIN { printf "%.0f%%", i * 100 / c }')"
	want_clips=$(( (avail - inclip) / clipsize ))
	[ "$hud_ammo" = "$inclip" ] && echo "PASS: ${label}: player_ammo = inclip (${inclip})" \
		|| { echo "FAIL: ${label}: player_ammo='${hud_ammo}', want '${inclip}'"; FAIL=1; }
	[ "$hud_clipsize" = "$clipsize" ] && echo "PASS: ${label}: player_clipsize = ${clipsize} (meter fill = ammo/clipsize)" \
		|| { echo "FAIL: ${label}: player_clipsize='${hud_clipsize}', want '${clipsize}' (meter fill = player_ammo/player_clipsize)"; FAIL=1; }
	[ "$hud_percent" = "$want_percent" ] && echo "PASS: ${label}: player_ammopercent = ${want_percent}" \
		|| { echo "FAIL: ${label}: player_ammopercent='${hud_percent}', want '${want_percent}'"; FAIL=1; }
	[ "$hud_clips" = "$want_clips" ] && echo "PASS: ${label}: player_clips = spare clips (${want_clips})" \
		|| { echo "FAIL: ${label}: player_clips='${hud_clips}', want '${want_clips}' ((available - inclip) / clipsize)"; FAIL=1; }
}

check_sample 1 "after selecting the pistol"
check_sample 2 "after using 3 rounds"
check_sample 3 "after another ammo pickup"

INCLIP_BEFORE="$(field weapon_ammo 1 inclip)"
INCLIP_AFTER="$(field weapon_ammo 2 inclip)"
if [ -n "$INCLIP_BEFORE" ] && [ -n "$INCLIP_AFTER" ] && [ "$INCLIP_AFTER" -lt "$INCLIP_BEFORE" ]; then
	echo "PASS: useAmmo drained the clip (${INCLIP_BEFORE} -> ${INCLIP_AFTER})"
else
	echo "FAIL: expected useAmmo to drain the clip, got inclip '${INCLIP_BEFORE}' -> '${INCLIP_AFTER}'"
	FAIL=1
fi

CLIPS_BEFORE="$(field hud_ammo 2 clips)"
CLIPS_AFTER="$(field hud_ammo 3 clips)"
if [[ "$CLIPS_BEFORE" =~ ^[0-9]+$ ]] && [[ "$CLIPS_AFTER" =~ ^[0-9]+$ ]] && [ "$CLIPS_AFTER" -gt "$CLIPS_BEFORE" ]; then
	echo "PASS: the ammo pickup raised the HUD's spare-clip count (${CLIPS_BEFORE} -> ${CLIPS_AFTER})"
else
	echo "FAIL: expected the ammo pickup to raise player_clips, got '${CLIPS_BEFORE}' -> '${CLIPS_AFTER}'"
	FAIL=1
fi

echo
if [ $FAIL -eq 0 ]; then
	echo "PASS: #73 hud-ammo scenario - the HUD's ammo meter and clip pips track the weapon"
	exit 0
else
	echo "FAIL: #73 hud-ammo scenario - see above"
	exit 1
fi
