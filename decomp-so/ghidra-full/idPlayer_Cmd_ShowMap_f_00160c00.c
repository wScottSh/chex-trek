// idPlayer::Cmd_ShowMap_f @ 00160c00
// undefined Cmd_ShowMap_f(idCmdArgs * param_1)
// literals (Ghidra address of the data, or of the instruction for an immediate; type; value):
//   0037f468  string ""
//   00371d1d  string "bad level %s\n"
//   00371d05  string "usage: showMap [level]\n"

/* WARNING: Function: __i686.get_pc_thunk.bx replaced with injection: get_pc_thunk_bx */
/* idPlayer::Cmd_ShowMap_f(idCmdArgs const&) */

void idPlayer::Cmd_ShowMap_f(idCmdArgs *param_1)

{
  uint uVar1;
  char *pcVar2;
  
  if (2 < *(int *)param_1) {
    idGameLocal::Printf((idGameLocal *)PTR_gameLocal_003e0cac,"usage: showMap [level]\n");
    return;
  }
  if (*(int *)param_1 == 2) {
    uVar1 = __strtol_internal(*(undefined4 *)(param_1 + 8),0,10,0);
    if (4 < uVar1) {
      pcVar2 = "";
      if (1 < *(int *)param_1) {
        pcVar2 = *(char **)(param_1 + 8);
      }
      idGameLocal::Printf((idGameLocal *)PTR_gameLocal_003e0cac,"bad level %s\n",pcVar2);
      return;
    }
    memset(PTR_hudmap_alpha_003e11ec + uVar1 * 0x10000,0xff,0x10000);
  }
  else {
    memset(PTR_hudmap_alpha_003e11ec,0xff,0x50000);
  }
  return;
}

