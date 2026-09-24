// matt_func_envshot::Event_envShot @ 002b6e60
// undefined Event_envShot(matt_func_envshot * this)

/* WARNING: Function: __i686.get_pc_thunk.bx replaced with injection: get_pc_thunk_bx */
/* matt_func_envshot::Event_envShot() */

void __thiscall matt_func_envshot::Event_envShot(matt_func_envshot *this)

{
  size_t *psVar1;
  size_t sVar2;
  code *pcVar3;
  undefined4 *__s;
  undefined4 uVar4;
  int *piVar5;
  undefined4 *puVar6;
  int iVar7;
  char cVar8;
  undefined *puVar9;
  idDict *this_00;
  int iVar10;
  int iVar11;
  undefined *local_158;
  char local_141;
  size_t local_110;
  undefined1 *local_10c;
  int local_108;
  undefined1 local_104 [20];
  size_t local_f0;
  undefined1 *local_ec;
  int local_e8;
  undefined1 local_e4 [20];
  size_t local_d0;
  undefined1 *local_cc;
  int local_c8;
  undefined1 local_c4 [20];
  int local_b0;
  char *local_ac;
  int local_a8;
  char local_a4 [20];
  int local_90;
  char *local_8c;
  int local_88;
  char local_84 [20];
  int local_70;
  char *local_6c;
  int local_68;
  char local_64 [20];
  int local_50;
  char *local_4c;
  int local_48;
  char local_44 [20];
  int local_30;
  char *local_2c;
  undefined4 local_28;
  char local_24 [16];
  undefined4 uStack_14;
  
  uStack_14 = 0x2b6e6b;
  __s = operator_new(0x88);
  memset(__s,0,0x88);
  puVar9 = PTR_gameLocal_003e0cac;
  __s[0x15] = *(undefined4 *)(PTR_gameLocal_003e0cac + 0x8fc0);
  __s[0x16] = *(undefined4 *)(puVar9 + 0x8fc4);
  __s[0x17] = *(undefined4 *)(puVar9 + 0x8fc8);
  __s[0x18] = *(undefined4 *)(puVar9 + 0x8fcc);
  __s[0x19] = *(undefined4 *)(puVar9 + 0x8fd0);
  __s[0x1a] = *(undefined4 *)(puVar9 + 0x8fd4);
  __s[0x1b] = *(undefined4 *)(puVar9 + 0x8fd8);
  __s[0x1c] = *(undefined4 *)(puVar9 + 0x8fdc);
  __s[0x1d] = *(undefined4 *)(puVar9 + 0x8fe0);
  __s[0x1e] = *(undefined4 *)(puVar9 + 0x8fe4);
  __s[0x1f] = *(undefined4 *)(puVar9 + 0x8fe8);
  __s[0x20] = *(undefined4 *)(puVar9 + 0x8fec);
  uVar4 = idGameLocal::GetGlobalMaterial((idGameLocal *)puVar9);
  __s[0x21] = uVar4;
  uVar4 = *(undefined4 *)(puVar9 + 0x251884);
  __s[1] = 0;
  __s[2] = 0;
  __s[3] = 0x280;
  __s[0x14] = uVar4;
  __s[4] = 0x1e0;
  *__s = 0;
  __s[10] = 0x3f800000;
  __s[0xb] = 0;
  __s[0xc] = 0;
  __s[0xd] = 0;
  __s[0xe] = 0x3f800000;
  __s[0xf] = 0;
  __s[0x10] = 0;
  __s[0x11] = 0;
  __s[0x12] = 0x3f800000;
  this_00 = (idDict *)(this + 100);
  piVar5 = (int *)idEntity::GetPhysics((idEntity *)this);
  puVar6 = (undefined4 *)(**(code **)(*piVar5 + 0x84))(piVar5,0);
  __s[7] = *puVar6;
  uVar4 = puVar6[2];
  __s[8] = puVar6[1];
  __s[9] = uVar4;
  puVar9 = PTR_gameRenderWorld_003e10a0;
  __s[5] = 0x42b40000;
  __s[6] = 0x42937ae1;
  (**(code **)(**(int **)puVar9 + 0x48))(*(int **)puVar9,__s);
  local_d0 = 0;
  local_c8 = 0x14;
  local_cc = local_c4;
  local_c4[0] = 0;
  local_f0 = 0;
  local_e8 = 0x14;
  local_ec = local_e4;
  local_e4[0] = 0;
  local_10c = local_104;
  local_110 = 0;
  local_108 = 0x14;
  local_104[0] = 0;
  iVar7 = idDict::FindKey(this_00,"name");
  if (iVar7 == 0) {
    idStr::operator=((idStr *)&local_d0,"");
  }
  else {
    psVar1 = *(size_t **)(iVar7 + 4);
    sVar2 = *psVar1;
    if (local_c8 < (int)(sVar2 + 1)) {
      idStr::ReAllocate((idStr *)&local_d0,sVar2 + 1,false);
    }
    memcpy(local_cc,(void *)psVar1[1],sVar2);
    local_cc[sVar2] = 0;
    local_d0 = sVar2;
  }
  iVar7 = idDict::FindKey(this_00,"size");
  if (iVar7 == 0) {
    idStr::operator=((idStr *)&local_f0,"");
  }
  else {
    psVar1 = *(size_t **)(iVar7 + 4);
    sVar2 = *psVar1;
    if (local_e8 < (int)(sVar2 + 1)) {
      idStr::ReAllocate((idStr *)&local_f0,sVar2 + 1,false);
    }
    memcpy(local_ec,(void *)psVar1[1],sVar2);
    local_ec[sVar2] = 0;
    local_f0 = sVar2;
  }
  iVar7 = idDict::FindKey(this_00,"blends");
  if (iVar7 == 0) {
    idStr::operator=((idStr *)&local_110,"");
  }
  else {
    psVar1 = *(size_t **)(iVar7 + 4);
    sVar2 = *psVar1;
    if (local_108 < (int)(sVar2 + 1)) {
      idStr::ReAllocate((idStr *)&local_110,sVar2 + 1,false);
    }
    memcpy(local_10c,(void *)psVar1[1],sVar2);
    local_10c[sVar2] = 0;
    local_110 = sVar2;
  }
  sVar2 = local_d0;
  iVar7 = local_d0 + 8;
  pcVar3 = *(code **)(**(int **)PTR_cmdSystem_003e076c + 0x24);
  local_30 = 8;
  local_28 = 0x14;
  local_2c = local_24;
  builtin_strncpy(local_24,"envShot ",9);
  if (0x14 < (int)(local_d0 + 9)) {
    idStr::ReAllocate((idStr *)&local_30,local_d0 + 9,true);
  }
  if (0 < (int)local_d0) {
    iVar11 = 0;
    do {
      iVar10 = iVar11 + 1;
      local_2c[local_30 + iVar11] = local_cc[iVar11];
      iVar11 = iVar10;
    } while (iVar10 < (int)local_d0);
  }
  local_2c[iVar7] = '\0';
  local_50 = 0;
  local_48 = 0x14;
  local_4c = local_44;
  iVar11 = sVar2 + 9;
  local_44[0] = '\0';
  local_30 = iVar7;
  if (0x14 < iVar11) {
    idStr::ReAllocate((idStr *)&local_50,iVar11,true);
  }
  strcpy(local_4c,local_2c);
  local_50 = iVar7;
  if (local_48 < (int)(sVar2 + 10)) {
    idStr::ReAllocate((idStr *)&local_50,sVar2 + 10,true);
  }
  puVar9 = &DAT_0037e7a9;
  local_141 = ' ';
  iVar7 = 0;
  do {
    local_4c[local_50 + iVar7] = local_141;
    local_141 = puVar9[1];
    puVar9 = puVar9 + 1;
    iVar7 = iVar7 + 1;
  } while (local_141 != '\0');
  local_4c[iVar11] = '\0';
  local_70 = 0;
  local_68 = 0x14;
  local_6c = local_64;
  local_64[0] = '\0';
  local_50 = iVar11;
  if (0x14 < (int)(sVar2 + 10)) {
    idStr::ReAllocate((idStr *)&local_70,sVar2 + 10,true);
  }
  strcpy(local_6c,local_4c);
  iVar7 = iVar11 + local_f0;
  local_70 = iVar11;
  if (local_68 < iVar7 + 1) {
    idStr::ReAllocate((idStr *)&local_70,iVar7 + 1,true);
  }
  local_158 = &DAT_0037e7a9;
  if (0 < (int)local_f0) {
    iVar11 = 0;
    do {
      iVar10 = iVar11 + 1;
      local_6c[local_70 + iVar11] = local_ec[iVar11];
      iVar11 = iVar10;
    } while (iVar10 < (int)local_f0);
  }
  local_6c[iVar7] = '\0';
  local_90 = 0;
  local_88 = 0x14;
  local_8c = local_84;
  iVar11 = iVar7 + 1;
  local_84[0] = '\0';
  local_70 = iVar7;
  if (0x14 < iVar11) {
    idStr::ReAllocate((idStr *)&local_90,iVar11,true);
  }
  strcpy(local_8c,local_6c);
  local_90 = iVar7;
  if (local_88 < iVar7 + 2) {
    idStr::ReAllocate((idStr *)&local_90,iVar7 + 2,true);
  }
  cVar8 = ' ';
  iVar10 = 0;
  do {
    local_8c[local_90 + iVar10] = cVar8;
    cVar8 = local_158[1];
    local_158 = local_158 + 1;
    iVar10 = iVar10 + 1;
  } while (cVar8 != '\0');
  local_8c[iVar11] = '\0';
  local_b0 = 0;
  local_a8 = 0x14;
  local_ac = local_a4;
  local_a4[0] = '\0';
  local_90 = iVar11;
  if (0x14 < iVar7 + 2) {
    idStr::ReAllocate((idStr *)&local_b0,iVar7 + 2,true);
  }
  strcpy(local_ac,local_8c);
  iVar7 = iVar11 + local_110;
  local_b0 = iVar11;
  if (local_a8 < iVar7 + 1) {
    idStr::ReAllocate((idStr *)&local_b0,iVar7 + 1,true);
  }
  if (0 < (int)local_110) {
    iVar11 = 0;
    do {
      iVar10 = iVar11 + 1;
      local_ac[local_b0 + iVar11] = local_10c[iVar11];
      iVar11 = iVar10;
    } while (iVar10 < (int)local_110);
  }
  local_ac[iVar7] = '\0';
  local_b0 = iVar7;
  (*pcVar3)(*(undefined4 *)PTR_cmdSystem_003e076c,0,local_ac);
  idStr::FreeData((idStr *)&local_b0);
  idStr::FreeData((idStr *)&local_90);
  idStr::FreeData((idStr *)&local_70);
  idStr::FreeData((idStr *)&local_50);
  idStr::FreeData((idStr *)&local_30);
  idStr::FreeData((idStr *)&local_110);
  idStr::FreeData((idStr *)&local_f0);
  idStr::FreeData((idStr *)&local_d0);
  return;
}

