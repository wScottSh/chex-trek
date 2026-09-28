# Dev-machine setup: building and testing `chextrek.dll`

Spec #28/#29 (Windows dev machine), extended by spec #58/#60/#61/#64 (Unicron, Linux/Wine). This
is the one-time, per-machine setup the build and harness scripts assume. Everything here is outside
this repo on purpose - see "Why none of this lives in the repo" below. The harness's *interface*
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

Spec #58/#60/#61/#64/#65. If you're an agent working on Unicron: `docs/agents/unicron-build-test.md`
has the one command to run and when to run it (before opening a PR on any game-library change) -
this section covers the one-time machine setup and internals that command depends on.

Unicron builds and runs the harness unattended, with nobody ever logged in to
a desktop; the platform layer this needs lives in `tools/lib-harness.sh` behind `chextrek_is_linux`.
`tools/build-chextrek.sh` builds `chextrek.dll` on Unicron too (#64 - see "Building `chextrek.dll`
on Unicron" below), so `tools/run-all-tests.sh` and every `tools/test-*.sh` build first by default,
same as on Windows. To run against a prebuilt DLL instead (e.g. one built on the Windows dev machine
and copied to the repo root, the same gitignored place the build writes to), set
`CHEXTREK_SKIP_BUILD=1` before running an individual `tools/test-*.sh` (`tools/run-harness.sh` never
builds) so it skips the build step and uses that DLL as-is. `tools/run-all-tests.sh` (#61) honors a
`CHEXTREK_SKIP_BUILD=1` set *before* it's called the same way: it skips `build-chextrek.sh` and runs
the whole suite against whatever `chextrek.dll` already sits at the repo root, failing fast with a
clear error if there isn't one. Left unset (the default), it always builds first.

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
| Build-toolchain image `chextrek-msvc-wine:14.50.35717-x86` | one-time: `tools/msvc-wine/build-image.sh` | Builds the image from `tools/msvc-wine/Dockerfile`; see "Building `chextrek.dll` on Unicron" below. |

Environment variables (all optional; Linux-specific defaults live in `tools/lib-harness.sh`):

- `DHEWM3_HOME`, `DOOM3_BASEPATH`, `DHEWM3_DOCUMENTS_DIR` - same meaning as on Windows, different
  default paths (the table above).
- `WINEPREFIX` - the Wine prefix dhewm3 runs in. Defaults to `$HOME/games/wineprefix-chextrek`.
- `CHEXTREK_LOCK_FILE` - the single-run lock file (#62, see "Only run one harness invocation at a
  time on a given machine" below). Defaults to `/tmp/chextrek-harness.lock`.

### Building `chextrek.dll` on Unicron (spec #64)

One-time setup: `tools/msvc-wine/build-image.sh` builds the `chextrek-msvc-wine:14.50.35717-x86`
Docker image from `tools/msvc-wine/Dockerfile`. That Dockerfile pins everything a rebuild needs to
reproduce the same MSVC toolset months later:

- **msvc-wine** (https://github.com/mstorsjo/msvc-wine, ISC license, not vendored into this repo),
  pinned at a fixed commit, fetches and wraps the real MSVC toolchain so `cl`/`link`/`lib`/etc. run
  transparently under Wine from Linux.
- **MSVC 14.50.35717 (VS 18), x86-only** - the same MSVC toolset `tools/build-chextrek.sh`'s
  Windows branch gets from the "Visual Studio 18 2026" generator (spec #28's pin). Downloading it
  requires accepting the Visual Studio Build Tools license terms
  (https://go.microsoft.com/fwlink/?LinkId=2327714 at the time of pinning) - spec #64's AC requires
  the owner to confirm this use is acceptable before this lands; record that confirmation on this
  sub-issue's PR, not here.
- `winbind`, needed for `mspdbsrv.exe` (`/FS`-forced synchronous PDB writes still invoke it even
  though nothing on Linux compiles with `/Zi` any more, or it's pre-started directly by
  `tools/build-chextrek.sh` - see "Building `chextrek.dll` on Unicron" below) to work at all under
  Wine; without `winbind` it fails with `C1902`, a known msvc-wine limitation.

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

**mspdbsrv pre-start, and why:** `mspdbsrv.exe` (spawned under `/Zi`/`/FS` for PDB writes) is a
long-lived background daemon; the first `cl.exe` invocation that needs it and finds none running
spawns it *itself*, and it inherits that `cl` invocation's stdout/stderr pipe - the one msvc-wine's
`sed` output filter reads from. Because `mspdbsrv` keeps that pipe's write end open long after the
`cl` that spawned it has exited, `sed` (and so that one build step) blocks waiting for EOF until
`mspdbsrv`'s own idle-shutdown timer closes it - about 10 minutes, observed to hit twice during a
from-scratch configure (once per compiler-ABI probe) and again during the first real compile.
`tools/build-chextrek.sh`'s Linux branch now starts `mspdbsrv.exe` itself first, stdio pointed at
`/dev/null`, before configuring, so every `cl.exe` invocation connects to that already-running
instance instead of spawning (and stalling behind) a new one; it also configures with
`-DCMAKE_MSVC_DEBUG_INFORMATION_FORMAT=$<$<CONFIG:Debug,RelWithDebInfo>:Embedded>` (CMake >= 3.25,
msvc-wine's documented workaround, restricted by that generator expression to the two configs
dhewm3-sdk's own `CMakeLists.txt` sets `/Zi` for in the first place) so CMake's own ABI-detection
probes use `/Z7` instead of `/Zi` and need `mspdbsrv` even less. For a Debug/RelWithDebInfo build
this also flips dhewm3-sdk's own explicit `/Zi` (in `CMAKE_C_FLAGS_DEBUG`/`_RELWITHDEBINFO`) to
`/Z7` - `cl` prints a harmless `D9025: overriding '/Zi' with '/Z7'` warning for every file, since
dhewm3-sdk sets that flag directly rather than through CMake's debug-format abstraction and this
repo can't fix that warning at the source without patching the pinned SDK import; it doesn't affect
correctness or the resulting `.pdb`. Release/MinSizeRel are unaffected (dhewm3-sdk doesn't set
`/Zi` for them to begin with), same as Windows.

**Measured build times** (Unicron, 32 logical CPUs, `ninja`'s default job count, RelWithDebInfo,
after the `mspdbsrv` fix above; one-time `docker build`/image-pull setup not included):

| Build | Wall-clock | Notes |
|---|---|---|
| Clean (`rm -rf engine/build`, 122 objects) | ~8s | Configure ~1s, rest is compile+link; no minutes-long stall. |
| No-change rebuild | ~1s | Ninja partially over-rebuilds (about 22/122 objects) some runs - same-second mtimes on a fast build outrace ninja's mtime-based staleness check on this filesystem; harmless and self-corrects, not a correctness issue. |
| One-file incremental (`touch` a `game/*.cpp`) | ~1s | Rebuilds just that file (plus its usual reverse dependents) and relinks. |

Before the `mspdbsrv` fix, a from-scratch configure alone measured ~1211s (about 20 minutes, two
~10-minute stalls) - the fix above is what makes the numbers above possible. This is no longer
"noticeably slower than Windows/MSBuild" in any way that matters for an iteration loop; docker's own
per-invocation overhead (container start against the already-booted image) is negligible next to
the compile time itself.

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
`chextrek.dll` itself on Linux - done by #64, see "Building `chextrek.dll` on Unicron" above; the
two scenarios spike #59 found Wine-only-red (`test-end-level-nextmap.sh`, `test-objectives.sh`) -
fixed by #61, see the next paragraph. The single-run lock across concurrent worktrees is #62 - see
"Only run one harness invocation at a time on a given machine" below.

**Fixed by #61** (both scenarios' Wine-only reds from the spike): in both cases the scenario's own
assertions were unchanged; only a `wait` count each script sends the game grew, gated on
`chextrek_is_linux` so the Windows-verified values are untouched.
- `test-objectives.sh`: the `wait 150` after each `loadgame` (meant to comfortably outlast
  `mkObjective::Restore`'s 500ms-after-load re-attach) wasn't enough under Wine/llvmpipe - the spike
  saw the first round-trip read `empty/empty` instead of `Investigate/empty`. `wait 600` (4x) is
  verified reliable across runs.
- `test-end-level-nextmap.sh`: the `wait 10` after triggering `target_endlevelgui_1` (meant to
  leave `Event_UpdateStats`'s state just past its `-1` -> `0` transition, but short of finishing the
  monsters line on its own) left state stuck at `-1` for the rest of the run under Wine - every
  `customui_gui_*` value and `level_time` stayed at their pre-screen defaults. `wait 40` (4x)
  reliably reaches state `0` with the monsters line only 1-2% into its count, the same "started but
  not finished" margin the original wait targets.

### Publishing pipeline: "process commit X" (spec #58/#66)

`tools/pipeline-process-commit.sh <commit-ish>` is the pipeline's one entry point. It's invoked by
hand for now (the poller trigger is #68, red-issue handling is #67):

```
bash tools/pipeline-process-commit.sh <commit-ish>
```

No `export PATH=...wine...` needed first (unlike `docs/agents/unicron-build-test.md`'s one
command) - this script prepends the harness's own Wine location itself if `wine` isn't already on
`PATH`, since it also has to work unattended once #68 invokes it with nobody around to have set up
a shell first.

It resolves `<commit-ish>` to an exact commit, then:

1. checks that commit out into its **own scratch git worktree** - never the caller's own working
   copy, never an agent's checkout - removing any stale worktree left by an earlier crashed run of
   the same commit first;
2. runs the full suite (`tools/run-all-tests.sh`, unchanged - see "Running the tests" below) inside
   that scratch worktree, which builds `chextrek.dll` fresh from that exact commit;
3. on green, publishes a GitHub Release tagged `win-<short-sha>`, targeting that commit, with
   `chextrek.dll` and `chextrek.pdb` as assets, marked Latest (never `--prerelease`), with notes
   that include the suite's own summary line;
4. always removes the scratch worktree again, whether the run was green, red, or blocked.

It's idempotent: before doing any of the above, it checks whether `win-<short-sha>` already exists
(`gh release view`) and exits at once if so - a repeat run of an already-published commit publishes
nothing new and doesn't rebuild.

**Exit status** (the seam #67's red/green issue handling hangs off of):

| Exit | Meaning |
|---|---|
| `0` | Published (just now, or already was - idempotent no-op). |
| `1` | The suite ran and found a real test FAIL - nothing published. |
| `2` | A pipeline-level error: bad commit-ish, a worktree/`gh` failure, the suite reported green but didn't actually produce `chextrek.dll`/`chextrek.pdb`, or the suite exited with anything other than 0/1/3 - not a game result either way. |
| `3` | An environment blocker, propagated verbatim from `tools/run-all-tests.sh`'s own exit 3 (e.g. Wine not on `PATH`) - not a test result. |

Two runs of the *same* commit (a by-hand run overlapping #68's poller, say) never corrupt each
other: a per-tag `flock` (under `$CHEXTREK_PIPELINE_STATE_DIR/locks/`, separate from the harness's
own single-run lock, #62) serializes them, so a second run never force-removes the first run's live
scratch worktree out from under it. A second run finding the tag already published after waiting
for the lock is the normal idempotent case above, not an error.

**Where things live, outside every repo/worktree on purpose** (so a scratch worktree's removal in
step 4 above never touches them, and logs outlive the checkout they describe):

| Thing | Location | Override |
|---|---|---|
| Scratch worktrees | `$CHEXTREK_PIPELINE_STATE_DIR/worktrees/win-<short-sha>` | one per commit currently being processed; removed again once that run finishes |
| Pipeline run logs | `$CHEXTREK_PIPELINE_STATE_DIR/logs/<timestamp>-win-<short-sha>-<pid>.log` | one file per run, `tail`-able while a run is in progress |
| Per-commit locks | `$CHEXTREK_PIPELINE_STATE_DIR/locks/win-<short-sha>.lock` | one per commit tag; held for a run's whole duration, released automatically on exit |

`$CHEXTREK_PIPELINE_STATE_DIR` defaults to `$XDG_STATE_HOME/chextrek-pipeline` if `$XDG_STATE_HOME`
is set, else `$HOME/.local/state/chextrek-pipeline`.

Also injectable, mainly for `tools/test-pipeline-process-commit.sh` (never point these at the real
repo/a real `gh` outside that self-test):

- `CHEXTREK_PIPELINE_REPO` - `owner/repo` passed to every `gh` call. Defaults to the `owner/repo`
  parsed from this checkout's own `origin` remote.
- `CHEXTREK_PIPELINE_SUITE_CMD` - the build+test command run inside the scratch worktree. Defaults
  to `bash tools/run-all-tests.sh`.
- `CHEXTREK_PIPELINE_TAG_PREFIX` - release tag prefix. Defaults to `win-`.
- `CHEXTREK_PIPELINE_RED_LABEL` - label on the single red-tracking issue. Defaults to
  `pipeline:red`.
- `CHEXTREK_PIPELINE_RED_TITLE` - fixed title of that issue. Defaults to `Pipeline: chex-trek build
  is red`.

The DLL is still never committed (same as always - see "Why none of this lives in the repo"); the
release is the only place a built `chextrek.dll` is ever published.

### Red/green issue tracking (spec #58/#67)

A red run (exit `1`) or an environment blocker (exit `3`) opens or updates a single tracking issue;
the next green run closes it. This is the seam that turns a red or blocked commit into a GitHub
notification, without ever spamming a second issue for the same ongoing problem:

- **Red or blocked, no issue currently open**: `tools/pipeline-process-commit.sh` creates the
  `pipeline:red` label if it doesn't already exist (`gh label create ... --force`, safe to re-run),
  then opens one issue with a fixed title (`Pipeline: chex-trek build is red`) and that label. The
  body names the commit and either the failing scenarios (red - parsed from the suite's own `FAIL:`
  lines) or the `ENVIRONMENT:` line (blocker) - worded distinctly so a broken Unicron is never
  mistaken for a real game bug - plus this run's own archive log path (see the table above).
- **Red or blocked, an issue is already open**: comments on that same issue instead of opening a
  second one. Found by `gh issue list --label pipeline:red --state open` - this pipeline is the
  only thing that ever applies that label, so at most one is ever open at a time.
- **Green**: if an issue is open, it's closed (`gh issue close ... --comment`) with a comment naming
  the now-green commit and linking the release that was just published. This only runs after a run
  whose own suite just genuinely passed for this exact commit (a fresh publish, or losing a
  same-commit publish race but confirming the release exists) - **not** on the idempotent
  (already-published) fast path, since that path can be hit by re-processing any old,
  already-published commit while a *later* commit is the one that's actually still red; closing the
  issue there would be a false all-clear.
- A pipeline-level error (exit `2`) never touches the issue - it isn't a game result either way, and
  filing it as "red" would misreport a pipeline/environment problem as a game bug. Likewise, if the
  `gh issue list` lookup itself fails (auth/network/rate-limit), the run does nothing to the issue
  tracker rather than risk a duplicate open or a wrongly-skipped close - the failure is logged as a
  WARNING in that run's own archive log, and a still-open issue waits for a later run.

This all assumes commits are processed in order, one at a time - true for a by-hand run today, and
for #68's poller (one commit fully processed before the next is picked up). It isn't proven safe
against two *different* commits being processed concurrently: e.g. two red commits racing could
both see no issue open and both create one, or a fresh green publish of an old, out-of-order commit
could close an issue a genuinely later, still-red commit opened. The per-commit lock above only
serializes two runs of the *same* commit.

`tools/test-pipeline-process-commit.sh` covers the label/issue create-vs-comment-vs-close logic end
to end against a stubbed `gh` (never the real repo), including the `gh issue list` failure case and
the idempotent-path-doesn't-falsely-close case above. **Live-verified** against the real
`wScottSh/chex-trek` repo and a real `gh`: opening a real `pipeline:red` issue from a throwaway
branch commit, commenting on it instead of duplicating for a second red run (another throwaway
commit), commenting on it again worded as an environment blocker, and finally closing it with a
comment - that last run against `a39130d` itself (already known-green, not a throwaway commit).
All four `gh label`/`gh issue` calls (create, comment x2, close) were real, against the real repo.
Two things stayed simulated/dry-run rather than real, for this verification specifically, so it
didn't wait on a full ~25-minute suite run four times over: the suite outcome itself (red/blocked/
green) was chosen via `CHEXTREK_PIPELINE_SUITE_CMD` for all four runs, not by actually building and
testing each commit - `bash tools/run-all-tests.sh` was separately run directly (not through this
pipeline script) on this same branch during development and passed 24/24, proving the real
build+test path independent of this issue-tracking verification; and release publishing stayed
stubbed/dry-run (no real release/tag is allowed yet - see "Publishing pipeline" above), so the
closing comment's release link is a dry-run URL, not a real one. That verification issue was
`wScottSh/chex-trek#72` - left closed, with a summary comment identifying it as this run and
spelling out exactly what was real vs. simulated, once the verification finished (not the same
issue as this spec ticket, #67).

### Playing the latest green build (Windows, spec #58/#69)

On the Windows PC, in Git Bash, from the checkout the `Doom 3\chextrek` symlink points at:

```
bash tools/fetch-and-play.sh
```

This is spec #58's final piece - the owner's one command to play the latest Unicron-built,
harness-proven `chextrek.dll`. It:

1. **Refuses on a dirty working tree** (uncommitted changes) before touching anything else - it
   never discards local work. This is also #70's own acceptance criterion; #69 ships it and proves
   it here (`tools/test-fetch-and-play.sh`'s dirty-tree case) rather than leaving it for #70, since
   shipping this command without it in the meantime would mean every play session silently threw
   away whatever the owner had checked out and hadn't committed - not a missing feature, an active
   hazard. #70's own job on top of this is the commit argument (play/bisect a specific release, not
   just Latest), not implemented here.
2. Resolves the release marked Latest (`gh release view`, no tag) and checks both `chextrek.dll`
   and `chextrek.pdb` are attached to it, and that `dhewm3.exe` is actually installed - all before
   touching `HEAD`.
3. Downloads `chextrek.dll` + `chextrek.pdb` from that release into a scratch directory (not the
   checkout root yet) - so a download failure still leaves `HEAD` and the checkout untouched.
4. Fetches and checks out that release's target commit, detached, so mod data (maps/scripts/defs)
   matches the DLL about to be played.
5. Moves the already-downloaded DLL/PDB into the checkout root (the same gitignored place
   `tools/build-chextrek.sh` writes to), points the `chextrek` mount at this checkout
   (`tools/lib-harness.sh`'s `chextrek_ensure_mount` - the same mount every harness run uses,
   factored out so this command and the harness share exactly one mount implementation), and
   launches `dhewm3` with `+set fs_basepath`/`+set fs_game chextrek`/`+set fs_gameDllPath` pointed
   at this checkout, the same engine conventions as `tools/run-harness.sh` - but interactively: no
   console script, no timeout. The owner plays until they quit.

**Exit status:** `0` once `dhewm3` has been launched - the script's own exit status then becomes
whatever `dhewm3` itself exits with (a real, interactive process, not a pass/fail check), not
necessarily `0`. `1` on any refusal before ever launching anything. In every refusal case except
one, the working tree, `HEAD`, and `chextrek.dll`/`chextrek.pdb` are all left exactly as they were:
a dirty working tree, no Latest release (or one missing an asset), a missing `gh`/`dhewm3.exe`, a
git/gh failure, or the checkout itself failing. The one exception: once `HEAD` has moved to the
release's target commit, a failure moving the already-downloaded DLL/PDB into the checkout root, or
pointing the mount, can leave `HEAD` at that commit with the DLL/PDB only partially in place - the
error message names exactly what state each file and `HEAD` is in whenever this happens.

Also injectable, mainly for `tools/test-fetch-and-play.sh` (never point this at the real
repo/a real `gh` outside that self-test):

- `CHEXTREK_FETCH_REPO` - `owner/repo` passed to every `gh` call. Defaults to the `owner/repo`
  parsed from this checkout's own `origin` remote (`chextrek_parse_github_repo`,
  `tools/lib-harness.sh`).

**What's proven where:** `tools/test-fetch-and-play.sh` runs on Unicron against a local bare git
repo standing in for the real GitHub remote, a stubbed `gh`, and stubbed `wine`/`winepath`/
`dhewm3.exe` that record the engine invocation instead of launching anything - it proves the dirty-
tree refusal, the release/asset resolution, the detached checkout landing on the release's exact
commit (not just the branch tip), the download, the mount, and the exact engine launch arguments
(`fs_basepath`/`fs_game`/`fs_gameDllPath`), all without a display, a real engine, or a real repo.
It cannot prove the two things only the owner, on real Windows, can: that the engine log shows
`chextrek.dll` loaded, and that the game is actually playable. Those are spec #58's own final
acceptance checks: run `bash tools/fetch-and-play.sh`, then check `dhewm3log.txt` (under the
save/config path in the table above - `Documents\My Games\dhewm3\chextrek\` by default) for a line
like `loaded game library '...chextrek.dll'` - not `base.dll`. `tools/fetch-and-play.sh` itself
prints this same reminder once it launches the engine.

### AFK trigger: a systemd user timer polls origin/master (spec #58/#68)

Nobody has to start anything. A systemd **user** timer on Unicron, combined with lingering
(already enabled for this user - `loginctl show-user <user> -p Linger`; spec #58/#68 doesn't touch
it - if it were ever off, `loginctl enable-linger <user>` turns it on), polls `origin/master` on a
schedule and hands every new commit to `tools/pipeline-process-commit.sh`, oldest first, one at a
time - the trigger #66/#67 were built without, and the piece that makes spec #58 actually AFK: a
commit pushed while nobody is logged in to Unicron still gets built, tested and published (or
reported red).

**The poll logic itself** lives in `tools/pipeline-poll.sh` - a plain script with no systemd
dependency (systemd just calls it on a timer), so it's fully covered by
`tools/test-pipeline-poll.sh` without needing a real timer:

```
tools/pipeline-poll.sh
```

One call is one "poll tick": it fetches `origin/<branch>` (default `master`;
`CHEXTREK_PIPELINE_POLL_BRANCH` overrides), compares the fetched tip to the last commit this
poller has already handed off (`CHEXTREK_PIPELINE_STATE_DIR/poller-last-processed` - the same
state root `tools/pipeline-process-commit.sh` uses), and processes every commit newer than that,
**oldest first, one full `tools/pipeline-process-commit.sh` run at a time, in this one call**. The
state file is updated after each commit's own run returns, not once at the end, so an interrupted
backlog resumes exactly where it left off. The backlog is walked via `git rev-list --first-parent`
- master's own linear merge-commit history, the same shape every PR into this repo actually takes
(a merge commit per PR, same as this repo's own `Merge #67:`/`Merge #69:` commits) - deliberately
**not** a plain `rev-list`, which would also enumerate every individual commit on each merged-in
feature branch, interleaved by date across branches rather than in master's own merge order -
exactly the out-of-order processing the in-order design below exists to avoid, and a needless
suite run/release per WIP commit on a branch that never itself sat at the tip of master.

**Why oldest-first, one at a time, rather than skipping straight to the newest commit when several
land between polls:** #67's red/green issue tracking is explicitly documented as only safe for
in-order, one-commit-at-a-time processing - re-processing an old commit can't be told apart from
the current state, and a stale green publish for an old commit could wrongly close an issue a
genuinely later, still-red commit opened (see "Red/green issue tracking" above, and #67's own
closing comment, which names #68's poller directly: "assumes commits are processed in order, one
at a time ... and for #68's poller (one commit fully processed before the next is picked up)").
Skipping ahead to the newest commit would violate that the moment any skipped commit was red - the
issue #67 would have opened for it would simply never open. The accepted trade-off: a backlog of
several commits (each a full suite run, tens of minutes - see "Measured build times" above) delays
the newest commit's own result until every older one in the backlog has been processed, in favor
of never producing a wrong answer. A poll-level error partway through a backlog (exit 2 - see
`tools/pipeline-poll.sh`'s own header) stops that tick at the failing commit without advancing past
it, so the next tick retries it first rather than skipping ahead. If a commit's error is
persistent rather than transient (e.g. `tools/pipeline-process-commit.sh` reliably exits 2 for that
exact commit - a bad worktree state it can't recover from, say), the poller retries it forever by
design rather than silently giving up; unsticking it is a manual step: investigate
`CHEXTREK_PIPELINE_STATE_DIR/logs/` for that commit's own run archive, and once the cause is
understood, either fix it and let the next tick retry normally, or deliberately skip past that one
commit by writing its SHA directly into `CHEXTREK_PIPELINE_STATE_DIR/poller-last-processed`.

**First run ever** (no state file yet) bootstraps the baseline to the current `origin/<branch>` tip
without processing anything - otherwise the very first poll tick would try to process this repo's
entire history and publish a release for every past commit. Only commits pushed *after* that
baseline are ever processed.

**History divergence** (a force-push to the polled branch past the last-processed commit) is
detected (`git merge-base --is-ancestor`) rather than guessed at: the baseline resets to the new
tip without processing anything, a WARNING is logged, and the poll tick exits 2 - a force-push to
`master` isn't expected in normal operation and is left for a human to look at.

**No overlap** has two independent layers:

1. **systemd's own singleton semantics for the oneshot service** - the primary guarantee, and a
   general systemd unit-activation invariant, not something specific to timers: starting a unit
   that's already active *merges into the in-flight job* rather than launching a second execution -
   whether the `start` comes from the timer's own elapse or from a human running
   `systemctl --user start` by hand while a run is in progress. That merge means the second `start`
   call itself **blocks until the running instance finishes** (confirmed live - it does not return
   early), not "fire and forget"; either way, the suite command is never invoked twice at once.
   Live-verified (`tools/test-pipeline-poll-systemd.sh`, phase D) via an explicit concurrent
   `systemctl --user start` against a deliberately slow run - not by waiting for the real timer to
   happen to re-elapse during the busy window, which turned out (probed live against this same
   systemd) to be too timing-dependent to assert reliably in a bounded self-test. That phase proves
   the deployed system as a whole (this layer plus layer 2 below) never runs the suite command
   twice at once; it doesn't, on its own, isolate which layer stopped any one particular attempt.
2. **`tools/pipeline-poll.sh`'s own non-blocking flock** (`STATE_DIR/locks/poll.lock`, separate
   from `pipeline-process-commit.sh`'s own per-tag lock) - defense in depth against anything
   invoking the poll script outside systemd entirely (e.g. a human running it directly by hand,
   bypassing `systemctl` altogether, while the timer also fires). A tick that finds the lock
   already held logs that and exits 0 at once, rather than queuing - the next tick picks up any
   backlog.

**Installing the timer** - `tools/setup-pipeline-poll-timer.sh` renders
`tools/systemd/chextrek-pipeline-poll.{service,timer}.tmpl` into
`~/.config/systemd/user/chextrek-pipeline-poll.{service,timer}` and manages them:

```
tools/setup-pipeline-poll-timer.sh install [--repo-dir DIR] [--interval DURATION] [--branch BRANCH]
tools/setup-pipeline-poll-timer.sh enable            # systemctl --user enable --now the timer
tools/setup-pipeline-poll-timer.sh disable            # systemctl --user disable --now the timer
tools/setup-pipeline-poll-timer.sh status              # unit status + next/last scheduled fire
tools/setup-pipeline-poll-timer.sh logs [--follow]      # journalctl --user -u the service
tools/setup-pipeline-poll-timer.sh uninstall            # disable, remove the unit files, reload
```

`--repo-dir` defaults to this checkout's own root and is the `WorkingDirectory` the service runs
`bash tools/pipeline-poll.sh` from - **this must be a persistent, dedicated checkout of the repo,
not any agent's own temporary worktree**: `tools/pipeline-process-commit.sh` creates its scratch
worktrees as siblings of this checkout (`git worktree add`), so it needs to still exist for every
future poll tick, indefinitely. `--interval` defaults to `10min`; `--branch` defaults to `master`.
`install` only renders the unit files and runs `systemctl --user daemon-reload` - it deliberately
does **not** enable or start anything, so installing is safe to do well ahead of actually turning
the poller on.

**That dedicated checkout's own `tools/` scripts are not self-updating.** The poller only ever
`git fetch`es `origin/<branch>` to read new commits - it never `git pull`s its own checkout, so
`tools/pipeline-poll.sh`/`tools/pipeline-process-commit.sh` as they run unattended stay pinned to
whatever commit that checkout happened to be at when installed, even as `origin/master` moves
ahead under them (this is the same pattern `tools/pipeline-process-commit.sh` already used by hand
before spec #58/#68 - not new here, just now unattended, where nobody will notice a stale checkout
by eye). If a change to either script needs to take effect, update that checkout by hand (e.g.
`git -C /path/to/checkout pull`) - a future improvement could have the poller pull its own
checkout each tick, but that's out of scope here.

**Reboot survival** (AC): `WantedBy=timers.target` plus `enable` is what makes the timer come back
after a reboot at all; lingering (already on for this user) is what lets a `systemd --user` unit
run with nobody logged in in the first place; `OnBootSec=5min` (boot-relative, not wall-clock) is
what makes a tick fire again shortly after *any* boot, catching up on whatever time Unicron was
off regardless of how long that was. `Persistent=true` is included in the timer unit per the usual
systemd convention, but - `systemd.timer(5)` is explicit about this - it only has an effect for
`OnCalendar=` timers; this timer uses `OnBootSec=`/`OnUnitActiveSec=` instead, for which it's a
documented no-op, so it isn't what's actually doing the reboot-catch-up work here - `OnBootSec=`
alone already provides it, as above. Can't reboot Unicron from here to prove this live - verified instead via
`systemd-analyze --user verify` against the rendered units (clean, no warnings) and by inspection
of the unit files themselves; **owner-pending**: reboot Unicron once the real timer is enabled and
confirm `systemctl --user list-timers` still shows it afterwards.

**gh auth / docker / Wine PATH under systemd, with nobody logged in:** a `systemd --user` service
already runs as this login user, with this user's own `$HOME` and group membership - no desktop
session or interactively-sourced shell profile is needed for any of the following:
- `gh` reads its token from `$HOME/.config/gh/hosts.yml`, which is on disk regardless of whether a
  session is open - no extra setup.
- Docker: this user is already in the `docker` group (see the Unicron setup table above); group
  membership is a property of the user account, inherited by the systemd user manager the same as
  any other process this user starts.
- Wine: the unit's own `Environment=PATH=...` puts `/opt/wine-11.0-wow64/bin` on `PATH` directly
  (`tools/systemd/chextrek-pipeline-poll.service.tmpl`) - belt and braces, since
  `tools/pipeline-process-commit.sh` already adds it itself if `wine` isn't already found on
  `PATH`, for exactly this "nobody set up a shell first" case.
- Display: nothing sets `DISPLAY` here on purpose - the harness (`tools/lib-harness.sh`) brings up
  its own Xvfb per run, same as every other unattended invocation on Unicron.
- Network: the unit deliberately has no `After=`/`Wants=network-online.target` - that target has
  no meaning for a `systemd --user` manager (confirmed live: `systemctl --user status
  network-online.target` reports `LoadState=not-found`), so adding it would be a silent no-op, not
  a real ordering guarantee. A poll tick that runs before the network is actually up simply fails
  fast (`tools/pipeline-poll.sh`'s own `git fetch` exit 2) and is retried at the next interval.

**What's proven where:**
- **Self-test, no systemd** (`tools/test-pipeline-poll.sh`): the poll/state/ordering logic end to
  end against a local bare repo standing in for `origin` and a stubbed process-commit command (not
  the real `tools/pipeline-process-commit.sh` - that script's own behavior is
  `tools/test-pipeline-process-commit.sh`'s job) - bootstrap, up-to-date no-op, a single new
  commit, a multi-commit backlog processed in order (including a merge commit, processed once via
  `--first-parent`, with the individual commits it merged in never processed separately),
  red/environment-blocked results still advancing the baseline, a poll-level error stopping and
  being retried first (not skipped) next time, a merge-base lookup error being treated as a
  poll-level error rather than a false force-push reset, the poll lock's no-overlap skip, and
  history-divergence handling.
- **Live systemd mechanics** (`tools/test-pipeline-poll-systemd.sh`): a real, uniquely-named
  throwaway unit (`chextrek-pipeline-test-<pid>-<random>`), a stubbed `gh` and stubbed suite
  command, an isolated state dir, and a local bare repo as `origin` - proves a real oneshot service
  bootstraps, processes a newly-pushed commit exactly once and publishes its (stub) release, skips
  a commit already processed, and is never joined by a second concurrent invocation while a run is
  slow (proven via an explicit second `systemctl --user start` while a run is confirmed mid-flight
  - not by waiting for the real timer to happen to re-elapse during that busy window, which turned
  out to be too timing-dependent to assert reliably in a bounded test; both go through the same
  systemd job-control machinery, so this is equally strong evidence for the timer's own no-overlap
  safety - see the test's own phase-D comment). Skips cleanly (prints `SKIP`, exits 0) if
  `systemctl --user` isn't usable in the environment it's run in; unconditionally disables, removes
  and `daemon-reload`s its throwaway unit (and `reset-failed`s it) on every exit path,
  live-verified by hand afterwards (`systemctl --user list-timers --all` /
  `list-units --all | grep chextrek`) to leave nothing behind.
- **Never done in spec #58/#68, on purpose (HARD RULE):** the real "chextrek-pipeline-poll" unit was
  never installed or enabled against the real `origin/master` with a real `gh` - that would let an
  unattended poll tick publish a real release the moment any new commit landed, which is forbidden
  until spec #58 is merged and the VS Build Tools license use is confirmed (#64). `gh release list`
  and origin's tags were both confirmed empty after every live-mechanics run above.

**Owner, once spec #58 is merged and the license is confirmed** - enable the real timer against a
dedicated, persistent checkout (not a worktree that gets cleaned up):

```
tools/setup-pipeline-poll-timer.sh install --repo-dir /path/to/persistent/chex-trek-checkout
tools/setup-pipeline-poll-timer.sh enable
tools/setup-pipeline-poll-timer.sh status
```

Then push a throwaway commit to `master` (or wait for a real one) and confirm within one interval
plus run time that either a `win-<sha>` release appears (`gh release view`, no tag - the Latest
release) or the `pipeline:red` issue is opened/updated - the AC this whole sub-issue exists to
satisfy. `tools/setup-pipeline-poll-timer.sh logs --follow` tails the run live.

## Building

```
tools/build-chextrek.sh [Debug|RelWithDebInfo|Release]
```

Configures `engine/dhewm3-sdk` (the pinned dhewm3-sdk import, see `engine/dhewm3-sdk/UPSTREAM.md`)
with CMake, `BASE_NAME=chextrek`, `D3XP=OFF`, 32-bit, and copies the resulting `chextrek.dll`
(+ `.pdb`) to the repo root. Both are gitignored; rebuild any time with this one command, on
either machine. On Windows this uses `Visual Studio 18 2026` / Win32 and MSBuild, unchanged since
spec #28/#29. On Unicron (spec #64) this uses Ninja against the pinned MSVC-14.50.35717-x86-under-
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

**Only run one harness invocation at a time on a given machine.** On Windows this is still just a
rule: it kills every `dhewm3.exe` process by image name on timeout (not just the one it started),
and two concurrent runs would race on the shared `chextrek` symlink and the shared save dir
(`Documents\My Games\dhewm3\chextrek\`).

On Unicron it's enforced (#62): `chextrek_run_console_script` (`tools/lib-harness.sh`) takes an
exclusive `flock` on a lock file (default `/tmp/chextrek-harness.lock`, override with
`CHEXTREK_LOCK_FILE`) before it touches the `chextrek` symlink or the save dir, and holds it for
the whole run - mount, wipe, launch, the `wineserver -k` cleanup, archiving - releasing it only once
that's all done. #63's environment checks (Wine/`winepath`, Wine prefix, Doom 3 data, dhewm3
engine) run before the lock is taken, so a broken environment stops with exit 3 at once instead of
waiting for the lock first. A second run that starts while another holds the lock prints
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
