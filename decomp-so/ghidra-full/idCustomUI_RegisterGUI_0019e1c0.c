// idCustomUI::RegisterGUI @ 0019e1c0
// undefined RegisterGUI(idCustomUI * this)
// literals: none

/* WARNING: Function: __i686.get_pc_thunk.bx replaced with injection: get_pc_thunk_bx */
/* idCustomUI::RegisterGUI() */

void __thiscall idCustomUI::RegisterGUI(idCustomUI *this)

{
  idPlayer *this_00;
  
  this_00 = (idPlayer *)idGameLocal::GetLocalPlayer((idGameLocal *)PTR_gameLocal_003e0cac);
                    /* try { // try from 0019e1ea to 001ae1ee has its CatchHandler @ 0019e405 */
  if ((this_00 != (idPlayer *)0x0) && (*(int *)(this + 0x27c) != 0)) {
    this[0x280] = (idCustomUI)0x1;
                    /* try { // try from 0019e20d to 001ae416 has its CatchHandler @ 0019d7a0 */
    idPlayer::useCustomUI(this_00,*(idUserInterface **)(this + 0x27c),this);
  }
  return;
}

