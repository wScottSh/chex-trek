// idTarget_EndLevelGUI::updateStats @ 0019d4c0
// undefined updateStats(idTarget_EndLevelGUI * this, playerStats_s * param_1, playerStats_s * param_2)

/* WARNING: Function: __i686.get_pc_thunk.bx replaced with injection: get_pc_thunk_bx */
/* idTarget_EndLevelGUI::updateStats(playerStats_s*, playerStats_s*) */

undefined4 __thiscall
idTarget_EndLevelGUI::updateStats
          (idTarget_EndLevelGUI *this,playerStats_s *param_1,playerStats_s *param_2)

{
  int iVar1;
  int iVar2;
  undefined4 uVar3;
  int iVar4;
  
  if (*(int *)param_1 == 0) {
    (**(code **)(**(int **)(this + 0x27c) + 0x40))
              (*(int **)(this + 0x27c),*(undefined4 *)(param_1 + 0x10),100);
    (**(code **)(**(int **)(this + 0x27c) + 0x58))
              (*(int **)(this + 0x27c),*(undefined4 *)(PTR_gameLocal_003e0cac + 0x251884),0);
    uVar3 = 1;
  }
  else {
    uVar3 = 1;
    if (*(int *)param_2 < (*(int *)(param_1 + 4) * 100) / *(int *)param_1) {
      iVar1 = *(int *)param_2 + 1;
      iVar4 = *(int *)(param_2 + 4);
      *(int *)param_2 = iVar1;
      iVar2 = iVar4 * 100;
      if (iVar2 / *(int *)param_1 < iVar1) {
        do {
          iVar2 = iVar2 + 100;
          iVar4 = iVar4 + 1;
        } while (iVar2 / *(int *)param_1 < *(int *)param_2);
        *(int *)(param_2 + 4) = iVar4;
      }
      (**(code **)(**(int **)(this + 0x27c) + 0x40))
                (*(int **)(this + 0x27c),*(undefined4 *)(param_1 + 0xc),iVar4);
      (**(code **)(**(int **)(this + 0x27c) + 0x40))
                (*(int **)(this + 0x27c),*(undefined4 *)(param_1 + 0x10),*(undefined4 *)param_2);
      (**(code **)(**(int **)(this + 0x27c) + 0x58))
                (*(int **)(this + 0x27c),*(undefined4 *)(PTR_gameLocal_003e0cac + 0x251884),0);
      uVar3 = 0;
    }
  }
                    /* catch() { ... } // from try @ 0019d624 with catch @ 0019d5e1 */
  return uVar3;
}

