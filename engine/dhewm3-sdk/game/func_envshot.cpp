/*
===============================================================================

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

===============================================================================
*/

// chextrek: spec #16/#44 (decomp-so/reference/env-shots.md). See func_envshot.h for the class's
// provenance and scope.

#include "sys/platform.h"
#include "Game_local.h"

#include "func_envshot.h"

// The event. Binary: constructed as idEventDef( "<envshot>", NULL, 0 ) - no arguments, no return
// value. The name is "<envshot>", not "envShot": the angle brackets mark an internal event, like
// stock's "<immediateremove>", which script code cannot name (reference Notes). No file in
// script/ names "envshot" in any case, so this isn't a script event: only Spawn posts it.
const idEventDef EV_envShot( "<envshot>" );

// Event table (binary: matt_func_envshot::eventCallbacks = { EV_envShot, Event_envShot }, { NULL }).
CLASS_DECLARATION( idEntity, matt_func_envshot )
	EVENT( EV_envShot,		matt_func_envshot::Event_envShot )
END_CLASS

/*
================
matt_func_envshot::~matt_func_envshot

Possibly not written in the source (see func_envshot.h). Nothing of its own: both binary
destructor clones reset the vtable pointer to this class's and run idEntity::~idEntity().
================
*/
matt_func_envshot::~matt_func_envshot( void ) {
}

/*
================
matt_func_envshot::Spawn
================
*/
void matt_func_envshot::Spawn( void ) {
	Hide();

	// UNCERTAIN (reference): GetBool or GetInt. Both compile to atoi( GetString( key, "0" ) ) != 0
	// here.
	if ( spawnArgs.GetBool( "atSpawn", "0" ) ) {
		PostEventMS( &EV_envShot, 250 );
	}
}

/*
================
matt_func_envshot::Event_envShot

Renders the scene once from this entity's origin, looking down +X, then runs the renderer's
"envShot <name> <size> <blends>" command at once. The stock envshot command (R_EnvShot_f) shoots
its six faces from the last primary view rendered, which is this one.
================
*/
void matt_func_envshot::Event_envShot( void ) {
	renderView_t *	view;
	int				i;

	// The same setup as the start of stock idPlayer::CalculateRenderView. The view is allocated
	// here and never freed (reference: no operator delete in this function - a leak in the
	// original mod, left as-is: spec #28's Out of Scope is "fixing the original mod's own bugs",
	// with the one exception "unless they crash" - this leak doesn't, it's just 136 bytes/shot).
	view = new renderView_t;
	memset( view, 0, sizeof( *view ) );

	// UNCERTAIN (reference): a loop, as in CalculateRenderView (whose own loop this build's
	// compiler also unrolls into 12 moves), or 12 separate assignments - the binary shows 12
	// unrolled moves either way, so it can't tell the two apart. Written as a loop here, matching
	// the reference's own preferred reading.
	for ( i = 0; i < MAX_GLOBAL_SHADER_PARMS; i++ ) {
		view->shaderParms[ i ] = gameLocal.globalShaderParms[ i ];
	}
	view->globalMaterial = gameLocal.GetGlobalMaterial();
	view->time = gameLocal.time;

	view->x = 0;
	view->y = 0;
	view->width = SCREEN_WIDTH;
	view->height = SCREEN_HEIGHT;
	view->viewID = 0;

	// UNCERTAIN (reference): the source form. Binary: an identity idMat3 built from immediates in
	// a stack temporary and copied into viewaxis - not mat3_identity or Identity(), which would
	// instead read the global mat3_identity from memory. Kept as this literal on purpose: folding
	// it into mat3_identity later would be an unflagged, unverified change from the reference.
	view->viewaxis = idMat3( 1.0f, 0.0f, 0.0f, 0.0f, 1.0f, 0.0f, 0.0f, 0.0f, 1.0f );
	view->vieworg = GetPhysics()->GetOrigin();
	// 73.74 is the fov_y that gameLocal.CalcFov gives for a fov_x of 90 at 4:3 (73.7398...),
	// rounded and written as a constant (reference: immediate 0x42937ae1 = 73.74f).
	view->fov_x = 90.0f;
	view->fov_y = 73.74f;

	// UNCERTAIN (reference): whether this build's renderer (not in gamex86.so, so not checked
	// against the binary) matches stock here, and that RenderScene sets tr.primaryView when
	// called from a console command outside the frame - the very thing the "envShot" command
	// below depends on. Still open: tools/test-env-shots.sh proves the six faces get written at
	// the expected size, but a stale tr.primaryView left over from the last rendered frame (the
	// player's own view, non-null in a running game) would write faces too, from that view instead
	// of this one - nothing the scenario currently checks distinguishes the two, since none of its
	// assertions depend on which view was actually copied. Not re-checked here.
	gameRenderWorld->RenderScene( view );

	idStr name;
	idStr size;
	idStr blends;
	// "name" is the entity's own name (every entity has one): the shots are env/<name>_px.tga etc.
	spawnArgs.GetString( "name", "", name );
	spawnArgs.GetString( "size", "", size );
	spawnArgs.GetString( "blends", "", blends );

	// UNCERTAIN (reference): whether the result went through a named idStr first before reaching
	// BufferCommandText, or was built and passed inline as here.
	//
	// UNCERTAIN/open question (reference): whether idCmdArgs::TokenizeString drops an empty
	// positional field. If "size" is left empty ("") while "blends" is set, the command text below
	// becomes "envShot <name>  <blends>" (two spaces where "size" would be) - if TokenizeString
	// collapses that missing field instead of tokenizing it as an empty argument, "blends"'s value
	// would silently land in R_EnvShot_f's "size" argument slot instead. Not exercised by
	// tools/test-env-shots.sh, which always sets both "size" and "blends" explicitly to avoid it.
	cmdSystem->BufferCommandText( CMD_EXEC_NOW, "envShot " + name + " " + size + " " + blends );
}

/*
================
matt_func_envshot::takeEnvShots_f

Console command "takeEnvShots": takes the env shot of every matt_func_envshot on the map at once.
================
*/
void matt_func_envshot::takeEnvShots_f( const idCmdArgs &args ) {
	int			i;
	int			count;
	idEntity *	ent;

	count = 0;
	for ( i = 0; i < gameLocal.num_entities; i++ ) {
		ent = gameLocal.entities[ i ];
		if ( ent && ent->IsType( matt_func_envshot::Type ) ) {
			// A direct call, not an event: every shot is taken now, in entity order.
			static_cast<matt_func_envshot *>( ent )->Event_envShot();
			count++;
		}
	}
	common->Printf( "%i envShots taken\n", count );
}
