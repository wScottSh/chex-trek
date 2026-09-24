// idPlayer::HudMapLevel @ 0015e450
// undefined HudMapLevel(idPlayer * this, idVec3 * param_1)

/* WARNING: Function: __i686.get_pc_thunk.bx replaced with injection: get_pc_thunk_bx */
/* WARNING: Globals starting with '_' overlap smaller symbols at the same address */
/* idPlayer::HudMapLevel(idVec3 const*) */

int __thiscall idPlayer::HudMapLevel(idPlayer *this,idVec3 *param_1)

{
  float fVar1;
  int iVar2;
  int *piVar3;
  
  if (param_1 == (idVec3 *)0x0) {
    piVar3 = (int *)idEntity::GetPhysics((idEntity *)this);
    iVar2 = (**(code **)(*piVar3 + 0x84))(piVar3,0);
    fVar1 = _LAB_0036b0e4 * *(float *)(*(int *)(PTR_pm_normalheight_003e04b0 + 0x2c) + 0x28) +
            *(float *)(iVar2 + 8);
  }
  else {
    fVar1 = *(float *)(param_1 + 8);
  }
  if (fVar1 < *(float *)(this + 0x1e80)) {
    idGameLocal::Warning((idGameLocal *)PTR_gameLocal_003e0cac,"Location below lowest MapLevel");
    iVar2 = 0;
  }
  else {
    iVar2 = 1;
    if (((*(float *)(this + 0x1e84) <= fVar1) && (iVar2 = 2, *(float *)(this + 0x1e88) <= fVar1)) &&
       (iVar2 = 3, *(float *)(this + 0x1e8c) <= fVar1)) {
      iVar2 = (*(float *)(this + 0x1e90) <= fVar1) + 4;
    }
    iVar2 = iVar2 + -1;
  }
  return iVar2;
}

