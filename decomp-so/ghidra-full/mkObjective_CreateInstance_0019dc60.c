// mkObjective::CreateInstance @ 0019dc60
// undefined CreateInstance(void)
// literals: none

/* WARNING: Function: __i686.get_pc_thunk.bx replaced with injection: get_pc_thunk_bx */
/* mkObjective::CreateInstance() */

idEntity * mkObjective::CreateInstance(void)

{
  undefined *puVar1;
  idEntity *this;
  uint in_stack_ffffffd8;
  
  this = idClass::operator_new((idClass *)0x2e8,in_stack_ffffffd8);
  idEntity::idEntity(this);
  puVar1 = PTR_vtable_003e1310;
  *(undefined4 *)(this + 0x2c4) = 0;
  *(undefined **)this = puVar1 + 8;
  *(undefined4 *)(this + 0x280) = 0;
  *(idEntity **)(this + 0x284) = this + 0x28c;
  *(undefined4 *)(this + 0x288) = 0x14;
  *(undefined4 *)(this + 0x2a0) = 0;
  this[0x28c] = (idEntity)0x0;
  *(idEntity **)(this + 0x2a4) = this + 0x2ac;
  *(undefined4 *)(this + 0x2a8) = 0x14;
  this[0x2ac] = (idEntity)0x0;
  *(undefined4 *)(this + 0x2cc) = 0x14;
  *(idEntity **)(this + 0x2c8) = this + 0x2d0;
  this[0x2d0] = (idEntity)0x0;
  idClass::FindUninitializedMemory();
  return this;
}

