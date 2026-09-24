// matt_func_envshot::Spawn @ 002b6b90
// undefined Spawn(matt_func_envshot * this)
// literals (read from .rodata; Ghidra address, type, value):
//   0038158b  string "atSpawn"
//   00372158  string "0"

/* WARNING: Function: __i686.get_pc_thunk.bx replaced with injection: get_pc_thunk_bx */
/* matt_func_envshot::Spawn() */

void __thiscall matt_func_envshot::Spawn(matt_func_envshot *this)

{
  int iVar1;
  char *pcVar2;
  
  (**(code **)(*(int *)this + 0x4c))(this);
  iVar1 = idDict::FindKey((idDict *)(this + 100),"atSpawn");
  pcVar2 = "0";
  if (iVar1 != 0) {
    pcVar2 = *(char **)(*(int *)(iVar1 + 4) + 4);
  }
  iVar1 = __strtol_internal(pcVar2,0,10,0);
  if (iVar1 != 0) {
    idClass::PostEventMS((idClass *)this,(idEventDef *)EV_envShot,0xfa);
  }
  return;
}

