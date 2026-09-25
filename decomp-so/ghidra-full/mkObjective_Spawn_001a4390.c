// mkObjective::Spawn @ 001a4390
// undefined Spawn(mkObjective * this)
// literals (Ghidra address of the data, or of the instruction for an immediate; type; value):
//   003722fd  string "title"
//   0037413e  string "description"
//   0037414a  string "image"
//   0037f468  string ""

/* WARNING: Function: __i686.get_pc_thunk.bx replaced with injection: get_pc_thunk_bx */
/* mkObjective::Spawn() */

void __thiscall mkObjective::Spawn(mkObjective *this)

{
  size_t *psVar1;
  size_t sVar2;
  idDict *this_00;
  int iVar3;
  
  this_00 = (idDict *)(this + 100);
  iVar3 = idDict::FindKey(this_00,"title");
  if (iVar3 == 0) {
    idStr::operator=((idStr *)(this + 0x2a0),"title");
  }
  else {
    psVar1 = *(size_t **)(iVar3 + 4);
    sVar2 = *psVar1;
    if (*(int *)(this + 0x2a8) < (int)(sVar2 + 1)) {
      idStr::ReAllocate((idStr *)(this + 0x2a0),sVar2 + 1,false);
    }
    memcpy(*(void **)(this + 0x2a4),(void *)psVar1[1],sVar2);
    *(undefined1 *)(*(int *)(this + 0x2a4) + sVar2) = 0;
    *(size_t *)(this + 0x2a0) = sVar2;
  }
  iVar3 = idDict::FindKey(this_00,"description");
  if (iVar3 == 0) {
    idStr::operator=((idStr *)(this + 0x2c4),"description");
  }
  else {
    psVar1 = *(size_t **)(iVar3 + 4);
    sVar2 = *psVar1;
    if (*(int *)(this + 0x2cc) < (int)(sVar2 + 1)) {
      idStr::ReAllocate((idStr *)(this + 0x2c4),sVar2 + 1,false);
    }
    memcpy(*(void **)(this + 0x2c8),(void *)psVar1[1],sVar2);
    *(undefined1 *)(*(int *)(this + 0x2c8) + sVar2) = 0;
    *(size_t *)(this + 0x2c4) = sVar2;
  }
  iVar3 = idDict::FindKey(this_00,"image");
  if (iVar3 == 0) {
    idStr::operator=((idStr *)(this + 0x280),"");
  }
  else {
    psVar1 = *(size_t **)(iVar3 + 4);
    sVar2 = *psVar1;
    if (*(int *)(this + 0x288) < (int)(sVar2 + 1)) {
      idStr::ReAllocate((idStr *)(this + 0x280),sVar2 + 1,false);
    }
    memcpy(*(void **)(this + 0x284),(void *)psVar1[1],sVar2);
    *(undefined1 *)(*(int *)(this + 0x284) + sVar2) = 0;
    *(size_t *)(this + 0x280) = sVar2;
  }
  this[0x2e4] = (mkObjective)0x0;
  return;
}

