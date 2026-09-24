// idPlayer::addObjective @ 0015e520
// undefined addObjective(idPlayer * this, mkObjective * param_1, idVec3 * param_2, int * param_3)
// literals (read from .rodata; Ghidra address, type, value):
//   00371b3c  string "MAX_OBJS reached!"

/* WARNING: Function: __i686.get_pc_thunk.bx replaced with injection: get_pc_thunk_bx */
/* idPlayer::addObjective(mkObjective*, idVec3 const&, int&) */

undefined4 __thiscall
idPlayer::addObjective(idPlayer *this,mkObjective *param_1,idVec3 *param_2,int *param_3)

{
  int iVar1;
  int iVar2;
  idPlayer *piVar3;
  
  iVar2 = *(int *)(this + 0x1f08);
  if (iVar2 != 5) {
    iVar1 = *(int *)(this + iVar2 * 4 + 0x1ef4);
    piVar3 = this + iVar2 * 4 + 0x1ef4;
    while( true ) {
      if (iVar1 == 0) {
        *(mkObjective **)(this + iVar2 * 4 + 0x1ef4) = param_1;
        *(int *)(this + 0x1f08) = iVar2 + 1;
        iVar2 = HudMapLevel(this,param_2);
        *param_3 = iVar2;
        return *(undefined4 *)(this + 0x1f08);
      }
      iVar2 = iVar2 + 1;
      *(int *)(this + 0x1f08) = iVar2;
      if (iVar2 == 5) break;
      iVar1 = *(int *)(piVar3 + 4);
      piVar3 = piVar3 + 4;
    }
  }
  idGameLocal::Warning((idGameLocal *)PTR_gameLocal_003e0cac,"MAX_OBJS reached!");
  return 0xffffffff;
}

