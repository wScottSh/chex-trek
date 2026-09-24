# HUD map (`idPlayer` HudMap family, `showMap`): reconstructed reference

**Provenance:** reconstructed by **Claude Opus 5.5** on 2026-09-24 from the complete Ghidra export `decomp-so/ghidra-full/` of `gamex86.so` (Ghidra 12.1.4, "Non-Returning Functions - Discovered" disabled), enriched export (issue #18: float constants and string literals resolved from `.rodata`). Checks 1-3 pass (issue #22). Export files: `idPlayer_initHudMap_0016bd00.c`, `idPlayer_HudMapLevel_0015e450.c`, `idPlayer_MapImageCoords_0015d340.c`, `idPlayer_updateMap_00164720.c`, `idPlayer_updateMapUI_00160eb0.c`, `idPlayer_updateHudMapAlpha_00164380.c` and `idPlayer_Cmd_ShowMap_f_00160c00.c`. Facts marked *binary* were read straight from `gamex86.so` (symbol table, relocations, disassembly). Reference material only, not original source. The original source does not exist.

**Depends on:** `objectives` (for idPlayer::objectives, MAX_OBJS, the HudMapLevel declaration and mkObjective::mapLevel).

Scope (spec #16, issue #22): `idPlayer::initHudMap`, `HudMapLevel`, `MapImageCoords`, `updateMap`, `updateMapUI`, `updateHudMapAlpha`, the `showMap` console command (`idPlayer::Cmd_ShowMap_f`) and its registration, and the `hudmap_alpha` global they share. Addresses below are ELF virtual addresses. Ghidra's are `+0x10000`. Stock DOOM-3 GPL source (a9c49da) is referenced, not repeated.

## Header

```cpp
// ---------------------------------------------------------------------------
// HUD map
// The player's map of the level, shown on the HUD (a corner box, always centered on the player)
// and on the PDA (a full view the player can scroll and zoom). Each map level (floor) has a map
// material, guis/hud_maps/<map name><level>, whose first stage takes its alpha from a
// "fog of war" image the game draws at run time: walking through the level reveals the map
// around the player. Positions of the player and of the objectives (objectives.md) are drawn on
// top. The level's worldspawn sets the map's extent and floors (initHudMap).
// ---------------------------------------------------------------------------

// The fog-of-war images, one per map level: 128 x 128 RGBA texels each, only alpha (byte 3) used.
// Uploaded as "textures/guis/hudmap_alpha<level>.tga" (updateHudMapAlpha).
// Binary: global symbol hudmap_alpha, 0x50000 bytes in .bss. It names Player.cpp's static
// initializer (_GLOBAL__I_hudmap_alpha), so it is the first global defined in Player.cpp.
// UNCERTAIN: the declared shape. The code indexes it as [ level ][ ( y * 128 + x ) * 4 + 3 ]
// and memsets 0x10000 bytes per level.
extern byte				hudmap_alpha[ 5 ][ 128 * 128 * 4 ];

// idPlayer::mapControl bits: the PDA map's buttons (guis/pda.gui, guis/pda_chex.gui) send these
// GUI commands, and the edited stock idPlayer::HandleSingleGuiCommand sets the bits (see Notes).
// Scrolling replaces the whole value; centering and zooming add a bit.
// UNCERTAIN: names and form (enum or #defines). Only the values are known.
enum {
	MAP_CENTER			= BIT( 0 ),		// "map_scroll_center": keep the view on the player
	MAP_ZOOM_IN			= BIT( 1 ),		// "map_zoom_in"
	MAP_ZOOM_OUT		= BIT( 2 ),		// "map_zoom_out"
	MAP_SCROLL_UP		= BIT( 3 ),		// "map_scroll_up"
	MAP_SCROLL_DOWN		= BIT( 4 ),		// "map_scroll_down"
	MAP_SCROLL_LEFT		= BIT( 5 ),		// "map_scroll_left"
	MAP_SCROLL_RIGHT	= BIT( 6 )		// "map_scroll_right"
};

// ---------------------------------------------------------------------------
// idPlayer additions used by this feature (full list: reference/idPlayer-additions.md)
// UNCERTAIN: where in the idPlayer declaration these sit, their access level, and all member
// names. Only the offsets and types are known. They are the first idPlayer additions:
// +0x1e30 is the stock sizeof( idPlayer ), 0x1e1c in a GCC 12 -m32 build, plus the 0x14 bytes
// this build's stock idPlayer members are shifted by (objectives.md, Notes).
// ---------------------------------------------------------------------------

class idPlayer : public idActor {
	// ... stock members ...
public:
	void					initHudMap( void );
	void					updateMap( void );
	void					updateMapUI( idUserInterface *gui, int level, bool isHud );
	void					updateHudMapAlpha( int level );
	void					MapImageCoords( float width, float height, const idVec2 &pos, idVec2 &out );
	// int HudMapLevel( const idVec3 *pos ) is this group's too, but it is declared in
	// objectives.md's header block: addObjective calls it, and that group compiles first.

	// Console command "showMap" (registered in idGameLocal::InitConsoleCommands). Static: the
	// binary calls it with the idCmdArgs only, and the command system holds a plain function pointer.
	static void				Cmd_ShowMap_f( const idCmdArgs &args );

	int						mapControl;			// +0x1e30  MAP_* bits. Init zeroes it. Not saved.
	float					mapScale;			// +0x1e34  PDA zoom, "map_scale" (default 1), 0.1 .. 9. Saved.
	idVec2					mapView;			// +0x1e38  world x, y at the center of the map box. Not saved.
	int						mapRadius;			// +0x1e40  reveal radius in alpha texels, "map_radius" (default 8). Saved.
	float					mapWidth;			// +0x1e44  map image width at scale 1, GUI units, "map_x" (default 640). Saved.
	float					mapHeight;			// +0x1e48  map image height at scale 1, GUI units, "map_y" (default 480). Saved.
	float					revealDistance;		// +0x1e4c  distance to move before revealing again: one alpha texel. Saved.
	idVec3					lastRevealOrigin;	// +0x1e50  origin at the last reveal. Init zeroes it. Not saved.
	int						unknown1e5c;		// +0x1e5c  Init sets -1; Save / Restore write / read it; no other use
	idStr					mapMaterial;		// +0x1e60  "guis/hud_maps/<map name>": material name without the level. Saved.
	float					mapLevels[ 5 ];		// +0x1e80  "map_level_0" ... "map_level_4": floor height of each map level. Not saved.
	idVec4					mapCoords;			// +0x1e94  "map_coords": left, top, right, bottom world coordinates of the map image. Saved.
};
```

## Implementation

```cpp
// ===========================================================================
// idPlayer additions (Player.cpp)
// ===========================================================================

byte hudmap_alpha[ 5 ][ 128 * 128 * 4 ];

/*
================
idPlayer::initHudMap

Reads the HUD map settings from the worldspawn. Called from idPlayer::Spawn (0x16f77b).
================
*/
void idPlayer::initHudMap( void ) {
	float	width;
	float	height;

	// The binary reads gameLocal.world again for every key (gameLocal+0x8f68: the offset the
	// stock idWorldspawn::Spawn in this binary stores `this` to).
	if ( !gameLocal.world ) {
		return;
	}

	if ( !gameLocal.world->spawnArgs.GetVec4( "map_coords", "0 0 0 0", mapCoords ) ) {
		common->Warning( "No map_coords set in world spawn, hud map won't work" );	// idCommon vtable +0x50
	}

	// "maps/e1m1.map" -> "guis/hud_maps/e1m1": Right() drops the first 5 characters, "maps/".
	idStr mapName = gameLocal.GetMapName();
	mapName.StripFileExtension();
	// UNCERTAIN: the form of this assignment. The binary builds a temporary idStr from the text
	// (inline constructor; the text is stored as instruction immediates, 0x15bdd4-0x15be08, not in
	// .rodata), copies it in with operator=( const idStr & ) and frees it. A plain
	// mapMaterial = "guis/hud_maps/" would call the out-of-line operator=( const char * ).
	mapMaterial = idStr( "guis/hud_maps/" );
	mapMaterial += mapName.Right( mapName.Length() - 5 );

	// Floors of the map levels. Level 0 defaults to -131072 (MIN_WORLD_COORD), 1-4 to 131072
	// (MAX_WORLD_COORD): with no keys, every position is on level 0. The binary passes the
	// defaults to va( "%f" ) as doubles.
	// UNCERTAIN: five statements or a loop. The binary has five calls in a row.
	gameLocal.world->spawnArgs.GetFloat( va( "map_level_%d", 0 ), va( "%f", -131072.0 ), mapLevels[ 0 ] );
	gameLocal.world->spawnArgs.GetFloat( va( "map_level_%d", 1 ), va( "%f", 131072.0 ), mapLevels[ 1 ] );
	gameLocal.world->spawnArgs.GetFloat( va( "map_level_%d", 2 ), va( "%f", 131072.0 ), mapLevels[ 2 ] );
	gameLocal.world->spawnArgs.GetFloat( va( "map_level_%d", 3 ), va( "%f", 131072.0 ), mapLevels[ 3 ] );
	gameLocal.world->spawnArgs.GetFloat( va( "map_level_%d", 4 ), va( "%f", 131072.0 ), mapLevels[ 4 ] );

	gameLocal.world->spawnArgs.GetFloat( "map_x", "640", mapWidth );
	gameLocal.world->spawnArgs.GetFloat( "map_y", "480", mapHeight );
	gameLocal.world->spawnArgs.GetInt( "map_radius", "8", mapRadius );
	gameLocal.world->spawnArgs.GetFloat( "map_scale", "1", mapScale );

	// One texel of the 128 x 128 alpha image, in world units, on the map's shorter side.
	// (0.0078125 = 1 / 128; the source may have divided by 128.)
	width = mapCoords[ 2 ] - mapCoords[ 0 ];
	height = mapCoords[ 1 ] - mapCoords[ 3 ];
	revealDistance = ( ( width <= height ) ? width : height ) * 0.0078125f;
}

/*
================
idPlayer::HudMapLevel

The map level (0-4) at height pos->z, or at the player's middle when pos is NULL: the highest
level whose floor (mapLevels) is at or below it. Below level 0's floor: warns, and returns 0.
================
*/
int idPlayer::HudMapLevel( const idVec3 *pos ) {
	float	z;
	int		level;

	if ( pos ) {
		z = pos->z;
	} else {
		// Half the standing height above the origin (the feet). pm_normalheight: stock cvar.
		z = 0.5f * pm_normalheight.GetFloat() + GetPhysics()->GetOrigin().z;
	}

	if ( z < mapLevels[ 0 ] ) {
		gameLocal.Warning( "Location below lowest MapLevel" );
		return 0;
	}
	// UNCERTAIN: loop form. The binary tests levels 1-4 one after another (unrolled).
	for ( level = 1; level < 5; level++ ) {
		if ( z < mapLevels[ level ] ) {
			break;
		}
	}
	return level - 1;
}

/*
================
idPlayer::MapImageCoords

World x, y -> position on a map image of width x height (GUI units, or texels), measured from
the image's top left. mapCoords gives the world coordinates of the image's edges; world y grows
up, image y down.
================
*/
void idPlayer::MapImageCoords( float width, float height, const idVec2 &pos, idVec2 &out ) {
	out.x = ( pos.x - mapCoords[ 0 ] ) * width / ( mapCoords[ 2 ] - mapCoords[ 0 ] );
	out.y = ( mapCoords[ 1 ] - pos.y ) * height / ( mapCoords[ 1 ] - mapCoords[ 3 ] );
}

/*
================
idPlayer::updateMap

Every frame (called from idPlayer::Think, 0x16e558): redraws the PDA map while the PDA is open
and on its map page, the HUD map while it is shown, and reveals the map around the player.
================
*/
void idPlayer::updateMap( void ) {
	int level;

	// gameLocal+0x251890: the byte stock code in this binary tests as isMultiplayer (e.g.
	// idGameLocal::CheatsOk). objectiveSystem is the PDA GUI (+0x142c), hud +0x1428,
	// objectiveSystemOpen +0x1430 (see objectives.md, Notes).
	if ( gameLocal.isMultiplayer || !objectiveSystem || !hud ) {
		return;
	}

	level = HudMapLevel( NULL );
	// "HudMap" is set to 1 by the GUIs while their map is visible. idUserInterface vtable +0x4c GetStateBool.
	if ( objectiveSystemOpen && objectiveSystem->GetStateBool( "HudMap", "0" ) ) {
		updateMapUI( objectiveSystem, level, false );
	}
	if ( hud->GetStateBool( "HudMap", "0" ) ) {
		updateMapUI( hud, level, true );
	}
	updateHudMapAlpha( level );
}

/*
================
idPlayer::updateMapUI

Sets one GUI's map variables. The map box is 640 x 480 GUI units (each GUI scales them to its
box). The HUD map is always centered on the player; the PDA map follows mapControl.
================
*/
void idPlayer::updateMapUI( idUserInterface *gui, int level, bool isHud ) {
	int				i;
	int				color;
	float			width;
	float			height;
	idVec2			mapPos;
	idVec2			iconPos;
	mkObjective *	obj;

	// Taken before this frame's zoom step: a zoom shows from the next frame on.
	width = mapWidth * mapScale;
	height = mapScale * mapHeight;

	if ( ( mapControl & MAP_CENTER ) || isHud ) {
		mapView.x = GetPhysics()->GetOrigin().x;
		mapView.y = GetPhysics()->GetOrigin().y;
	}
	if ( !isHud ) {
		// 1% per frame, between 0.1 and 9.
		if ( ( mapControl & MAP_ZOOM_OUT ) && mapScale > 0.1f ) {
			mapScale += mapScale / -100.0f;
		}
		if ( ( mapControl & MAP_ZOOM_IN ) && mapScale < 9.0f ) {
			mapScale += mapScale / 100.0f;
		}
		// 16 world units per frame, up to the map's edge. Compared with ==: only while no other
		// bit is set.
		switch ( mapControl ) {
			case MAP_SCROLL_UP:
				if ( mapView.y < mapCoords[ 1 ] ) {
					mapView.y += 16.0f;
				}
				break;
			case MAP_SCROLL_DOWN:
				if ( mapView.y > mapCoords[ 3 ] ) {
					mapView.y -= 16.0f;
				}
				break;
			case MAP_SCROLL_LEFT:
				if ( mapView.x > mapCoords[ 0 ] ) {
					mapView.x -= 16.0f;
				}
				break;
			case MAP_SCROLL_RIGHT:
				if ( mapView.x < mapCoords[ 2 ] ) {
					mapView.x += 16.0f;
				}
				break;
		}
	}

	// Top left of the map image, so that mapView is at the box's center (320, 240).
	MapImageCoords( width, height, mapView, mapPos );
	mapPos.x = 320.0f - mapPos.x;
	mapPos.y = 240.0f - mapPos.y;

	// idUserInterface vtable: +0x38 SetStateString, +0x40 SetStateInt, +0x44 SetStateFloat.
	// The level's map, and the level below it faded underneath (level 0: itself).
	gui->SetStateString( "hud_map_mtr", va( "%s%i", mapMaterial.c_str(), level ) );
	gui->SetStateString( "hud_map_faded_mtr", va( "%s%i", mapMaterial.c_str(), ( level != 0 ) ? level - 1 : 0 ) );
	gui->SetStateInt( "map_w", (int)width );
	gui->SetStateInt( "map_h", (int)height );
	gui->SetStateInt( "map_pos_x", (int)mapPos.x );
	gui->SetStateInt( "map_pos_y", (int)mapPos.y );

	// Icons are 32 x 32: their top left is 16 up and left of the point.
	MapImageCoords( width, height, GetPhysics()->GetOrigin().ToVec2(), iconPos );
	gui->SetStateInt( "player_x", (int)( mapPos.x + iconPos.x ) - 16 );
	gui->SetStateInt( "player_y", (int)( mapPos.y + iconPos.y ) - 16 );
	gui->SetStateFloat( "player_direction", viewAngles.yaw );	// +0x1238 (viewAngles +0x1234)

	for ( i = 0; i < MAX_OBJS; i++ ) {
		obj = objectives[ i ];
		if ( !obj ) {
			continue;
		}
		// The GUIs tint the icon: 1 red (below this level), 2 green (above), 3 white (on it).
		if ( level < obj->mapLevel ) {
			color = 2;
		} else if ( level == obj->mapLevel ) {
			color = 3;
		} else {
			color = 1;
		}
		MapImageCoords( width, height, obj->GetPhysics()->GetOrigin().ToVec2(), iconPos );
		gui->SetStateInt( va( "map_obj%d_x", i + 1 ), (int)( mapPos.x + iconPos.x ) - 16 );
		gui->SetStateInt( va( "map_obj%d_y", i + 1 ), (int)( mapPos.y + iconPos.y ) - 16 );
		gui->SetStateInt( va( "map_obj%d_c", i + 1 ), color );
	}
}

/*
================
idPlayer::updateHudMapAlpha

Reveals the map of this level around the player: raises the alpha of the texels within
mapRadius, 255 at the player fading to 0 at the corners of the 2 x mapRadius square, and
uploads the image. Only after the player moved revealDistance since the last reveal.
================
*/
void idPlayer::updateHudMapAlpha( int level ) {
	int		x;
	int		y;
	int		x0;
	int		y0;
	int		x1;
	int		y1;
	int		alpha;
	float	maxDist;
	idVec2	center;
	byte *	texel;

	if ( ( lastRevealOrigin - GetPhysics()->GetOrigin() ).LengthFast() < revealDistance ) {
		return;
	}
	lastRevealOrigin = GetPhysics()->GetOrigin();

	// The player's texel, then the square around it, clipped to the image.
	MapImageCoords( 128.0f, 128.0f, GetPhysics()->GetOrigin().ToVec2(), center );
	x0 = (int)( center.x - mapRadius );
	if ( x0 < 0 ) {
		x0 = 0;
	}
	y0 = (int)( center.y - mapRadius );
	if ( y0 < 0 ) {
		y0 = 0;
	}
	x1 = x0 + mapRadius * 2;
	if ( x1 > 128 ) {
		x1 = 128;
	}
	y1 = y0 + mapRadius * 2;
	if ( y1 > 128 ) {
		y1 = 128;
	}
	// UNCERTAIN: the expression. The binary computes the int mapRadius * ( mapRadius * 2 ).
	maxDist = idMath::Sqrt( mapRadius * ( mapRadius * 2 ) );

	for ( x = x0; x < x1; x++ ) {
		for ( y = y0; y < y1; y++ ) {
			alpha = (int)( ( 1.0f - ( center - idVec2( x, y ) ).Length() / maxDist ) * 255.0f );
			if ( alpha < 0 ) {
				alpha = 0;
			} else if ( alpha > 255 ) {
				alpha = 255;
			}
			texel = &hudmap_alpha[ level ][ ( y * 128 + x ) * 4 ];
			if ( alpha > texel[ 3 ] ) {
				texel[ 3 ] = alpha;
			}
		}
	}

	if ( renderSystem ) {
		renderSystem->UploadImage( va( "textures/guis/hudmap_alpha%d.tga", level ), hudmap_alpha[ level ], 128, 128 );	// idRenderSystem vtable +0x94
	}
}

/*
================
idPlayer::Cmd_ShowMap_f

Console command "showMap [level]": reveals the whole map of one level (0-4), or of all of them.
================
*/
void idPlayer::Cmd_ShowMap_f( const idCmdArgs &args ) {
	int level;

	if ( args.Argc() > 2 ) {
		gameLocal.Printf( "usage: showMap [level]\n" );
		return;
	}
	if ( args.Argc() == 2 ) {
		level = atoi( args.Argv( 1 ) );
		if ( level < 0 || level > 4 ) {		// binary: one unsigned compare with 4
			gameLocal.Printf( "bad level %s\n", args.Argv( 1 ) );
			return;
		}
		memset( hudmap_alpha[ level ], 0xff, sizeof( hudmap_alpha[ level ] ) );
	} else {
		memset( hudmap_alpha, 0xff, sizeof( hudmap_alpha ) );
	}
	// Not uploaded here: the image changes on screen at the next reveal (updateHudMapAlpha).
}

// ===========================================================================
// Registration (game/gamesys/SysCmds.cpp)
// ===========================================================================

/*
================
idGameLocal::InitConsoleCommands

Excerpt: only the line the mod added. Binary (0x1e7e09-0x1e7e33): cmdSystem->AddCommand
(idCmdSystem vtable +0x10) with "showMap", idPlayer::Cmd_ShowMap_f, flags 0x11, "show the whole
map" and a NULL completion hook, right after the last stock command, "testid", and before the
mod's "takeEnvShots" (env-shots group). The stock ShutdownConsoleCommands removes it with the
other CMD_FL_GAME commands.
================
*/
void idGameLocal::InitConsoleCommands( void ) {
	// ... stock commands, the last "testid" ...
	cmdSystem->AddCommand( "showMap", idPlayer::Cmd_ShowMap_f, CMD_FL_GAME|CMD_FL_CHEAT, "show the whole map" );
	// ... "takeEnvShots" (env-shots group) ...
}
```

## Notes

- **Names agree with `objectives.md`.** `HudMapLevel` is declared there (its caller `addObjective` is in that group) and defined here. `updateMapUI` reads `objectives[ i ]` (+0x1ef4) and each objective's `mapLevel` (+0x2c0), the values `addObjective` stores. The new members are added to `reference/idPlayer-additions.md`; they fill +0x1e30 .. +0x1ea3, right before `levelStats` (+0x1ea4), and overlap nothing listed there.
- **GUIs, cross-checked with `guis/`.**
  - `guis/hud.gui` (HUD corner box, 200 x 150) and `guis/pda.gui` / `guis/pda_chex.gui` (PDA map page, 570 x 390) read exactly the variables `updateMapUI` sets: `hud_map_mtr` (`map` window), `hud_map_faded_mtr` (`faded_map`, drawn at 0.25 alpha under it), `map_w`, `map_h`, `map_pos_x`, `map_pos_y` (both windows' rects, scaled from 640 x 480), `player_x`, `player_y` and `player_direction` (`map_direction`, `rotate`), and `map_obj1_x` ... `map_obj5_c` (`objective_1` ... `objective_5`; `_c` 1, 2, 3 set the icon's matcolor to red, green, white).
  - The older HUDs `guis/hud2.gui`, `guis/hud_old.gui` and `guis/hud_stoney.gui` read `hud_map_mtr`, `map_pos_x`, `map_pos_y` and `player_direction` (and `HudMap`, which they only read; only `hud.gui` and `pda_chex.gui` set it), plus `map_scale_x` / `map_scale_y` for the map's size, which nothing in the binary sets (the text `map_scale_x` is not in `gamex86.so`): an earlier version of the map, apparently. The player's HUD is `guis/hud.gui` (`def/player.def`, `"hud"`).
  - `HudMap` is the GUIs' own flag: `hud.gui`'s `hudmap_open` / `hudmap_close` windows set it to 1 / 0 (the named events `openMap` / `closeMap`), and `pda_chex.gui` sets it when its map page opens and closes. `pda.gui` only reads it.
  - The PDA's arrow, center and zoom buttons send `map_scroll_up`, `map_scroll_down`, `map_scroll_left`, `map_scroll_right`, `map_scroll_center`, `map_zoom_in`, `map_zoom_out`, and `map_stop` on release: the command names the edited `HandleSingleGuiCommand` compares (see the leads below). `pda_chex.gui` also sends `map_scroll_center` when its map page opens.
- **Map data, cross-checked with `def/`, `maps/` and `materials/`.**
  - `def/misc.def` (`worldspawn`) documents `map_coords` ("top left, and lower right corners", e.g. `-256 256 256 -256`: left, top, right, bottom, as `MapImageCoords` uses them), `map_x`, `map_y` and `map_radius` ("in pixels of an alpha image 128x128"). `map_scale` and `map_level_N` are not documented there.
  - Maps: `e1m1`, `e1m1_2`, `rail_1`, `credits` set `map_coords "-1768 1840 1752 -2120"`, `map_x "640"`, `map_y "800"`, `map_radius "12"`; `sf_923` and `storage_facility` set `"-1856 2240 384 -1408"`, 640, 1000, 12. Only `e1m1` (`map_level_0 "-256"`) and `sf_923` (`map_level_0 "-128"`) set a level floor. No map sets `map_scale`.
  - `materials/chex_gui.mtr` defines `guis/hud_maps/e1m10` and `guis/hud_maps/sf_9230` (`mapMaterial` + level 0): a `maskcolor` stage with `textures/guis/hudmap_alpha0` (the uploaded image, so only its alpha is written) under the map picture blended with `gl_dst_alpha`. No material exists for levels 1-4, nor for the other maps.
  - The HUD map is toggled with impulse 23 (`bind m "_impulse23"` in `autoexec.cfg`, `matt.cfg`, `scott.cfg`), see the leads below.
- **`showMap` registration.** Name `"showMap"`, function `idPlayer::Cmd_ShowMap_f`, flags `CMD_FL_GAME|CMD_FL_CHEAT` (0x11), description `"show the whole map"`, no completion hook (NULL). It is a cheat command. The registration's strings are read by the stock `idGameLocal::InitConsoleCommands`, which is not a covered function, so check 2 does not cover them; they were read from the disassembly (the excerpt in the implementation block). `ArgCompletion_GuiName` is not used by `showMap` (it is `g_PDA`'s, `custom-ui.md`).
- **Behavior worth knowing (binary, not checked in-game).**
  - The fog of war is a single global, not per player, and is not reset per map by this group's code: `idPlayer::Init` zeroes it (lead below). `showMap` fills whole levels with 0xff (RGB too, which the `maskcolor` stage ignores) but does not upload; the change shows at the next reveal, and only for the level the player is on.
  - Only the current level is revealed. `revealDistance` is one texel of the shorter map side, so the image is redrawn about once per texel of movement.
  - `hud_map_faded_mtr` at level 0 is the level 0 map itself.
  - Scrolling (`==` compare) stops while a zoom or center bit is set; `map_stop` keeps only `MAP_CENTER`, and only when a zoom bit was set with it.
- **Stock-inline callees (check 1 allow-list).** `initHudMap`: `strlen`, `strcpy`, `idStr::ReAllocate` inside `idStr( const char * )`, `idStr::operator=( const idStr & )` and `operator+=( const idStr & )`; `idStr::Mid` inside `idStr::Right`; `idStr::FreeData` inside `~idStr()` (all `ID_INLINE`, `idlib/Str.h`). `Cmd_ShowMap_f`: `__strtol_internal` inside glibc's inline `atoi` (kind `libc-inline`, new with this group: the inline function is the C library's, not the SDK's). Each is on `verify/allowlist.tsv` for the exact function.
- **Literals (check 2).** Every string and float the group's functions read appears with its value. Allow-listed (`verify/literal-allowlist.tsv`, `stock-inline`): `updateHudMapAlpha`'s 0.5 and 1.5 are the Newton steps of `idMath::RSqrt` (in `idVec3::LengthFast`) and `idMath::InvSqrt` (in `idMath::Sqrt` and `idVec2::Length`); `Cmd_ShowMap_f`'s `""` is `idCmdArgs::Argv`'s out-of-range result (`idlib/CmdArgs.h`). `HudMapLevel`'s 0.5 is its own. `"guis/hud_maps/"` is not in `.rodata`: the binary stores its text as `mov` immediates, and check 2 accepts it from there (new with this group, `binary.immediate_bytes`). `1.0f` in `updateHudMapAlpha` is an `fld1`, not a constant read.
- **Compile (check 3).** Compiles with g++ 12 `-m32` against stock DOOM-3 GPL a9c49da, on top of `objectives.md`'s header block (the **Depends on** line). The `idPlayer` partial declaration is spliced into a scratch copy of `game/Player.h`. The `idGameLocal::InitConsoleCommands` excerpt compiles as a definition in this translation unit only; the stock body is not repeated.
- **Offsets.** Vtable offsets (`idUserInterface`: `SetStateString` +0x38, `SetStateInt` +0x40, `SetStateFloat` +0x44, `GetStateBool` +0x4c; `idRenderSystem::UploadImage` +0x94; `idCommon::Warning` +0x50; `idCmdSystem::AddCommand` +0x10) were matched with a GCC 12 `-m32` build of the stock headers (pointer-to-virtual-member values). `gameLocal.world` (+0x8f68) and `gameLocal.isMultiplayer` (+0x251890) are 0x10 bytes past their GCC 12 stock offsets (0x8f58, 0x251880); `viewAngles` (+0x1234, stock `idPlayer::SetViewAngles` in this binary stores there) is 0x10 past stock 0x1224. `pm_normalheight.GetFloat()` is `internalVar` (+0x2c) then `floatValue` (+0x28) of the stock `idCVar`.
- **Edits inside stock functions (out of scope for spec #16, recorded as leads).** A scan of all code for `[reg + disp]` operands in +0x1e30..+0x1ea3 found these users besides this group (indexed forms were not scanned):
  - `idPlayer::Spawn` calls `initHudMap` (0x16f77b); `idPlayer::Think` calls `updateMap` (0x16e558).
  - `idPlayer::Init` (0x16acc6-0x16ad21): `mapControl` = 0, `mapView` = 0, `lastRevealOrigin` = 0, `unknown1e5c` = -1, `memset( hudmap_alpha, 0, 0x50000 )`.
  - `idPlayer::Save` (0x152d88-0x152e8f) writes `mapScale`, `mapRadius`, `unknown1e5c`, `revealDistance`, `mapWidth`, `mapHeight`, `mapCoords`, `mapMaterial`, then all of `hudmap_alpha`, one `WriteByte` per byte. `idPlayer::Restore` (0x168b19-0x168bdd) reads them back in the same order. `mapControl`, `mapView`, `lastRevealOrigin` and `mapLevels` are not saved. Only `initHudMap` sets `mapLevels`, and only `idPlayer::Spawn` calls it; the constructors do not set them.
  - Both constructors construct `mapMaterial`, the three destructors free it.
  - `idPlayer::HandleSingleGuiCommand` (0x16d96e-0x16db5b): `map_stop` sets `mapControl` to `MAP_CENTER` if it had a zoom bit and `MAP_CENTER`, else 0; `map_zoom_in` / `map_zoom_out` / `map_scroll_center` OR in their bit; the four scroll commands set `mapControl` to theirs.
  - `idPlayer::PerformImpulse`, impulse 23 (jump table entry, 0x16cb92-0x16cd7c): if `hud` exists, `hud->HandleNamedEvent( "closeMap" )` when `hud->GetStateBool( "HudMap", "0" )`, else `"openMap"`.
- **Ghidra artifacts.**
  - `initHudMap`: the stack runs `uStack_44` ... `uStack_36` are the temporary `idStr( "guis/hud_maps/" )` (`0x73697567` = "guis", ...), and `sStack_70` / `sStack_30` the `mapName` and `Right()` temporaries; the loops and `ReAllocate` calls are inlined `idStr` code. `va("%f",0,0xc1000000,piVar10)` is `va( "%f", -131072.0 )`: two stack words of one double, `piVar10` is noise.
  - `updateMapUI`: the goto maze is the two zoom `if`s and the `switch`. `&UNK_00371d3c`, `&UNK_00371d54`, `&UNK_00371d64`, `&UNK_00371d77` are the strings `"hud_map_faded_mtr"`, `"map_h"`, `"map_pos_y"`, `"player_y"` (Ghidra did not type them). `cVar1` is the int color.
  - `updateHudMapAlpha`: `fStack_14 = 2.044611e-39` is a stale stack slot. `0x5f3759df - (i >> 1)` is `idMath::RSqrt` (`idVec3::LengthFast`), and the `PTR_iSqrt` lookups with `0x17c` are `idMath::InvSqrt` (inside `idMath::Sqrt`).
  - `HudMapLevel`: `(z >= mapLevels[4]) + 4` then `- 1` is the unrolled loop's last step.
  - `Cmd_ShowMap_f`: `param_1 + 8` is `argv[ 1 ]` (`idCmdArgs`: `argc` +0, `argv` +4); `__strtol_internal( s, 0, 10, 0 )` is `atoi`.
- **Open questions (need an in-game check or more binary work).**
  - `unknown1e5c`: set to -1, saved and restored, never read.
  - Whether `mapLevels` are valid after loading a save: they are not saved, and whether `idPlayer::Spawn` (hence `initHudMap`) runs on a load was not checked.
  - `hudmap_alpha` is only zeroed in `idPlayer::Init`; whether the fog of war carries over between maps depends on when `Init` runs, not checked.
