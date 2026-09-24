// idCustomUI::idCustomUI @ 0019dd60
// undefined idCustomUI(idCustomUI * this)

/* WARNING: Function: __i686.get_pc_thunk.bx replaced with injection: get_pc_thunk_bx */
/* idCustomUI::idCustomUI() */

void __thiscall idCustomUI::idCustomUI(idCustomUI *this)

{
  undefined *puVar1;
  
  idEntity::idEntity((idEntity *)this);
  puVar1 = PTR_vtable_003e1390;
  this[0x280] = (idCustomUI)0x0;
  *(undefined **)this = puVar1 + 8;
  *(undefined4 *)(this + 0x27c) = 0;
  return;
}

