// idPlayer::updateMap @ 00164720
// undefined updateMap(idPlayer * this)

/* WARNING: Function: __i686.get_pc_thunk.bx replaced with injection: get_pc_thunk_bx */
/* idPlayer::updateMap() */

void __thiscall idPlayer::updateMap(idPlayer *this)

{
  char cVar1;
  int iVar2;
  
  if (((PTR_gameLocal_003e0cac[0x251890] == '\0') && (*(int *)(this + 0x142c) != 0)) &&
     (*(int *)(this + 0x1428) != 0)) {
    iVar2 = HudMapLevel(this,(idVec3 *)0x0);
    if ((this[0x1430] != (idPlayer)0x0) &&
       (cVar1 = (**(code **)(**(int **)(this + 0x142c) + 0x4c))
                          (*(int **)(this + 0x142c),&LAB_00371dc5_3,&LAB_00372157_1), cVar1 != '\0')
       ) {
      updateMapUI(this,*(idUserInterface **)(this + 0x142c),iVar2,false);
    }
    cVar1 = (**(code **)(**(int **)(this + 0x1428) + 0x4c))
                      (*(int **)(this + 0x1428),&LAB_00371dc5_3,&LAB_00372157_1);
    if (cVar1 != '\0') {
      updateMapUI(this,*(idUserInterface **)(this + 0x1428),iVar2,true);
    }
    updateHudMapAlpha(this,iVar2);
  }
  return;
}

