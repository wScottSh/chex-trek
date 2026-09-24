# End-level stats screen (`idTarget_EndLevelGUI`): reconstructed reference

**Provenance:** reconstructed by **Claude Opus 5.5** on 2026-09-24 from the complete Ghidra export `decomp-so/ghidra-full/` of `gamex86.so` (Ghidra 12.1.4, "Non-Returning Functions - Discovered" disabled), enriched export (issue #18: float constants and string literals resolved from `.rodata`). Checks 1-3 pass (issue #20). Export files: `idTarget_EndLevelGUI_*.c` (11 files), `idPlayer_getLevelStats_0015d2f0.c`, `idPlayer_incSecretsFound_0015d2e0.c`, `idGameLocal_GetLevelStats_00100800.c` and `idStr_FormatTime_00354230.c`. Facts marked *binary* were read straight from `gamex86.so` (symbol table, vtables, RTTI, relocations, disassembly). Reference material only, not original source. The original source does not exist.

**Depends on:** `custom-ui` (for idCustomUI, the base class, and its gui member).

Scope (spec #16, issue #20): the `idTarget_EndLevelGUI` class, its `<UpdateEndLevelStats>` event and `g_statTicTime` cvar, the `playerStats_s` record, `idPlayer::getLevelStats` / `incSecretsFound`, `idGameLocal::GetLevelStats` and `idStr::FormatTime`. In the binary, `getLevelStats` and `FormatTime` are called only from `idTarget_EndLevelGUI`. Addresses below are ELF virtual addresses. Ghidra's are `+0x10000`. Stock DOOM-3 GPL source (a9c49da) is referenced, not repeated.

## Header

```cpp
// ---------------------------------------------------------------------------
// playerStats_s
// One line of the stats screen: a count and the names of the GUI state variables that show it.
// The player keeps four (idPlayer::levelStats): [0] monsters, [1] items, [2] secrets, [3] level
// time. Evidence (binary): idPlayer::Spawn fills the name pointers, 0x14 bytes apart, with
// "ai_total", "ai_killed", "ai_percent" (at +0x1eac/+0x1eb0/+0x1eb4), "items_total", "items_found",
// "items_percent" (+0x1ec0...), "secrets_total", "secrets_found", "secrets_percent" (+0x1ed4...)
// and "level_time" (+0x1ee8); idPlayer's constructors memset all 0x50 bytes at +0x1ea4.
// updateStats( playerStats_s *, playerStats_s * ) is called with pointers 0x14 apart
// (base + state * 0x14), so sizeof( playerStats_s ) is 0x14 and the four are an array.
// UNCERTAIN: the field names, and whether the source also had a typedef (playerStats_t).
// The mangled names use the struct tag playerStats_s.
// ---------------------------------------------------------------------------
struct playerStats_s {
	int						total;			// +0x00  how many the level has. [3]: the level time in ms
	int						found;			// +0x04  how many the player got. [3]: not used
	const char *			totalVar;		// +0x08  GUI state variable for total ("ai_total", ..., "level_time")
	const char *			foundVar;		// +0x0c  GUI state variable for found ("ai_killed", ...). [3]: NULL
	const char *			percentVar;		// +0x10  GUI state variable for found/total in % ("ai_percent", ...). [3]: NULL
};

// ---------------------------------------------------------------------------
// idTarget_EndLevelGUI
// Shows the end-of-level stats GUI to the local player, counts each stat up on it, then starts
// the next map (or triggers its targets). The entityDef is target_endLevelGUI (def/endlevelgui.def).
//
// Base class: idCustomUI (reference/custom-ui.md), not idTarget. Evidence (binary):
//   1. idTarget_EndLevelGUI::Type is built with superclass name "idCustomUI": the static
//      initializer at 0x18f1d0 loads "idCustomUI" into esi at 0x190fee (the idCustomUI Type's own
//      name) and passes esi again as the superclass name to idTypeInfo::idTypeInfo @ 0x191299,
//      next to "idTarget_EndLevelGUI".
//   2. RTTI: _ZTI20idTarget_EndLevelGUI (0x3cc718) is a __si_class_type_info whose base is
//      _ZTI10idCustomUI (which in turn has base _ZTI8idEntity).
//   3. CreateInstance calls idCustomUI's base constructor (C2 0x18ddb0), then stores this class's
//      vtable. Both destructor clones store this class's vtable, then idCustomUI's (idCustomUI's
//      empty destructor, inlined), then call idEntity's base destructor.
//   4. Vtable _ZTV20idTarget_EndLevelGUI (60 words, 0x3ca820) matches _ZTV10idCustomUI word for
//      word, except for the type, the destructors and slot 59: HandleCustomGUICommand, the virtual
//      idCustomUI added. Slot numbering as in custom-ui.md.
//   5. Its first member is at this+0x284, right after idCustomUI's last (registered, +0x280).
//      sizeof = 0x2e4: CreateInstance allocates 0x2e4 bytes.
// ---------------------------------------------------------------------------
class idTarget_EndLevelGUI : public idCustomUI {
public:
	CLASS_PROTOTYPE( idTarget_EndLevelGUI );

							~idTarget_EndLevelGUI( void );
	// UNCERTAIN: whether ~idTarget_EndLevelGUI() was declared in the source. Both clones (D1
	// 0x199180, D0 0x1993e0) are weak symbols with no code of their own, which is what a
	// compiler-generated destructor gives. Declaring an empty one here behaves the same.
	// No constructor is declared: the binary has no idTarget_EndLevelGUI constructor symbol, and
	// CreateInstance only runs idCustomUI's and stores the vtable.

	void					Spawn( void );
	void					Save( idSaveGame *savefile ) const;
	void					Restore( idRestoreGame *savefile );

	// Overrides idCustomUI's (vtable slot 59). It re-implements "unregister" instead of calling it.
	virtual bool			HandleCustomGUICommand( idEntity *entityGui, idToken *token );

	// UNCERTAIN: access level (public/protected/private) of everything below.
	// UNCERTAIN: member names. Only offsets and types are known.
private:
	// The counts shown so far, one per line of the screen (same order as idPlayer::levelStats).
	// Only total and found are used here, and not with the player's meaning: total holds the
	// percent shown ([3]: the time shown, in ms) and found the count shown. The name pointers stay NULL.
	playerStats_s			displayStats[ 4 ];	// +0x284  zeroed in Spawn; Save/Restore write/read all 0x50 bytes
	int						unknown2d4;			// +0x2d4  zeroed in Spawn, saved and restored, read nowhere else
	int						timeStep;			// +0x2d8  ms added to the shown time per tic (see Event_Activate)
	const idSoundShader *	ticSound;			// +0x2dc  "s_shader", played every tic. Not saved.
	int						state;				// +0x2e0  -1 idle, 0-2 counting stats[state], 3 time, 4 pause, 5 next map

	bool					updateStats( playerStats_s *stats, playerStats_s *display );

	void					Event_Activate( idEntity *activator );
	void					Event_UpdateStats( void );
};

// ---------------------------------------------------------------------------
// idPlayer additions used by this feature (full list: reference/idPlayer-additions.md)
// UNCERTAIN: where in the idPlayer declaration these sit. Only the offsets are known.
// ---------------------------------------------------------------------------
class idPlayer : public idActor {
	// ... stock members ...
public:
	void					incSecretsFound( void );
	playerStats_s *			getLevelStats( void );

	// [0] monsters, [1] items, [2] secrets, [3] level time. Filled in idPlayer::Spawn (see Notes).
	playerStats_s			levelStats[ 4 ];	// +0x1ea4 .. +0x1ef3
};

// ---------------------------------------------------------------------------
// idGameLocal addition (Game_local.h)
// ---------------------------------------------------------------------------
class idGameLocal : public idGame {
	// ... stock members ...
public:
	void					GetLevelStats( playerStats_s *stats );
};

// ---------------------------------------------------------------------------
// idStr addition (idlib/Str.h). Static: the binary passes only the return slot, the format and
// the time (no this). Its code sits in idlib/Str.cpp's run of idStr functions, between
// idStr::DefaultFileExtension and idStr::SetUnit (binary).
// ---------------------------------------------------------------------------
class idStr {
	// ... stock members ...
public:
	static idStr			FormatTime( const char *format, int ms );
};

// Target.cpp globals (defined below). UNCERTAIN whether externs were also added to a header.
extern idCVar			g_statTicTime;
extern const idEventDef	EV_UpdateEndLevelStats;
```

## Implementation

```cpp
// ===========================================================================
// idTarget_EndLevelGUI (Target.cpp: its code and static initializer are shared with idCustomUI
// and the stock idTarget_* classes. UNCERTAIN: file name.)
// ===========================================================================

// Built in Target.cpp's static initializer (idCVar constructor inlined at 0x191136-0x1911aa).
// Stored flags 0x21082 = CVAR_ARCHIVE | CVAR_STATIC | CVAR_GAME | CVAR_INTEGER; idCVar::Init adds
// CVAR_STATIC. valueMin 1.0 / valueMax -1.0 are the constructor defaults (no range given).
idCVar g_statTicTime( "g_statTicTime", "50", CVAR_GAME | CVAR_ARCHIVE | CVAR_INTEGER, "time in MS between tics" );

// idEventDef( "<UpdateEndLevelStats>", NULL, 0 ) @ 0x1911e3: no arguments, no return value.
// The <...> name marks an internal event: scripts cannot call it.
const idEventDef EV_UpdateEndLevelStats( "<UpdateEndLevelStats>" );

// Event table (binary: idTarget_EndLevelGUI::eventCallbacks @ 0x3d5a80 =
// { EV_Activate, Event_Activate }, { EV_UpdateEndLevelStats, Event_UpdateStats }, { NULL }).
CLASS_DECLARATION( idCustomUI, idTarget_EndLevelGUI )
	EVENT( EV_Activate,				idTarget_EndLevelGUI::Event_Activate )
	EVENT( EV_UpdateEndLevelStats,	idTarget_EndLevelGUI::Event_UpdateStats )
END_CLASS

/*
================
idTarget_EndLevelGUI::~idTarget_EndLevelGUI

Possibly not written in the source (see header).
================
*/
idTarget_EndLevelGUI::~idTarget_EndLevelGUI( void ) {
	// Nothing of its own. Both clones reset the vtable pointer to this class's, then to
	// idCustomUI's (idCustomUI::~idCustomUI, inlined), and run idEntity::~idEntity().
	// The D0 clone then frees `this`.
}

/*
================
idTarget_EndLevelGUI::Spawn
================
*/
void idTarget_EndLevelGUI::Spawn( void ) {
	memset( displayStats, 0, sizeof( displayStats ) );
	unknown2d4	= 0;
	state		= -1;
	timeStep	= 0;
	// ticSound is not set here (nor in a constructor): it is set only by Event_Activate.
}

/*
================
idTarget_EndLevelGUI::Save
================
*/
void idTarget_EndLevelGUI::Save( idSaveGame *savefile ) const {
	savefile->Write( displayStats, sizeof( displayStats ) );
	savefile->WriteInt( state );
	savefile->WriteInt( unknown2d4 );
	savefile->WriteInt( timeStep );
}

/*
================
idTarget_EndLevelGUI::Restore
================
*/
void idTarget_EndLevelGUI::Restore( idRestoreGame *savefile ) {
	savefile->Read( displayStats, sizeof( displayStats ) );
	savefile->ReadInt( state );
	savefile->ReadInt( unknown2d4 );
	savefile->ReadInt( timeStep );

	// Scheduled events are not saved, so restart the count if the screen was running.
	if ( state != -1 ) {
		CancelEvents( &EV_UpdateEndLevelStats );
		PostEventMS( &EV_UpdateEndLevelStats, g_statTicTime.GetInteger() );
	}
}

/*
================
idTarget_EndLevelGUI::Event_Activate

Ghidra did not see __thiscall here: its param_1 is `this`, and the activator is never read.
================
*/
void idTarget_EndLevelGUI::Event_Activate( idEntity *activator ) {
	idStr			guiName;
	idStr			soundName;
	idPlayer *		player;
	playerStats_s *	stats;
	int				levelTime;
	int				i;

	if ( gui ) {
		// Already showing: pass the activation on to the GUI (idUserInterface vtable +0x60).
		gui->Trigger( gameLocal.time );
		return;
	}

	player = gameLocal.GetLocalPlayer();
	if ( !player ) {
		return;
	}

	// levelStats[ 3 ].total holds the level's start time (idPlayer::Spawn stores gameLocal.time
	// there). Turn it into the time the level took. (Two getLevelStats() calls in the binary.)
	levelTime = gameLocal.time - player->getLevelStats()[ 3 ].total;
	player->getLevelStats()[ 3 ].total = levelTime;

	// Count the shown time up in at most about 100 tics: the smallest step with
	// timeStep * 100 >= levelTime, and 1 for levelTime <= 100.
	// UNCERTAIN: the loop's form. The binary counts the loop's trips with the closed form
	// ( levelTime - 101 ) / 100 + 2 (unsigned) when levelTime > 100, which is what this loop compiles to.
	timeStep = 1;
	while ( timeStep * 100 < levelTime ) {
		timeStep++;
	}

	if ( !spawnArgs.GetString( "gui", "", guiName ) ) {
		return;
	}
	setGUI( guiName );
	if ( spawnArgs.GetString( "s_shader", "", soundName ) ) {
		ticSound = declManager->FindSound( soundName );		// idDeclManager vtable +0x68
	}
	if ( !gui ) {
		return;
	}

	// idUserInterface vtable: +0x40 SetStateInt, +0x38 SetStateString, +0x58 StateChanged.
	stats = player->getLevelStats();
	// UNCERTAIN: loop or written out. The binary has the 9 calls in this order, unrolled.
	for ( i = 0; i < 3; i++ ) {
		gui->SetStateInt( stats[ i ].foundVar, 0 );
		gui->SetStateInt( stats[ i ].totalVar, stats[ i ].total );
		gui->SetStateInt( stats[ i ].percentVar, 0 );
	}
	gui->SetStateString( stats[ 3 ].totalVar, "00:00:000" );
	gui->SetStateString( "mapname", spawnArgs.GetString( "mapname" ) );
	gui->StateChanged( gameLocal.time );

	RegisterGUI();
	PostEventMS( &EV_UpdateEndLevelStats, g_statTicTime.GetInteger() );
}

/*
================
idTarget_EndLevelGUI::updateStats

Counts one stats line up by one percent. Returns true when the line is done.
display->total is the percent shown, display->found the count shown (see header).
================
*/
bool idTarget_EndLevelGUI::updateStats( playerStats_s *stats, playerStats_s *display ) {
	if ( stats->total == 0 ) {
		// Nothing to find in this level: show 100%.
		gui->SetStateInt( stats->percentVar, 100 );
		gui->StateChanged( gameLocal.time );
		return true;
	}
	if ( display->total < stats->found * 100 / stats->total ) {
		display->total++;
		// Raise the shown count until it matches the shown percent.
		while ( display->found * 100 / stats->total < display->total ) {
			display->found++;
		}
		gui->SetStateInt( stats->foundVar, display->found );
		gui->SetStateInt( stats->percentVar, display->total );
		gui->StateChanged( gameLocal.time );
		return false;
	}
	return true;
}

/*
================
idTarget_EndLevelGUI::Event_UpdateStats

One tic of the stats screen. Reposts itself every g_statTicTime ms, except in states 4 and 5.
================
*/
void idTarget_EndLevelGUI::Event_UpdateStats( void ) {
	if ( ticSound ) {
		StartSoundShader( ticSound, SND_CHANNEL_ANY, 0, false, NULL );
	}

	idStr nextMap;

	switch ( state ) {
		case 0:		// monsters
		case 1:		// items
		case 2:		// secrets
			if ( !updateStats( &gameLocal.GetLocalPlayer()->getLevelStats()[ state ], &displayStats[ state ] ) ) {
				break;		// still counting this line
			}
			state++;
			break;
		case 3:		// level time
			if ( displayStats[ 3 ].total < gameLocal.GetLocalPlayer()->getLevelStats()[ 3 ].total ) {
				displayStats[ 3 ].total += timeStep;
				gui->SetStateString( gameLocal.GetLocalPlayer()->getLevelStats()[ 3 ].totalVar,
					idStr::FormatTime( "mm:ss:MMM", displayStats[ 3 ].total ) );
				break;
			}
			state++;
			break;
		case 4:		// all shown: wait 3 s, then go on
			PostEventMS( &EV_UpdateEndLevelStats, 3000 );
			state++;
			return;
		case 5:		// leave the level, unless a script does it ("extHndNextMap")
			if ( !spawnArgs.GetBool( "extHndNextMap", "0" ) ) {
				UnregisterGUI();
				if ( spawnArgs.GetString( "nextmap", "", nextMap ) ) {
					// As stock idTarget_EndLevel::Event_Activate does (gameLocal+0x251298).
					gameLocal.sessionCommand = "map ";
					gameLocal.sessionCommand += nextMap;
				} else {
					ActivateTargets( this );
				}
			}
			return;
		case -1:	// not started
			state = 0;
			break;
		default:
			break;
	}
	PostEventMS( &EV_UpdateEndLevelStats, g_statTicTime.GetInteger() );
}

/*
================
idTarget_EndLevelGUI::HandleCustomGUICommand

GUI commands: "nextmap" (leave now), "skip" (show the current line's final value),
"unregister" (close). Returns true if the command was handled. entityGui is not used.
================
*/
bool idTarget_EndLevelGUI::HandleCustomGUICommand( idEntity *entityGui, idToken *token ) {
	playerStats_s *	stats;
	int				percent;

	// Static idStr::Icmp( token->data, ... ) in the binary: the inline member Icmp( const char * ).
	if ( token->Icmp( "nextmap" ) == 0 ) {
		state = 5;		// taken by the next tic of Event_UpdateStats
		return true;
	}
	if ( token->Icmp( "skip" ) == 0 ) {
		stats = gameLocal.GetLocalPlayer()->getLevelStats();
		if ( state >= 0 ) {
			if ( state < 3 ) {
				gui->SetStateInt( stats[ state ].foundVar, stats[ state ].found );
				percent = 100;
				if ( stats[ state ].total ) {
					percent = stats[ state ].found * 100 / stats[ state ].total;
				}
				gui->SetStateInt( stats[ state ].percentVar, percent );
				state++;
			} else if ( state == 3 ) {
				gui->SetStateString( stats[ 3 ].totalVar, idStr::FormatTime( "mm:ss:MMM", stats[ 3 ].total ) );
				state++;
			}
		}
		gui->StateChanged( gameLocal.time );
		return true;
	}
	if ( token->Icmp( "unregister" ) == 0 ) {
		CancelEvents( &EV_UpdateEndLevelStats );
		UnregisterGUI();
		return true;
	}
	return false;
}

// ===========================================================================
// idPlayer additions (Player.cpp)
// ===========================================================================

/*
================
idPlayer::incSecretsFound

Called only from idMover_Binary::Use_BinaryMover (binary; a stock function, see Notes).
================
*/
void idPlayer::incSecretsFound( void ) {
	levelStats[ 2 ].found++;		// +0x1ed0
}

/*
================
idPlayer::getLevelStats

Returns the array of four (Ghidra types the result as idPlayer *: `return this + 0x1ea4`).
================
*/
playerStats_s *idPlayer::getLevelStats( void ) {
	return levelStats;
}

// ===========================================================================
// idGameLocal addition (Game_local.cpp: between the stock EntitiesWithinRadius and
// RandomizeInitialSpawns in the binary)
// ===========================================================================

/*
================
idGameLocal::GetLevelStats

Counts the level's monsters, items and secrets into stats[ 0 ].total, [ 1 ] and [ 2 ].
An entity counts once: "secret" wins over "level_item", which wins over "level_monster".
Called only from idPlayer::Spawn, with the player's levelStats (binary).
================
*/
void idGameLocal::GetLevelStats( playerStats_s *stats ) {
	stats[ 0 ].total = 0;
	stats[ 1 ].total = 0;
	stats[ 2 ].total = 0;
	// entities (+0xf44) and num_entities (+0x8f48): the stock idGameLocal layout.
	for ( int i = 0; i < num_entities; i++ ) {
		idEntity *ent = entities[ i ];
		if ( !ent ) {
			continue;
		}
		// UNCERTAIN: GetBool or GetInt. Both compile to atoi( GetString( key, "0" ) ) != 0 here.
		if ( ent->spawnArgs.GetBool( "secret", "0" ) ) {
			stats[ 2 ].total++;
		} else if ( ent->spawnArgs.GetBool( "level_item", "0" ) ) {
			stats[ 1 ].total++;
		} else if ( ent->spawnArgs.GetBool( "level_monster", "0" ) ) {
			stats[ 0 ].total++;
		}
	}
}

// ===========================================================================
// idStr addition (idlib/Str.cpp)
// ===========================================================================

/*
================
idStr::FormatTime

Formats `ms` by a pattern such as "mm:ss:MMM": runs of h, m, s and M are hours, minutes,
seconds and milliseconds, zero-padded to the run's length ("mm" -> "%02i"). A field whose
letter is absent is not split off, so its time stays in the next smaller field.
================
*/
idStr idStr::FormatTime( const char *format, int ms ) {
	idStr	result;
	int		hCount = 0;
	int		mCount = 0;
	int		sCount = 0;
	int		msCount = 0;
	int		hours;
	int		minutes;
	int		seconds;
	int		i;
	char	c;

	// Count each field's letters (over the whole pattern, not per run).
	i = 0;
	do {
		c = format[ i++ ];
		if ( c == 'h' ) {
			hCount++;
		} else if ( c == 'm' ) {
			mCount++;
		} else if ( c == 's' ) {
			sCount++;
		} else if ( c == 'M' ) {
			msCount++;
		}
	} while ( c != '\0' );

	hours = 0;
	if ( hCount ) {
		hours = ms / 3600000;
		ms %= 3600000;
	}
	minutes = 0;
	if ( mCount ) {
		minutes = ms / 60000;
		ms %= 60000;
	}
	seconds = 0;
	if ( sCount ) {
		seconds = ms / 1000;
		ms %= 1000;
	}
	// What is left of ms is the milliseconds field.

	idStr spec;		// the printf spec for one field, e.g. "%02i"
	i = 0;
	do {
		// UNCERTAIN: an explicit FreeData() call. The binary calls FreeData then operator=( "%0" )
		// at the top of each pass, with no Init() (so not Clear(), and not a new idStr per pass).
		spec.FreeData();
		spec = "%0";
		c = format[ i++ ];
		if ( c == 'h' ) {
			spec += va( "%i", hCount );
			spec += 'i';
			result += va( spec, hours );
			while ( ( c = format[ i++ ] ) == 'h' ) {
			}
		} else if ( c == 'm' ) {
			spec += va( "%i", mCount );
			spec += 'i';
			result += va( spec, minutes );
			while ( ( c = format[ i++ ] ) == 'm' ) {
			}
		} else if ( c == 's' ) {
			spec += va( "%i", sCount );
			spec += 'i';
			result += va( spec, seconds );
			while ( ( c = format[ i++ ] ) == 's' ) {
			}
		} else if ( c == 'M' ) {
			spec += va( "%i", msCount );
			spec += 'i';
			result += va( spec, ms );
			while ( ( c = format[ i++ ] ) == 'M' ) {
			}
		}
		// The character after a field (or any other character) is copied as is. This also
		// appends the final '\0', so Length() is one more than strlen() (in the binary too).
		result += c;
	} while ( c != '\0' );

	return result;
}
```

## Notes

- **Base class and names agree with `custom-ui.md`.** `idTarget_EndLevelGUI` derives from `idCustomUI` (evidence in the header). It uses `idCustomUI`'s `gui` (+0x27c), `setGUI`, `RegisterGUI` and `UnregisterGUI` under the names `custom-ui.md` gives them, and overrides vtable slot 59, `HandleCustomGUICommand`. Its first member at +0x284 fits `custom-ui.md`'s `sizeof(idCustomUI)` of 0x281-0x284. The harness compiles this group on top of `custom-ui.md`'s header block (the **Depends on** line).
- **The `updateStats` event.** The binary has no script event named `updateStats`, and no such string. The stats screen's event is `EV_UpdateEndLevelStats`, defined as `idEventDef( "<UpdateEndLevelStats>" )`: no arguments (format spec `NULL`), no return value. It is bound to `idTarget_EndLevelGUI::Event_UpdateStats( void )`. `updateStats` is the name of the non-event helper `idTarget_EndLevelGUI::updateStats( playerStats_s *, playerStats_s * )`, which returns `bool`. Matched to the mod's scripts: no file in `script/`, `maps/` or `def/` names `UpdateEndLevelStats` or `updateStats`, and the `<...>` name cannot be written in a script, so only the C++ code posts it (`Event_Activate`, itself, `Restore`). Scripts drive the screen through the entity instead: they trigger it (`target_endlevelgui_1` is a target in `maps/e1m1.map`) and `script/map_storage_facility.script:101` calls `$target_endlevelgui_2.hide()`.
- **GUI commands** (resolved from the binary's `Icmp` strings): `"nextmap"`, `"skip"`, `"unregister"`. Cross-check with the mod's GUIs: `guis/chex/stats.gui` sends `"skip"` (line 223) and `"nextmap"` (line 238). No GUI in `guis/` sends `"unregister"` (as in `custom-ui.md`). `guis/end_trek.gui`, which the second end-level entity in `maps/sf_923.map` shows, sends only `runScript` commands. This class returns `false` for them, and the stock GUI command code handles them (not checked).
- **GUI state variables** (set by name through `playerStats_s`): `ai_total`, `ai_killed`, `ai_percent`, `items_total`, `items_found`, `items_percent`, `secrets_total`, `secrets_found`, `secrets_percent`, `level_time`, and `mapname`. All 11 appear as `gui::` variables in `guis/chex/stats.gui`.
- **spawnArgs, cross-checked with `def/` and `maps/`.**
  - `gui`: `guis/chex/stats.gui` in `e1m1.map`, `e1m1_2.map` and `sf_923.map`. `guis/end_trek.gui` on `sf_923.map`'s `target_endlevelgui_2`.
  - `s_shader`: default `sound/chex/level_stats` in `def/endlevelgui.def`. `sf_923.map`'s `target_endlevelgui_2` sets it to `""`, which still takes the `FindSound` branch (`FindSound( "" )`, what that returns is not checked).
  - `mapname`: "Landing Zone" (`e1m1`), "Storage Facility" (`sf_923`).
  - `extHndNextMap`: `"1"` only on `sf_923.map`'s `target_endlevelgui_2`, whose screen a script closes.
  - `nextmap`: set on no `target_endlevelgui` in `maps/`, so every screen ends with `ActivateTargets` (`e1m1`: `trigger_credits`; `sf_923`: `target_endlevelgui_2`). idDict keys are case-insensitive, so `nextMap` would also match.
  - `secret` (7 entities in `e1m1.map`, `e1m1_2.map`, `sf_923.map`), `level_item` (`def/ammo.def`, `def/chex.def`, `def/items.def`), `level_monster` (`def/monster_default.def`; one `"0"` override in `sf_923.map`): read by `idGameLocal::GetLevelStats`.
- **The screen's sequence.** Activation (`Event_Activate`) turns the player's start time into the level time, shows the GUI with zeroed counts and posts the first tic. Each tic (`g_statTicTime` ms, default 50) plays `ticSound` and advances `state`: lines 0-2 count up one percent per tic (`updateStats`), line 3 counts the time up by `timeStep`, state 4 waits 3000 ms, state 5 closes the GUI and loads `nextmap` or triggers the targets. `"skip"` finishes the current line at once. `"nextmap"` jumps to state 5.
- **Edits inside stock functions (out of scope for spec #16, recorded as leads).**
  - `idPlayer::Spawn` calls `gameLocal.GetLevelStats( levelStats )`, stores `gameLocal.time` in `levelStats[ 3 ].total`, and sets the 10 variable names (0x16f3cc-0x16f469).
  - Both `idPlayer` constructors `memset` the 0x50 bytes at +0x1ea4 (0x170ec8 `mov edi, 0x50`, memset @ 0x170f69).
  - `idPlayer::AddAIKill` increments `levelStats[ 0 ].found` (+0x1ea8, 0x15e878). `idPlayer::GiveItem( idItem * )` increments `levelStats[ 1 ].found` (+0x1ebc, 0x164f64).
  - `idMover_Binary::Use_BinaryMover` is the only caller of `incSecretsFound`.
  - None of these are checked here. A scan of all code for `[reg + disp]` operands with these displacements found no other use of +0x1ea4..+0x1ef3 (indexed forms were not scanned).
- **Stock-inline callees (check 1 allow-list, `stock-inline`).** Some callees are made by stock `ID_INLINE` code the reconstruction calls by its SDK name: `idDict::FindKey` inside `spawnArgs.GetString` / `GetBool`, `__strtol_internal` inside their `atoi`, `idStr::ReAllocate` / `memcpy` / `strlen` inside `idStr::operator=( const idStr & )` and `operator+=`, `idStr::FreeData` inside `~idStr()`. Each is on `verify/allowlist.tsv` for the exact function, with the stock function named.
- **Literals (check 2).** Every string the group's functions read from `.rodata` appears verbatim. None of them reads a float constant. The integer divisors in `FormatTime` (3600000, 60000, 1000) are compiled to multiply-by-reciprocal immediates, which are not float constants. The `g_statTicTime` strings (`"g_statTicTime"`, `"50"`, `"time in MS between tics"`) and `"<UpdateEndLevelStats>"` are read by the static initializer, which is not a covered function, so check 2 does not cover them. They were read from its disassembly.
- **Compile (check 3).** Compiles with g++ 12 `-m32` against stock DOOM-3 GPL a9c49da, after `custom-ui.md`'s header block. The `idPlayer`, `idGameLocal` and `idStr` partial declarations are spliced into scratch copies of `game/Player.h`, `game/Game_local.h` and `idlib/Str.h`. `playerStats_s` is compiled before the stock game headers, because `idPlayer` holds it by value. In the mod's source it had to be declared before `idPlayer` (UNCERTAIN where).
- **Vtable offsets** (`idUserInterface`: `SetStateString` +0x38, `SetStateInt` +0x40, `StateChanged` +0x58, `Trigger` +0x60; `idDeclManager::FindSound` +0x68) were matched by counting virtual declarations in the stock headers, with GCC 3 two-slot virtual destructors. `g_statTicTime.GetInteger()` is `internalVar` (+0x2c) then `integerValue` (+0x24) of the stock `idCVar`. `gameLocal.sessionCommand` (+0x251298) is the offset the stock `idTarget_EndLevel::Event_Activate` in this binary writes `"map "` to.
- **Ghidra artifacts.**
  - `Event_Activate`: Ghidra missed `__thiscall`, so its `param_1` is `this`.
  - `getLevelStats` is typed `idPlayer *` (`return this + 0x1ea4`). It returns `&levelStats[ 0 ]`.
  - `CreateInstance` types the new object `idCustomUI *`. The D0 destructor passes a stray `unaff_EBX` to `operator_delete` (really `idClass::operator delete( this )`).
  - `idStr local_30 [4]` with `uStack_2c` in `Event_UpdateStats` / `HandleCustomGUICommand` is `FormatTime`'s returned `idStr`. `uStack_2c` is its `data`, passed as `const char *`.
  - The `try { ... } CatchHandler` and `catch() { ... }` comments in `updateStats` and `FormatTime` span far past the functions and are not code. In `FormatTime`'s 'M' branch, `cVar1 = acStack_24[0]` ... `acStack_24[0] = cVar1` is register-allocation noise.
- **Open questions (binary behavior, need an in-game check).**
  - `ticSound` is set only by `Event_Activate`, and only if the `s_shader` key exists. Nothing else initializes it (not `Spawn`, not a constructor), and it is not saved. After loading a save in which the screen was running, `Restore` restarts the tics, and `Event_UpdateStats` plays whatever `ticSound` holds.
  - `unknown2d4` is zeroed, saved and restored, and read nowhere in the binary's copy of this class. Possibly left over from an earlier version.
  - With `extHndNextMap` set, state 5 posts nothing more, so the GUI stays up until a script hides the entity (`idCustomUI::Event_Hide` unregisters it).
  - `FormatTime` copies the character after a field run as is, so fields must be separated ("hhmm" would print the hours, then a literal 'm'). The mod uses only "mm:ss:MMM".
