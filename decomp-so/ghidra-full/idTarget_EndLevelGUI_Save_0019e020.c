// idTarget_EndLevelGUI::Save @ 0019e020
// undefined Save(idTarget_EndLevelGUI * this, idSaveGame * param_1)

/* WARNING: Function: __i686.get_pc_thunk.bx replaced with injection: get_pc_thunk_bx */
/* idTarget_EndLevelGUI::Save(idSaveGame*) const */

void __thiscall idTarget_EndLevelGUI::Save(idTarget_EndLevelGUI *this,idSaveGame *param_1)

{
  idSaveGame::Write(param_1,this + 0x284,0x50);
  idSaveGame::WriteInt(param_1,*(int *)(this + 0x2e0));
  idSaveGame::WriteInt(param_1,*(int *)(this + 0x2d4));
  idSaveGame::WriteInt(param_1,*(int *)(this + 0x2d8));
  return;
}

