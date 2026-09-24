// idTarget_EndLevelGUI::Event_Activate @ 001a3ee0
// undefined Event_Activate(idEntity * param_1)
// literals (Ghidra address of the data, or of the instruction for an immediate; type; value):
//   003710d9  string "gui"
//   0036cc00  string "s_shader"
//   0037412c  string "00:00:000"
//   00374136  string "mapname"
//   0037f468  string ""

/* WARNING: Function: __i686.get_pc_thunk.bx replaced with injection: get_pc_thunk_bx */
/* idTarget_EndLevelGUI::Event_Activate(idEntity*) */

void idTarget_EndLevelGUI::Event_Activate(idEntity *param_1)

{
  idDict *this;
  int *piVar1;
  size_t *psVar2;
  size_t sVar3;
  code *pcVar4;
  idPlayer *this_00;
  int iVar5;
  undefined4 uVar6;
  undefined4 *puVar7;
  char *pcVar8;
  int iVar9;
  idStr *local_60;
  size_t local_50;
  undefined1 *local_4c;
  int local_48;
  undefined1 local_44 [20];
  size_t local_30;
  char *local_2c;
  int local_28;
  char local_24 [20];
  
  piVar1 = *(int **)(param_1 + 0x27c);
  if (piVar1 == (int *)0x0) {
    local_30 = 0;
    local_2c = local_24;
    local_4c = local_44;
    local_50 = 0;
    local_28 = 0x14;
    local_24[0] = '\0';
    local_48 = 0x14;
    local_44[0] = 0;
    this_00 = (idPlayer *)idGameLocal::GetLocalPlayer((idGameLocal *)PTR_gameLocal_003e0cac);
    if (this_00 != (idPlayer *)0x0) {
      iVar9 = *(int *)(PTR_gameLocal_003e0cac + 0x251884);
      iVar5 = idPlayer::getLevelStats(this_00);
      iVar9 = iVar9 - *(int *)(iVar5 + 0x3c);
      iVar5 = idPlayer::getLevelStats(this_00);
      *(int *)(iVar5 + 0x3c) = iVar9;
      *(undefined4 *)(param_1 + 0x2d8) = 1;
      if (100 < iVar9) {
        iVar5 = 1;
        do {
          iVar5 = iVar5 + 1;
        } while ((iVar9 - 0x65U) / 100 + 2 != iVar5);
        *(int *)(param_1 + 0x2d8) = iVar5;
      }
      this = (idDict *)(param_1 + 100);
      iVar9 = idDict::FindKey(this,"gui");
      if (iVar9 != 0) {
        psVar2 = *(size_t **)(iVar9 + 4);
        sVar3 = *psVar2;
        if (local_28 < (int)(sVar3 + 1)) {
          idStr::ReAllocate((idStr *)&local_30,sVar3 + 1,false);
        }
        memcpy(local_2c,(void *)psVar2[1],sVar3);
        local_2c[sVar3] = '\0';
        local_30 = sVar3;
        idCustomUI::setGUI((idCustomUI *)param_1,local_2c);
        iVar9 = idDict::FindKey(this,"s_shader");
        if (iVar9 == 0) {
          idStr::operator=((idStr *)&local_50,"");
        }
        else {
          psVar2 = *(size_t **)(iVar9 + 4);
          sVar3 = *psVar2;
          if (local_48 < (int)(sVar3 + 1)) {
            idStr::ReAllocate((idStr *)&local_50,sVar3 + 1,false);
          }
          memcpy(local_4c,(void *)psVar2[1],sVar3);
          local_4c[sVar3] = 0;
          local_50 = sVar3;
          uVar6 = (**(code **)(**(int **)PTR_declManager_003e13c8 + 0x68))
                            (*(int **)PTR_declManager_003e13c8,local_4c,1);
          *(undefined4 *)(param_1 + 0x2dc) = uVar6;
        }
        if (*(int *)(param_1 + 0x27c) != 0) {
          puVar7 = (undefined4 *)idPlayer::getLevelStats(this_00);
          (**(code **)(**(int **)(param_1 + 0x27c) + 0x40))(*(int **)(param_1 + 0x27c),puVar7[3],0);
          (**(code **)(**(int **)(param_1 + 0x27c) + 0x40))
                    (*(int **)(param_1 + 0x27c),puVar7[2],*puVar7);
          (**(code **)(**(int **)(param_1 + 0x27c) + 0x40))(*(int **)(param_1 + 0x27c),puVar7[4],0);
          (**(code **)(**(int **)(param_1 + 0x27c) + 0x40))(*(int **)(param_1 + 0x27c),puVar7[8],0);
          (**(code **)(**(int **)(param_1 + 0x27c) + 0x40))
                    (*(int **)(param_1 + 0x27c),puVar7[7],puVar7[5]);
          (**(code **)(**(int **)(param_1 + 0x27c) + 0x40))(*(int **)(param_1 + 0x27c),puVar7[9],0);
          (**(code **)(**(int **)(param_1 + 0x27c) + 0x40))
                    (*(int **)(param_1 + 0x27c),puVar7[0xd],0);
          (**(code **)(**(int **)(param_1 + 0x27c) + 0x40))
                    (*(int **)(param_1 + 0x27c),puVar7[0xc],puVar7[10]);
          (**(code **)(**(int **)(param_1 + 0x27c) + 0x40))
                    (*(int **)(param_1 + 0x27c),puVar7[0xe],0);
          (**(code **)(**(int **)(param_1 + 0x27c) + 0x38))
                    (*(int **)(param_1 + 0x27c),puVar7[0x11],"00:00:000");
          pcVar4 = *(code **)(**(int **)(param_1 + 0x27c) + 0x38);
          iVar9 = idDict::FindKey(this,"mapname");
          pcVar8 = "";
          if (iVar9 != 0) {
            pcVar8 = *(char **)(*(int *)(iVar9 + 4) + 4);
          }
          (*pcVar4)(*(undefined4 *)(param_1 + 0x27c),"mapname",pcVar8);
          (**(code **)(**(int **)(param_1 + 0x27c) + 0x58))
                    (*(int **)(param_1 + 0x27c),*(undefined4 *)(PTR_gameLocal_003e0cac + 0x251884),0
                    );
          idCustomUI::RegisterGUI((idCustomUI *)param_1);
          idClass::PostEventMS
                    ((idClass *)param_1,(idEventDef *)EV_UpdateEndLevelStats,
                     *(int *)(*(int *)(PTR_g_statTicTime_003e0608 + 0x2c) + 0x24));
        }
        idStr::FreeData((idStr *)&local_50);
        idStr::FreeData((idStr *)&local_30);
        return;
      }
      idStr::operator=((idStr *)&local_30,"");
    }
    local_60 = (idStr *)&local_30;
    idStr::FreeData((idStr *)&local_50);
    idStr::FreeData(local_60);
  }
  else {
    (**(code **)(*piVar1 + 0x60))(piVar1,*(undefined4 *)(PTR_gameLocal_003e0cac + 0x251884));
  }
  return;
}

