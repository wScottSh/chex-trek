// idThread::Event_SpawnDict @ 0024dc00
// undefined Event_SpawnDict(idThread * this, char * param_1)
// literals: none

/* WARNING: Function: __i686.get_pc_thunk.bx replaced with injection: get_pc_thunk_bx */
/* idThread::Event_SpawnDict(char const*) */

void __thiscall idThread::Event_SpawnDict(idThread *this,char *param_1)

{
  int iVar1;
  undefined4 uVar2;
  void *pvVar3;
  idDict *piVar4;
  undefined4 *puVar5;
  int iVar6;
  int local_40;
  int local_3c;
  undefined4 local_38;
  void *local_34;
  undefined4 local_30 [2];
  undefined4 local_28;
  undefined4 local_20;
  idEntity *local_14;
  
  local_14 = (idEntity *)0x24dc0b;
  piVar4 = (idDict *)
           idGameLocal::FindEntityDefDict((idGameLocal *)PTR_gameLocal_003e0cac,param_1,false);
  local_38 = 0x10;
  local_34 = (void *)0x0;
  local_40 = 0;
  local_3c = 0;
  idHashIndex::Init((idHashIndex *)local_30,0x400,0x400);
  pvVar3 = local_34;
  local_38 = 0x10;
  if ((local_34 != (void *)0x0) &&
     (iVar6 = (local_40 + 0xf) - (local_40 + 0xf) % 0x10, iVar6 != local_3c)) {
    if (iVar6 < 1) {
      operator_delete__(local_34);
      local_34 = (void *)0x0;
      local_40 = 0;
      local_3c = 0;
    }
    else {
      if (iVar6 < local_40) {
        local_40 = iVar6;
      }
      local_3c = iVar6;
      local_34 = operator_new__(iVar6 * 8);
      if (0 < local_40) {
        iVar6 = 0;
        do {
          iVar1 = iVar6 * 8;
          puVar5 = (undefined4 *)(iVar6 * 8 + (int)local_34);
          uVar2 = *(undefined4 *)((int)pvVar3 + iVar6 * 8 + 4);
          iVar6 = iVar6 + 1;
          *puVar5 = *(undefined4 *)((int)pvVar3 + iVar1);
          puVar5[1] = uVar2;
        } while (iVar6 < local_40);
      }
      operator_delete__(pvVar3);
    }
  }
  local_20 = 0x10;
  idHashIndex::Free((idHashIndex *)local_30);
  local_30[0] = 0x80;
  local_28 = 0x10;
  idDict::Copy((idDict *)&local_40,piVar4);
  idDict::Copy((idDict *)&local_40,(idDict *)(this + 0x1b40));
  idGameLocal::SpawnEntityDef
            ((idDict *)PTR_gameLocal_003e0cac,(idEntity **)&local_40,SUB41(&local_14,0));
  ReturnEntity(local_14);
  idDict::Clear((idDict *)&local_40);
  idDict::Clear((idDict *)(this + 0x1b40));
  idDict::Clear((idDict *)&local_40);
  idHashIndex::Free((idHashIndex *)local_30);
  if (local_34 != (void *)0x0) {
    operator_delete__(local_34);
  }
  return;
}

