// mkTrail::Spawn @ 002b5540
// undefined Spawn(mkTrail * this)
// literals (Ghidra address of the data, or of the instruction for an immediate; type; value):
//   003814f2  string "mtr_trail"
//   0037f468  string ""
//   003814fc  string "updateDist"
//   0036b527  string "2"
//   00381507  string "trailWidth"
//   00370e03  string "32"
//   00381512  string "anchorDist"
//   00371dbd  string "16"
//   0038151d  string "maxAnchors"
//   00375009  string "15"
//   00381528  string "surfDist"
//   00372016  string "3.0"
//   00381531  string "maxSurfDist"
//   0038153d  string "10.0"
//   00374196  string "fadeTime"
//   00372158  string "0"
//   00381542  string "uvWidth"
//   0036ee48  string ".05"
//   0038154a  string "uvRepeat"
//   0036fbcb  string ".25"
//   00381553  string "1 1 1 0"
//   0038155b  string "startcolor"
//   00372152  string "0 0 0 0"
//   00381566  string "endcolor"

/* WARNING: Function: __i686.get_pc_thunk.bx replaced with injection: get_pc_thunk_bx */
/* mkTrail::Spawn() */

void __thiscall mkTrail::Spawn(mkTrail *this)

{
  idDict *this_00;
  float fVar1;
  code *pcVar2;
  undefined *puVar3;
  int iVar4;
  undefined4 uVar5;
  int *piVar6;
  char *pcVar7;
  longdouble lVar8;
  undefined4 local_30;
  undefined4 local_2c;
  undefined4 local_28;
  undefined4 local_24;
  undefined4 local_20;
  undefined4 local_1c;
  undefined4 local_18;
  undefined4 local_14;
  
  local_14 = 0x2b5549;
  this_00 = (idDict *)(this + 8);
  pcVar2 = *(code **)(**(int **)PTR_declManager_003e13c8 + 0x60);
  iVar4 = idDict::FindKey(this_00,"mtr_trail");
  pcVar7 = "";
  if (iVar4 != 0) {
    pcVar7 = *(char **)(*(int *)(iVar4 + 4) + 4);
  }
  uVar5 = (*pcVar2)(*(undefined4 *)PTR_declManager_003e13c8,pcVar7,1);
  *(undefined4 *)(this + 0x17c) = uVar5;
  memset(this + 0xa4,0,0xd8);
  iVar4 = idDict::FindKey(this_00,"updateDist");
  pcVar7 = "2";
  if (iVar4 != 0) {
    pcVar7 = *(char **)(*(int *)(iVar4 + 4) + 4);
  }
  lVar8 = (longdouble)__strtod_internal(pcVar7,0,0);
  *(float *)(this + 0x50) = (float)lVar8;
  iVar4 = idDict::FindKey(this_00,"trailWidth");
  pcVar7 = "32";
  if (iVar4 != 0) {
    pcVar7 = *(char **)(*(int *)(iVar4 + 4) + 4);
  }
  lVar8 = (longdouble)__strtod_internal(pcVar7,0,0);
  *(float *)(this + 0x4c) = (float)lVar8;
  iVar4 = idDict::FindKey(this_00,"anchorDist");
  pcVar7 = "16";
  if (iVar4 != 0) {
    pcVar7 = *(char **)(*(int *)(iVar4 + 4) + 4);
  }
  lVar8 = (longdouble)__strtod_internal(pcVar7,0,0);
  *(float *)(this + 0x54) = (float)lVar8;
  iVar4 = idDict::FindKey(this_00,"maxAnchors");
  pcVar7 = "15";
  if (iVar4 != 0) {
    pcVar7 = *(char **)(*(int *)(iVar4 + 4) + 4);
  }
  uVar5 = __strtol_internal(pcVar7,0,10,0);
  *(undefined4 *)(this + 0x90) = uVar5;
  iVar4 = idDict::FindKey(this_00,"surfDist");
  pcVar7 = "3.0";
  if (iVar4 != 0) {
    pcVar7 = *(char **)(*(int *)(iVar4 + 4) + 4);
  }
  lVar8 = (longdouble)__strtod_internal(pcVar7,0,0);
  *(float *)(this + 0x58) = (float)lVar8;
  iVar4 = idDict::FindKey(this_00,"maxSurfDist");
  pcVar7 = "10.0";
  if (iVar4 != 0) {
    pcVar7 = *(char **)(*(int *)(iVar4 + 4) + 4);
  }
  lVar8 = (longdouble)__strtod_internal(pcVar7,0,0);
  *(float *)(this + 0x5c) = (float)lVar8;
  iVar4 = idDict::FindKey(this_00,"fadeTime");
  pcVar7 = "0";
  if (iVar4 != 0) {
    pcVar7 = *(char **)(*(int *)(iVar4 + 4) + 4);
  }
  lVar8 = (longdouble)__strtod_internal(pcVar7,0,0);
  *(int *)(this + 0x34) = (int)((float)lVar8 * *(float *)PTR_M_SEC2MS_003e0fc8);
  iVar4 = idDict::FindKey(this_00,"uvWidth");
  pcVar7 = ".05";
  if (iVar4 != 0) {
    pcVar7 = *(char **)(*(int *)(iVar4 + 4) + 4);
  }
  lVar8 = (longdouble)__strtod_internal(pcVar7,0,0);
  *(float *)(this + 100) = (float)lVar8;
  iVar4 = idDict::FindKey(this_00,"uvRepeat");
  pcVar7 = ".25";
  if (iVar4 != 0) {
    pcVar7 = *(char **)(*(int *)(iVar4 + 4) + 4);
  }
  lVar8 = (longdouble)__strtod_internal(pcVar7,0,0);
  puVar3 = PTR_renderModelManager_003e0128;
  *(float *)(this + 0x60) = (float)lVar8;
  piVar6 = (int *)(**(code **)(**(int **)puVar3 + 0x18))(*(int **)puVar3);
  puVar3 = mkTrail_SnapshotName;
  *(int **)(this + 0xa4) = piVar6;
  (**(code **)(*piVar6 + 0x10))(piVar6,puVar3);
  *(undefined **)(this + 200) = PTR_ModelCallback_003e039c;
  fVar1 = *(float *)PTR_INFINITY_003e01a0;
  *(float *)(this + 0xb8) = fVar1;
  *(float *)(this + 0xb4) = fVar1;
  puVar3 = PTR_mat3_identity_003e13e0;
  *(float *)(this + 0xb0) = fVar1;
  fVar1 = -fVar1;
  *(float *)(this + 0xc4) = fVar1;
  *(float *)(this + 0xc0) = fVar1;
  *(float *)(this + 0xbc) = fVar1;
  this[0x16d] = (mkTrail)0x0;
  this[0x16c] = (mkTrail)0x0;
  this[0x16e] = (mkTrail)0x0;
  *(mkTrail **)(this + 0xa8) = this;
  *(mkTrail **)(this + 0x38) = this;
  *(undefined4 *)(this + 0xec) = *(undefined4 *)puVar3;
  *(undefined4 *)(this + 0xf0) = *(undefined4 *)(puVar3 + 4);
  *(undefined4 *)(this + 0xf4) = *(undefined4 *)(puVar3 + 8);
  *(undefined4 *)(this + 0xf8) = *(undefined4 *)(puVar3 + 0xc);
  *(undefined4 *)(this + 0xfc) = *(undefined4 *)(puVar3 + 0x10);
  *(undefined4 *)(this + 0x100) = *(undefined4 *)(puVar3 + 0x14);
  *(undefined4 *)(this + 0x104) = *(undefined4 *)(puVar3 + 0x18);
  *(undefined4 *)(this + 0x108) = *(undefined4 *)(puVar3 + 0x1c);
  *(undefined4 *)(this + 0x10c) = *(undefined4 *)(puVar3 + 0x20);
  *(undefined4 *)(this + 0xe8) = 0;
  *(undefined4 *)(this + 0xe4) = 0;
  *(undefined4 *)(this + 0xe0) = 0;
  idDict::GetVec4(this_00,"startcolor","1 1 1 0",(idVec4 *)&local_30);
  *(undefined4 *)(this + 0x70) = local_30;
  *(undefined4 *)(this + 0x74) = local_2c;
  *(undefined4 *)(this + 0x78) = local_28;
  *(undefined4 *)(this + 0x7c) = local_24;
  *(undefined4 *)(this + 0x120) = *(undefined4 *)(this + 0x70);
  *(undefined4 *)(this + 0x124) = *(undefined4 *)(this + 0x74);
  *(undefined4 *)(this + 0x128) = *(undefined4 *)(this + 0x78);
  *(undefined4 *)(this + 300) = *(undefined4 *)(this + 0x7c);
  idDict::GetVec4(this_00,"endcolor","0 0 0 0",(idVec4 *)&local_20);
  *(undefined4 *)(this + 0x80) = local_20;
  *(undefined4 *)(this + 0x84) = local_1c;
  *(undefined4 *)(this + 0x88) = local_18;
  *(undefined4 *)(this + 0x8c) = local_14;
  uVar5 = (**(code **)(**(int **)PTR_gameRenderWorld_003e10a0 + 0xc))
                    (*(int **)PTR_gameRenderWorld_003e10a0,this + 0xa4);
  *(undefined4 *)(this + 0x3c) = 9;
  *(undefined4 *)(this + 0x188) = uVar5;
  idGameLocal::BabySitTrail((idGameLocal *)PTR_gameLocal_003e0cac,this);
  return;
}

