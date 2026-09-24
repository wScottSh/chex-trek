// idActor::Event_FootPrint @ 000c6210
// undefined Event_FootPrint(idActor * this, char * param_1, char * param_2)

/* WARNING: Function: __i686.get_pc_thunk.bx replaced with injection: get_pc_thunk_bx */
/* WARNING: Globals starting with '_' overlap smaller symbols at the same address */
/* idActor::Event_FootPrint(char const*, char const*) */

void __thiscall idActor::Event_FootPrint(idActor *this,char *param_1,char *param_2)

{
  float fVar1;
  undefined4 uVar2;
  float fVar3;
  float fVar4;
  float fVar5;
  char cVar6;
  int *piVar7;
  undefined4 *puVar8;
  int iVar9;
  char *pcVar10;
  undefined4 uVar11;
  float fVar12;
  undefined1 *puVar13;
  float *pfVar14;
  undefined *puVar15;
  idDict *this_00;
  longdouble lVar16;
  float fStack_12c;
  char *pcStack_128;
  float fStack_114;
  float fStack_110;
  float fStack_10c;
  float fStack_100;
  float fStack_fc;
  undefined4 uStack_f8;
  float fStack_f4;
  float fStack_f0;
  undefined4 uStack_ec;
  float fStack_e8;
  float fStack_e4;
  undefined4 uStack_e0;
  float fStack_dc;
  float fStack_d8;
  undefined4 uStack_d4;
  undefined1 auStack_d0 [28];
  int iStack_b4;
  float fStack_a8;
  float fStack_a4;
  float fStack_a0;
  float fStack_9c;
  float fStack_98;
  float fStack_94;
  undefined4 uStack_90;
  undefined4 uStack_8c;
  undefined4 uStack_88;
  float fStack_84;
  float fStack_80;
  float fStack_7c;
  float fStack_78;
  float fStack_74;
  float fStack_70;
  float fStack_68;
  undefined4 local_60;
  undefined4 local_5c;
  float local_58;
  undefined4 local_54;
  undefined4 local_50;
  float local_4c;
  undefined4 uStack_48;
  undefined4 uStack_44;
  undefined4 uStack_40;
  float fStack_3c;
  float fStack_38;
  float fStack_34;
  undefined4 uStack_30;
  undefined4 uStack_2c;
  undefined4 uStack_28;
  float fStack_24;
  float fStack_20;
  float fStack_1c;
  float fStack_18;
  float fStack_14;
  
  fStack_14 = 1.137217e-39;
  piVar7 = (int *)idEntity::GetPhysics((idEntity *)this);
  cVar6 = (**(code **)(*piVar7 + 0xdc))(piVar7);
  if (cVar6 == '\0') {
    return;
  }
  piVar7 = (int *)idEntity::GetPhysics((idEntity *)this);
  puVar8 = (undefined4 *)(**(code **)(*piVar7 + 0x84))(piVar7,0);
  this_00 = (idDict *)(this + 100);
  local_5c = puVar8[1];
  local_60 = *puVar8;
  fVar12 = (float)puVar8[2];
  local_58 = fVar12;
  local_54 = local_60;
  local_50 = local_5c;
  local_4c = fVar12;
  iVar9 = idDict::FindKey(this_00,"footprint_s_z");
  puVar13 = &LAB_00372157_1;
  if (iVar9 != 0) {
    puVar13 = *(undefined1 **)(*(int *)(iVar9 + 4) + 4);
  }
  lVar16 = (longdouble)__strtod_internal(puVar13,0,0);
  fVar1 = local_58;
  local_4c = fVar12 + (float)lVar16;
  iVar9 = idDict::FindKey(this_00,"footprint_e_z");
  puVar13 = &LAB_0036bec7;
  if (iVar9 != 0) {
    puVar13 = *(undefined1 **)(*(int *)(iVar9 + 4) + 4);
  }
  lVar16 = (longdouble)__strtod_internal(puVar13,0,0);
  local_58 = (float)lVar16 + fVar1;
  cVar6 = (**(code **)(**(int **)PTR_gameRenderWorld_003e10a0 + 0x7c))
                    (*(int **)PTR_gameRenderWorld_003e10a0,auStack_d0,&local_54,&local_60,0x41000000
                     ,0,1);
  if ((cVar6 != '\0') && (iStack_b4 != 0)) {
    pcVar10 = (char *)va("footprint_time_%s",
                         *(undefined4 *)
                          (PTR_sufaceTypeNames_003e1118 + (*(uint *)(iStack_b4 + 100) & 0xf) * 4));
    cVar6 = idDict::GetFloat(this_00,pcVar10,"0",&fStack_14);
    if (cVar6 != '\0') {
      *(uint *)(this + 0xf74) = *(uint *)(iStack_b4 + 100) & 0xf;
      *(int *)(this + 0xf70) =
           (int)(fStack_14 * *(float *)PTR_M_SEC2MS_003e0fc8) +
           *(int *)(PTR_gameLocal_003e0cac + 0x251884);
    }
  }
  if ((*(int *)(this + 0xf74) == -1) ||
     (*(int *)(this + 0xf70) <= *(int *)(PTR_gameLocal_003e0cac + 0x251884))) {
    *(undefined4 *)(this + 0xf74) = 0xffffffff;
  }
  else {
    pcVar10 = (char *)va("mtr_footprint_%s",
                         *(undefined4 *)(PTR_sufaceTypeNames_003e1118 + *(int *)(this + 0xf74) * 4))
    ;
    iVar9 = idDict::FindKey(this_00,pcVar10);
    pcStack_128 = "";
    if ((iVar9 == 0) ||
       (pcStack_128 = *(char **)(*(int *)(iVar9 + 4) + 4), pcStack_128 != (char *)0x0))
    goto LAB_000c64b6;
  }
  iVar9 = idDict::FindKey(this_00,"mtr_footprint");
  pcStack_128 = "";
  if (iVar9 != 0) {
    pcStack_128 = *(char **)(*(int *)(iVar9 + 4) + 4);
  }
LAB_000c64b6:
  if (*pcStack_128 != '\0') {
    iVar9 = idDict::FindKey(this_00,"footprint_scale_x");
    puVar15 = &DAT_0037470c;
    if (iVar9 != 0) {
      puVar15 = *(undefined **)(*(int *)(iVar9 + 4) + 4);
    }
    lVar16 = (longdouble)__strtod_internal(puVar15,0,0);
    fVar12 = (float)lVar16;
    iVar9 = idDict::FindKey(this_00,"footprint_scale_y");
    puVar15 = &DAT_0037470c;
    if (iVar9 != 0) {
      puVar15 = *(undefined **)(*(int *)(iVar9 + 4) + 4);
    }
    lVar16 = (longdouble)__strtod_internal(puVar15,0,0);
    fVar1 = (float)lVar16;
    iVar9 = idDict::FindKey(this_00,"footprint_size");
    puVar13 = &LAB_00371dbc_1;
    if (iVar9 != 0) {
      puVar13 = *(undefined1 **)(*(int *)(iVar9 + 4) + 4);
    }
    lVar16 = (longdouble)__strtod_internal(puVar13,0,0);
    uStack_f8 = 0;
    uStack_ec = 0;
    uStack_e0 = 0;
    uStack_d4 = 0;
    fStack_f4 = -fVar12;
    fStack_e4 = -fVar1;
    fStack_100 = fVar12;
    fStack_fc = fVar1;
    fStack_f0 = fVar1;
    fStack_e8 = fStack_f4;
    fStack_dc = fVar12;
    fStack_d8 = fStack_e4;
    idMat3::ToAngles();
    if (param_2 != (char *)0x0) {
      pcVar10 = (char *)va("footprint_offset_%s",param_1);
      idDict::GetVector(this_00,pcVar10,(char *)0x0,(idVec3 *)&fStack_84);
      puVar15 = PTR_gameLocal_003e0cac;
      uVar2 = *(undefined4 *)(PTR_gameLocal_003e0cac + 0x251884);
      uVar11 = idAnimator::GetJointHandle((idAnimator *)(this + 0x27c),param_2);
      idAnimatedEntity::GetJointWorldTransform
                ((idAnimatedEntity *)this,uVar11,uVar2,&fStack_78,&fStack_a8);
      uStack_90 = 0;
      uStack_8c = 0;
      uStack_88 = 0x3f800000;
      fStack_a0 = *(float *)(this + 0x8e0) * 0.0 + *(float *)(this + 0x8dc) * 0.0 +
                  *(float *)(this + 0x8e4);
      fStack_a4 = fStack_a0 * 0.0;
      fStack_a8 = *(float *)(this + 0x8dc) - fStack_a4;
      fStack_a4 = *(float *)(this + 0x8e0) - fStack_a4;
      fStack_a0 = *(float *)(this + 0x8e4) - fStack_a0;
      fVar3 = *(float *)(this + 0x8ec) * 0.0 + *(float *)(this + 0x8e8) * 0.0 +
              *(float *)(this + 0x8f0);
      fStack_98 = fVar3 * 0.0;
      fStack_9c = *(float *)(this + 0x8e8) - fStack_98;
      fStack_98 = *(float *)(this + 0x8ec) - fStack_98;
      fVar3 = *(float *)(this + 0x8f0) - fVar3;
      fVar1 = fStack_a0 * fStack_a0 + fStack_a4 * fStack_a4 + fStack_a8 * fStack_a8;
      fVar12 = (float)((0x17c - ((uint)fVar1 >> 0x17 & 0xff) >> 1) << 0x17 |
                      *(uint *)(PTR_iSqrt_003e0edc + ((uint)fVar1 >> 0xf & 0x1ff) * 4));
      fVar12 = (_LAB_0036b0e8 - fVar12 * fVar12 * fVar1 * _LAB_0036b0e4) * fVar12;
      fVar12 = fVar12 * (_LAB_0036b0e8 - fVar12 * fVar12 * fVar1 * _LAB_0036b0e4);
      fStack_a8 = fStack_a8 * fVar12;
      fStack_a4 = fStack_a4 * fVar12;
      fStack_a0 = fStack_a0 * fVar12;
      fStack_18 = fVar3 * fVar3 + fStack_98 * fStack_98 + fStack_9c * fStack_9c;
      fStack_94 = (float)((0x17c - ((uint)fStack_18 >> 0x17 & 0xff) >> 1) << 0x17 |
                         *(uint *)(PTR_iSqrt_003e0edc + ((uint)fStack_18 >> 0xf & 0x1ff) * 4));
      fStack_94 = (_LAB_0036b0e8 - fStack_94 * fStack_94 * fStack_18 * _LAB_0036b0e4) * fStack_94;
      fStack_94 = (_LAB_0036b0e8 - fStack_94 * fStack_94 * fStack_18 * _LAB_0036b0e4) * fStack_94;
      fStack_9c = fStack_9c * fStack_94;
      fStack_98 = fStack_98 * fStack_94;
      fStack_94 = fStack_94 * fVar3;
      fVar3 = fStack_84 * fStack_a0;
      fVar5 = fStack_94 * fStack_80;
      fVar4 = fStack_a4 * fStack_84;
      fStack_84 = fStack_7c * 0.0 + fStack_84 * fStack_a8 + fStack_80 * fStack_9c;
      fVar12 = *(float *)PTR_M_DEG2RAD_003dfd70;
      fVar1 = *(float *)PTR_HALF_PI_003e05b4;
      fStack_80 = fStack_98 * fStack_80 + fVar4 + fStack_7c * 0.0;
      fStack_7c = fVar5 + fVar3 + fStack_7c;
      pcVar10 = (char *)va("%s_%s",pcStack_128,param_1);
      uStack_30 = 0;
      uStack_2c = 0;
      uStack_28 = 0xbf800000;
      fStack_1c = fStack_70 + fStack_7c;
      fStack_20 = fStack_74 + fStack_80;
      fStack_24 = fStack_78 + fStack_84;
      idGameLocal::ProjectDecal
                ((idGameLocal *)puVar15,(idVec3 *)&fStack_24,(idVec3 *)&uStack_30,8.0,true,
                 (float)lVar16,pcVar10,(idVec3 *)&fStack_100,fVar1 - fStack_68 * fVar12);
      return;
    }
    if (this[0xf6d] == (idActor)0x0) {
      fStack_114 = *(float *)(this + 0x8f0) * _LAB_0036c143_1;
      fStack_110 = *(float *)(this + 0x8ec) * _LAB_0036c143_1;
      fStack_10c = _LAB_0036c143_1 * *(float *)(this + 0x8e8);
      fStack_12c = *(float *)PTR_HALF_PI_003e05b4 - fStack_68 * *(float *)PTR_M_DEG2RAD_003dfd70;
      puVar13 = (undefined1 *)0x36bf31;
    }
    else {
      fStack_114 = *(float *)(this + 0x8f0) * fRam0036c140;
      fStack_110 = *(float *)(this + 0x8ec) * fRam0036c140;
      fStack_10c = fRam0036c140 * *(float *)(this + 0x8e8);
      fStack_12c = *(float *)PTR_HALF_PI_003e05b4 - fStack_68 * *(float *)PTR_M_DEG2RAD_003dfd70;
      puVar13 = &LAB_0036bf2d_1;
    }
    pcVar10 = (char *)va("%s%s",pcStack_128,puVar13);
    uStack_48 = 0;
    uStack_44 = 0;
    uStack_40 = 0xbf800000;
    piVar7 = (int *)idEntity::GetPhysics((idEntity *)this);
    pfVar14 = (float *)(**(code **)(*piVar7 + 0x84))(piVar7,0);
    fStack_34 = fStack_114 + pfVar14[2];
    fStack_38 = fStack_110 + pfVar14[1];
    fStack_3c = fStack_10c + *pfVar14;
    idGameLocal::ProjectDecal
              ((idGameLocal *)PTR_gameLocal_003e0cac,(idVec3 *)&fStack_3c,(idVec3 *)&uStack_48,8.0,
               true,(float)lVar16,pcVar10,(idVec3 *)&fStack_100,fStack_12c);
    this[0xf6d] = (idActor)((byte)this[0xf6d] ^ 1);
  }
  return;
}

