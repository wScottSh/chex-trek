# Custom UI (`idCustomUI`): reconstructed reference

**Provenance:** reconstructed by **Claude Opus 5.5** on 2026-09-24 from the complete Ghidra export `decomp-so/ghidra-full/` of `gamex86.so` (Ghidra 12.1.4, "Non-Returning Functions - Discovered" disabled). Export files: `idCustomUI_*.c` (13 files), `idPlayer_useCustomUI_0015d300.c`, `idPlayer_clearCustomUI_0015d320.c` and `idCmdSystem_ArgCompletion_GuiName_00183a40.c`. Facts marked *binary* were read straight from `gamex86.so` (symbol table, vtables, RTTI, relocations, disassembly). Reference material only, not original source. The original source does not exist.

Scope (spec #16, issue #17): the `idCustomUI` class, `idPlayer::useCustomUI` / `clearCustomUI`, `idCmdSystem::ArgCompletion_GuiName` and the `g_PDA` cvar that registers it. Addresses below are ELF virtual addresses. Ghidra's are `+0x10000`. Stock DOOM-3 GPL source (a9c49da) is referenced, not repeated.

## Header

```cpp
// ---------------------------------------------------------------------------
// idCustomUI
// An entity that shows a GUI to the local player and routes that GUI's commands
// back to itself. Abstract. Its one subclass in the binary is idTarget_EndLevelGUI.
//
// Base class: idEntity. Evidence (binary):
//   1. idCustomUI::Type is built with superclass name "idEntity": the static initializer
//      at 0x18f1d0 passes "idCustomUI" and "idEntity" to idTypeInfo::idTypeInfo (call @ 0x191119).
//   2. RTTI: _ZTI10idCustomUI is a __si_class_type_info whose base is _ZTI8idEntity.
//   3. Both constructor clones (C1 0x18dd60, C2 0x18ddb0) call idEntity's base constructor first.
//      Both destructor clones (D0 0x199100, D1 0x199150) end in idEntity's base destructor.
//   4. Vtable _ZTV10idCustomUI (60 slots) matches _ZTV8idEntity (59 slots) slot for slot,
//      except for the idCustomUI overrides (type, destructors) and one new slot at the end.
//   5. Its first member is at this+0x27c, and sizeof(idEntity) in this build is 0x27c
//      (stock idTarget::CreateInstance @ 0x18de90 allocates 0x27c for an idTarget, which adds
//      no members to idEntity).
// Abstract: CreateInstance calls gameLocal.Error( "Cannot instanciate abstract class %s.",
//   "idCustomUI" ). That is stock ABSTRACT_DECLARATION, so ABSTRACT_PROTOTYPE is used here.
// ---------------------------------------------------------------------------
class idCustomUI : public idEntity {
public:
	ABSTRACT_PROTOTYPE( idCustomUI );

							idCustomUI( void );
	// UNCERTAIN: whether ~idCustomUI() was declared in the source. The binary has D0/D1 clones
	// (vtable slots 3/4) with an empty body, which a compiler-generated destructor also produces.

	void					Save( idSaveGame *savefile ) const;
	void					Restore( idRestoreGame *savefile );

	void					setGUI( const char *guiName );
	void					RegisterGUI( void );
	void					UnregisterGUI( void );

	// New virtual: vtable slot 59, the one slot idEntity does not have. The stock
	// idPlayer::HandleSingleGuiCommand calls it through the vtable (call [vptr+0xe4] @ 0x16db8c).
	virtual bool			HandleCustomGUICommand( idEntity *entityGui, idToken *token );

	// UNCERTAIN: access level (public/protected) of everything below. The binary does not record it.
	// UNCERTAIN: member names. Only offsets and types are known.
	idUserInterface *		gui;				// +0x27c  written by setGUI, passed to idPlayer::useCustomUI
	bool					registered;			// +0x280  true while the local player has this GUI up
	// sizeof(idCustomUI) is at least 0x281. UNCERTAIN: 0x284 with normal 4-byte padding.

private:
	void					Event_Hide( void );	// replaces idEntity::Event_Hide for EV_Hide
};

// ---------------------------------------------------------------------------
// idPlayer additions used by this feature (full list: reference/idPlayer-additions.md)
// UNCERTAIN: where in the idPlayer declaration these sit. Only the offsets are known.
// ---------------------------------------------------------------------------
class idPlayer : public idActor {
	// ... stock members ...
public:
	void					useCustomUI( idUserInterface *ui, idCustomUI *uiEntity );
	void					clearCustomUI( void );

	idCustomUI *			customUIEntity;		// +0x1f0c
	idUserInterface *		customUI;			// +0x1f10
};

// ---------------------------------------------------------------------------
// idCmdSystem addition (framework/CmdSystem.h, next to the stock ArgCompletion_MapName etc.)
// The symbol is STB_WEAK (binary), which fits an ID_INLINE body in the header, as the stock
// completion helpers have.
// ---------------------------------------------------------------------------
class idCmdSystem {
	// ... stock members ...
	static void			ArgCompletion_GuiName( const idCmdArgs &args, void(*callback)( const char *s ) );
};

// Player.cpp global (defined below). UNCERTAIN whether an extern was also added to a header.
extern idCVar			g_PDA;
```

## Implementation

```cpp
// ===========================================================================
// idCustomUI
// The class's code sits between idTarget_* code in the binary and shares its static initializer
// (0x18f1d0) with them, so it was probably in Target.cpp. UNCERTAIN: file name.
// ===========================================================================

// Event table (binary: idCustomUI::eventCallbacks @ 0x3d5a64 = { EV_Hide, Event_Hide }, { NULL }).
// EV_Hide is the stock "hide" event from Entity.cpp. No new event is defined.
ABSTRACT_DECLARATION( idEntity, idCustomUI )
	EVENT( EV_Hide,		idCustomUI::Event_Hide )
END_CLASS

/*
================
idCustomUI::idCustomUI
================
*/
idCustomUI::idCustomUI( void ) {
	// Base constructor idEntity::idEntity() runs first (C1 and C2 both call it).
	gui			= NULL;
	registered	= false;
}

/*
================
idCustomUI::~idCustomUI

Not written in the source, or empty (see header).
================
*/
idCustomUI::~idCustomUI( void ) {
	// Nothing of its own. Both clones only reset the vtable pointer and run the base
	// destructor idEntity::~idEntity(). The D0 clone then frees `this`.
}

/*
================
idCustomUI::Save
================
*/
void idCustomUI::Save( idSaveGame *savefile ) const {
	savefile->WriteUserInterface( gui, false );
	savefile->WriteBool( registered );
}

/*
================
idCustomUI::Restore
================
*/
void idCustomUI::Restore( idRestoreGame *savefile ) {
	savefile->ReadUserInterface( gui );
	savefile->ReadBool( registered );
	if ( registered ) {
		RegisterGUI();
	}
}

/*
================
idCustomUI::setGUI

An empty name keeps the current gui. There is no NULL check on guiName.
================
*/
void idCustomUI::setGUI( const char *guiName ) {
	if ( guiName[ 0 ] != '\0' ) {
		// uiManager vtable +0x38 = FindGui( qpath, autoLoad, needUnique, forceUnique )
		gui = uiManager->FindGui( guiName, true, false, true );
	}
	if ( gui ) {
		// idUserInterface vtable +0x5c = Activate( activate, time ). gameLocal+0x251884 is
		// gameLocal.time: stock idEvent::Schedule reads the same offset for gameLocal.time.
		gui->Activate( true, gameLocal.time );
		return;
	}
	common->Warning( "idCustomUI::setGUI, set GUI failed" );		// idCommon vtable +0x50 = Warning
}

/*
================
idCustomUI::RegisterGUI

Gives this GUI to the local player, which then shows it (idPlayer::ActiveGui returns it)
and routes its commands back here.
================
*/
void idCustomUI::RegisterGUI( void ) {
	idPlayer *player = gameLocal.GetLocalPlayer();
	if ( player && gui ) {
		registered = true;
		player->useCustomUI( gui, this );
	}
}

/*
================
idCustomUI::UnregisterGUI
================
*/
void idCustomUI::UnregisterGUI( void ) {
	idPlayer *player = gameLocal.GetLocalPlayer();
	if ( player ) {
		player->clearCustomUI();
		registered = false;
	}
	if ( gui ) {
		gui->Activate( false, gameLocal.time );
	}
}

/*
================
idCustomUI::HandleCustomGUICommand

Handles the "unregister" GUI command. Returns true if the command was handled.
entityGui is not used.
================
*/
bool idCustomUI::HandleCustomGUICommand( idEntity *entityGui, idToken *token ) {
	// The binary calls the static idStr::Icmp( token->data, "unregister" ), which is what the
	// inline member idStr::Icmp( const char * ) compiles to.
	if ( token->Icmp( "unregister" ) == 0 ) {
		UnregisterGUI();
		return true;
	}
	return false;
}

/*
================
idCustomUI::Event_Hide
================
*/
void idCustomUI::Event_Hide( void ) {
	// Direct (non-virtual) call to idEntity::Hide in the binary, so the source named the base
	// class explicitly.
	idEntity::Hide();
	UnregisterGUI();
}

// ===========================================================================
// idPlayer additions (Player.cpp)
// ===========================================================================

/*
================
idPlayer::useCustomUI
================
*/
void idPlayer::useCustomUI( idUserInterface *ui, idCustomUI *uiEntity ) {
	customUI		= ui;
	customUIEntity	= uiEntity;
}

/*
================
idPlayer::clearCustomUI
================
*/
void idPlayer::clearCustomUI( void ) {
	customUI		= NULL;
	customUIEntity	= NULL;
}

// ===========================================================================
// idCmdSystem::ArgCompletion_GuiName (framework/CmdSystem.h) and its registration
// ===========================================================================

// cmdSystem vtable +0x2c = ArgCompletion_FolderExtension( args, callback, folder, stripFolder, ... )
ID_INLINE void idCmdSystem::ArgCompletion_GuiName( const idCmdArgs &args, void(*callback)( const char *s ) ) {
	cmdSystem->ArgCompletion_FolderExtension( args, callback, "guis/", false, ".gui", NULL );
}

// The only use of ArgCompletion_GuiName in the binary: the value completion of the g_PDA cvar,
// built in Player.cpp's static initializer (0x14f860, the `_GLOBAL__I_hudmap_alpha` unit;
// the function address is loaded @ 0x14fd25). The idCVar constructor is inlined there.
// Stored flags 0x21080 = CVAR_ARCHIVE | CVAR_STATIC | CVAR_GAME. idCVar::Init adds CVAR_STATIC.
// g_PDA is read in idPlayer::Spawn (0x16f730).
idCVar g_PDA( "g_PDA", "guis/pda_chex.gui", CVAR_GAME | CVAR_ARCHIVE, "gui file to use for the pda", idCmdSystem::ArgCompletion_GuiName );
```

## Notes

- **Placement of `ArgCompletion_GuiName`.** Issue #17 placed this function here provisionally. Its only registration site is the `g_PDA` cvar (PDA GUI file), not the HUD map's `showMap` command. It stays in this group: it is a GUI-name helper, and the HUD map group (#22) does not use it.
- **Who uses `idCustomUI` (binary, outside this group).** `idTarget_EndLevelGUI` is its only subclass: its `CreateInstance` calls `idCustomUI`'s base constructor. It calls `setGUI` and `RegisterGUI` from `Event_Activate`, and `UnregisterGUI` from `Event_UpdateStats` and its own `HandleCustomGUICommand`. Nothing else calls `idPlayer::useCustomUI` / `clearCustomUI` except `idCustomUI::RegisterGUI` / `UnregisterGUI`. Among the entity defs in `def/`, only `def/endlevelgui.def` (`spawnclass idTarget_EndLevelGUI`) names either class.
- **Edits inside stock `idPlayer` functions (out of scope for spec #16, recorded as leads).** A displacement of `+0x1f10` (presumably `customUI`) also appears in `ActiveGui` (returned first when non-NULL, 0x14ce64), `UpdateViewAngles`, `SelectWeapon`, `Weapon_GUI`, `ClientPredictionThink`, `Think`, `HandleSingleGuiCommand` and `idPlayerView::SingleView`. When both `+0x1f10` and `+0x1f0c` are non-NULL, `HandleSingleGuiCommand` calls vtable slot 59 (`HandleCustomGUICommand`) on the `+0x1f0c` object (0x16db60-0x16db8c). Both constructor clones write both members. None of these are checked here.
- **`gameLocal.time` offset.** `+0x251884` is taken as `gameLocal.time` because stock `idEvent::Schedule` (`this->time = gameLocal.time + time`) reads the same offset (0x1df4fb). Not proven by compiling.
- **Vtable offsets** (`FindGui` +0x38, `Activate` +0x5c, `Warning` +0x50, `ArgCompletion_FolderExtension` +0x2c) were matched by counting virtual declarations in the stock headers, with GCC 3 two-slot virtual destructors.
- **Ghidra artifacts.**
  - Ghidra labels the D0 clone `~idCustomUI` and passes a stray `unaff_EBX` to `operator_delete`. The call is really `idClass::operator delete( this )`.
  - The `try { ... } CatchHandler` comments in `RegisterGUI` span far past the function and are not code.
  - `LAB_00373d0d_7` in `CreateInstance` is the string `"idCustomUI"`, not a code label.
- **Open questions.** Is `registered` restored correctly when a save is loaded without a local player? `RegisterGUI` silently does nothing then, but `registered` stays `true`. This is in the binary. It needs an in-game check.
