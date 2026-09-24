// mkTrail::ModelCallback @ 002b4c70
// undefined ModelCallback(renderEntity_s * param_1, renderView_s * param_2)
// literals: none

/* WARNING: Function: __i686.get_pc_thunk.bx replaced with injection: get_pc_thunk_bx */
/* mkTrail::ModelCallback(renderEntity_s*, renderView_s const*) */

undefined1 mkTrail::ModelCallback(renderEntity_s *param_1,renderView_s *param_2)

{
  undefined1 uVar1;
  
  uVar1 = UpdateRenderEntity(*(mkTrail **)(param_1 + 4),param_1,param_2);
  return uVar1;
}

