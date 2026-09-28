# Dev-machine setup: building and testing `chextrek.dll`

Spec #28/#29 (Windows dev machine), extended by spec #58/#60/#64 (Unicron, Linux/Wine). This is the
one-time, per-machine setup the build and harness scripts assume. Everything here is outside this
repo on purpose - see "Why none of this lives in the repo" below. The harness's *interface*
(`tools/build-chextrek.sh`, `tools/run-harness.sh`, `tools/run-all-tests.sh`, every
`tools/test-*.sh`) is identical on both machines, including `tools/build-chextrek.sh`: same
one-command invocation, same optional build-config argument, same output
(`chextrek.dll`/`chextrek.pdb` at the repo root, gitignored) - only the one-time setup and a few
internals differ.

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

Spec #58/#60/#64. Unicron builds and runs the harness unattended, with nobody ever logged in to a
desktop; the platform layer this needs lives in `tools/lib-harness.sh` behind `chextrek_is_linux`.

| Thing | Location | Notes |
|---|---|---|
| Wine 11.0, new-WoW64 | `/opt/wine-11.0-wow64` (built from source; add `.../bin` to `PATH`) | The WineHQ `noble` packages can't do new-WoW64 (see spike #59's comment on #58 for the full build recipe). Provides `wine`, `winepath` and `wineserver`, all required on `PATH` - without `wineserver` on `PATH` the post-run cleanup below can't run, and a run can hang forever (see "Wine process cleanup"). This is a *separate* Wine install from the one baked into the `tools/msvc-wine/` build-toolchain image below - the harness's Wine runs the game engine, the image's Wine runs the compiler, and their versions don't need to match. |
| Wine prefix | `$WINEPREFIX`, default `$HOME/games/wineprefix-chextrek` | Needs the **VC++ 2015-2022 x86 redist** installed in it (`vc_redist.x86.exe /install /quiet`) - `dhewm3.exe` imports `mfc140.dll`, which Wine has no builtin for; without it the loader fails with `c0000135`. |
| Classic Doom 3 1.3.1 | `$HOME/games/doom3` (has `base/pak000.pk4`-`pak008.pk4`) | Copied once from the Windows PC, outside every repo, same as the Windows machine's copy. This is `$DOOM3_BASEPATH`. |
| dhewm3 1.5.5 win32 (official, unmodified) | `$HOME/games/dhewm3/1.5.5-win32/dhewm3/dhewm3.exe` | The same `dhewm3-1.5.5_win32.zip` as the Windows machine, run under Wine - never built from source. This is `$DHEWM3_HOME`. |
| `chextrek` mount | `$DOOM3_BASEPATH/chextrek` | A plain `ln -s` to whichever checkout is being tested - no NTFS-symlink privilege quirk on Linux. The harness creates/repoints it automatically, same as Windows. |
| Xvfb | anywhere on `PATH` (e.g. the distro package) | The harness starts its own (`chextrek_ensure_display_or_exit` in `tools/lib-harness.sh`) on the first free display number when `$DISPLAY` isn't already usable, and stops it again when the run finishes. Nobody needs to be logged in, and no `DISPLAY` needs to be pre-set - that's the whole point on a headless box reached over SSH. |
| Save/config/screenshot path | `$WINEPREFIX/drive_c/users/<you>/Documents/My Games/dhewm3/chextrek/` | The "Documents" dhewm3 hardcodes is the one inside the Wine prefix it's actually running in, not this Linux user's own `$HOME/Documents`. |
| Docker | already installed, owner in the `docker` group (no `sudo` needed) | Runs the pinned MSVC-under-Wine build-toolchain container below. |
| Build-toolchain image `chextrek-msvc-wine:14.50.18.0-x86` | one-time: `tools/msvc-wine/build-image.sh` | Builds the image from `tools/msvc-wine/Dockerfile`; see "Building `chextrek.dll` on Unicron" below. |

Environment variables (all optional; Linux-specific defaults live in `tools/lib-harness.sh`):

- `DHEWM3_HOME`, `DOOM3_BASEPATH`, `DHEWM3_DOCUMENTS_DIR` - same meaning as on Windows, different
  default paths (the table above).
- `WINEPREFIX` - the Wine prefix dhewm3 runs in. Defaults to `$HOME/games/wineprefix-chextrek`.

### Building `chextrek.dll` on Unicron (spec #64)

One-time setup: `tools/msvc-wine/build-image.sh` builds the `chextrek-msvc-wine:14.50.18.0-x86`
Docker image from `tools/msvc-wine/Dockerfile`. That Dockerfile pins everything a rebuild needs to
reproduce the same compiler months later:

- **msvc-wine** (https://github.com/mstorsjo/msvc-wine, ISC license, not vendored into this repo),
  pinned at a fixed commit, fetches and wraps the real MSVC toolchain so `cl`/`link`/`lib`/etc. run
  transparently under Wine from Linux.
- **MSVC 14.50.18.0 (VS 18), x86-only** - the exact compiler version `tools/build-chextrek.sh`'s
  Windows branch gets from the "Visual Studio 18 2026" generator (spec #28's pin). Downloading it
  requires accepting the Visual Studio Build Tools license terms
  (https://go.microsoft.com/fwlink/?LinkId=2327714 at the time of pinning) - spec #64's AC requires
  the owner to confirm this use is acceptable before this lands; record that confirmation on this
  sub-issue's PR, not here.
- `winbind`, needed for CMake's MSVC probe (`/Zi`+`/FS` spawn a background `mspdbsrv.exe` under
  Wine; without `winbind` that probe fails with `C1902`, a known msvc-wine limitation).

`tools/build-chextrek.sh`'s Linux branch (a `uname` check, the same test `chextrek_is_linux` in
`tools/lib-harness.sh` makes - this script doesn't source that library, so it repeats the check
rather than adding the dependency) then:

1. Checks `docker` is on `PATH` and the pinned image exists - a clear `error:` line pointing at
   `tools/msvc-wine/build-image.sh` if not, never a bare Docker error.
2. Runs `cmake -S engine/dhewm3-sdk -B engine/build -G Ninja` inside that image against this
   checkout (bind-mounted), with the same project options as Windows (`BASE=ON`,
   `BASE_NAME=chextrek`, `D3XP=OFF`), cross-compiling for `CMAKE_SYSTEM_NAME=Windows`/
   `CMAKE_SYSTEM_PROCESSOR=x86`. `CMAKE_EXE_LINKER_FLAGS`/`CMAKE_SHARED_LINKER_FLAGS` are set to
   `/MANIFEST:NO`: this MSVC-under-Wine `link.exe` doesn't produce the side-car manifest CMake's
   default rule expects to feed to `mt.exe` afterwards (`mt` then fails, "File not found") -
   `chextrek.dll` doesn't need a manifest embedded, so the fix is to not ask for one.
3. Builds with `cmake --build engine/build --target base`. An `EXIT` trap `chown`s `engine/build`
   back from `root` (the container's user - it needs `root`'s own wine prefix, baked into the
   image at image-build time) to the invoking user before the container exits either way, so a
   failed configure or build doesn't leave it un-owned by the invoking user.
4. The same shared copy step as Windows then copies the resulting `chextrek.dll`/`.pdb` from
   `engine/build` to the repo root.

The result is a `PE32 executable (DLL), Intel 80386` - the same MSVC-ABI binary format the official
win32 dhewm3 1.5.5 (spec #59) loads. `tools/test-menu-smoke.sh` on Unicron, run without
`CHEXTREK_SKIP_BUILD` set, is the reproducible proof: it builds via this Linux branch, then checks
that result against every always-on check. See the #64 PR for a run of it.

**This is noticeably slower than the Windows/MSBuild build** - every `cl`/`link` invocation pays
Wine per-process startup overhead - expect it to take much longer wall-clock than a native Windows
build of the same config; budget accordingly rather than assuming a hang.

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

**Not handled by #60/#64** (left for later sub-issues, not asserted by anything here): a single-run
lock across concurrent worktrees (two concurrent runs against the same default `$WINEPREFIX` can
still race on each other's wine processes, same as the existing "one run at a time" note below
already says for the shared mount and save dir); the two scenarios spike #59 found Wine-only-red
(`test-end-level-nextmap.sh`, `test-objectives.sh`).

## Building

```
tools/build-chextrek.sh [Debug|RelWithDebInfo|Release]
```

Configures `engine/dhewm3-sdk` (the pinned dhewm3-sdk import, see `engine/dhewm3-sdk/UPSTREAM.md`)
with CMake, `BASE_NAME=chextrek`, `D3XP=OFF`, 32-bit, and copies the resulting `chextrek.dll`
(+ `.pdb`) to the repo root. Both are gitignored; rebuild any time with this one command, on
either machine. On Windows this uses `Visual Studio 18 2026` / Win32 and MSBuild, unchanged since
spec #28/#29. On Unicron (spec #64) this uses Ninja against the pinned MSVC-14.50.18.0-x86-under-
Wine container image - see "Building `chextrek.dll` on Unicron" above for the one-time setup and
what differs.

## Running the tests

```
tools/run-all-tests.sh                   # the whole suite: builds once, runs every tools/test-*.sh
tools/run-harness.sh [timeout-seconds]   # just the main-menu smoke run (default timeout: 60s)
```

`tools/run-all-tests.sh` is the one command for the whole suite (spec #28 story 38): it builds
`chextrek.dll`, then runs the harness self-test, the main-menu smoke test and every feature scenario
in turn, and prints a pass/fail summary. It exits 0 if all pass, 1 if any fail, 3 on a broken-
environment blocker (no display, or, Linux-only, #63: missing Wine/winepath, an uninitialized
Wine prefix, missing Doom 3 data, or a missing dhewm3 engine).
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

**Only run one harness invocation at a time on a given machine.** On Windows it kills every
`dhewm3.exe` process by image name on timeout (not just the one it started). On Unicron a timeout
itself kills only the PID that run started (see "Unicron (Linux/Wine)" above), but the
`wineserver -k` cleanup every run does afterwards stops *every* wine process in `$WINEPREFIX` -
harmless for one run at a time, but two concurrent runs sharing the same default `$WINEPREFIX`
would still be able to kill each other's dhewm3 via that cleanup, on top of racing on the shared
`chextrek` symlink and the shared save dir (`Documents\My Games\dhewm3\chextrek\` on Windows, the
equivalent path inside the Wine prefix on Unicron).

**The harness needs a display to open a window on.** dhewm3 opens a real window, so it needs
somewhere to put it. On the Windows dev machine that's an active desktop session: if this Windows
user session is disconnected (another user switched in on the console, or RDP dropped), SDL dies
with `No displays available`; the harness checks `qwinsta` before launching and the log after each
run, and on no display it prints `ENVIRONMENT: no display ...` and exits the whole script with code
3 - stop and get a human to reconnect, don't wait or retry. On Unicron nobody is ever logged in, so
the harness brings its own display (Xvfb) instead of treating "no display" as that same kind of
stop - see "Unicron (Linux/Wine)" above; exit 3 there means Xvfb itself couldn't be started at all.
`tools/test-harness-no-display.sh` covers both without needing a display itself.

**Every other broken-Unicron-environment case stops the same way (#63), Linux-only.** Before ever
touching a display, on Linux the harness checks that `wine` and `winepath` are on `PATH`, that
`$WINEPREFIX` looks initialized (`system.reg` present), that the classic Doom 3 data is at
`$DOOM3_BASEPATH` (`base/pak000.pk4` present), and that the dhewm3 engine itself is at
`$DHEWM3_HOME`. Any of these missing prints one `ENVIRONMENT: ...` line naming the missing piece
and exits the whole script with code 3, the same contract as the no-display case above - never an
ordinary FAIL, and never a bare "command not found" from a missing `wine`/`winepath` silently
swallowed by a path-conversion call. On Windows a missing dhewm3 engine is unchanged by #63: still
an ordinary FAIL/exit-1 next to chextrek.dll's own missing-build check, not this ENVIRONMENT/exit-3
treatment. `tools/test-harness-broken-environment.sh` covers each of the Linux-only cases in
isolation (a no-op on Windows), without needing any of the real installs
itself.

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
