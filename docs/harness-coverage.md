# Harness coverage record: features -> scenarios

Which of spec #28's features are ported and which AFK-harness scenario proves each (spec #28 user
story 39). `decomp-so/reference/coverage.md` is a different record: spec #16's decompiled
functions against the reference files.

- **Run everything:** `tools/run-all-tests.sh` builds `chextrek.dll` once, then runs every
  `tools/test-*.sh` and prints a pass/fail summary (exit 0 all pass, 1 any fail, 3 no display).
- **Run one feature:** `tools/test-<feature>.sh` (game scenarios build first unless
  `CHEXTREK_SKIP_BUILD=1`).
  Setup and environment variables: `docs/dev-setup.md`.
- Every run also makes the always-on checks (`tools/lib-harness.sh`): `chextrek.dll` loaded, the
  state-dump header is present, no `ERROR`/unknown-event/unknown-spawnclass/script-compile line.
  A run the harness had to kill after its timeout is a FAIL, reported with the log's last error
  line. Scenarios that load a map also assert `<N> msec to load <map>` (`chextrek_assert_map_loaded`).
- **Status:** `covered` = the scenario exists and its checks pass.

## Foundation

| Feature | Scenario | Status |
|---|---|---|
| `chextrek.dll` builds (32-bit x86) from stock dhewm3-sdk pinned at `ad837f9b1b` | `tools/build-chextrek.sh` | covered |
| Harness launches dhewm3 1.5.5 win32 with the mod mounted, drives it with a console script ending in `quit`, kills a hung run after a timeout | `tools/run-harness.sh` (`tools/run-scenario.sh` for any console script) | covered |
| Harness stops at once with exit 3 and one `ENVIRONMENT` line when there's no display (disconnected Windows session) | `tools/test-harness-no-display.sh` | covered - self-test; stubs `qwinsta`, never launches the game. |
| `chextrek.dll` (not `base.dll`) is the game library that loaded; state-dump command `chextrek_dump` prints a stable header (`CHEXTREK-STATE-DUMP v1`) | always-on checks, every run | covered - each feature below adds its own dump lines. |
| Main menu loads clean (script compile passes) | `tools/test-menu-smoke.sh` | covered - also checks #29's known `openDoors` unknown-event failure is gone. |
| Always-on checks on both real maps (`e1m1`, `sf_923`) | every scenario that loads a map | covered - no allowlist. The unknown-spawnclass check matches the engine's real message (`Could not spawn '<classname>'.  Class '<spawnclass>' not found`). |

## Per-feature (spec #28 order)

| Feature | Scenario | Status |
|---|---|---|
| Script events `openDoors`, `setProj`, `spawnDict`, `footPrint` (anim frame command + `PlayFootStepSound`); `idActor`'s extra `EV_Remove` entry; `ProjectDecal` 8-arg overload (#30) | `tools/test-script-events.sh` | covered - on `e1m1` each event shows its effect: a door opens, the weapon's projectile class changes, an entity spawns, the dump's `footprints` count rises, a script `remove()` drops `entities`. |
| Objectives (`mkObjective`, `idPlayer::addObjective`/`freeObjective`) (#31) | `tools/test-objectives.sh` | covered - on `sf_923`, triggering fills a dump `objective_slot_N`, re-triggering empties it, and the active objective survives save/load (re-attached to slot 1). |
| `idPlayer::addItemText` (#32) | `tools/test-item-text.sh` | covered - replays `sf_923`'s real order (`trigger_once_6`, then the pistol pickup that re-triggers `trigger_objective_1`); the dump's `item_text_last` shows "Objective Complete". Proves the text is queued, not that the HUD draws it. |
| Custom UI (`idCustomUI`) + end-level stats (`idTarget_EndLevelGUI`, stat counting) (#33) | `tools/test-end-level-stats.sh` | covered - on `e1m1`, a kill, a `level_item` pickup and a `secret` door each raise `level_stats` by one, and `target_endlevelgui_1` shows the stats UI with those values; `sf_923`'s screen spawns and activates too. |
| Stats screen `skip`/`nextmap` (`HandleCustomGUICommand`) (#34) | `tools/test-end-level-nextmap.sh` | covered - `skip` x4 jumps each line (monsters, items, secrets, time) to its final value; `nextmap` on a spawned `target_endlevelgui` with `nextmap e1m1` loads `e1m1`. |
| `g_PDA` cvar + `ArgCompletion_GuiName` (#35) | `tools/test-pda.sh` | covered - `idPlayer::Spawn` loads the PDA gui `g_PDA` names (checked with a third, unrelated gui, then the default `guis/pda_chex.gui`), and opening the PDA shows it; `g_PDA`'s completion is `ArgCompletion_GuiName` by address and lists `guis/pda_chex.gui`. |
| HUD map: impulse 23 toggle, fog-of-war reveal (#36) | `tools/test-hud-map.sh` | covered - on `e1m1`, impulse 23 flips the dump's `hud_map visible` 0 -> 1 -> 0, and `coverage` grows after each of three `setviewpos` moves. |
| PDA map `map_*` zoom/scroll/center/stop commands (#37) | `tools/test-pda-map.sh` | covered - every `map_*` command's `mapControl` bit and its effect on `mapScale`/`mapView`, plus both branches of `map_stop`, checked in the dump. |
| `showMap` console command (#38) | `tools/test-show-map.sh` | covered - plain `showMap` gives full coverage (16384 texels); `showMap 1` leaves the player's own level 0 unchanged. |
| HUD map state survives save/load (#39) | `tools/test-hud-map-saveload.sh` | covered - `coverage`, `mapScale` and `level` after load match the pre-save values, though `coverage` and `mapScale` were changed between save and load; no "Location below lowest MapLevel" warning. |
| Player door opening: `tryOpen` on `IMPULSE_16`, `g_doorTraceDist` (#40) | `tools/test-door-open.sh` | covered - on `sf_923`, the use key opens an unlocked door in range, does nothing out of range, and works once `g_doorTraceDist` is raised. |
| Locked doors: `lockedtext` and `requires` tips (#41) | `tools/test-door-locked.sh` | covered - `sf_923`'s `hbdoor1` shows its `lockedtext`; `e1m1`'s Blue Key door shows the "You need a Blue Key" tip and stays shut, then opens once the key is given. |
| AI door opening: `canopendoors` + `OpenDoors` from blocked movement (#42) | `tools/test-ai-door-open.sh` | covered - a spawned monster walked into `sf_923`'s `func_door_1` opens it; with `canopendoors 0` it is blocked by the same door and the door stays shut. |
| Trails (`mkTrail`, `idGameLocal::trails`/`BabySitTrail`/`RemoveTrail`) (#43) | `tools/test-trails.sh` | covered - on `sf_923` a spawned flemoid adds exactly one trail, which survives its removal and is deleted after the fade; the map's own trails have anchors at load. A static grep checks for no pointer-to-int casts. |
| Env shots (`func_envshot`, `takeEnvShots`) (#44) | `tools/test-env-shots.sh` | covered - on `e1m1`, `takeEnvShots` shoots one spawned `func_envshot`: log shows `1 envShots taken` and the engine's `Wrote env/...`; all six faces exist, 32 px wide (the fixture's `size`). |
| Worldspawn music volume (`g_MusicVolume`, `idWorldspawn::Think`) (#45) | `tools/test-music-volume.sh` | covered - on `e1m1`, setting `g_MusicVolume` to 80, 0, 45 mid-map re-runs `Think` each time; the dump shows each value applied, 0 stopping the music, 45 resuming it. |
| New Game plays `sf_923` clean, its exit loads `e1m1`, which plays clean (#46) | `tools/test-new-game.sh` | covered - from the main menu, `sf_923` then `e1m1` each run 300 frames clean with stable trail counts (18, 19) and `level_stats` totals (27/30/1, 22/34/3). |

## Recorded deviations, port choices and known gaps

Detail lives where each bullet points; this list is the index.

**Test code in the library.**
- The test surface beyond `chextrek_dump` (`ChexTrek_Note*` recorders, `chextrek_test_str1..15`
  cvars, five input stand-in commands) is a recorded deviation from spec #28's "only test code"
  clause: `engine/dhewm3-sdk/game/ChexTrekDump.h`, top comment.
- Test commands aren't gated on `developer`, because the engine's `map` command resets it to 0
  (`Session_Map_f`); same file.
- Scenario fixture data (e.g. `test-trails.sh`'s fast-fade trail entityDef) is written per run and
  copied into the scratch save path via `CHEXTREK_FIXTURE_DIR` (`tools/lib-harness.sh`); none
  ships in the mod's data.

**Port choices and fixes beyond the reconstruction** (each in that reference file's Notes).
- `idTarget_EndLevelGUI::Spawn` zeroes `ticSound` (crash fix); `idMover_Binary` `secret`/
  `secretFound` are saved (binary unchecked): `decomp-so/reference/end-level-stats.md`.
- `idPlayer` constructor defaults for the unsaved HUD-map members (a savegame load never runs
  `Spawn`/`Init`); `hudmap_alpha` saved in one bulk write: `decomp-so/reference/hud-map.md`.
- `mkTrail`: `callbackData` instead of the `entityNum` pointer cast; `addNewAnchor` bounds guard
  and `MapClear` deleting trails (fixes); `idActor` `hasTrail`/`trail` defaults, not saved:
  `decomp-so/reference/trails.md`.
- `canOpenDoors` saved; one `OpenDoors` call per move function (`FlyMove`'s two listed addresses
  left as an open lead): `decomp-so/reference/door-opening.md`.
- `idWorldspawn::Save( idSaveGame * )` declared `const`; `EV_FadeSound` made `static` (link
  clash): `decomp-so/reference/worldspawn.md`.
- `FC_FOOTPRINT` field use, `footprintRight` left uninitialized, `EV_Remove` entry ported as a
  no-op: `decomp-so/reference/script-events.md`.

**Original-mod bugs kept** (spec #28 Out of Scope; they don't crash).
- `mkTrail::lastPos` uninitialized: about half of `sf_923`'s trails never update or anchor, so
  the spawned trail's anchor count is INFO only (`decomp-so/reference/trails.md`).
- After a load, objectives are renumbered in re-attach order (confirmed live: slot 2 came back as
  slot 1) (`decomp-so/reference/objectives.md`). Env-shot `renderView_t` leak
  (`decomp-so/reference/env-shots.md`).

**What the scenarios don't prove.**
- `idActor`'s extra `EV_Remove` entry is behaviorally a no-op, so not separately observable.
- `addItemText`: the HUD rendering path (`hud.gui`'s commented-out `invPickup`) isn't checked.
- `showMap <level>`: the dump reports only the player's current level, so filling the named level
  isn't directly seen.
- `view_x`/`view_y`/`control` aren't asserted after a load (not saved, by the binary's design).
- AI doors: only the `SlideMove` copy of the `OpenDoors` call is exercised (no flying monster).
- Env shots: whether `RenderScene` sets `tr.primaryView` outside the frame (the faces could come
  from the player's view) and the `atSpawn` path stay open. The written faces sit under the
  scratch save dir's `env/`, which the harness doesn't archive.
- New Game: `startgame sf_923` is a GUI-only command (`Unknown command` from a console script),
  so the scenario uses `map sf_923`; the exit fires `target_endlevel_3` (`nextMap e1m1`) with
  `trigger` instead of clicking through `end_trek.gui`.
- `nextmap`: no shipped `target_endlevelgui` sets a `nextmap` spawnArg, so the scenario spawns one.

**Harness facts for scenario writers.**
- A console `wait` tick is one rendered frame, a few ms of game time that varies by run, not a
  fixed server tick; scenarios poll with margin rather than trust one fixed wait.
- `hud.gui`'s and `pda_chex.gui`'s `hudmap_close` flip `gui::HudMap` to 0 at `onTime 400` (game
  time): `test-hud-map.sh` samples the close repeatedly; `test-pda-map.sh` re-sends
  `chextrek_test_pda_map_open 1` around every step.
- A bare `CHEXTREK-STATE-DUMP v1` header is sometimes flushed early during a map load, so
  multi-dump scenarios read fields by dump position (`chextrek_line_field_values`).
