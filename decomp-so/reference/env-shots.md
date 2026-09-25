# Env shots (`matt_func_envshot`, `takeEnvShots`): reconstructed reference

**Provenance:** reconstructed by **Claude Opus 5.5** on 2026-09-24 from the complete Ghidra export `decomp-so/ghidra-full/` of `gamex86.so` (Ghidra 12.1.4, "Non-Returning Functions - Discovered" disabled), enriched export (issue #18: float constants and string literals resolved from `.rodata`). Checks 1-3 pass (issue #25). Check 3 compiles it, 32-bit, against stock DOOM-3 GPL a9c49da. Export files: `matt_func_envshot_*.c` (8 files). Facts marked *binary* were read straight from `gamex86.so` (symbol table, vtables, RTTI, relocations, event tables, disassembly). Reference material only, not original source. The original source does not exist.

Scope (spec #16, issue #25): the `matt_func_envshot` class, its `EV_envShot` event (`Event_envShot`), and the `takeEnvShots` console command (`matt_func_envshot::takeEnvShots_f`) with its registration. The symbol table's `STT_FILE` entry names the file `func_envshot.cpp`; `ChexTrek_SDK_ChangeLog.txt` (r1) adds `game/func_envshot.cpp` and `game/func_envshot.h`. Addresses below are ELF virtual addresses. Ghidra's are `+0x10000`. Stock DOOM-3 GPL source (a9c49da) is referenced, not repeated.

## Header

```cpp
// ---------------------------------------------------------------------------
// matt_func_envshot (game/func_envshot.h)
// An editor-placed point that takes an environment shot (the stock renderer's "envshot"
// command, six cube-map faces) from its own origin: 250 ms after spawn with "atSpawn" "1", or
// for every such entity at once with the console command takeEnvShots. The entityDef is
// func_envshot (def/func_envshot.def).
//
// Base class: idEntity. Evidence (binary):
//   1. matt_func_envshot::Type is built with superclass name "idEntity": func_envshot.cpp's
//      static initializer (0x2a6cb0) loads "idEntity" (lea at 0x2a6df5) and "matt_func_envshot"
//      (lea at 0x2a6dff) as arguments to idTypeInfo::idTypeInfo @ 0x2a6e12, with matt_func_envshot::Spawn,
//      idEntity::Save and idEntity::Restore (so the class has no Save / Restore of its own).
//   2. RTTI: _ZTI17matt_func_envshot (0x3cedec) is a __si_class_type_info whose base is _ZTI8idEntity.
//   3. CreateInstance calls idEntity's base constructor (C2), then stores this class's vtable.
//      Both destructor clones store this class's vtable, then call idEntity's base destructor.
//   4. Vtable _ZTV17matt_func_envshot (59 words, 0x3ced00) matches _ZTV8idEntity word for word,
//      except for the type info, GetType and the two destructors: no new virtuals, no overrides.
//   5. No members of its own: CreateInstance allocates 0x27c bytes, sizeof( idEntity ) in this
//      build (mkObjective's and idCustomUI's first members sit at +0x27c).
// ---------------------------------------------------------------------------
class matt_func_envshot : public idEntity {
public:
	CLASS_PROTOTYPE( matt_func_envshot );

	// UNCERTAIN: whether ~matt_func_envshot() was declared in the source. Both clones (D1 0x2a7990,
	// D0 0x2a7940) are weak symbols that do nothing of their own, which is what a compiler-generated
	// destructor gives. Declaring an empty one here behaves the same.
	// No constructor is declared: the binary has no matt_func_envshot constructor symbol, and
	// CreateInstance only runs idEntity's.
							~matt_func_envshot( void );

	void					Spawn( void );

	// UNCERTAIN: access level. takeEnvShots_f calls it directly, which any access level allows
	// (a static member of the same class).
	void					Event_envShot( void );

	// Console command "takeEnvShots" (registered in idGameLocal::InitConsoleCommands). Static:
	// the symbol _ZN17matt_func_envshot14takeEnvShots_fERK9idCmdArgs takes no `this`.
	static void				takeEnvShots_f( const idCmdArgs &args );
};
```

## Implementation

```cpp
// ===========================================================================
// matt_func_envshot (game/func_envshot.cpp)
// ===========================================================================

// The event. Binary: func_envshot.cpp's static initializer (0x2a6cb0) constructs it at 0x2a6d8e
// as idEventDef( "<envshot>", NULL, 0 ): no arguments, no return value. The name is "<envshot>",
// not "envShot": the angle brackets mark an internal event, like the stock "<immediateremove>",
// which script code cannot name (Notes). The symbol EV_envShot (0x75bba0) is STB_LOCAL, as a
// `const idEventDef` at file scope is (const gives internal linkage).
const idEventDef EV_envShot( "<envshot>" );

// Event table (binary: matt_func_envshot::eventCallbacks @ 0x3d77e0 =
// { EV_envShot, Event_envShot }, { NULL }).
CLASS_DECLARATION( idEntity, matt_func_envshot )
	EVENT( EV_envShot,		matt_func_envshot::Event_envShot )
END_CLASS

/*
================
matt_func_envshot::~matt_func_envshot

Possibly not written in the source (see header).
================
*/
matt_func_envshot::~matt_func_envshot( void ) {
	// Nothing of its own. Both clones reset the vtable pointer to this class's and run
	// idEntity::~idEntity(). The D0 clone then frees `this`.
}

/*
================
matt_func_envshot::Spawn
================
*/
void matt_func_envshot::Spawn( void ) {
	Hide();		// virtual, idEntity vtable +0x4c (binary: _ZTV17matt_func_envshot + 8 + 0x4c holds idEntity::Hide)

	// UNCERTAIN: GetBool or GetInt. Both compile to atoi( GetString( key, "0" ) ) != 0 here.
	if ( spawnArgs.GetBool( "atSpawn", "0" ) ) {
		PostEventMS( &EV_envShot, 250 );
	}
}

/*
================
matt_func_envshot::Event_envShot

Renders the scene once from this entity's origin, looking down +X, then runs the renderer's
"envShot <name> <size> <blends>" command at once. The stock envshot command (R_EnvShot_f)
shoots its six faces from the last primary view rendered, which is this one.
================
*/
void matt_func_envshot::Event_envShot( void ) {
	renderView_t *	view;
	int				i;

	// The same setup as the start of the stock idPlayer::CalculateRenderView. The view is
	// allocated here and never freed (binary: no operator delete in this function; Notes).
	view = new renderView_t;
	memset( view, 0, sizeof( *view ) );

	// copy global shader parms. Binary: 12 unrolled moves from gameLocal+0x8fc0 to view+0x54.
	// UNCERTAIN: a loop, as in CalculateRenderView (whose loop this build also unrolls into 12
	// moves, 0x15961d-0x1596c2), or 12 assignments.
	for ( i = 0; i < MAX_GLOBAL_SHADER_PARMS; i++ ) {
		view->shaderParms[ i ] = gameLocal.globalShaderParms[ i ];
	}
	view->globalMaterial = gameLocal.GetGlobalMaterial();
	view->time = gameLocal.time;		// gameLocal+0x251884

	view->x = 0;
	view->y = 0;
	view->width = SCREEN_WIDTH;			// 640
	view->height = SCREEN_HEIGHT;		// 480
	view->viewID = 0;

	// Binary: an identity idMat3 is built from immediates (1.0f on the diagonal, 0 elsewhere) in a
	// stack temporary and copied into viewaxis. UNCERTAIN: the source form. Not mat3_identity or
	// Identity(), which would read the global mat3_identity from memory.
	view->viewaxis = idMat3( 1.0f, 0.0f, 0.0f, 0.0f, 1.0f, 0.0f, 0.0f, 0.0f, 1.0f );
	view->vieworg = GetPhysics()->GetOrigin();		// idPhysics vtable +0x84, id 0
	// 73.74 is the fov_y that gameLocal.CalcFov gives for a fov_x of 90 at 4:3 (73.7398...),
	// rounded and written as a constant (binary: immediate 0x42937ae1 = 73.74f).
	view->fov_x = 90.0f;
	view->fov_y = 73.74f;

	gameRenderWorld->RenderScene( view );		// idRenderWorld vtable +0x48

	idStr name;
	idStr size;
	idStr blends;
	// "name" is the entity's own name (every entity has one): the shots are env/<name>_px.tga etc.
	spawnArgs.GetString( "name", "", name );
	spawnArgs.GetString( "size", "", size );
	spawnArgs.GetString( "blends", "", blends );

	// Binary: five idStr temporaries, built left to right by the inline idStr operator+ ("envShot "
	// is copied with immediate stores, " " read from .rodata), then idCmdSystem vtable +0x24 with
	// exec 0. UNCERTAIN: whether the result went through a named idStr first.
	cmdSystem->BufferCommandText( CMD_EXEC_NOW, "envShot " + name + " " + size + " " + blends );
}

/*
================
matt_func_envshot::takeEnvShots_f

Console command "takeEnvShots": takes the env shot of every matt_func_envshot on the map at once.
================
*/
void matt_func_envshot::takeEnvShots_f( const idCmdArgs &args ) {
	int			i;
	int			count;
	idEntity *	ent;

	count = 0;
	// gameLocal.num_entities is +0x8f48 and gameLocal.entities +0xf44 in this build.
	for ( i = 0; i < gameLocal.num_entities; i++ ) {
		ent = gameLocal.entities[ i ];
		// ent->IsType() is the inline idClass::IsType: GetType() (vtable +0x0) and the
		// typeNum / lastChild range test against matt_func_envshot::Type.
		if ( ent && ent->IsType( matt_func_envshot::Type ) ) {
			// A direct call, not an event: every shot is taken now, in entity order.
			static_cast<matt_func_envshot *>( ent )->Event_envShot();
			count++;
		}
	}
	// common->Printf directly (idCommon vtable +0x44), not gameLocal.Printf.
	common->Printf( "%i envShots taken\n", count );
}

// ===========================================================================
// Registration (game/gamesys/SysCmds.cpp)
// ===========================================================================

/*
================
idGameLocal::InitConsoleCommands

Excerpt: only the line the mod added. Binary (0x1e7e38-0x1e7e6a): cmdSystem->AddCommand
(idCmdSystem vtable +0x10) with "takeEnvShots", matt_func_envshot::takeEnvShots_f, flags 0x11,
"takes an environment shot at func_envshots" and a NULL completion hook. It is the last command
the function registers, right after the mod's "showMap" (hud-map group). The stock
ShutdownConsoleCommands removes it with the other CMD_FL_GAME commands.
================
*/
void idGameLocal::InitConsoleCommands( void ) {
	// ... stock commands, the last "testid" ...
	// ... "showMap" (hud-map group) ...
	cmdSystem->AddCommand( "takeEnvShots", matt_func_envshot::takeEnvShots_f, CMD_FL_GAME|CMD_FL_CHEAT, "takes an environment shot at func_envshots" );
}
```

## Notes

- **Callers (binary).** `Event_envShot` is reached from the event table (`EV_envShot`) and called directly only by `takeEnvShots_f` (checked over every function's direct calls). `EV_envShot` is used only by `Spawn` (`PostEventMS`) and the static initializer that builds it. `takeEnvShots_f`'s address is loaded only by `idGameLocal::InitConsoleCommands` (scan of every GOT load of its slot).
- **The `EV_envShot` event, matched to the mod's data.** Definition: `idEventDef( "<envshot>" )`, no arguments, no return value. The spec's name for it, `envShot`, is the C++ symbol's (`EV_envShot`, `Event_envShot`) and the renderer command's (`"envShot "`); the event's own name is `"<envshot>"` (binary: `.rodata` 0x371593, and `"envShot"` is not a whole string in `.rodata`). No file in `script/` names `envshot` in any case, and a script identifier cannot contain `<`, so it is not a script event: only `Spawn` posts it.
- **`takeEnvShots` registration.** Name `"takeEnvShots"`, function `matt_func_envshot::takeEnvShots_f`, flags `CMD_FL_GAME|CMD_FL_CHEAT` (0x11), description `"takes an environment shot at func_envshots"`, no completion hook (NULL). It is a cheat command. The registration's strings are read by the stock `idGameLocal::InitConsoleCommands`, which is not a covered function, so check 2 does not cover them. They were read from the disassembly. `takeEnvShots_f` ignores its arguments.
- **How a shot is taken.** `Event_envShot` renders a 640 x 480 scene from the entity's origin, looking down +X, with fov 90 x 73.74 (`idRenderWorld::RenderScene`, vtable +0x48, not `SetRenderView` at +0x44; offsets counted in stock `renderer/RenderWorld.h`, where every virtual is declared in order). It then runs `envShot <name> <size> <blends>` with `CMD_EXEC_NOW`. The stock renderer command `envshot` (`R_EnvShot_f`, `renderer/RenderSystem_init.cpp`; command names are case-insensitive) copies `tr.primaryView`'s render view, sets `x`, `y`, `fov_x`, `fov_y`, `width`, `height` and `viewaxis` for each of the six faces, and writes `env/<basename>_px.tga`, `_nx`, `_py`, `_ny`, `_pz`, `_nz`. So the render call's job is to make this entity's view the primary view: only its `vieworg` (and time, shader parms, material) reach the shots. UNCERTAIN (not checked): that this build's renderer (`gamex86.so` does not contain it) matches stock here, and that `RenderScene` sets `tr.primaryView` when called from a console command outside the frame.
- **spawnArgs, cross-checked with `def/` and `maps/`.**
  - Entity: `func_envshot` (`def/func_envshot.def`, `"spawnclass" "matt_func_envshot"`). Its `editor_var`s are exactly the four keys the binary reads: `size`, `name`, `blends` (`Event_envShot`) and `atSpawn` (`Spawn`). The def's comment: "takes an envshot at the origin of the entity, triggered by spawn w/atSpawn or the takeEnvShots command".
  - Maps: no `.map` file in this repo has a `func_envshot`, and `env/` has no `_px.tga` ... `_nz.tga` files (its skyboxes use `_back`, `_up` ... names). So the tool seems to have been used on maps or shots not kept here.
  - Missing keys give `""`, and the command text then has an empty field. `R_EnvShot_f` reads `size` and `blends` by position (`Argv( 2 )`, `Argv( 3 )`, default size 256, blends 1). UNCERTAIN (not checked): whether `idCmdArgs::TokenizeString` drops the empty field, in which case a missing `size` with a set `blends` would make `blends` the size.
- **Leak.** Each `Event_envShot` allocates a `renderView_t` (`operator new( 0x88 )`) and never frees it: 136 bytes per shot. The stock code it follows (`idPlayer::CalculateRenderView`, `idEntity::GetRenderView`) keeps its view in the `renderView` member and allocates only once; this one uses a local.
- **Not saved.** No `Save` / `Restore` (the type info registers idEntity's). A pending `atSpawn` event is saved with the other events by the stock event system, as for any entity.
- **Stock-inline callees (check 1 allow-list, `stock-inline`).** `Spawn`: `idDict::FindKey` and `__strtol_internal` inside `spawnArgs.GetBool`. `Event_envShot`: `idDict::FindKey`, `idStr::ReAllocate` and `memcpy` inside `spawnArgs.GetString( key, default, idStr & )`; `idStr::ReAllocate` and `strcpy` inside the inline `idStr` `operator+` (the copy constructor and `Append`); `idStr::FreeData` inside `~idStr()`. `idStr::operator=( const char * )` (GetString's `out = defaultString`, not inline: `idlib/Str.cpp`) needs no entry: check 1 matches an operator callee by its operator (`=`) in the code. Each is on `verify/allowlist.tsv` for the exact function, with the stock function named. `memset`, `operator new`, `GetGlobalMaterial` and `GetPhysics` are named in the code. `Hide`, `GetOrigin`, `RenderScene`, `BufferCommandText`, `GetType` (inside `IsType`) and `Printf` are vtable calls, which check 1 does not see.
- **Literals (check 2).** Every string and float the group's functions read appears with its value: `"atSpawn"`, `"0"` (`Spawn`); `"name"`, `"size"`, `"blends"`, `""`, `" "` and the immediates 1.0, 90.0, 73.74 (`Event_envShot`); `"%i envShots taken\n"` (`takeEnvShots_f`). `"envShot "` is not in `.rodata`: the inline `idStr( const char * )` stores it (NUL included) as `mov` immediates, and check 2 accepts it from there. The event name `"<envshot>"` and the registration strings are read by static initializers and a stock function, which are not covered functions (see above).
- **Compile (check 3).** The header and implementation compile with g++ 12 `-m32` against stock DOOM-3 GPL a9c49da. Nothing is spliced into a stock class. The `idGameLocal::InitConsoleCommands` excerpt compiles as a definition in this translation unit only; the stock body is not repeated.
- **Offsets.** `idCmdSystem` vtable: `AddCommand` +0x10, `BufferCommandText` +0x24; `idCommon::Printf` +0x44; `idRenderWorld::RenderScene` +0x48 (counted in the stock headers, as above). `gameLocal`: `entities` +0xf44, `num_entities` +0x8f48, `globalShaderParms` +0x8fc0, `time` +0x251884 (binary). Each is 0x10 bytes past its offset in a GCC 12 `-m32` build of the stock headers (0xf34, 0x8f38, 0x8fb0, 0x251874, from `offsetof`), the same shift `hud-map.md` found for `world` and `isMultiplayer`. So this build's `idGameLocal` differs from stock before `entities`. Not examined (edits inside stock declarations are out of scope). `renderView_t` (0x88 bytes, as in the GCC 12 stock build) is the stock layout: `shaderParms` +0x54, `globalMaterial` +0x84, `time` +0x50, `viewaxis` +0x28, `vieworg` +0x1c, `fov_x` / `fov_y` +0x14 / +0x18.
- **Ghidra artifacts.**
  - `CreateInstance` types the new object `idEntity *` and passes a stray `in_stack_ffffffd8` to `operator_new` (really `idClass::operator new( 0x27c )`). Its exception path (`operator delete`, `__cxa_begin_catch`) is CLASS_DECLARATION's `try` / `catch`, not shown.
  - The D0 destructor passes a stray `unaff_EBX` to `operator_delete` (really `idClass::operator delete( this )`).
  - `Event_envShot`: `__s` is the `renderView_t *`, `this + 100` is `spawnArgs` (+0x64), the three `FindKey` / `ReAllocate` / `memcpy` runs are the inlined `GetString`, and `local_30` ... `local_b0` with their copy loops are the `idStr operator+` temporaries. `builtin_strncpy( local_24, "envShot ", 9 )` is the inline `idStr( "envShot " )`.
  - `takeEnvShots_f`: `puVar2 + 0xf44` walks `gameLocal.entities[]` alongside the index; the `+ 0x38` / `+ 0x3c` compares are `IsType`'s `typeNum` / `lastChild` test.
- **Open questions.** Whether `takeEnvShots` and `atSpawn` shots work in game (the render call outside the frame, above). Why `atSpawn` waits 250 ms (probably so the map has rendered once). Both need an in-game check.
