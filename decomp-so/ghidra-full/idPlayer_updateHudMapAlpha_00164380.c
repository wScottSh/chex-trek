// idPlayer::updateHudMapAlpha @ 00164380
// undefined updateHudMapAlpha(idPlayer * this, int param_1)

/* WARNING: Function: __i686.get_pc_thunk.bx replaced with injection: get_pc_thunk_bx */
/* WARNING: Globals starting with '_' overlap smaller symbols at the same address */
/* WARNING: Restarted to delay deadcode elimination for space: stack */
/* idPlayer::updateHudMapAlpha(int) */

void __thiscall idPlayer::updateHudMapAlpha(idPlayer *this,int param_1)

{
  code *pcVar1;
  float fVar2;
  float fVar3;
  int *piVar4;
  float *pfVar5;
  undefined4 *puVar6;
  idVec2 *piVar7;
  int iVar8;
  float fVar9;
  float fVar10;
  uint uVar11;
  undefined4 uVar12;
  int iVar13;
  uint uVar14;
  int iVar15;
  int iVar16;
  int iVar17;
  undefined *puVar18;
  int iStack_38;
  float fStack_20;
  float fStack_1c;
  float fStack_18;
  float fStack_14;
  
  fStack_14 = 2.044611e-39;
  piVar4 = (int *)idEntity::GetPhysics((idEntity *)this);
  pfVar5 = (float *)(**(code **)(*piVar4 + 0x84))(piVar4,0);
  fStack_14 = (*(float *)(this + 0x1e58) - pfVar5[2]) * (*(float *)(this + 0x1e58) - pfVar5[2]) +
              (*(float *)(this + 0x1e54) - pfVar5[1]) * (*(float *)(this + 0x1e54) - pfVar5[1]) +
              (*(float *)(this + 0x1e50) - *pfVar5) * (*(float *)(this + 0x1e50) - *pfVar5);
  fStack_18 = (float)(0x5f3759df - ((int)fStack_14 >> 1));
  if (*(float *)(this + 0x1e4c) <=
      (_LAB_0036b0e8 - fStack_18 * fStack_18 * fStack_14 * _LAB_0036b0e4) * fStack_18 * fStack_14) {
    piVar4 = (int *)idEntity::GetPhysics((idEntity *)this);
    puVar6 = (undefined4 *)(**(code **)(*piVar4 + 0x84))(piVar4,0);
    *(undefined4 *)(this + 0x1e50) = *puVar6;
    uVar12 = puVar6[2];
    *(undefined4 *)(this + 0x1e54) = puVar6[1];
    *(undefined4 *)(this + 0x1e58) = uVar12;
    piVar4 = (int *)idEntity::GetPhysics((idEntity *)this);
    piVar7 = (idVec2 *)(**(code **)(*piVar4 + 0x84))(piVar4,0);
    MapImageCoords(this,128.0,128.0,piVar7,(idVec2 *)&fStack_20);
    fVar2 = _LAB_0036b0e8;
    iVar17 = *(int *)(this + 0x1e40);
    iStack_38 = (int)(fStack_20 - (float)iVar17);
    if (iStack_38 < 0) {
      iStack_38 = 0;
    }
    iVar13 = (int)(fStack_1c - (float)iVar17);
    iVar8 = 0;
    if (-1 < iVar13) {
      iVar8 = iVar13;
    }
    iVar13 = iVar17 * 2;
    iVar16 = iStack_38 + iVar13;
    if (0x80 < iVar16) {
      iVar16 = 0x80;
    }
    iVar15 = iVar13 + iVar8;
    if (0x80 < iVar15) {
      iVar15 = 0x80;
    }
    fStack_14 = (float)(iVar17 * iVar13);
    fVar9 = (float)((0x17c - ((uint)fStack_14 >> 0x17 & 0xff) >> 1) << 0x17 |
                   *(uint *)(PTR_iSqrt_003e0edc + ((uint)fStack_14 >> 0xf & 0x1ff) * 4));
    fVar9 = (_LAB_0036b0e8 - fVar9 * fVar9 * fStack_14 * _LAB_0036b0e4) * fVar9;
    fVar9 = fVar9 * (_LAB_0036b0e8 - fVar9 * fVar9 * fStack_14 * _LAB_0036b0e4) * fStack_14;
    if (iStack_38 < iVar16) {
      do {
        fVar3 = DAT_00372bd4;
        if (iVar8 < iVar15) {
          puVar18 = PTR_hudmap_alpha_003e11ec + ((param_1 * 0x80 + iVar8) * 0x80 + iStack_38) * 4;
          iVar17 = iVar8;
          do {
            fStack_14 = (fStack_1c - (float)iVar17) * (fStack_1c - (float)iVar17) +
                        (fStack_20 - (float)iStack_38) * (fStack_20 - (float)iStack_38);
            fVar10 = (float)((0x17c - ((uint)fStack_14 >> 0x17 & 0xff) >> 1) << 0x17 |
                            *(uint *)(PTR_iSqrt_003e0edc + ((uint)fStack_14 >> 0xf & 0x1ff) * 4));
            uVar14 = 0;
            fVar10 = (fVar2 - fVar10 * fVar10 * fStack_14 * _LAB_0036b0e4) * fVar10;
            uVar11 = (uint)((1.0 - ((fVar2 - fVar10 * fVar10 * fStack_14 * _LAB_0036b0e4) * fVar10 *
                                   fStack_14) / fVar9) * fVar3);
            if ((-1 < (int)uVar11) && (uVar14 = 0xff, (int)uVar11 < 0x100)) {
              uVar14 = uVar11 & 0xff;
            }
            if ((byte)puVar18[3] < uVar14) {
              puVar18[3] = (char)uVar14;
            }
            iVar17 = iVar17 + 1;
            puVar18 = puVar18 + 0x200;
          } while (iVar15 != iVar17);
        }
        iStack_38 = iStack_38 + 1;
      } while (iStack_38 != iVar16);
    }
    puVar18 = PTR_renderSystem_003e0700;
    if (*(int **)PTR_renderSystem_003e0700 != (int *)0x0) {
      pcVar1 = *(code **)(**(int **)PTR_renderSystem_003e0700 + 0x94);
      uVar12 = va("textures/guis/hudmap_alpha%d.tga",param_1);
      (*pcVar1)(*(undefined4 *)puVar18,uVar12,PTR_hudmap_alpha_003e11ec + param_1 * 0x10000,0x80,
                0x80);
      return;
    }
  }
  return;
}

