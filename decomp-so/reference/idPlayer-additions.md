# `idPlayer` additions: consolidated list

**Provenance:** compiled by **Claude Opus 5.5** from the group references in this folder. Those were reconstructed from the complete Ghidra export `decomp-so/ghidra-full/` of `gamex86.so` (Ghidra 12.1.4, discovered non-returning functions disabled), with offsets checked against the binary's disassembly. Reference material only.

One place for every `idPlayer` member and method the mod added, so they can be added to a modern `idPlayer` together. Each feature group adds its own rows. If a group finds a conflict (same offset, different type or meaning), fix it here and note it in the group's Notes.

Offsets are from the start of `idPlayer` in this build (`this + offset`). Names are ours; the binary keeps only method names. UNCERTAIN: where each member sat in the source declaration. Only the offsets are known, and stock `idPlayer` members around them were not mapped.

## Members

| Offset | Type | Name | Group | Evidence (binary) |
|---|---|---|---|---|
| `+0x1e30` | `int` | `mapControl` | hud-map | `MAP_*` bits: `updateMapUI` tests 1, 2, 4 and compares with 8, 0x10, 0x20, 0x40. `HandleSingleGuiCommand` sets them for the `map_*` GUI commands, `Init` zeroes it. The first addition: stock `sizeof( idPlayer )` (0x1e1c, GCC 12 `-m32`) + 0x14. Declaration: `reference/hud-map.md`. |
| `+0x1e34` | `float` | `mapScale` | hud-map | `initHudMap` reads `"map_scale"` into it; `updateMapUI` multiplies `+0x1e44` / `+0x1e48` by it and steps it by 1% between 0.1 and 9. Saved. |
| `+0x1e38` | `idVec2` (to `+0x1e3f`) | `mapView` | hud-map | `updateMapUI` sets it to the player's origin x, y, scrolls it by 16 and passes `this + 0x1e38` to `MapImageCoords` as `const idVec2 &`. `Init` zeroes it. |
| `+0x1e40` | `int` | `mapRadius` | hud-map | `initHudMap`: `GetInt( "map_radius", "8" )`. `updateHudMapAlpha` sizes the revealed square with it. Saved. |
| `+0x1e44` | `float` | `mapWidth` | hud-map | `initHudMap`: `GetFloat( "map_x", "640" )`. Saved. |
| `+0x1e48` | `float` | `mapHeight` | hud-map | `initHudMap`: `GetFloat( "map_y", "480" )`. Saved. |
| `+0x1e4c` | `float` | `revealDistance` | hud-map | `initHudMap` stores min( map width, height ) * 1/128; `updateHudMapAlpha` compares the distance moved with it. Saved. |
| `+0x1e50` | `idVec3` (to `+0x1e5b`) | `lastRevealOrigin` | hud-map | `updateHudMapAlpha` measures from it and stores the origin in it. `Init` zeroes it. |
| `+0x1e5c` | `int` | `unknown1e5c` | hud-map | `Init` sets -1, `Save` / `Restore` write / read it. No other use found. |
| `+0x1e60` | `idStr` (0x20 bytes, to `+0x1e7f`) | `mapMaterial` | hud-map | `initHudMap` builds `"guis/hud_maps/<map>"` in it; `updateMapUI` passes its `data` (`+0x1e64`) to `va( "%s%i" )`. The constructors construct it, the destructors free it. |
| `+0x1e80` | `float[ 5 ]` (to `+0x1e93`) | `mapLevels` | hud-map | `initHudMap` reads `"map_level_0"` ... `"map_level_4"` into `+0x1e80` ... `+0x1e90`; `HudMapLevel` compares a height with each. |
| `+0x1e94` | `idVec4` (to `+0x1ea3`) | `mapCoords` | hud-map | `initHudMap`: `GetVec4( "map_coords", "0 0 0 0", this + 0x1e94 )`. `MapImageCoords` maps world x, y with it. Saved. |
| `+0x1ea4` | `playerStats_s[ 4 ]` (0x50 bytes, to `+0x1ef3`) | `levelStats` | end-level-stats | `getLevelStats` returns `this + 0x1ea4`. Both constructors `memset` 0x50 bytes there. `idPlayer::Spawn` fills it (`GetLevelStats`, start time at `+0x1ee0`, GUI variable names at `+0x1eac`...`+0x1ee8`). `incSecretsFound` increments `+0x1ed0` (`[2].found`), `AddAIKill` `+0x1ea8` (`[0].found`), `GiveItem` `+0x1ebc` (`[1].found`). Element type and layout: `reference/end-level-stats.md`. |
| `+0x1ef4` | `mkObjective *[ MAX_OBJS ]` (5, to `+0x1f07`) | `objectives` | objectives | `addObjective` stores its `mkObjective *` at `this + nextObjective * 4 + 0x1ef4` (first NULL slot from `nextObjective` on), `freeObjective( num )` NULLs `this + num * 4 + 0x1ef0` (slot `num - 1`). `updateMapUI` reads each slot's `+0x2c0` (`mkObjective::mapLevel`). Both constructors NULL all five. Declaration: `reference/objectives.md`. |
| `+0x1f08` | `int` | `nextObjective` | objectives | `addObjective` compares it with 5, reads/increments it and returns it after the store (the objective's number, slot + 1). `freeObjective` sets it to its argument. Constructors and `idPlayer::Init` zero it. |
| `+0x1f0c` | `idCustomUI *` | `customUIEntity` | custom-ui | `useCustomUI` stores its 2nd argument (`idCustomUI *`), `clearCustomUI` zeroes it. `HandleSingleGuiCommand` calls `HandleCustomGUICommand` (vtable slot 59, `[vptr+0xe4]`) on it. |
| `+0x1f10` | `idUserInterface *` | `customUI` | custom-ui | `useCustomUI` stores its 1st argument (`idUserInterface *`), `clearCustomUI` zeroes it. `ActiveGui` returns it first when non-NULL. |

## Methods

| Method | Group | Address (ELF) |
|---|---|---|
| `void incSecretsFound( void )` | end-level-stats | 0x14d2e0 |
| `playerStats_s *getLevelStats( void )` | end-level-stats | 0x14d2f0 |
| `int addObjective( mkObjective *obj, const idVec3 &origin, int &level )` | objectives | 0x14e520 |
| `void freeObjective( int num )` | objectives | 0x14d390 |
| `int HudMapLevel( const idVec3 *pos )` | hud-map (declared in `objectives.md`, whose `addObjective` calls it; body in `hud-map.md`) | 0x14e450 |
| `void initHudMap( void )` | hud-map | 0x15bd00 |
| `void MapImageCoords( float width, float height, const idVec2 &pos, idVec2 &out )` | hud-map | 0x14d340 |
| `void updateMap( void )` | hud-map | 0x154720 |
| `void updateMapUI( idUserInterface *gui, int level, bool isHud )` | hud-map | 0x150eb0 |
| `void updateHudMapAlpha( int level )` | hud-map | 0x154380 |
| `static void Cmd_ShowMap_f( const idCmdArgs &args )` | hud-map | 0x150c00 |
| `void useCustomUI( idUserInterface *ui, idCustomUI *uiEntity )` | custom-ui | 0x14d300 |
| `void clearCustomUI( void )` | custom-ui | 0x14d320 |
| `void addItemText( const idItemInfo &info )` | objectives | 0x16f990 |
| `void tryOpen( void )` | door-opening | 0x16c420 |

## Types

`struct playerStats_s` (0x14 bytes: `int total`, `int found`, `const char *totalVar`, `foundVar`, `percentVar`) is new, and must be declared before `idPlayer`, which holds four by value. Declaration: `reference/end-level-stats.md`.

The HUD map also adds a global, `byte hudmap_alpha[ 5 ][ 128 * 128 * 4 ]` (the fog-of-war images, defined in `Player.cpp`), and the `MAP_*` bit values of `mapControl` (`reference/hud-map.md`).

`MAX_OBJS` (5) sizes `objectives`. The warning "MAX_OBJS reached!" gives the name. UNCERTAIN whether it was a `#define`: `reference/objectives.md` writes it as a class constant so check 3 can compile it. `class mkObjective;` must be declared before `idPlayer` (`reference/objectives.md`). `idItemInfo` (`addItemText`'s argument) is the stock struct in `Player.h`.

## Conflicts reconciled

None yet. Checked for end-level-stats: `levelStats` (`+0x1ea4`..`+0x1ef3`) does not overlap the custom-ui members (`+0x1f0c`, `+0x1f10`). Checked for objectives: `objectives` (`+0x1ef4`..`+0x1f07`) and `nextObjective` (`+0x1f08`) fill the gap between them exactly, and overlap neither. Checked for hud-map: its twelve members fill `+0x1e30`..`+0x1ea3` without gaps, ending right before `levelStats` (`+0x1ea4`), and overlap no other row. `HudMapLevel` was already listed (declared by objectives); hud-map adds its body, no change. Checked for door-opening: `tryOpen` uses no new members (only the stock `viewAngles`), so it adds a method row only.
