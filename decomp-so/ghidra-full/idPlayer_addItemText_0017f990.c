// idPlayer::addItemText @ 0017f990
// undefined addItemText(idPlayer * this, idItemInfo * param_1)
// literals (read from .rodata; Ghidra address, type, value):
//   00372b4d  string "itemicon"
//   00372b56  string "invPickup"

/* WARNING: Function: __i686.get_pc_thunk.bx replaced with injection: get_pc_thunk_bx */
/* idPlayer::addItemText(idItemInfo const&) */

void __thiscall idPlayer::addItemText(idPlayer *this,idItemInfo *param_1)

{
  size_t sVar1;
  int *piVar2;
  idList<idItemInfo> *this_00;
  idStr *this_01;
  int iVar3;
  
  this_00 = (idList<idItemInfo> *)(this + 0x1404);
  if (*(int *)(this + 0x1410) == 0) {
    idList<idItemInfo>::Resize(this_00,*(int *)(this + 0x140c));
  }
  if (*(int *)(this + 0x1404) == *(int *)(this + 0x1408)) {
    if (*(int *)(this + 0x140c) == 0) {
      *(undefined4 *)(this + 0x140c) = 0x10;
    }
    iVar3 = *(int *)(this + 0x140c) + *(int *)(this + 0x1408);
    idList<idItemInfo>::Resize(this_00,iVar3 - iVar3 % *(int *)(this + 0x140c));
  }
  this_01 = (idStr *)(*(int *)this_00 * 0x40 + *(int *)(this + 0x1410));
  sVar1 = *(size_t *)param_1;
  if (*(int *)(this_01 + 8) < (int)(sVar1 + 1)) {
    idStr::ReAllocate(this_01,sVar1 + 1,false);
  }
  memcpy(*(void **)(this_01 + 4),*(void **)(param_1 + 4),sVar1);
  *(undefined1 *)(*(int *)(this_01 + 4) + sVar1) = 0;
  *(size_t *)this_01 = sVar1;
  sVar1 = *(size_t *)(param_1 + 0x20);
  if (*(int *)(this_01 + 0x28) < (int)(sVar1 + 1)) {
    idStr::ReAllocate(this_01 + 0x20,sVar1 + 1,false);
  }
  memcpy(*(void **)(this_01 + 0x24),*(void **)(param_1 + 0x24),sVar1);
  *(undefined1 *)(*(int *)(this_01 + 0x24) + sVar1) = 0;
  *(size_t *)(this_01 + 0x20) = sVar1;
  *(int *)this_00 = *(int *)this_00 + 1;
  piVar2 = *(int **)(this + 0x1428);
  if (piVar2 != (int *)0x0) {
    (**(code **)(*piVar2 + 0x38))(piVar2,"itemicon",*(undefined4 *)(param_1 + 0x24));
    (**(code **)(**(int **)(this + 0x1428) + 0x24))(*(int **)(this + 0x1428),"invPickup");
  }
  return;
}

