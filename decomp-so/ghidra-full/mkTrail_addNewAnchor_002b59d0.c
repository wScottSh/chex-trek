// mkTrail::addNewAnchor @ 002b59d0
// undefined addNewAnchor(mkTrail * this)
// literals (read from .rodata; Ghidra address, type, value):
//   0036b0e4  float  0.5
//   0036b0e8  float  1.5
//   0036d260  float  -0.5

/* WARNING: Function: __i686.get_pc_thunk.bx replaced with injection: get_pc_thunk_bx */
/* mkTrail::addNewAnchor() */

undefined4 __thiscall mkTrail::addNewAnchor(mkTrail *this)

{
  float *pfVar1;
  int iVar2;
  float fVar3;
  float fVar4;
  float fVar5;
  char cVar6;
  float *pfVar7;
  float fVar8;
  int iVar9;
  void *pvVar10;
  void *pvVar11;
  float fVar12;
  int iVar13;
  float fVar14;
  mkTrail *pmVar15;
  float *local_c4;
  float local_ac;
  float local_a8;
  float local_a4;
  float local_a0;
  float local_40;
  float local_3c;
  float local_38;
  undefined4 local_34;
  undefined4 local_30;
  undefined4 local_2c;
  float local_28;
  float local_24;
  float local_20;
  
  local_30 = *(undefined4 *)(this + 0x40);
  local_2c = *(undefined4 *)(this + 0x44);
  local_28 = *(float *)(this + 0x48) - *(float *)(this + 0x5c);
  idClip::Translation((idClip *)(PTR_gameLocal_003e0cac + 0x2350a8),(trace_s *)&local_ac,
                      (idVec3 *)(this + 0x40),(idVec3 *)&local_30,(idClipModel *)0x0,
                      (idMat3 *)PTR_mat3_identity_003e13e0,2,*(idEntity **)(this + 4));
  fVar5 = 0.5;
  if (1.0 <= local_ac) {
    return 0;
  }
  pmVar15 = this + 0x94;
  if (*(int *)(this + 0x94) != 0) {
    pfVar7 = *(float **)(*(int *)(this + 0xa0) + -4 + *(int *)(this + 0x94) * 4);
    local_20 = (pfVar7[2] - *(float *)(this + 0x48)) * (pfVar7[2] - *(float *)(this + 0x48)) +
               (pfVar7[1] - *(float *)(this + 0x44)) * (pfVar7[1] - *(float *)(this + 0x44)) +
               (*pfVar7 - *(float *)(this + 0x40)) * (*pfVar7 - *(float *)(this + 0x40));
    local_24 = (float)(0x5f3759df - ((int)local_20 >> 1));
    if (local_20 * (1.5 - local_24 * local_24 * local_20 * 0.5) * local_24 <=
        *(float *)(this + 0x54)) {
      return 0;
    }
  }
  pfVar7 = operator_new(0x30);
  iVar13 = *(int *)(this + 4);
  if (iVar13 == 0) {
    iVar13 = *(int *)(*(int *)(this + 0xa0) + (*(int *)(this + 0x94) + -1) * 4);
    pfVar7[3] = *(float *)(iVar13 + 0xc);
    pfVar7[4] = *(float *)(iVar13 + 0x10);
    pfVar7[5] = *(float *)(iVar13 + 0x14);
  }
  else {
    pfVar7[3] = *(float *)(iVar13 + 0x8e8);
    pfVar7[4] = *(float *)(iVar13 + 0x8ec);
    pfVar7[5] = *(float *)(iVar13 + 0x8f0);
  }
  local_c4 = pfVar7 + 3;
  local_a0 = local_a0 + *(float *)(this + 0x58);
  *pfVar7 = local_a8;
  pfVar7[2] = local_a0;
  pfVar7[1] = local_a4;
  fVar8 = *(float *)(this + 0x4c);
  fVar3 = fVar8 * pfVar7[5] * -0.5;
  fVar12 = pfVar7[4] * fVar8 * -0.5;
  pfVar7[6] = fVar8 * pfVar7[3] * -0.5 + *pfVar7;
  pfVar7[7] = fVar12 + pfVar7[1];
  pfVar7[8] = fVar3 + pfVar7[2];
  fVar8 = *(float *)(this + 0x4c);
  pfVar7[9] = fVar8 * pfVar7[3] * fVar5 + *pfVar7;
  pfVar7[10] = pfVar7[4] * fVar8 * fVar5 + pfVar7[1];
  pfVar7[0xb] = pfVar7[5] * fVar8 * fVar5 + pfVar7[2];
  if (*(int *)pmVar15 != 0) {
    local_38 = pfVar7[4];
    iVar13 = *(int *)(*(int *)(this + 0xa0) + -4 + *(int *)pmVar15 * 4);
    local_34 = *(undefined4 *)(iVar13 + 0x10);
    local_3c = *(float *)(iVar13 + 0xc);
    local_40 = pfVar7[3];
    cVar6 = idMat2::InverseSelf((idMat2 *)&local_40);
    if (cVar6 != '\0') {
      iVar13 = *(int *)(this + 0xa0);
      iVar9 = *(int *)pmVar15 + -1;
      pfVar1 = *(float **)(iVar13 + iVar9 * 4);
      fVar8 = (pfVar1[1] - *(float *)(this + 0x44)) * local_3c +
              (*pfVar1 - *(float *)(this + 0x40)) * local_40;
      local_24 = fVar8 * pfVar7[5] * fVar8 * pfVar7[5] +
                 pfVar7[4] * fVar8 * pfVar7[4] * fVar8 + fVar8 * pfVar7[3] * fVar8 * pfVar7[3];
      local_20 = (float)(0x5f3759df - ((int)local_24 >> 1));
      if (local_20 * (1.5 - local_20 * local_20 * local_24 * fVar5) * local_24 <
          *(float *)(this + 0x4c) * fVar5) {
        iVar2 = *(int *)(iVar13 + iVar9 * 4);
        fVar3 = *(float *)(iVar2 + 0x20) - pfVar7[8];
        fVar12 = *(float *)(iVar2 + 0x1c) - pfVar7[7];
        fVar8 = *(float *)(iVar2 + 0x18) - pfVar7[6];
        fVar8 = fVar3 * fVar3 + fVar12 * fVar12 + fVar8 * fVar8;
        fVar14 = (float)(0x5f3759df - ((int)fVar8 >> 1));
        iVar2 = *(int *)(iVar13 + iVar9 * 4);
        fVar4 = *(float *)(iVar2 + 0x2c) - pfVar7[0xb];
        fVar3 = *(float *)(iVar2 + 0x28) - pfVar7[10];
        fVar12 = *(float *)(iVar2 + 0x24) - pfVar7[9];
                    /* catch() { ... } // from try @ 002b6430 with catch @ 002b5db0 */
        local_24 = fVar4 * fVar4 + fVar3 * fVar3 + fVar12 * fVar12;
        fVar12 = (float)(0x5f3759df - ((int)local_24 >> 1));
        if (fVar8 * (1.5 - fVar14 * fVar14 * fVar8 * fVar5) * fVar14 <=
            local_24 * fVar12 * (1.5 - fVar12 * fVar12 * local_24 * fVar5)) {
          iVar13 = *(int *)(iVar13 + iVar9 * 4);
          pfVar7[6] = *(float *)(iVar13 + 0x18);
          pfVar7[7] = *(float *)(iVar13 + 0x1c);
          pfVar7[8] = *(float *)(iVar13 + 0x20);
          iVar13 = *(int *)(*(int *)(this + 0xa0) + (*(int *)pmVar15 + -1) * 4);
          fVar8 = *(float *)(iVar13 + 0x2c);
          fVar12 = *(float *)(iVar13 + 0x28);
          pfVar7[9] = (*(float *)(iVar13 + 0x24) - pfVar7[9]) * fVar5 + pfVar7[9];
          pfVar7[10] = (fVar12 - pfVar7[10]) * fVar5 + pfVar7[10];
          pfVar7[0xb] = (fVar8 - pfVar7[0xb]) * fVar5 + pfVar7[0xb];
        }
        else {
          iVar13 = *(int *)(iVar13 + iVar9 * 4);
          pfVar7[9] = *(float *)(iVar13 + 0x24);
          pfVar7[10] = *(float *)(iVar13 + 0x28);
          pfVar7[0xb] = *(float *)(iVar13 + 0x2c);
          iVar13 = *(int *)(*(int *)(this + 0xa0) + (*(int *)pmVar15 + -1) * 4);
          fVar8 = *(float *)(iVar13 + 0x20);
          fVar12 = *(float *)(iVar13 + 0x1c);
          pfVar7[6] = (*(float *)(iVar13 + 0x18) - pfVar7[6]) * fVar5 + pfVar7[6];
          pfVar7[7] = (fVar12 - pfVar7[7]) * fVar5 + pfVar7[7];
          pfVar7[8] = (fVar8 - pfVar7[8]) * fVar5 + pfVar7[8];
        }
        fVar3 = pfVar7[0xb] - pfVar7[8];
        fVar12 = pfVar7[10] - pfVar7[7];
        fVar8 = pfVar7[9] - pfVar7[6];
        *local_c4 = fVar8;
        pfVar7[4] = fVar12;
        pfVar7[5] = fVar3;
        local_20 = fVar3 * fVar3 + fVar12 * fVar12 + fVar8 * fVar8;
        fVar8 = (float)((0x17c - ((uint)local_20 >> 0x17 & 0xff) >> 1) << 0x17 |
                       *(uint *)(PTR_iSqrt_003e0edc + ((uint)local_20 >> 0xf & 0x1ff) * 4));
        fVar8 = (1.5 - fVar8 * fVar8 * local_20 * fVar5) * fVar8;
        fVar8 = fVar8 * (1.5 - fVar8 * fVar8 * local_20 * fVar5);
        *local_c4 = *local_c4 * fVar8;
        pfVar7[4] = pfVar7[4] * fVar8;
        pfVar7[5] = fVar8 * pfVar7[5];
        fVar8 = *(float *)(this + 0x4c);
        *pfVar7 = fVar8 * *local_c4 * fVar5 + pfVar7[6];
        pfVar7[1] = pfVar7[4] * fVar8 * fVar5 + pfVar7[7];
        pfVar7[2] = pfVar7[5] * fVar8 * fVar5 + pfVar7[8];
      }
    }
  }
  if (*(int *)(this + 0xa0) == 0) {
    iVar13 = *(int *)(this + 0x9c);
    if (iVar13 < 1) {
      *(undefined4 *)(this + 0xa0) = 0;
      *(int *)pmVar15 = 0;
      *(undefined4 *)(this + 0x98) = 0;
    }
    else if (iVar13 != *(int *)(this + 0x98)) {
      *(int *)(this + 0x98) = iVar13;
      if (iVar13 < *(int *)pmVar15) {
        *(int *)pmVar15 = iVar13;
        iVar13 = *(int *)(this + 0x98);
      }
      pvVar11 = operator_new__(iVar13 << 2);
      *(void **)(this + 0xa0) = pvVar11;
      if (0 < *(int *)pmVar15) {
        iVar13 = 0;
        do {
          *(undefined4 *)(*(int *)(this + 0xa0) + iVar13 * 4) = *(undefined4 *)(iVar13 * 4);
          iVar13 = iVar13 + 1;
        } while (iVar13 < *(int *)pmVar15);
      }
    }
  }
  iVar13 = *(int *)pmVar15;
  if (iVar13 == *(int *)(this + 0x98)) {
    if (*(int *)(this + 0x9c) == 0) {
      *(undefined4 *)(this + 0x9c) = 0x10;
    }
    iVar9 = *(int *)(this + 0x98) + *(int *)(this + 0x9c);
    iVar9 = iVar9 - iVar9 % *(int *)(this + 0x9c);
    if (iVar9 < 1) {
      if (*(void **)(this + 0xa0) != (void *)0x0) {
        operator_delete__(*(void **)(this + 0xa0));
      }
      iVar13 = 0;
      *(undefined4 *)(this + 0xa0) = 0;
      *(int *)pmVar15 = 0;
      *(undefined4 *)(this + 0x98) = 0;
    }
    else if (*(int *)(this + 0x98) != iVar9) {
      pvVar11 = *(void **)(this + 0xa0);
      *(int *)(this + 0x98) = iVar9;
      if (iVar9 < *(int *)pmVar15) {
        *(int *)pmVar15 = iVar9;
        iVar9 = *(int *)(this + 0x98);
      }
      pvVar10 = operator_new__(iVar9 << 2);
      *(void **)(this + 0xa0) = pvVar10;
      if (0 < *(int *)pmVar15) {
        iVar13 = 0;
        do {
          *(undefined4 *)(*(int *)(this + 0xa0) + iVar13 * 4) =
               *(undefined4 *)((int)pvVar11 + iVar13 * 4);
          iVar13 = iVar13 + 1;
        } while (iVar13 < *(int *)pmVar15);
      }
      if (pvVar11 == (void *)0x0) {
        iVar13 = *(int *)pmVar15;
      }
      else {
        operator_delete__(pvVar11);
        iVar13 = *(int *)pmVar15;
      }
    }
  }
  *(float **)(*(int *)(this + 0xa0) + iVar13 * 4) = pfVar7;
  *(int *)pmVar15 = *(int *)pmVar15 + 1;
  return 1;
}

