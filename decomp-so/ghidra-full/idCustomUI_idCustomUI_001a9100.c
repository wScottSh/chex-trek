// idCustomUI::~idCustomUI @ 001a9100
// undefined ~idCustomUI(idCustomUI * this)

/* WARNING: Function: __i686.get_pc_thunk.bx replaced with injection: get_pc_thunk_bx */
/* idCustomUI::~idCustomUI() */

void __thiscall idCustomUI::~idCustomUI(idCustomUI *this)

{
  void *unaff_EBX;
  
  *(undefined **)this = PTR_vtable_003e1390 + 8;
  idEntity::~idEntity((idEntity *)this);
  idClass::operator_delete((idClass *)this,unaff_EBX);
  return;
}

