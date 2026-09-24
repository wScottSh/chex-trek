// idCustomUI::UnregisterGUI @ 0019e0b0
// undefined UnregisterGUI(idCustomUI * this)

/* WARNING: Function: __i686.get_pc_thunk.bx replaced with injection: get_pc_thunk_bx */
/* idCustomUI::UnregisterGUI() */

void __thiscall idCustomUI::UnregisterGUI(idCustomUI *this)

{
  int *piVar1;
  undefined *puVar2;
  idPlayer *this_00;
  
  puVar2 = PTR_gameLocal_003e0cac;
  this_00 = (idPlayer *)idGameLocal::GetLocalPlayer((idGameLocal *)PTR_gameLocal_003e0cac);
  if (this_00 != (idPlayer *)0x0) {
    idPlayer::clearCustomUI(this_00);
    this[0x280] = (idCustomUI)0x0;
  }
  piVar1 = *(int **)(this + 0x27c);
  if (piVar1 != (int *)0x0) {
    (**(code **)(*piVar1 + 0x5c))(piVar1,0,*(undefined4 *)(puVar2 + 0x251884));
  }
  return;
}

