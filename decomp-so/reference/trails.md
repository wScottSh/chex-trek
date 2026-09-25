# Trails (`mkTrail`, `idGameLocal` trail hooks): reconstructed reference

**Provenance:** reconstructed by **Claude Opus 5.5** on 2026-09-24 from the complete Ghidra export `decomp-so/ghidra-full/` of `gamex86.so` (Ghidra 12.1.4, "Non-Returning Functions - Discovered" disabled), enriched export (issue #18: float constants and string literals resolved from `.rodata`). Checks 1-3 pass (issue #23). Export files: `mkTrail_*.c` (17 files), `idGameLocal_BabySitTrail_00102a10.c` and `idGameLocal_RemoveTrail_000fe7f0.c`. Facts marked *binary* were read straight from `gamex86.so` (symbol table, vtables, RTTI, relocations, disassembly). Redone from scratch: the earlier comparison versions (made from the truncated first export) were deleted and not used. Reference material only, not original source. The original source does not exist.

Scope (spec #16, issue #23): the `mkTrail` class and `idGameLocal::BabySitTrail` / `RemoveTrail`, which in the binary are called only from `mkTrail` (`Spawn` and the three destructor clones; checked over every function's direct calls). The source files were `game/Trail.h` and `game/Trail.cpp` (SVN changelog, `ChexTrek_SDK_ChangeLog.txt`: added in r1, changed in r4 and r5). Addresses below are ELF virtual addresses. Ghidra's are `+0x10000`. Stock DOOM-3 GPL source (a9c49da) is referenced, not repeated.

## Header

```cpp
class mkTrail;

// ---------------------------------------------------------------------------
// idGameLocal addition (Game_local.h)
// ---------------------------------------------------------------------------
class idGameLocal : public idGame {
	// ... stock members ...
public:
	// Every live trail. RunFrame calls each one's Think once a frame (see Notes).
	// UNCERTAIN: name. Position (binary): idGameLocal's FIRST member, +0x4 .. +0x13 (num +0x4,
	// size +0x8, granularity +0xc, list +0x10), so every stock member after it is 0x10 bytes
	// further on than in stock: time +0x251884 (stock 0x251874), clip +0x2350a8 (stock 0x235098).
	// Check 3 splices it at the end of the stock declaration.
	idList<mkTrail *>		trails;

	void					BabySitTrail( mkTrail *trail );
	void					RemoveTrail( mkTrail *trail );
};

// ---------------------------------------------------------------------------
// trailAnchor_t (Trail.h)
// One cross-section of the trail: a point on the ground and the segment across it.
// UNCERTAIN: every name. Size 0x30 (binary: addNewAnchor and Restore allocate 0x30 bytes, Save
// and Restore write / read 0x30 bytes per anchor). No constructor (the binary runs none).
// ---------------------------------------------------------------------------
typedef struct trailAnchor_s {
	idVec3					origin;		// +0x00  on the ground (trace end + surfDist)
	idVec3					dir;		// +0x0c  unit vector across the trail (owner's viewAxis[ 1 ])
	idVec3					edge0;		// +0x18  origin - dir * trailWidth / 2: vertex with t = 0
	idVec3					edge1;		// +0x24  origin + dir * trailWidth / 2: vertex with t = 1
} trailAnchor_t;

// ---------------------------------------------------------------------------
// mkTrail
// A ribbon of quads laid on the ground behind a moving actor: a slime trail. idActor::Spawn
// creates one for an actor whose def has "hasTrail" "1", copies the entityDef named by
// "trailDef" into its spawnArgs and sets owner (see Notes). Not an entity: it owns its own
// renderEntity, and gameLocal runs its Think.
//
// Base class: idClass. Evidence (binary):
//   1. mkTrail::Type is built with superclass name "idClass": the file's static initializer
//      (__static_initialization_and_destruction_0 @ 0x2a40d0) passes "mkTrail" (0x3714e0) and
//      "idClass" (0x35c973) to idTypeInfo::idTypeInfo @ 0x2a420e, with mkTrail's
//      eventCallbacks, CreateInstance, Spawn, Save and Restore.
//   2. RTTI: _ZTI7mkTrail (0x3cece4) is a __si_class_type_info whose base is _ZTI7idClass.
//   3. The constructors call no base constructor (idClass's is implicit and inline). Their
//      exception landing pad and all three destructor clones end in idClass::~idClass.
//   4. Vtable _ZTV7mkTrail (0x3cecc8, 7 words): GetType, the two destructors, then two virtuals
//      idClass does not have: Present (vptr+0xc) and Think (vptr+0x10). idClass's own vtable
//      has 3 slots (GetType, D1, D0).
//   5. The first member is at this+0x4 = sizeof( idClass ) (the vptr only). sizeof = 0x18c:
//      CreateInstance and idActor::Spawn allocate 0x18c bytes.
// ---------------------------------------------------------------------------
class mkTrail : public idClass {
public:
	CLASS_PROTOTYPE( mkTrail );

							mkTrail( void );
							~mkTrail( void );		// virtual (idClass's destructor is)

	void					Spawn( void );
	void					Save( idSaveGame *savefile ) const;
	void					Restore( idRestoreGame *savefile );

	// New virtuals, in vtable order (binary: slots 3 and 4). Think calls Present through the
	// vtable.
	virtual void			Present( void );
	virtual void			Think( void );

	// Called by ~idActor (see Notes): detach from the owner and start fading out.
	void					FadeTrail( void );

	// renderEntity.callback. UNCERTAIN: access level. Stock idBrittleFracture, which this class
	// copies closely, has the same pair (ModelCallback static, UpdateRenderEntity const).
	bool					UpdateRenderEntity( renderEntity_s *renderEntity, const renderView_t *renderView ) const;
	static bool				ModelCallback( renderEntity_s *renderEntity, const renderView_t *renderView );

	// UNCERTAIN: return type. The binary returns 1 when it added an anchor, 0 when not; its only
	// caller (Present) ignores it.
	bool					addNewAnchor( void );

	// UNCERTAIN: access level (public/protected/private) of every member. idActor::Spawn writes
	// spawnArgs and owner directly, so at least those were public (or idActor a friend).
	// UNCERTAIN: every member name. Only offsets and types are known. Offsets are this + n.
	idActor *				owner;			// +0x004  followed actor; NULL after FadeTrail. Saved (WriteObject)
	idDict					spawnArgs;		// +0x008 .. +0x033  copy of the "trailDef" entityDef
	int						fadeTime;		// +0x034  ms: SEC2MS( "fadeTime" ); -1000 ("-1"): never fade
	mkTrail *				self;			// +0x038  UNCERTAIN: set to this by Spawn and Restore, never read
	int						thinkFlags;		// +0x03c  TH_THINK (1) | TH_UPDATEVISUALS (8), as idEntity's
	idVec3					lastPos;		// +0x040  owner's origin at the last update. Never initialized (see Notes)
	float					trailWidth;		// +0x04c  "trailWidth": width of the ribbon
	float					updateDist;		// +0x050  "updateDist": owner movement that triggers an update
	float					anchorDist;		// +0x054  "anchorDist": minimum spacing of anchors
	float					surfDist;		// +0x058  "surfDist": height of the ribbon above the ground
	float					maxSurfDist;	// +0x05c  "maxSurfDist": how far down to look for ground
	float					uvRepeat;		// +0x060  "uvRepeat": lower bound of the texture's s bounce
	float					uvWidth;		// +0x064  "uvWidth": s step per anchor
	int						fadeStart;		// +0x068  game time the fade starts; 0 = not fading
	int						fadeEnd;		// +0x06c  game time the fade ends
	idVec4					startColor;		// +0x070  "startcolor": shaderParms 0-3 before the fade
	idVec4					endColor;		// +0x080  "endcolor": shaderParms 0-3 at the end of the fade
	int						maxAnchors;		// +0x090  "maxAnchors": the oldest anchor goes beyond this
	idList<trailAnchor_t *>	anchors;		// +0x094 .. +0x0a3  oldest first
	renderEntity_t			renderEntity;	// +0x0a4 .. +0x17b  (0xd8 bytes: the stock renderEntity_t)
	const idMaterial *		material;		// +0x17c  "mtr_trail"
	// mutable: UpdateRenderEntity is const (binary: mangled `K`) yet writes these two. Stock
	// idBrittleFracture declares its lastRenderEntityUpdate and changed the same way.
	mutable int				lastRenderEntityUpdate;	// +0x180  game time of the last model rebuild
	mutable bool			changed;		// +0x184  the model needs rebuilding (set by Present)
	int						modelDefHandle;	// +0x188  render world handle, -1 = none
};
```

## Implementation

```cpp
// ===========================================================================
// mkTrail (Trail.cpp)
// ===========================================================================

// Static in the file (binary: local symbol mkTrail_SnapshotName @ 0x3c4a68, pointing at
// "_mkTrail_Snapshot_"). The name copies stock BrittleFracture.cpp's brittleFracture_SnapshotName.
static const char *mkTrail_SnapshotName = "_mkTrail_Snapshot_";

// No events (binary: mkTrail::eventCallbacks is 12 bytes, the terminating { NULL } entry only).
// The file's static-initialization entry _GLOBAL__I__ZN7mkTrail4TypeE (0x2a4250) comes from
// this: it runs __static_initialization_and_destruction_0, which constructs mkTrail::Type
// (and the file-scope objects of the stock headers).
CLASS_DECLARATION( idClass, mkTrail )
END_CLASS

/*
================
mkTrail::mkTrail

The C1 (0x2a51e0) and C2 (0x2a65f0) clones are the same code except where one store
(anchors' num) is scheduled.
================
*/
mkTrail::mkTrail( void ) {
	// spawnArgs' and anchors' constructors run first (stock, inline: idDict::idDict and
	// idList::idList). owner, lastPos, thinkFlags and modelDefHandle are not set here.
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
		gameRenderWorld->FreeEntityDef( modelDefHandle );		// idRenderWorld vtable +0x14
		modelDefHandle = -1;
	}
	if ( renderEntity.hModel ) {
		renderModelManager->FreeModel( renderEntity.hModel );	// idRenderModelManager vtable +0x1c
	}
	// Each entry is deleted, but not set to NULL (so not idList::DeleteContents).
	for ( int i = 0; i < anchors.Num(); i++ ) {
		delete anchors[ i ];
	}
	// Then the members' destructors (stock, inline): anchors, then spawnArgs. Then
	// idClass::~idClass(). The D0 clone then frees this with idClass::operator delete.
}

/*
================
mkTrail::Spawn

Called by idActor::Spawn after it has filled spawnArgs and owner.
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

	// idRenderModelManager vtable +0x18 AllocModel; idRenderModel vtable +0x10 InitEmpty.
	renderEntity.hModel = renderModelManager->AllocModel();
	renderEntity.hModel->InitEmpty( mkTrail_SnapshotName );
	renderEntity.callback = mkTrail::ModelCallback;
	renderEntity.bounds.Clear();
	renderEntity.noSelfShadow = false;
	renderEntity.noShadow = false;
	renderEntity.noDynamicInteractions = false;
	// Not an entity number: the pointer to this trail, which ModelCallback reads back.
	renderEntity.entityNum = reinterpret_cast<int>( this );
	self = this;
	renderEntity.axis = mat3_identity;
	renderEntity.origin.Zero();

	startColor = spawnArgs.GetVec4( "startcolor", "1 1 1 0" );
	renderEntity.shaderParms[ SHADERPARM_RED ] = startColor[ 0 ];
	renderEntity.shaderParms[ SHADERPARM_GREEN ] = startColor[ 1 ];
	renderEntity.shaderParms[ SHADERPARM_BLUE ] = startColor[ 2 ];
	renderEntity.shaderParms[ SHADERPARM_ALPHA ] = startColor[ 3 ];
	endColor = spawnArgs.GetVec4( "endcolor", "0 0 0 0" );

	modelDefHandle = gameRenderWorld->AddEntityDef( &renderEntity );	// idRenderWorld vtable +0xc
	thinkFlags = TH_THINK | TH_UPDATEVISUALS;
	gameLocal.BabySitTrail( this );
}

/*
================
mkTrail::Save

23 write calls, in this order (the truncated first export had 4).
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

Reads back exactly what Save wrote, in the same order. Does not call gameLocal.BabySitTrail
(see Notes).
================
*/
void mkTrail::Restore( idRestoreGame *savefile ) {
	int				i, num;
	trailAnchor_t *	anchor;

	// The renderEntity setup of Spawn, without the colors and entityNum (set below).
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

	renderEntity.entityNum = reinterpret_cast<int>( this );
	self = this;
	// The saved handle belonged to the old render world: only its "is there one" survives.
	if ( modelDefHandle != -1 ) {
		modelDefHandle = gameRenderWorld->AddEntityDef( &renderEntity );
	}
}

/*
================
mkTrail::Think

Run once a frame by idGameLocal::RunFrame, through the vtable.
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

	Present();		// virtual call (binary: vptr+0xc)

	if ( fadeStart ) {
		// fadeEnd == fadeStart (a "fadeTime" of 0) divides by zero here (see Notes).
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
			delete this;	// the deleting destructor, through the vtable (vptr+0x8)
		}
	}
}

/*
================
mkTrail::FadeTrail

The owner is going away (~idActor). Detach from it. With "fadeTime" "-1", stop thinking: the
trail stays as it is for good. Otherwise fade from startColor to endColor over fadeTime,
after "fadeDelay" seconds; Think deletes the trail at the end.
================
*/
void mkTrail::FadeTrail( void ) {
	owner = NULL;
	// UNCERTAIN: the form of the test. The binary compares with the constant -1000 (SEC2MS( -1 )).
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

Adds an anchor at the owner's position if it moved, and pushes the model to the renderer.
Copies the shape of stock idBrittleFracture::Present.
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
		renderEntity.bounds = renderEntity.hModel->Bounds( &renderEntity );	// idRenderModel vtable +0x78
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
		gameRenderWorld->UpdateEntityDef( modelDefHandle, &renderEntity );	// idRenderWorld vtable +0x10
	}
	changed = true;
}

/*
================
mkTrail::addNewAnchor

Drops an anchor on the ground below lastPos, unless there is no ground within maxSurfDist or
the last anchor is within anchorDist. If the new cross-section would cross the last one within
half the trail's width (a sharp turn), it is bent to share an edge point with it.
================
*/
bool mkTrail::addNewAnchor( void ) {
	trace_t				tr;
	idVec3				end;
	trailAnchor_t *		anchor;
	trailAnchor_t *		last;

	end = lastPos;
	end.z -= maxSurfDist;
	// UNCERTAIN: MASK_OPAQUE or CONTENTS_OPAQUE (both 2).
	gameLocal.clip.Translation( tr, lastPos, end, NULL, mat3_identity, MASK_OPAQUE, owner );
	if ( tr.fraction >= 1.0f ) {
		return false;
	}
	if ( anchors.Num() ) {
		if ( ( anchors[ anchors.Num() - 1 ]->origin - lastPos ).LengthFast() <= anchorDist ) {
			return false;
		}
	}

	anchor = new trailAnchor_t;
	// With no owner (after FadeTrail) the last anchor's direction is reused. The binary does not
	// check that there is one (see Notes).
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
		// Where the two cross lines meet, in the xy plane: t along the new dir.
		idMat2 m( anchor->dir.x, last->dir.x, anchor->dir.y, last->dir.y );
		if ( m.InverseSelf() ) {
			float t = m[ 0 ][ 0 ] * ( last->origin.x - lastPos.x ) + m[ 0 ][ 1 ] * ( last->origin.y - lastPos.y );
			if ( ( anchor->dir * t ).LengthFast() < trailWidth * 0.5f ) {
				// Keep the last anchor's nearer edge point, and move the other one halfway to the
				// last anchor's.
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
	// entityNum holds the trail itself (see Spawn). No NULL check (stock BrittleFracture has one).
	const mkTrail *trail = reinterpret_cast<const mkTrail *>( renderEntity->entityNum );
	return trail->UpdateRenderEntity( renderEntity, renderView );
}

/*
================
mkTrail::UpdateRenderEntity

Rebuilds the model: one quad per anchor, from each anchor's cross-section to the next, the
last one ending at a head section below the owner's current position. The texture's t runs
across the trail (0 to 1). Its s starts at 0, rises by uvWidth per anchor to 1, then bounces
between 1 and uvRepeat (SDK changelog r4).
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
	// idRenderModel vtable +0x10 InitEmpty, +0x5c AllocSurfaceTriangles.
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

	// The head section, on the ground below lastPos (as addNewAnchor would place it), or at
	// the last anchor when there is no ground. s goes on in proportion to the distance.
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

	// UNCERTAIN: the form. The binary indexes verts[ numVerts ] for each field and increments
	// numVerts on the xyz store, unlike the loop above.
	tris->verts[ tris->numVerts ].Clear();
	tris->verts[ tris->numVerts ].st[ 0 ] = s;
	tris->verts[ tris->numVerts ].st[ 1 ] = 0.0f;
	tris->verts[ tris->numVerts++ ].xyz = tr.endpos + dir * trailWidth * -0.5f;
	tris->verts[ tris->numVerts ].Clear();
	tris->verts[ tris->numVerts ].st[ 0 ] = s;
	tris->verts[ tris->numVerts ].st[ 1 ] = 1.0f;
	tris->verts[ tris->numVerts++ ].xyz = tr.endpos + dir * trailWidth * 0.5f;

	// Two triangles per quad. Vertex 2k is edge0 of section k, 2k+1 its edge1.
	// UNCERTAIN: the form. The binary keeps the index in a register and stores numIndexes once
	// per quad.
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

	// idSIMDProcessor vtable +0x80: MinMax( idVec3 &, idVec3 &, const idDrawVert *, const int ).
	SIMDProcessor->MinMax( tris->bounds[ 0 ], tris->bounds[ 1 ], tris->verts, tris->numVerts );

	surface.id = 0;
	surface.shader = material;
	surface.geometry = tris;
	renderEntity->hModel->AddSurface( surface );	// idRenderModel vtable +0x14

	return true;
}

// ===========================================================================
// idGameLocal additions (Game_local.cpp; in the binary, RemoveTrail sits between the stock
// SetAASAreaState and GetAAS, BabySitTrail between RadiusPushClipModel and AlertAI)
// ===========================================================================

/*
================
idGameLocal::BabySitTrail

Registers a trail so RunFrame thinks it. Called only from mkTrail::Spawn.
================
*/
void idGameLocal::BabySitTrail( mkTrail *trail ) {
	trails.Append( trail );
}

/*
================
idGameLocal::RemoveTrail

Called only from ~mkTrail. Does nothing if the trail is not in the list.
================
*/
void idGameLocal::RemoveTrail( mkTrail *trail ) {
	trails.Remove( trail );
}
```

## Notes

- **Base class and hooks agree.** `mkTrail` derives from `idClass` (evidence in the header), not from `idEntity`: it is not an entity, has no physics, and draws through its own `renderEntity`. `idGameLocal::trails` (+0x4) holds `mkTrail *`. `BabySitTrail` / `RemoveTrail` are the only functions that add to or remove from it (in the covered code), and `idGameLocal::RunFrame` is the only place that walks it (below).
- **Who drives a trail (edits inside stock functions, out of scope for spec #16, recorded as leads).**
  - `idActor::Spawn` (0xb951e-0xb95b2): `if ( spawnArgs.GetBool( "hasTrail" ) )` (stored at idActor+0xf6c) it allocates a `mkTrail` (`idClass::operator new( 0x18c )`, the C1 constructor), stores it at idActor+0x920, copies `*gameLocal.FindEntityDefDict( spawnArgs.GetString( "trailDef" ), false )` into its `spawnArgs` (`idDict::Copy`), sets `owner = this` and calls `Spawn()`. There is no NULL check on the def.
  - `~idActor` (all three clones, e.g. 0xb5c1f-0xb5c39): `if ( hasTrail ) trail->FadeTrail();`.
  - `idGameLocal::RunFrame` (0xf5c4a-0xf5c71), just before its call to `RunDebugInfo`: `for ( i = 0; i < trails.Num(); i++ ) trails[ i ]->Think();` (a virtual call, vptr+0x10).
  - Nothing else calls a `mkTrail` function directly (checked over every function's direct calls). Where the list is emptied at map end was not checked.
- **spawnArgs, cross-checked with `def/` and `maps/`.**
  - The only trail def is `entityDef trail` (`def/slime_trail.def`). It sets all 13 keys the binary reads: `mtr_trail` ("textures/chex/decals/slime_trail"), `updateDist` 2, `trailWidth` 60, `anchorDist` 15, `maxAnchors` 300, `uvWidth` 0.05575284, `uvRepeat` 0.38671875, `startcolor` "1 1 1 1", `endcolor` "0 0 0 0", `fadeDelay` 0, `fadeTime` -1, `surfDist` 1, `maxSurfDist` 8.
  - It also sets `"spawnclass" "mkTrail"` and `"leader" "player1"`, which nothing in the binary reads for trails. `corvette_notes.txt` (12/14 entry) lists `leader` as "Actor to follow (needs the viewAxis)": an earlier design. The owner now comes from `idActor::Spawn`.
  - Actors: `def/chex_monster_flemoid.def` sets `"hasTrail" "1"`, `"trailDef" "trail"`. `def/monster_default.def` and one entity in `maps/sf_923.map` set `"hasTrail" "0"`, and `def/monster_chex_biped.def` sets `"hastrail" "0"` (lowercase; stock `idDict` key lookup ignores case, not checked in this binary).
  - `fadeTime` -1 (the def's value) means `FadeTrail` stops the trail's thinking and it is never deleted. `corvette_notes.txt` (6/15/06): "i thought the trails lasted forever, but it looks like it's back at 5secs".
  - The binary's own defaults (`"2"`, `"32"`, `"16"`, `"15"`, `"3.0"`, `"10.0"`, `"0"`, `".05"`, `".25"`, `"1 1 1 0"`, `"0 0 0 0"`, `mtr_trail` `""`) apply only to keys a def leaves out. The constructor's 2.0 / 32.0 / 16.0 / 15 are overwritten by `Spawn` in every case.
- **Rendering.** The model is rebuilt in `UpdateRenderEntity` only when `Present` has set `changed`, at most once per game frame. It has `numAnchors * 2 + 2` vertices and `numAnchors * 6` indexes, one quad from each anchor's section to the next and the last to the head. The color comes from `shaderParms` 0-3 (start color, then the fade). `renderEntity.entityNum` holds the `mkTrail *`, not an entity number: `ModelCallback` casts it back. The layout of `renderEntity_t`, `srfTriangles_t` (`tangentsCalculated` +0x1d, `numVerts` +0x24, `verts` +0x28, `numIndexes` +0x2c, `indexes` +0x30), `idDrawVert` (0x3c bytes) and `trace_t` (`endpos` +0x4) match a GCC 12 `-m32` build of the stock headers, as do the vtable offsets named in the code (pointer-to-virtual-member values; Itanium layout, as the binary's GCC 3): `idDeclManager::FindMaterial` +0x60, `idRenderModelManager::AllocModel` +0x18 / `FreeModel` +0x1c, `idRenderModel::InitEmpty` +0x10 / `AddSurface` +0x14 / `AllocSurfaceTriangles` +0x5c / `Bounds` +0x78, `idRenderWorld::AddEntityDef` +0xc / `UpdateEntityDef` +0x10 / `FreeEntityDef` +0x14, `idSIMDProcessor::MinMax` +0x80, `idPhysics::GetOrigin` +0x84. `idActor::viewAxis` is +0x8dc in both this binary (stock `idActor::GetViewPos` reads it there) and stock, so `viewAxis[ 1 ]` is +0x8e8.
- **Stock idioms.** `idMath::Fabs` (the `and 0x7fffffff` in the binary), `idVec3::LengthFast` (the 0x5f3759df `RSqrt` step), `idVec3::Normalize` (the `iSqrt` table of `idMath::InvSqrt`), `idBounds::Clear` / `AddPoint`, `idDrawVert::Clear`, `idList::Append` / `Remove` / `RemoveIndex` / `Clear`, `idDict::GetFloat` / `GetInt` / `GetString`, `SEC2MS` (a truncating `cvttss2si`: stock `idMath::FtoiFast` is `(int) f` on Linux). The class copies stock `idBrittleFracture` closely: snapshot name, `ModelCallback` / `UpdateRenderEntity`, `lastRenderEntityUpdate` = -1, `changed`, `Present`'s `forceUpdate` and `AddEntityDef` / `UpdateEntityDef`. The member names `lastRenderEntityUpdate`, `changed`, `modelDefHandle`, `thinkFlags` are taken from there and from `idEntity`.
- **Allow-listed callees (check 1, `verify/allowlist.tsv`).**
  - `exception-only`: `idClass::~idClass` in both constructor clones. The constructors' only call to it is in their exception landing pad (C1 0x2a53d6, just before `_Unwind_Resume`): if a member constructor throws, the already-built base is destroyed. No source statement makes the call.
  - `stock-inline`: `idHashIndex::Init`, `idHashIndex::Free`, `operator new[]` and `operator delete[]` in the constructors (the inline `idDict::idDict()` of `spawnArgs`: `idHashIndex()`, `args.SetGranularity`, `argHash.Clear( 128, 16 )`); `idDict::Clear`, `idHashIndex::Free` and `operator delete[]` in the three destructor clones (the inline destructors of `anchors` and `spawnArgs`); `idDict::FindKey` and `__strtod_internal` (plus `__strtol_internal` in `Spawn`) inside `spawnArgs.GetFloat` / `GetInt` / `GetString` in `Spawn` and `FadeTrail`; `operator new[]` / `operator delete[]` inside `idList::Append` / `Clear` in `addNewAnchor`, `Restore` and `BabySitTrail`. Each entry names the stock function.
  - `abi-implicit` (the existing wildcard entry): `idClass::operator delete` in the D0 clone.
- **Literals (check 2).** Every string `Spawn` and `FadeTrail` read appears verbatim. The constructors' 2.0 / 32.0 / 16.0 are instruction immediates. `UpdateRenderEntity`'s 0.001 is a double (`idMath::Fabs( ... ) <= 0.001`, no `f`), its 1.0 is the `st[ 1 ]` immediate, and -0.5 / 0.5 are the half-widths. Allow-listed (`verify/literal-allowlist.tsv`, `stock-inline`): 1.5 in `Think`, `UpdateRenderEntity` and `addNewAnchor`, and 0.5 in `Think`, which come only from the Newton step of `idMath::RSqrt` / `InvSqrt` inside `LengthFast` / `Normalize`.
- **Compile (check 3).** Compiles with g++ 12 `-m32` against stock DOOM-3 GPL a9c49da. The `idGameLocal` partial declaration is spliced into a scratch copy of `game/Game_local.h` (at the end, not at +0x4). `class mkTrail;` is a top-level forward declaration, compiled before the stock game headers, because `idGameLocal::trails` points to it. `reinterpret_cast<int>( this )` is valid only in a 32-bit build, like the original.
- **Save / Restore.** `Save` makes all 23 write calls of the binary (the truncated first export showed 4). `Restore` makes exactly the matching 23 read calls (`Read` once per anchor), nothing more. After the reads it points `entityNum` / `self` at itself again and, if the trail had a render entity, adds a new one.
- **Ghidra artifacts.**
  - `this + 8` is `spawnArgs` (the `idDict`), not an `idDict` at the start of a base class. In the constructors the stores to +0x8 ... +0x2c with `idHashIndex::Init` / `Free` and the `operator_new__` / `operator_delete__` run are the inline `idDict` constructor; +0x94 ... +0xa0 are `anchors`' `idList` constructor.
  - The long `operator_new__` / `operator_delete__` blocks in `addNewAnchor`, `Restore` and `BabySitTrail` are the inline `idList::Append` (its `Resize`), not custom code. In `Present` and `RemoveTrail` the shifting loops are `idList::RemoveIndex` / `Remove`.
  - In `Present`, the goto maze after `GetPhysics` is `idBounds::AddPoint` (min / max per axis). `piVar7[-1] = 0x2b...` stores and `stack0xffffffc4` are return addresses and argument slots, not data.
  - In `UpdateRenderEntity`, `(float)0.001` is the double 0.001 (the compare is done on the x87 stack), and `ABS` is the inlined `idMath::Fabs`. The block of zero stores before each vertex is `idDrawVert::Clear()`.
  - `mkTrail::CreateInstance` passes a stray `in_stack_ffffffd8` to `operator_new`; the size is 0x18c. `GetType` returns `&mkTrail::Type` (`PTR_Type_003e10bc`).
  - The D0 destructor passes `pmVar3` (a leftover register) to `operator_delete`; it is `idClass::operator delete( this )`. The same export drops the `modelDefHandle` / `hModel` arguments of the `FreeEntityDef` / `FreeModel` calls (the D1 export shows them).
  - `Spawn`'s `local_14 = 0x2b5549` is the return address the PIC thunk call pushes, not data; the same slot later holds `endColor`'s last component.
- **Open questions (binary behavior, need an in-game check).**
  - `lastPos` is never initialized (not by the constructor, not by `Spawn`). The first `Think` compares the owner's origin with whatever the allocation held; `Spawn` also sets `TH_UPDATEVISUALS`, so the first `Present` traces from that value if the distance test fails (for example on a NaN).
  - `addNewAnchor` with no owner (after `FadeTrail`) reads `anchors[ Num() - 1 ]` without checking that there is one. It gets there only if the trace below `lastPos` hits ground and the trail has no anchor yet.
  - `Restore` does not call `gameLocal.BabySitTrail`, so a restored trail is not in `gameLocal.trails` (unless something outside this group re-adds it) and does not think after a load. Whether `idActor::Save` / `Restore` save the `trail` pointer was not checked.
  - `Think` deleting its trail makes `RemoveTrail` shift the list while `RunFrame` walks it with an increasing index, so the next trail skips one frame.
  - With the def's `"fadeTime" "-1"`, trails are never deleted by themselves; with `"fadeTime" "0"` the fade divides by zero (`fadeEnd == fadeStart`).
