// chextrek: developer-only state-dump console command (spec #28/#29). See ChexTrekDump.h.

#include "sys/platform.h"
#include "idlib/LangDict.h"
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
