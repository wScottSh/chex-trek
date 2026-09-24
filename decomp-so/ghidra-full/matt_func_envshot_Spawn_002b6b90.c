// matt_func_envshot::Spawn @ 002b6b90
// undefined Spawn(matt_func_envshot * this)

/* WARNING: Function: __i686.get_pc_thunk.bx replaced with injection: get_pc_thunk_bx */
/* matt_func_envshot::Spawn() */

void __thiscall matt_func_envshot::Spawn(matt_func_envshot *this)

{
  int iVar1;
  undefined1 *puVar2;
  
  (**(code **)(*(int *)this + 0x4c))(this);
  iVar1 = idDict::FindKey((idDict *)(this + 100),"atSpawn");
  puVar2 = &LAB_00372157_1;
  if (iVar1 != 0) {
    puVar2 = *(undefined1 **)(*(int *)(iVar1 + 4) + 4);
  }
  iVar1 = __strtol_internal(puVar2,0,10,0);
  if (iVar1 != 0) {
    idClass::PostEventMS((idClass *)this,(idEventDef *)EV_envShot,0xfa);
  }
  return;
}

