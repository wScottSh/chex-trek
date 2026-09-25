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
| Always-on checks: no `ERROR`, no unknown event/spawnclass, no script-compile error, map finishes loading | `tools/run-harness.sh`, `tools/test-script-events.sh` (loads `e1m1`) | covered |

## Per-feature (spec #28 order; #30 onward)

| Feature | Scenario | Status |
|---|---|---|
| Script events `openDoors` (`idAI::OpenDoors`/`Event_OpenDoors`), `setProj`, `spawnDict`, `footPrint` (anim frame command + `PlayFootStepSound` lead); `idActor` extra `EV_Remove` entry; `ProjectDecal` 8-arg overload | `tools/test-script-events.sh` | covered - each event's observable effect: `openDoors` opens `e1m1`'s `func_door_17`, `setProj` changes the weapon's `createProjectile()` classname, `spawnDict` spawns an entity from a def, `footPrint`/`ProjectDecal` show up in `chextrek_dump`'s `footprints:` counter, and a script's `remove()` shrinks `chextrek_dump`'s `entities:` counter. `idActor`'s extra `EV_Remove` entry is ported for fidelity to the reconstruction but is behaviorally a no-op (routes to the same `idClass::Event_Remove` already inherited) - not separately observable, see `decomp-so/reference/script-events.md` Notes. |
| Objectives (`mkObjective`) + item text (`addItemText`) | - | pending (#31+) |
| Custom UI + end-level stats (incl. stat counting) | - | pending |
| HUD map | - | pending |
| Door opening (player + AI) | - | pending |
| Trails | - | pending |
| Env shots | - | pending |
| Worldspawn music volume | - | pending |
