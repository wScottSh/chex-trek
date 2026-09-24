// idPlayer::useCustomUI @ 0015d300
// undefined useCustomUI(idPlayer * this, idUserInterface * param_1, idCustomUI * param_2)

/* idPlayer::useCustomUI(idUserInterface*, idCustomUI*) */

void __thiscall idPlayer::useCustomUI(idPlayer *this,idUserInterface *param_1,idCustomUI *param_2)

{
  *(idUserInterface **)(this + 0x1f10) = param_1;
  *(idCustomUI **)(this + 0x1f0c) = param_2;
  return;
}

