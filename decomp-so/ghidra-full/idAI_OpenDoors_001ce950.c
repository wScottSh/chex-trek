// idAI::OpenDoors @ 001ce950
// undefined OpenDoors(idAI * this, idEntity * param_1)

/* WARNING: Function: __i686.get_pc_thunk.bx replaced with injection: get_pc_thunk_bx */
/* idAI::OpenDoors(idEntity*) */

void __thiscall idAI::OpenDoors(idAI *this,idEntity *param_1)

{
  char cVar1;
  int iVar2;
  
  if (param_1 != (idEntity *)0x0) {
    iVar2 = (*(code *)**(undefined4 **)param_1)(param_1);
    if ((((*(int *)(PTR_Type_003e01a8 + 0x38) <= *(int *)(iVar2 + 0x38)) &&
         (*(int *)(iVar2 + 0x38) <= *(int *)(PTR_Type_003e01a8 + 0x3c))) &&
        (iVar2 = idDoor::IsLocked((idDoor *)param_1), iVar2 == 0)) &&
       (cVar1 = (**(code **)(*(int *)param_1 + 0x90))(param_1), cVar1 != '\0')) {
      idDoor::Use((idDoor *)param_1,param_1,(idEntity *)this);
    }
  }
  return;
}

