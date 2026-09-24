// mkTrail::Think @ 002b4260
// undefined Think(mkTrail * this)
// literals (read from .rodata; Ghidra address, type, value):
//   0036b0e4  float  0.5
//   0036b0e8  float  1.5

/* WARNING: Function: __i686.get_pc_thunk.bx replaced with injection: get_pc_thunk_bx */
/* mkTrail::Think() */

void __thiscall mkTrail::Think(mkTrail *this)

{
  int iVar1;
  undefined4 uVar2;
  float fVar3;
  int *piVar4;
  float *pfVar5;
  undefined4 *puVar6;
  undefined4 local_24;
  undefined4 local_20;
  undefined4 local_1c;
  undefined4 local_18;
  float local_14;
  float local_10;
  
  if (((byte)this[0x3c] & 1) == 0) {
    return;
  }
  if (*(idEntity **)(this + 4) != (idEntity *)0x0) {
    piVar4 = (int *)idEntity::GetPhysics(*(idEntity **)(this + 4));
    pfVar5 = (float *)(**(code **)(*piVar4 + 0x84))(piVar4,0);
    local_10 = (*(float *)(this + 0x48) - pfVar5[2]) * (*(float *)(this + 0x48) - pfVar5[2]) +
               (*(float *)(this + 0x44) - pfVar5[1]) * (*(float *)(this + 0x44) - pfVar5[1]) +
               (*(float *)(this + 0x40) - *pfVar5) * (*(float *)(this + 0x40) - *pfVar5);
    local_14 = (float)(0x5f3759df - ((int)local_10 >> 1));
    if (*(float *)(this + 0x50) <
        (1.5 - local_14 * local_14 * 0.5 * local_10) * local_14 * local_10) {
      *(uint *)(this + 0x3c) = *(uint *)(this + 0x3c) | 8;
      piVar4 = (int *)idEntity::GetPhysics(*(idEntity **)(this + 4));
      puVar6 = (undefined4 *)(**(code **)(*piVar4 + 0x84))(piVar4,0);
      *(undefined4 *)(this + 0x40) = *puVar6;
      uVar2 = puVar6[2];
      *(undefined4 *)(this + 0x44) = puVar6[1];
      *(undefined4 *)(this + 0x48) = uVar2;
      (**(code **)(*(int *)this + 0xc))(this);
      iVar1 = *(int *)(this + 0x68);
      goto joined_r0x002b4315;
    }
  }
  (**(code **)(*(int *)this + 0xc))(this);
  iVar1 = *(int *)(this + 0x68);
joined_r0x002b4315:
  if (iVar1 != 0) {
    fVar3 = (float)(*(int *)(PTR_gameLocal_003e0cac + 0x251884) - iVar1) /
            (float)(*(int *)(this + 0x6c) - iVar1);
    if (fVar3 < 0.0) {
      return;
    }
    idVec4::Lerp((idVec4 *)&local_24,(idVec4 *)(this + 0x70),(idVec4 *)(this + 0x80),fVar3);
    *(undefined4 *)(this + 0x120) = local_24;
    *(undefined4 *)(this + 0x124) = local_20;
    *(undefined4 *)(this + 0x128) = local_1c;
    *(uint *)(this + 0x3c) = *(uint *)(this + 0x3c) | 8;
    *(undefined4 *)(this + 300) = local_18;
    if (1.0 < fVar3) {
      (**(code **)(*(int *)this + 8))(this);
    }
  }
  return;
}

