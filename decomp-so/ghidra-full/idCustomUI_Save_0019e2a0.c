// idCustomUI::Save @ 0019e2a0
// undefined Save(idCustomUI * this, idSaveGame * param_1)
// literals: none

/* WARNING: Function: __i686.get_pc_thunk.bx replaced with injection: get_pc_thunk_bx */
/* idCustomUI::Save(idSaveGame*) const */

void __thiscall idCustomUI::Save(idCustomUI *this,idSaveGame *param_1)

{
  idSaveGame::WriteUserInterface(param_1,*(idUserInterface **)(this + 0x27c),false);
  idSaveGame::WriteBool(param_1,(bool)this[0x280]);
  return;
}

