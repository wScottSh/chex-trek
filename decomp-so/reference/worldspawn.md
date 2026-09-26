# Map music volume (`idWorldspawn::Think`, `g_MusicVolume`): reconstructed reference

**Provenance:** reconstructed by **Claude Opus 5.5** on 2026-09-24 from the complete Ghidra export `decomp-so/ghidra-full/` of `gamex86.so` (Ghidra 12.1.4, "Non-Returning Functions - Discovered" disabled), enriched export (issue #18: float constants and string literals resolved from `.rodata`). Checks 1-3 pass (added in PR #27's final review). Check 3 compiles it, 32-bit, against stock DOOM-3 GPL a9c49da. Export files: `idWorldspawn_Think_001bbe40.c` and `idWorldspawn_Save_001bb5e0.c`. Facts marked *binary* were read straight from `gamex86.so` (symbol table, vtables, relocations, static initializers, disassembly). Reference material only, not original source. The original source does not exist.

Scope (spec #16, story 2; no sub-issue): two methods on the stock class `idWorldspawn` that the stock DOOM-3 GPL source does not have. They were found after issues #17-#26, by comparing every function symbol in `gamex86.so` with a build of the stock source (`coverage.md`, "How the target set was checked"). `idWorldspawn::Think` applies the new `g_MusicVolume` cvar to the map's music. `idWorldspawn::Save( idSaveGame * )` is empty. `idWorldspawn` is a stock class (base `idEntity`, as in stock). Addresses below are ELF virtual addresses. Ghidra's are `+0x10000`. Stock DOOM-3 GPL source (a9c49da) is referenced, not repeated.

## Header

```cpp
// ---------------------------------------------------------------------------
// idWorldspawn additions (WorldSpawn.h)
// ---------------------------------------------------------------------------
class idWorldspawn : public idEntity {
	// ... stock members ...
public:
	// Binary: _ZN12idWorldspawn4SaveEP10idSaveGame is the Save that idWorldspawn::Type registers
	// (GOT load at 0x1ab8c4 in WorldSpawn.cpp's static initializer). The GPL source declares
	// Save( idRestoreGame * ) instead, which the .so does not have.
	// UNCERTAIN: whether the mod or id's 2005 SDK changed the parameter type.
	void					Save( idSaveGame *savefile );
	// Binary: idWorldspawn's vtable entry +0x14, idEntity::Think's slot (idEntity's vtable has
	// idEntity::Think there), is this function. So it overrides the stock virtual Think.
	virtual void			Think( void );
};

// Binary: EV_FadeSound (0x719bc0) is STB_GLOBAL, so it was declared extern.
// UNCERTAIN: where. Not in a header Entity.cpp includes: its own EV_FadeSound (0x3d9e60, STB_LOCAL)
// would then have external linkage too, and the two definitions would clash.
extern const idEventDef EV_FadeSound;
```

## Implementation

```cpp
// ===========================================================================
// g_MusicVolume and EV_FadeSound (WorldSpawn.cpp)
// ===========================================================================

// Binary: WorldSpawn.cpp's static initializer (0x1ab7e0) builds it at 0x1ab94c with the inline idCVar
// constructor: name "g_MusicVolume", value "50", description "Music Volume", flags 0x21084 =
// CVAR_GAME | CVAR_ARCHIVE | CVAR_FLOAT plus the CVAR_STATIC the constructor adds, valueMin 1 and
// valueMax -1 (the no-range defaults of the constructor without a range). The symbol (0x719b80,
// STB_GLOBAL) comes right after idWorldspawn::Type in .data.
idCVar g_MusicVolume( "g_MusicVolume", "50", CVAR_GAME | CVAR_ARCHIVE | CVAR_FLOAT, "Music Volume" );

// Binary: the same initializer then builds EV_FadeSound (0x1ab9f5) as idEventDef( "fadeSound", "dff" ):
// the stock Entity.cpp event's name and format again. The stock idEventDef constructor finds the name
// already defined and takes that event's number, so ProcessEvent( &EV_FadeSound, ... ) runs the stock
// EVENT( EV_FadeSound, idEntity::Event_FadeSound ) entry.
const idEventDef EV_FadeSound( "fadeSound", "dff" );

// ===========================================================================
// idWorldspawn (WorldSpawn.cpp)
// ===========================================================================

/*
=================
idWorldspawn::Save

Empty, as the stock Save( idRestoreGame * ) is (binary: a lone `ret`).
=================
*/
void idWorldspawn::Save( idSaveGame *savefile ) {
}

/*
=================
idWorldspawn::Think

Applies g_MusicVolume to the map's music: the worldspawn's own sound, which stock idEntity::Spawn
sets up from the worldspawn's s_shader key. Spawn marks the cvar modified and turns thinking on
(an edit inside the stock function, see Notes), so this runs its body at map start and again each
time the menu's music slider changes the cvar. Below 1 the music stops. Otherwise it is restarted
if it was stopped, and faded at once to s_volume - 30 + 0.6 * g_MusicVolume dB: s_volume - 30 at 0,
s_volume at the default 50, s_volume + 30 at 100.
=================
*/
void idWorldspawn::Think( void ) {
	// IsModified / ClearModified are the stock inline idCVar methods: CVAR_MODIFIED (0x40000) in
	// internalVar->flags (internalVar +0x2c, flags +0x10).
	if ( !g_MusicVolume.IsModified() ) {
		return;
	}

	// UNCERTAIN: 8 is TH_UPDATEVISUALS, not TH_THINK. So thinking stays on and Think is called
	// every frame; only the IsModified test runs then.
	BecomeInactive( TH_UPDATEVISUALS );

	// GetFloat is internalVar->floatValue (+0x28). The binary compares with fld1: 1.0 is no constant.
	if ( g_MusicVolume.GetFloat() < 1.0f ) {
		StopSound( SND_CHANNEL_ANY, false );
	} else {
		// refSound is the stock idEntity member (+0x1a0): referenceSound +0x1a0, shader +0x1b4,
		// waitfortrigger +0x1bc. CurrentlyPlaying is idSoundEmitter vtable +0x20. The inner test and
		// call are stock idEntity::Spawn's own start of the sound.
		if ( refSound.referenceSound && !refSound.referenceSound->CurrentlyPlaying() ) {
			if ( refSound.shader && !refSound.waitfortrigger ) {
				StartSoundShader( refSound.shader, SND_CHANNEL_ANY, 0, false, NULL );
			}
		}
		// idEntity::Event_FadeSound( channel, to, over ): all channels, to the volume, over 0 seconds.
		// UNCERTAIN: the binary has the volume computation twice, once after each outcome of the test
		// above. Whether the source repeated it or the compiler did is not known.
		ProcessEvent( &EV_FadeSound, SND_CHANNEL_ANY, spawnArgs.GetFloat( "s_volume", "0" ) - 30.0f + 0.6f * g_MusicVolume.GetFloat(), 0.0f );
	}

	g_MusicVolume.ClearModified();
}
```

## Notes

- **How the two methods were found.** The target list (`scripts/targets.txt`) was built by method name, so it missed methods whose names are not new. After issues #17-#26, every function symbol in `gamex86.so` was compared with the symbols of a build of the stock source (`coverage.md`, "How the target set was checked"). Only these two, the `ProjectDecal` overload (`script-events.md`) and the SDK checksum functions `coverage.md` lists as not custom were left over. `idWorldspawn`'s other functions (`Spawn`, `Restore`, `Event_Remove`, the destructors, `GetType`, `CreateInstance`) have stock names and signatures.
- **Edit inside the stock `Spawn` (out of scope for spec #16, recorded as a lead).** Near its end `idWorldspawn::Spawn` sets `CVAR_MODIFIED` on `g_MusicVolume` (`or [internalVar + 0x10], 0x40000` at 0x1abcd3, the inline `SetModified()`) and calls `BecomeActive( TH_THINK )` (0x1abcea). Stock `Spawn` does neither. So `Think` runs its body once when the map starts. `Restore` has the stock calls only (`va`, the inline `GetFloat` / `GetBool`): it does not set the cvar modified, so after a savegame is loaded the volume is reapplied only when the cvar next changes. UNCERTAIN (not checked in game): whether the restored sound keeps its faded volume.
- **Ported by spec #45 (stock `game/WorldSpawn.h` / `.cpp`): two compile/link fixes, no behavior change.**
  - `Save( idSaveGame * )` is declared `const`. With the stock `Save( idRestoreGame * )` typo also in scope, `CLASS_DECLARATION`'s `(void (idClass::*)(idSaveGame*) const)&Save` cast needs an exact match; `idEntity::Save` is `const` too. The body is empty either way.
  - The second `EV_FadeSound` is `static` in `WorldSpawn.cpp`, not this reference's `extern` declaration plus plain definition: MSVC gives a top-level `const idEventDef` external linkage, which clashed with `Entity.cpp`'s own `EV_FadeSound` (LNK2005). The `idEventDef` constructor still finds the name already registered and reuses its event number.
  - `BecomeInactive( TH_UPDATEVISUALS )` is kept as written (open question below).
- **Cross-check against the mod's data.**
  - `guis/mainmenu.gui:5440-5448` (under the title "Ingame Music", just before an `//END MATT` comment): a `sliderDef` with `low 0`, `high 100`, `step 5`, `cvar "g_MusicVolume"`. `corvette_notes.txt:141` (11/23): "g_musicvolume on mainmenu->system"; `:146-147` (11/21): "g_musicvolume range 0 -> 100", "use worldspawn s_shader for music". The cvar itself has no range (valueMin 1, valueMax -1): only the slider limits it.
  - Maps: the worldspawns of `maps/e1m1.map`, `maps/e1m1_2.map` (`s_shader` `sound/chex/e1m1_music`) and `maps/sf_923.map` (`sound/chex/sf_923_music`) set `s_volume` -6, `s_looping` 1 and `s_global` 1. So at the default 50 the music plays at -6 dB, the map's own volume. The other maps' worldspawns set no `s_shader`, so `refSound.shader` is NULL and `Think` never starts a sound. `refSound.referenceSound` is allocated by the first stock `StartSoundShader` on the entity, so it too is normally NULL there, and the fade event then does nothing (stock `Event_FadeSound` tests `referenceSound`).
  - Both music shaders are in `sound/chex_snd.sndshd` (lines 28, 33).
- **Callees (check 1).** Named in the code: `BecomeInactive`, `StopSound`, `StartSoundShader`, `ProcessEvent`. From stock inline code, on `allowlist.tsv` as `stock-inline`: `idDict::FindKey` and `__strtod_internal` (`spawnArgs.GetFloat( key, default )`). `CurrentlyPlaying` is a vtable call, which check 1 does not see. `Save` calls nothing.
- **Literals (check 2).** `Think` reads `"s_volume"`, `"0"`, 30.0 and 0.6 from `.rodata`. All appear in the code. `Save` reads none. The cvar's and the event's strings are read by the static initializer, which is not a covered function, so check 2 does not cover them. They were read from the disassembly.
- **Compile (check 3).** The header and implementation compile with g++ 12 `-m32` against stock DOOM-3 GPL a9c49da. The `idWorldspawn` partial declaration is spliced into a scratch copy of `game/WorldSpawn.h`, next to the stock `Save( idRestoreGame * )`. The check proves the code is well-formed only.
- **Offsets checked against a g++ 12 `-m32` build of the stock headers:** `sizeof( idCVar )` 0x34 (the symbol's size is 52), `idCVar::internalVar` +0x2c, `flags` +0x10, `floatValue` +0x28, `idEntity::refSound` +0x1a0, `refSound_t::shader` +0x14, `waitfortrigger` +0x1c. Vtable offsets (pointer-to-virtual-member values): `idSoundEmitter::CurrentlyPlaying` +0x20, `idEntity::Think` +0x14. All match the binary's accesses.
- **Ghidra artifacts.**
  - `Think`: the `(*(byte *)(... + 0x12) & 4)` test is `IsModified()` (byte 2 of `flags`, bit 18). `this + 100` is `spawnArgs` (+0x64). The two `ProcessEvent` argument pairs `100, 0` and `0x66, fVar6` / `0x66, 0` are `idEventArg`s: type `'d'` (channel 0) and type `'f'` (the volume, then 0.0). The `try` / `catch() { ... }` comments come from the function's exception table, not from code.
  - `Save`: Ghidra shows no `this`, only `param_1`. The body is a lone `ret`.
- **Open questions.** Whether `BecomeInactive( TH_UPDATEVISUALS )` was meant to be `TH_THINK` (as written, the worldspawn thinks every frame). What `Save( idSaveGame * )` changed, if the 2005 SDK already had it. Both need the 2005 SDK source or an in-game check.
