# Harness coverage record: features -> scenarios

Which of spec #28's features are ported and which AFK-harness scenario proves each (spec #28 user
story 39). `decomp-so/reference/coverage.md` is a different record: spec #16's decompiled
functions against the reference files.

- **Run everything:** `bash tools/run-all-tests.sh` builds `chextrek.dll` once, then runs every
  `tools/test-*.sh` and prints a pass/fail summary (exit 0 all pass, 1 any fail, 3 on a broken-
  environment blocker - no display, or, Linux-only: missing wine/winepath/wineserver/flock, an
  uninitialized Wine prefix, missing Doom 3 data, a missing dhewm3 engine, an unopenable lock file,
  or docker/the msvc-wine image missing for the build).
- **Run one feature:** `bash tools/test-<feature>.sh` (game scenarios build first unless
  `CHEXTREK_SKIP_BUILD=1`).
  Setup and environment variables: `docs/dev-setup.md`.
- Every run also makes the always-on checks (`tools/lib-harness.sh`): `chextrek.dll` loaded, the
  state-dump header is present, no `ERROR`/unknown-event/unknown-spawnclass/script-compile line.
  A run the harness had to kill after its timeout is a FAIL, reported with the log's last error
  line. Scenarios that load a map also assert `<N> msec to load <map>` (`chextrek_assert_map_loaded`).
- **Status:** `covered` = the scenario exists and its checks pass. `partially covered` = the
  self-test proves everything it can, but the feature also has an owner-only acceptance check (real
  Windows, a human's own judgment) that no automated test can cover.

## Foundation

| Feature | Scenario | Status |
|---|---|---|
| `chextrek.dll` builds (32-bit x86) from stock dhewm3-sdk pinned at `ad837f9b1b`, on both the Windows dev machine (MSVC/MSBuild) and Unicron (the same MSVC version under Wine, a pinned container image, #64) | `tools/build-chextrek.sh` | covered - `tools/test-menu-smoke.sh` (and every other `tools/test-*.sh`) builds via this script unless `CHEXTREK_SKIP_BUILD=1`, so it also proves the Unicron-built DLL loads and passes the always-on checks, same as a Windows-built one. |
| Harness launches dhewm3 1.5.5 win32 with the mod mounted, drives it with a console script ending in `quit`, kills a hung run after a timeout | `tools/run-harness.sh` (`tools/run-scenario.sh` for any console script) | covered |
| Harness stops at once with exit 3 and one `ENVIRONMENT` line when there's no display (disconnected Windows session), or brings up its own display when none is usable (Unicron/Wine, #60) | `tools/test-harness-no-display.sh` | covered - self-test; on Windows stubs `qwinsta`, on Linux hides Xvfb from `PATH` and separately stubs it to fail to start, never launches the game either way. |
| Harness stops at once with exit 3 and one `ENVIRONMENT` line for every other broken-Unicron-environment case: missing `wine`/`winepath`/`wineserver`/`flock` on `PATH`, an uninitialized Wine prefix, missing Doom 3 data, a missing dhewm3 engine (#63), an unopenable lock file; `tools/build-chextrek.sh` does the same when `docker` is missing, and `tools/run-all-tests.sh` passes a build's exit 3 through | `tools/test-harness-broken-environment.sh`, `tools/test-run-all-tests-skip-build.sh` | covered - self-test; each case checked in isolation with every other resource stubbed present, plus a "nothing missing" case proving none of the checks false-positive. Linux-only (a no-op on Windows); never launches the game. |
| Concurrent runs on Unicron never collide: a single-run `flock` serializes them, a blocked run prints that it's waiting, a crashed/killed run leaves no stale lock (#62) | `tools/test-harness-lock.sh` | covered - Unicron (Linux/Wine)-only, no-op on Windows; mixes the lock primitive in isolation with genuinely concurrent real harness runs, including SIGKILLing a real run mid-flight to prove no stale lock. |
| `chextrek.dll` (not `base.dll`) is the game library that loaded; state-dump command `chextrek_dump` prints a stable header (`CHEXTREK-STATE-DUMP v1`) | always-on checks, every run | covered - each feature below adds its own dump lines. |
| Main menu loads clean (script compile passes), on both the Windows dev machine and Unicron (Linux/Wine, #60) - same script, same interface, unchanged assertions | `tools/test-menu-smoke.sh` | covered - also checks #29's known `openDoors` unknown-event failure is gone. |
| Always-on checks on both real maps (`e1m1`, `sf_923`) | every scenario that loads a map | covered - no allowlist. The unknown-spawnclass check matches the engine's real message (`Could not spawn '<classname>'.  Class '<spawnclass>' not found`). |
| `tools/run-all-tests.sh` skips `build-chextrek.sh` and runs against a prebuilt `chextrek.dll` when the caller pre-sets `CHEXTREK_SKIP_BUILD=1` (Unicron, #61), but still always builds first when it isn't set | `tools/test-run-all-tests-skip-build.sh` | covered - self-test against stubbed `build-chextrek.sh`/`test-*.sh` scripts in a scratch dir; never launches the game. |
| A deliberately broken change - a failing `tools/test-*.sh` - makes `tools/run-all-tests.sh` exit 1 with that scenario listed as `FAIL` in the summary, while passing scenarios before and after it still run (spec #58/#65, so an agent on Unicron can prove a change in game with one command before opening a PR) | `tools/test-run-all-tests-scenario-failure.sh` | covered - self-test against stubbed `build-chextrek.sh`/`test-*.sh` scripts in a scratch dir, one of them deliberately exiting 1; never launches the game. |
| "Process commit X": checks a commit out into its own scratch worktree, runs the full suite, and on green publishes a `win-<sha>` GitHub Release targeting that commit with `chextrek.dll`/`chextrek.pdb`, marked Latest, not prerelease, notes with the suite summary; idempotent; a red or environment-blocker run publishes nothing; two overlapping runs of the same commit never corrupt each other's worktree (spec #58/#66) | `tools/pipeline-process-commit.sh` | covered - `tools/test-pipeline-process-commit.sh` self-test against a scratch git repo, a stub `gh` recording argv, and fake suite scripts standing in for `tools/run-all-tests.sh`'s outcomes; also run for real on Unicron against a real build+suite with a stub `gh` (see PR #66). Never touches a real repo, `gh`, or release. |
| Red/green issue tracking: a red run (exit 1) or an environment blocker (exit 3) opens one `pipeline:red` issue (creating the label if needed) or comments on the open one, worded distinctly for a blocker, with the commit, failing scenarios or `ENVIRONMENT` line, and archive log path; a later genuinely-green run closes it with a comment linking the release; a pipeline error (exit 2), the idempotent already-published path, and a failed `gh issue list` never touch it (spec #58/#67) | `tools/pipeline-process-commit.sh` | covered - `tools/test-pipeline-process-commit.sh` against a stub `gh`; also live-verified once against the real repo with a simulated suite and dry-run releases (see docs/dev-setup.md). |
| AFK trigger: one poll tick fetches `origin/master`, bootstraps without processing history on first run, then hands every new first-parent commit to `tools/pipeline-process-commit.sh`, oldest first, once each; red/blocked results advance the baseline, a pipeline error stops the tick and is retried first next time; force-push divergence resets the baseline and exits 2; a non-blocking lock skips an overlapping tick (spec #58/#68) | `tools/pipeline-poll.sh` | covered - `tools/test-pipeline-poll.sh` (no systemd: local bare `origin`, stub process-commit command). |
| The systemd user timer/oneshot service runs that poll tick with nobody logged in, processes a new commit once, skips an already-processed one, and never runs twice at once (spec #58/#68) | `tools/setup-pipeline-poll-timer.sh`, `tools/systemd/*.tmpl` | partially covered - `tools/test-pipeline-poll-systemd.sh` drives a real throwaway user unit (stub `gh` and suite; SKIPs if `systemctl --user` isn't usable). Reboot survival and the real unit against the real repo are owner-pending (see docs/dev-setup.md). |
| Owner's one command (Windows): refuses on a dirty working tree; resolves the release marked Latest and confirms both assets are attached; downloads `chextrek.dll`/`chextrek.pdb` to a scratch dir; lands detached on that release's exact target commit; moves the DLL/PDB into the checkout root; points the `chextrek` mount at the checkout and launches dhewm3 interactively with `fs_gameDllPath` pointed at it (spec #58/#69) | `tools/fetch-and-play.sh` | partially covered - `tools/test-fetch-and-play.sh` self-test on Unicron against a local bare git remote, a stub `gh`, and stub `wine`/`winepath`/`dhewm3.exe` that record the launch instead of running anything: proves the dirty-tree refusal, release/asset resolution, the detached checkout landing on the release's exact commit (not the branch tip), the download, the mount, and the launch arguments. Cannot prove the engine log shows `chextrek.dll` loaded, or that the game is actually playable - spec #58's own final acceptance checks, owner-only on real Windows (see docs/dev-setup.md). |
| Owner's one command also takes a commit-ish (`tools/fetch-and-play.sh COMMIT`): the dirty-tree refusal above also covers this path; resolves the commit to a full sha, derives that commit's own `win-<short sha>` release tag (spec #66's scheme) and confirms the release's target matches the resolved sha before downloading anything; a commit with no release refuses non-zero, naming the commit, `HEAD` unchanged; the self-rewriting-checkout hazard (the checkout can rewrite `tools/fetch-and-play.sh` itself mid-run) is guarded twice: the script re-execs from a temp copy of itself first, so nothing holds the checkout's copy open during the checkout (Git for Windows' "Unlink of file ... failed"), and the whole body is one `main() { ...; }` function bash fully parses before `git checkout` runs (spec #58/#70) | `tools/fetch-and-play.sh` | partially covered - `tools/test-fetch-and-play.sh` proves: a commit with a green release lands on that exact commit (not Latest/branch tip), with gh looked up by that commit's own tag rather than a no-tag Latest lookup; the dirty-tree refusal on the commit-arg path too; a commit with no release refuses non-zero naming it, `HEAD` unchanged; a release found by tag but targeting a different commit refuses, `HEAD` unchanged; a release commit whose own `tools/fetch-and-play.sh` differs (in the middle, not just appended) from the copy currently running still completes correctly - a mutation-tested proof of the `main()` guard (the same case genuinely fails with it removed); at checkout time no process in the run holds the checkout's own `tools/fetch-and-play.sh` open and the temp copy is already deleted - mutation-tested the same way against the temp-copy guard. Whether Git for Windows then replaces the file cleanly is owner-pending. Same owner-only limits as the row above for the actual play/bisect session. |

## Per-feature (spec #28 order)

| Feature | Scenario | Status |
|---|---|---|
| Script events `openDoors`, `setProj`, `spawnDict`, `footPrint` (anim frame command + `PlayFootStepSound`); `idActor`'s extra `EV_Remove` entry; `ProjectDecal` 8-arg overload (#30) | `tools/test-script-events.sh` | covered - on `e1m1` each event shows its effect: a door opens, the weapon's projectile class changes, an entity spawns, the dump's `footprints` count rises, a script `remove()` drops `entities`. |
| Objectives (`mkObjective`, `idPlayer::addObjective`/`freeObjective`) (#31) | `tools/test-objectives.sh` | covered - on `sf_923`, triggering fills a dump `objective_slot_N`, re-triggering empties it, and the active objective survives save/load (re-attached to slot 1). |
| `idPlayer::addItemText` (#32) | `tools/test-item-text.sh` | covered - replays `sf_923`'s real order (`trigger_once_6`, then the pistol pickup that re-triggers `trigger_objective_1`); the dump's `item_text_last` shows "Objective Complete". Proves the text is queued, not that the HUD draws it. |
| Custom UI (`idCustomUI`) + end-level stats (`idTarget_EndLevelGUI`, stat counting) (#33) | `tools/test-end-level-stats.sh` | covered - on `e1m1`, a kill, a `level_item` pickup and a `secret` door each raise `level_stats` by one, and `target_endlevelgui_1` shows the stats UI with those values; `sf_923`'s screen spawns and activates too. |
| Stats screen `skip`/`nextmap` (`HandleCustomGUICommand`) (#34) | `tools/test-end-level-nextmap.sh` | covered - `skip` x4 jumps each line (monsters, items, secrets, time) to its final value; `nextmap` on a spawned `target_endlevelgui` with `nextmap e1m1` loads `e1m1`. |
| `g_PDA` cvar + `ArgCompletion_GuiName` (#35) | `tools/test-pda.sh` | covered - `idPlayer::Spawn` loads the PDA gui `g_PDA` names (checked with a third, unrelated gui, then the default `guis/pda_chex.gui`), and opening the PDA shows it; `g_PDA`'s completion is `ArgCompletion_GuiName` by address and lists `guis/pda_chex.gui`. |
| PDA key (impulse 19) opens and closes the PDA gui, not just the PDA model's "comm down" screen (bug #48) | `tools/test-pda-impulse.sh` | covered - on `e1m1` (PDA owned from the map's start, as in the bug report), four impulse 19s give `pda_open` 0 -> 1 -> 0 -> 1 -> 0 with `guis/pda_chex.gui`, and it's still open 100 waits after opening; on `office` (no PDA owned) impulse 19 leaves it closed. Fails on the pre-fix code (`pda_open` never leaves 0 on e1m1). |
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
| HUD ammo battery and spare-clip pips (`idPlayer::UpdateHudAmmo`'s `player_clipsize`/`player_ammopercent`/spare-clip `player_clips`) (bug #73) | `tools/test-hud-ammo.sh` | covered - on `e1m1` with the pistol, the dump's `hud_ammo` matches the original DLL's formulas against the weapon's own `weapon_ammo`: after selecting it, after `useAmmo( 3 )` (percent 100% -> 75%), and after an ammo pickup (spare clips 2 -> 6). Proves the HUD state, not that the gui draws it. |

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
