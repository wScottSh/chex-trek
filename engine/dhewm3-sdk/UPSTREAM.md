# Upstream import record

- **Source:** https://github.com/dhewm/dhewm3-sdk.git
- **Branch:** `master`
- **Pinned commit:** `ad837f9b1ba70bf6e38e61fd8eb242f2f09d1a2a` ("Fix build with compilers that default to C++20"), 2026-06-08.
  This matches the dhewm3 1.5.5 engine release's game API (`GAME_API_VERSION`), which is the engine version
  the harness launches (see `docs/dev-setup.md`).
- **Import method:** plain copy of the working tree (no submodule, no subtree) with the upstream `.git`
  directory and `.gitignore` dropped (the latter is upstream's own build-output ignores; this repo's root
  `.gitignore` already covers `engine/build/` and the built `chextrek.dll`/`.pdb`). Everything under
  `engine/dhewm3-sdk/` is stock SDK source at the pinned commit, except:
  - New files in `game/`: `Trail.cpp`/`.h` (`mkTrail`), `func_envshot.cpp`/`.h` (`matt_func_envshot`)
    and `ChexTrekDump.cpp`/`.h` (the developer-only state-dump command and the rest of the harness's
    test surface - see the note at the top of `ChexTrekDump.h`).
  - Edits recorded as "leads" in `decomp-so/reference/*.md` Notes, and the mod's additions to stock
    classes, are applied in place to the relevant stock files (`.cpp` and `.h`, including
    `idlib/Str.*` and `framework/CmdSystem.h`), each block marked with a `// chextrek:` comment.
  - `CMakeLists.txt` is upstream's file with one edit per new `.cpp`: each is listed in `src_game_mod`,
    where the upstream template says to put them. The build itself is still configured by passing
    `-DBASE_NAME=chextrek -DD3XP=OFF` at CMake-configure time (see `tools/build-chextrek.sh`).
  - Every edited or added block carries a `chextrek` marker comment (`// chextrek` in C++, `# chextrek`
    in CMake). That's a convenience for skimming, not the authoritative list - when rebasing onto a
    newer commit, diff against a fresh, unmodified clone of *this same pinned commit* instead (see
    "Updating the pin" below), which catches everything regardless of markers.

## Updating the pin

To move to a newer upstream commit:

1. Re-clone `dhewm3-sdk` at the *current* pinned commit (`ad837f9b1b...` above) into one scratch directory,
   and at the new target commit into a second scratch directory.
2. Diff the current-pin clone against `engine/dhewm3-sdk/` in this repo to get the complete, authoritative
   list of every edit made here (not just the ones marked `// chextrek:` - see the note above):
   git diff --no-index <scratch-clone-at-current-pin> engine/dhewm3-sdk
3. Diff the current-pin clone against the new-target-commit clone to see what upstream changed:
   git diff --no-index <scratch-clone-at-current-pin> <scratch-clone-at-new-commit>
4. Re-apply this repo's edits from step 2 on top of the new-target-commit tree.
5. Update the pinned commit hash and date above, and confirm `GAME_API_VERSION` still matches the target
   dhewm3 engine release.
6. Rebuild (`tools/build-chextrek.sh`) and re-run the whole test suite (`tools/run-all-tests.sh`) before merging.
