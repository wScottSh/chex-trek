// matt_func_envshot::~matt_func_envshot @ 002b7940
// undefined ~matt_func_envshot(matt_func_envshot * this)
// literals: none

/* WARNING: Function: __i686.get_pc_thunk.bx replaced with injection: get_pc_thunk_bx */
/* matt_func_envshot::~matt_func_envshot() */

void __thiscall matt_func_envshot::~matt_func_envshot(matt_func_envshot *this)

{
  void *unaff_EBX;
  
  *(undefined **)this = PTR_vtable_003e0170 + 8;
  idEntity::~idEntity((idEntity *)this);
  idClass::operator_delete((idClass *)this,unaff_EBX);
  return;
}

