// idPlayer::tryOpen @ 0017c420
// undefined tryOpen(void)

/* WARNING: Function: __i686.get_pc_thunk.bx replaced with injection: get_pc_thunk_bx */
/* idPlayer::tryOpen() */

void idPlayer::tryOpen(void)

{
  size_t *psVar1;
  size_t sVar2;
  size_t sVar3;
  undefined *this;
  char cVar4;
  idDoor *this_00;
  int iVar5;
  int iVar6;
  undefined1 *puVar7;
  size_t sVar8;
  idPlayer *unaff_retaddr;
  float local_130;
  trace_s atStack_fc [108];
  size_t local_90;
  char *local_8c;
  int local_88;
  char acStack_84 [20];
  size_t local_70;
  char *local_6c;
  int local_68;
  char acStack_64 [20];
  float local_50;
  float local_4c;
  float local_48;
  float local_44;
  float local_40;
  float local_3c;
  float local_38;
  float local_34;
  float local_30;
  float local_2c;
  float local_28;
  float fStack_24;
  undefined4 uStack_14;
  
  uStack_14 = 0x17c42b;
  GetEyePosition();
  local_40 = local_34;
  local_3c = local_30;
  local_38 = local_2c;
  idAngles::ToForward();
  this = PTR_gameLocal_003e0cac;
  local_48 = fStack_24 * local_130 + local_3c;
  local_4c = local_28 * local_130 + local_40;
  local_50 = local_130 * local_2c + local_44;
  idClip::Translation((idClip *)(PTR_gameLocal_003e0cac + 0x2350a8),atStack_fc,(idVec3 *)&local_44,
                      (idVec3 *)&local_50,(idClipModel *)0x0,(idMat3 *)PTR_mat3_identity_003e13e0,1,
                      (idEntity *)unaff_retaddr);
  this_00 = (idDoor *)idGameLocal::GetTraceEntity((idGameLocal *)this,atStack_fc);
  if (this_00 == (idDoor *)0x0) {
    return;
  }
  iVar5 = (*(code *)**(undefined4 **)this_00)(this_00);
  if (*(int *)(iVar5 + 0x38) < *(int *)(PTR_Type_003e01a8 + 0x38)) {
    return;
  }
  if (*(int *)(PTR_Type_003e01a8 + 0x3c) < *(int *)(iVar5 + 0x38)) {
    return;
  }
  local_70 = 0;
  local_6c = acStack_64;
  local_68 = 0x14;
  acStack_64[0] = '\0';
  iVar5 = idDict::FindKey((idDict *)(this_00 + 100),"requires");
  if (iVar5 == 0) {
                    /* try { // try from 0017c964 to 0018c9bc has its CatchHandler @ 0017ca8e */
    idStr::operator=((idStr *)&local_70,"");
  }
  else {
    psVar1 = *(size_t **)(iVar5 + 4);
    sVar2 = *psVar1;
    if (local_68 < (int)(sVar2 + 1)) {
      idStr::ReAllocate((idStr *)&local_70,sVar2 + 1,false);
    }
    memcpy(local_6c,(void *)psVar1[1],sVar2);
    local_6c[sVar2] = '\0';
    local_70 = sVar2;
  }
  local_90 = 0;
  local_8c = acStack_84;
  local_88 = 0x14;
  acStack_84[0] = '\0';
  iVar5 = idDict::FindKey((idDict *)(this_00 + 100),"lockedtext");
  if (iVar5 == 0) {
    idStr::operator=((idStr *)&local_90,"This door is locked.");
  }
  else {
    psVar1 = *(size_t **)(iVar5 + 4);
    sVar2 = *psVar1;
    if (local_88 < (int)(sVar2 + 1)) {
      idStr::ReAllocate((idStr *)&local_90,sVar2 + 1,false);
    }
    memcpy(local_8c,(void *)psVar1[1],sVar2);
    local_8c[sVar2] = '\0';
    local_90 = sVar2;
  }
  iVar5 = idDoor::IsLocked(this_00);
  if (iVar5 == 0) {
LAB_0017c904:
    idClass::ProcessEvent(this_00,PTR_EV_Activate_003e01ac,0x65,unaff_retaddr);
  }
  else {
    if (local_70 != 0) {
      cVar4 = idGameLocal::RequirementMet
                        ((idGameLocal *)this,(idEntity *)unaff_retaddr,(idStr *)&local_70,0);
      sVar2 = local_70;
      if (cVar4 != '\0') goto LAB_0017c904;
      if (local_70 != 0) {
        if (local_68 < (int)(local_70 + 0xc)) {
          idStr::ReAllocate((idStr *)&local_70,local_70 + 0xc,true);
        }
        sVar3 = local_70;
        sVar8 = 0;
        if ((int)sVar2 < 1) {
          sVar8 = sVar2;
        }
        for (; (int)sVar8 <= (int)sVar3; sVar3 = sVar3 - 1) {
          local_6c[sVar3 + 0xb] = local_6c[sVar3];
        }
        builtin_strncpy(local_6c + sVar8,"You need a ",0xb);
        iVar5 = local_70 + 0xb;
        sVar2 = local_70 + 0x1e;
        iVar6 = local_70 + 0x1f;
        local_70 = iVar5;
        if (local_68 < iVar6) {
          idStr::ReAllocate((idStr *)&local_70,iVar6,true);
        }
        iVar5 = 0;
        cVar4 = ' ';
        puVar7 = &LAB_00372961_4;
        do {
          local_6c[iVar5 + local_70] = cVar4;
          iVar5 = iVar5 + 1;
          cVar4 = puVar7[1];
          puVar7 = puVar7 + 1;
        } while (cVar4 != '\0');
                    /* catch() { ... } // from try @ 0017caab with catch @ 0017c8c0 */
        local_6c[sVar2] = '\0';
        local_70 = sVar2;
        ShowTip(unaff_retaddr,"Door Locked",local_6c,true);
        goto LAB_0017c734;
      }
    }
    ShowTip(unaff_retaddr,"Door Locked",local_8c,true);
  }
LAB_0017c734:
  idStr::FreeData((idStr *)&local_90);
  idStr::FreeData((idStr *)&local_70);
  return;
}

