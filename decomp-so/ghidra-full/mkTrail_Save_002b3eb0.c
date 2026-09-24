// mkTrail::Save @ 002b3eb0
// undefined Save(mkTrail * this, idSaveGame * param_1)
// literals: none

/* WARNING: Function: __i686.get_pc_thunk.bx replaced with injection: get_pc_thunk_bx */
/* mkTrail::Save(idSaveGame*) const */

void __thiscall mkTrail::Save(mkTrail *this,idSaveGame *param_1)

{
  int iVar1;
  int iVar2;
  
  idSaveGame::WriteDict(param_1,(idDict *)(this + 8));
  idSaveGame::WriteMaterial(param_1,*(idMaterial **)(this + 0x17c));
  idSaveGame::WriteVec3(param_1,(idVec3 *)(this + 0x40));
  idSaveGame::WriteFloat(param_1,*(float *)(this + 0x4c));
  idSaveGame::WriteFloat(param_1,*(float *)(this + 0x50));
  idSaveGame::WriteFloat(param_1,*(float *)(this + 0x54));
  idSaveGame::WriteFloat(param_1,*(float *)(this + 0x58));
  idSaveGame::WriteFloat(param_1,*(float *)(this + 0x5c));
  idSaveGame::WriteFloat(param_1,*(float *)(this + 0x60));
  idSaveGame::WriteFloat(param_1,*(float *)(this + 100));
  idSaveGame::WriteInt(param_1,*(int *)(this + 0x68));
  idSaveGame::WriteInt(param_1,*(int *)(this + 0x6c));
  idSaveGame::WriteInt(param_1,*(int *)(this + 0x34));
  idSaveGame::WriteVec4(param_1,(idVec4 *)(this + 0x70));
  idSaveGame::WriteVec4(param_1,(idVec4 *)(this + 0x80));
  idSaveGame::WriteInt(param_1,*(int *)(this + 0x90));
  idSaveGame::WriteInt(param_1,*(int *)(this + 0x94));
  if (0 < *(int *)(this + 0x94)) {
    iVar2 = 0;
    do {
      iVar1 = iVar2 * 4;
      iVar2 = iVar2 + 1;
      idSaveGame::Write(param_1,*(void **)(*(int *)(this + 0xa0) + iVar1),0x30);
    } while (iVar2 < *(int *)(this + 0x94));
  }
  idSaveGame::WriteInt(param_1,*(int *)(this + 0x180));
  idSaveGame::WriteBool(param_1,(bool)this[0x184]);
  idSaveGame::WriteInt(param_1,*(int *)(this + 0x3c));
  idSaveGame::WriteInt(param_1,*(int *)(this + 0x188));
  idSaveGame::WriteObject(param_1,*(idClass **)(this + 4));
  return;
}

