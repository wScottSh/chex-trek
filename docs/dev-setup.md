# Dev-machine setup: building and testing `chextrek.dll`

Spec #28/#29. This is the one-time, per-machine setup the build and harness scripts assume.
Everything here is outside this repo on purpose - see "Why none of this lives in the repo" below.

## What's installed where

| Thing | Location | Notes |
|---|---|---|
| VS 18 Build Tools (x86) + bundled CMake | `C:\Program Files (x86)\Microsoft Visual Studio\18\BuildTools\` | Already installed on the dev machine. `tools/build-chextrek.sh` finds CMake under `Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe`. |
| Classic Doom 3 1.3.1 (Steam) | `C:\Program Files (x86)\Steam\steamapps\common\Doom 3` | Has `base\pak000.pk4`-`pak008.pk4`. This is `fs_basepath` / `$DOOM3_BASEPATH`. |
| dhewm3 1.5.5 win32 (official, unmodified) | `C:\Users\Scott\dhewm3\1.5.5-win32\dhewm3\dhewm3.exe` | Downloaded from https://github.com/dhewm/dhewm3/releases/tag/1.5.5 (`dhewm3-1.5.5_win32.zip`). This is `$DHEWM3_HOME`. The engine is never built from source. |
| `chextrek` mount | `C:\Program Files (x86)\Steam\steamapps\common\Doom 3\chextrek` | A **real NTFS symlink** (not a junction, not a copy) to whichever checkout of this repo you're currently testing. `tools/run-harness.sh` creates/repoints it automatically. |
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

## Running the harness

```
tools/run-harness.sh [timeout-seconds]   # default timeout: 60s
```

One command (run `tools/build-chextrek.sh` first - the harness checks for `chextrek.dll` and
tells you to build it if it's missing, but doesn't build it for you):

1. Points the `chextrek` symlink at whichever checkout you're running from.
2. Wipes `Documents\My Games\dhewm3\chextrek\` (see below) and writes a console script there that
   runs `chextrek_dump`, takes a screenshot, and `quit`s.
3. Launches `dhewm3.exe` with the mod mounted and that script queued via `+exec`.
4. Kills it if it doesn't exit within the timeout (an error dialog hanging it).
5. Copies the run's log and any screenshot into
   `Documents\My Games\dhewm3\chextrek-harness-artifacts\<run-id>\` - next to, but never inside,
   this repo - and reports PASS/FAIL for: `chextrek.dll` (not `base.dll`) loaded, the
   `CHEXTREK-STATE-DUMP v1` header appeared, and the spec #28 always-on checks (no `ERROR:`, no
   unknown event/spawnclass, no script-compile error).

Right now (before #30 ports the mod's script events) this is expected to report **red**: the
known `script\chex_events.script, line 2: Unknown event 'openDoors'` failure, reproduced from an
unmodified `dhewm3-sdk` build. That's what proves the tracer bullet works end to end. When it's
red like this, the game hangs on the error dialog before it ever reaches the `screenshot` command
in the console script, so there's no screenshot artifact for a red run - that's expected, not a
bug (screenshots are "saved as artifacts, never asserted").

**Only run one harness invocation at a time on a given machine.** It kills every `dhewm3.exe`
process by image name on timeout (not just the one it started), and concurrent runs - e.g. from
two worktrees at once - would also race on the shared `chextrek` symlink and the shared
`Documents\My Games\dhewm3\chextrek\` save dir.

## Why none of this lives in the repo

- **The junction/symlink must be a real NTFS symlink, not a plain `ln -s` fallback.** On this
  toolchain, `ln -s` on a directory silently falls back to a full recursive *copy* when it can't
  get symlink privilege, instead of failing loudly. A copy would make the harness silently test
  stale content. `tools/run-harness.sh` forces a real symlink with
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
