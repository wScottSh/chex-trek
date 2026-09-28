# Research: build + test Windows `chextrek.dll` on Unicron (Linux), AFK, and pull it to the Windows PC

Researched 2026-09-27. Nothing was installed or run on Unicron beyond read-only probes; every "works" claim below
is sourced, and anything not proven on this machine is marked **UNVERIFIED**.

## TL;DR recommendation

Do it all on Unicron, with no Windows VM and no self-hosted GitHub runner:

1. **Trigger:** agents on Unicron run `tools/run-all-tests.sh` directly, as they do today on Windows. A systemd timer
   (or a post-merge hook) runs the same thing on every new `origin/master` commit and publishes the result.
2. **Build:** use **real MSVC `cl.exe` under Wine via [msvc-wine]**, pinned to the toolchain spec #28 already uses
   (`--major 18 --msvc-version 14.50`, x86), inside a Docker image. Build with CMake + Ninja using the same flags
   `tools/build-chextrek.sh` passes (`-DBASE=ON -DBASE_NAME=chextrek -DD3XP=OFF`). If msvc-wine gives trouble,
   fall back to clang-cl + [xwin] (also MSVC ABI). **Don't use MinGW**: see "Why not MinGW" below.
3. **Test:** run the **official, unmodified dhewm3 1.5.5 win32 zip under Wine 11** (new WoW64) on an **Xvfb** display,
   with the classic Doom 3 `pak000`-`pak008` copied once from the Windows PC. Port `tools/lib-harness.sh`'s
   Windows-only calls (`cygpath`, `qwinsta`, `taskkill`, NTFS symlink) to Wine equivalents. The assertions (log
   greps, state dump, archived screenshots) stay as they are.
4. **Deliver:** when the suite is green, Unicron runs `gh release create win-<sha> chextrek.dll chextrek.pdb
   --prerelease --target <sha>`. The DLL is never committed.
5. **Parity guard (optional, free):** a GitHub-hosted `windows-2025-vs2026` Actions job that only *compiles* the DLL
   with real VS 2026 on each push. It catches msvc-wine drift and needs no game data.
6. **Play on the Windows PC** (Git Bash, in the existing checkout that the `Doom 3\chextrek` symlink points at):

   ```bash
   SHA=$(gh release view -R wScottSh/chex-trek --json tagName -q .tagName | sed 's/^win-//') \
     && git fetch origin && git checkout --detach "$SHA" \
     && gh release download "win-$SHA" -R wScottSh/chex-trek -p 'chextrek.*' --clobber \
     && "$DHEWM3_HOME/dhewm3.exe" +set fs_basepath "$(cygpath -w "$DOOM3_BASEPATH")" +set fs_game chextrek +set fs_gameDllPath "$(cygpath -w "$PWD")"
   ```

   This checks out the exact commit the DLL was built and tested from, so the mod data matches the code. Worth
   wrapping as `tools/fetch-windows-build.sh`. `gh release view` with no tag returns the release marked Latest, so
   each publish must pass `--latest` (and prereleases can't be Latest, which leads to **open question 4**).
   LAN fallback without GitHub: `scp unicron:<checkout>/chextrek.dll .` (sshd is running on Unicron).

**Gate before committing to this:** a half-day spike (see "Risks"). The biggest unknown is whether 32-bit
dhewm3's OpenGL works under Wine 11 new-WoW64 on Xvfb. If it doesn't, try Ubuntu's Wine 9 with i386 multiarch
(old WoW64) or a GPU-backed display. If all of those fail, fall back to option C (a Windows VM).

## Current state

### Repo (chex-trek @ `4f704c1`, merge of PR #47 / spec #28)

- **What "the Windows build" is:** a single 32-bit x86 `chextrek.dll` game library, built from the vendored
  dhewm3-sdk at `ad837f9b1b` (`engine/dhewm3-sdk/UPSTREAM.md`). The engine is **not** built. It's the official
  dhewm3 1.5.5 win32 release, unmodified (issue #28 "Implementation Decisions"; `docs/dev-setup.md`). 64-bit,
  Linux and macOS builds are out of scope (#28 "Out of Scope").
- **How dhewm3 is pulled in:** as a plain copy, not a submodule (`UPSTREAM.md`). The sibling repo
  `wScottSh/chex-dhewm3-sdk` (public, last updated 2026-04-17) is older prior work. This repo doesn't reference it.
- **Build today:** `tools/build-chextrek.sh` runs on **Windows Git Bash only**. It hardcodes `cmake.exe` under
  `C:\Program Files*\...\18\BuildTools`, the generator `Visual Studio 18 2026`, and `-A Win32`. It already handles
  a single-config (Ninja) output path. MSVC flags are `/MD` (dynamic CRT) (`engine/dhewm3-sdk/CMakeLists.txt:326-329`).
- **Tests today** (`tools/lib-harness.sh`, `tools/run-all-tests.sh`, 19 `tools/test-*.sh`, `docs/harness-coverage.md`):
  - Each test launches the real `dhewm3.exe` **windowed** (needs a display: `qwinsta`, exit 3 on no display) with
    `+set fs_game chextrek +set fs_gameDllPath <checkout> +exec <script>`. The console scripts use `map`, `wait`,
    `setviewpos`, `script`, `impulse`, `screenshot` and `quit`.
  - A timeout kills a hung run (`taskkill //IM dhewm3.exe`).
  - Assertions are greps of `dhewm3log.txt`: the DLL loaded, the `CHEXTREK-STATE-DUMP v1` header, no
    `ERROR:`/unknown event/spawnclass/script errors, and per-scenario dump fields.
  - Screenshots are archived but never asserted.
  - The mod is mounted as a real NTFS symlink `Doom 3\chextrek` → the checkout. Only one run per machine at a time.
- **Pain point:** agent sessions on Windows couldn't create that symlink, so PR #57 shipped "Not run in game"
  (`gh pr view 57`). A Linux host doesn't have this problem, because plain `ln -s` works and Wine follows Unix
  symlinks.
- **Data:**
  - Base game: classic Doom 3 1.3.1 from Steam (app 9050, `base/pak000`-`pak008`). It's commercial, so it can't
    go in the public repo or in CI artifacts. dhewm3's own `base/WHAT_TO_DO.txt` says to copy these from your
    own install.
  - Mod data (maps, scripts, textures, about 190 MiB packed) is already public in this repo. There's no license
    file for it (checked: none at the repo root).
  - dhewm3-sdk code is GPLv3 (`engine/dhewm3-sdk/COPYING.txt`), so shipping `chextrek.dll` publicly is fine as
    long as the source stays public, which it is.
- **CI:** there is no `.github/workflows` directory. The repo is **public** (`gh repo view`).
- **Where research lives:** earlier research (R1-R10) lives in GitHub issues, and there was no `docs/research/`
  directory. This file creates it, as instructed.

### Unicron (probed 2026-09-27)

| Present | Absent |
|---|---|
| Ubuntu 24.04.5, kernel 7.0 | wine / wine32 (apt has 9.0; **no i386 multiarch** configured) |
| AMD Ryzen AI MAX+ 395, 32 threads, 109 GiB RAM, 1.6 TB free | mingw-w64, clang/clang-cl/lld (apt has clang-18, mingw-w64 11) |
| Radeon 8060S iGPU (`/dev/dri/renderD128`), user in `video`,`render` | qemu/libvirt/virsh; user **not** in `kvm` group |
| `/dev/kvm` + `kvm_amd` loaded (AMD-V) | podman, Tailscale, Samba |
| docker (active, user in `docker` group) | GitHub Actions runner |
| cmake, ninja, gcc 13, Xvfb/xvfb-run, gh 2.45, rsync, sshd (active) | Steam / Doom 3 data, dhewm3 |

## Why not MinGW (the "obvious" cross-compile)

- dhewm3 upstream supports MinGW-w64 cross builds *of the engine* ([dhewm3 README "Cross-compiling"][dh-readme]).
  The SDK README marks a MinGW game-DLL build "(Untested:)" ([dhewm3-sdk README][sdk-readme]).
- The official 1.5.5 win32 `dhewm3.exe`/`base.dll` are **MSVC-built**. Verified by unzipping
  `dhewm3-1.5.5_win32.zip`: both import `VCRUNTIME140.dll` and `api-ms-win-crt-*`. Upstream's Windows CI also
  builds with MSVC ([win_msvc.yml][dh-ci]).
- The game ↔ engine boundary is C++ virtual interfaces, and **the virtual destructor is the first vtable slot** in
  `idGame` and `idCommon` (`framework/Game.h:78-80`, `framework/Common.h:114-116`), and in `idCmdSystem`,
  `idFileSystem`, `idRenderSystem` and others.
  - The Itanium ABI (used by MinGW g++) gives a virtual destructor **two** slots: "The entries for virtual
    destructors are actually pairs of entries" ([Itanium C++ ABI][itanium]).
  - The MSVC ABI gives it **one** slot: clang's MS vftable builder assigns a single deleting-dtor slot, while its
    Itanium builder assigns `VTableIndex` and `VTableIndex + 1` ([clang VTableBuilder.cpp][clang-vtb]).
  - So every virtual call after the destructor would be off by one slot. A MinGW `chextrek.dll` can't talk to the
    official exe. Making MinGW work would mean also building and shipping a MinGW dhewm3 engine, which contradicts
    #28's "official engine, unmodified".
- clang-cl targets the MSVC ABI. Record layout and RTTI are "Complete", and class inheritance is "Mostly complete"
  ([clang MSVC compatibility][clang-msvc]).

## Options compared

| | A. msvc-wine on Unicron (**recommended**) | B. clang-cl + xwin on Unicron | C. Windows VM on KVM (e.g. dockur/windows) | D. GitHub-hosted `windows-2025-vs2026` | E. MinGW cross |
|---|---|---|---|---|---|
| Compiler vs today | **Same** `cl.exe` 14.50, pinnable ([vsdownload.py `--major/--msvc-version`][msvcwine-dl]) | Different compiler, same ABI | Same | VS 2026 Enterprise 18.9 ([image readme][gha-img]) | Wrong ABI (see above) |
| Runs on Unicron | Yes (Docker/Wine) | Yes (Docker) | Yes, KVM present; needs `kvm` group or docker `--device /dev/kvm` | No (cloud) | Yes |
| Can run full test suite | Yes, with Wine + local Doom 3 data | Yes (same) | Yes, native Windows; needs autologon desktop + mesa-dist-win llvmpipe (no GPU in VM) | **No**: Doom 3 data can't go to CI; GUI session on hosted runners **UNVERIFIED** | n/a |
| Cost / license | Free. VS license applies to the downloaded toolchain; msvc-wine: "requires accepting the license… the installed toolchain isn't [redistributable]" ([msvc-wine README][msvcwine]) | Free. xwin also needs `--accept-license` for MS CRT/SDK ([xwin README][xwin]) | Needs a **valid Windows license**; "You are responsible for ensuring that you have a valid Windows license" ([dockur README][dockur]) + VS license | Free for public repos: "The use of standard GitHub-hosted runners is free: In public repositories" ([GH billing][gh-bill]) | Free |
| Maintenance | Medium: Wine + msvc-wine updates, `winbind` for `/Zi` PDBs ([msvc-wine FAQ][msvcwine]) | Medium: clang/xwin versions; x86 in xwin "not fully tested" ([xwin README][xwin]) | High: Windows updates, VM image, autologon, RDP-drop exit-3 issues persist | Low | n/a |
| AFK agent loop speed | Local, seconds to minutes | Local | Local, but agents must drive a VM | Push → wait on cloud per iteration; too slow as the inner loop | n/a |
| Fidelity of *test* vs Scott's PC | Wine ≠ Windows (final check = Scott plays) | Same as A, plus a compiler difference | Highest short of real hardware | Build only | n/a |

**Self-hosted runner on Unicron: no.** GitHub says "Self-hosted runners should almost never be used for public
repositories on GitHub, because any user can open pull requests against the repository and compromise the
environment" ([GH secure use][gh-sec]). Use a local timer or script instead.

**VS Build Tools licensing (not legal advice):** Build Tools are licensed as a supplement to a Visual Studio license.
Since 2022 they may also be used without a VS license to compile *OSI-licensed open-source dependencies*
([MS C++ blog, 2022-08-18][ms-bt-blog]); the current terms are at [VS 2026 Build Tools license][ms-bt-2026]. The
page text didn't render for this research, so the exact 2026 wording is **UNVERIFIED**. Scott's Windows PC already
uses the same toolchain on the same terms, so A doesn't change his licensing position. Confirm if unsure.

## Testing strategy (Unicron + Wine)

- **Engine:** the official `dhewm3-1.5.5_win32.zip` (ships `dhewm3.exe`, `dhewm3ded.exe`, `base.dll`, `SDL2.dll`,
  `OpenAL32.dll`, `libcurl-4.dll`, verified by listing) unpacked under a dedicated `WINEPREFIX`. Wine has builtin
  `vcruntime140`/`ucrtbase`/`msvcp140`/`opengl32` ([wine dlls/][wine-dlls]).
- **Wine version:** use WineHQ 11.x packages, not Ubuntu's 9.0.
  - In Wine 11 the "_new WoW64_ mode … is considered fully supported". A 32-bit exe needs no i386 host libraries
    and a 64-bit prefix (`WINEARCH=win32` prefixes are deprecated). "In new WoW64 mode, OpenGL buffers are mapped to
    32-bit memory space using Vulkan extensions if available" ([Wine 11.0 ANNOUNCE][wine11]).
  - **UNVERIFIED:** whether that path works on Xvfb/llvmpipe (no Vulkan) for dhewm3. Test it in the spike.
- **Display:** `xvfb-run -s '-screen 0 1280x720x24'` gives each run a private X display. Mesa llvmpipe renders in
  software, which is fine for scripted smoke tests and screenshots. If llvmpipe is too slow or fails, run a
  GPU-backed headless X or Wayland session on the Radeon (**UNVERIFIED**).
  - Upside: separate displays + separate `WINEPREFIX` (save dir) + a per-worktree `fs_basepath` of symlinks to
    the paks could lift today's "one harness run per machine" limit (`docs/dev-setup.md`). **UNVERIFIED**; needs a
    harness change.
- **Harness port** (small, mechanical; keep one script with a platform switch):
  - `cygpath -w` → `winepath -w`
  - `qwinsta` check → check that `$DISPLAY` is set and reachable
  - `taskkill //IM` → kill the run's PID or `wineserver -k` (per prefix)
  - NTFS-symlink dance → plain `ln -s`
  - `DHEWM3_DOCUMENTS_DIR` → the prefix's `drive_c/users/$USER/Documents`. Wine may link it to `~/Documents`;
    **UNVERIFIED**, so detect it rather than assume.
  - Assertions, timeouts and exit codes stay the same.
- **Base data on Unicron:** copy `base/pak000-008.pk4` once from the Windows PC's Steam folder, e.g.
  `rsync`/`scp` over the existing SSH access. SteamCMD with `+@sSteamCmdForcePlatformType windows` is an
  alternative, but its docs page returned 403 to this research: **UNVERIFIED**. Keep the paks outside every repo
  and artifact.
- **Headless alternatives considered:**
  - `dhewm3ded.exe` (dedicated server) is in the zip and could load maps without GL. But the suite exercises
    HUD/PDA/GUI/screenshots, so it would cover only a subset. Not recommended as the main path.
  - A native Linux `chextrek.so` + Linux dhewm3 1.5.5 (upstream ships `Linux_amd64`) would test game logic fast.
    But it isn't the Windows binary Scott plays, so it's optional extra coverage at most.
- **Windows-runner testing** (option D) would need Mesa for GL: [mesa-dist-win] ships llvmpipe for x86 via a
  per-app `opengl32.dll` deployment. But without Doom 3 data on the runner it can't run the suite. Skip it.
- **Final acceptance** is Scott playing on real Windows + GPU. Wine green means "very likely fine", not proof.

## AFK orchestration

- **Inner loop:** agents on Unicron edit → `tools/build-chextrek.sh` → `tools/run-all-tests.sh`, all local.
  Unattended agent runs can use `claude -p … --permission-mode auto --permission-prompts none`
  ([Claude Code headless docs][cc-headless]).
- **Publish loop:** a systemd user timer polls `git ls-remote origin master`. On a new SHA it:
  1. checks out that SHA into a scratch worktree;
  2. builds and runs the suite;
  3. uploads logs and screenshots somewhere browsable (release assets or a local dir);
  4. on green, runs `gh release create win-<sha> … --target <sha>`; on red, opens or updates a GitHub issue.

  A GitHub issue or release doubles as the notification: GitHub emails or pushes to watchers.
- **Optional D job** (`windows-2025-vs2026`, free on this public repo) for compile-parity only. Workflow artifacts
  are kept 90 days by default ([GH artifact retention][gh-retain]). Note that `build-chextrek.sh` looks only in
  `...\18\BuildTools`, while the image has `...\18\Enterprise` ([image readme][gha-img]), so the script needs
  another candidate or should use `cmake` from PATH.

## Delivery to the Windows PC

- **Recommended:** GitHub Releases (`gh release create` on Unicron, `gh release download` on Windows; flags checked
  against gh 2.45 `--help`). Releases don't expire, unlike 90-day workflow artifacts. Each release is tagged to
  the exact source SHA it was built from. Shipping GPL binaries next to public source is compliant.
- **Don't commit the DLL:** `.gitignore` already excludes `chextrek.dll`/`.pdb` by design. Git LFS isn't configured
  (`.gitattributes` only sets `*.sh eol=lf`). Binaries would bloat the history of a repo that's already about 190 MiB.
- **"Pull the changes down"** = `git checkout <sha>` for the mod data + `gh release download` for the DLL (the
  command in the TL;DR). Data and DLL must come from the **same SHA**, because scripts and code co-evolve.
- **Fallbacks:** `scp`/`rsync` over SSH on the LAN. Tailscale isn't installed. An SMB share is possible, but Samba
  isn't installed and adds nothing over scp.
- **Windows-side prerequisite:** Smart App Control must stay **off**, or the unsigned DLL is blocked (`0x11C7`,
  `docs/dev-setup.md`).

## Risks / open questions (verify in the spike)

1. **Wine + 32-bit GL** (new WoW64 on Xvfb/llvmpipe): does the official `dhewm3.exe` reach the main menu and
   `quit` cleanly? This is the go/no-go. Fallbacks, in order: i386 multiarch + old-WoW64 Wine, a GPU-backed
   display, option C.
2. **msvc-wine** `cl.exe` x86 build of this CMake tree with Ninja. The SDK hardcodes `/Zi`, so it needs `winbind`
   ([msvc-wine FAQ][msvcwine]). Is the output DLL loadable and does it pass the menu smoke test?
3. **Wine vs Windows behavior divergence:** timing, file-path case, the save path, and log flushing (the harness
   already notes flush sensitivity).
4. **Release naming:** per-SHA prereleases vs a rolling `win-latest` tag. The fetch command needs a stable "latest
   green" lookup.
5. **VS 2026 Build Tools license text** could not be read (the page didn't render). Confirm it covers use on a
   second (Linux) machine.
6. **How Scott reaches Unicron** from Windows (SSH? RDP? LAN only?) decides whether scp is a real fallback.

## Context: how studios do remote builds (brief)

Epic's Horde provides "build automation, remote code compilation, and test automation" for large Perforce repos,
driven by BuildGraph ([Horde docs][horde]). JetBrains TeamCity + Perforce and Incredibuild distributed compiles are
the common alternatives. All of them are sized for teams; for one DLL, a timer + `gh` release is the right scale.

## Sources

- Repo: `docs/dev-setup.md`, `tools/build-chextrek.sh`, `tools/lib-harness.sh`, `tools/run-all-tests.sh`,
  `engine/dhewm3-sdk/UPSTREAM.md`, `engine/dhewm3-sdk/CMakeLists.txt`, `framework/Game.h`, `framework/Common.h`;
  issue #28 (`gh issue view 28`), PR #57 (`gh pr view 57`), commit `4f704c1`.
- Official dhewm3 1.5.5 win32 zip, inspected locally:
  https://github.com/dhewm/dhewm3/releases/tag/1.5.5
- [dh-readme]: https://github.com/dhewm/dhewm3/blob/455b88e8dff2be822f08eb498f51b383e851fa38/README.md
- [dh-ci]: https://github.com/dhewm/dhewm3/blob/455b88e8dff2be822f08eb498f51b383e851fa38/.github/workflows/win_msvc.yml
- [sdk-readme]: https://github.com/dhewm/dhewm3-sdk/blob/ad837f9b1ba70bf6e38e61fd8eb242f2f09d1a2a/README.md
- [itanium]: https://itanium-cxx-abi.github.io/cxx-abi/abi.html (vtable components, virtual destructors)
- [clang-vtb]: https://github.com/llvm/llvm-project/blob/main/clang/lib/AST/VTableBuilder.cpp (Itanium `Dtor_Complete` @ `VTableIndex`, `Dtor_Deleting` @ `+1`; MS single deleting-dtor slot)
- [clang-msvc]: https://clang.llvm.org/docs/MSVCCompatibility.html
- [msvcwine]: https://github.com/mstorsjo/msvc-wine/blob/514f8ea34842cd6d831804d0e9658d3a32870ae1/README.md
- [msvcwine-dl]: https://github.com/mstorsjo/msvc-wine/blob/514f8ea34842cd6d831804d0e9658d3a32870ae1/vsdownload.py
- [xwin]: https://github.com/Jake-Shadle/xwin
- [dockur]: https://github.com/dockur/windows/blob/1e99833c8f7946238566ecd0d5d2b40ba5f6c03a/README.md
- [mesa-dist-win]: https://github.com/pal1000/mesa-dist-win/blob/9d027e91d2ba2de7da37bf180f8d544945ae811c/README.md
- [wine11]: https://github.com/wine-mirror/wine/blob/wine-11.0/ANNOUNCE.md
- [wine-dlls]: https://github.com/wine-mirror/wine/tree/wine-11.0/dlls
- [gha-img]: https://github.com/actions/runner-images/blob/055a621061058268af5c62abada4bd7150afd5f1/images/windows/Windows2025-VS2026-Readme.md (and the runner-images README label table)
- [gh-bill]: https://docs.github.com/en/billing/concepts/product-billing/github-actions
- [gh-sec]: https://docs.github.com/en/actions/reference/security/secure-use
- [gh-retain]: https://docs.github.com/en/actions/how-tos/manage-workflow-runs/remove-workflow-artifacts
- [ms-bt-blog]: https://devblogs.microsoft.com/cppblog/updates-to-visual-studio-build-tools-license-for-c-and-cpp-open-source-projects/
- [ms-bt-2026]: https://visualstudio.microsoft.com/license-terms/vs2026-ga-diagnostic-buildtools/
- [cc-headless]: https://code.claude.com/docs/en/headless
- [horde]: https://dev.epicgames.com/documentation/en-us/unreal-engine/horde-in-unreal-engine

[dh-readme]: https://github.com/dhewm/dhewm3/blob/455b88e8dff2be822f08eb498f51b383e851fa38/README.md
[dh-ci]: https://github.com/dhewm/dhewm3/blob/455b88e8dff2be822f08eb498f51b383e851fa38/.github/workflows/win_msvc.yml
[sdk-readme]: https://github.com/dhewm/dhewm3-sdk/blob/ad837f9b1ba70bf6e38e61fd8eb242f2f09d1a2a/README.md
[itanium]: https://itanium-cxx-abi.github.io/cxx-abi/abi.html
[clang-vtb]: https://github.com/llvm/llvm-project/blob/main/clang/lib/AST/VTableBuilder.cpp
[clang-msvc]: https://clang.llvm.org/docs/MSVCCompatibility.html
[msvcwine]: https://github.com/mstorsjo/msvc-wine/blob/514f8ea34842cd6d831804d0e9658d3a32870ae1/README.md
[msvcwine-dl]: https://github.com/mstorsjo/msvc-wine/blob/514f8ea34842cd6d831804d0e9658d3a32870ae1/vsdownload.py
[msvc-wine]: https://github.com/mstorsjo/msvc-wine
[xwin]: https://github.com/Jake-Shadle/xwin
[dockur]: https://github.com/dockur/windows/blob/1e99833c8f7946238566ecd0d5d2b40ba5f6c03a/README.md
[mesa-dist-win]: https://github.com/pal1000/mesa-dist-win/blob/9d027e91d2ba2de7da37bf180f8d544945ae811c/README.md
[wine11]: https://github.com/wine-mirror/wine/blob/wine-11.0/ANNOUNCE.md
[wine-dlls]: https://github.com/wine-mirror/wine/tree/wine-11.0/dlls
[gha-img]: https://github.com/actions/runner-images/blob/055a621061058268af5c62abada4bd7150afd5f1/images/windows/Windows2025-VS2026-Readme.md
[gh-bill]: https://docs.github.com/en/billing/concepts/product-billing/github-actions
[gh-sec]: https://docs.github.com/en/actions/reference/security/secure-use
[gh-retain]: https://docs.github.com/en/actions/how-tos/manage-workflow-runs/remove-workflow-artifacts
[ms-bt-blog]: https://devblogs.microsoft.com/cppblog/updates-to-visual-studio-build-tools-license-for-c-and-cpp-open-source-projects/
[ms-bt-2026]: https://visualstudio.microsoft.com/license-terms/vs2026-ga-diagnostic-buildtools/
[cc-headless]: https://code.claude.com/docs/en/headless
[horde]: https://dev.epicgames.com/documentation/en-us/unreal-engine/horde-in-unreal-engine
