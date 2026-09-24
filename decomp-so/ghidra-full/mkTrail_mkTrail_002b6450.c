// mkTrail::~mkTrail @ 002b6450
// undefined ~mkTrail(mkTrail * this)

/* WARNING: Function: __i686.get_pc_thunk.bx replaced with injection: get_pc_thunk_bx */
/* mkTrail::~mkTrail() */

void __thiscall mkTrail::~mkTrail(mkTrail *this)

{
  int iVar1;
  int iVar2;
  mkTrail *pmVar3;
  mkTrail *pmVar4;
  
  *(undefined **)this = PTR_vtable_003e0020 + 8;
  pmVar3 = this;
  idGameLocal::RemoveTrail((idGameLocal *)PTR_gameLocal_003e0cac,this);
  pmVar4 = *(mkTrail **)(this + 0x188);
  if (pmVar4 != (mkTrail *)0xffffffff) {
    (**(code **)(**(int **)PTR_gameRenderWorld_003e10a0 + 0x14))
              (*(int **)PTR_gameRenderWorld_003e10a0);
    *(undefined4 *)(this + 0x188) = 0xffffffff;
    pmVar3 = pmVar4;
  }
  pmVar4 = *(mkTrail **)(this + 0xa4);
  if (pmVar4 != (mkTrail *)0x0) {
    (**(code **)(**(int **)PTR_renderModelManager_003e0128 + 0x1c))
              (*(int **)PTR_renderModelManager_003e0128);
    pmVar3 = pmVar4;
  }
  if (0 < *(int *)(this + 0x94)) {
    iVar2 = 0;
    do {
      iVar1 = iVar2 * 4;
      iVar2 = iVar2 + 1;
      operator_delete(*(void **)(*(int *)(this + 0xa0) + iVar1));
    } while (iVar2 < *(int *)(this + 0x94));
  }
  if (*(void **)(this + 0xa0) != (void *)0x0) {
    operator_delete__(*(void **)(this + 0xa0));
  }
  *(undefined4 *)(this + 0xa0) = 0;
  *(int *)(this + 0x94) = 0;
  *(undefined4 *)(this + 0x98) = 0;
  idDict::Clear((idDict *)(this + 8));
  idHashIndex::Free((idHashIndex *)(this + 0x18));
  if (*(void **)(this + 0x14) != (void *)0x0) {
    operator_delete__(*(void **)(this + 0x14));
  }
  *(undefined4 *)(this + 0x14) = 0;
  *(undefined4 *)(this + 8) = 0;
  *(undefined4 *)(this + 0xc) = 0;
  idClass::~idClass((idClass *)this);
  idClass::operator_delete((idClass *)this,pmVar3);
  return;
}

