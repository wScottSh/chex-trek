// chextrek: developer-only state-dump console command (spec #28/#29). See ChexTrekDump.h.

#include "sys/platform.h"
#include "idlib/LangDict.h"
#include "framework/async/NetworkSystem.h"

#include "gamesys/SysCvar.h"
#include "Game_local.h"

#include "ChexTrekDump.h"

// The harness greps the game log for this exact line to prove chextrek.dll (not base.dll)
// loaded, independent of anything else the command goes on to print. Keep it stable: don't
// change the text or the "v1" tag without updating the harness and docs/dev-setup.md.
static const char *CHEXTREK_DUMP_HEADER = "CHEXTREK-STATE-DUMP v1";

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
ChexTrek_Dump_f

Prints the mod's custom state to the game log for the AFK test harness. #29 lands only the
stable header line; later feature sub-issues append their own state under it (objective slots,
level stats, hud-map/fog-of-war coverage, trail/anchor counts, the active custom UI), per the
state-dump list in spec #28.
==================
*/
void ChexTrek_Dump_f( const idCmdArgs &args ) {
	ChexTrek_PrintHeader();
}
