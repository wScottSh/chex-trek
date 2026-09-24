// idTarget_EndLevelGUI::~idTarget_EndLevelGUI @ 001a9180
// undefined ~idTarget_EndLevelGUI(idTarget_EndLevelGUI * this)
// literals: none

/* WARNING: Function: __i686.get_pc_thunk.bx replaced with injection: get_pc_thunk_bx */
/* idTarget_EndLevelGUI::~idTarget_EndLevelGUI() */

void __thiscall idTarget_EndLevelGUI::~idTarget_EndLevelGUI(idTarget_EndLevelGUI *this)

{
  *(undefined **)this = PTR_vtable_003e15c8 + 8;
  *(undefined **)this = PTR_vtable_003e1390 + 8;
  idEntity::~idEntity((idEntity *)this);
  return;
}

