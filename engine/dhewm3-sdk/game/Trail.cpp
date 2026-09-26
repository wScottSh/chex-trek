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

// chextrek: spec #16/#43 (decomp-so/reference/trails.md). See Trail.h for the class's provenance
// and scope.

#include "sys/platform.h"
#include "gamesys/SysCvar.h"
#include "renderer/ModelManager.h"
#include "Game_local.h"
#include "Actor.h"

#include "Trail.h"

// chextrek: spec #43. Static in the file, matching stock BrittleFracture.cpp's
// brittleFracture_SnapshotName, which mkTrail's model-rebuild plumbing copies closely.
static const char *mkTrail_SnapshotName = "_mkTrail_Snapshot_";

// No events (reference: mkTrail::eventCallbacks is 12 bytes, the terminating { NULL } entry only).
CLASS_DECLARATION( idClass, mkTrail )
END_CLASS

/*
================
mkTrail::mkTrail
================
*/
mkTrail::mkTrail( void ) {
	// spawnArgs' and anchors' constructors run first (idDict::idDict and idList::idList, both
	// inline/stock). owner, lastPos, thinkFlags and modelDefHandle are deliberately left
	// uninitialized here, matching the reference's binary evidence (see Trail.h/Notes) - idActor::
	// Spawn always sets owner before calling Spawn() below, and Spawn() itself sets thinkFlags and
	// modelDefHandle, so the only window where they're read uninitialized would be a caller that
	// skips Spawn() entirely, which nothing in this port does.
	material = NULL;
	lastRenderEntityUpdate = -1;
	changed = false;
	updateDist = 2.0f;
	trailWidth = 32.0f;
	anchorDist = 16.0f;
	maxAnchors = 15;
	fadeStart = 0;
}

/*
================
mkTrail::~mkTrail
================
*/
mkTrail::~mkTrail( void ) {
	gameLocal.RemoveTrail( this );
	if ( modelDefHandle != -1 ) {
		gameRenderWorld->FreeEntityDef( modelDefHandle );
		modelDefHandle = -1;
	}
	if ( renderEntity.hModel ) {
		renderModelManager->FreeModel( renderEntity.hModel );
	}
	// Each entry is deleted, but not set to NULL (reference: not idList::DeleteContents).
	for ( int i = 0; i < anchors.Num(); i++ ) {
		delete anchors[ i ];
	}
}

/*
================
mkTrail::Spawn

Called by idActor::Spawn after it has filled spawnArgs and owner (see Actor.cpp).
================
*/
void mkTrail::Spawn( void ) {
	material = declManager->FindMaterial( spawnArgs.GetString( "mtr_trail", "" ) );
	memset( &renderEntity, 0, sizeof( renderEntity ) );

	updateDist = spawnArgs.GetFloat( "updateDist", "2" );
	trailWidth = spawnArgs.GetFloat( "trailWidth", "32" );
	anchorDist = spawnArgs.GetFloat( "anchorDist", "16" );
	maxAnchors = spawnArgs.GetInt( "maxAnchors", "15" );
	surfDist = spawnArgs.GetFloat( "surfDist", "3.0" );
	maxSurfDist = spawnArgs.GetFloat( "maxSurfDist", "10.0" );
	fadeTime = SEC2MS( spawnArgs.GetFloat( "fadeTime", "0" ) );
	uvWidth = spawnArgs.GetFloat( "uvWidth", ".05" );
	uvRepeat = spawnArgs.GetFloat( "uvRepeat", ".25" );

	renderEntity.hModel = renderModelManager->AllocModel();
	renderEntity.hModel->InitEmpty( mkTrail_SnapshotName );
	renderEntity.callback = mkTrail::ModelCallback;
	renderEntity.bounds.Clear();
	renderEntity.noSelfShadow = false;
	renderEntity.noShadow = false;
	renderEntity.noDynamicInteractions = false;
	// chextrek: spec #43 (AC2, "no pointer-to-int casts"). The reference stashes `this` in
	// `renderEntity.entityNum = reinterpret_cast<int>( this );` so the static ModelCallback (below)
	// can recover which mkTrail a render-world callback belongs to (mkTrail isn't an idEntity, so it
	// has no real entity number gameLocal.entities[] could look up instead - unlike stock
	// idBrittleFracture, which this class otherwise copies closely) - a direct pointer-to-int cast
	// that only round-trips on a 32-bit build (Notes: "valid only in a 32-bit build, like the
	// original"). renderEntity_t already has a field built for exactly this ("callbackData: used for
	// whatever the callback wants", renderer/RenderWorld.h) and typed `void *`, so it round-trips a
	// pointer on any build without ever converting one to `int` - no cast at all, pointer-size
	// concerns or not. entityNum itself is left at its memset default (0); nothing else in this file
	// reads it.
	renderEntity.callbackData = this;
	self = this;
	renderEntity.axis = mat3_identity;
	renderEntity.origin.Zero();

	startColor = spawnArgs.GetVec4( "startcolor", "1 1 1 0" );
	renderEntity.shaderParms[ SHADERPARM_RED ] = startColor[ 0 ];
	renderEntity.shaderParms[ SHADERPARM_GREEN ] = startColor[ 1 ];
	renderEntity.shaderParms[ SHADERPARM_BLUE ] = startColor[ 2 ];
	renderEntity.shaderParms[ SHADERPARM_ALPHA ] = startColor[ 3 ];
	endColor = spawnArgs.GetVec4( "endcolor", "0 0 0 0" );

	modelDefHandle = gameRenderWorld->AddEntityDef( &renderEntity );
	thinkFlags = TH_THINK | TH_UPDATEVISUALS;
	gameLocal.BabySitTrail( this );
}

/*
================
mkTrail::Save

23 write calls, in the reference's order.
================
*/
void mkTrail::Save( idSaveGame *savefile ) const {
	savefile->WriteDict( &spawnArgs );
	savefile->WriteMaterial( material );
	savefile->WriteVec3( lastPos );
	savefile->WriteFloat( trailWidth );
	savefile->WriteFloat( updateDist );
	savefile->WriteFloat( anchorDist );
	savefile->WriteFloat( surfDist );
	savefile->WriteFloat( maxSurfDist );
	savefile->WriteFloat( uvRepeat );
	savefile->WriteFloat( uvWidth );
	savefile->WriteInt( fadeStart );
	savefile->WriteInt( fadeEnd );
	savefile->WriteInt( fadeTime );
	savefile->WriteVec4( startColor );
	savefile->WriteVec4( endColor );
	savefile->WriteInt( maxAnchors );
	savefile->WriteInt( anchors.Num() );
	for ( int i = 0; i < anchors.Num(); i++ ) {
		savefile->Write( anchors[ i ], sizeof( trailAnchor_t ) );
	}
	savefile->WriteInt( lastRenderEntityUpdate );
	savefile->WriteBool( changed );
	savefile->WriteInt( thinkFlags );
	savefile->WriteInt( modelDefHandle );
	savefile->WriteObject( owner );
	// Not saved: renderEntity (rebuilt by Restore) and self.
}

/*
================
mkTrail::Restore

Reads back exactly what Save wrote, in the same order. Does not call gameLocal.BabySitTrail - the
reference flags this as an open question (a restored trail is not in gameLocal.trails and so never
thinks again after a load unless something else re-adds it); not fixed here since no #43 scenario
exercises save/load and it isn't a crash.
================
*/
void mkTrail::Restore( idRestoreGame *savefile ) {
	int				i, num;
	trailAnchor_t *	anchor;

	memset( &renderEntity, 0, sizeof( renderEntity ) );
	renderEntity.hModel = renderModelManager->AllocModel();
	renderEntity.hModel->InitEmpty( mkTrail_SnapshotName );
	renderEntity.callback = mkTrail::ModelCallback;
	renderEntity.bounds.Clear();
	renderEntity.noSelfShadow = false;
	renderEntity.noShadow = false;
	renderEntity.noDynamicInteractions = false;
	renderEntity.axis = mat3_identity;
	renderEntity.origin.Zero();

	savefile->ReadDict( &spawnArgs );
	savefile->ReadMaterial( material );
	savefile->ReadVec3( lastPos );
	savefile->ReadFloat( trailWidth );
	savefile->ReadFloat( updateDist );
	savefile->ReadFloat( anchorDist );
	savefile->ReadFloat( surfDist );
	savefile->ReadFloat( maxSurfDist );
	savefile->ReadFloat( uvRepeat );
	savefile->ReadFloat( uvWidth );
	savefile->ReadInt( fadeStart );
	savefile->ReadInt( fadeEnd );
	savefile->ReadInt( fadeTime );
	savefile->ReadVec4( startColor );
	renderEntity.shaderParms[ SHADERPARM_RED ] = startColor[ 0 ];
	renderEntity.shaderParms[ SHADERPARM_GREEN ] = startColor[ 1 ];
	renderEntity.shaderParms[ SHADERPARM_BLUE ] = startColor[ 2 ];
	renderEntity.shaderParms[ SHADERPARM_ALPHA ] = startColor[ 3 ];
	savefile->ReadVec4( endColor );
	savefile->ReadInt( maxAnchors );

	savefile->ReadInt( num );
	anchors.Clear();
	for ( i = 0; i < num; i++ ) {
		anchor = new trailAnchor_t;
		savefile->Read( anchor, sizeof( trailAnchor_t ) );
		anchors.Append( anchor );
	}

	savefile->ReadInt( lastRenderEntityUpdate );
	savefile->ReadBool( changed );
	savefile->ReadInt( thinkFlags );
	savefile->ReadInt( modelDefHandle );
	savefile->ReadObject( reinterpret_cast<idClass *&>( owner ) );

	// chextrek: spec #43 (AC2). See the matching comment in Spawn() above.
	renderEntity.callbackData = this;
	self = this;
	// The saved handle belonged to the old render world: only its "is there one" survives.
	if ( modelDefHandle != -1 ) {
		modelDefHandle = gameRenderWorld->AddEntityDef( &renderEntity );
	}
}

/*
================
mkTrail::Think

Run once a frame by idGameLocal::RunFrame (see the wiring lead ported into Game_local.cpp), through
the vtable.
================
*/
void mkTrail::Think( void ) {
	if ( !( thinkFlags & TH_THINK ) ) {
		return;
	}

	// The owner moved far enough: update the trail to its new position.
	if ( owner ) {
		if ( ( lastPos - owner->GetPhysics()->GetOrigin() ).LengthFast() > updateDist ) {
			thinkFlags |= TH_UPDATEVISUALS;
			lastPos = owner->GetPhysics()->GetOrigin();
		}
	}

	Present();

	if ( fadeStart ) {
		// fadeEnd == fadeStart (a "fadeTime" of 0) divides by zero here - a documented, preserved
		// reference open question (decomp-so/reference/trails.md's Notes); not #43's
		// scenario, which uses a nonzero fadeTime.
		float frac = (float)( gameLocal.time - fadeStart ) / (float)( fadeEnd - fadeStart );
		if ( frac < 0.0f ) {
			return;		// still in the "fadeDelay"
		}
		idVec4 color;
		color.Lerp( startColor, endColor, frac );
		renderEntity.shaderParms[ SHADERPARM_RED ] = color[ 0 ];
		renderEntity.shaderParms[ SHADERPARM_GREEN ] = color[ 1 ];
		renderEntity.shaderParms[ SHADERPARM_BLUE ] = color[ 2 ];
		renderEntity.shaderParms[ SHADERPARM_ALPHA ] = color[ 3 ];
		thinkFlags |= TH_UPDATEVISUALS;
		if ( frac > 1.0f ) {
			delete this;
		}
	}
}

/*
================
mkTrail::FadeTrail

The owner is going away (~idActor). Detach from it. With "fadeTime" "-1", stop thinking: the trail
stays as it is for good. Otherwise fade from startColor to endColor over fadeTime, after
"fadeDelay" seconds; Think deletes the trail at the end.
================
*/
void mkTrail::FadeTrail( void ) {
	owner = NULL;
	// UNCERTAIN (reference): the form of the test. The binary compares with the constant -1000
	// (SEC2MS( -1 )).
	if ( fadeTime == -1000 ) {
		thinkFlags &= ~TH_THINK;
		return;
	}
	fadeStart = gameLocal.time + SEC2MS( spawnArgs.GetFloat( "fadeDelay", "0" ) );
	fadeEnd = fadeStart + fadeTime;
}

/*
================
mkTrail::Present

Adds an anchor at the owner's position if it moved, and pushes the model to the renderer. Copies
the shape of stock idBrittleFracture::Present.
================
*/
void mkTrail::Present( void ) {
	if ( !( thinkFlags & TH_UPDATEVISUALS ) ) {
		return;
	}
	thinkFlags &= ~TH_UPDATEVISUALS;

	addNewAnchor();
	if ( anchors.Num() > maxAnchors ) {
		delete anchors[ 0 ];
		anchors.RemoveIndex( 0 );
	}

	if ( renderEntity.hModel ) {
		renderEntity.bounds = renderEntity.hModel->Bounds( &renderEntity );
	}
	if ( owner ) {
		renderEntity.bounds.AddPoint( owner->GetPhysics()->GetOrigin() );
	} else {
		renderEntity.bounds.AddPoint( lastPos );
	}

	renderEntity.forceUpdate = true;
	if ( modelDefHandle == -1 ) {
		modelDefHandle = gameRenderWorld->AddEntityDef( &renderEntity );
	} else {
		gameRenderWorld->UpdateEntityDef( modelDefHandle, &renderEntity );
	}
	changed = true;
}

/*
================
mkTrail::addNewAnchor

Drops an anchor on the ground below lastPos, unless there is no ground within maxSurfDist or the
last anchor is within anchorDist. If the new cross-section would cross the last one within half the
trail's width (a sharp turn), it is bent to share an edge point with it.
================
*/
bool mkTrail::addNewAnchor( void ) {
	trace_t				tr;
	idVec3				end;
	trailAnchor_t *		anchor;
	trailAnchor_t *		last;

	end = lastPos;
	end.z -= maxSurfDist;
	// UNCERTAIN (reference): MASK_OPAQUE or CONTENTS_OPAQUE (both 2).
	gameLocal.clip.Translation( tr, lastPos, end, NULL, mat3_identity, MASK_OPAQUE, owner );
	if ( tr.fraction >= 1.0f ) {
		return false;
	}
	if ( anchors.Num() ) {
		if ( ( anchors[ anchors.Num() - 1 ]->origin - lastPos ).LengthFast() <= anchorDist ) {
			return false;
		}
	}

	// chextrek: spec #43 crash fix, recorded per spec #28's "fixing the original mod's own bugs...
	// unless they crash on dhewm3" allowance. The reference's Notes flag this exact spot as an open
	// question: with no owner (after FadeTrail) and zero anchors yet, the binary indexes
	// anchors[ anchors.Num() - 1 ] with no bounds check, which is undefined behavior (0.Num() - 1 ==
	// -1). It's only reachable if FadeTrail runs before the trail ever placed an anchor at all -
	// e.g. a trail whose uninitialized lastPos kept it from ever updating (see tools/test-trails.sh's
	// header and the reference's Notes) and whose actor is then removed - and a defensive bail matches "just
	// return false" (the same thing a failed ground trace already does two lines above) rather than
	// changing any other observable behavior.
	if ( !owner && anchors.Num() == 0 ) {
		return false;
	}

	anchor = new trailAnchor_t;
	if ( owner ) {
		anchor->dir = owner->viewAxis[ 1 ];
	} else {
		anchor->dir = anchors[ anchors.Num() - 1 ]->dir;
	}
	tr.endpos.z += surfDist;
	anchor->origin = tr.endpos;
	anchor->edge0 = anchor->origin + anchor->dir * trailWidth * -0.5f;
	anchor->edge1 = anchor->origin + anchor->dir * trailWidth * 0.5f;

	if ( anchors.Num() ) {
		last = anchors[ anchors.Num() - 1 ];
		idMat2 m( anchor->dir.x, last->dir.x, anchor->dir.y, last->dir.y );
		if ( m.InverseSelf() ) {
			float t = m[ 0 ][ 0 ] * ( last->origin.x - lastPos.x ) + m[ 0 ][ 1 ] * ( last->origin.y - lastPos.y );
			if ( ( anchor->dir * t ).LengthFast() < trailWidth * 0.5f ) {
				if ( ( last->edge0 - anchor->edge0 ).LengthFast() <= ( last->edge1 - anchor->edge1 ).LengthFast() ) {
					anchor->edge0 = last->edge0;
					anchor->edge1 += ( last->edge1 - anchor->edge1 ) * 0.5f;
				} else {
					anchor->edge1 = last->edge1;
					anchor->edge0 += ( last->edge0 - anchor->edge0 ) * 0.5f;
				}
				anchor->dir = anchor->edge1 - anchor->edge0;
				anchor->dir.Normalize();
				anchor->origin = anchor->edge0 + anchor->dir * trailWidth * 0.5f;
			}
		}
	}

	anchors.Append( anchor );
	return true;
}

/*
================
mkTrail::ModelCallback
================
*/
bool mkTrail::ModelCallback( renderEntity_s *renderEntity, const renderView_t *renderView ) {
	// callbackData holds the trail itself (see Spawn/Restore above) - a void * round-trip, never a
	// pointer-to-int cast. No NULL check (reference: stock BrittleFracture has one, the binary
	// doesn't).
	const mkTrail *trail = reinterpret_cast<const mkTrail *>( renderEntity->callbackData );
	return trail->UpdateRenderEntity( renderEntity, renderView );
}

/*
================
mkTrail::UpdateRenderEntity

Rebuilds the model: one quad per anchor, from each anchor's cross-section to the next, the last one
ending at a head section below the owner's current position. The texture's t runs across the trail
(0 to 1). Its s starts at 0, rises by uvWidth per anchor to 1, then bounces between 1 and uvRepeat
(SDK changelog r4).
================
*/
bool mkTrail::UpdateRenderEntity( renderEntity_s *renderEntity, const renderView_t *renderView ) const {
	int					i, numAnchors, a, b;
	float				s, step;
	bool				firstPass;
	srfTriangles_t *	tris;
	idDrawVert *		v;
	trace_t				tr;
	idVec3				end, dir;
	modelSurface_t		surface;

	// this may be triggered by a model trace or other non-view related source
	if ( !renderView ) {
		return false;
	}
	// don't regenerate it if it is current
	if ( lastRenderEntityUpdate == gameLocal.time || !changed || anchors.Num() == 0 ) {
		return false;
	}
	lastRenderEntityUpdate = gameLocal.time;
	changed = false;

	numAnchors = anchors.Num();
	renderEntity->hModel->InitEmpty( mkTrail_SnapshotName );
	tris = renderEntity->hModel->AllocSurfaceTriangles( numAnchors * 2 + 2, numAnchors * 6 );
	tris->tangentsCalculated = false;

	// The anchors' sections: two vertices each.
	step = uvWidth;
	s = -step;
	firstPass = true;
	for ( i = 0; i < numAnchors; i++ ) {
		s += step;
		// At the top (1.0): turn back.
		if ( s >= 1.0f || idMath::Fabs( 1.0f - s ) <= 0.001 ) {
			step = -step;
			firstPass = false;
			s = 1.0f;
		}
		// After the first climb, at the bottom (uvRepeat): turn back.
		if ( !firstPass && ( s <= uvRepeat || idMath::Fabs( uvRepeat - s ) <= 0.001 ) ) {
			step = -step;
			s = uvRepeat;
		}

		v = &tris->verts[ tris->numVerts++ ];
		v->Clear();
		v->st[ 0 ] = s;
		v->st[ 1 ] = 0.0f;
		v->xyz = anchors[ i ]->edge0;

		v = &tris->verts[ tris->numVerts++ ];
		v->Clear();
		v->st[ 0 ] = s;
		v->st[ 1 ] = 1.0f;
		v->xyz = anchors[ i ]->edge1;
	}

	// The head section, on the ground below lastPos (as addNewAnchor would place it), or at the
	// last anchor when there is no ground. s goes on in proportion to the distance.
	end = lastPos;
	end.z -= maxSurfDist;
	gameLocal.clip.Translation( tr, lastPos, end, NULL, mat3_identity, MASK_OPAQUE, owner );
	if ( tr.fraction >= 1.0f ) {
		tr.endpos = anchors[ numAnchors - 1 ]->origin;
	} else {
		tr.endpos.z += surfDist;
	}
	s += ( tr.endpos - anchors[ numAnchors - 1 ]->origin ).LengthFast() * step / anchorDist;
	if ( owner ) {
		dir = owner->viewAxis[ 1 ];
	} else {
		dir = anchors[ numAnchors - 1 ]->dir;
	}

	// UNCERTAIN (reference): the form. The binary indexes verts[ numVerts ] for each field and
	// increments numVerts on the xyz store, unlike the loop above.
	tris->verts[ tris->numVerts ].Clear();
	tris->verts[ tris->numVerts ].st[ 0 ] = s;
	tris->verts[ tris->numVerts ].st[ 1 ] = 0.0f;
	tris->verts[ tris->numVerts++ ].xyz = tr.endpos + dir * trailWidth * -0.5f;
	tris->verts[ tris->numVerts ].Clear();
	tris->verts[ tris->numVerts ].st[ 0 ] = s;
	tris->verts[ tris->numVerts ].st[ 1 ] = 1.0f;
	tris->verts[ tris->numVerts++ ].xyz = tr.endpos + dir * trailWidth * 0.5f;

	// Two triangles per quad. Vertex 2k is edge0 of section k, 2k+1 its edge1.
	a = 0;
	b = 1;
	for ( i = tris->numIndexes; i < numAnchors * 6; i += 6 ) {
		tris->indexes[ i + 0 ] = a;
		tris->indexes[ i + 1 ] = b;
		tris->indexes[ i + 2 ] = a + 2;
		tris->indexes[ i + 3 ] = b + 2;
		tris->indexes[ i + 4 ] = a + 2;
		tris->indexes[ i + 5 ] = b;
		tris->numIndexes = i + 6;
		a += 2;
		b += 2;
	}

	SIMDProcessor->MinMax( tris->bounds[ 0 ], tris->bounds[ 1 ], tris->verts, tris->numVerts );

	surface.id = 0;
	surface.shader = material;
	surface.geometry = tris;
	renderEntity->hModel->AddSurface( surface );

	return true;
}
