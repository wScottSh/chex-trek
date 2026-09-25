# Upstream import record

- **Source:** https://github.com/dhewm/dhewm3-sdk.git
- **Branch:** `master`
- **Pinned commit:** `ad837f9b1ba70bf6e38e61fd8eb242f2f09d1a2a` ("Fix build with compilers that default to C++20"), 2026-06-08.
  This matches the dhewm3 1.5.5 engine release's game API (`GAME_API_VERSION`), which is the engine version
  the harness launches (see `docs/dev-setup.md`).
- **Import method:** plain copy of the working tree (no submodule, no subtree) with the upstream `.git`
  directory dropped. Everything under `engine/dhewm3-sdk/` is stock SDK source at the pinned commit, except:
  - `game/ChexTrek*.cpp` / `.h` (new files) hold the mod's ported code and the developer-only state-dump
    console command (spec #28/#29 in this repo).
  - Edits recorded as "leads" in `decomp-so/reference/*.md` Notes are applied in place to the relevant stock
    `.cpp` files as each feature sub-issue lands. Search this tree for `// chextrek:` comments to find them.
  - `CMakeLists.txt` is upstream's file with one intended, one-line-per-file edit: the mod's new `.cpp`
    files (e.g. `game/ChexTrekDump.cpp`) are listed in `src_game_mod`, exactly where the upstream template
    says to put them. The build itself is still configured by passing `-DBASE_NAME=chextrek -DD3XP=OFF` at
    CMake-configure time (see `tools/build-chextrek.sh`), not by editing anything else in the file.

## Updating the pin

To move to a newer upstream commit:

1. Re-clone `dhewm3-sdk` at the new commit into a scratch directory.
2. Diff it against this directory's *stock* files (i.e. excluding the `ChexTrek*` additions and any
   `// chextrek:` edits) to see what upstream changed.
   git diff --no-index engine/dhewm3-sdk 
3. Re-apply the mod's additions and `// chextrek:` edits on top of the new stock tree.
4. Update the pinned commit hash and date above, and confirm `GAME_API_VERSION` still matches the target
   dhewm3 engine release.
5. Rebuild (`tools/build-chextrek.sh`) and re-run the harness (`tools/run-harness.sh`) before merging.
