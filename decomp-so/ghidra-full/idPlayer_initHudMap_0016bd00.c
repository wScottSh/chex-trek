// idPlayer::initHudMap @ 0016bd00
// undefined initHudMap(idPlayer * this)
// literals (read from .rodata; Ghidra address, type, value):
//   00372152  string "0 0 0 0"
//   0037215a  string "map_coords"
//   003859f8  string "%f"
//   00372165  string "map_level_%d"
//   00372c30  float  131072.0
//   00372172  string "640"
//   00372176  string "map_x"
//   0037217c  string "480"
//   00372180  string "map_y"
//   0036bec8  string "8"
//   00372186  string "map_radius"
//   0037470c  string "1"
//   00372191  string "map_scale"
//   0036b1a4  float  0.0078125
//   00372d6c  string "No map_coords set in world spawn, hud map won't work"

/* WARNING: Function: __i686.get_pc_thunk.bx replaced with injection: get_pc_thunk_bx */
/* idPlayer::initHudMap() */

void __thiscall idPlayer::initHudMap(idPlayer *this)

{
  idStr *this_00;
  undefined4 *puVar1;
  float fVar2;
  char cVar3;
  char *pcVar4;
  size_t sVar5;
  char *pcVar6;
  int iVar7;
  int iVar8;
  idVec4 *piVar9;
  idVec4 *piVar10;
  idStr *piStack_7c;
  size_t sStack_70;
  char *pcStack_6c;
  undefined4 uStack_68;
  char acStack_64 [20];
  undefined4 uStack_50;
  undefined4 *puStack_4c;
  undefined4 uStack_48;
  undefined4 uStack_44;
  undefined4 uStack_40;
  undefined4 uStack_3c;
  undefined2 uStack_38;
  undefined1 uStack_36;
  size_t sStack_30;
  char *pcStack_2c;
  undefined4 uStack_28;
  char acStack_24 [16];
  undefined4 uStack_14;
  
  uStack_14 = 0x16bd09;
  if (*(int *)(PTR_gameLocal_003e0cac + 0x8f68) == 0) {
    return;
  }
  piVar9 = (idVec4 *)(this + 0x1e94);
  cVar3 = idDict::GetVec4((idDict *)(*(int *)(PTR_gameLocal_003e0cac + 0x8f68) + 100),"map_coords",
                          "0 0 0 0",piVar9);
  if (cVar3 == '\0') {
    (**(code **)(**(int **)PTR_common_003e01fc + 0x50))
              (*(int **)PTR_common_003e01fc,"No map_coords set in world spawn, hud map won\'t work")
    ;
  }
  pcVar4 = (char *)idGameLocal::GetMapName((idGameLocal *)PTR_gameLocal_003e0cac);
  sStack_70 = 0;
  uStack_68 = 0x14;
  acStack_64[0] = '\0';
  pcStack_6c = acStack_64;
  if (pcVar4 != (char *)0x0) {
    sVar5 = strlen(pcVar4);
    if (0x14 < (int)(sVar5 + 1)) {
      idStr::ReAllocate((idStr *)&sStack_70,sVar5 + 1,true);
    }
    strcpy(pcStack_6c,pcVar4);
    sStack_70 = sVar5;
  }
  idStr::StripFileExtension((idStr *)&sStack_70);
  uStack_48 = 0x14;
  puStack_4c = &uStack_44;
  uStack_44 = 0x73697567;
  this_00 = (idStr *)(this + 0x1e60);
  uStack_40 = 0x6475682f;
  uStack_3c = 0x70616d5f;
  uStack_38 = 0x2f73;
  uStack_36 = 0;
  uStack_50 = 0xe;
  if (*(int *)(this + 0x1e68) < 0xf) {
    idStr::ReAllocate(this_00,0xf,false);
  }
  puVar1 = *(undefined4 **)(this + 0x1e64);
  *puVar1 = *puStack_4c;
  puVar1[1] = puStack_4c[1];
  puVar1[2] = puStack_4c[2];
  *(undefined2 *)(puVar1 + 3) = *(undefined2 *)(puStack_4c + 3);
  *(undefined1 *)(*(int *)(this + 0x1e64) + 0xe) = 0;
  *(undefined4 *)(this + 0x1e60) = 0xe;
  idStr::FreeData((idStr *)&uStack_50);
  sVar5 = sStack_70;
  piVar10 = (idVec4 *)(sStack_70 - 5);
  if ((int)piVar10 < (int)sStack_70) {
    idStr::Mid((int)&sStack_30,(int)&sStack_70);
    iVar8 = sStack_30 + *(int *)this_00;
    iVar7 = iVar8 + 1;
    if (iVar7 <= *(int *)(this + 0x1e68)) goto LAB_0016bec4;
  }
  else {
    sStack_30 = 0;
    uStack_28 = 0x14;
    pcStack_2c = acStack_24;
    acStack_24[0] = '\0';
    piVar10 = piVar9;
    if (0x14 < (int)(sStack_70 + 1)) {
      idStr::ReAllocate((idStr *)&sStack_30,sStack_70 + 1,true);
      piVar10 = piVar9;
    }
    strcpy(pcStack_2c,pcStack_6c);
    sStack_30 = sVar5;
    iVar8 = sVar5 + *(int *)this_00;
    iVar7 = iVar8 + 1;
    if (iVar7 <= *(int *)(this + 0x1e68)) goto LAB_0016bec4;
  }
  idStr::ReAllocate(this_00,iVar7,true);
LAB_0016bec4:
  piStack_7c = (idStr *)&sStack_30;
  if (0 < (int)sStack_30) {
    iVar7 = 0;
    do {
      *(char *)(*(int *)(this + 0x1e64) + *(int *)this_00 + iVar7) = pcStack_2c[iVar7];
      iVar7 = iVar7 + 1;
    } while (iVar7 < (int)sStack_30);
  }
  *(int *)this_00 = iVar8;
  *(undefined1 *)(*(int *)(this + 0x1e64) + iVar8) = 0;
  idStr::FreeData(piStack_7c);
  pcVar4 = (char *)va("%f",0,0xc1000000,piVar10);
  pcVar6 = (char *)va("map_level_%d",0);
  idDict::GetFloat((idDict *)(*(int *)(PTR_gameLocal_003e0cac + 0x8f68) + 100),pcVar6,pcVar4,
                   (float *)(this + 0x1e80));
  pcVar4 = (char *)va("%f",(double)131072.0);
  pcVar6 = (char *)va("map_level_%d",1);
  idDict::GetFloat((idDict *)(*(int *)(PTR_gameLocal_003e0cac + 0x8f68) + 100),pcVar6,pcVar4,
                   (float *)(this + 0x1e84));
  pcVar4 = (char *)va("%f",(double)131072.0);
  pcVar6 = (char *)va("map_level_%d",2);
  idDict::GetFloat((idDict *)(*(int *)(PTR_gameLocal_003e0cac + 0x8f68) + 100),pcVar6,pcVar4,
                   (float *)(this + 0x1e88));
  pcVar4 = (char *)va("%f",(double)131072.0);
  pcVar6 = (char *)va("map_level_%d",3);
  idDict::GetFloat((idDict *)(*(int *)(PTR_gameLocal_003e0cac + 0x8f68) + 100),pcVar6,pcVar4,
                   (float *)(this + 0x1e8c));
  pcVar4 = (char *)va("%f",(double)131072.0);
  pcVar6 = (char *)va("map_level_%d",4);
  idDict::GetFloat((idDict *)(*(int *)(PTR_gameLocal_003e0cac + 0x8f68) + 100),pcVar6,pcVar4,
                   (float *)(this + 0x1e90));
  idDict::GetFloat((idDict *)(*(int *)(PTR_gameLocal_003e0cac + 0x8f68) + 100),"map_x","640",
                   (float *)(this + 0x1e44));
  idDict::GetFloat((idDict *)(*(int *)(PTR_gameLocal_003e0cac + 0x8f68) + 100),"map_y","480",
                   (float *)(this + 0x1e48));
  idDict::GetInt((idDict *)(*(int *)(PTR_gameLocal_003e0cac + 0x8f68) + 100),"map_radius","8",
                 (int *)(this + 0x1e40));
  idDict::GetFloat((idDict *)(*(int *)(PTR_gameLocal_003e0cac + 0x8f68) + 100),"map_scale","1",
                   (float *)(this + 0x1e34));
  fVar2 = *(float *)(this + 0x1e9c) - *(float *)(this + 0x1e94);
  if (*(float *)(this + 0x1e98) - *(float *)(this + 0x1ea0) < fVar2) {
    fVar2 = *(float *)(this + 0x1e98) - *(float *)(this + 0x1ea0);
  }
  *(float *)(this + 0x1e4c) = fVar2 * 0.0078125;
  idStr::FreeData((idStr *)&sStack_70);
  return;
}

