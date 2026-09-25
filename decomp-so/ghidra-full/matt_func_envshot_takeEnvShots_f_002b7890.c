// matt_func_envshot::takeEnvShots_f @ 002b7890
// undefined takeEnvShots_f(idCmdArgs * param_1)
// literals (Ghidra address of the data, or of the instruction for an immediate; type; value):
//   003815b6  string "%i envShots taken\n"

/* WARNING: Function: __i686.get_pc_thunk.bx replaced with injection: get_pc_thunk_bx */
/* matt_func_envshot::takeEnvShots_f(idCmdArgs const&) */

void matt_func_envshot::takeEnvShots_f(idCmdArgs *param_1)

{
  matt_func_envshot *this;
  int iVar1;
  undefined *puVar2;
  int iVar3;
  int local_14;
  
  local_14 = 0;
  if (0 < *(int *)(PTR_gameLocal_003e0cac + 0x8f48)) {
    iVar3 = 0;
    puVar2 = PTR_gameLocal_003e0cac;
    do {
      this = *(matt_func_envshot **)(puVar2 + 0xf44);
      if (this != (matt_func_envshot *)0x0) {
        iVar1 = (*(code *)**(undefined4 **)this)(this);
        if ((*(int *)(PTR_Type_003e0430 + 0x38) <= *(int *)(iVar1 + 0x38)) &&
           (*(int *)(iVar1 + 0x38) <= *(int *)(PTR_Type_003e0430 + 0x3c))) {
          Event_envShot(this);
          local_14 = local_14 + 1;
        }
      }
      iVar3 = iVar3 + 1;
      puVar2 = puVar2 + 4;
    } while (iVar3 < *(int *)(PTR_gameLocal_003e0cac + 0x8f48));
  }
  (**(code **)(**(int **)PTR_common_003e01fc + 0x44))
            (*(int **)PTR_common_003e01fc,"%i envShots taken\n",local_14);
  return;
}

