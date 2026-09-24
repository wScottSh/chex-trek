// mkObjective::Save @ 0019e8f0
// undefined Save(mkObjective * this, idSaveGame * param_1)
// literals: none

/* WARNING: Function: __i686.get_pc_thunk.bx replaced with injection: get_pc_thunk_bx */
/* mkObjective::Save(idSaveGame*) const */

void __thiscall mkObjective::Save(mkObjective *this,idSaveGame *param_1)

{
  idSaveGame::WriteString(param_1,*(char **)(this + 0x2a4));
  idSaveGame::WriteString(param_1,*(char **)(this + 0x2c8));
  idSaveGame::WriteString(param_1,*(char **)(this + 0x284));
  idSaveGame::WriteBool(param_1,(bool)this[0x2e4]);
  return;
}

