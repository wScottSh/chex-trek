// idPlayer::clearCustomUI @ 0015d320
// undefined clearCustomUI(idPlayer * this)
// literals: none

/* idPlayer::clearCustomUI() */

void __thiscall idPlayer::clearCustomUI(idPlayer *this)

{
  *(undefined4 *)(this + 0x1f10) = 0;
  *(undefined4 *)(this + 0x1f0c) = 0;
  return;
}

