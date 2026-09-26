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

#ifndef __GAME_TRAIL_H__
#define __GAME_TRAIL_H__

// chextrek: spec #16/#43 (decomp-so/reference/trails.md). Not a stock dhewm3-sdk file: the
// original mod added game/Trail.h and game/Trail.cpp (SDK changelog: added r1, changed r4/r5).
// mkTrail is a ribbon of quads laid on the ground behind a moving actor (a slime trail). It derives
// from idClass, not idEntity: it has no physics and isn't in gameLocal.entities[]; idGameLocal's
// own idGameLocal::trails list is what idGameLocal::RunFrame walks to Think() each live trail (the
// same wiring lead this sub-issue ports into Game_local.cpp).

// ---------------------------------------------------------------------------
// trailAnchor_t (Trail.h)
// One cross-section of the trail: a point on the ground and the segment across it.
// UNCERTAIN (reference): every name. Size 0x30 (binary evidence). No constructor (the binary runs
// none - a plain struct, matching that).
// ---------------------------------------------------------------------------
typedef struct trailAnchor_s {
	idVec3					origin;		// on the ground (trace end + surfDist)
	idVec3					dir;		// unit vector across the trail (owner's viewAxis[ 1 ])
	idVec3					edge0;		// origin - dir * trailWidth / 2: vertex with t = 0
	idVec3					edge1;		// origin + dir * trailWidth / 2: vertex with t = 1
} trailAnchor_t;

/*
===============================================================================

mkTrail

chextrek: spec #16/#43 (decomp-so/reference/trails.md). idActor::Spawn creates one for an actor
whose def has "hasTrail" "1", copying the entityDef named by "trailDef" into its own spawnArgs and
setting owner to that actor (see the leads ported into Actor.cpp). Not an entity: it owns its own
renderEntity and gameLocal runs its Think every frame.

===============================================================================
*/
class mkTrail : public idClass {
public:
	CLASS_PROTOTYPE( mkTrail );

							mkTrail( void );
	virtual					~mkTrail( void );

	void					Spawn( void );
	void					Save( idSaveGame *savefile ) const;
	void					Restore( idRestoreGame *savefile );

	// New virtuals, in vtable order (reference: slots 3 and 4, right after GetType/D1/D0). Think
	// calls Present through the vtable.
	virtual void			Present( void );
	virtual void			Think( void );

	// Called by ~idActor (see Actor.cpp): detach from the owner and start fading out.
	void					FadeTrail( void );

	// renderEntity.callback. Stock idBrittleFracture, which this class copies closely, has the
	// same pair (ModelCallback static, UpdateRenderEntity const).
	bool					UpdateRenderEntity( renderEntity_s *renderEntity, const renderView_t *renderView ) const;
	static bool				ModelCallback( renderEntity_s *renderEntity, const renderView_t *renderView );

	// UNCERTAIN (reference): return type. The binary returns 1 when it added an anchor, 0 when
	// not; its only caller (Present) ignores it.
	bool					addNewAnchor( void );

	// UNCERTAIN (reference): access level of every member below - kept public (the reference's own
	// code block never re-declares "private"/"protected"), which also lets
	// ChexTrek_Dump_f (spec #43) read anchors.Num() for the state dump's "anchors:" line without a
	// new accessor.
	idActor *				owner;			// followed actor; NULL after FadeTrail. Saved (WriteObject)
	idDict					spawnArgs;		// copy of the "trailDef" entityDef
	int						fadeTime;		// ms: SEC2MS( "fadeTime" ); -1000 ("-1"): never fade
	mkTrail *				self;			// UNCERTAIN (reference): set to this by Spawn/Restore, never read
	int						thinkFlags;		// TH_THINK (1) | TH_UPDATEVISUALS (8), as idEntity's
	idVec3					lastPos;		// owner's origin at the last update. Never initialized (see Notes)
	float					trailWidth;		// "trailWidth": width of the ribbon
	float					updateDist;		// "updateDist": owner movement that triggers an update
	float					anchorDist;		// "anchorDist": minimum spacing of anchors
	float					surfDist;		// "surfDist": height of the ribbon above the ground
	float					maxSurfDist;	// "maxSurfDist": how far down to look for ground
	float					uvRepeat;		// "uvRepeat": lower bound of the texture's s bounce
	float					uvWidth;		// "uvWidth": s step per anchor
	int						fadeStart;		// game time the fade starts; 0 = not fading
	int						fadeEnd;		// game time the fade ends
	idVec4					startColor;		// "startcolor": shaderParms 0-3 before the fade
	idVec4					endColor;		// "endcolor": shaderParms 0-3 at the end of the fade
	int						maxAnchors;		// "maxAnchors": the oldest anchor goes beyond this
	idList<trailAnchor_t *>	anchors;		// oldest first
	renderEntity_t			renderEntity;
	const idMaterial *		material;		// "mtr_trail"
	// mutable: UpdateRenderEntity is const yet writes these two, matching stock idBrittleFracture.
	mutable int				lastRenderEntityUpdate;	// game time of the last model rebuild
	mutable bool			changed;		// the model needs rebuilding (set by Present)
	int						modelDefHandle;	// render world handle, -1 = none
};

#endif /* !__GAME_TRAIL_H__ */
