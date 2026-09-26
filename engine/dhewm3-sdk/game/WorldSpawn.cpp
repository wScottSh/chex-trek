/*
===========================================================================

Doom 3 GPL Source Code
Copyright (C) 1999-2011 id Software LLC, a ZeniMax Media company.

This file is part of the Doom 3 GPL Source Code ("Doom 3 Source Code").

Doom 3 Source Code is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

Doom 3 Source Code is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with Doom 3 Source Code.  If not, see <http://www.gnu.org/licenses/>.

In addition, the Doom 3 Source Code is also subject to certain additional terms. You should have received a copy of these additional terms immediately following the terms and conditions of the GNU General Public License which accompanied the Doom 3 Source Code.  If not, please request a copy in writing from id Software at the address below.

If you have questions concerning this license or the applicable additional terms, you may contact in writing id Software LLC, c/o ZeniMax Media Inc., Suite 120, Rockville, Maryland 20850 USA.

===========================================================================
*/

#include "sys/platform.h"
#include "framework/FileSystem.h"

#include "gamesys/SysCvar.h"
#include "script/Script_Thread.h"

#include "WorldSpawn.h"
#include "ChexTrekDump.h" // chextrek: spec #45, test-only hook - see ChexTrek_NoteMusicVolume

// chextrek: spec #45/#16 (decomp-so/reference/worldspawn.md). Binary: WorldSpawn.cpp's static
// initializer builds this at 0x1ab94c with the inline idCVar constructor: name "g_MusicVolume",
// value "50", description "Music Volume", flags CVAR_GAME | CVAR_ARCHIVE | CVAR_FLOAT (plus the
// CVAR_STATIC the constructor itself adds), no explicit range (the cvar itself has no clamp - only
// guis/mainmenu.gui's slider, low 0 / high 100, limits it in practice).
idCVar g_MusicVolume( "g_MusicVolume", "50", CVAR_GAME | CVAR_ARCHIVE | CVAR_FLOAT, "Music Volume" );

// chextrek: spec #45/#16. Binary: the same static initializer then builds this second EV_FadeSound
// as idEventDef( "fadeSound", "dff" ) - the stock Entity.cpp event's name and format again. The
// idEventDef constructor finds the name already registered (Entity.cpp's own file-scope
// EV_FadeSound) and reuses its event number, so ProcessEvent( &EV_FadeSound, ... ) below dispatches
// through the stock EVENT( EV_FadeSound, idEntity::Event_FadeSound ) entry - no new event handler
// needed. Recorded deviation from worldspawn.md's own header/Implementation split (an `extern`
// declaration in WorldSpawn.h plus a plain, non-`extern` definition here): this build's MSVC gives
// a plain top-level `const idEventDef` external linkage regardless (confirmed - Entity.cpp's own
// EV_FadeSound linked as a public symbol too, LNK2005 duplicate-symbol on the reference's own
// approach), so this is `static` instead, keeping it internal-linkage and confined to this file
// only - the constructor's name-based number lookup works identically either way, and nothing
// outside WorldSpawn.cpp needs to name this object.
static const idEventDef EV_FadeSound( "fadeSound", "dff" );

/*
================
idWorldspawn

Worldspawn class.  Each map has one worldspawn which handles global spawnargs.
Every map should have exactly one worldspawn.
================
*/
CLASS_DECLARATION( idEntity, idWorldspawn )
	EVENT( EV_Remove,				idWorldspawn::Event_Remove )
	EVENT( EV_SafeRemove,			idWorldspawn::Event_Remove )
END_CLASS

/*
================
idWorldspawn::Spawn
================
*/
void idWorldspawn::Spawn( void ) {
	idStr				scriptname;
	idThread			*thread;
	const function_t	*func;
	const idKeyValue	*kv;

	assert( gameLocal.world == NULL );
	gameLocal.world = this;

	g_gravity.SetFloat( spawnArgs.GetFloat( "gravity", va( "%f", DEFAULT_GRAVITY ) ) );

	// disable stamina on hell levels
	if ( spawnArgs.GetBool( "no_stamina" ) ) {
		pm_stamina.SetFloat( 0.0f );
	}

	// load script
	scriptname = gameLocal.GetMapName();
	scriptname.SetFileExtension( ".script" );
	if ( fileSystem->ReadFile( scriptname, NULL, NULL ) > 0 ) {
		gameLocal.program.CompileFile( scriptname );

		// call the main function by default
		func = gameLocal.program.FindFunction( "main" );
		if ( func != NULL ) {
			thread = new idThread( func );
			thread->DelayedStart( 0 );
		}
	}

	// call any functions specified in worldspawn
	kv = spawnArgs.MatchPrefix( "call" );
	while( kv != NULL ) {
		func = gameLocal.program.FindFunction( kv->GetValue() );
		if ( func == NULL ) {
			gameLocal.Error( "Function '%s' not found in script for '%s' key on worldspawn", kv->GetValue().c_str(), kv->GetKey().c_str() );
		}

		thread = new idThread( func );
		thread->DelayedStart( 0 );
		kv = spawnArgs.MatchPrefix( "call", kv );
	}

	// chextrek: spec #45/#16 (decomp-so/reference/worldspawn.md's Notes: "edit inside the stock
	// Spawn", recorded lead). Near its end, gamex86.so's idWorldspawn::Spawn sets g_MusicVolume's
	// CVAR_MODIFIED flag (SetModified) and calls BecomeActive( TH_THINK ) - stock Spawn does
	// neither. So Think runs its body once when the map starts (applying the current cvar value to
	// the worldspawn's music) and again each time the menu's slider changes the cvar afterward.
	g_MusicVolume.SetModified();
	BecomeActive( TH_THINK );
}

/*
=================
idWorldspawn::Save
=================
*/
void idWorldspawn::Save( idRestoreGame *savefile ) {
}

/*
=================
idWorldspawn::Restore
=================
*/
void idWorldspawn::Restore( idRestoreGame *savefile ) {
	assert( gameLocal.world == this );

	g_gravity.SetFloat( spawnArgs.GetFloat( "gravity", va( "%f", DEFAULT_GRAVITY ) ) );

	// disable stamina on hell levels
	if ( spawnArgs.GetBool( "no_stamina" ) ) {
		pm_stamina.SetFloat( 0.0f );
	}
}

/*
=================
idWorldspawn::Save

chextrek: spec #45/#16 (decomp-so/reference/worldspawn.md). The correctly-typed overload
gamex86.so exports and CLASS_DECLARATION's idWorldspawn::Type actually registers/calls (see
WorldSpawn.h). Empty, as the binary's function is (a lone `ret`).
=================
*/
void idWorldspawn::Save( idSaveGame *savefile ) const {
}

/*
=================
idWorldspawn::Think

chextrek: spec #45/#16 (decomp-so/reference/worldspawn.md). Applies g_MusicVolume to the map's
music: the worldspawn's own sound, which stock idEntity::Spawn sets up from the worldspawn's
s_shader key. The stock idWorldspawn::Spawn edit above (SetModified/BecomeActive) makes this run
once at map start and again each time the menu's music slider changes the cvar. Below 1 the music
stops; otherwise it's (re)started if stopped and faded at once to
s_volume - 30 + 0.6 * g_MusicVolume dB (s_volume at the default 50).
=================
*/
void idWorldspawn::Think( void ) {
	if ( !g_MusicVolume.IsModified() ) {
		return;
	}

	// UNCERTAIN (worldspawn.md): TH_UPDATEVISUALS, not TH_THINK, as the reference itself records -
	// so thinking stays on and Think runs every frame; only the IsModified test above runs then.
	BecomeInactive( TH_UPDATEVISUALS );

	bool stopped = false;
	if ( g_MusicVolume.GetFloat() < 1.0f ) {
		StopSound( SND_CHANNEL_ANY, false );
		stopped = true;
	} else {
		if ( refSound.referenceSound && !refSound.referenceSound->CurrentlyPlaying() ) {
			if ( refSound.shader && !refSound.waitfortrigger ) {
				StartSoundShader( refSound.shader, SND_CHANNEL_ANY, 0, false, NULL );
			}
		}
		ProcessEvent( &EV_FadeSound, SND_CHANNEL_ANY, spawnArgs.GetFloat( "s_volume", "0" ) - 30.0f + 0.6f * g_MusicVolume.GetFloat(), 0.0f );
	}

	// chextrek: spec #45, test-only hook (ChexTrekDump.cpp). Think itself (and stock
	// Event_FadeSound/StartSoundShader/StopSound) log nothing, so this is the only way a scenario
	// can observe "Think actually applied the changed cvar" from the log/dump - it counts calls and
	// remembers the last applied value, it doesn't change what Think does.
	ChexTrek_NoteMusicVolume( g_MusicVolume.GetFloat(), stopped );

	g_MusicVolume.ClearModified();
}

/*
================
idWorldspawn::~idWorldspawn
================
*/
idWorldspawn::~idWorldspawn() {
	if ( gameLocal.world == this ) {
		gameLocal.world = NULL;
	}
}

/*
================
idWorldspawn::Event_Remove
================
*/
void idWorldspawn::Event_Remove( void ) {
	gameLocal.Error( "Tried to remove world" );
}
