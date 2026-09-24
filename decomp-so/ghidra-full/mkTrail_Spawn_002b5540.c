// mkTrail::Spawn @ 002b5540
// undefined Spawn(mkTrail * this)

/* WARNING: Function: __i686.get_pc_thunk.bx replaced with injection: get_pc_thunk_bx */
/* mkTrail::Spawn() */

void __thiscall mkTrail::Spawn(mkTrail *this)

{
  idDict *this_00;
  float fVar1;
  code *pcVar2;
  int iVar3;
  undefined4 uVar4;
  int *piVar5;
  undefined *puVar6;
  undefined1 *puVar7;
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
  iVar3 = idDict::FindKey(this_00,"mtr_trail");
  puVar7 = &DAT_0037f468;
  if (iVar3 != 0) {
    puVar7 = *(undefined1 **)(*(int *)(iVar3 + 4) + 4);
  }
  uVar4 = (*pcVar2)(*(undefined4 *)PTR_declManager_003e13c8,puVar7,1);
  *(undefined4 *)(this + 0x17c) = uVar4;
  memset(this + 0xa4,0,0xd8);
  iVar3 = idDict::FindKey(this_00,"updateDist");
  puVar7 = &LAB_0036b527;
  if (iVar3 != 0) {
    puVar7 = *(undefined1 **)(*(int *)(iVar3 + 4) + 4);
  }
  lVar8 = (longdouble)__strtod_internal(puVar7,0,0);
  *(float *)(this + 0x50) = (float)lVar8;
  iVar3 = idDict::FindKey(this_00,"trailWidth");
  puVar7 = &LAB_00370e03;
  if (iVar3 != 0) {
    puVar7 = *(undefined1 **)(*(int *)(iVar3 + 4) + 4);
  }
  lVar8 = (longdouble)__strtod_internal(puVar7,0,0);
  *(float *)(this + 0x4c) = (float)lVar8;
  iVar3 = idDict::FindKey(this_00,"anchorDist");
  puVar7 = &LAB_00371dbc_1;
  if (iVar3 != 0) {
    puVar7 = *(undefined1 **)(*(int *)(iVar3 + 4) + 4);
  }
  lVar8 = (longdouble)__strtod_internal(puVar7,0,0);
  *(float *)(this + 0x54) = (float)lVar8;
  iVar3 = idDict::FindKey(this_00,"maxAnchors");
  puVar7 = &LAB_00375007_2;
  if (iVar3 != 0) {
    puVar7 = *(undefined1 **)(*(int *)(iVar3 + 4) + 4);
  }
  uVar4 = __strtol_internal(puVar7,0,10,0);
  *(undefined4 *)(this + 0x90) = uVar4;
  iVar3 = idDict::FindKey(this_00,"surfDist");
  puVar7 = &LAB_00372013_3;
  if (iVar3 != 0) {
    puVar7 = *(undefined1 **)(*(int *)(iVar3 + 4) + 4);
  }
  lVar8 = (longdouble)__strtod_internal(puVar7,0,0);
  *(float *)(this + 0x58) = (float)lVar8;
  iVar3 = idDict::FindKey(this_00,"maxSurfDist");
  puVar6 = &DAT_0038153d;
  if (iVar3 != 0) {
    puVar6 = *(undefined **)(*(int *)(iVar3 + 4) + 4);
  }
  lVar8 = (longdouble)__strtod_internal(puVar6,0,0);
  *(float *)(this + 0x5c) = (float)lVar8;
  iVar3 = idDict::FindKey(this_00,"fadeTime");
  puVar7 = &LAB_00372157_1;
  if (iVar3 != 0) {
    puVar7 = *(undefined1 **)(*(int *)(iVar3 + 4) + 4);
  }
  lVar8 = (longdouble)__strtod_internal(puVar7,0,0);
  *(int *)(this + 0x34) = (int)((float)lVar8 * *(float *)PTR_M_SEC2MS_003e0fc8);
  iVar3 = idDict::FindKey(this_00,"uvWidth");
  puVar7 = &LAB_0036ee48;
  if (iVar3 != 0) {
    puVar7 = *(undefined1 **)(*(int *)(iVar3 + 4) + 4);
  }
  lVar8 = (longdouble)__strtod_internal(puVar7,0,0);
  *(float *)(this + 100) = (float)lVar8;
  iVar3 = idDict::FindKey(this_00,"uvRepeat");
  puVar7 = &LAB_0036fbca_1;
  if (iVar3 != 0) {
    puVar7 = *(undefined1 **)(*(int *)(iVar3 + 4) + 4);
  }
  lVar8 = (longdouble)__strtod_internal(puVar7,0,0);
  puVar6 = PTR_renderModelManager_003e0128;
  *(float *)(this + 0x60) = (float)lVar8;
  piVar5 = (int *)(**(code **)(**(int **)puVar6 + 0x18))(*(int **)puVar6);
  puVar6 = mkTrail_SnapshotName;
  *(int **)(this + 0xa4) = piVar5;
  (**(code **)(*piVar5 + 0x10))(piVar5,puVar6);
  *(undefined **)(this + 200) = PTR_ModelCallback_003e039c;
  fVar1 = *(float *)PTR_INFINITY_003e01a0;
  *(float *)(this + 0xb8) = fVar1;
  *(float *)(this + 0xb4) = fVar1;
  puVar6 = PTR_mat3_identity_003e13e0;
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
  *(undefined4 *)(this + 0xec) = *(undefined4 *)puVar6;
  *(undefined4 *)(this + 0xf0) = *(undefined4 *)(puVar6 + 4);
  *(undefined4 *)(this + 0xf4) = *(undefined4 *)(puVar6 + 8);
  *(undefined4 *)(this + 0xf8) = *(undefined4 *)(puVar6 + 0xc);
  *(undefined4 *)(this + 0xfc) = *(undefined4 *)(puVar6 + 0x10);
  *(undefined4 *)(this + 0x100) = *(undefined4 *)(puVar6 + 0x14);
  *(undefined4 *)(this + 0x104) = *(undefined4 *)(puVar6 + 0x18);
  *(undefined4 *)(this + 0x108) = *(undefined4 *)(puVar6 + 0x1c);
  *(undefined4 *)(this + 0x10c) = *(undefined4 *)(puVar6 + 0x20);
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
  uVar4 = (**(code **)(**(int **)PTR_gameRenderWorld_003e10a0 + 0xc))
                    (*(int **)PTR_gameRenderWorld_003e10a0,this + 0xa4);
  *(undefined4 *)(this + 0x3c) = 9;
  *(undefined4 *)(this + 0x188) = uVar4;
  idGameLocal::BabySitTrail((idGameLocal *)PTR_gameLocal_003e0cac,this);
  return;
}

