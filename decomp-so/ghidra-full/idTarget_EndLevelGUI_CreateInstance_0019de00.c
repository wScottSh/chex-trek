// idTarget_EndLevelGUI::CreateInstance @ 0019de00
// undefined CreateInstance(void)
// literals: none

/* WARNING: Function: __i686.get_pc_thunk.bx replaced with injection: get_pc_thunk_bx */
/* idTarget_EndLevelGUI::CreateInstance() */

idCustomUI * idTarget_EndLevelGUI::CreateInstance(void)

{
  idCustomUI *this;
  uint in_stack_ffffffd8;
  
  this = idClass::operator_new((idClass *)0x2e4,in_stack_ffffffd8);
  idCustomUI::idCustomUI(this);
  *(undefined **)this = PTR_vtable_003e15c8 + 8;
  idClass::FindUninitializedMemory();
  return this;
}

