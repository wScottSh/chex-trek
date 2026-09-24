// idCustomUI::setGUI @ 0019d3d0
// undefined setGUI(idCustomUI * this, char * param_1)

/* WARNING: Function: __i686.get_pc_thunk.bx replaced with injection: get_pc_thunk_bx */
/* idCustomUI::setGUI(char const*) */

void __thiscall idCustomUI::setGUI(idCustomUI *this,char *param_1)

{
  int *piVar1;
  undefined4 uVar2;
  
  if (*param_1 == '\0') {
    piVar1 = *(int **)(this + 0x27c);
  }
  else {
    uVar2 = (**(code **)(**(int **)PTR_uiManager_003e03dc + 0x38))
                      (*(int **)PTR_uiManager_003e03dc,param_1,1,0,1);
    *(undefined4 *)(this + 0x27c) = uVar2;
    piVar1 = *(int **)(this + 0x27c);
  }
  if (piVar1 != (int *)0x0) {
    (**(code **)(*piVar1 + 0x5c))(piVar1,1,*(undefined4 *)(PTR_gameLocal_003e0cac + 0x251884));
    return;
  }
  (**(code **)(**(int **)PTR_common_003e01fc + 0x50))(*(int **)PTR_common_003e01fc,&DAT_00373bc0);
  return;
}

