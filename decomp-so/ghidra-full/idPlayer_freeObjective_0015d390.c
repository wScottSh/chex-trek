// idPlayer::freeObjective @ 0015d390
// undefined freeObjective(idPlayer * this, int param_1)

/* idPlayer::freeObjective(int) */

void __thiscall idPlayer::freeObjective(idPlayer *this,int param_1)

{
  *(undefined4 *)(this + param_1 * 4 + 0x1ef0) = 0;
  *(int *)(this + 0x1f08) = param_1;
  return;
}

