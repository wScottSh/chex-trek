// idPlayer::incSecretsFound @ 0015d2e0
// undefined incSecretsFound(idPlayer * this)
// literals: none

/* idPlayer::incSecretsFound() */

void __thiscall idPlayer::incSecretsFound(idPlayer *this)

{
  *(int *)(this + 0x1ed0) = *(int *)(this + 0x1ed0) + 1;
  return;
}

