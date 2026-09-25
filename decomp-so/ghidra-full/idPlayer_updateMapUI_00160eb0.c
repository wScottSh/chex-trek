// idPlayer::updateMapUI @ 00160eb0
// undefined updateMapUI(idPlayer * this, idUserInterface * param_1, int param_2, bool param_3)
// literals (Ghidra address of the data, or of the instruction for an immediate; type; value):
//   00371d2b  string "%s%i"
//   00372bc8  float  320.0
//   00372bcc  float  240.0
//   00371d30  string "hud_map_mtr"
//   00371d3c  string "hud_map_faded_mtr"
//   00371d4e  string "map_w"
//   00371d54  string "map_h"
//   00371d5a  string "map_pos_x"
//   00371d64  string "map_pos_y"
//   00371d6e  string "player_x"
//   00371d77  string "player_y"
//   00371d80  string "player_direction"
//   00371d91  string "map_obj%d_x"
//   00371d9d  string "map_obj%d_y"
//   00371da9  string "map_obj%d_c"
//   0036d274  float  9.0
//   0036d460  float  0.1
//   0036b1a8  float  16.0
//   00372bc4  float  -100.0
//   0036d46c  float  100.0

/* WARNING: Function: __i686.get_pc_thunk.bx replaced with injection: get_pc_thunk_bx */
/* idPlayer::updateMapUI(idUserInterface*, int, bool) */

void __thiscall
idPlayer::updateMapUI(idPlayer *this,idUserInterface *param_1,int param_2,bool param_3)

{
  char cVar1;
  float fVar2;
  idPlayer iVar3;
  code *pcVar4;
  idEntity *this_00;
  float fVar5;
  float fVar6;
  undefined4 uVar7;
  int *piVar8;
  idVec2 *piVar9;
  undefined4 *puVar10;
  int iVar11;
  int iVar12;
  bool bVar13;
  float fStack_20;
  float fStack_1c;
  float fStack_18;
  float fStack_14;
  
  fVar5 = *(float *)(this + 0x1e44) * *(float *)(this + 0x1e34);
  fVar6 = *(float *)(this + 0x1e34) * *(float *)(this + 0x1e48);
  if ((((byte)this[0x1e30] & 1) != 0) || (param_3)) {
    piVar8 = (int *)idEntity::GetPhysics((idEntity *)this);
    puVar10 = (undefined4 *)(**(code **)(*piVar8 + 0x84))(piVar8,0);
    *(undefined4 *)(this + 0x1e38) = *puVar10;
    piVar8 = (int *)idEntity::GetPhysics((idEntity *)this);
    iVar12 = (**(code **)(*piVar8 + 0x84))(piVar8,0);
    *(undefined4 *)(this + 0x1e3c) = *(undefined4 *)(iVar12 + 4);
    if (param_3) goto LAB_00160f50;
    if (((byte)this[0x1e30] & 4) == 0) goto LAB_00160f11;
LAB_00161381:
    fVar2 = *(float *)(this + 0x1e34);
    if (0.1 < fVar2) {
      *(float *)(this + 0x1e34) = fVar2 / -100.0 + fVar2;
      iVar3 = this[0x1e30];
      goto joined_r0x00161425;
    }
    if (((byte)this[0x1e30] & 2) != 0) goto LAB_00161356;
LAB_00160f22:
    iVar12 = *(int *)(this + 0x1e30);
joined_r0x00161379:
    bVar13 = iVar12 == 0x10;
    if (!bVar13) {
LAB_00160f35:
      if (bVar13 || iVar12 < 0x10) {
        if ((iVar12 == 8) && (*(float *)(this + 0x1e3c) < *(float *)(this + 0x1e98))) {
          *(float *)(this + 0x1e3c) = *(float *)(this + 0x1e3c) + 16.0;
        }
      }
      else if (iVar12 == 0x20) {
        if (*(float *)(this + 0x1e94) < *(float *)(this + 0x1e38)) {
          *(float *)(this + 0x1e38) = *(float *)(this + 0x1e38) - 16.0;
        }
      }
      else if ((iVar12 == 0x40) && (*(float *)(this + 0x1e38) < *(float *)(this + 0x1e9c))) {
        *(float *)(this + 0x1e38) = *(float *)(this + 0x1e38) + 16.0;
      }
      goto LAB_00160f50;
    }
  }
  else {
    if (((byte)this[0x1e30] & 4) != 0) goto LAB_00161381;
LAB_00160f11:
    iVar3 = this[0x1e30];
joined_r0x00161425:
    if (((byte)iVar3 & 2) == 0) goto LAB_00160f22;
LAB_00161356:
    fVar2 = *(float *)(this + 0x1e34);
    if (9.0 <= fVar2) {
      iVar12 = *(int *)(this + 0x1e30);
      goto joined_r0x00161379;
    }
    *(float *)(this + 0x1e34) = fVar2 / 100.0 + fVar2;
    iVar12 = *(int *)(this + 0x1e30);
    bVar13 = false;
    if (iVar12 != 0x10) goto LAB_00160f35;
  }
  if (*(float *)(this + 0x1ea0) < *(float *)(this + 0x1e3c)) {
    *(float *)(this + 0x1e3c) = *(float *)(this + 0x1e3c) - 16.0;
  }
LAB_00160f50:
  MapImageCoords(this,fVar5,fVar6,(idVec2 *)(this + 0x1e38),(idVec2 *)&fStack_18);
  fStack_18 = 320.0 - fStack_18;
  fStack_14 = 240.0 - fStack_14;
  pcVar4 = *(code **)(*(int *)param_1 + 0x38);
  uVar7 = va("%s%i",*(undefined4 *)(this + 0x1e64),param_2);
  (*pcVar4)(param_1,"hud_map_mtr",uVar7);
  pcVar4 = *(code **)(*(int *)param_1 + 0x38);
  iVar12 = 0;
  if (param_2 != 0) {
    iVar12 = param_2 + -1;
  }
  iVar11 = 0;
  uVar7 = va("%s%i",*(undefined4 *)(this + 0x1e64),iVar12);
  (*pcVar4)(param_1,&UNK_00371d3c,uVar7);
  (**(code **)(*(int *)param_1 + 0x40))(param_1,"map_w",(int)fVar5);
  (**(code **)(*(int *)param_1 + 0x40))(param_1,&UNK_00371d54,(int)fVar6);
  (**(code **)(*(int *)param_1 + 0x40))(param_1,"map_pos_x",(int)fStack_18);
  (**(code **)(*(int *)param_1 + 0x40))(param_1,&UNK_00371d64,(int)fStack_14);
  piVar8 = (int *)idEntity::GetPhysics((idEntity *)this);
  piVar9 = (idVec2 *)(**(code **)(*piVar8 + 0x84))(piVar8,0);
  MapImageCoords(this,fVar5,fVar6,piVar9,(idVec2 *)&fStack_20);
  (**(code **)(*(int *)param_1 + 0x40))(param_1,"player_x",(int)(fStack_18 + fStack_20) + -0x10);
  (**(code **)(*(int *)param_1 + 0x40))(param_1,&UNK_00371d77,(int)(fStack_14 + fStack_1c) + -0x10);
  (**(code **)(*(int *)param_1 + 0x44))(param_1,"player_direction",*(undefined4 *)(this + 0x1238));
  do {
    this_00 = *(idEntity **)(this + iVar11 * 4 + 0x1ef4);
    if (this_00 != (idEntity *)0x0) {
      cVar1 = '\x02';
      if (*(int *)(this_00 + 0x2c0) <= param_2) {
        cVar1 = (param_2 <= *(int *)(this_00 + 0x2c0)) * '\x02' + '\x01';
      }
      iVar12 = iVar11 + 1;
      piVar8 = (int *)idEntity::GetPhysics(this_00);
      piVar9 = (idVec2 *)(**(code **)(*piVar8 + 0x84))(piVar8,0);
      MapImageCoords(this,fVar5,fVar6,piVar9,(idVec2 *)&fStack_20);
      fVar2 = fStack_18 + fStack_20;
      pcVar4 = *(code **)(*(int *)param_1 + 0x40);
      uVar7 = va("map_obj%d_x",iVar12);
      (*pcVar4)(param_1,uVar7,(int)fVar2 + -0x10);
      fVar2 = fStack_14 + fStack_1c;
      pcVar4 = *(code **)(*(int *)param_1 + 0x40);
      uVar7 = va("map_obj%d_y",iVar12);
      (*pcVar4)(param_1,uVar7,(int)fVar2 + -0x10);
      pcVar4 = *(code **)(*(int *)param_1 + 0x40);
      uVar7 = va("map_obj%d_c",iVar12);
      (*pcVar4)(param_1,uVar7,cVar1);
    }
    iVar11 = iVar11 + 1;
  } while (iVar11 < 5);
  return;
}

