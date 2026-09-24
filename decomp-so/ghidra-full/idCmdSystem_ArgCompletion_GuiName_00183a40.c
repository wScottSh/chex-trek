// idCmdSystem::ArgCompletion_GuiName @ 00183a40
// undefined ArgCompletion_GuiName(idCmdArgs * param_1, _func_void_char_ptr * param_2)

/* WARNING: Function: __i686.get_pc_thunk.bx replaced with injection: get_pc_thunk_bx */
/* idCmdSystem::ArgCompletion_GuiName(idCmdArgs const&, void (*)(char const*)) */

void idCmdSystem::ArgCompletion_GuiName(idCmdArgs *param_1,_func_void_char_ptr *param_2)

{
  (**(code **)(**(int **)PTR_cmdSystem_003e076c + 0x2c))
            (*(int **)PTR_cmdSystem_003e076c,param_1,param_2,"guis/",0,&LAB_003710d8,0);
  return;
}

