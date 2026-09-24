// matt_func_envshot::CreateInstance @ 002b6c20
// undefined CreateInstance(void)
// literals: none

/* WARNING: Function: __i686.get_pc_thunk.bx replaced with injection: get_pc_thunk_bx */
/* matt_func_envshot::CreateInstance() */

idEntity * matt_func_envshot::CreateInstance(void)

{
  idEntity *this;
  uint in_stack_ffffffd8;
  
  this = idClass::operator_new((idClass *)0x27c,in_stack_ffffffd8);
  idEntity::idEntity(this);
  *(undefined **)this = PTR_vtable_003e0170 + 8;
  idClass::FindUninitializedMemory();
  return this;
}

