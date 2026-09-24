// mkTrail::UpdateRenderEntity @ 002b4420
// undefined UpdateRenderEntity(mkTrail * this, renderEntity_s * param_1, renderView_s * param_2)
// literals (read from .rodata; Ghidra address, type, value):
//   0036e4d0  double 0.001
//   0036b0e4  float  0.5
//   0036b0e8  float  1.5
//   0036d260  float  -0.5

/* WARNING: Function: __i686.get_pc_thunk.bx replaced with injection: get_pc_thunk_bx */
/* mkTrail::UpdateRenderEntity(renderEntity_s*, renderView_s const*) const */

undefined4 __thiscall
mkTrail::UpdateRenderEntity(mkTrail *this,renderEntity_s *param_1,renderView_s *param_2)

{
  float fVar1;
  float fVar2;
  float fVar3;
  float fVar4;
  float fVar5;
  int iVar6;
  float fVar7;
  float fVar8;
  int iVar9;
  bool bVar10;
  undefined4 uVar11;
  int iVar12;
  undefined4 *puVar13;
  float *pfVar14;
  int iVar15;
  int iVar16;
  int iVar17;
  int local_c4;
  int local_b4;
  float local_a8;
  float local_a4;
  float local_a0;
  float local_9c;
  undefined4 local_3c;
  undefined4 local_38;
  float local_34;
  undefined4 local_30;
  undefined4 local_2c;
  int local_28;
  float local_24;
  float local_20;
  
  if ((((param_2 == (renderView_s *)0x0) ||
       (*(int *)(this + 0x180) == *(int *)(PTR_gameLocal_003e0cac + 0x251884))) ||
      (this[0x184] == (mkTrail)0x0)) || (*(int *)(this + 0x94) == 0)) {
    uVar11 = 0;
  }
  else {
    *(int *)(this + 0x180) = *(int *)(PTR_gameLocal_003e0cac + 0x251884);
    this[0x184] = (mkTrail)0x0;
    iVar15 = *(int *)(this + 0x94);
    (**(code **)(**(int **)param_1 + 0x10))(*(int **)param_1,mkTrail_SnapshotName);
    iVar9 = iVar15 * 6;
    iVar12 = (**(code **)(**(int **)param_1 + 0x5c))(*(int **)param_1,iVar15 * 2 + 2,iVar9);
    *(undefined1 *)(iVar12 + 0x1d) = 0;
    fVar1 = *(float *)(this + 100);
    fVar5 = -fVar1;
    if (0 < iVar15) {
      iVar16 = 0;
      bVar10 = true;
      do {
        fVar5 = fVar5 + fVar1;
        if (fVar5 < 1.0) {
          local_20 = 1.0 - fVar5;
          local_24 = ABS(local_20);
          if (local_24 <= (float)0.001) goto LAB_002b46d8;
          if (!bVar10) goto LAB_002b46e5;
        }
        else {
LAB_002b46d8:
          fVar1 = -fVar1;
          bVar10 = false;
          fVar5 = 1.0;
LAB_002b46e5:
          fVar2 = *(float *)(this + 0x60);
          if (fVar2 < fVar5) {
            local_24 = fVar2 - fVar5;
            local_20 = ABS(local_24);
            if ((float)0.001 < local_20) goto LAB_002b4560;
          }
          fVar1 = -fVar1;
          fVar5 = fVar2;
        }
LAB_002b4560:
        puVar13 = (undefined4 *)(*(int *)(iVar12 + 0x24) * 0x3c + *(int *)(iVar12 + 0x28));
        *(int *)(iVar12 + 0x24) = *(int *)(iVar12 + 0x24) + 1;
        puVar13[2] = 0;
        iVar17 = iVar16 * 4;
        iVar16 = iVar16 + 1;
        puVar13[7] = 0;
        puVar13[1] = 0;
        puVar13[6] = 0;
        puVar13[10] = 0;
        puVar13[9] = 0;
        puVar13[0xd] = 0;
        puVar13[0xc] = 0;
        puVar13[3] = fVar5;
        *(undefined1 *)((int)puVar13 + 0x3b) = 0;
        *(undefined1 *)((int)puVar13 + 0x3a) = 0;
        *(undefined1 *)((int)puVar13 + 0x39) = 0;
        *(undefined1 *)(puVar13 + 0xe) = 0;
        puVar13[4] = 0;
        *puVar13 = 0;
        puVar13[5] = 0;
        puVar13[8] = 0;
        puVar13[0xb] = 0;
        iVar6 = *(int *)(iVar17 + *(int *)(this + 0xa0));
        *puVar13 = *(undefined4 *)(iVar6 + 0x18);
        puVar13[1] = *(undefined4 *)(iVar6 + 0x1c);
        puVar13[2] = *(undefined4 *)(iVar6 + 0x20);
        iVar6 = *(int *)(iVar12 + 0x24);
        *(int *)(iVar12 + 0x24) = iVar6 + 1;
        puVar13 = (undefined4 *)(iVar6 * 0x3c + *(int *)(iVar12 + 0x28));
        puVar13[2] = 0;
        puVar13[7] = 0;
        puVar13[1] = 0;
        puVar13[6] = 0;
        puVar13[10] = 0;
        puVar13[9] = 0;
        puVar13[0xd] = 0;
        puVar13[0xc] = 0;
        puVar13[3] = fVar5;
        *(undefined1 *)((int)puVar13 + 0x3b) = 0;
        *(undefined1 *)((int)puVar13 + 0x3a) = 0;
        *(undefined1 *)((int)puVar13 + 0x39) = 0;
        *(undefined1 *)(puVar13 + 0xe) = 0;
        puVar13[4] = 0x3f800000;
        *puVar13 = 0;
        puVar13[5] = 0;
        puVar13[8] = 0;
        puVar13[0xb] = 0;
        iVar17 = *(int *)(iVar17 + *(int *)(this + 0xa0));
        *puVar13 = *(undefined4 *)(iVar17 + 0x24);
        puVar13[1] = *(undefined4 *)(iVar17 + 0x28);
        puVar13[2] = *(undefined4 *)(iVar17 + 0x2c);
      } while (iVar15 != iVar16);
    }
    local_3c = *(undefined4 *)(this + 0x40);
    local_38 = *(undefined4 *)(this + 0x44);
    local_34 = *(float *)(this + 0x48) - *(float *)(this + 0x5c);
    idClip::Translation((idClip *)(PTR_gameLocal_003e0cac + 0x2350a8),(trace_s *)&local_a8,
                        (idVec3 *)(this + 0x40),(idVec3 *)&local_3c,(idClipModel *)0x0,
                        (idMat3 *)PTR_mat3_identity_003e13e0,2,*(idEntity **)(this + 4));
    if (1.0 <= local_a8) {
      iVar15 = iVar15 * 4 + -4;
      iVar16 = *(int *)(this + 0xa0);
      pfVar14 = *(float **)(iVar16 + iVar15);
      local_a4 = *pfVar14;
      local_a0 = pfVar14[1];
      local_9c = pfVar14[2];
    }
    else {
      local_9c = local_9c + *(float *)(this + 0x58);
      iVar15 = iVar15 * 4 + -4;
      iVar16 = *(int *)(this + 0xa0);
    }
    pfVar14 = *(float **)(iVar16 + iVar15);
    local_20 = (local_9c - pfVar14[2]) * (local_9c - pfVar14[2]) +
               (local_a0 - pfVar14[1]) * (local_a0 - pfVar14[1]) +
               (local_a4 - *pfVar14) * (local_a4 - *pfVar14);
    local_24 = (float)(0x5f3759df - ((int)local_20 >> 1));
    iVar17 = *(int *)(this + 4);
    fVar5 = ((1.5 - local_24 * local_24 * local_20 * 0.5) * local_24 *
             local_20 * fVar1) / *(float *)(this + 0x54) + fVar5;
    if (iVar17 == 0) {
      iVar15 = *(int *)(iVar16 + iVar15);
      fVar1 = *(float *)(iVar15 + 0xc);
      fVar2 = *(float *)(iVar15 + 0x10);
      fVar3 = *(float *)(iVar15 + 0x14);
    }
    else {
      fVar1 = *(float *)(iVar17 + 0x8e8);
      fVar2 = *(float *)(iVar17 + 0x8ec);
      fVar3 = *(float *)(iVar17 + 0x8f0);
    }
    puVar13 = (undefined4 *)(*(int *)(iVar12 + 0x24) * 0x3c + *(int *)(iVar12 + 0x28));
    puVar13[4] = 0;
    puVar13[3] = 0;
    puVar13[2] = 0;
    puVar13[1] = 0;
    puVar13[7] = 0;
    puVar13[6] = 0;
    puVar13[10] = 0;
    puVar13[9] = 0;
    puVar13[0xd] = 0;
    puVar13[0xc] = 0;
    *puVar13 = 0;
    puVar13[5] = 0;
    puVar13[8] = 0;
    puVar13[0xb] = 0;
    *(undefined1 *)((int)puVar13 + 0x3b) = 0;
    *(undefined1 *)((int)puVar13 + 0x3a) = 0;
    *(undefined1 *)((int)puVar13 + 0x39) = 0;
    *(undefined1 *)(puVar13 + 0xe) = 0;
    *(float *)(*(int *)(iVar12 + 0x24) * 0x3c + 0xc + *(int *)(iVar12 + 0x28)) = fVar5;
    *(undefined4 *)(*(int *)(iVar12 + 0x24) * 0x3c + 0x10 + *(int *)(iVar12 + 0x28)) = 0;
    fVar4 = *(float *)(this + 0x4c);
    fVar8 = fVar3 * fVar4 * -0.5;
    pfVar14 = (float *)(*(int *)(iVar12 + 0x24) * 0x3c + *(int *)(iVar12 + 0x28));
    fVar7 = fVar2 * fVar4 * -0.5;
    fVar4 = fVar4 * fVar1 * -0.5;
    *(int *)(iVar12 + 0x24) = *(int *)(iVar12 + 0x24) + 1;
    *pfVar14 = fVar4 + local_a4;
    pfVar14[1] = fVar7 + local_a0;
    pfVar14[2] = fVar8 + local_9c;
    puVar13 = (undefined4 *)(*(int *)(iVar12 + 0x24) * 0x3c + *(int *)(iVar12 + 0x28));
    puVar13[4] = 0;
    puVar13[3] = 0;
    puVar13[2] = 0;
    puVar13[1] = 0;
    puVar13[7] = 0;
    puVar13[6] = 0;
    puVar13[10] = 0;
    puVar13[9] = 0;
    puVar13[0xd] = 0;
    puVar13[0xc] = 0;
    *puVar13 = 0;
    puVar13[5] = 0;
    puVar13[8] = 0;
    puVar13[0xb] = 0;
    *(undefined1 *)((int)puVar13 + 0x3b) = 0;
    *(undefined1 *)((int)puVar13 + 0x3a) = 0;
    *(undefined1 *)((int)puVar13 + 0x39) = 0;
    *(undefined1 *)(puVar13 + 0xe) = 0;
    *(float *)(*(int *)(iVar12 + 0x24) * 0x3c + 0xc + *(int *)(iVar12 + 0x28)) = fVar5;
    *(undefined4 *)(*(int *)(iVar12 + 0x24) * 0x3c + 0x10 + *(int *)(iVar12 + 0x28)) = 0x3f800000;
    iVar15 = *(int *)(iVar12 + 0x24);
    fVar5 = *(float *)(this + 0x4c);
    fVar3 = fVar3 * fVar5 * 0.5;
    fVar2 = fVar2 * fVar5 * 0.5;
    fVar1 = fVar1 * fVar5 * 0.5;
    *(int *)(iVar12 + 0x24) = iVar15 + 1;
    pfVar14 = (float *)(iVar15 * 0x3c + *(int *)(iVar12 + 0x28));
    *pfVar14 = fVar1 + local_a4;
    pfVar14[1] = fVar2 + local_a0;
    pfVar14[2] = fVar3 + local_9c;
    iVar15 = *(int *)(iVar12 + 0x2c);
    if (iVar15 < iVar9) {
      local_b4 = 0;
      iVar17 = iVar15 * 4;
      local_c4 = 1;
      iVar16 = iVar17 + 4;
      do {
        iVar15 = iVar15 + 6;
        *(int *)(iVar17 + *(int *)(iVar12 + 0x30)) = local_b4;
        iVar17 = iVar17 + 0x18;
        *(int *)(iVar16 + *(int *)(iVar12 + 0x30)) = local_c4;
        local_b4 = local_b4 + 2;
        *(int *)(iVar16 + 4 + *(int *)(iVar12 + 0x30)) = local_b4;
        *(int *)(iVar16 + 8 + *(int *)(iVar12 + 0x30)) = local_c4 + 2;
        *(int *)(iVar16 + 0xc + *(int *)(iVar12 + 0x30)) = local_b4;
        *(int *)(iVar16 + 0x10 + *(int *)(iVar12 + 0x30)) = local_c4;
        iVar16 = iVar16 + 0x18;
        *(int *)(iVar12 + 0x2c) = iVar15;
        local_c4 = local_c4 + 2;
      } while (iVar15 < iVar9);
    }
    (**(code **)(**(int **)PTR_SIMDProcessor_003e0c48 + 0x80))
              (*(int **)PTR_SIMDProcessor_003e0c48,iVar12,iVar12 + 0xc,
               *(undefined4 *)(iVar12 + 0x28),*(undefined4 *)(iVar12 + 0x24));
    local_2c = *(undefined4 *)(this + 0x17c);
    local_30 = 0;
    local_28 = iVar12;
    (**(code **)(**(int **)param_1 + 0x14))(*(int **)param_1,0,local_2c,iVar12);
    uVar11 = 1;
  }
  return uVar11;
}

