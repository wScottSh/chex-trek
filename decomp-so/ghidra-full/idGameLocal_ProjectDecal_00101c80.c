// idGameLocal::ProjectDecal @ 00101c80
// undefined ProjectDecal(idGameLocal * this, idVec3 * param_1, idVec3 * param_2, float param_3, bool param_4, float param_5, char * param_6, idVec3 * param_7, float param_8)
// literals (Ghidra address of the data, or of the instruction for an immediate; type; value):
//   0036b18c  float  3.0517578E-5
//   0036b0f0  float  -1.0
//   0036d23c  float  -2.605E-7
//   0036d240  float  2.47609E-5
//   0036d244  float  0.0013888397
//   0036d248  float  0.04166664
//   0036b0e4  float  0.5
//   0036b0e8  float  1.5
//   00101f01  float  1.0  (immediate 0x3f800000)
//   0036d24c  float  -2.39E-8
//   0036d250  float  2.7526E-6
//   0036d254  float  1.98409E-4
//   0036d258  float  0.008333332
//   0036d25c  float  0.16666667
//   001020cf  float  1.0  (immediate 0x3f800000)
//   001020da  float  1.0  (immediate 0x3f800000)
//   0010217f  float  1.0  (immediate 0x3f800000)
//   00102186  float  1.0  (immediate 0x3f800000)
//   00102230  float  1.0  (immediate 0x3f800000)
//   00102279  float  1.0  (immediate 0x3f800000)
//   00102416  float  1.0  (immediate 0x3f800000)
//   0010247a  float  1.0  (immediate 0x3f800000)

/* WARNING: Function: __i686.get_pc_thunk.bx replaced with injection: get_pc_thunk_bx */
/* WARNING: Removing unreachable block (ram,0x00102800) */
/* WARNING: Removing unreachable block (ram,0x0010282e) */
/* WARNING: Removing unreachable block (ram,0x001027d0) */
/* WARNING: Removing unreachable block (ram,0x001027f9) */
/* WARNING: Removing unreachable block (ram,0x001027a0) */
/* WARNING: Removing unreachable block (ram,0x001027c9) */
/* WARNING: Removing unreachable block (ram,0x00102770) */
/* WARNING: Removing unreachable block (ram,0x00102799) */
/* idGameLocal::ProjectDecal(idVec3 const&, idVec3 const&, float, bool, float, char const*, idVec3
   const*, float) */

void __thiscall
idGameLocal::ProjectDecal
          (idGameLocal *this,idVec3 *param_1,idVec3 *param_2,float param_3,bool param_4,
          float param_5,char *param_6,idVec3 *param_7,float param_8)

{
  float fVar1;
  float fVar2;
  float fVar3;
  code *pcVar4;
  undefined4 uVar5;
  float fVar6;
  undefined *puVar7;
  uint uVar8;
  undefined4 uVar9;
  undefined2 in_FPUControlWord;
  undefined *local_59c;
  undefined4 local_598;
  float *local_594;
  undefined4 local_590;
  float local_58c;
  float fStack_588;
  float fStack_584;
  undefined4 uStack_580;
  undefined4 uStack_57c;
  float fStack_578;
  float fStack_574;
  float fStack_570;
  undefined4 uStack_56c;
  undefined4 uStack_568;
  float fStack_564;
  float fStack_560;
  float fStack_55c;
  undefined4 uStack_558;
  undefined4 uStack_554;
  float fStack_550;
  float fStack_54c;
  float fStack_548;
  undefined4 uStack_544;
  undefined4 uStack_540;
  float local_8c;
  float local_88;
  undefined4 local_84;
  float local_80;
  float local_7c;
  float local_78;
  float local_68;
  float local_64;
  float local_60;
  float local_5c;
  float local_58;
  float local_54;
  float local_50;
  float local_4c;
  float local_48;
  float local_44;
  float local_40;
  float local_3c;
  undefined4 local_38;
  undefined4 local_34;
  undefined4 uStack_30;
  undefined4 uStack_2c;
  undefined4 uStack_28;
  undefined4 uStack_24;
  undefined4 uStack_20;
  undefined4 uStack_1c;
  float local_18;
  undefined4 uStack_14;
  
  uStack_14 = 0x101c89;
  local_59c = PTR_vtable_003e0f44 + 8;
  local_594 = &local_58c;
  if (*(int *)(*(int *)(PTR_g_decals_003e15d8 + 0x2c) + 0x24) == 0) {
    return;
  }
  if ((param_8 != 0.0) || (NAN(param_8))) {
    if (0.0 <= param_8) goto LAB_00101d87;
LAB_00102619:
    uStack_14 = CONCAT22(in_FPUControlWord,0x1c89);
    param_8 = param_8 - ROUND(param_8 / *(float *)PTR_TWO_PI_003e117c) *
                        *(float *)PTR_TWO_PI_003e117c;
  }
  else {
    uVar8 = *(int *)(this + 0x8ff0) * 0x10dcd + 1;
    *(uint *)(this + 0x8ff0) = uVar8;
    param_8 = (float)(uVar8 & 0x7fff) * 3.0517578E-5 * *(float *)PTR_TWO_PI_003e117c;
    if (param_8 < 0.0) goto LAB_00102619;
LAB_00101d87:
    if (*(float *)PTR_TWO_PI_003e117c <= param_8) goto LAB_00102619;
  }
  puVar7 = PTR_gameRenderWorld_003e10a0;
  fVar1 = *(float *)PTR_PI_003e0238;
  if (fVar1 <= param_8) {
    if (*(float *)PTR_HALF_PI_003e05b4 + fVar1 < param_8) {
      param_8 = param_8 - *(float *)PTR_TWO_PI_003e117c;
      fVar1 = 1.0;
      goto LAB_00101dd6;
    }
  }
  else if (param_8 <= *(float *)PTR_HALF_PI_003e05b4) {
    fVar1 = 1.0;
    goto LAB_00101dd6;
  }
  param_8 = fVar1 - param_8;
  fVar1 = -1.0;
LAB_00101dd6:
  fVar6 = param_8 * param_8;
  fVar1 = (((((-2.605E-7 * fVar6 + 2.47609E-5) * fVar6 - 0.0013888397) * fVar6 +
            0.04166664) * fVar6 - 0.5) * fVar6 + 1.0) * fVar1;
  local_50 = *(float *)param_2;
  local_4c = *(float *)(param_2 + 4);
  fVar2 = *(float *)(param_2 + 8);
  fVar3 = fVar2 * fVar2 + local_4c * local_4c + local_50 * local_50;
  local_48 = (float)((0x17c - ((uint)fVar3 >> 0x17 & 0xff) >> 1) << 0x17 |
                    *(uint *)(PTR_iSqrt_003e0edc + ((uint)fVar3 >> 0xf & 0x1ff) * 4));
  local_48 = (1.5 - local_48 * local_48 * fVar3 * 0.5) * local_48;
  local_48 = local_48 * (1.5 - local_48 * local_48 * fVar3 * 0.5);
  local_50 = local_50 * local_48;
  local_4c = local_4c * local_48;
  local_48 = local_48 * fVar2;
  local_18 = local_4c * local_4c + local_50 * local_50;
  if ((local_18 != 0.0) || (NAN(local_18))) {
    local_88 = (float)((0x17c - ((uint)local_18 >> 0x17 & 0xff) >> 1) << 0x17 |
                      *(uint *)(PTR_iSqrt_003e0edc + ((uint)local_18 >> 0xf & 0x1ff) * 4));
    local_88 = (1.5 - local_88 * local_88 * local_18 * 0.5) * local_88;
    local_88 = (1.5 - local_88 * local_88 * local_18 * 0.5) * local_88;
    local_8c = -local_4c * local_88;
    local_88 = local_88 * local_50;
  }
  else {
    local_8c = 1.0;
    local_88 = 0.0;
    local_18 = fVar3;
  }
  local_78 = local_4c * local_8c - local_50 * local_88;
  local_80 = local_48 * local_88 - local_4c * 0.0;
  local_7c = local_50 * 0.0 - local_48 * local_8c;
  fVar2 = -((((((fVar6 * -2.39E-8 + 2.7526E-6) * fVar6 - 1.98409E-4) * fVar6 +
              0.008333332) * fVar6 - 0.16666667) * fVar6 + 1.0) * param_8);
  local_68 = fVar1 * local_8c + fVar2 * local_80;
  local_64 = local_88 * fVar1 + fVar2 * local_7c;
  local_60 = fVar1 * 0.0 + local_78 * fVar2;
  fVar1 = -fVar1;
  local_5c = local_8c * fVar2 + local_80 * fVar1;
  local_58 = local_88 * fVar2 + local_7c * fVar1;
  local_54 = fVar2 * 0.0 + fVar1 * local_78;
  local_3c = *(float *)(param_1 + 8);
  fStack_548 = param_3 * local_48 + local_3c;
  local_40 = *(float *)(param_1 + 4);
  fStack_54c = param_3 * local_4c + local_40;
  local_44 = *(float *)param_1;
  fStack_550 = param_3 * local_50 + local_44;
  if (param_4) {
    local_44 = local_44 - param_3 * local_50;
    local_40 = local_40 - param_3 * local_4c;
    local_3c = local_3c - param_3 * local_48;
  }
  fVar6 = 0.5 * param_5;
  fVar1 = *(float *)param_7;
  fVar2 = *(float *)(param_7 + 4);
  fVar3 = *(float *)(param_7 + 8);
                    /* catch() { ... } // from try @ 0010215b with catch @ 00102140
                       catch() { ... } // from try @ 00102361 with catch @ 00102140 */
  fStack_584 = (local_48 * fVar3 + local_54 * fVar2 + local_60 * fVar1) * fVar6 + fStack_548;
  fStack_588 = (fVar3 * local_4c + fVar2 * local_58 + fVar1 * local_64) * fVar6 + fStack_54c;
  local_58c = fStack_550 + fVar6 * (fVar3 * local_50 + fVar2 * local_5c + fVar1 * local_68);
  fVar1 = *(float *)(param_7 + 0xc);
  fVar2 = *(float *)(param_7 + 0x10);
  fVar3 = *(float *)(param_7 + 0x14);
  fStack_570 = (local_48 * fVar3 + local_54 * fVar2 + local_60 * fVar1) * fVar6 + fStack_548;
  fStack_574 = (local_4c * fVar3 + local_58 * fVar2 + local_64 * fVar1) * fVar6 + fStack_54c;
  fStack_578 = fStack_550 + fVar6 * (local_50 * fVar3 + local_5c * fVar2 + local_68 * fVar1);
  fVar1 = *(float *)(param_7 + 0x18);
  fVar2 = *(float *)(param_7 + 0x1c);
  fVar3 = *(float *)(param_7 + 0x20);
  uStack_554 = 0;
  uStack_558 = 0;
  fStack_55c = (local_48 * fVar3 + local_54 * fVar2 + local_60 * fVar1) * fVar6 + fStack_548;
  fStack_560 = (local_4c * fVar3 + local_58 * fVar2 + local_64 * fVar1) * fVar6 + fStack_54c;
  fStack_564 = fStack_550 + fVar6 * (local_50 * fVar3 + local_5c * fVar2 + local_68 * fVar1);
  fVar1 = *(float *)(param_7 + 0x24);
  fVar2 = *(float *)(param_7 + 0x28);
  fVar3 = *(float *)(param_7 + 0x2c);
  uStack_568 = 0x3f800000 /* 1.0f */;
  uStack_56c = 0;
  uStack_57c = 0x3f800000 /* 1.0f */;
  uStack_580 = 0x3f800000 /* 1.0f */;
  uStack_540 = 0;
  uStack_544 = 0x3f800000 /* 1.0f */;
  fStack_548 = fStack_548 + fVar6 * (local_48 * fVar3 + local_54 * fVar2 + local_60 * fVar1);
  fStack_54c = fStack_54c + fVar6 * (local_4c * fVar3 + local_58 * fVar2 + local_64 * fVar1);
  fStack_550 = fStack_550 + fVar6 * (local_50 * fVar3 + local_5c * fVar2 + local_68 * fVar1);
  local_598 = 4;
  uStack_1c = 0;
  uStack_20 = 0x3f800000 /* 1.0f */;
  uStack_24 = 0;
  uStack_28 = 0;
  uStack_2c = 0x3f800000 /* 1.0f */;
  uStack_30 = 0;
  local_34 = 0x3f800000 /* 1.0f */;
  local_38 = 0x3f800000 /* 1.0f */;
  local_84 = 0;
  local_590 = 0x40;
  pcVar4 = *(code **)(**(int **)PTR_gameRenderWorld_003e10a0 + 0x34);
  uVar5 = *(undefined4 *)(this + 0x251884);
  uVar9 = (**(code **)(**(int **)PTR_declManager_003e13c8 + 0x60))
                    (*(int **)PTR_declManager_003e13c8,param_6,1);
  (*pcVar4)(*(undefined4 *)puVar7,&local_59c,&local_44,param_4,0.5 * param_3,uVar9,uVar5)
  ;
  return;
}

