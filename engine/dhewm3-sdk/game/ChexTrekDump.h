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
// by idGameLocal::InitConsoleCommands. AC2 ("g_PDA exists with GUI-name completion") needs g_PDA's
// own registered value-completion function to actually run and list guis/*.gui files, but
// tab-completion itself isn't reachable from a console script (spec #28's harness only drives the
// game through queued commands, not interactive keystrokes) - the same class of gap
// chextrek_customui_cmd (spec #34) closes for a GUI button click, though this one is read-only
// (no CMD_FL_CHEAT, like chextrek_dump - it changes no cvar or game state, just calls a function
// pointer and prints what it returns). This command looks g_PDA up via cvarSystem->Find, reads its
// idCVar::GetValueCompletion(), confirms it's actually idCmdSystem::ArgCompletion_GuiName (not
// just non-NULL) and calls it with "g_PDA" as the completed command name, printing how many
// results it produced plus each one, so a scenario can assert the cvar is really wired to that
// function and that one result names the mod's default PDA GUI ("guis/pda_chex.gui").
void ChexTrek_TestGuiCompletion_f( const idCmdArgs &args );

// chextrek: spec #36, test-only. Registered as the "chextrek_test_impulse" console command by
// idGameLocal::InitConsoleCommands. AC1 ("impulse 23 toggles the map") needs idPlayer::
// PerformImpulse(23) to actually run, but impulses in this engine aren't reachable from a console
// script: the "_impulseN" strings autoexec.cfg/matt.cfg/scott.cfg bind keys to (decomp-so/
// reference/hud-map.md's Notes) are bind-target tokens idUsercmdGenLocal recognizes only from a
// real, currently-held key - typing them directly ("impulse 23" or "_impulse23") is rejected as an
// unknown command (confirmed against this engine build), and there's no plain "impulse" console
// command either. The same class of gap chextrek_customui_cmd (spec #34) closes for a GUI button
// click and chextrek_test_gui_completion (spec #35) closes for interactive tab-completion: this
// command reads one integer argument and calls the local player's PerformImpulse with it directly -
// everything downstream (the switch in PerformImpulse, HandleNamedEvent, the GUI's own onNamedEvent
// blocks) is the real, already-ported game code, unchanged. CMD_FL_CHEAT plus its own
// CheatsOk( false ) check, matching chextrek_customui_cmd.
void ChexTrek_TestImpulse_f( const idCmdArgs &args );

// chextrek: spec #37, test-only. Registered as the "chextrek_test_map_cmd" console command by
// idGameLocal::InitConsoleCommands. AC ("each map_* command changes the map scale/position shown
// in the dump as expected") needs the PDA map's GUI commands (map_zoom_in/out, map_scroll_up/
// down/left/right, map_scroll_center, map_stop - decomp-so/reference/hud-map.md) to actually reach
// idPlayer::HandleSingleGuiCommand, but those only ever arrive, in the real game, from a mouse
// click on the PDA map's buttons (guis/pda.gui, guis/pda_chex.gui onAction) - input the
// console-only harness can't produce, the same class of gap chextrek_customui_cmd (spec #34)
// closes for the end-level stats screen's buttons. This command reads one command-name argument
// and calls the local player's own idEntity::HandleGuiCommands( player, cmd ) - the exact same
// stock entry point a real GUI onAction reaches - so everything downstream (HandleSingleGuiCommand's
// token dispatch, the #37 edit itself, updateMapUI's per-frame use of mapControl) is the real,
// already-ported game code, unchanged. CMD_FL_CHEAT plus its own CheatsOk( false ) check, matching
// chextrek_customui_cmd/chextrek_test_impulse.
void ChexTrek_TestMapCmd_f( const idCmdArgs &args );

// chextrek: spec #37, test-only. Registered as the "chextrek_test_pda_map_open" console command by
// idGameLocal::InitConsoleCommands. idPlayer::updateMap (decomp-so/reference/hud-map.md) only
// applies mapControl's scroll/zoom/center bits to the PDA's own map page (the `!isHud` branch of
// updateMapUI) while the PDA is open AND the PDA gui's own "HudMap" state variable is true - the
// same variable name hud.gui's impulse-23 path uses for the HUD's corner map, but for the PDA it is
// set only by guis/pda_chex.gui's own click-driven script (its "Data" tab button resets the
// hudmap_open window's timeline, `set "gui::HudMap" "1"` at its onTime 5) - a real mouse click on a
// PDA tab, not anything idPlayer's C++ (this sub-issue's scope) drives, and out of the console-only
// harness's reach the same way #34/#35/#36's real inputs were. Since this variable is purely a GUI
// state flag (not a member of idPlayer, and not read or written by any #37 C++), setting it
// directly through idUserInterface::SetStateBool - the same underlying engine call the GUI
// script's own `set "gui::HudMap" "1"` resolves to (not literally the same call site: the real
// click goes through the window-script interpreter, this calls SetStateBool directly) -
// reproducing its real effect with no new C++ decision logic. Takes one
// "0"/"1" argument; requires the local player to have a registered objectiveSystem gui (spec #35's
// idPlayer::GivePDA/TogglePDA path opens one - see tools/test-pda.sh for how a scenario gives the
// player a PDA without mouse/impulse input).
void ChexTrek_TestPdaMapOpen_f( const idCmdArgs &args );

#endif /* !__CHEXTREK_DUMP_H__ */
