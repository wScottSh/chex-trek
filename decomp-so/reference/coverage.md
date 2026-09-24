# Coverage record: custom game code in `gamex86.so`

Which exported custom functions have a verified reference, and which do not yet.

- **Source of the list:** all 84 functions in the complete Ghidra export, `ghidra-full/_index.tsv`
  (Ghidra 12.1.4, "Non-Returning Functions - Discovered" disabled; made with `scripts/ExportCustom.java`,
  `scripts/NoReturnOff.java` and `scripts/targets.txt`).
- **Status:** `covered` = the function is in its group's reference (`reference/<group>.md`) and passes the
  harness (`python decomp-so/verify/verify.py <group>`). `pending` = not reconstructed yet.
- **ELF vaddr** is the symbol-table address. The Ghidra export address is this plus `0x10000` (Ghidra's image base).
- **Symbol** is the mangled `.symtab` name the harness uses to find the function's real byte range (`st_size`).
- **Group** is the planned reference file. Groups: `custom-ui` (#17), `end-level-stats` (#20), `objectives` (#21),
  `hud-map` (#22), `trails` (#23), `door-opening` (#24), `env-shots` (#25), `script-events` (#26).

The harness reads the table below. Keep one function per row and six columns.

## Targets not exported

None. Checked 2026-09-24 against `gamex86.so`'s `.symtab`:

- All 40 method names in `scripts/targets.txt` have at least one exported function.
- Every `.symtab` function whose name mentions one of the 5 custom classes
  (`mkTrail`, `mkObjective`, `matt_func_envshot`, `idCustomUI`, `idTarget_EndLevelGUI`) is exported.

Custom code the export does not reach, by design: code inside stock functions. One example is the `g_PDA` cvar, which
registers `idCmdSystem::ArgCompletion_GuiName` from `Player.cpp`'s static initializer (see `reference/custom-ui.md`).
Edits inside stock function bodies are out of scope for spec #16.

## Functions

| Function | Symbol | ELF vaddr | Ghidra export | Group | Status |
|---|---|---|---|---|---|
| `idActor::Event_FootPrint` | `_ZN7idActor15Event_FootPrintEPKcS1_` | 0xb6210 | idActor_Event_FootPrint_000c6210.c | script-events | pending |
| `idGameLocal::RemoveTrail` | `_ZN11idGameLocal11RemoveTrailEP7mkTrail` | 0xee7f0 | idGameLocal_RemoveTrail_000fe7f0.c | trails | pending |
| `idGameLocal::GetLevelStats` | `_ZN11idGameLocal13GetLevelStatsEP13playerStats_s` | 0xf0800 | idGameLocal_GetLevelStats_00100800.c | end-level-stats | pending |
| `idGameLocal::BabySitTrail` | `_ZN11idGameLocal12BabySitTrailEP7mkTrail` | 0xf2a10 | idGameLocal_BabySitTrail_00102a10.c | trails | pending |
| `idPlayer::incSecretsFound` | `_ZN8idPlayer15incSecretsFoundEv` | 0x14d2e0 | idPlayer_incSecretsFound_0015d2e0.c | end-level-stats | pending |
| `idPlayer::getLevelStats` | `_ZN8idPlayer13getLevelStatsEv` | 0x14d2f0 | idPlayer_getLevelStats_0015d2f0.c | end-level-stats | pending |
| `idPlayer::useCustomUI` | `_ZN8idPlayer11useCustomUIEP15idUserInterfaceP10idCustomUI` | 0x14d300 | idPlayer_useCustomUI_0015d300.c | custom-ui | covered |
| `idPlayer::clearCustomUI` | `_ZN8idPlayer13clearCustomUIEv` | 0x14d320 | idPlayer_clearCustomUI_0015d320.c | custom-ui | covered |
| `idPlayer::MapImageCoords` | `_ZN8idPlayer14MapImageCoordsEffRK6idVec2RS0_` | 0x14d340 | idPlayer_MapImageCoords_0015d340.c | hud-map | pending |
| `idPlayer::freeObjective` | `_ZN8idPlayer13freeObjectiveEi` | 0x14d390 | idPlayer_freeObjective_0015d390.c | objectives | pending |
| `idPlayer::HudMapLevel` | `_ZN8idPlayer11HudMapLevelEPK6idVec3` | 0x14e450 | idPlayer_HudMapLevel_0015e450.c | hud-map | pending |
| `idPlayer::addObjective` | `_ZN8idPlayer12addObjectiveEP11mkObjectiveRK6idVec3Ri` | 0x14e520 | idPlayer_addObjective_0015e520.c | objectives | pending |
| `idPlayer::Cmd_ShowMap_f` | `_ZN8idPlayer13Cmd_ShowMap_fERK9idCmdArgs` | 0x150c00 | idPlayer_Cmd_ShowMap_f_00160c00.c | hud-map | pending |
| `idPlayer::updateMapUI` | `_ZN8idPlayer11updateMapUIEP15idUserInterfaceib` | 0x150eb0 | idPlayer_updateMapUI_00160eb0.c | hud-map | pending |
| `idPlayer::updateHudMapAlpha` | `_ZN8idPlayer17updateHudMapAlphaEi` | 0x154380 | idPlayer_updateHudMapAlpha_00164380.c | hud-map | pending |
| `idPlayer::updateMap` | `_ZN8idPlayer9updateMapEv` | 0x154720 | idPlayer_updateMap_00164720.c | hud-map | pending |
| `idPlayer::initHudMap` | `_ZN8idPlayer10initHudMapEv` | 0x15bd00 | idPlayer_initHudMap_0016bd00.c | hud-map | pending |
| `idPlayer::tryOpen` | `_ZN8idPlayer7tryOpenEv` | 0x16c420 | idPlayer_tryOpen_0017c420.c | door-opening | pending |
| `idPlayer::addItemText` | `_ZN8idPlayer11addItemTextERK10idItemInfo` | 0x16f990 | idPlayer_addItemText_0017f990.c | objectives | pending |
| `idCmdSystem::ArgCompletion_GuiName` | `_ZN11idCmdSystem21ArgCompletion_GuiNameERK9idCmdArgsPFvPKcE` | 0x173a40 | idCmdSystem_ArgCompletion_GuiName_00183a40.c | custom-ui | covered |
| `idCustomUI::GetType` | `_ZNK10idCustomUI7GetTypeEv` | 0x18d3b0 | idCustomUI_GetType_0019d3b0.c | custom-ui | covered |
| `idCustomUI::setGUI` | `_ZN10idCustomUI6setGUIEPKc` | 0x18d3d0 | idCustomUI_setGUI_0019d3d0.c | custom-ui | covered |
| `idTarget_EndLevelGUI::GetType` | `_ZNK20idTarget_EndLevelGUI7GetTypeEv` | 0x18d4a0 | idTarget_EndLevelGUI_GetType_0019d4a0.c | end-level-stats | pending |
| `idTarget_EndLevelGUI::updateStats` | `_ZN20idTarget_EndLevelGUI11updateStatsEP13playerStats_sS1_` | 0x18d4c0 | idTarget_EndLevelGUI_updateStats_0019d4c0.c | end-level-stats | pending |
| `mkObjective::GetType` | `_ZNK11mkObjective7GetTypeEv` | 0x18d640 | mkObjective_GetType_0019d640.c | objectives | pending |
| `mkObjective::CreateInstance` | `_ZN11mkObjective14CreateInstanceEv` | 0x18dc60 | mkObjective_CreateInstance_0019dc60.c | objectives | pending |
| `idCustomUI::idCustomUI` | `_ZN10idCustomUIC1Ev` | 0x18dd60 | idCustomUI_idCustomUI_0019dd60.c | custom-ui | covered |
| `idCustomUI::idCustomUI` | `_ZN10idCustomUIC2Ev` | 0x18ddb0 | idCustomUI_idCustomUI_0019ddb0.c | custom-ui | covered |
| `idTarget_EndLevelGUI::CreateInstance` | `_ZN20idTarget_EndLevelGUI14CreateInstanceEv` | 0x18de00 | idTarget_EndLevelGUI_CreateInstance_0019de00.c | end-level-stats | pending |
| `idTarget_EndLevelGUI::Spawn` | `_ZN20idTarget_EndLevelGUI5SpawnEv` | 0x18dfc0 | idTarget_EndLevelGUI_Spawn_0019dfc0.c | end-level-stats | pending |
| `idTarget_EndLevelGUI::Save` | `_ZNK20idTarget_EndLevelGUI4SaveEP10idSaveGame` | 0x18e020 | idTarget_EndLevelGUI_Save_0019e020.c | end-level-stats | pending |
| `idCustomUI::UnregisterGUI` | `_ZN10idCustomUI13UnregisterGUIEv` | 0x18e0b0 | idCustomUI_UnregisterGUI_0019e0b0.c | custom-ui | covered |
| `idCustomUI::HandleCustomGUICommand` | `_ZN10idCustomUI22HandleCustomGUICommandEP8idEntityP7idToken` | 0x18e130 | idCustomUI_HandleCustomGUICommand_0019e130.c | custom-ui | covered |
| `idCustomUI::Event_Hide` | `_ZN10idCustomUI10Event_HideEv` | 0x18e180 | idCustomUI_Event_Hide_0019e180.c | custom-ui | covered |
| `idCustomUI::RegisterGUI` | `_ZN10idCustomUI11RegisterGUIEv` | 0x18e1c0 | idCustomUI_RegisterGUI_0019e1c0.c | custom-ui | covered |
| `idCustomUI::Restore` | `_ZN10idCustomUI7RestoreEP13idRestoreGame` | 0x18e230 | idCustomUI_Restore_0019e230.c | custom-ui | covered |
| `idCustomUI::Save` | `_ZNK10idCustomUI4SaveEP10idSaveGame` | 0x18e2a0 | idCustomUI_Save_0019e2a0.c | custom-ui | covered |
| `idCustomUI::CreateInstance` | `_ZN10idCustomUI14CreateInstanceEv` | 0x18e300 | idCustomUI_CreateInstance_0019e300.c | custom-ui | covered |
| `mkObjective::Save` | `_ZNK11mkObjective4SaveEP10idSaveGame` | 0x18e8f0 | mkObjective_Save_0019e8f0.c | objectives | pending |
| `mkObjective::Restore` | `_ZN11mkObjective7RestoreEP13idRestoreGame` | 0x18ede0 | mkObjective_Restore_0019ede0.c | objectives | pending |
| `idTarget_EndLevelGUI::Restore` | `_ZN20idTarget_EndLevelGUI7RestoreEP13idRestoreGame` | 0x18eeb0 | idTarget_EndLevelGUI_Restore_0019eeb0.c | end-level-stats | pending |
| `idTarget_EndLevelGUI::HandleCustomGUICommand` | `_ZN20idTarget_EndLevelGUI22HandleCustomGUICommandEP8idEntityP7idToken` | 0x1913c0 | idTarget_EndLevelGUI_HandleCustomGUICommand_001a13c0.c | end-level-stats | pending |
| `mkObjective::AttachToLocalPlayer` | `_ZN11mkObjective19AttachToLocalPlayerEb` | 0x1936b0 | mkObjective_AttachToLocalPlayer_001a36b0.c | objectives | pending |
| `mkObjective::RemoveFromLocalPlayer` | `_ZN11mkObjective21RemoveFromLocalPlayerEb` | 0x193a10 | mkObjective_RemoveFromLocalPlayer_001a3a10.c | objectives | pending |
| `idTarget_EndLevelGUI::Event_Activate` | `_ZN20idTarget_EndLevelGUI14Event_ActivateEP8idEntity` | 0x193ee0 | idTarget_EndLevelGUI_Event_Activate_001a3ee0.c | end-level-stats | pending |
| `mkObjective::Spawn` | `_ZN11mkObjective5SpawnEv` | 0x194390 | mkObjective_Spawn_001a4390.c | objectives | pending |
| `mkObjective::Event_Activate` | `_ZN11mkObjective14Event_ActivateEP8idEntity` | 0x1956a0 | mkObjective_Event_Activate_001a56a0.c | objectives | pending |
| `idTarget_EndLevelGUI::Event_UpdateStats` | `_ZN20idTarget_EndLevelGUI17Event_UpdateStatsEv` | 0x195760 | idTarget_EndLevelGUI_Event_UpdateStats_001a5760.c | end-level-stats | pending |
| `idCustomUI::~idCustomUI` | `_ZN10idCustomUID0Ev` | 0x199100 | idCustomUI_idCustomUI_001a9100.c | custom-ui | covered |
| `idCustomUI::~idCustomUI` | `_ZN10idCustomUID1Ev` | 0x199150 | idCustomUI_idCustomUI_001a9150.c | custom-ui | covered |
| `idTarget_EndLevelGUI::~idTarget_EndLevelGUI` | `_ZN20idTarget_EndLevelGUID1Ev` | 0x199180 | idTarget_EndLevelGUI_idTarget_EndLevelGUI_001a9180.c | end-level-stats | pending |
| `mkObjective::~mkObjective` | `_ZN11mkObjectiveD0Ev` | 0x199280 | mkObjective_mkObjective_001a9280.c | objectives | pending |
| `mkObjective::~mkObjective` | `_ZN11mkObjectiveD1Ev` | 0x199330 | mkObjective_mkObjective_001a9330.c | objectives | pending |
| `idTarget_EndLevelGUI::~idTarget_EndLevelGUI` | `_ZN20idTarget_EndLevelGUID0Ev` | 0x1993e0 | idTarget_EndLevelGUI_idTarget_EndLevelGUI_001a93e0.c | end-level-stats | pending |
| `idWeapon::Event_SetProj` | `_ZN8idWeapon13Event_SetProjEPKc` | 0x19f990 | idWeapon_Event_SetProj_001af990.c | script-events | pending |
| `idAI::OpenDoors` | `_ZN4idAI9OpenDoorsEP8idEntity` | 0x1be950 | idAI_OpenDoors_001ce950.c | door-opening | pending |
| `idAI::Event_OpenDoors` | `_ZN4idAI15Event_OpenDoorsEP8idEntity` | 0x1cc9a0 | idAI_Event_OpenDoors_001dc9a0.c | door-opening | pending |
| `idThread::Event_SpawnDict` | `_ZN8idThread15Event_SpawnDictEPKc` | 0x23dc00 | idThread_Event_SpawnDict_0024dc00.c | script-events | pending |
| `mkTrail::GetType` | `_ZNK7mkTrail7GetTypeEv` | 0x2a3e60 | mkTrail_GetType_002b3e60.c | trails | pending |
| `mkTrail::Save` | `_ZNK7mkTrail4SaveEP10idSaveGame` | 0x2a3eb0 | mkTrail_Save_002b3eb0.c | trails | pending |
| `mkTrail::_GLOBAL__I_Type` | `_GLOBAL__I__ZN7mkTrail4TypeE` | 0x2a4250 | mkTrail__GLOBAL__I_Type_002b4250.c | trails | pending |
| `mkTrail::Think` | `_ZN7mkTrail5ThinkEv` | 0x2a4260 | mkTrail_Think_002b4260.c | trails | pending |
| `mkTrail::UpdateRenderEntity` | `_ZNK7mkTrail18UpdateRenderEntityEP14renderEntity_sPK12renderView_s` | 0x2a4420 | mkTrail_UpdateRenderEntity_002b4420.c | trails | pending |
| `mkTrail::ModelCallback` | `_ZN7mkTrail13ModelCallbackEP14renderEntity_sPK12renderView_s` | 0x2a4c70 | mkTrail_ModelCallback_002b4c70.c | trails | pending |
| `mkTrail::Restore` | `_ZN7mkTrail7RestoreEP13idRestoreGame` | 0x2a4cb0 | mkTrail_Restore_002b4cb0.c | trails | pending |
| `mkTrail::mkTrail` | `_ZN7mkTrailC1Ev` | 0x2a51e0 | mkTrail_mkTrail_002b51e0.c | trails | pending |
| `mkTrail::CreateInstance` | `_ZN7mkTrail14CreateInstanceEv` | 0x2a53f0 | mkTrail_CreateInstance_002b53f0.c | trails | pending |
| `mkTrail::FadeTrail` | `_ZN7mkTrail9FadeTrailEv` | 0x2a5470 | mkTrail_FadeTrail_002b5470.c | trails | pending |
| `mkTrail::Spawn` | `_ZN7mkTrail5SpawnEv` | 0x2a5540 | mkTrail_Spawn_002b5540.c | trails | pending |
| `mkTrail::addNewAnchor` | `_ZN7mkTrail12addNewAnchorEv` | 0x2a59d0 | mkTrail_addNewAnchor_002b59d0.c | trails | pending |
| `mkTrail::Present` | `_ZN7mkTrail7PresentEv` | 0x2a6140 | mkTrail_Present_002b6140.c | trails | pending |
| `mkTrail::~mkTrail` | `_ZN7mkTrailD0Ev` | 0x2a6450 | mkTrail_mkTrail_002b6450.c | trails | pending |
| `mkTrail::mkTrail` | `_ZN7mkTrailC2Ev` | 0x2a65f0 | mkTrail_mkTrail_002b65f0.c | trails | pending |
| `mkTrail::~mkTrail` | `_ZN7mkTrailD1Ev` | 0x2a6800 | mkTrail_mkTrail_002b6800.c | trails | pending |
| `mkTrail::~mkTrail` | `_ZN7mkTrailD2Ev` | 0x2a69a0 | mkTrail_mkTrail_002b69a0.c | trails | pending |
| `matt_func_envshot::GetType` | `_ZNK17matt_func_envshot7GetTypeEv` | 0x2a6b40 | matt_func_envshot_GetType_002b6b40.c | env-shots | pending |
| `matt_func_envshot::Spawn` | `_ZN17matt_func_envshot5SpawnEv` | 0x2a6b90 | matt_func_envshot_Spawn_002b6b90.c | env-shots | pending |
| `matt_func_envshot::CreateInstance` | `_ZN17matt_func_envshot14CreateInstanceEv` | 0x2a6c20 | matt_func_envshot_CreateInstance_002b6c20.c | env-shots | pending |
| `matt_func_envshot::_GLOBAL__I_Type` | `_GLOBAL__I__ZN17matt_func_envshot4TypeE` | 0x2a6e50 | matt_func_envshot__GLOBAL__I_Type_002b6e50.c | env-shots | pending |
| `matt_func_envshot::Event_envShot` | `_ZN17matt_func_envshot13Event_envShotEv` | 0x2a6e60 | matt_func_envshot_Event_envShot_002b6e60.c | env-shots | pending |
| `matt_func_envshot::takeEnvShots_f` | `_ZN17matt_func_envshot14takeEnvShots_fERK9idCmdArgs` | 0x2a7890 | matt_func_envshot_takeEnvShots_f_002b7890.c | env-shots | pending |
| `matt_func_envshot::~matt_func_envshot` | `_ZN17matt_func_envshotD0Ev` | 0x2a7940 | matt_func_envshot_matt_func_envshot_002b7940.c | env-shots | pending |
| `matt_func_envshot::~matt_func_envshot` | `_ZN17matt_func_envshotD1Ev` | 0x2a7990 | matt_func_envshot_matt_func_envshot_002b7990.c | env-shots | pending |
| `idStr::FormatTime` | `_ZN5idStr10FormatTimeEPKci` | 0x344230 | idStr_FormatTime_00354230.c | end-level-stats | pending |
