// mkTrail::Present @ 002b6140
// undefined Present(mkTrail * this)

/* WARNING: Function: __i686.get_pc_thunk.bx replaced with injection: get_pc_thunk_bx */
/* mkTrail::Present() */

void __thiscall mkTrail::Present(mkTrail *this)

{
  float fVar1;
  code *pcVar2;
  int *piVar3;
  float *pfVar4;
  int iVar5;
  undefined4 uVar6;
  int *piVar7;
  int iVar8;
  undefined4 local_40;
  undefined4 local_2c;
  undefined4 local_28;
  undefined4 local_24;
  undefined4 local_20;
  undefined4 local_1c;
  undefined4 local_18;
  
  piVar7 = (int *)&stack0xffffffc4;
  if ((*(uint *)(this + 0x3c) & 8) == 0) {
    return;
  }
  *(uint *)(this + 0x3c) = *(uint *)(this + 0x3c) & 0xfffffff7;
  local_40 = 0x2b6194;
  addNewAnchor(this);
  if (*(int *)(this + 0x90) < *(int *)(this + 0x94)) {
    local_40 = 0x2b63df;
    operator_delete((void *)**(undefined4 **)(this + 0xa0));
    if ((0 < *(int *)(this + 0x94)) &&
       (iVar5 = *(int *)(this + 0x94) + -1, *(int *)(this + 0x94) = iVar5, 0 < iVar5)) {
      iVar8 = 0;
      iVar5 = 0;
      do {
        iVar8 = iVar8 + 1;
        *(undefined4 *)(iVar5 + *(int *)(this + 0xa0)) =
             ((undefined4 *)(iVar5 + *(int *)(this + 0xa0)))[1];
        iVar5 = iVar5 + 4;
      } while (iVar8 < *(int *)(this + 0x94));
    }
  }
  if (*(int **)(this + 0xa4) != (int *)0x0) {
    local_40 = 0x2b61ca;
    (**(code **)(**(int **)(this + 0xa4) + 0x78))();
    piVar7 = &local_40;
    *(undefined4 *)(this + 0xb0) = local_2c;
    *(undefined4 *)(this + 0xb4) = local_28;
    *(undefined4 *)(this + 0xb8) = local_24;
    *(undefined4 *)(this + 0xbc) = local_20;
    *(undefined4 *)(this + 0xc0) = local_1c;
    *(undefined4 *)(this + 0xc4) = local_18;
  }
  if (*(int *)(this + 4) == 0) {
    fVar1 = *(float *)(this + 0x40);
    if (fVar1 < *(float *)(this + 0xb0)) {
      *(float *)(this + 0xb0) = fVar1;
    }
    if (*(float *)(this + 0xbc) < fVar1) {
      *(float *)(this + 0xbc) = fVar1;
    }
    fVar1 = *(float *)(this + 0x44);
    if (fVar1 < *(float *)(this + 0xb4)) {
      *(float *)(this + 0xb4) = fVar1;
    }
    if (*(float *)(this + 0xc0) < fVar1) {
      *(float *)(this + 0xc0) = fVar1;
    }
    fVar1 = *(float *)(this + 0x48);
    if (fVar1 < *(float *)(this + 0xb8)) {
      *(float *)(this + 0xb8) = fVar1;
    }
    goto LAB_002b62a0;
  }
  *piVar7 = *(int *)(this + 4);
  piVar7[-1] = 0x2b621c;
  piVar3 = (int *)idEntity::GetPhysics((idEntity *)*piVar7);
  iVar5 = *piVar3;
  piVar7[1] = 0;
  *piVar7 = (int)piVar3;
  pcVar2 = *(code **)(iVar5 + 0x84);
  piVar7[-1] = 0x2b622d;
  pfVar4 = (float *)(*pcVar2)();
  fVar1 = *pfVar4;
  if (*(float *)(this + 0xb0) <= fVar1) {
    if (*(float *)(this + 0xbc) < fVar1) goto LAB_002b6308;
LAB_002b6257:
    fVar1 = pfVar4[1];
    if (*(float *)(this + 0xb4) <= fVar1) goto LAB_002b626a;
LAB_002b631f:
    *(float *)(this + 0xb4) = fVar1;
    fVar1 = pfVar4[1];
    if (*(float *)(this + 0xc0) < fVar1) goto LAB_002b633a;
LAB_002b627c:
    fVar1 = pfVar4[2];
    if (*(float *)(this + 0xb8) <= fVar1) goto LAB_002b62a0;
  }
  else {
    *(float *)(this + 0xb0) = fVar1;
    fVar1 = *pfVar4;
    if (fVar1 <= *(float *)(this + 0xbc)) goto LAB_002b6257;
LAB_002b6308:
    *(float *)(this + 0xbc) = fVar1;
    fVar1 = pfVar4[1];
    if (fVar1 < *(float *)(this + 0xb4)) goto LAB_002b631f;
LAB_002b626a:
    if (fVar1 <= *(float *)(this + 0xc0)) goto LAB_002b627c;
LAB_002b633a:
    *(float *)(this + 0xc0) = fVar1;
    fVar1 = pfVar4[2];
    if (*(float *)(this + 0xb8) <= fVar1) goto LAB_002b62a0;
  }
  *(float *)(this + 0xb8) = fVar1;
  fVar1 = pfVar4[2];
LAB_002b62a0:
  if (*(float *)(this + 0xc4) < fVar1) {
    *(float *)(this + 0xc4) = fVar1;
  }
  iVar5 = *(int *)(this + 0x188);
  *(undefined4 *)(this + 0x170) = 1;
  if (iVar5 == -1) {
    piVar3 = *(int **)PTR_gameRenderWorld_003e10a0;
    iVar5 = *piVar3;
    piVar7[1] = (int)(this + 0xa4);
                    /* try { // try from 002b6430 to 002c6434 has its CatchHandler @ 002b5db0 */
    *piVar7 = (int)piVar3;
    pcVar2 = *(code **)(iVar5 + 0xc);
    piVar7[-1] = 0x2b6434;
    uVar6 = (*pcVar2)();
    *(undefined4 *)(this + 0x188) = uVar6;
  }
  else {
    piVar3 = *(int **)PTR_gameRenderWorld_003e10a0;
    iVar8 = *piVar3;
    piVar7[2] = (int)(this + 0xa4);
    piVar7[1] = iVar5;
    *piVar7 = (int)piVar3;
    pcVar2 = *(code **)(iVar8 + 0x10);
    piVar7[-1] = 0x2b62ea;
    (*pcVar2)();
  }
  this[0x184] = (mkTrail)0x1;
  return;
}

