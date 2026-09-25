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
| Harness reproduces the known script-compile failure (`script\chex_events.script, line 2: Unknown event 'openDoors'`) as red, with the offending line | `tools/run-harness.sh` (run against current data, before #30 ports the script events) | covered - expected red until #30 |
| Always-on checks: no `ERROR`, no unknown event/spawnclass, no script-compile error, map finishes loading | `tools/run-harness.sh` | covered for the error checks; "map finishes loading" has no scenario yet - blocked on #30 (nothing loads a map until script compile passes) |

## Per-feature (spec #28 order; #30 onward)

| Feature | Scenario | Status |
|---|---|---|
| Script events (`openDoors`, `setProj`, `spawnDict`, `footPrint`), `idActor` `EV_Remove`, `ProjectDecal` overload; menu/`e1m1`/`sf_923` load | - | pending (#30) |
| Objectives (`mkObjective`) + item text (`addItemText`) | - | pending (#31+) |
| Custom UI + end-level stats (incl. stat counting) | - | pending |
| HUD map | - | pending |
| Door opening (player + AI) | - | pending |
| Trails | - | pending |
| Env shots | - | pending |
| Worldspawn music volume | - | pending |
