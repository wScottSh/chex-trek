// idWorldspawn::Think @ 001bbe40
// undefined Think(idWorldspawn * this)
// literals (Ghidra address of the data, or of the instruction for an immediate; type; value):
//   0036cb92  string "s_volume"
//   00372158  string "0"
//   0036f3d0  float  30.0
//   00375284  float  0.6

/* WARNING: Function: __i686.get_pc_thunk.bx replaced with injection: get_pc_thunk_bx */
/* idWorldspawn::Think() */

void __thiscall idWorldspawn::Think(idWorldspawn *this)

{
  int *piVar1;
  char cVar2;
  int iVar3;
  char *pcVar4;
  longdouble lVar5;
  float fVar6;
  
  if ((*(byte *)(*(int *)(PTR_g_MusicVolume_003e0b68 + 0x2c) + 0x12) & 4) != 0) {
    idEntity::BecomeInactive((idEntity *)this,8);
    if (*(float *)(*(int *)(PTR_g_MusicVolume_003e0b68 + 0x2c) + 0x28) < 1.0) {
      idEntity::StopSound((idEntity *)this,0,false);
    }
    else {
      piVar1 = *(int **)(this + 0x1a0);
      if ((piVar1 == (int *)0x0) || (cVar2 = (**(code **)(*piVar1 + 0x20))(piVar1), cVar2 != '\0'))
      {
                    /* try { // try from 001bbf07 to 001cbff1 has its CatchHandler @ 001bbeb0 */
        iVar3 = idDict::FindKey((idDict *)(this + 100),"s_volume");
        pcVar4 = "0";
        if (iVar3 != 0) {
          pcVar4 = *(char **)(*(int *)(iVar3 + 4) + 4);
        }
        lVar5 = (longdouble)__strtod_internal(pcVar4,0,0);
        fVar6 = 0.6 * *(float *)(*(int *)(PTR_g_MusicVolume_003e0b68 + 0x2c) + 0x28) +
                ((float)lVar5 - 30.0);
      }
      else {
        if ((*(idSoundShader **)(this + 0x1b4) != (idSoundShader *)0x0) &&
           (this[0x1bc] == (idWorldspawn)0x0)) {
          idEntity::StartSoundShader
                    ((idEntity *)this,*(idSoundShader **)(this + 0x1b4),0,0,false,(int *)0x0);
        }
        iVar3 = idDict::FindKey((idDict *)(this + 100),"s_volume");
        pcVar4 = "0";
        if (iVar3 != 0) {
          pcVar4 = *(char **)(*(int *)(iVar3 + 4) + 4);
        }
        lVar5 = (longdouble)__strtod_internal(pcVar4,0,0);
        fVar6 = 0.6 * *(float *)(*(int *)(PTR_g_MusicVolume_003e0b68 + 0x2c) + 0x28) +
                ((float)lVar5 - 30.0);
      }
      idClass::ProcessEvent(this,PTR_EV_FadeSound_003e1560,100,0,0x66,fVar6,0x66,0);
    }
    *(uint *)(*(int *)(PTR_g_MusicVolume_003e0b68 + 0x2c) + 0x10) =
         *(uint *)(*(int *)(PTR_g_MusicVolume_003e0b68 + 0x2c) + 0x10) & 0xfffbffff;
                    /* catch() { ... } // from try @ 001bbf07 with catch @ 001bbeb0
                       catch() { ... } // from try @ 001bc01f with catch @ 001bbeb0
                       catch() { ... } // from try @ 001bc054 with catch @ 001bbeb0 */
    return;
  }
  return;
}

