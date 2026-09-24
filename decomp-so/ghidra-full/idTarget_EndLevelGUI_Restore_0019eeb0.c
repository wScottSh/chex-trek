// idTarget_EndLevelGUI::Restore @ 0019eeb0
// undefined Restore(idTarget_EndLevelGUI * this, idRestoreGame * param_1)

/* WARNING: Function: __i686.get_pc_thunk.bx replaced with injection: get_pc_thunk_bx */
/* idTarget_EndLevelGUI::Restore(idRestoreGame*) */

void __thiscall idTarget_EndLevelGUI::Restore(idTarget_EndLevelGUI *this,idRestoreGame *param_1)

{
  idRestoreGame::Read(param_1,this + 0x284,0x50);
  idRestoreGame::ReadInt(param_1,(int *)(this + 0x2e0));
  idRestoreGame::ReadInt(param_1,(int *)(this + 0x2d4));
  idRestoreGame::ReadInt(param_1,(int *)(this + 0x2d8));
  if (*(int *)(this + 0x2e0) != -1) {
    idClass::CancelEvents((idClass *)this,(idEventDef *)EV_UpdateEndLevelStats);
    idClass::PostEventMS
              ((idClass *)this,(idEventDef *)EV_UpdateEndLevelStats,
               *(int *)(*(int *)(PTR_g_statTicTime_003e0608 + 0x2c) + 0x24));
  }
  return;
}

