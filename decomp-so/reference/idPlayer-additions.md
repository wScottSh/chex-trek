# `idPlayer` additions: consolidated list

**Provenance:** compiled by **Claude Opus 5.5** from the group references in this folder. Those were reconstructed from the complete Ghidra export `decomp-so/ghidra-full/` of `gamex86.so` (Ghidra 12.1.4, discovered non-returning functions disabled), with offsets checked against the binary's disassembly. Reference material only.

One place for every `idPlayer` member and method the mod added, so they can be added to a modern `idPlayer` together. Each feature group adds its own rows. If a group finds a conflict (same offset, different type or meaning), fix it here and note it in the group's Notes.

Offsets are from the start of `idPlayer` in this build (`this + offset`). Names are ours; the binary keeps only method names. UNCERTAIN: where each member sat in the source declaration. Only the offsets are known, and stock `idPlayer` members around them were not mapped.

## Members

| Offset | Type | Name | Group | Evidence (binary) |
|---|---|---|---|---|
| `+0x1ea4` | `playerStats_s[ 4 ]` (0x50 bytes, to `+0x1ef3`) | `levelStats` | end-level-stats | `getLevelStats` returns `this + 0x1ea4`. Both constructors `memset` 0x50 bytes there. `idPlayer::Spawn` fills it (`GetLevelStats`, start time at `+0x1ee0`, GUI variable names at `+0x1eac`...`+0x1ee8`). `incSecretsFound` increments `+0x1ed0` (`[2].found`), `AddAIKill` `+0x1ea8` (`[0].found`), `GiveItem` `+0x1ebc` (`[1].found`). Element type and layout: `reference/end-level-stats.md`. |
| `+0x1f0c` | `idCustomUI *` | `customUIEntity` | custom-ui | `useCustomUI` stores its 2nd argument (`idCustomUI *`), `clearCustomUI` zeroes it. `HandleSingleGuiCommand` calls `HandleCustomGUICommand` (vtable slot 59, `[vptr+0xe4]`) on it. |
| `+0x1f10` | `idUserInterface *` | `customUI` | custom-ui | `useCustomUI` stores its 1st argument (`idUserInterface *`), `clearCustomUI` zeroes it. `ActiveGui` returns it first when non-NULL. |

## Methods

| Method | Group | Address (ELF) |
|---|---|---|
| `void incSecretsFound( void )` | end-level-stats | 0x14d2e0 |
| `playerStats_s *getLevelStats( void )` | end-level-stats | 0x14d2f0 |
| `void useCustomUI( idUserInterface *ui, idCustomUI *uiEntity )` | custom-ui | 0x14d300 |
| `void clearCustomUI( void )` | custom-ui | 0x14d320 |

## Types

`struct playerStats_s` (0x14 bytes: `int total`, `int found`, `const char *totalVar`, `foundVar`, `percentVar`) is new, and must be declared before `idPlayer`, which holds four by value. Declaration: `reference/end-level-stats.md`.

## Conflicts reconciled

None yet. Checked for end-level-stats: `levelStats` (`+0x1ea4`..`+0x1ef3`) does not overlap the custom-ui members (`+0x1f0c`, `+0x1f10`).
