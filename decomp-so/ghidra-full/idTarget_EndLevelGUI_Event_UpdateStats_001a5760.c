// idTarget_EndLevelGUI::Event_UpdateStats @ 001a5760
// undefined Event_UpdateStats(idTarget_EndLevelGUI * this)

/* WARNING: Function: __i686.get_pc_thunk.bx replaced with injection: get_pc_thunk_bx */
/* idTarget_EndLevelGUI::Event_UpdateStats() */

void __thiscall idTarget_EndLevelGUI::Event_UpdateStats(idTarget_EndLevelGUI *this)

{
  code *pcVar1;
  size_t *psVar2;
  size_t __n;
  undefined *puVar3;
  char cVar4;
  int iVar5;
  idPlayer *piVar6;
  int iVar7;
  undefined1 *puVar8;
  size_t local_50;
  undefined1 *local_4c;
  int local_48;
  undefined1 local_44 [20];
  idStr local_30 [4];
  undefined4 uStack_2c;
  
  if (*(idSoundShader **)(this + 0x2dc) != (idSoundShader *)0x0) {
    idEntity::StartSoundShader
              ((idEntity *)this,*(idSoundShader **)(this + 0x2dc),0,0,false,(int *)0x0);
  }
  puVar3 = PTR_gameLocal_003e0cac;
  local_50 = 0;
  local_48 = 0x14;
  local_4c = local_44;
  local_44[0] = 0;
  iVar5 = *(int *)(this + 0x2e0);
  switch(iVar5) {
  case 0:
  case 1:
  case 2:
    piVar6 = (idPlayer *)idGameLocal::GetLocalPlayer((idGameLocal *)PTR_gameLocal_003e0cac);
    iVar7 = idPlayer::getLevelStats(piVar6);
    cVar4 = updateStats(this,(playerStats_s *)(iVar7 + *(int *)(this + 0x2e0) * 0x14),
                        (playerStats_s *)(this + iVar5 * 0x14 + 0x284));
    if (cVar4 == '\0') goto switchD_001a57ea_default;
    break;
  case 3:
    iVar5 = *(int *)(this + 0x2c0);
    piVar6 = (idPlayer *)idGameLocal::GetLocalPlayer((idGameLocal *)PTR_gameLocal_003e0cac);
    iVar7 = idPlayer::getLevelStats(piVar6);
    if (iVar5 < *(int *)(iVar7 + 0x3c)) {
      iVar5 = *(int *)(this + 0x2c0);
      *(int *)(this + 0x2c0) = iVar5 + *(int *)(this + 0x2d8);
      pcVar1 = *(code **)(**(int **)(this + 0x27c) + 0x38);
      idStr::FormatTime(local_30,"mm:ss:MMM",iVar5 + *(int *)(this + 0x2d8));
      piVar6 = (idPlayer *)idGameLocal::GetLocalPlayer((idGameLocal *)puVar3);
      iVar5 = idPlayer::getLevelStats(piVar6);
      (*pcVar1)(*(undefined4 *)(this + 0x27c),*(undefined4 *)(iVar5 + 0x44),uStack_2c);
      idStr::FreeData(local_30);
      goto switchD_001a57ea_default;
    }
    break;
  case 4:
    idClass::PostEventMS((idClass *)this,(idEventDef *)EV_UpdateEndLevelStats,3000);
    *(int *)(this + 0x2e0) = *(int *)(this + 0x2e0) + 1;
    goto LAB_001a592e;
  case 5:
    iVar5 = idDict::FindKey((idDict *)(this + 100),"extHndNextMap");
    puVar8 = &LAB_00372157_1;
    if (iVar5 != 0) {
      puVar8 = *(undefined1 **)(*(int *)(iVar5 + 4) + 4);
    }
    iVar5 = __strtol_internal(puVar8,0,10,0);
    if (iVar5 == 0) {
      idCustomUI::UnregisterGUI((idCustomUI *)this);
      iVar5 = idDict::FindKey((idDict *)(this + 100),"nextmap");
      if (iVar5 == 0) {
        idStr::operator=((idStr *)&local_50,"");
        idEntity::ActivateTargets((idEntity *)this,(idEntity *)this);
      }
      else {
        psVar2 = *(size_t **)(iVar5 + 4);
        __n = *psVar2;
        if (local_48 < (int)(__n + 1)) {
          idStr::ReAllocate((idStr *)&local_50,__n + 1,false);
        }
        memcpy(local_4c,(void *)psVar2[1],__n);
        puVar3 = PTR_gameLocal_003e0cac;
        local_4c[__n] = 0;
        local_50 = __n;
        idStr::operator=((idStr *)(PTR_gameLocal_003e0cac + 0x251298),"map ");
        iVar5 = local_50 + *(int *)(puVar3 + 0x251298);
        if (*(int *)(puVar3 + 0x2512a0) < iVar5 + 1) {
          idStr::ReAllocate((idStr *)(puVar3 + 0x251298),iVar5 + 1,true);
        }
        if (0 < (int)local_50) {
          iVar7 = 0;
          do {
            *(undefined1 *)(*(int *)(puVar3 + 0x25129c) + *(int *)(puVar3 + 0x251298) + iVar7) =
                 local_4c[iVar7];
            iVar7 = iVar7 + 1;
          } while (iVar7 < (int)local_50);
        }
        *(int *)(puVar3 + 0x251298) = iVar5;
        *(undefined1 *)(*(int *)(puVar3 + 0x25129c) + iVar5) = 0;
      }
    }
LAB_001a592e:
    idStr::FreeData((idStr *)&local_50);
    return;
  case -1:
    *(undefined4 *)(this + 0x2e0) = 0;
  default:
    goto switchD_001a57ea_default;
  }
  *(int *)(this + 0x2e0) = *(int *)(this + 0x2e0) + 1;
switchD_001a57ea_default:
  idClass::PostEventMS
            ((idClass *)this,(idEventDef *)EV_UpdateEndLevelStats,
             *(int *)(*(int *)(PTR_g_statTicTime_003e0608 + 0x2c) + 0x24));
  idStr::FreeData((idStr *)&local_50);
  return;
}

