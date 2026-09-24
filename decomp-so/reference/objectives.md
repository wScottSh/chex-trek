# Objectives (`mkObjective`): reconstructed reference

**Provenance:** reconstructed by **Claude Opus 5.5** on 2026-09-24 from the complete Ghidra export `decomp-so/ghidra-full/` of `gamex86.so` (Ghidra 12.1.4, "Non-Returning Functions - Discovered" disabled), enriched export (issue #18: float constants and string literals resolved from `.rodata`). Checks 1-3 pass (issue #21). Export files: `mkObjective_*.c` (10 files), `idPlayer_addObjective_0015e520.c`, `idPlayer_freeObjective_0015d390.c` and `idPlayer_addItemText_0017f990.c`. Facts marked *binary* were read straight from `gamex86.so` (symbol table, vtables, RTTI, relocations, disassembly). Reference material only, not original source. The original source does not exist.

Scope (spec #16, issue #21): the `mkObjective` class, and `idPlayer::addObjective` / `freeObjective` / `addItemText`. In the binary, these three are called only from `mkObjective::AttachToLocalPlayer` / `RemoveFromLocalPlayer` (checked over every function's direct calls). `idPlayer::HudMapLevel`, which `addObjective` calls, belongs to the `hud-map` group (#22) and is only declared here. Addresses below are ELF virtual addresses. Ghidra's are `+0x10000`. Stock DOOM-3 GPL source (a9c49da) is referenced, not repeated.

## Header

```cpp
class mkObjective;

// ---------------------------------------------------------------------------
// mkObjective
// A map objective. Triggering it adds it to the local player's objective list: its image goes
// on the HUD map and the PDA map, its title and description on the PDA. Triggering it again
// removes it (and, with "remove" "1", the entity). The entityDef is trigger_objective
// (def/func_envshot.def).
//
// Base class: idEntity. Evidence (binary):
//   1. mkObjective::Type is built with superclass name "idEntity": the static initializer at
//      0x18f1d0 loads "idEntity" at 0x18f986 into [esp+0x44], reloads it into edi at 0x191081,
//      and passes edi as the superclass name to idTypeInfo::idTypeInfo @ 0x191365, next to
//      "mkObjective". (The same initializer builds idCustomUI and idTarget_EndLevelGUI, so the
//      class lives in Target.cpp. UNCERTAIN: file name, as in custom-ui.md.)
//   2. RTTI: _ZTI11mkObjective (0x3cc70c) is a __si_class_type_info whose base is _ZTI8idEntity.
//   3. CreateInstance calls idEntity's base constructor (C2), then stores this class's vtable.
//      Both destructor clones store this class's vtable, free the three idStr members, then call
//      idEntity's base destructor.
//   4. Vtable _ZTV11mkObjective (59 words, 0x3ca720) matches _ZTV8idEntity word for word, except
//      for the type and the two destructors: no new virtuals, no overrides.
//   5. Its first member is at this+0x27c = sizeof( idEntity ) (the stock layout; idCustomUI's
//      first member is there too). sizeof = 0x2e8: CreateInstance allocates 0x2e8 bytes.
// ---------------------------------------------------------------------------
class mkObjective : public idEntity {
public:
	CLASS_PROTOTYPE( mkObjective );

	// UNCERTAIN: whether ~mkObjective() was declared in the source. Both clones (D1 0x199330,
	// D0 0x199280) are weak symbols that only destroy the idStr members, which is what a
	// compiler-generated destructor gives. Declaring an empty one here behaves the same.
	// No constructor is declared: the binary has no mkObjective constructor symbol, and
	// CreateInstance only runs idEntity's and the idStr members' (inline) constructors.
							~mkObjective( void );

	void					Spawn( void );
	void					Save( idSaveGame *savefile ) const;
	void					Restore( idRestoreGame *savefile );

	// UNCERTAIN: access level (public/protected/private) of everything below, except mapLevel:
	// idPlayer::updateMapUI (hud-map group) reads it, so it was public (or idPlayer a friend).
	// UNCERTAIN: member names. Only offsets and types are known.
	int						objectiveNum;	// +0x27c  number addObjective gave (1-5), -1 if the list was full
	idStr					image;			// +0x280  "image": map icon material (map_obj%d)
	idStr					title;			// +0x2a0  "title": PDA title (map_obj%d_tle)
	int						mapLevel;		// +0x2c0  HUD map level of the origin (idPlayer::HudMapLevel)
	idStr					description;	// +0x2c4  "description": PDA text (map_obj%d_txt)
	bool					active;			// +0x2e4  true while on the player's list. Saved.

	bool					AttachToLocalPlayer( bool showMessage );
	void					RemoveFromLocalPlayer( bool showMessage );

	void					Event_Activate( idEntity *activator );
};

// ---------------------------------------------------------------------------
// idPlayer additions used by this feature (full list: reference/idPlayer-additions.md)
// UNCERTAIN: where in the idPlayer declaration these sit. Only the offsets are known.
// ---------------------------------------------------------------------------

class idPlayer : public idActor {
	// ... stock members ...
public:
	// Size of objectives. The binary's only trace of the name is the warning text
	// "MAX_OBJS reached!". The value: addObjective stops at 5, updateMapUI loops over 5, and the
	// GUIs have map_obj1 ... map_obj5. UNCERTAIN: its form and place. More likely a #define in
	// Player.h; written as a class constant here because check 3 compiles this header block's
	// own lines after the stock headers, where a #define would come too late for idPlayer.
	static const int		MAX_OBJS = 5;

	int						addObjective( mkObjective *obj, const idVec3 &origin, int &level );
	void					freeObjective( int num );
	void					addItemText( const idItemInfo &info );

	// Declared here for addObjective's call. Its body belongs to the hud-map group (#22).
	// Return type int (binary: the result is stored through addObjective's int &).
	int						HudMapLevel( const idVec3 *pos );

	mkObjective *			objectives[ MAX_OBJS ];	// +0x1ef4 .. +0x1f07  slot i shows as map_obj<i+1>
	int						nextObjective;			// +0x1f08  first slot addObjective tries
};
```

## Implementation

```cpp
// ===========================================================================
// mkObjective (Target.cpp; see the header's base-class evidence, item 1)
// ===========================================================================

// Event table (binary: mkObjective::eventCallbacks @ 0x3d5aa4 =
// { EV_Activate, Event_Activate }, { NULL }).
CLASS_DECLARATION( idEntity, mkObjective )
	EVENT( EV_Activate,		mkObjective::Event_Activate )
END_CLASS

/*
================
mkObjective::~mkObjective

Possibly not written in the source (see header).
================
*/
mkObjective::~mkObjective( void ) {
	// Nothing of its own. Both clones reset the vtable pointer to this class's, run ~idStr() on
	// description, title and image (idStr::FreeData, inlined), and run idEntity::~idEntity().
	// The D0 clone then frees `this`.
}

/*
================
mkObjective::Spawn
================
*/
void mkObjective::Spawn( void ) {
	// A missing title or description falls back to the key's own name.
	spawnArgs.GetString( "title", "title", title );
	spawnArgs.GetString( "description", "description", description );
	spawnArgs.GetString( "image", "", image );
	active = false;
	// objectiveNum and mapLevel are not set here (nor in a constructor): only by AttachToLocalPlayer.
}

/*
================
mkObjective::Save
================
*/
void mkObjective::Save( idSaveGame *savefile ) const {
	savefile->WriteString( title );
	savefile->WriteString( description );
	savefile->WriteString( image );
	savefile->WriteBool( active );
	// objectiveNum and mapLevel are not saved: Restore re-attaches, which sets both again.
}

/*
================
mkObjective::Restore
================
*/
void mkObjective::Restore( idRestoreGame *savefile ) {
	savefile->ReadString( title );
	savefile->ReadString( description );
	savefile->ReadString( image );
	savefile->ReadBool( active );

	// The player's objective list is not saved. If this objective was on it, put it back:
	// half a second on, activate itself with itself as the activator, which re-attaches it
	// without the "addmsg" message (see Event_Activate).
	if ( active ) {
		PostEventMS( &EV_Activate, 500, this );
	}
}

/*
================
mkObjective::AttachToLocalPlayer

Adds this objective to the local player's list and shows it on the HUD and PDA. With
showMessage, also shows the "addmsg" text as an item pickup message. Returns true if added.
================
*/
bool mkObjective::AttachToLocalPlayer( bool showMessage ) {
	idItemInfo			info;
	idPlayer *			player;
	idUserInterface *	pda;
	idUserInterface *	hud;

	player = gameLocal.GetLocalPlayer();
	// The two GUI pointers are read once (binary: kept in registers across the virtual calls).
	if ( !player || ( pda = player->objectiveSystem ) == NULL || ( hud = player->hud ) == NULL ) {
		return false;
	}

	objectiveNum = player->addObjective( this, GetPhysics()->GetOrigin(), mapLevel );
	if ( objectiveNum == -1 ) {
		return false;
	}

	// idUserInterface vtable: +0x3c SetStateBool, +0x38 SetStateString.
	pda->SetStateBool( va( "map_obj%d_v", objectiveNum ), true );
	hud->SetStateBool( va( "map_obj%d_v", objectiveNum ), true );
	pda->SetStateString( va( "map_obj%d", objectiveNum ), image );
	hud->SetStateString( va( "map_obj%d", objectiveNum ), image );
	pda->SetStateString( va( "map_obj%d_txt", objectiveNum ), description );
	pda->SetStateString( va( "map_obj%d_tle", objectiveNum ), title );

	// The message has no icon (info.icon stays empty).
	if ( showMessage && spawnArgs.GetString( "addmsg", "", info.name ) ) {
		player->addItemText( info );
	}
	return true;
}

/*
================
mkObjective::RemoveFromLocalPlayer

Takes this objective off the local player's list and hides it on the HUD and PDA. With
showMessage, also shows the "rmmsg" text as an item pickup message.
================
*/
void mkObjective::RemoveFromLocalPlayer( bool showMessage ) {
	idItemInfo			info;
	idPlayer *			player;
	idUserInterface *	pda;
	idUserInterface *	hud;

	player = gameLocal.GetLocalPlayer();
	if ( !player || ( pda = player->objectiveSystem ) == NULL || ( hud = player->hud ) == NULL ) {
		return;
	}

	player->freeObjective( objectiveNum );
	pda->SetStateBool( va( "map_obj%d_v", objectiveNum ), false );
	hud->SetStateBool( va( "map_obj%d_v", objectiveNum ), false );

	if ( showMessage && spawnArgs.GetString( "rmmsg", "", info.name ) ) {
		player->addItemText( info );
	}
}

/*
================
mkObjective::Event_Activate

Off the list: attach, with the message. On the list: remove, with the message, and with
"remove" also remove the entity. Activated by itself (Restore) while on the list: attach
again, without the message.
================
*/
void mkObjective::Event_Activate( idEntity *activator ) {
	if ( !active || activator == this ) {
		active = AttachToLocalPlayer( !active );
		return;
	}
	RemoveFromLocalPlayer( true );
	active = false;
	// UNCERTAIN: GetBool or GetInt. Both compile to atoi( GetString( key, "0" ) ) != 0 here.
	if ( spawnArgs.GetBool( "remove", "0" ) ) {
		ProcessEvent( &EV_Remove );
	}
}

// ===========================================================================
// idPlayer additions (Player.cpp)
// ===========================================================================

/*
================
idPlayer::addObjective

Puts obj in the first free slot from nextObjective on, and sets level to the HUD map level of
origin. Returns the objective's number: its slot + 1 (the N of the GUI's map_objN). Returns -1
if no slot from nextObjective to the end is free: the search does not wrap around.
================
*/
int idPlayer::addObjective( mkObjective *obj, const idVec3 &origin, int &level ) {
	// UNCERTAIN: the loop's form. The binary tests nextObjective with equality (cmp 5, je/jne),
	// before the first slot and after each increment, and stores it back on every step.
	while ( nextObjective != MAX_OBJS ) {
		if ( objectives[ nextObjective ] == NULL ) {
			objectives[ nextObjective ] = obj;
			nextObjective++;
			level = HudMapLevel( &origin );
			return nextObjective;
		}
		nextObjective++;
	}
	gameLocal.Warning( "MAX_OBJS reached!" );
	return -1;
}

/*
================
idPlayer::freeObjective

num is the objective's number (slot + 1), as addObjective returned it.
================
*/
void idPlayer::freeObjective( int num ) {
	objectives[ num - 1 ] = NULL;		// +0x1ef0 + num * 4
	// As in the binary: the next search starts at slot num, after the freed slot (see Notes).
	nextObjective = num;
}

/*
================
idPlayer::addItemText

Queues a text (and icon) in the item pickup list, the way stock item pickups are shown, and
shows the icon on the HUD at once.
================
*/
void idPlayer::addItemText( const idItemInfo &info ) {
	inventory.pickupItemNames.Append( info );		// +0x1404
	if ( hud ) {
		hud->SetStateString( "itemicon", info.icon );
		hud->HandleNamedEvent( "invPickup" );		// idUserInterface vtable +0x24
	}
}
```

## Notes

- **Base class and names agree between `mkObjective` and `idPlayer`.** `mkObjective` derives from `idEntity` (evidence in the header). `addObjective` fills the objective's `mapLevel` (+0x2c0) through its `int &` argument, and its return value becomes `objectiveNum` (+0x27c), which `freeObjective` takes back. `idPlayer::objectives` (+0x1ef4) holds `mkObjective *`: `updateMapUI` (hud-map, #22) reads `objectives[ i ]->mapLevel` (+0x2c0) and the objective's origin from it (not reconstructed here). The members are added to `reference/idPlayer-additions.md`.
- **Numbering.** An objective's number is its slot + 1 (1-5), and the GUI variables use it: `map_obj1` ... `map_obj5`. The GUIs have exactly these five: `guis/hud.gui` (HUD map: `map_objN`, `_v`, `_x`, `_y`, `_c`), `guis/pda.gui` and `guis/pda_chex.gui` (PDA map, plus `_tle` and `_txt`). This group sets `_v` on both GUIs, `map_objN` (the image) on both, and `_txt` / `_tle` on the PDA only, matching where the GUIs read them. `_x`, `_y` and `_c` are set by `idPlayer::updateMapUI` (hud-map, #22).
- **GUIs.** `pda` is the stock `idPlayer::objectiveSystem` (+0x142c) and `hud` the stock `idPlayer::hud` (+0x1428). Evidence (binary): the stock `idPlayer::HideTip` calls `HandleNamedEvent` on +0x1428 (stock: `hud->HandleNamedEvent( "tipWindowDown" )`), and the stock `idPlayer::TogglePDA` uses +0x142c with `objectiveSystemOpen` at +0x1430, the stock member order. `inventory.pickupItemNames` is +0x1404: the stock `idInventory::AddPickupName` uses the list at inventory+0x154, and the stock `idPlayer::UpdateHud` reads +0x1404 next to `hud`. These stock members are 0x14 bytes further on than in a GCC 12 `-m32` build of the stock headers (hud +0x1414, objectiveSystem +0x1418, pickupItemNames +0x13f0, inventory +0x12a0, pickupItemNames inventory+0x150). So this build's `idPlayer` / `idInventory` differ from stock a9c49da before them. Not examined (edits inside stock declarations are out of scope).
- **spawnArgs, cross-checked with `def/` and `maps/`.**
  - Entity: `trigger_objective` (`def/func_envshot.def`, `"spawnclass" "mkObjective"`). Its `editor_var`s are exactly the six keys the binary reads: `description`, `title`, `image` (`Spawn`), `remove` (`Event_Activate`), `addmsg` (`AttachToLocalPlayer`), `rmmsg` (`RemoveFromLocalPlayer`).
  - Maps: only `maps/sf_923.map` (and its backup `sf_923.bak`) has `trigger_objective` entities: `trigger_objective_1` ("Acquire a weapon") and `trigger_objective_2` ("Investigate"). Both set `title`, `description`, `image` (`textures/chex/guis/map_investigate`), `addmsg` ("New Objective") and `remove` "1". Only `trigger_objective_1` sets `rmmsg` ("Objective Complete"), so `trigger_objective_2` goes away without a message.
  - Triggers: `trigger_once_6` targets both (they are added). `moveable_item_pistol_1` (picking up the weapon) targets `trigger_objective_1`, and `trigger_once_9` (at the hangar) `trigger_objective_2`: the second trigger removes each.
  - Scripts: no file in `script/` names `trigger_objective`, `mkObjective`, `addmsg` or `rmmsg`. Objectives are driven only by map targets.
  - Defaults: missing `title` / `description` give the literal texts "title" / "description". Missing `image`, `addmsg`, `rmmsg` give "" (no message for the last two). Missing `remove` gives "0".
- **Messages.** `addItemText` appends to `inventory.pickupItemNames`, the stock pickup-message queue, with an empty icon. It then sets the HUD's `itemicon` to that empty icon and fires `invPickup`. In the mod's current `guis/hud.gui`, both `onNamedEvent invPickup` and the `gui::itemicon` window are commented out (lines 9 and 729). They are live in `guis/hud_old.gui`. How the queued text itself is shown (stock `idPlayer::UpdateHud`) was not checked.
- **Stock-inline callees (check 1 allow-list, `stock-inline`).** `idDict::FindKey`, `idStr::ReAllocate` and `memcpy` inside `spawnArgs.GetString( key, default, idStr & )` (`Spawn`, `AttachToLocalPlayer`, `RemoveFromLocalPlayer`); `idDict::FindKey` and `__strtol_internal` inside `spawnArgs.GetBool` (`Event_Activate`); `idStr::FreeData` inside the implicit `~idItemInfo()` of the local `info` and inside the members' `~idStr()` in the destructor clones; `idList<idItemInfo>::Resize`, `idStr::ReAllocate` and `memcpy` inside `idList::Append` and `idItemInfo`'s implicit `operator=` (`addItemText`). Each is on `verify/allowlist.tsv` for the exact function, with the stock function named.
- **Literals (check 2).** Every string the group's functions read from `.rodata` appears verbatim. None of them reads a float constant. The 500 ms delay in `Restore` is an integer.
- **Compile (check 3).** Compiles with g++ 12 `-m32` against stock DOOM-3 GPL a9c49da. The `idPlayer` partial declaration is spliced into a scratch copy of `game/Player.h`. `class mkObjective;` is a top-level forward declaration, compiled before the stock game headers, because `idPlayer::objectives` points to it. `MAX_OBJS` is an `idPlayer` class constant for the same reason (see its comment).
- **Vtable offsets** (`idUserInterface`: `SetStateString` +0x38, `SetStateBool` +0x3c, `HandleNamedEvent` +0x24; `idPhysics::GetOrigin` +0x84 with id 0) were matched with a GCC 12 `-m32` build of the stock headers (pointer-to-virtual-member values), which uses the same Itanium vtable layout as the binary's GCC 3.
- **Edits inside stock functions (out of scope for spec #16, recorded as leads).**
  - Both `idPlayer` constructors set `objectives[ 0..4 ]` to NULL (C2 stores at +0x1ef4 and +0x1ef8 ... +0x1f04, 0x170edb-0x170f51) and `nextObjective` to 0 (0x170f70). `idPlayer::Init` also sets `nextObjective` to 0 (0x16acd1).
  - A scan of all code for `[reg + disp]` operands in +0x1ef0..+0x1f08 found no other users: `addObjective`, `freeObjective`, `updateMapUI`, `Init` and the constructors. So `idPlayer::Save` / `Restore` do not save the list (indexed forms with other bases were not scanned).
- **Ghidra artifacts.**
  - `CreateInstance` types the new object `idEntity *`. The stores after `idEntity::idEntity` are the three inline `idStr` constructors (`len` 0, `data` = `baseBuffer`, `alloced` 0x14 = `STR_ALLOC_BASE`, `baseBuffer[0]` 0). The D0 destructor passes a stray `in_stack_ffffffe8` to `operator_delete` (really `idClass::operator delete( this )`).
  - `this + 100` is `spawnArgs` (+0x64). In `Spawn`, `AttachToLocalPlayer` and `RemoveFromLocalPlayer`, the `FindKey` / `ReAllocate` / `memcpy` runs are the inlined `idDict::GetString( key, default, idStr & )`.
  - In `AttachToLocalPlayer` / `RemoveFromLocalPlayer`, `local_50` ... `local_24` are the two `idStr`s of the local `idItemInfo` (`name` at `local_50`, `icon` at `local_30`). The function returns `bool`, not `undefined4`, and the `goto LAB_001a3982` is the shared exit that destroys them.
  - `Event_Activate`: `(bool)((byte)this[0x2e4] ^ 1)` is `!active`.
  - `addObjective`: `piVar3` walks `objectives[]` alongside the index; it is the same loop.
  - `GetType`: the `catch() { ... }` comments are not code.
- **Open questions (binary behavior, need an in-game check).**
  - `freeObjective( num )` clears slot `num - 1` but sets `nextObjective` to `num`, so the freed slot is not searched again, and `addObjective` never wraps around. Each slot is therefore used about once per player spawn: after five objectives, or after freeing the last slot, every further `addObjective` warns "MAX_OBJS reached!" and fails. Possibly meant as `num - 1`. The mod's one map with objectives (`sf_923`) uses two.
  - When `AttachToLocalPlayer` fails (list full, or no local player / GUIs), `Event_Activate` stores `false` in `active`, and `objectiveNum` keeps -1 (list full) or its old value.
  - After a load, `Restore` re-attaches after 500 ms. A trigger in those 500 ms (with `active` already true) would take the remove path before the objective is back on the list, calling `freeObjective( objectiveNum )` with an `objectiveNum` that was neither saved nor set since the load.
  - Objectives are re-added in the order their `Restore` events fire, so after a load an objective may get a different number (and map icon slot) than before.
