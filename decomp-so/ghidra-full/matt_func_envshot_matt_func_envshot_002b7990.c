// matt_func_envshot::~matt_func_envshot @ 002b7990
// undefined ~matt_func_envshot(matt_func_envshot * this)
// literals: none

/* WARNING: Function: __i686.get_pc_thunk.bx replaced with injection: get_pc_thunk_bx */
/* matt_func_envshot::~matt_func_envshot() */

void __thiscall matt_func_envshot::~matt_func_envshot(matt_func_envshot *this)

{
  *(undefined **)this = PTR_vtable_003e0170 + 8;
  idEntity::~idEntity((idEntity *)this);
  return;
}

