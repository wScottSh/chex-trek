// idGameLocal::BabySitTrail @ 00102a10
// undefined BabySitTrail(idGameLocal * this, mkTrail * param_1)

/* WARNING: Function: __i686.get_pc_thunk.bx replaced with injection: get_pc_thunk_bx */
/* idGameLocal::BabySitTrail(mkTrail*) */

void __thiscall idGameLocal::BabySitTrail(idGameLocal *this,mkTrail *param_1)

{
  idGameLocal *piVar1;
  int iVar2;
  void *pvVar3;
  void *pvVar4;
  int iVar5;
  
  piVar1 = this + 4;
  if (*(int *)(this + 0x10) == 0) {
    iVar5 = *(int *)(this + 0xc);
    if (iVar5 < 1) {
      *(undefined4 *)(this + 0x10) = 0;
      *(undefined4 *)(this + 4) = 0;
      *(undefined4 *)(this + 8) = 0;
    }
    else if (iVar5 != *(int *)(this + 8)) {
      *(int *)(this + 8) = iVar5;
      if (iVar5 < *(int *)(this + 4)) {
        *(int *)(this + 4) = iVar5;
        iVar5 = *(int *)(this + 8);
      }
      pvVar4 = operator_new__(iVar5 << 2);
      *(void **)(this + 0x10) = pvVar4;
      if (0 < *(int *)(this + 4)) {
        iVar5 = 0;
        do {
          *(undefined4 *)(*(int *)(this + 0x10) + iVar5 * 4) = *(undefined4 *)(iVar5 * 4);
          iVar5 = iVar5 + 1;
        } while (iVar5 < *(int *)piVar1);
      }
    }
  }
  iVar5 = *(int *)piVar1;
  if (iVar5 == *(int *)(this + 8)) {
    if (*(int *)(this + 0xc) == 0) {
      *(undefined4 *)(this + 0xc) = 0x10;
    }
    iVar2 = *(int *)(this + 8) + *(int *)(this + 0xc);
    iVar2 = iVar2 - iVar2 % *(int *)(this + 0xc);
    if (iVar2 < 1) {
      if (*(void **)(this + 0x10) != (void *)0x0) {
        operator_delete__(*(void **)(this + 0x10));
      }
      iVar5 = 0;
      *(undefined4 *)(this + 0x10) = 0;
      *(int *)piVar1 = 0;
      *(undefined4 *)(this + 8) = 0;
    }
    else if (*(int *)(this + 8) != iVar2) {
      pvVar4 = *(void **)(this + 0x10);
      *(int *)(this + 8) = iVar2;
      if (iVar2 < *(int *)piVar1) {
        *(int *)piVar1 = iVar2;
        iVar2 = *(int *)(this + 8);
      }
      pvVar3 = operator_new__(iVar2 << 2);
      *(void **)(this + 0x10) = pvVar3;
      if (0 < *(int *)piVar1) {
        iVar5 = 0;
        do {
          *(undefined4 *)(*(int *)(this + 0x10) + iVar5 * 4) =
               *(undefined4 *)((int)pvVar4 + iVar5 * 4);
          iVar5 = iVar5 + 1;
        } while (iVar5 < *(int *)piVar1);
      }
      if (pvVar4 == (void *)0x0) {
        iVar5 = *(int *)piVar1;
      }
      else {
        operator_delete__(pvVar4);
        iVar5 = *(int *)piVar1;
      }
    }
  }
  *(mkTrail **)(*(int *)(this + 0x10) + iVar5 * 4) = param_1;
  *(int *)piVar1 = *(int *)piVar1 + 1;
  return;
}

