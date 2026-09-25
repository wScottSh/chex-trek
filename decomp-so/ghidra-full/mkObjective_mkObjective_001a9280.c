// mkObjective::~mkObjective @ 001a9280
// undefined ~mkObjective(mkObjective * this)
// literals: none

/* WARNING: Function: __i686.get_pc_thunk.bx replaced with injection: get_pc_thunk_bx */
/* mkObjective::~mkObjective() */

void __thiscall mkObjective::~mkObjective(mkObjective *this)

{
  void *in_stack_ffffffe8;
  
  *(undefined **)this = PTR_vtable_003e1310 + 8;
  idStr::FreeData((idStr *)(this + 0x2c4));
  idStr::FreeData((idStr *)(this + 0x2a0));
  idStr::FreeData((idStr *)(this + 0x280));
  idEntity::~idEntity((idEntity *)this);
  idClass::operator_delete((idClass *)this,in_stack_ffffffe8);
  return;
}

