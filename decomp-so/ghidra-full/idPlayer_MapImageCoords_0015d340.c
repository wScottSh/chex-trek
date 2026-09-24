// idPlayer::MapImageCoords @ 0015d340
// undefined MapImageCoords(idPlayer * this, float param_1, float param_2, idVec2 * param_3, idVec2 * param_4)

/* idPlayer::MapImageCoords(float, float, idVec2 const&, idVec2&) */

void __thiscall
idPlayer::MapImageCoords(idPlayer *this,float param_1,float param_2,idVec2 *param_3,idVec2 *param_4)

{
  *(float *)param_4 =
       ((*(float *)param_3 - *(float *)(this + 0x1e94)) * param_1) /
       (*(float *)(this + 0x1e9c) - *(float *)(this + 0x1e94));
  *(float *)(param_4 + 4) =
       ((*(float *)(this + 0x1e98) - *(float *)(param_3 + 4)) * param_2) /
       (*(float *)(this + 0x1e98) - *(float *)(this + 0x1ea0));
  return;
}

