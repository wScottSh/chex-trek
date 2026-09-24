// mkObjective::RemoveFromLocalPlayer @ 001a3a10
// undefined RemoveFromLocalPlayer(mkObjective * this, bool param_1)

/* WARNING: Function: __i686.get_pc_thunk.bx replaced with injection: get_pc_thunk_bx */
/* mkObjective::RemoveFromLocalPlayer(bool) */

void __thiscall mkObjective::RemoveFromLocalPlayer(mkObjective *this,bool param_1)

{
  int *piVar1;
  int *piVar2;
  code *pcVar3;
  size_t *psVar4;
  size_t __n;
  idPlayer *this_00;
  undefined4 uVar5;
  int iVar6;
  size_t local_50;
  undefined1 *local_4c;
  int local_48;
  undefined1 local_44 [20];
  undefined4 local_30;
  undefined1 *local_2c;
  undefined4 local_28;
  undefined1 local_24 [20];
  
  local_4c = local_44;
  local_2c = local_24;
  local_50 = 0;
  local_48 = 0x14;
  local_44[0] = 0;
  local_30 = 0;
  local_28 = 0x14;
  local_24[0] = 0;
  this_00 = (idPlayer *)idGameLocal::GetLocalPlayer((idGameLocal *)PTR_gameLocal_003e0cac);
  if (((this_00 != (idPlayer *)0x0) && (piVar1 = *(int **)(this_00 + 0x142c), piVar1 != (int *)0x0))
     && (piVar2 = *(int **)(this_00 + 0x1428), piVar2 != (int *)0x0)) {
    idPlayer::freeObjective(this_00,*(int *)(this + 0x27c));
    pcVar3 = *(code **)(*piVar1 + 0x3c);
    uVar5 = va("map_obj%d_v",*(undefined4 *)(this + 0x27c));
    (*pcVar3)(piVar1,uVar5,0);
    pcVar3 = *(code **)(*piVar2 + 0x3c);
    uVar5 = va("map_obj%d_v",*(undefined4 *)(this + 0x27c));
    (*pcVar3)(piVar2,uVar5,0);
    if (param_1) {
      iVar6 = idDict::FindKey((idDict *)(this + 100),"rmmsg");
      if (iVar6 == 0) {
        idStr::operator=((idStr *)&local_50,"");
      }
      else {
        psVar4 = *(size_t **)(iVar6 + 4);
        __n = *psVar4;
        if (local_48 < (int)(__n + 1)) {
          idStr::ReAllocate((idStr *)&local_50,__n + 1,false);
        }
        memcpy(local_4c,(void *)psVar4[1],__n);
        local_4c[__n] = 0;
        local_50 = __n;
        idPlayer::addItemText(this_00,(idItemInfo *)&local_50);
      }
    }
  }
  idStr::FreeData((idStr *)&local_30);
  idStr::FreeData((idStr *)&local_50);
  return;
}

