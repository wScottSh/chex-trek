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

#ifndef __GAME_FUNC_ENVSHOT_H__
#define __GAME_FUNC_ENVSHOT_H__

#include "Entity.h"

// chextrek: spec #16/#44 (decomp-so/reference/env-shots.md). Not a stock dhewm3-sdk file: the
// original mod added game/func_envshot.cpp and game/func_envshot.h (the symbol table's own
// STT_FILE entry names it func_envshot.cpp; ChexTrek_SDK_ChangeLog.txt r1 adds both). An
// editor-placed point (entityDef func_envshot, def/func_envshot.def) that takes an environment
// cubemap shot (the stock renderer's "envShot" command, six faces) from its own origin: 250 ms
// after spawn when "atSpawn" "1", or for every matt_func_envshot on the map at once with the
// console command "takeEnvShots".

// ---------------------------------------------------------------------------
// matt_func_envshot (game/func_envshot.h)
// Base class: idEntity, with no overrides and no members of its own (reference: vtable matches
// idEntity's word for word bar type info/GetType/destructors; CreateInstance allocates
// sizeof( idEntity )).
// ---------------------------------------------------------------------------
class matt_func_envshot : public idEntity {
public:
	CLASS_PROTOTYPE( matt_func_envshot );

	// UNCERTAIN (reference): whether this was declared in the source at all - both destructor
	// clones do nothing of their own, which a compiler-generated destructor also gives.
							~matt_func_envshot( void );

	void					Spawn( void );

	// UNCERTAIN (reference): access level - takeEnvShots_f calls it directly, which any access
	// level allows (a static member of the same class).
	void					Event_envShot( void );

	// Console command "takeEnvShots" (registered in idGameLocal::InitConsoleCommands,
	// gamesys/SysCmds.cpp). Static: the binary symbol takes no `this`.
	static void				takeEnvShots_f( const idCmdArgs &args );
};

#endif /* !__GAME_FUNC_ENVSHOT_H__ */
