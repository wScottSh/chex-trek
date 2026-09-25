// idGameLocal::GetLevelStats @ 00100800
// undefined GetLevelStats(idGameLocal * this, playerStats_s * param_1)
// literals (Ghidra address of the data, or of the instruction for an immediate; type; value):
//   0036d77a  string "secret"
//   00372158  string "0"
//   0036d781  string "level_item"
//   0036d78c  string "level_monster"

/* WARNING: Function: __i686.get_pc_thunk.bx replaced with injection: get_pc_thunk_bx */
/* idGameLocal::GetLevelStats(playerStats_s*) */

void __thiscall idGameLocal::GetLevelStats(idGameLocal *this,playerStats_s *param_1)

{
  int iVar1;
  char *pcVar2;
  int iVar3;
  
  *(undefined4 *)param_1 = 0;
  *(undefined4 *)(param_1 + 0x14) = 0;
  *(undefined4 *)(param_1 + 0x28) = 0;
  if (*(int *)(this + 0x8f48) < 1) {
    return;
  }
  iVar3 = 0;
  do {
    while (*(int *)(this + iVar3 * 4 + 0xf44) == 0) {
LAB_00100856:
      iVar3 = iVar3 + 1;
      if (*(int *)(this + 0x8f48) <= iVar3) {
        return;
      }
    }
    iVar1 = idDict::FindKey((idDict *)(*(int *)(this + iVar3 * 4 + 0xf44) + 100),"secret");
    pcVar2 = "0";
    if (iVar1 != 0) {
      pcVar2 = *(char **)(*(int *)(iVar1 + 4) + 4);
    }
    iVar1 = __strtol_internal(pcVar2,0,10,0);
    if (iVar1 != 0) {
      *(int *)(param_1 + 0x28) = *(int *)(param_1 + 0x28) + 1;
      goto LAB_00100856;
    }
    iVar1 = idDict::FindKey((idDict *)(*(int *)(this + iVar3 * 4 + 0xf44) + 100),"level_item");
    pcVar2 = "0";
    if (iVar1 != 0) {
      pcVar2 = *(char **)(*(int *)(iVar1 + 4) + 4);
    }
    iVar1 = __strtol_internal(pcVar2,0,10,0);
    if (iVar1 == 0) {
      iVar1 = idDict::FindKey((idDict *)(*(int *)(this + iVar3 * 4 + 0xf44) + 100),"level_monster");
      pcVar2 = "0";
      if (iVar1 != 0) {
        pcVar2 = *(char **)(*(int *)(iVar1 + 4) + 4);
      }
      iVar1 = __strtol_internal(pcVar2,0,10,0);
      if (iVar1 != 0) {
        *(int *)param_1 = *(int *)param_1 + 1;
      }
      goto LAB_00100856;
    }
    iVar3 = iVar3 + 1;
    *(int *)(param_1 + 0x14) = *(int *)(param_1 + 0x14) + 1;
    if (*(int *)(this + 0x8f48) <= iVar3) {
      return;
    }
  } while( true );
}

