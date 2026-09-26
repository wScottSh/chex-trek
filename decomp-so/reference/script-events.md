# Standalone script events (`footprint`, `setProj`, `spawnDict`) and the `ProjectDecal` overload: reconstructed reference

**Provenance:** reconstructed by **Claude Opus 5.5** on 2026-09-24 from the complete Ghidra export `decomp-so/ghidra-full/` of `gamex86.so` (Ghidra 12.1.4, "Non-Returning Functions - Discovered" disabled), enriched export (issue #18: float constants and string literals resolved from `.rodata`). Checks 1-3 pass (issue #26; the `ProjectDecal` overload was added in PR #27's final review). Check 3 compiles it, 32-bit, against stock DOOM-3 GPL a9c49da. Export files: `idActor_Event_FootPrint_000c6210.c`, `idWeapon_Event_SetProj_001af990.c`, `idThread_Event_SpawnDict_0024dc00.c` and `idGameLocal_ProjectDecal_00101c80.c`. Facts marked *binary* were read straight from `gamex86.so` (symbol table, relocations, event tables, static initializers, disassembly). Reference material only, not original source. The original source does not exist.

Scope (spec #16, issue #26): three new script events, each added to a stock class, and their handlers. `idActor::Event_FootPrint` (the `footprint` event, spelled `footPrint` in the spec), `idWeapon::Event_SetProj` (`setProj`) and `idThread::Event_SpawnDict` (`spawnDict`). They are grouped by kind only: none calls another. Also the new 8-argument `idGameLocal::ProjectDecal` overload, whose only caller is `Event_FootPrint`.

Spec #16 (story 15) lists six new script events. The other three are in other groups: `openDoors` (`door-opening.md`), `updateStats` (`end-level-stats.md`: really the internal `"<UpdateEndLevelStats>"`) and `envShot` (`env-shots.md`). `envShot` is not a script event: the event is `"<envshot>"`, an internal event with no arguments that only `matt_func_envshot::Spawn` posts. `envShot` is the name of its C++ symbols and of the renderer command it runs. Addresses below are ELF virtual addresses. Ghidra's are `+0x10000`. Stock DOOM-3 GPL source (a9c49da) is referenced, not repeated.

## Header

```cpp
// ---------------------------------------------------------------------------
// idGameLocal addition (Game_local.h)
// ---------------------------------------------------------------------------
class idGameLocal : public idGame {
	// ... stock members ...
public:
	// A new overload next to the stock 7-argument ProjectDecal. The binary has both:
	// _ZN11idGameLocal12ProjectDecalERK6idVec3S2_fbfPKcf @ 0xf0db0 (stock) and
	// _ZN11idGameLocal12ProjectDecalERK6idVec3S2_fbfPKcPS1_f @ 0xf1c80 (this one).
	// UNCERTAIN: the name of `decalWinding` (named after the stock static it replaces) and whether
	// it has default arguments.
	void					ProjectDecal( const idVec3 &origin, const idVec3 &dir, float depth, bool parallel, float size, const char *material, const idVec3 *decalWinding, float angle );
};

// ---------------------------------------------------------------------------
// idActor additions (Actor.h)
// ---------------------------------------------------------------------------
// Binary: EV_FootPrint is STB_GLOBAL and other files read it through the GOT
// (idAnim::CallFrameCommands, 0x20d9a9). So it is declared extern, like the stock EV_Footstep.
extern const idEventDef EV_FootPrint;

class idActor : public idAFEntity_Gibbable {
	// ... stock members ...
private:
	// UNCERTAIN: access level. Stock idActor keeps its Event_* handlers private; the only direct
	// caller, PlayFootStepSound, is an idActor member (see Notes), so private is enough.
	void					Event_FootPrint( const char *side, const char *jointName );

public:
	// UNCERTAIN: every name, and the access level. Offsets (binary): idActor is 0xf78 bytes in this build
	// (idActor::CreateInstance allocates 0xf78), and 0xf68 in stock (g++ -m32 of the stock header). The
	// last stock members are 4 bytes further on than in stock (allowPain +0xf54, stock 0xf50; attachments
	// +0xf5c, stock 0xf58). So the new members come after attachments, at the end:
	//   +0xf6c  bool hasTrail (reference/trails.md, Notes: idActor::Spawn stores spawnArgs "hasTrail")
	//   +0xf6d .. +0xf77  the footprint state below.
	// idActor::idActor sets footprintSurfaceType = -1 and footprintEndTime = 0 (binary: C1 0xb593f / 0xb5945, C2 0xb75df / 0xb75e5).
	// It does not set footprintRight. No idActor, idAI or idPlayer function other than Event_FootPrint
	// touches +0xf6d, +0xf70 or +0xf74 (binary scan), so Save / Restore write none of the three.
	// Check 3 splices them at the end of the stock declaration.
	bool					footprintRight;			// +0xf6d  next footstep print is the right foot ("_r")
	int						footprintEndTime;		// +0xf70  gameLocal.time until which the surface-type print is used
	int						footprintSurfaceType;	// +0xf74  surfTypes_t last stepped on with a footprint_time_<type>; -1 = none
};

// ---------------------------------------------------------------------------
// idWeapon addition (Weapon.h)
// ---------------------------------------------------------------------------
class idWeapon : public idAnimatedEntity {
	// ... stock members ...
private:
	// UNCERTAIN: access level. Stock idWeapon keeps its Event_* handlers private.
	void					Event_SetProj( const char *projName );
};

// ---------------------------------------------------------------------------
// idThread addition (script/Script_Thread.h)
// ---------------------------------------------------------------------------
// Binary: EV_Thread_SpawnDict is STB_GLOBAL and read through the GOT, like the stock events
// Script_Thread.h declares extern (EV_Thread_SpawnVector ...).
extern const idEventDef EV_Thread_SpawnDict;

class idThread : public idClass {
	// ... stock members ...
private:
	// UNCERTAIN: access level. Stock idThread keeps its Event_* handlers private.
	void					Event_SpawnDict( const char *defName );
};
```

## Implementation

```cpp
// ===========================================================================
// footprint (Actor.cpp)
// ===========================================================================

// Binary: Actor.cpp's static initializer (0xb0f30) constructs it at 0xb160e as
// idEventDef( "footprint", "ss", 0 ): two string arguments, no return value. It comes right after the
// stock AI_GetHead (0xb15e6). The name "footprint" is not a string of its own in .rodata: it is the
// tail of "mtr_footprint" (the linker shares the bytes).
const idEventDef EV_FootPrint( "footprint", "ss" );

// Binary: idActor::eventCallbacks (44 entries) entry 41 = { EV_FootPrint, idActor::Event_FootPrint }.
// Entries 0-40 are the stock table, which ends with AI_GetHead. So in the stock
// CLASS_DECLARATION( idAFEntity_Gibbable, idActor ) table in Actor.cpp (not repeated here), after
// EVENT( AI_GetHead, idActor::Event_GetHead ), the mod added:
//
//	EVENT( EV_FootPrint,				idActor::Event_FootPrint )
//
// (Entry 42, before the terminator, is { EV_Remove, idClass::Event_Remove }. It is not stock either and
// not part of this group. See Notes.)

/*
================
idActor::Event_FootPrint

Leaves a footprint decal under the actor. Called with a joint by the anim frame command
"footprint <joint> <l|r>", and with no joint by PlayFootStepSound when "footprint_on_sound" is set.

A surface type with a "footprint_time_<type>" key makes the actor leave "mtr_footprint_<type>"
prints for that many seconds after stepping on it. Otherwise "mtr_footprint" is used, and nothing
is printed when that is empty. The material name gets "_<side>" (frame command) or "_l" / "_r"
(footsteps, alternating) appended.
================
*/
void idActor::Event_FootPrint( const char *side, const char *jointName ) {
	modelTrace_t	result;
	float			time;
	const char		*mtr;
	idVec3			winding[ 4 ];
	idVec3			offset;
	idVec3			origin;
	idMat3			axis;

	// GetPhysics() vtable +0xdc is idPhysics::HasGroundContacts (pointer-to-member value in a
	// g++ -m32 build of the stock header).
	if ( !GetPhysics()->HasGroundContacts() ) {
		return;
	}

	// What is under the actor: trace from the physics origin raised by footprint_s_z to the origin
	// raised by footprint_e_z (defaults 0 and -8: from the origin to 8 below). GetOrigin is vtable +0x84.
	// idDict::GetFloat( key, default ) is ID_INLINE: FindKey, then atof.
	idVec3 start = GetPhysics()->GetOrigin();
	idVec3 end = start;
	start.z += spawnArgs.GetFloat( "footprint_s_z", "0" );
	end.z += spawnArgs.GetFloat( "footprint_e_z", "-8" );
	// idRenderWorld::Trace is vtable +0x7c: radius 8, skipDynamic false, skipPlayer true.
	if ( gameRenderWorld->Trace( result, start, end, 8.0f, false, true ) && result.material ) {
		// GetSurfaceType() is the inline idMaterial accessor: surfaceFlags (+0x64) & SURF_TYPE_MASK (0xf).
		// The non-inline GetFloat( key, default, float & ) returns whether the key is set.
		if ( spawnArgs.GetFloat( va( "footprint_time_%s", gameLocal.sufaceTypeNames[ result.material->GetSurfaceType() ] ), "0", time ) ) {
			footprintSurfaceType = result.material->GetSurfaceType();
			// gameLocal.time is +0x251884 (stock 0x251874, see reference/trails.md). SEC2MS is the
			// stock macro: FtoiFast( t * M_SEC2MS ), a truncating cvttss2si in this build.
			footprintEndTime = gameLocal.time + SEC2MS( time );
		}
	}

	// UNCERTAIN: how the source was written. The binary sets footprintSurfaceType to -1 on the
	// fallback path only, and falls back to "mtr_footprint" when the type's lookup gives a NULL
	// pointer (0xb6a40). GetString never returns NULL, so a missing "mtr_footprint_<type>" key
	// gives "" and no print, not the fallback.
	mtr = NULL;
	if ( footprintSurfaceType != -1 && gameLocal.time < footprintEndTime ) {
		mtr = spawnArgs.GetString( va( "mtr_footprint_%s", gameLocal.sufaceTypeNames[ footprintSurfaceType ] ), "" );
	} else {
		footprintSurfaceType = -1;
	}
	if ( !mtr ) {
		mtr = spawnArgs.GetString( "mtr_footprint", "" );
	}
	if ( !mtr[ 0 ] ) {
		return;
	}

	float scaleX = spawnArgs.GetFloat( "footprint_scale_x", "1" );
	float scaleY = spawnArgs.GetFloat( "footprint_scale_y", "1" );
	float size = spawnArgs.GetFloat( "footprint_size", "16" );

	// The decal's corners: the stock decalWinding, scaled per axis.
	// UNCERTAIN: written as four Set calls or as an initialized array.
	winding[ 0 ].Set( scaleX, scaleY, 0.0f );
	winding[ 1 ].Set( -scaleX, scaleY, 0.0f );
	winding[ 2 ].Set( -scaleX, -scaleY, 0.0f );
	winding[ 3 ].Set( scaleX, -scaleY, 0.0f );

	// viewAxis is +0x8dc (as in stock). Only yaw is used: it turns the print to face along the view.
	idAngles angles = viewAxis.ToAngles();

	if ( jointName ) {
		// Frame command: print at the joint, moved by footprint_offset_<side> in the actor's
		// ground-plane frame. GetVector( key, NULL, out ) leaves out at 0 0 0 when the key is missing.
		spawnArgs.GetVector( va( "footprint_offset_%s", side ), NULL, offset );
		// animator is +0x27c (as in stock).
		GetJointWorldTransform( animator.GetJointHandle( jointName ), gameLocal.time, origin, axis );

		// The joint's axis is not used: the same stack slots are filled with viewAxis flattened onto
		// the ground plane. ProjectOntoPlane (default overBounce 1) and Normalize are ID_INLINE
		// (idlib/math/Vector.h). UNCERTAIN: whether the source reused `axis` or had a second idMat3.
		axis[ 2 ].Set( 0.0f, 0.0f, 1.0f );
		axis[ 0 ] = viewAxis[ 0 ];
		axis[ 0 ].ProjectOntoPlane( axis[ 2 ] );
		axis[ 0 ].Normalize();
		axis[ 1 ] = viewAxis[ 1 ];
		axis[ 1 ].ProjectOntoPlane( axis[ 2 ] );
		axis[ 1 ].Normalize();
		offset *= axis;

		// Straight down, 8 deep, parallel projection.
		gameLocal.ProjectDecal( origin + offset, idVec3( 0.0f, 0.0f, -1.0f ), 8.0f, true, size, va( "%s_%s", mtr, side ), winding, idMath::HALF_PI - DEG2RAD( angles.yaw ) );
		return;
	}

	// Footstep: no joint. Alternate feet, 12 units to either side of the physics origin
	// (viewAxis[ 1 ] points left). The binary computes the angle in each branch.
	idVec3 sideOffset;
	const char *suffix;
	if ( footprintRight ) {
		sideOffset = viewAxis[ 1 ] * -12.0f;
		suffix = "_r";
	} else {
		sideOffset = viewAxis[ 1 ] * 12.0f;
		suffix = "_l";
	}
	gameLocal.ProjectDecal( GetPhysics()->GetOrigin() + sideOffset, idVec3( 0.0f, 0.0f, -1.0f ), 8.0f, true, size, va( "%s%s", mtr, suffix ), winding, idMath::HALF_PI - DEG2RAD( angles.yaw ) );
	// xor byte [this + 0xf6d], 1
	footprintRight = !footprintRight;
}

// ===========================================================================
// ProjectDecal overload (Game_local.cpp)
// ===========================================================================

/*
================
idGameLocal::ProjectDecal

The stock ProjectDecal with the decal's four corner directions passed in by the caller
(decalWinding) instead of read from the stock function's static decalWinding. Only
Event_FootPrint calls it, with the stock corners scaled by footprint_scale_x / _y.

Binary: the body is the stock one (0xf0db0) instruction for instruction, register allocation
aside. The two differences: the corners are read through the 7th argument (esi, from
[esp + 0x65c]; +0x0, +0xc, +0x18, +0x24), and the static's one-time initialization
(`cmp byte [guard], 0`, __cxa_guard_acquire / __cxa_guard_release and the twelve stores) is gone.
The rest is the stock inline code: g_decals.GetBool() (internalVar->integerValue),
random.RandomFloat() (seed * 69069 + 1, & 0x7fff, / 32768), idMath::SinCos16,
idVec3::Normalize / NormalVectors, idFixedWinding with 64 points on the stack, then the two
vtable calls declManager->FindMaterial and gameRenderWorld->ProjectDecalOntoWorld.
================
*/
void idGameLocal::ProjectDecal( const idVec3 &origin, const idVec3 &dir, float depth, bool parallel, float size, const char *material, const idVec3 *decalWinding, float angle ) {
	float s, c;
	idMat3 axis, axistemp;
	idFixedWinding winding;
	idVec3 windingOrigin, projectionOrigin;

	if ( !g_decals.GetBool() ) {
		return;
	}

	// randomly rotate the decal winding, unless an angle is given (Event_FootPrint's is 0 only
	// when the actor's yaw is exactly 90)
	idMath::SinCos16( ( angle ) ? angle : random.RandomFloat() * idMath::TWO_PI, s, c );

	// winding orientation
	axis[2] = dir;
	axis[2].Normalize();
	axis[2].NormalVectors( axistemp[0], axistemp[1] );
	axis[0] = axistemp[ 0 ] * c + axistemp[ 1 ] * -s;
	axis[1] = axistemp[ 0 ] * -s + axistemp[ 1 ] * -c;

	windingOrigin = origin + depth * axis[2];
	if ( parallel ) {
		projectionOrigin = origin - depth * axis[2];
	} else {
		projectionOrigin = origin;
	}

	size *= 0.5f;

	winding.Clear();
	winding += idVec5( windingOrigin + ( axis * decalWinding[0] ) * size, idVec2( 1.0f, 1.0f ) );
	winding += idVec5( windingOrigin + ( axis * decalWinding[1] ) * size, idVec2( 0.0f, 1.0f ) );
	winding += idVec5( windingOrigin + ( axis * decalWinding[2] ) * size, idVec2( 0.0f, 0.0f ) );
	winding += idVec5( windingOrigin + ( axis * decalWinding[3] ) * size, idVec2( 1.0f, 0.0f ) );
	gameRenderWorld->ProjectDecalOntoWorld( winding, projectionOrigin, parallel, depth * 0.5f, declManager->FindMaterial( material ), time );
}

// ===========================================================================
// setProj (Weapon.cpp)
// ===========================================================================

// Binary: Weapon.cpp's static initializer (0x1a2d10) constructs it at 0x1a31ed as
// idEventDef( "setProj", "s", 0 ): one string argument, no return value. The symbol
// EV_Weapon_SetProj is STB_LOCAL, like the stock `const idEventDef EV_Weapon_*` in Weapon.cpp.
const idEventDef EV_Weapon_SetProj( "setProj", "s" );

// Binary: idWeapon::eventCallbacks (38 entries) entry 36 = { EV_Weapon_SetProj, idWeapon::Event_SetProj },
// right after the last stock entry (35, EV_Weapon_NetEndReload). So at the end of the stock
// CLASS_DECLARATION( idAnimatedEntity, idWeapon ) table in Weapon.cpp (not repeated here) the mod added:
//
//	EVENT( EV_Weapon_SetProj,				idWeapon::Event_SetProj )

/*
================
idWeapon::Event_SetProj

Swaps the projectile this weapon fires for the entityDef projName. Unknown names are ignored,
without a warning.
================
*/
void idWeapon::Event_SetProj( const char *projName ) {
	const idDeclEntityDef *projectileDef = gameLocal.FindEntityDef( projName, false );
	if ( projectileDef ) {
		// projectileDict is the stock member (+0x798, as in stock); dict is +0x8 in the decl.
		projectileDict = projectileDef->dict;
	}
}

// ===========================================================================
// spawnDict (script/Script_Thread.cpp)
// ===========================================================================

// Binary: Script_Thread.cpp's static initializer (0x23bac0) constructs it at 0x23c724 as
// idEventDef( "spawnDict", "s", 'e' ): one string argument, returns an entity. It comes right after the
// stock EV_Thread_InfluenceActive (0x23c6fd). The format "s" is held in ebp from 0x23bc57 on.
const idEventDef EV_Thread_SpawnDict( "spawnDict", "s", 'e' );

// Binary: idThread::eventCallbacks (80 entries) entry 78 = { EV_Thread_SpawnDict, idThread::Event_SpawnDict },
// right after the last stock entry (77, EV_Thread_InfluenceActive). So at the end of the stock
// CLASS_DECLARATION( idClass, idThread ) table in Script_Thread.cpp (not repeated here) the mod added:
//
//	EVENT( EV_Thread_SpawnDict,				idThread::Event_SpawnDict )

/*
================
idThread::Event_SpawnDict

Like the stock spawn event, but starts from the entityDef defName: its keys, then the keys set with
setSpawnArg on top. Returns the new entity.
================
*/
void idThread::Event_SpawnDict( const char *defName ) {
	idEntity *ent;

	// Looked up before the local dict is built (binary order). No NULL check: an unknown name
	// makes Copy read through a NULL reference.
	const idDict *defDict = gameLocal.FindEntityDefDict( defName, false );

	// idDict's constructor and destructor are ID_INLINE (idlib/Dict.h): the binary shows
	// idHashIndex::Init( 1024, 1024 ), the idList::SetGranularity resize (new[] / delete[]),
	// argHash.Clear( 128, 16 ) (Free), and at the end Clear, Free and delete[].
	idDict dict;
	dict.Copy( *defDict );
	// spawnArgs is the stock member (+0x1b40, as in stock) that setSpawnArg fills.
	dict.Copy( spawnArgs );
	// Third argument false (binary: 0 stored to the argument slot at 0x23dd57). Stock names it setDefaults (default true) and
	// never reads it. UNCERTAIN: whether this build's SpawnEntityDef reads it (not checked).
	// The stock spawn event passes the default.
	gameLocal.SpawnEntityDef( dict, &ent, false );
	ReturnEntity( ent );
	dict.Clear();
	spawnArgs.Clear();
}
```

## Notes

- **The three events, matched to the mod's data.** `script/doom_main.script:12` includes `script/chex_events.script`, which declares the mod's script events (line 2 is `openDoors`, see `reference/door-opening.md`).
  - `setProj`: definition `idEventDef( "setProj", "s" )`, one string, no return value. `script/chex_events.script:3` declares `scriptEvent void setProj( string def );`: the same name, one string argument and `void`. The only calls are `script/map_storage_facility.script:128` and `:130`, in `weap_disable()`: once a second, `weap.setProj( weap.getKey( "def_projectile" ) )`, or with `+ "_nodamage"` appended while `weapDamage` is off, on `$player1.getWeaponEntity()`. The only `_nodamage` def is `projectile_minizorchblast_nodamage` (`def/weapon_pistol.def:253`), so for other weapons `FindEntityDef( ..., false )` returns NULL and nothing changes.
  - `spawnDict`: definition `idEventDef( "spawnDict", "s", 'e' )`, one string, returns an entity. `script/chex_events.script:4` declares `scriptEvent entity spawnDict( string def );`: the same name, argument and return type. It is an `idThread` event, so scripts would call it as `sys.spawnDict( ... )`. No script, map or def in this repo calls it. `corvette_notes.txt` (1/3/06): "spawnDict added to script system, allows spawning dicts by name, stuff set by setSpawnArg overrides defaults". That matches the code: the def's keys first, then `setSpawnArg`'s keys copied over them.
  - `footprint`: definition `idEventDef( "footprint", "ss" )`, two strings (`side`, then `jointName`), no return value. No script declares it: `script/` has no `scriptEvent` for it, so scripts cannot call it. The spec calls it `footPrint` after the handler's name. Its two callers are C++ (binary):
    - `idAnim::CallFrameCommands` (0x20d9b6): `ent->ProcessEvent( &EV_FootPrint, <string>, modelDef->GetJointName( <index> ) )`. Both arguments are type `'s'` (0x73). `idAnim::AddFrameCommand` parses the frame command's name `"footprint"` (0x2175d5, `idStr::Cmp`). `corvette_notes.txt` (11/28) documents it as the anim command `footprint <bone> <l|r>`. `def/monster_chex_biped.def:11-12` uses it on the `walk` anim: `frame 12 footprint Lfoot l`, `frame 33 footprint Rfoot r`. So `side` is `"l"` / `"r"` and `jointName` the bone. UNCERTAIN: the `frameCommand_t` field names (the string and the joint index). These are edits inside stock functions, out of scope for spec #16 and not reconstructed.
    - `idActor::PlayFootStepSound` (0xb6cf5-0xb6d4b), after the stock `StartSoundShader`: `if ( spawnArgs.GetBool( "footprint_on_sound" ) ) { Event_FootPrint( NULL, NULL ); }`. It is a direct call, not an event. Also an edit inside a stock function.
- **Footprint keys, cross-checked against `def/`** (the key list in `corvette_notes.txt` 11/28 and 1/3/06 agrees).
  - `def/player.def:936-945`: `footprint_size` 18, `footprint_scale_x` .7, `footprint_scale_y` 1, `footprint_s_z` 2, `footprint_e_z` -10, `footprint_on_sound` 1, `mtr_footprint_surftype15` `textures/chex/decals/chex_footprint`, `footprint_time_surftype15` 8. No `mtr_footprint`. So the player leaves prints on every footstep for 8 seconds after walking on a `surftype15` material ("we'll let surftype15 be flemoids"), alternating `chex_footprint_l` / `_r`. `surftype15` is the stock `idGameLocal::sufaceTypeNames[ 15 ]`.
  - `def/monster_chex_biped.def:42-51`: `footprint_size` 18, scales .7 / 1, `footprint_offset_l` / `_r` `"5 0 0"`, `mtr_footprint` `textures/chex/decals/flemprint`. No `footprint_on_sound`. So the biped prints `flemprint_l` / `flemprint_r` from its walk frame commands, 5 units forward of the foot joint, always.
  - Both defs list `mtr_footprint1` / `mtr_footprint2` as the `_l` / `_r` materials "for preload only". The code never reads those keys: the names it builds (`%s_%s`, `%s%s`) are what the preload is for.
  - `footprint_time_<type>` / `mtr_footprint_<type>` take the stock type names (`metal`, `stone`, ..., `surftype15`). The notes spell them `_surfacetype`, meaning the type's name.
- **The `idGameLocal::ProjectDecal` overload.** `Event_FootPrint` is the only caller of the 8-argument `ProjectDecal` (binary: every direct call in the `.so`). The stock callers (`idEntityFx::Run`, `idProjectile::DefaultDamageEffect`, `idWeapon::Event_Melee`, `idFuncSplat::Event_Splat`, `idExplodingBarrel::ExplodingEffects`, `idGameLocal::BloodSplat`) still call the stock 7-argument one. It was found in issue #26 and exported afterwards: `scripts/targets.txt` names it with its entry point (`idGameLocal::ProjectDecal @ 00101c80`), because a plain name would also export the stock overload. Its body is the stock one (0xf0db0) with `decalWinding` passed in, compared instruction by instruction (see the comment above the definition). `Event_FootPrint` passes an angle, so a print is turned to the actor's yaw, not at random (unless the angle is exactly 0), and the scaled corners give it its shape. `g_decals 0` turns footprints off, as it does every decal.
- **`idActor` event table, entry 42.** After `EV_FootPrint`, `idActor::eventCallbacks` has `{ EV_Remove, idClass::Event_Remove }`, which stock `Actor.cpp` does not have. No new function comes with it, so it is not in any group's scope. Recorded as a lead: some edit made `remove` on actors go straight to `idClass::Event_Remove`. Not checked further.
- **Ported by spec #30: port choices.**
  - Both footprint leads are ported: a new `FC_FOOTPRINT` anim frame command (`anim/Anim.h`, `anim/Anim_Blend.cpp`) and the `footprint_on_sound` call in `PlayFootStepSound`. For the UNCERTAIN `frameCommand_t` fields, the joint goes in `index` (like `FC_FIREMISSILEATTARGET`, turned back into a name at call time) and the side in `string`.
  - `footprintRight` is left uninitialized, as in the binary (so the first print's side may be arbitrary). `footprintEndTime` 0 and `footprintSurfaceType` -1 are set in the constructor, as the binary does.
  - The extra `{ EV_Remove, idClass::Event_Remove }` entry is ported. It routes to the handler `idActor` already inherits, so it changes nothing observable.
- **`setProj` behavior.** `projectileDict` is the stock member that stock `Event_LaunchProjectiles` / `Event_CreateProjectile` spawn from. In stock, `GetWeaponDef` (weapon change) and `Restore` (loading a savegame) refill it from the weapon's `def_projectile`. So `setProj` lasts only until then, which fits `weap_disable()` repeating it once a second. Not checked in this build's `GetWeaponDef` / `Restore`.
- **`spawnDict` compared to stock `spawn`.** Stock `idThread::Event_Spawn` sets `"classname"` in `spawnArgs` and spawns from `spawnArgs` itself. `Event_SpawnDict` copies into a local `idDict` instead, passes `false` as `SpawnEntityDef`'s third argument (stock `setDefaults`, which the stock body never reads; UNCERTAIN whether this build's does), and clears both dicts after. Like stock, `ent` is not initialized before `SpawnEntityDef`, which sets it.
- **Callees (check 1).** Named in the code: `GetPhysics`, `va`, `GetFloat` (the 3-argument, non-inline one), `ToAngles`, `GetVector`, `GetJointHandle`, `GetJointWorldTransform`, `ProjectDecal` (`Event_FootPrint`). `FindEntityDef` and `idDict::operator=` (`Event_SetProj`). `FindEntityDefDict`, `Copy`, `SpawnEntityDef`, `ReturnEntity` and `Clear` (`Event_SpawnDict`). From stock inline code, on `allowlist.tsv` as `stock-inline`: `idDict::FindKey` and `__strtod_internal` in `Event_FootPrint` (`idDict::GetFloat( key, default )` and `GetString`), and `idHashIndex::Init` / `Free` and `operator new[]` / `delete[]` in `Event_SpawnDict` (the local `idDict`'s constructor and destructor). The vtable calls `HasGroundContacts`, `GetOrigin` and `idRenderWorld::Trace` are indirect, which check 1 does not see. `ProjectDecal` makes no direct call (the PIC thunk and `_Unwind_Resume` are never checked): `g_decals.GetBool()`, `random.RandomFloat()`, `idMath::SinCos16`, `Normalize`, `NormalVectors` and the `idFixedWinding` code are inline, and `declManager->FindMaterial`, `gameRenderWorld->ProjectDecalOntoWorld` and the winding's `ReAllocate` (in `operator+=`) are vtable calls.
- **Literals (check 2).** `Event_FootPrint` reads 18 strings and the floats 8.0 (an immediate, three times: trace radius and both decal depths), 1.0 (immediate, `axis[ 2 ].z`), -1.0 (immediate, both `dir.z`), 12.0 and -12.0 (`.rodata`). All appear in the code. 0.5 and 1.5 are the Newton step of `idMath::InvSqrt` inside the two inline `idVec3::Normalize` calls: on `literal-allowlist.tsv` as `stock-inline`. `Event_SetProj` and `Event_SpawnDict` read no literals. `ProjectDecal` reads 0.5 (`size *= 0.5f`, `depth * 0.5f`) and 1.0 (immediates: the `idVec2` texture coordinates), both in the code. The rest come from stock inline code, on `literal-allowlist.tsv` as `stock-inline`: 3.0517578e-05 (1 / 32768, `idRandom::RandomFloat`), -1.0 and nine polynomial coefficients of `idMath::SinCos16` (its tenth, 0.5, is also in the code), and 1.5 (`idMath::InvSqrt`, in `Normalize` and `NormalVectors`). The event names and formats are read by static initializers, which are not covered functions, so check 2 does not cover them. They were read from the disassembly.
- **Compile (check 3).** The header and implementation compile with g++ 12 `-m32` against stock DOOM-3 GPL a9c49da. The `idGameLocal`, `idActor`, `idWeapon` and `idThread` partial declarations are spliced into scratch copies of `game/Game_local.h`, `game/Actor.h`, `game/Weapon.h` and `game/script/Script_Thread.h`. The event-table lines are comments because the stock `CLASS_DECLARATION`s cannot be repeated. The check proves the code is well-formed only.
- **Offsets checked against a g++ 12 `-m32` build of the stock headers** (the build is Itanium-ABI like the binary's GCC 3): `idEntity::spawnArgs` +0x64, `idAnimatedEntity::animator` +0x27c, `idActor::viewAxis` +0x8dc, `sizeof( idActor )` 0xf68, `idWeapon::projectileDict` +0x798, `idThread::spawnArgs` +0x1b40, `idGameLocal::random` +0x8fe0 (binary +0x8ff0: 0x10 further on, see `trails.md`), `idDeclEntityDef::dict` +0x8, `modelTrace_t::material` +0x1c, `idMaterial::surfaceFlags` +0x64. Vtable offsets (pointer-to-virtual-member values): `idPhysics::HasGroundContacts` +0xdc, `idPhysics::GetOrigin` +0x84, `idRenderWorld::Trace` +0x7c, `idRenderWorld::ProjectDecalOntoWorld` +0x34, `idDeclManager::FindMaterial` +0x60. All match the binary's accesses.
- **Ghidra artifacts.**
  - `Event_FootPrint`: `fStack_14 = 1.137217e-39` is the PIC thunk's return address seen as a float. `this + 100` is `spawnArgs`. `idMat3::ToAngles()` shows no arguments: it takes `&viewAxis` (+0x8dc) and a hidden return slot (`angles`, of which `fStack_68` is the yaw). The `iSqrt` table lookups with `0x17c` and the `1.5 - r * r * x * 0.5` steps are the inline `idMath::InvSqrt` in `Normalize`. The `* 0.0` terms are the components of the constant `axis[ 2 ]` = ( 0, 0, 1 ), not folded because x87 math keeps them. The `goto LAB_000c64b6` maze is the `mtr` selection above.
  - `Event_SpawnDict`: `local_14 = 0x24dc0b` is the PIC thunk's return address, not an initial value of `ent`. The `SpawnEntityDef` call shows `gameLocal` as `(idDict *)`, `dict` as `(idEntity **)` and `SUB41( &local_14, 0 )` for the bool: really `( &gameLocal, dict, &ent, false )`. The resize loop over `local_34` is `idList::SetGranularity( 16 )` in the inline `idDict` constructor. The landing pads (0x23ddd8-0x23de14) are the exception cleanup of `dict`. Not code.
  - `Event_SetProj`: `iVar1 + 8` is `&projectileDef->dict`.
  - `ProjectDecal`: `local_59c = PTR_vtable + 8` and `local_594 = &local_58c` are the inline `idFixedWinding` constructor (vtable, then `p` = the 64-point stack buffer). `this + 0x8ff0` is `random`'s seed (`* 0x10dcd + 1`, `& 0x7fff`). `ROUND( a / TWO_PI )` is `floorf` in `SinCos16`. The two `iSqrt` blocks are `InvSqrt` in `Normalize` and in `NormalVectors`; `local_8c = 1.0` / `local_88 = 0.0` is `NormalVectors`' zero-length branch. The eight "unreachable blocks" Ghidra removed are the four `EnsureAlloc` reallocation paths of `winding +=` (vtable +0xc), reached only when the fixed buffer is full.
- **Open questions.** Whether `footprintRight` really starts uninitialized (so the first footstep's side is arbitrary). Whether the `mtr_footprint_<type>` NULL test was meant to fall back to `mtr_footprint` when the key is missing (it does not). Why `EV_Remove` was added to `idActor`'s table. All need an in-game check or more work in the binary.
