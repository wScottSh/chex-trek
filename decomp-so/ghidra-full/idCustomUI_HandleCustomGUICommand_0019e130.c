// idCustomUI::HandleCustomGUICommand @ 0019e130
// undefined HandleCustomGUICommand(idCustomUI * this, idEntity * param_1, idToken * param_2)

/* WARNING: Function: __i686.get_pc_thunk.bx replaced with injection: get_pc_thunk_bx */
/* idCustomUI::HandleCustomGUICommand(idEntity*, idToken*) */

bool __thiscall
idCustomUI::HandleCustomGUICommand(idCustomUI *this,idEntity *param_1,idToken *param_2)

{
  int iVar1;
  
  iVar1 = idStr::Icmp(*(char **)(param_2 + 4),"unregister");
  if (iVar1 == 0) {
    UnregisterGUI(this);
  }
  return iVar1 == 0;
}

