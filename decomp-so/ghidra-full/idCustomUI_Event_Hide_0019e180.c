// idCustomUI::Event_Hide @ 0019e180
// undefined Event_Hide(idCustomUI * this)
// literals: none

/* WARNING: Function: __i686.get_pc_thunk.bx replaced with injection: get_pc_thunk_bx */
/* idCustomUI::Event_Hide() */

void __thiscall idCustomUI::Event_Hide(idCustomUI *this)

{
  idEntity::Hide((idEntity *)this);
  UnregisterGUI(this);
  return;
}

