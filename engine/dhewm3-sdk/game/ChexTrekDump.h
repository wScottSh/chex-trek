// chextrek: developer-only state-dump console command (spec #28/#29).
//
// Prints the mod's custom state to the game log in a stable, line-based format meant for the
// AFK test harness to parse. This file is the bulk of the test-only code in the library and never
// changes game behavior; #30 adds a little more alongside it for the same reason (a footprint
// counter here, plus a handful of test-only string-literal cvars - see the comment above
// chextrek_test_str1 in ChexTrekDump.cpp), all likewise inert. See decomp-so/reference/coverage.md
// and the spec #28 issue body for the full list of state the finished command will report
// (objective slots, level stats, map/fog-of-war coverage,
// trail/anchor counts, the active custom UI and its GUI state). Each feature sub-issue adds its
// own section under the stable header as that feature lands; #29 only lands the header itself, so
// the harness can prove chextrek.dll (not base.dll) loaded before the game gets past script
// compilation.
#ifndef __CHEXTREK_DUMP_H__
#define __CHEXTREK_DUMP_H__

// Registered as the "chextrek_dump" console command by idGameLocal::InitConsoleCommands.
void ChexTrek_Dump_f( const idCmdArgs &args );

// Prints just the stable header line, with no console-command wrapper. idGameLocal::Init calls
// this once, right after idLib/cvars are up, so the header always reaches the log even when game
// init later aborts (e.g. the known script-compile failure #29's harness proves is still red) -
// before Common::Init ever gets to run queued console commands. The "chextrek_dump" command
// above calls this too, so later scenarios can re-dump on demand once maps are loading.
void ChexTrek_PrintHeader( void );

// chextrek: spec #30. idActor::Event_FootPrint calls this right after each decal it actually
// projects (mtr non-empty). Decal projection itself is a renderer call with no log line, so this
// is the only way a harness scenario can observe "a footprint decal was projected" from the log,
// per the state-dump command's purpose (state the log doesn't already show). Test-only
// instrumentation: it counts calls, it doesn't change what Event_FootPrint does.
void ChexTrek_NoteFootprintProjected( void );

// chextrek: spec #32. idPlayer::addItemText (decomp-so/reference/objectives.md, ported #31) calls
// this right after it queues the item's text, passing the same idItemInfo::name it just queued.
// addItemText's queue (idPlayer::inventory.pickupItemNames) is drained by the stock
// idPlayer::UpdateHud within a frame or two of being filled (it copies each entry into HUD GUI
// state, e.g. "itemtext1", then RemoveIndex(0)s it) - so a scenario's chextrek_dump, which runs
// after a `wait`, can't reliably see the item still sitting in the queue. This hook is the only
// way a scenario can observe "addItemText showed this item's text" from the log, per the
// state-dump command's purpose (state the log doesn't already show). Test-only instrumentation:
// it counts calls and remembers the last name, it doesn't change what addItemText does.
void ChexTrek_NoteItemTextShown( const char *name );

#endif /* !__CHEXTREK_DUMP_H__ */
