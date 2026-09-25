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
// way a scenario can observe "addItemText queued this item's text" from the log, per the
// state-dump command's purpose (state the log doesn't already show). It proves addItemText ran
// with a given name (spec #32's AC), not that UpdateHud went on to render it on screen -
// decomp-so/reference/objectives.md's Notes flag that render path (hud.gui's "invPickup"/
// "itemicon" wiring) as not checked. Test-only instrumentation, same pattern as
// ChexTrek_NoteFootprintProjected above (a hook call added to already-ported game code, not to
// this dump-only file): it counts calls and remembers the last name, it doesn't change what
// addItemText does.
void ChexTrek_NoteItemTextShown( const char *name );

// chextrek: spec #34, test-only. Registered as the "chextrek_customui_cmd" console command by
// idGameLocal::InitConsoleCommands. Sends its one argument to the local player's registered
// idCustomUI (idTarget_EndLevelGUI::HandleCustomGUICommand) exactly as idPlayer::
// HandleSingleGuiCommand would - see ChexTrek_CustomUICmd_f in ChexTrekDump.cpp for why a console
// command has to stand in for what a real mouse click on the stats screen produces.
void ChexTrek_CustomUICmd_f( const idCmdArgs &args );

// chextrek: spec #35, test-only. Registered as the "chextrek_test_gui_completion" console command
// by idGameLocal::InitConsoleCommands. AC2 ("g_PDA exists with GUI-name completion") needs
// idCmdSystem::ArgCompletion_GuiName (framework/CmdSystem.h) to actually run and list guis/*.gui
// files, but tab-completion itself isn't reachable from a console script (spec #28's harness only
// drives the game through queued commands, not interactive keystrokes) - the same class of gap
// chextrek_customui_cmd (spec #34) closes for a GUI button click. This command calls
// ArgCompletion_GuiName directly with "g_PDA" as the completed command name and prints how many
// results it produced plus each one, so a scenario can assert the callback actually ran and that
// one result names the mod's default PDA GUI (g_PDA's default, "guis/pda_chex.gui").
void ChexTrek_TestGuiCompletion_f( const idCmdArgs &args );

#endif /* !__CHEXTREK_DUMP_H__ */
