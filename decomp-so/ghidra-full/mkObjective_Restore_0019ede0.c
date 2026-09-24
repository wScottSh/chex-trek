// mkObjective::Restore @ 0019ede0
// undefined Restore(mkObjective * this, idRestoreGame * param_1)
// literals: none

/* WARNING: Function: __i686.get_pc_thunk.bx replaced with injection: get_pc_thunk_bx */
/* mkObjective::Restore(idRestoreGame*) */

void __thiscall mkObjective::Restore(mkObjective *this,idRestoreGame *param_1)

{
  idRestoreGame::ReadString(param_1,(idStr *)(this + 0x2a0));
  idRestoreGame::ReadString(param_1,(idStr *)(this + 0x2c4));
  idRestoreGame::ReadString(param_1,(idStr *)(this + 0x280));
  idRestoreGame::ReadBool(param_1,(bool *)(this + 0x2e4));
  if (this[0x2e4] != (mkObjective)0x0) {
    idClass::PostEventMS(this,PTR_EV_Activate_003e01ac,500,0x65,this);
  }
  return;
}

