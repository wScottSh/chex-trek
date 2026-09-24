// mkTrail::CreateInstance @ 002b53f0
// undefined CreateInstance(void)
// literals: none

/* WARNING: Function: __i686.get_pc_thunk.bx replaced with injection: get_pc_thunk_bx */
/* mkTrail::CreateInstance() */

mkTrail * mkTrail::CreateInstance(void)

{
  mkTrail *this;
  uint in_stack_ffffffd8;
  
  this = idClass::operator_new((idClass *)0x18c,in_stack_ffffffd8);
  mkTrail(this);
  idClass::FindUninitializedMemory();
  return this;
}

