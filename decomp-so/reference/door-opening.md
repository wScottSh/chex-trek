# Door opening (`idPlayer::tryOpen`, `idAI::OpenDoors`, `openDoors`): reconstructed reference

**Provenance:** reconstructed by **Claude Opus 5.5** on 2026-09-24 from the complete Ghidra export `decomp-so/ghidra-full/` of `gamex86.so` (Ghidra 12.1.4, "Non-Returning Functions - Discovered" disabled), enriched export (issue #18: float constants and string literals resolved from `.rodata`). Checks 1-3 pass (issue #24). Check 3 compiles it, 32-bit, against stock DOOM-3 GPL a9c49da. Export files: `idPlayer_tryOpen_0017c420.c`, `idAI_OpenDoors_001ce950.c` and `idAI_Event_OpenDoors_001dc9a0.c`. Facts marked *binary* were read straight from `gamex86.so` (symbol table, vtables, relocations, event tables, disassembly). Reference material only, not original source. The original source does not exist.

Scope (spec #16, issue #24): `idPlayer::tryOpen` and the `g_doorTraceDist` cvar it reads, `idAI::OpenDoors` / `Event_OpenDoors` and the `openDoors` script event (`AI_OpenDoors`). The two halves are grouped by theme only: neither calls the other (Notes). Addresses below are ELF virtual addresses. Ghidra's are `+0x10000`. Stock DOOM-3 GPL source (a9c49da) is referenced, not repeated.

## Header

```cpp
// ---------------------------------------------------------------------------
// idPlayer addition (Player.h; full list: reference/idPlayer-additions.md)
// No new idPlayer members: tryOpen uses only stock ones (viewAngles, spawnArgs of the door).
// UNCERTAIN: where in the idPlayer declaration it sits, and its access level.
// ---------------------------------------------------------------------------
class idPlayer : public idActor {
	// ... stock members ...
public:
	// Bound to the stock "<unused>" IMPULSE_16 (see Notes). The mod's configs bind "e" to _impulse16.
	void					tryOpen( void );
};

// ---------------------------------------------------------------------------
// idAI additions (ai/AI.h)
// UNCERTAIN: access levels. Stock idAI keeps its Event_* handlers protected.
// ---------------------------------------------------------------------------
class idAI : public idActor {
	// ... stock members ...
public:
	void					OpenDoors( idEntity *ent );

	// UNCERTAIN: name. Offset +0x1058 (binary): a new bool right after savedMove, which shifts
	// kickForce from stock 0x1048 to +0x105c (idAI::Spawn stores "kick_force" there). Only
	// stock functions use it: idAI::Spawn reads spawnArgs.GetBool( "canopendoors", "1", ... )
	// into it, and AnimMove / FlyMove / SlideMove call OpenDoors only when it is set (Notes).
	// Check 3 splices it at the end of the stock declaration.
	bool					canOpenDoors;		// +0x1058

	void					Event_OpenDoors( idEntity *ent );
};

// SysCvar.h (defined in SysCvar.cpp, see below). UNCERTAIN whether the extern is in SysCvar.h:
// the cvar's static initializer is SysCvar.cpp's, and stock declares every SysCvar.cpp cvar there.
extern idCVar			g_doorTraceDist;
```

## Implementation

```cpp
// ===========================================================================
// g_doorTraceDist (SysCvar.cpp)
// Built in SysCvar.cpp's static initializer (0x1f2920, right after net_serverDlTable; the idCVar
// constructor is inlined, store of the name @ 0x1fa06c). Stored flags 0x21884 =
// CVAR_ARCHIVE | CVAR_STATIC | CVAR_NETWORKSYNC | CVAR_GAME | CVAR_FLOAT. idCVar::Init adds CVAR_STATIC.
// No min / max (stored 1.0 / -1.0, the idCVar defaults). No completion function.
// ===========================================================================
idCVar g_doorTraceDist( "g_doorTraceDist", "100", CVAR_GAME | CVAR_NETWORKSYNC | CVAR_ARCHIVE | CVAR_FLOAT, "trace distance from player to open doors" );

// ===========================================================================
// idPlayer::tryOpen (Player.cpp)
// ===========================================================================

/*
================
idPlayer::tryOpen

Traces g_doorTraceDist units along the view direction. If the first thing hit is an
idDoor, the door is activated when it is unlocked, or when it is locked with a "requires"
key whose item the player has. Otherwise a "Door Locked" tip names the required item,
or shows the door's "lockedtext" (default "This door is locked.").
================
*/
void idPlayer::tryOpen( void ) {
	trace_t		trace;
	idEntity	*ent;
	idDoor		*door;

	idVec3 start = GetEyePosition();
	// viewAngles is +0x1234 in this build (stock +0x1224; see reference/hud-map.md, Notes).
	// g_doorTraceDist.GetFloat() is internalVar (+0x2c) then floatValue (+0x28).
	idVec3 end = start + viewAngles.ToForward() * g_doorTraceDist.GetFloat();

	// Direct call to idClip::Translation, not the inline TracePoint (which would also compare
	// trace.fraction). gameLocal.clip is +0x2350a8 (stock +0x235098, see reference/trails.md).
	// Content mask 1. UNCERTAIN: written CONTENTS_SOLID or MASK_SOLID (both 1).
	gameLocal.clip.Translation( trace, start, end, NULL, mat3_identity, CONTENTS_SOLID, this );
	ent = gameLocal.GetTraceEntity( trace );
	// ent->IsType() is the inline idClass::IsType: GetType() (vtable +0x0) and the
	// typeNum / lastChild range test against idDoor::Type.
	if ( !ent || !ent->IsType( idDoor::Type ) ) {
		return;
	}
	door = static_cast<idDoor *>( ent );

	// The door's own spawnArgs (+0x64), not idDoor's private requires member.
	// GetString( key, default, idStr & ) is ID_INLINE (idlib/Dict.h): FindKey, then idStr copy or
	// idStr::operator=( default ).
	idStr requires;
	door->spawnArgs.GetString( "requires", "", requires );
	idStr lockedText;
	door->spawnArgs.GetString( "lockedtext", "This door is locked.", lockedText );

	// The binary tests requires.Length() again after RequirementMet returns false (0x16c7b0).
	// RequirementMet takes a const idStr &, so the compiler has to reload len; that is why the
	// test appears twice. One test in source reads the same.
	if ( !door->IsLocked() || ( requires.Length() && gameLocal.RequirementMet( this, requires, 0 ) ) ) {
		// idEventArg type 'e' (0x65): the player is the activator.
		door->ProcessEvent( &EV_Activate, this );
	} else if ( requires.Length() ) {
		// Both are the ID_INLINE idStr members (idlib/Str.h): Insert shifts the text right by 11
		// and copies "You need a " with byte stores (no .rodata string, no NUL), then
		// operator+= (Append) copies " to open this door." from .rodata.
		requires.Insert( "You need a ", 0 );
		requires += " to open this door.";
		ShowTip( "Door Locked", requires, true );
	} else {
		ShowTip( "Door Locked", lockedText, true );
	}
	// ~idStr() of lockedText, then requires (idStr::FreeData, inline in idlib/Str.h).
}

// ===========================================================================
// idAI door opening (AI.cpp / AI_events.cpp)
// ===========================================================================

/*
=====================
idAI::OpenDoors

Uses ent if it is an unlocked idDoor that is not moving. The AI is the activator.
=====================
*/
void idAI::OpenDoors( idEntity *ent ) {
	// ent->IsType() is the inline idClass::IsType (vtable +0x0 GetType, range test on idDoor::Type).
	if ( ent && ent->IsType( idDoor::Type ) ) {
		idDoor *door = static_cast<idDoor *>( ent );
		// IsAtRest is a virtual call, vtable +0x90 (binary: _ZTV6idDoor + 8 + 0x90 holds
		// idEntity::IsAtRest, which idDoor does not override).
		if ( !door->IsLocked() && door->IsAtRest() ) {
			// Direct call: idDoor::Use is not virtual. `other` is the door itself (binary: the
			// same register is passed as `this` and as `other`).
			door->Use( ent, this );
		}
	}
}

// The script event. Binary: AI_events.cpp's static initializer (0x1cfc00) constructs it at
// 0x1d0d5d as idEventDef( "openDoors", "E", 0 ): one entity argument that may be $null_entity
// ('E', D_EVENT_ENTITY_NULL), no return value. The symbol AI_OpenDoors is STB_LOCAL, as the
// stock `const idEventDef AI_*` in AI_events.cpp are (const gives internal linkage).
const idEventDef AI_OpenDoors( "openDoors", "E" );

// Binary: idAI::eventCallbacks (0x3d5ec0) entry 116 = { AI_OpenDoors, idAI::Event_OpenDoors },
// between the stock AI_KickObstacles and AI_GetObstacle entries. So in the stock
// CLASS_DECLARATION( idActor, idAI ) table in AI_events.cpp (not repeated here), after
// EVENT( AI_KickObstacles, idAI::Event_KickObstacles ), the mod added:
//
//	EVENT( AI_OpenDoors,						idAI::Event_OpenDoors )

/*
=====================
idAI::Event_OpenDoors
=====================
*/
void idAI::Event_OpenDoors( idEntity *ent ) {
	OpenDoors( ent );
}
```

## Notes

- **Does the binary link the two halves? No.** `idPlayer::tryOpen` and `idAI::OpenDoors` do not call each other, and nothing calls both. Their only shared callee is `idDoor::IsLocked`.
  - `tryOpen`'s only caller (binary) is `idPlayer::PerformImpulse`, jump-table case 16 (0x16cc53): `IMPULSE_16`, `<unused>` in stock `framework/UsercmdGen.h`. `autoexec.cfg`, `matt.cfg` and `scott.cfg` bind `e` to `_impulse16`. `corvette_notes.txt` (5/23/05): "replaced _opendoor by _impulse16".
  - `OpenDoors`'s callers (binary) are `Event_OpenDoors` and the stock `idAI::AnimMove` (0x1c29a7), `FlyMove` (0x1c3346, 0x1c34ae) and `SlideMove` (0x1c3f5a).
- **The `openDoors` script event, matched to the mod's scripts.** Definition: `idEventDef( "openDoors", "E" )`, one nullable entity argument, no return value (see the implementation block). `script/chex_events.script:2` declares `scriptEvent void openDoors( entity doorEnt );`: the same name, one entity argument and a `void` return. `script/doom_main.script:12` includes that file. The only call is `script/ai_monster_base.script:1353`, in the "blocked by object" branch after `kickObstacles( getObstacle(), force )`: `if( getIntKey( "canopendoors" ) ) { openDoors( getObstacle() ); }`. `getObstacle()` can return `$null_entity`, which `"E"` allows and `OpenDoors` checks for.
- **`idPlayer` members.** `tryOpen` uses no new `idPlayer` members, so none were added to `reference/idPlayer-additions.md`. Its method row was added. No conflicts. `viewAngles` (+0x1234) and `spawnArgs` (+0x64 in the door) are stock members.
- **Edits inside stock functions (out of scope for spec #16, recorded as leads).**
  - `idPlayer::PerformImpulse`: `case IMPULSE_16: tryOpen(); break;` (above). Not checked.
  - `idAI::Spawn` (0x1c99e4): `spawnArgs.GetBool( "canopendoors", "1", <+0x1058> )`, between the stock `"talks"` and `"npc_name"` reads. `corvette_notes.txt` (10/01/05): "AI now also can open doors, key canopendoors defaults to 1".
  - `idAI::AnimMove` (0x1c239a), `FlyMove` (0x1c2e25, 0x1c3317) and `SlideMove` (0x1c3880) test the `+0x1058` byte, and the calls to `OpenDoors` pass the result of `physicsObj.GetSlideMoveEntity()`. In `AnimMove` the pattern is `blockEnt = physicsObj.GetSlideMoveEntity(); if ( canOpenDoors ) OpenDoors( blockEnt );` just before the stock `idMoveable` kick test. So monsters open doors they slide into from C++. The script's `openDoors` call would do the same when the monster is blocked, but only if the entity sets `canopendoors` (below). UNCERTAIN: the exact code in `FlyMove` / `SlideMove`, and whether `canOpenDoors` is saved (not checked).
    - **Ported by spec #42, lead left open.** `AnimMove`/`SlideMove`/`FlyMove` each got one `if ( canOpenDoors ) { OpenDoors( blockEnt ); }` block, matching the single call site this note gives for `SlideMove` (0x1c3f5a) and `AnimMove` (0x1c29a7) - `tools/test-ai-door-open.sh` exercises the `SlideMove` copy directly (a console-spawned monster physically blocked by `sf_923`'s `func_door_1`) and, since the three copies are textually identical, that scenario stands in for `AnimMove` too. `FlyMove`'s two listed addresses (0x1c2e25/0x1c3317 for the `+0x1058` test, 0x1c3346/0x1c34ae for the `OpenDoors` call) were **not** double-ported: only one `if`/call pair was added, right before `FlyMove`'s own kick-obstacles branch (mirroring the other two functions), because no second blocked-movement branch exists in this reconstructed `FlyMove` for a second copy to belong to - the two addresses more likely reflect compiler tail-duplication of the same source line (already flagged UNCERTAIN above) than a second logical call site. No scenario in this repo drives an AAS-flying monster (`MOVETYPE_FLY`) into a closed door, so this reading is unconfirmed either way; flagging it here rather than guessing at a second branch to add.
    - **`canOpenDoors` save/restore: this port's own choice, original binary still uncertain.** The uncertainty above ("whether `canOpenDoors` is saved") is about the *original binary* and remains unchecked. Independent of that, this port's `canOpenDoors` member (`AI.h`) is itself saved/restored like the sibling `af_push_moveables`/`ignore_obstacles` spawnArg-derived bools (`Save`/`Restore` in `AI.cpp`), so a save/restore round-trip can't leave it uninitialized - a deliberate choice for this port, not a claim about the original binary's layout.
  - `g_doorTraceDist`: `corvette_notes.txt` (10/01/05): "g_doorTraceDist cvar to control open door distance". No `.cfg` in this repo sets it.
- **Cross-check against the mod's data** (`def/`, `script/`, `maps/`, `.cfg`).
  - `"requires"`: `maps/e1m1.map`, `maps/e1m1_2.map`, `maps/storage_facility.map` set `"Blue Key"` / `"Red Key"`, so the tip reads "You need a Blue Key to open this door.". `corvette_notes.txt` (7/6/05): "New requires key can be used to specifiy a required item to open the door ... Only works with idPlayer::tryOpen/_impulse16". Stock `idDoor` also reads `"requires"` into its own member for `idDoor::Use`, so `OpenDoors`'s `Use` call checks it against the AI (stock `RequirementMet` returns true for a non-player activator).
  - `"lockedtext"`: `maps/sf_923.map` sets it on three doors ("This door is slimed. Find another route.", "This door is locked.  It can be opened at a console on the bridge.").
  - `"canopendoors"`: only `script/ai_monster_base.script` reads it (`getIntKey`). No file in `def/` or `maps/` sets it. So the C++ default `"1"` applies and monsters open doors from `AnimMove` / `FlyMove` / `SlideMove`, while the script's `openDoors` call never runs: stock `getIntKey` reads a missing key as `"0"`.
- **Behavior.** When the door is locked and the player has the required item, `tryOpen` sends the stock `EV_Activate` to the door with the player as activator. Stock `idDoor::Event_Activate` unlocks a locked door (`Lock( 0 )`) before opening it. The item is not removed (`removeItem` 0). UNCERTAIN: whether this build's `idDoor::Event_Activate` is unchanged from stock (not checked).
- **Callees (check 1).** `tryOpen`: `GetEyePosition`, `ToForward`, `Translation`, `GetTraceEntity`, `IsLocked`, `RequirementMet`, `ProcessEvent`, `ShowTip` and `idStr::operator=` (from `GetString`'s `out = defaultString`) are named in the code. `idDict::FindKey`, `memcpy`, `idStr::ReAllocate` and `idStr::FreeData` come from stock inline code (`idDict::GetString`, `idStr::operator=( const idStr & )`, `Insert`, `Append`, `~idStr`) and are on `allowlist.tsv` as `stock-inline`, one entry per callee. `OpenDoors`: `IsLocked` and `Use`. `IsAtRest` and `GetType` (inside `IsType`) are vtable calls, which check 1 does not see. `Event_OpenDoors`: `OpenDoors`.
- **Literals (check 2).** `tryOpen` reads six strings from `.rodata`: `"requires"`, `"lockedtext"`, `""`, `"This door is locked."`, `" to open this door."` and `"Door Locked"`. All appear verbatim. `"You need a "` is not in `.rodata`: the inline `idStr::Insert` copies it with 11 byte stores (0x16c7f9-0x16c870) and no NUL. The harness accepts it because its bytes are exactly one unbroken run of byte-immediate stores (see `verify.py`). `OpenDoors` and `Event_OpenDoors` read no literals. No function in this group uses a float constant. The strings `"g_doorTraceDist"`, `"100"`, `"trace distance from player to open doors"` and `"openDoors"`, `"E"` are read by static initializers, which are not covered functions, so check 2 does not cover them. They were read from the disassembly.
- **Compile (check 3).** The header and implementation compile with g++ 12 `-m32` against stock DOOM-3 GPL a9c49da. The `idPlayer` and `idAI` partial declarations are spliced into scratch copies of stock `game/Player.h` and `game/ai/AI.h`. The event-table line is a comment because the stock `idAI` `CLASS_DECLARATION` cannot be repeated. The check proves the code is well-formed only.
- **Ghidra artifacts.**
  - Ghidra shows `tryOpen` as `idPlayer::tryOpen(void)` with `this` as `unaff_retaddr`. It is a normal `__thiscall` member: `this` is the first stack argument.
  - `local_130` (the trace length) looks uninitialized in the pseudo-C. It is `g_doorTraceDist.GetFloat()` spilled to the stack (0x16c48f-0x16c4a5).
  - The `try { ... } CatchHandler` comments in `tryOpen` are the exception cleanup of the two `idStr` locals (landing pad 0x16c9b8: two `FreeData`, `_Unwind_Resume`). Not code.
  - `builtin_strncpy( local_6c + sVar8, "You need a ", 0xb )` and the copy loop over `" to open this door."` are the inline `idStr::Insert` and `idStr::Append`.
  - In `OpenDoors`, `(**(code **)(*(int *)param_1 + 0x90))(param_1)` is the virtual `IsAtRest()`.
- **Open questions.** Whether AI door opening is really on by default in game (`canopendoors` defaults to 1 in C++, 0 in the script). Whether `g_doorTraceDist` 100 was tuned for Chex's player size. Both need an in-game check.
