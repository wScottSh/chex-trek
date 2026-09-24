// mkTrail::mkTrail @ 002b51e0
// undefined mkTrail(mkTrail * this)

/* WARNING: Function: __i686.get_pc_thunk.bx replaced with injection: get_pc_thunk_bx */
/* mkTrail::mkTrail() */

void __thiscall mkTrail::mkTrail(mkTrail *this)

{
  void *pvVar1;
  undefined4 uVar2;
  undefined *puVar3;
  int iVar4;
  void *pvVar5;
  undefined4 *puVar6;
  int iVar7;
  idHashIndex *this_00;
  
  puVar3 = PTR_vtable_003e0020;
  *(undefined4 *)(this + 8) = 0;
  *(undefined **)this = puVar3 + 8;
  this_00 = (idHashIndex *)(this + 0x18);
  *(undefined4 *)(this + 0x10) = 0x10;
  *(undefined4 *)(this + 0x14) = 0;
  *(undefined4 *)(this + 0xc) = 0;
  idHashIndex::Init(this_00,0x400,0x400);
  pvVar1 = *(void **)(this + 0x14);
  *(undefined4 *)(this + 0x10) = 0x10;
  if ((pvVar1 != (void *)0x0) &&
     (iVar7 = (*(int *)(this + 8) + 0xf) - (*(int *)(this + 8) + 0xf) % 0x10,
     iVar7 != *(int *)(this + 0xc))) {
    if (iVar7 < 1) {
      operator_delete__(pvVar1);
      *(undefined4 *)(this + 0x14) = 0;
      *(undefined4 *)(this + 0xc) = 0;
      *(undefined4 *)(this + 8) = 0;
    }
    else {
      *(int *)(this + 0xc) = iVar7;
      iVar4 = iVar7;
      if (iVar7 < *(int *)(this + 8)) {
        iVar4 = *(int *)(this + 0xc);
        *(int *)(this + 8) = iVar7;
      }
      pvVar5 = operator_new__(iVar4 << 3);
      *(void **)(this + 0x14) = pvVar5;
      if (0 < *(int *)(this + 8)) {
        iVar7 = 0;
        do {
          iVar4 = iVar7 * 8;
          puVar6 = (undefined4 *)(iVar7 * 8 + *(int *)(this + 0x14));
          uVar2 = *(undefined4 *)((int)pvVar1 + iVar7 * 8 + 4);
          iVar7 = iVar7 + 1;
          *puVar6 = *(undefined4 *)((int)pvVar1 + iVar4);
          puVar6[1] = uVar2;
        } while (iVar7 < *(int *)(this + 8));
      }
      operator_delete__(pvVar1);
    }
  }
  *(undefined4 *)(this + 0x28) = 0x10;
  idHashIndex::Free(this_00);
  *(undefined4 *)(this + 0x20) = 0x10;
  *(undefined4 *)this_00 = 0x80;
  *(undefined4 *)(this + 0x9c) = 0x10;
  *(undefined4 *)(this + 0xa0) = 0;
  *(undefined4 *)(this + 0x98) = 0;
  *(undefined4 *)(this + 0x94) = 0;
  *(undefined4 *)(this + 0x17c) = 0;
  *(undefined4 *)(this + 0x180) = 0xffffffff;
  this[0x184] = (mkTrail)0x0;
  *(undefined4 *)(this + 0x50) = 0x40000000;
  *(undefined4 *)(this + 0x4c) = 0x42000000;
  *(undefined4 *)(this + 0x54) = 0x41800000;
  *(undefined4 *)(this + 0x90) = 0xf;
  *(undefined4 *)(this + 0x68) = 0;
  return;
}

