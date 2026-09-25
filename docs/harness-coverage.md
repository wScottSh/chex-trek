# Harness coverage record: features -> scenarios

Which of spec #28's features have a scripted AFK-harness scenario proving them. Updated by each
sub-issue as it lands (#29-#46). See `docs/dev-setup.md` for how to run the harness and
`decomp-so/reference/coverage.md` for the *reconstruction's* function-level coverage (a different,
earlier record from spec #16 - that one tracks decompiled functions against reference files; this
one tracks spec #28 features against harness scenarios).

- **Status:** `covered` = a scripted scenario in `tools/` (or a documented harness invocation)
  exercises the feature and the harness's checks pass (or, for #29 only, are expected to report
  red - see its row). `pending` = no scenario yet.
- **Scenario** names the harness entry point that exercises the feature.

## Foundation

| Feature | Scenario | Status |
|---|---|---|
| `chextrek.dll` builds (32-bit x86) from stock dhewm3-sdk, pinned at `ad837f9b1b` | `tools/build-chextrek.sh` | covered |
| AFK harness launches dhewm3 1.5.5 win32 with the mod mounted, drives it via a console script ending in `quit`, kills a hung run after a timeout | `tools/run-harness.sh` | covered |
| Developer-only state-dump console command (`chextrek_dump`), stable header line | `tools/run-harness.sh` asserts `CHEXTREK-STATE-DUMP v1` in the log | covered (header only - #29 lands the skeleton; later sub-issues add state under it as their features land) |
| Harness proves *chextrek.dll* (not `base.dll`) loaded | `tools/run-harness.sh` asserts `loaded game library '...chextrek.dll'` and the state-dump header | covered |
| Harness run to the main menu is green (script compile passes, menu loads) | `tools/run-harness.sh`, `tools/test-menu-smoke.sh` | covered - flipped green by #30 (was expected red under #29; `tools/test-menu-smoke.sh` replaces the old `tools/test-tracer-bullet.sh`, which asserted the opposite) |
| Always-on checks: no `ERROR`, no unknown event/spawnclass, no script-compile error, map finishes loading | `tools/run-harness.sh`, `tools/test-script-events.sh` (loads `e1m1`, asserts `<N> msec to load e1m1`), `tools/test-objectives.sh` (loads `sf_923`, asserts `<N> msec to load sf_923`) | covered. The unknown-spawnclass check (`tools/lib-harness.sh`) matches the engine's real message (`Could not spawn '<classname>'.  Class '<spawnclass>' not found` - the "Unknown spawnclass" text #29 guessed never actually appears) and allowlists exactly one pre-existing, tracked gap by class name (so it applies wherever the class is used, not just on one map): `idTarget_EndLevelGUI` isn't implemented yet (below, "Custom UI + end-level stats"), so `target_endlevelgui_1`/`_2` on both `e1m1` and `sf_923` fail to spawn independently of #30's or #31's own changes. |

## Per-feature (spec #28 order; #30 onward)

| Feature | Scenario | Status |
|---|---|---|
| Script events `openDoors` (`idAI::OpenDoors`/`Event_OpenDoors`), `setProj`, `spawnDict`, `footPrint` (anim frame command + `PlayFootStepSound` lead); `idActor` extra `EV_Remove` entry; `ProjectDecal` 8-arg overload | `tools/test-script-events.sh` | covered - each event's observable effect: `openDoors` opens `e1m1`'s `func_door_17`, `setProj` changes the weapon's `createProjectile()` classname, `spawnDict` spawns an entity from a def, `footPrint`/`ProjectDecal` show up in `chextrek_dump`'s `footprints:` counter, and a script's `remove()` shrinks `chextrek_dump`'s `entities:` counter. `idActor`'s extra `EV_Remove` entry is ported for fidelity to the reconstruction but is behaviorally a no-op (routes to the same `idClass::Event_Remove` already inherited) - not separately observable, see `decomp-so/reference/script-events.md` Notes. |
| Objectives (`mkObjective`) + `idPlayer::addObjective`/`freeObjective`/`addItemText` | `tools/test-objectives.sh` | covered - loads `sf_923` (the only map with `trigger_objective` entities) and triggers both `trigger_objective_1` and `trigger_objective_2`: triggering fills `chextrek_dump`'s `objective_slot_N` with the objective's title, a second trigger on `trigger_objective_1` empties its slot without disturbing `trigger_objective_2`'s, and a `savegame`/`loadgame` round-trip leaves `trigger_objective_2` (the only one still active going into the save) attached and shown in the dump. `addItemText` (the `addmsg`/`rmmsg` messages) is exercised as a side effect of every (re)attach/remove but not separately asserted; nothing in the log distinguishes it from the slot-fill effect it triggers. `idPlayer::HudMapLevel`, which `addObjective` calls to fill `mkObjective::mapLevel`, is a stub returning 0 (`Player.cpp`) - its real body (`decomp-so/reference/hud-map.md`) needs `idPlayer::mapLevels[]` and the rest of the HUD map group's members, not yet ported (see the "HUD map" row below); nothing yet reads `mapLevel`, so the stub is inert. **Confirmed live, not just inferred from the reference:** after a save/load, a lone active objective can come back in a *different* slot than it had before saving (`trigger_objective_2` came back as `objective_slot_1`, not `_2`) - `decomp-so/reference/objectives.md`'s Notes call this out as an open question (`nextObjective` isn't saved, and it's the reconstructed `idPlayer`'s *constructor* that zeroes it back to 0 on the reload - `idPlayer::Restore` never calls `Init()` - so re-attachment order, not original slot, decides the new slot). This is the reconstructed mod's actual behavior, not a harness bug or a regression to fix (spec #28 targets original behavior, not enhancements), so the scenario asserts the exact, deterministic post-load slot (`objective_slot_1`) this produces here, rather than treating the renumbering as untestable. |
| Custom UI + end-level stats (incl. stat counting) | - | pending. `idTarget_EndLevelGUI` not existing yet is why the always-on unknown-spawnclass check above allowlists `e1m1`'s `target_endlevelgui_1`. |
| HUD map | - | pending |
| Door opening (player + AI) | - | pending |
| Trails | - | pending |
| Env shots | - | pending |
| Worldspawn music volume | - | pending |
