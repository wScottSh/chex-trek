# Dev-machine setup: building and testing `chextrek.dll`

Spec #28/#29. This is the one-time, per-machine setup the build and harness scripts assume.
Everything here is outside this repo on purpose - see "Why none of this lives in the repo" below.

## What's installed where

| Thing | Location | Notes |
|---|---|---|
| VS 18 Build Tools (x86) + bundled CMake | `C:\Program Files (x86)\Microsoft Visual Studio\18\BuildTools\` | Already installed on the dev machine. `tools/build-chextrek.sh` finds CMake under `Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe`. |
| Classic Doom 3 1.3.1 (Steam) | `C:\Program Files (x86)\Steam\steamapps\common\Doom 3` | Has `base\pak000.pk4`-`pak008.pk4`. This is `fs_basepath` / `$DOOM3_BASEPATH`. |
| dhewm3 1.5.5 win32 (official, unmodified) | `C:\Users\Scott\dhewm3\1.5.5-win32\dhewm3\dhewm3.exe` | Downloaded from https://github.com/dhewm/dhewm3/releases/tag/1.5.5 (`dhewm3-1.5.5_win32.zip`). This is `$DHEWM3_HOME`. The engine is never built from source. |
| `chextrek` mount | `C:\Program Files (x86)\Steam\steamapps\common\Doom 3\chextrek` | A **real NTFS symlink** (not a junction, not a copy) to whichever checkout of this repo you're currently testing. The harness (`tools/lib-harness.sh`) creates/repoints it automatically. |
| Save/config/screenshot path | `%USERPROFILE%\Documents\My Games\dhewm3\chextrek\` | dhewm3 hardcodes this on Windows; see "Why none of this lives in the repo". |
| Windows Smart App Control | **Off** | With it on, unsigned game DLLs - including dhewm3's own `base.dll` - are blocked (`LoadLibrary` fails with `0x11C7`, "An Application Control policy has blocked this file"). Must be off for `dhewm3.exe`, `base.dll`, and our own unsigned `chextrek.dll` to load at all. |

Environment variables the scripts read (all optional, default to the table above):

- `DHEWM3_HOME` - the dhewm3 1.5.5 win32 engine's install dir (has `dhewm3.exe` in it).
- `DOOM3_BASEPATH` - the classic Doom 3 1.3.1 install (`fs_basepath`).
- `DHEWM3_DOCUMENTS_DIR` - override for the user's Documents folder, if it's not `$HOME/Documents`.

## Building

```
tools/build-chextrek.sh [Debug|RelWithDebInfo|Release]
```

Configures `engine/dhewm3-sdk` (the pinned dhewm3-sdk import, see `engine/dhewm3-sdk/UPSTREAM.md`)
with CMake for `Visual Studio 18 2026` / Win32, `BASE_NAME=chextrek`, `D3XP=OFF`, builds it with
MSBuild, and copies the resulting `chextrek.dll` (+ `.pdb`) to the repo root. Both are gitignored;
rebuild any time with this one command.

## Running the tests

```
tools/run-all-tests.sh                   # the whole suite: builds once, runs every tools/test-*.sh
tools/run-harness.sh [timeout-seconds]   # just the main-menu smoke run (default timeout: 60s)
```

`tools/run-all-tests.sh` is the one command for the whole suite (spec #28 story 38): it builds
`chextrek.dll`, then runs the harness self-test, the main-menu smoke test and every feature scenario
in turn, and prints a pass/fail summary. It exits 0 if all pass, 1 if any fail, 3 on no display.
`docs/harness-coverage.md` lists which scenario covers which feature. Each `tools/test-*.sh` also
runs on its own (it builds first unless `CHEXTREK_SKIP_BUILD=1`).

Every run, smoke or scenario, goes through `chextrek_run_console_script` in `tools/lib-harness.sh`,
which:

1. Points the `chextrek` symlink at whichever checkout you're running from.
2. Wipes `Documents\My Games\dhewm3\chextrek\` (see below), copies in any scenario fixture files
   (`CHEXTREK_FIXTURE_DIR`), and writes the console script there.
3. Launches `dhewm3.exe` with the mod mounted and that script queued via `+exec`.
4. Kills it if it doesn't exit within the timeout (an error dialog hanging it); that counts as a
   FAIL, reported with the log's last error line.
5. Copies the run's log and screenshots into
   `Documents\My Games\dhewm3\chextrek-harness-artifacts\<run-id>\` - next to dhewm3's own save
   path, never inside this repo - and reports PASS/FAIL for: `chextrek.dll` (not `base.dll`) loaded,
   the `CHEXTREK-STATE-DUMP v1` header appeared, and the spec #28 always-on checks (no `ERROR:`, no
   unknown event/spawnclass, no script-compile error). Each scenario also checks its map finished
   loading (`<N> msec to load <map>`).

`screenshot <name>` writes an extensionless file named exactly `<name>` into the save dir; the
harness archives everything a run leaves there, so screenshots are kept whatever their name. They
are never asserted on.

**Only run one harness invocation at a time on a given machine.** It kills every `dhewm3.exe`
process by image name on timeout (not just the one it started), and concurrent runs - e.g. from
two worktrees at once - would also race on the shared `chextrek` symlink and the shared
`Documents\My Games\dhewm3\chextrek\` save dir.

**The harness needs an active desktop session.** dhewm3 opens a real window, so if this Windows
user session is disconnected (another user switched in on the console, or RDP dropped), SDL dies
with `No displays available`. The harness checks `qwinsta` before launching and the log after each
run; on no display it prints `ENVIRONMENT: no display ...` and exits the whole script with code 3.
Exit 3 is never a test result: stop and get a human to reconnect - don't wait or retry.
`tools/test-harness-no-display.sh` covers this without needing a display.

## Writing a feature scenario

Scenarios `map` into a real level and drive it with console commands. A `tools/test-*.sh` script
writes the *complete* console script (including `developer 1` and a trailing `quit`) to a scratch
file and runs it with `chextrek_run_scenario` (`tools/lib-harness.sh`, which wraps
`tools/run-scenario.sh <scenario-name> <console-script-file> [timeout-seconds]`), then asserts on the
archived log. See `tools/test-script-events.sh` for a full example.

A workaround worth knowing before writing one: the engine's console tokenizer strips quotes from a
typed string literal *before* doom-script's compiler sees it (so `script sys.println( "x" )`
recompiles as the bareword `x`, which fails to compile), and treats a bare `$name` token as *cvar*
expansion, which collides with doom-script's own `$entityName` syntax. Both are worked around with
test-only cvars in `ChexTrekDump.cpp` (`chextrek_test_str1`..`str15`; `str15` holds a vector
literal) whose *values* already contain the quoted strings or entity/def names a scenario needs,
referenced as `$chextrek_test_strN` (a cvar substitution, which survives verbatim) together with
`sys.getEntity( $chextrek_test_strN )` (a runtime name lookup) instead of `$entityName`. See the
comment above those cvars.

Note that `map` resets the `developer` cvar to 0 (engine `Session_Map_f`); the test commands don't
depend on it.

## Why none of this lives in the repo

- **The junction/symlink must be a real NTFS symlink, not a plain `ln -s` fallback.** On this
  toolchain, `ln -s` on a directory silently falls back to a full recursive *copy* when it can't
  get symlink privilege, instead of failing loudly. A copy would make the harness silently test
  stale content. `tools/lib-harness.sh` forces a real symlink with
  `MSYS=winsymlinks:nativestrict` and verifies it with `readlink` before trusting it. If your
  account can't create symlinks, turn on Developer Mode (Settings > Privacy & Security > For
  developers) rather than loosening this.
- **`fs_savepath` can't be redirected via `+set` on this engine build.** dhewm3 resolves its
  Windows save path (`Documents\My Games\dhewm3\<mod>\`) before command-line `+set` overrides are
  applied, so logs/configs/screenshots always land there regardless of what you pass. That's fine:
  it's already outside the repo, which is what the "never write into the repo's mod folder" AC
  cares about. The harness treats it as the scratch save path and wipes it before every run.
- **A stale `dhewm.cfg`/`config.spec` from an earlier hung run changes engine behavior on the next
  run.** One was observed to make the engine hang on what looks like a cached video-mode
  confirmation dialog *before* it even reaches the mod's scripts, well short of the known failure -
  making runs non-reproducible. Wiping the per-mod save dir before every run fixes this and is
  also just good hygiene for a "scratch" path.
- **The engine's log write is buffered and can truncate the last line mid-word when the process is
  killed while blocked on an error dialog.** This is an unmodified, official binary - it isn't
  something we can patch. In practice `^ERROR:` (or the other always-on markers) still show up
  before the truncation point, which is what the harness actually greps for; treat a truncated
  final line as normal, not a bug in the harness.
