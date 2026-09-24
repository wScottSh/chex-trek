// mkTrail::Restore @ 002b4cb0
// undefined Restore(mkTrail * this, idRestoreGame * param_1)

/* WARNING: Function: __i686.get_pc_thunk.bx replaced with injection: get_pc_thunk_bx */
/* mkTrail::Restore(idRestoreGame*) */

void __thiscall mkTrail::Restore(mkTrail *this,idRestoreGame *param_1)

{
  float fVar1;
  undefined *puVar2;
  int *piVar3;
  void *pvVar4;
  int iVar5;
  void *pvVar6;
  void *pvVar7;
  undefined4 uVar8;
  int iVar9;
  mkTrail *pmVar10;
  int local_28;
  int local_14;
  
  memset(this + 0xa4,0,0xd8);
  piVar3 = (int *)(**(code **)(**(int **)PTR_renderModelManager_003e0128 + 0x18))
                            (*(int **)PTR_renderModelManager_003e0128);
  *(int **)(this + 0xa4) = piVar3;
  (**(code **)(*piVar3 + 0x10))(piVar3,mkTrail_SnapshotName);
  *(undefined **)(this + 200) = PTR_ModelCallback_003e039c;
  fVar1 = *(float *)PTR_INFINITY_003e01a0;
  *(float *)(this + 0xb8) = fVar1;
  *(float *)(this + 0xb4) = fVar1;
  puVar2 = PTR_mat3_identity_003e13e0;
  *(float *)(this + 0xb0) = fVar1;
  fVar1 = -fVar1;
  *(float *)(this + 0xc4) = fVar1;
  *(float *)(this + 0xc0) = fVar1;
  *(float *)(this + 0xbc) = fVar1;
  this[0x16d] = (mkTrail)0x0;
  this[0x16c] = (mkTrail)0x0;
  this[0x16e] = (mkTrail)0x0;
  *(undefined4 *)(this + 0xec) = *(undefined4 *)puVar2;
  *(undefined4 *)(this + 0xf0) = *(undefined4 *)(puVar2 + 4);
  *(undefined4 *)(this + 0xf4) = *(undefined4 *)(puVar2 + 8);
  *(undefined4 *)(this + 0xf8) = *(undefined4 *)(puVar2 + 0xc);
  *(undefined4 *)(this + 0xfc) = *(undefined4 *)(puVar2 + 0x10);
  *(undefined4 *)(this + 0x100) = *(undefined4 *)(puVar2 + 0x14);
  *(undefined4 *)(this + 0x104) = *(undefined4 *)(puVar2 + 0x18);
  *(undefined4 *)(this + 0x108) = *(undefined4 *)(puVar2 + 0x1c);
  *(undefined4 *)(this + 0x10c) = *(undefined4 *)(puVar2 + 0x20);
  *(undefined4 *)(this + 0xe8) = 0;
  *(undefined4 *)(this + 0xe4) = 0;
  *(undefined4 *)(this + 0xe0) = 0;
  idRestoreGame::ReadDict(param_1,(idDict *)(this + 8));
  idRestoreGame::ReadMaterial(param_1,(idMaterial **)(this + 0x17c));
  idRestoreGame::ReadVec3(param_1,(idVec3 *)(this + 0x40));
  idRestoreGame::ReadFloat(param_1,(float *)(this + 0x4c));
  idRestoreGame::ReadFloat(param_1,(float *)(this + 0x50));
  idRestoreGame::ReadFloat(param_1,(float *)(this + 0x54));
  idRestoreGame::ReadFloat(param_1,(float *)(this + 0x58));
  idRestoreGame::ReadFloat(param_1,(float *)(this + 0x5c));
  idRestoreGame::ReadFloat(param_1,(float *)(this + 0x60));
  idRestoreGame::ReadFloat(param_1,(float *)(this + 100));
  idRestoreGame::ReadInt(param_1,(int *)(this + 0x68));
  idRestoreGame::ReadInt(param_1,(int *)(this + 0x6c));
  idRestoreGame::ReadInt(param_1,(int *)(this + 0x34));
  idRestoreGame::ReadVec4(param_1,(idVec4 *)(this + 0x70));
  *(undefined4 *)(this + 0x120) = *(undefined4 *)(this + 0x70);
  *(undefined4 *)(this + 0x124) = *(undefined4 *)(this + 0x74);
  *(undefined4 *)(this + 0x128) = *(undefined4 *)(this + 0x78);
  *(undefined4 *)(this + 300) = *(undefined4 *)(this + 0x7c);
  idRestoreGame::ReadVec4(param_1,(idVec4 *)(this + 0x80));
  idRestoreGame::ReadInt(param_1,(int *)(this + 0x90));
  idRestoreGame::ReadInt(param_1,&local_14);
  pmVar10 = this + 0x94;
  if (*(void **)(this + 0xa0) != (void *)0x0) {
    operator_delete__(*(void **)(this + 0xa0));
  }
  *(undefined4 *)(this + 0xa0) = 0;
  *(undefined4 *)(this + 0x98) = 0;
  *(undefined4 *)(this + 0x94) = 0;
  if (0 < local_14) {
    local_28 = 0;
    do {
      pvVar4 = operator_new(0x30);
      idRestoreGame::Read(param_1,pvVar4,0x30);
      if (*(int *)(this + 0xa0) == 0) {
        iVar9 = *(int *)(this + 0x9c);
        if (iVar9 < 1) {
          *(undefined4 *)(this + 0xa0) = 0;
          *(int *)pmVar10 = 0;
          *(undefined4 *)(this + 0x98) = 0;
        }
        else if (iVar9 != *(int *)(this + 0x98)) {
          *(int *)(this + 0x98) = iVar9;
          if (iVar9 < *(int *)pmVar10) {
            *(int *)pmVar10 = iVar9;
            iVar9 = *(int *)(this + 0x98);
          }
          pvVar7 = operator_new__(iVar9 << 2);
          *(void **)(this + 0xa0) = pvVar7;
          if (0 < *(int *)pmVar10) {
            iVar9 = 0;
            do {
              *(undefined4 *)(*(int *)(this + 0xa0) + iVar9 * 4) = *(undefined4 *)(iVar9 * 4);
              iVar9 = iVar9 + 1;
            } while (iVar9 < *(int *)pmVar10);
          }
        }
      }
      iVar9 = *(int *)pmVar10;
      if (iVar9 == *(int *)(this + 0x98)) {
        if (*(int *)(this + 0x9c) == 0) {
          *(undefined4 *)(this + 0x9c) = 0x10;
        }
        iVar5 = *(int *)(this + 0x98) + *(int *)(this + 0x9c);
        iVar5 = iVar5 - iVar5 % *(int *)(this + 0x9c);
        if (iVar5 < 1) {
          if (*(void **)(this + 0xa0) != (void *)0x0) {
            operator_delete__(*(void **)(this + 0xa0));
          }
          iVar9 = 0;
          *(undefined4 *)(this + 0xa0) = 0;
          *(int *)pmVar10 = 0;
          *(undefined4 *)(this + 0x98) = 0;
        }
        else if (*(int *)(this + 0x98) != iVar5) {
          pvVar7 = *(void **)(this + 0xa0);
          *(int *)(this + 0x98) = iVar5;
          if (iVar5 < *(int *)pmVar10) {
            *(int *)pmVar10 = iVar5;
            iVar5 = *(int *)(this + 0x98);
          }
          pvVar6 = operator_new__(iVar5 << 2);
          *(void **)(this + 0xa0) = pvVar6;
          if (0 < *(int *)pmVar10) {
            iVar9 = 0;
            do {
              *(undefined4 *)(*(int *)(this + 0xa0) + iVar9 * 4) =
                   *(undefined4 *)((int)pvVar7 + iVar9 * 4);
              iVar9 = iVar9 + 1;
            } while (iVar9 < *(int *)pmVar10);
          }
          if (pvVar7 == (void *)0x0) {
            iVar9 = *(int *)pmVar10;
          }
          else {
            operator_delete__(pvVar7);
            iVar9 = *(int *)pmVar10;
          }
        }
      }
      *(void **)(*(int *)(this + 0xa0) + iVar9 * 4) = pvVar4;
      *(int *)pmVar10 = *(int *)pmVar10 + 1;
      local_28 = local_28 + 1;
    } while (local_28 < local_14);
  }
  idRestoreGame::ReadInt(param_1,(int *)(this + 0x180));
  idRestoreGame::ReadBool(param_1,(bool *)(this + 0x184));
  idRestoreGame::ReadInt(param_1,(int *)(this + 0x3c));
  idRestoreGame::ReadInt(param_1,(int *)(this + 0x188));
  idRestoreGame::ReadObject(param_1,(idClass **)(this + 4));
  *(mkTrail **)(this + 0xa8) = this;
  *(mkTrail **)(this + 0x38) = this;
  if (*(int *)(this + 0x188) != -1) {
    uVar8 = (**(code **)(**(int **)PTR_gameRenderWorld_003e10a0 + 0xc))
                      (*(int **)PTR_gameRenderWorld_003e10a0,this + 0xa4);
    *(undefined4 *)(this + 0x188) = uVar8;
  }
  return;
}

