// mkTrail::~mkTrail @ 002b69a0
// undefined ~mkTrail(mkTrail * this)
// literals: none

/* WARNING: Function: __i686.get_pc_thunk.bx replaced with injection: get_pc_thunk_bx */
/* mkTrail::~mkTrail() */

void __thiscall mkTrail::~mkTrail(mkTrail *this)

{
  int iVar1;
  int iVar2;
  
  *(undefined **)this = PTR_vtable_003e0020 + 8;
  idGameLocal::RemoveTrail((idGameLocal *)PTR_gameLocal_003e0cac,this);
  if (*(int *)(this + 0x188) != -1) {
    (**(code **)(**(int **)PTR_gameRenderWorld_003e10a0 + 0x14))
              (*(int **)PTR_gameRenderWorld_003e10a0,*(int *)(this + 0x188));
    *(undefined4 *)(this + 0x188) = 0xffffffff;
  }
  if (*(int *)(this + 0xa4) != 0) {
    (**(code **)(**(int **)PTR_renderModelManager_003e0128 + 0x1c))
              (*(int **)PTR_renderModelManager_003e0128,*(int *)(this + 0xa4));
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
  return;
}

