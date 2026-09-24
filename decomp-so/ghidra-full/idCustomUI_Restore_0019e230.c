// idCustomUI::Restore @ 0019e230
// undefined Restore(idCustomUI * this, idRestoreGame * param_1)
// literals: none

/* WARNING: Function: __i686.get_pc_thunk.bx replaced with injection: get_pc_thunk_bx */
/* idCustomUI::Restore(idRestoreGame*) */

void __thiscall idCustomUI::Restore(idCustomUI *this,idRestoreGame *param_1)

{
  idRestoreGame::ReadUserInterface(param_1,(idUserInterface **)(this + 0x27c));
  idRestoreGame::ReadBool(param_1,(bool *)(this + 0x280));
  if (this[0x280] != (idCustomUI)0x0) {
    RegisterGUI(this);
  }
  return;
}

