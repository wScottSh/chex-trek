// idCustomUI::~idCustomUI @ 001a9150
// undefined ~idCustomUI(idCustomUI * this)
// literals: none

/* WARNING: Function: __i686.get_pc_thunk.bx replaced with injection: get_pc_thunk_bx */
/* idCustomUI::~idCustomUI() */

void __thiscall idCustomUI::~idCustomUI(idCustomUI *this)

{
  *(undefined **)this = PTR_vtable_003e1390 + 8;
  idEntity::~idEntity((idEntity *)this);
  return;
}

