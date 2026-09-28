# Dev-machine setup: building and testing `chextrek.dll`

Spec #28/#29 (Windows dev machine), extended by spec #58/#60 (Unicron, Linux/Wine). This is the
one-time, per-machine setup the build and harness scripts assume. Everything here is outside this
repo on purpose - see "Why none of this lives in the repo" below. The harness's *interface*
(`tools/build-chextrek.sh`, `tools/run-harness.sh`, `tools/run-all-tests.sh`, every
`tools/test-*.sh`) is identical on both machines; only the one-time setup and a few internals
differ. The one current exception is `tools/build-chextrek.sh` itself, which only knows how to
build on Windows - see "Unicron (Linux/Wine)" below for what that means for `run-all-tests.sh`
until the Linux build step exists.

## Windows dev machine

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

## Unicron (Linux/Wine)

Spec #58/#60. Unicron builds and runs the harness unattended, with nobody ever logged in to a
desktop; the platform layer this needs lives in `tools/lib-harness.sh` behind `chextrek_is_linux`.
Building `chextrek.dll` itself on Linux is a later sub-issue - #60 only covers running the harness
against a prebuilt DLL (built on the Windows dev machine and copied over, or produced by that later
Linux build step once it exists). Until that build step exists, `tools/build-chextrek.sh` only knows
how to build on Windows, so on Unicron: copy a Windows-built `chextrek.dll` (+ `.pdb`) to the repo
root yourself, same gitignored place the Windows build writes to, and set `CHEXTREK_SKIP_BUILD=1`
before running an individual `tools/test-*.sh` (or `tools/run-harness.sh`, which never builds) so it
skips the build step and uses the prebuilt DLL as-is. `tools/run-all-tests.sh` always builds first
regardless of `CHEXTREK_SKIP_BUILD` (it only sets that variable for the `test-*.sh` scripts it goes
on to run) and so can't run on Unicron until the Linux build step exists.

| Thing | Location | Notes |
|---|---|---|
| Wine 11.0, new-WoW64 | `/opt/wine-11.0-wow64` (built from source; add `.../bin` to `PATH`) | The WineHQ `noble` packages can't do new-WoW64 (see spike #59's comment on #58 for the full build recipe). Provides `wine`, `winepath` and `wineserver`, all required on `PATH` - without `wineserver` on `PATH` the post-run cleanup below can't run, and a run can hang forever (see "Wine process cleanup"). |
| Wine prefix | `$WINEPREFIX`, default `$HOME/games/wineprefix-chextrek` | Needs the **VC++ 2015-2022 x86 redist** installed in it (`vc_redist.x86.exe /install /quiet`) - `dhewm3.exe` imports `mfc140.dll`, which Wine has no builtin for; without it the loader fails with `c0000135`. |
| Classic Doom 3 1.3.1 | `$HOME/games/doom3` (has `base/pak000.pk4`-`pak008.pk4`) | Copied once from the Windows PC, outside every repo, same as the Windows machine's copy. This is `$DOOM3_BASEPATH`. |
| dhewm3 1.5.5 win32 (official, unmodified) | `$HOME/games/dhewm3/1.5.5-win32/dhewm3/dhewm3.exe` | The same `dhewm3-1.5.5_win32.zip` as the Windows machine, run under Wine - never built from source. This is `$DHEWM3_HOME`. |
| `chextrek` mount | `$DOOM3_BASEPATH/chextrek` | A plain `ln -s` to whichever checkout is being tested - no NTFS-symlink privilege quirk on Linux. The harness creates/repoints it automatically, same as Windows. |
| Xvfb | anywhere on `PATH` (e.g. the distro package) | The harness starts its own (`chextrek_ensure_display_or_exit` in `tools/lib-harness.sh`) on the first free display number when `$DISPLAY` isn't already usable, and stops it again when the run finishes. Nobody needs to be logged in, and no `DISPLAY` needs to be pre-set - that's the whole point on a headless box reached over SSH. |
| Save/config/screenshot path | `$WINEPREFIX/drive_c/users/<you>/Documents/My Games/dhewm3/chextrek/` | The "Documents" dhewm3 hardcodes is the one inside the Wine prefix it's actually running in, not this Linux user's own `$HOME/Documents`. |

Environment variables (all optional; Linux-specific defaults live in `tools/lib-harness.sh`):

- `DHEWM3_HOME`, `DOOM3_BASEPATH`, `DHEWM3_DOCUMENTS_DIR` - same meaning as on Windows, different
  default paths (the table above).
- `WINEPREFIX` - the Wine prefix dhewm3 runs in. Defaults to `$HOME/games/wineprefix-chextrek`.
- `CHEXTREK_LOCK_FILE` - the single-run lock file (#62, see "Only run one harness invocation at a
  time on a given machine" below). Defaults to `/tmp/chextrek-harness.lock`.

What the Linux platform layer does differently (same `chextrek_run_console_script` interface,
`tools/lib-harness.sh`):

- **Path conversion:** `winepath -w` instead of `cygpath -w`, for the `+set fs_basepath`/
  `+set fs_gameDllPath` command-line values dhewm3 needs in Windows-path form.
- **Display:** starts (or reuses) its own Xvfb instead of checking `qwinsta` for an active desktop
  session - see the Xvfb row above.
- **Mount:** a plain `ln -s`, not the NTFS-symlink dance Windows needs.
- **Launch:** `wine dhewm3.exe ...`, run from the engine's own directory (it looks for
  `SDL2.dll`/`OpenAL32.dll` next to itself) so `timeout` tracks exactly the wine process this call
  started, not a wrapper shell around it.
- **Timeout kill:** `timeout --kill-after` on that same PID - the one this call started - instead
  of Windows' `taskkill //IM dhewm3.exe`, which kills every `dhewm3.exe` on the machine by image
  name (spec #60 AC: "a timeout kills only the dhewm3 process the harness started").
- **Log normalization:** the win32 engine writes `dhewm3log.txt` with CRLF line endings. Git Bash's
  `grep` on Windows tolerates the trailing CR; Linux's doesn't, so every `...$`-anchored always-on
  check would silently fail even though the value is right there (spike #59 finding). The Linux
  branch strips it (`sed -i 's/\r$//'`) before anything greps the log.
- **Wine process cleanup:** `wineserver`/`winedevice.exe` daemonize without closing the fds they
  inherited from the wine invocation that started them - including this call's own stdout/stderr -
  so a freshly-spawned one left running after dhewm3 exits can hold a caller's `$(...)` capture
  (e.g. `tools/run-harness.sh`'s own output, or `chextrek_run_scenario`'s) open indefinitely, well
  past the run actually finishing (spike #59 finding 4). Right after each run, the harness stops
  this run's own `$WINEPREFIX` server with `wineserver -k` (not `-w` - the spike saw *that* hang
  instead, when `winedevice.exe` outlives its display) so those fds close; scoped to one prefix, it
  can't touch a concurrent run's wine processes in a different prefix.

**Not handled by #60** (left for later sub-issues, not asserted by anything here): building
`chextrek.dll` itself on Linux; the two scenarios spike #59 found Wine-only-red
(`test-end-level-nextmap.sh`, `test-objectives.sh`). The single-run lock across concurrent
worktrees is #62 - see "Only run one harness invocation at a time on a given machine" below.

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
3. Launches `dhewm3.exe` with the mod mounted, `+set fs_gameDllPath <this checkout>` so the engine
   loads the freshly built `chextrek.dll` from the repo root (not from the engine's install dir),
   and that script queued via `+exec`.
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

**Only run one harness invocation at a time on a given machine.** On Windows this is still just a
rule: it kills every `dhewm3.exe` process by image name on timeout (not just the one it started),
and two concurrent runs would race on the shared `chextrek` symlink and the shared save dir
(`Documents\My Games\dhewm3\chextrek\`).

On Unicron it's enforced (#62): `chextrek_run_console_script` (`tools/lib-harness.sh`) takes an
exclusive `flock` on a lock file (default `/tmp/chextrek-harness.lock`, override with
`CHEXTREK_LOCK_FILE`) before it touches the `chextrek` symlink or the save dir, and holds it for
the whole run - mount, wipe, launch, the `wineserver -k` cleanup, archiving - releasing it only once
that's all done. A second run that starts while another holds the lock prints
`Waiting for the harness lock ...` and blocks until it's free, instead of racing it; a timeout
itself still kills only the PID that run started (see "Unicron (Linux/Wine)" above), and the
`wineserver -k` cleanup that follows can no longer reach a concurrent run's wine processes in the
same `$WINEPREFIX` because the lock means there never is a concurrent run in progress. The lock is
attached to the run's own open file descriptor on that lock file, not to the file's contents or a
recorded pid, so a run that crashes or is killed - by any signal, including `SIGKILL` - has its fd
closed by the kernel and the lock released right along with it; there is no stale lock file to
clean up by hand. Xvfb, `winepath` and the wine launch itself each close their own inherited copy
of that fd before they exec, so an orphaned Xvfb or wine/dhewm3 a killed run leaves running can't
keep holding the lock either. One caveat: the lock freeing immediately doesn't mean the killed
run's own wine/dhewm3 is gone yet - it can keep running as an orphan for up to its timeout, still
sharing the mount and save dir, until the *next* run's `wineserver -k` cleanup reaps it.
`tools/test-harness-lock.sh` covers this.

**The harness needs a display to open a window on.** dhewm3 opens a real window, so it needs
somewhere to put it. On the Windows dev machine that's an active desktop session: if this Windows
user session is disconnected (another user switched in on the console, or RDP dropped), SDL dies
with `No displays available`; the harness checks `qwinsta` before launching and the log after each
run, and on no display it prints `ENVIRONMENT: no display ...` and exits the whole script with code
3 - stop and get a human to reconnect, don't wait or retry. On Unicron nobody is ever logged in, so
the harness brings its own display (Xvfb) instead of treating "no display" as that same kind of
stop - see "Unicron (Linux/Wine)" above; exit 3 there means Xvfb itself couldn't be started at all.
`tools/test-harness-no-display.sh` covers both without needing a display itself.

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

- **The mount must be a real NTFS symlink, not a plain `ln -s` fallback.** On this
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
  confirmation dialog *before* it even reaches the mod's scripts -
  making runs non-reproducible. Wiping the per-mod save dir before every run fixes this and is
  also just good hygiene for a "scratch" path.
- **The engine's log write is buffered and can truncate the last line mid-word when the process is
  killed while blocked on an error dialog.** This is an unmodified, official binary - it isn't
  something we can patch. In practice `^ERROR:` (or the other always-on markers) still show up
  before the truncation point, which is what the harness actually greps for; treat a truncated
  final line as normal, not a bug in the harness.
