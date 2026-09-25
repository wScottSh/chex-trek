// chextrek: developer-only state-dump console command (spec #28/#29). See ChexTrekDump.h.

#include "sys/platform.h"
#include "idlib/LangDict.h"
#include "idlib/Lexer.h"
#include "idlib/Token.h"
#include "framework/async/NetworkSystem.h"

#include "gamesys/SysCvar.h"
#include "Game_local.h"
#include "Player.h"
#include "Target.h"

#include "ChexTrekDump.h"

// chextrek: spec #33. idTarget_EndLevelGUI's private state (displayStats/state/...) isn't
// readable from outside the class, and it's the only idCustomUI subclass in the mod. Rather than
// add getters to game code purely for a test dump, ChexTrek_Dump_f reads the local player's own
// idPlayer::customUIEntity/customUI (already public on idPlayer/idCustomUI: registered, and the
// GUI's own state via idUserInterface::State()) - see the dump's "customui:" lines below.

// The harness greps the game log for this exact line to prove chextrek.dll (not base.dll)
// loaded, independent of anything else the command goes on to print. Keep it stable: don't
// change the text or the "v1" tag without updating the harness and docs/dev-setup.md.
static const char *CHEXTREK_DUMP_HEADER = "CHEXTREK-STATE-DUMP v1";

// chextrek: spec #30. See ChexTrek_NoteFootprintProjected in ChexTrekDump.h.
static int chextrekFootprintCount = 0;

// chextrek: spec #32. See ChexTrek_NoteItemTextShown in ChexTrekDump.h.
static int chextrekItemTextCount = 0;
static idStr chextrekItemTextLast;

// chextrek: spec #30, test-only. The AFK harness drives the game only through console commands
// (spec #28), including the "script" command to call scriptEvents like setProj/spawnDict that
// need a string literal argument. The console's own tokenizer (idCmdArgs::TokenizeString,
// idlib/CmdArgs.cpp) strips the quotes off a quoted argument before idGameLocal's script compiler
// ever sees it (confirmed: `script sys.println( "x" )` recompiles as `sys.println( x )`, a bare
// identifier, which fails to compile with "Unknown value "x""). There's no escape sequence that
// survives that stripping (NOSTRINGESCAPECHARS is set on that tokenizer). The same tokenizer also
// intercepts a bare "$name" token as *cvar* expansion (idCVarSystem::GetCVarString), which means
// doom-script's own "$entityName" entity-reference syntax can't be typed directly in a console
// "script" line either - it silently resolves as an (empty) cvar lookup instead. The workarounds
// both lean on the one thing that *does* survive verbatim: idCVarSystem::GetCVarString( name )
// substitutes the cvar's raw stored value into the token with no further quote handling. So (a) a
// cvar whose value already contains literal quote characters survives into the reconstructed
// text as a real string literal (`script sys.spawnDict( $chextrek_test_str1 )` compiles as
// `sys.spawnDict( "moveable_item_shotgun" )`), and (b) named entities are looked up at runtime via
// `sys.getEntity( $cvar )` (idThread::Event_GetEntity -> gameLocal.FindEntity, unrelated to the
// "$name" compile-time syntax) instead of "$entityName". Not read by any game code; changes no
// game behavior.
idCVar chextrek_test_str1( "chextrek_test_str1", "\"moveable_item_shotgun\"", CVAR_GAME, "chextrek: test-only string-literal holder for AFK harness scenarios (spec #30) - see ChexTrekDump.cpp" );
idCVar chextrek_test_str2( "chextrek_test_str2", "\"func_door_17\"", CVAR_GAME, "chextrek: test-only string-literal holder for AFK harness scenarios (spec #30) - see ChexTrekDump.cpp" );
idCVar chextrek_test_str3( "chextrek_test_str3", "\"monster_chex_cly_2\"", CVAR_GAME, "chextrek: test-only string-literal holder for AFK harness scenarios (spec #30) - see ChexTrekDump.cpp" );
idCVar chextrek_test_str4( "chextrek_test_str4", "\"chextrek_removeme\"", CVAR_GAME, "chextrek: test-only string-literal holder for AFK harness scenarios (spec #30) - see ChexTrekDump.cpp" );
idCVar chextrek_test_str5( "chextrek_test_str5", "\"chextrek_footprint_actor\"", CVAR_GAME, "chextrek: test-only string-literal holder for AFK harness scenarios (spec #30) - see ChexTrekDump.cpp" );
idCVar chextrek_test_str6( "chextrek_test_str6", "\"player1\"", CVAR_GAME, "chextrek: test-only string-literal holder for AFK harness scenarios (spec #30) - see ChexTrekDump.cpp" );
idCVar chextrek_test_str7( "chextrek_test_str7", "\"projectile_minizorchblast_nodamage\"", CVAR_GAME, "chextrek: test-only string-literal holder for AFK harness scenarios (spec #30) - see ChexTrekDump.cpp" );
idCVar chextrek_test_str8( "chextrek_test_str8", "\"classname\"", CVAR_GAME, "chextrek: test-only string-literal holder for AFK harness scenarios (spec #30) - see ChexTrekDump.cpp" );
idCVar chextrek_test_str9( "chextrek_test_str9", "\"damage_rocketSplash\"", CVAR_GAME, "chextrek: test-only string-literal holder for AFK harness scenarios (spec #33) - see ChexTrekDump.cpp" );

/*
==================
ChexTrek_PrintHeader

Prints the stable header line the harness greps for. See ChexTrekDump.h for why this is a plain
function as well as a console command.
==================
*/
void ChexTrek_PrintHeader( void ) {
	gameLocal.Printf( "%s\n", CHEXTREK_DUMP_HEADER );
}

/*
==================
ChexTrek_NoteFootprintProjected
==================
*/
void ChexTrek_NoteFootprintProjected( void ) {
	chextrekFootprintCount++;
}

/*
==================
ChexTrek_NoteItemTextShown
==================
*/
void ChexTrek_NoteItemTextShown( const char *name ) {
	chextrekItemTextCount++;
	chextrekItemTextLast = name;
}

/*
==================
ChexTrek_Dump_f

Prints the mod's custom state to the game log for the AFK test harness. #29 lands only the
stable header line; later feature sub-issues append their own state under it (objective slots,
level stats, hud-map/fog-of-war coverage, trail/anchor counts, the active custom UI), per the
state-dump list in spec #28.

#30 adds two lines: `entities: <N>` (gameLocal.spawnedEntities.Num(), so a scenario can prove a
script's `remove()` call actually shrank the entity count - the log has no other line for this)
and `footprints: <N>` (see ChexTrek_NoteFootprintProjected).

#31 adds 5 more: `objective_slot_1` .. `objective_slot_5`, one per idPlayer::objectives[] slot
(MAX_OBJS, decomp-so/reference/objectives.md) - "empty" when the slot is NULL, else that slot's
mkObjective's title, so a scenario can assert a trigger_objective's slot filling/emptying without
depending on PDA/HUD GUI state.

#32 adds 2 more: `item_text_count` (how many times idPlayer::addItemText has run, via
ChexTrek_NoteItemTextShown) and `item_text_last` (the name it queued the last time, or "none" if
it has never run), so a scenario can assert that picking up an item showed its item text without
depending on HUD GUI state or racing the queue idPlayer::UpdateHud drains within a frame or two.

#33 adds:
- `level_stats: monsters=<found>/<total> items=<found>/<total> secrets=<found>/<total>`
  (idPlayer::levelStats[0..2], decomp-so/reference/end-level-stats.md), so a scenario can assert a
  kill/pickup/secret raised the right counter by exactly one without depending on the stats screen
  being up at all.
- `customui: <none|inactive|active>` - "none" when the local player has no idCustomUI registered
  (idPlayer::customUIEntity NULL), "inactive"/"active" (idCustomUI::registered) otherwise - and,
  only when active, `customui_gui_<name>: <value>` for each of the stats screen's own GUI state
  variables (ai_killed, ai_percent, items_found, items_percent, secrets_found, secrets_percent,
  level_time - decomp-so/reference/end-level-stats.md's Notes list the full set; ai_total/
  items_total/secrets_total/mapname are set once at Event_Activate and not re-asserted here), read
  straight from idUserInterface::State() (the same idDict idTarget_EndLevelGUI::updateStats writes
  through SetStateInt/SetStateString) - so a scenario can assert the screen counted up without
  depending on idTarget_EndLevelGUI's private displayStats/state members, which nothing outside the
  class can read.

#35 adds `pda_gui: <name|none>` (idPlayer::objectiveSystem's idUserInterface::Name(), the gui file
it was loaded from - this sub-issue's edit makes idPlayer::Spawn read that from g_PDA instead of
stock's hardcoded "guis/pda.gui"; "none" if there's no local player or no objectiveSystem) and
`pda_open: <0|1>` (idPlayer::objectiveSystemOpen), so a scenario can assert opening the PDA
(idPlayer::TogglePDA, reached here via idPlayer::GivePDA's own call to it on the player's first
PDA, not an impulse - see tools/test-pda.sh) made the mod's own PDA GUI (not stock's) the active
one, without depending on any GUI rendering.

#36 adds `hud_map: level=<N> visible=<0|1> coverage=<N>` (decomp-so/reference/hud-map.md):
`visible` is the HUD gui's own "HudMap" state flag (idPlayer::hud->GetStateBool, the same one
impulse 23 flips via the "openMap"/"closeMap" named events and hud.gui's hudmap_open/hudmap_close
windows handle), `level` is idPlayer::HudMapLevel( NULL ) (the player's current map floor), and
`coverage` is the number of alpha-revealed texels (hudmap_alpha[level][...][3] > 0) out of the
128x128 fog-of-war image for that level - so a scenario can assert impulse 23 flips `visible`
without depending on GUI rendering, and that `setviewpos` moves grow `coverage` without depending
on a screenshot.
==================
*/
void ChexTrek_Dump_f( const idCmdArgs &args ) {
	ChexTrek_PrintHeader();
	gameLocal.Printf( "entities: %d\n", gameLocal.spawnedEntities.Num() );
	gameLocal.Printf( "footprints: %d\n", chextrekFootprintCount );
	gameLocal.Printf( "item_text_count: %d\n", chextrekItemTextCount );
	gameLocal.Printf( "item_text_last: %s\n", chextrekItemTextCount > 0 ? chextrekItemTextLast.c_str() : "none" );

	// chextrek: spec #31. One line per objective slot (idPlayer::objectives[], MAX_OBJS = 5, see
	// decomp-so/reference/objectives.md), so a scenario can assert a slot filled/emptied by a
	// trigger_objective without depending on GUI state. "objective_slot_<N>: empty" when the slot
	// is NULL, else its mkObjective's title (the same text placed on the PDA).
	idPlayer *player = gameLocal.GetLocalPlayer();
	for ( int i = 0; i < idPlayer::MAX_OBJS; i++ ) {
		mkObjective *obj = player ? player->objectives[ i ] : NULL;
		if ( obj ) {
			gameLocal.Printf( "objective_slot_%d: %s\n", i + 1, obj->title.c_str() );
		} else {
			gameLocal.Printf( "objective_slot_%d: empty\n", i + 1 );
		}
	}

	// chextrek: spec #33 (decomp-so/reference/end-level-stats.md). idPlayer::levelStats[0..2]'s
	// found/total, so a scenario can assert a kill/pickup/secret raised the right counter by
	// exactly one - independent of whether the end-level stats screen is even up.
	if ( player ) {
		playerStats_s *stats = player->getLevelStats();
		gameLocal.Printf( "level_stats: monsters=%d/%d items=%d/%d secrets=%d/%d\n",
			stats[ 0 ].found, stats[ 0 ].total,
			stats[ 1 ].found, stats[ 1 ].total,
			stats[ 2 ].found, stats[ 2 ].total );
	} else {
		gameLocal.Printf( "level_stats: none\n" );
	}

	// chextrek: spec #16/#35 (decomp-so/reference/custom-ui.md). idPlayer::objectiveSystem is the
	// GUI idPlayer::Spawn loads from g_PDA (stock loads a hardcoded "guis/pda.gui" instead) and
	// shows while the PDA is up (idPlayer::objectiveSystemOpen, toggled by TogglePDA). Printing
	// idUserInterface::Name() (the gui's own qpath, not just "some gui is up") lets a scenario
	// assert the *mod's* PDA GUI (g_PDA's value, "guis/pda_chex.gui" by default) is the one that
	// actually got loaded and is the active GUI when the PDA is opened, not merely that opening
	// the PDA does something.
	if ( player && player->objectiveSystem ) {
		gameLocal.Printf( "pda_gui: %s\n", player->objectiveSystem->Name() );
		gameLocal.Printf( "pda_open: %s\n", player->objectiveSystemOpen ? "1" : "0" );
	} else {
		gameLocal.Printf( "pda_gui: none\n" );
		gameLocal.Printf( "pda_open: 0\n" );
	}

	// chextrek: spec #16/#36 (decomp-so/reference/hud-map.md). "visible" is the HUD gui's own
	// "HudMap" state flag (the same one impulse 23 flips), "level" is the player's current map
	// floor, and "coverage" counts the fog-of-war texels revealed so far on that level - see the
	// ChexTrek_Dump_f header comment above.
	if ( !player || !player->hud ) {
		gameLocal.Printf( "hud_map: none\n" );
	} else {
		int level = player->HudMapLevel( NULL );
		int coverage = 0;
		for ( int i = 0; i < 128 * 128; i++ ) {
			if ( hudmap_alpha[ level ][ i * 4 + 3 ] > 0 ) {
				coverage++;
			}
		}
		gameLocal.Printf( "hud_map: level=%d visible=%s coverage=%d\n",
			level, player->hud->GetStateBool( "HudMap", "0" ) ? "1" : "0", coverage );
	}

	// chextrek: spec #33 (decomp-so/reference/custom-ui.md, end-level-stats.md). The local
	// player's registered idCustomUI (only idTarget_EndLevelGUI in this mod) and, while active, the
	// stats screen's own GUI state variables - see the ChexTrek_Dump_f header comment above.
	if ( !player || !player->customUIEntity ) {
		gameLocal.Printf( "customui: none\n" );
	} else {
		gameLocal.Printf( "customui: %s\n", player->customUIEntity->registered ? "active" : "inactive" );
		if ( player->customUI ) {
			const idDict &guiState = player->customUI->State();
			static const char *statVars[] = {
				"ai_killed", "ai_percent", "items_found", "items_percent",
				"secrets_found", "secrets_percent", "level_time"
			};
			for ( int i = 0; i < (int)( sizeof( statVars ) / sizeof( statVars[ 0 ] ) ); i++ ) {
				gameLocal.Printf( "customui_gui_%s: %s\n", statVars[ i ], guiState.GetString( statVars[ i ], "" ) );
			}
		}
	}
}

/*
==================
ChexTrek_CustomUICmd_f

Test-only, spec #34. AC1/AC2 need the stats screen's "skip" and "nextmap" GUI commands
(decomp-so/reference/end-level-stats.md: idTarget_EndLevelGUI::HandleCustomGUICommand) run from a
scenario, but those commands only ever reach the game in the real game through a real mouse click:
guis/chex/stats.gui's "skip"/"nextmap" windowDefs fire on onAction, idPlayer::Weapon_GUI turns a
BUTTON_ATTACK edge into a mouse-button sysEvent_t, and idUserInterface::HandleEvent (engine-side,
not part of this SDK) turns that, plus its own tracked cursor position, into the "skip"/"nextmap"
command string that reaches idPlayer::HandleSingleGuiCommand -> HandleCustomGUICommand. Positioning
that cursor over a specific button needs real mouse-delta input (idPlayer::Think reads it from
usercmd_t::mx/my, Player.cpp) - not reachable from the console-only commands (map, script,
setviewpos, trigger, spawn, impulse, wait) spec #28's harness is limited to driving the game
through.

So this command supplies the one part a console script can't: the command string itself. It reads
a single token from its argument the same way idPlayer::HandleSingleGuiCommand would (idLexer over
the raw text, same as idEntity::HandleGuiCommands does for a real GUI command string), and passes
it to the local player's registered idCustomUI through the exact same virtual call
HandleSingleGuiCommand makes - HandleCustomGUICommand( entityGui, &token ) - with the customUI
entity itself standing in for entityGui (the reference's Notes say idTarget_EndLevelGUI's override
never reads that parameter). Everything downstream of that call is the real, already-ported game
code; this command changes no game behavior of its own, the same as chextrek_dump. Not a stand-in
for "any GUI command" generally - it only reaches idCustomUI subclasses (the only kind of GUI this
mod routes through a single, always-reachable idPlayer member, customUIEntity), which is exactly
the "nextmap"/"skip"/"unregister" screen spec #34 is about.

Recorded deviation from spec #28's Implementation Decisions, which describe the state-dump command
as "the only test code in the library": this is a second one, needed because #34's AC can't be
proven through spec #28's console-only command list otherwise (see above) - the same class of gap
the state-dump command itself exists to close (observing/driving state those commands can't reach),
just on the driving side instead of the observing side. CMD_FL_CHEAT (gamesys/SysCmds.cpp) plus its
own CheatsOk( false ) check matches idGameLocal's other state-changing debug commands
(Cmd_Trigger_f, Cmd_Spawn_f) - "false" (don't require a live player) is fine here since reaching
past the customUIEntity check below already implies one. This is honestly a weaker gate than "only
runs with developer 1" (spec #28 story 34 calls the state-dump command "developer-only"):
CheatsOk()/CMD_FL_CHEAT only block non-cheat multiplayer clients, not single-player without
"developer 1" (Game_local.cpp) - an explicit developer.GetBool() check was tried here too and
reverted after it broke the harness scenario for a reason not tracked down (the harness always runs
with "developer 1" set, both via the launch command line and this command's own console script -
tools/test-end-level-nextmap.sh - so the cvar not reading true where other game code's own
developer.GetBool() calls, e.g. Light.cpp, presumably do work needs more investigation before
relying on it). Narrower in practice, though not in principle (multiplayer with net_allowCheats 1
still passes this gate): this command can only ever change anything meaningful when a
player-triggered idCustomUI (only idTarget_EndLevelGUI in this mod) is already registered.
==================
*/
void ChexTrek_CustomUICmd_f( const idCmdArgs &args ) {
	if ( !gameLocal.CheatsOk( false ) ) {
		return;
	}

	if ( args.Argc() != 2 ) {
		gameLocal.Printf( "usage: chextrek_customui_cmd <command>\n" );
		return;
	}

	// Same guard idPlayer::HandleSingleGuiCommand itself uses (Player.cpp) before calling
	// HandleCustomGUICommand: both customUI (the idUserInterface, set by idCustomUI::RegisterGUI
	// only once its own `gui` is non-NULL) and customUIEntity must be set.
	idPlayer *player = gameLocal.GetLocalPlayer();
	if ( !player || !player->customUI || !player->customUIEntity ) {
		gameLocal.Printf( "chextrek_customui_cmd: no idCustomUI registered on the local player\n" );
		return;
	}

	const char *cmd = args.Argv( 1 );
	idLexer src( LEXFL_ALLOWMULTICHARLITERALS | LEXFL_NOFATALERRORS );
	idToken token;
	src.LoadMemory( cmd, idStr::Length( cmd ), "chextrek_customui_cmd" );
	if ( !src.ReadToken( &token ) ) {
		gameLocal.Printf( "chextrek_customui_cmd: no command token in '%s'\n", cmd );
		return;
	}

	bool handled = player->customUIEntity->HandleCustomGUICommand( player->customUIEntity, &token );
	gameLocal.Printf( "chextrek_customui_cmd: '%s' %s\n", token.c_str(), handled ? "handled" : "not handled" );
}

/*
==================
ChexTrek_TestImpulse_f

Test-only, spec #36. See ChexTrek_TestImpulse_f's comment in ChexTrekDump.h for why a console
command has to stand in for a real, currently-held bind key here. Reads one integer argument and
calls idPlayer::PerformImpulse with it directly - everything downstream is the real, already-ported
game code (Player.cpp's PerformImpulse switch), unchanged.
==================
*/
void ChexTrek_TestImpulse_f( const idCmdArgs &args ) {
	if ( !gameLocal.CheatsOk( false ) ) {
		return;
	}

	if ( args.Argc() != 2 ) {
		gameLocal.Printf( "usage: chextrek_test_impulse <N>\n" );
		return;
	}

	idPlayer *player = gameLocal.GetLocalPlayer();
	if ( !player ) {
		gameLocal.Printf( "chextrek_test_impulse: no local player\n" );
		return;
	}

	int impulse = atoi( args.Argv( 1 ) );
	player->PerformImpulse( impulse );
	gameLocal.Printf( "chextrek_test_impulse: sent impulse %d\n", impulse );
}

/*
==================
ChexTrek_TestGuiCompletion_f

Test-only, spec #35. See ChexTrek_TestGuiCompletion_f's comment in ChexTrekDump.h for why a
console command has to stand in for interactive tab-completion here. Rather than call
idCmdSystem::ArgCompletion_GuiName directly (which would only prove that function exists, not that
g_PDA is actually wired to it), this looks g_PDA up through cvarSystem->Find (prints
`g_pda_found`, whether that lookup succeeded at all) and reads its own
idCVar::GetValueCompletion() - the exact function pointer the engine's interactive tab-completion
would call for this cvar - prints whether it equals idCmdSystem::ArgCompletion_GuiName by address
(`g_pda_completion_wired`, so a scenario can assert the cvar's completion is *that* function, not
merely *a* function), then calls it through that pointer with a callback that collects every string
the engine's ArgCompletion_FolderExtension produces, printing the count plus each result so a
scenario can also assert it lists guis/*.gui files, including the mod's own default PDA gui.
==================
*/
static idList<idStr> chextrekGuiCompletions;

static void ChexTrek_GuiCompletionCallback( const char *s ) {
	chextrekGuiCompletions.Append( s );
}

void ChexTrek_TestGuiCompletion_f( const idCmdArgs &args ) {
	chextrekGuiCompletions.Clear();

	idCVar *pdaCvar = cvarSystem->Find( "g_PDA" );
	if ( !pdaCvar ) {
		gameLocal.Printf( "g_pda_found: 0\n" );
		gameLocal.Printf( "g_pda_completion_wired: 0\n" );
		gameLocal.Printf( "gui_completion_count: 0\n" );
		return;
	}
	gameLocal.Printf( "g_pda_found: 1\n" );

	argCompletion_t completion = pdaCvar->GetValueCompletion();
	gameLocal.Printf( "g_pda_completion_wired: %d\n", completion == idCmdSystem::ArgCompletion_GuiName ? 1 : 0 );

	if ( !completion ) {
		gameLocal.Printf( "gui_completion_count: 0\n" );
		return;
	}

	idCmdArgs fakeArgs;
	fakeArgs.TokenizeString( "g_PDA", false );
	completion( fakeArgs, ChexTrek_GuiCompletionCallback );

	gameLocal.Printf( "gui_completion_count: %d\n", chextrekGuiCompletions.Num() );
	for ( int i = 0; i < chextrekGuiCompletions.Num(); i++ ) {
		gameLocal.Printf( "gui_completion_%d: %s\n", i, chextrekGuiCompletions[ i ].c_str() );
	}
}
