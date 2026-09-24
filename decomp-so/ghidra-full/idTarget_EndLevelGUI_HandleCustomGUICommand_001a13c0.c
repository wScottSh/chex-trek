// idTarget_EndLevelGUI::HandleCustomGUICommand @ 001a13c0
// undefined HandleCustomGUICommand(idTarget_EndLevelGUI * this, idEntity * param_1, idToken * param_2)
// literals (read from .rodata; Ghidra address, type, value):
//   00374024  string "nextmap"
//   0037402c  string "skip"
//   00373d09  string "unregister"
//   00374031  string "mm:ss:MMM"

/* WARNING: Function: __i686.get_pc_thunk.bx replaced with injection: get_pc_thunk_bx */
/* idTarget_EndLevelGUI::HandleCustomGUICommand(idEntity*, idToken*) */

undefined4 __thiscall
idTarget_EndLevelGUI::HandleCustomGUICommand
          (idTarget_EndLevelGUI *this,idEntity *param_1,idToken *param_2)

{
  int *piVar1;
  code *pcVar2;
  int iVar3;
  idPlayer *this_00;
  int iVar4;
  undefined4 uVar5;
  idStr local_30 [4];
  undefined4 uStack_2c;
  
  iVar3 = idStr::Icmp(*(char **)(param_2 + 4),"nextmap");
  if (iVar3 == 0) {
    uVar5 = 1;
    *(undefined4 *)(this + 0x2e0) = 5;
  }
  else {
    iVar3 = idStr::Icmp(*(char **)(param_2 + 4),"skip");
    if (iVar3 == 0) {
      this_00 = (idPlayer *)idGameLocal::GetLocalPlayer((idGameLocal *)PTR_gameLocal_003e0cac);
      iVar4 = idPlayer::getLevelStats(this_00);
      iVar3 = *(int *)(this + 0x2e0);
      if (-1 < iVar3) {
        if (iVar3 < 3) {
          iVar3 = iVar4 + iVar3 * 0x14;
          (**(code **)(**(int **)(this + 0x27c) + 0x40))
                    (*(int **)(this + 0x27c),*(undefined4 *)(iVar3 + 0xc),*(undefined4 *)(iVar3 + 4)
                    );
          piVar1 = (int *)(iVar4 + *(int *)(this + 0x2e0) * 0x14);
          iVar3 = 100;
          if (*piVar1 != 0) {
            iVar3 = (piVar1[1] * 100) / *piVar1;
          }
          (**(code **)(**(int **)(this + 0x27c) + 0x40))(*(int **)(this + 0x27c),piVar1[4],iVar3);
          *(int *)(this + 0x2e0) = *(int *)(this + 0x2e0) + 1;
        }
        else if (iVar3 == 3) {
          pcVar2 = *(code **)(**(int **)(this + 0x27c) + 0x38);
          idStr::FormatTime(local_30,"mm:ss:MMM",*(int *)(iVar4 + 0x3c));
          (*pcVar2)(*(undefined4 *)(this + 0x27c),*(undefined4 *)(iVar4 + 0x44),uStack_2c);
          idStr::FreeData(local_30);
          *(int *)(this + 0x2e0) = *(int *)(this + 0x2e0) + 1;
        }
      }
      (**(code **)(**(int **)(this + 0x27c) + 0x58))
                (*(int **)(this + 0x27c),*(undefined4 *)(PTR_gameLocal_003e0cac + 0x251884),0);
      uVar5 = 1;
    }
    else {
      iVar3 = idStr::Icmp(*(char **)(param_2 + 4),"unregister");
      uVar5 = 0;
      if (iVar3 == 0) {
        idClass::CancelEvents((idClass *)this,(idEventDef *)EV_UpdateEndLevelStats);
        idCustomUI::UnregisterGUI((idCustomUI *)this);
        uVar5 = 1;
      }
    }
  }
  return uVar5;
}

