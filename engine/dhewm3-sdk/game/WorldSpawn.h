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

#ifndef __GAME_WORLDSPAWN_H__
#define __GAME_WORLDSPAWN_H__

#include "Entity.h"

/*
===============================================================================

  World entity.

===============================================================================
*/

class idWorldspawn : public idEntity {
public:
	CLASS_PROTOTYPE( idWorldspawn );

					~idWorldspawn();

	void			Spawn( void );

	void			Save( idRestoreGame *savefile );
	void			Restore( idRestoreGame *savefile );

	// chextrek: spec #45/#16 (decomp-so/reference/worldspawn.md). The stock GPL source above
	// declares Save with the wrong parameter type (idRestoreGame*, a pre-existing stock typo left
	// untouched - see its own empty body in WorldSpawn.cpp); gamex86.so exports a distinctly-named
	// _ZN12idWorldspawn4SaveEP10idSaveGame, so the mod adds this correctly-typed overload, which is
	// what CLASS_DECLARATION's idWorldspawn::Type actually registers and the save system calls.
	// Declared `const`, unlike the reference's plain "void Save( idSaveGame *savefile );": with two
	// overloads now in scope, CLASS_DECLARATION's `(void (idClass::*)(idSaveGame*) const)&Save` cast
	// needs an exact function-type match (params + cv-qualification) to pick this one over the
	// idRestoreGame* overload, matching idEntity::Save's own `const` (Entity.h) - the reference's
	// Ghidra reconstruction can't observe constness from disassembly either way, and an
	// unqualified declaration here fails to compile once both overloads exist. Recorded deviation,
	// not a behavior change (the body is empty either way).
	void			Save( idSaveGame *savefile ) const;
	// Binary: idWorldspawn's vtable entry +0x14, idEntity::Think's slot (idEntity's vtable has
	// idEntity::Think there), is this function. So it overrides the stock virtual Think.
	virtual void	Think( void );

private:
	void			Event_Remove( void );
};

#endif /* !__GAME_WORLDSPAWN_H__ */
