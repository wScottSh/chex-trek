// idWeapon::Event_SetProj @ 001af990
// undefined Event_SetProj(idWeapon * this, char * param_1)

/* WARNING: Function: __i686.get_pc_thunk.bx replaced with injection: get_pc_thunk_bx */
/* idWeapon::Event_SetProj(char const*) */

void __thiscall idWeapon::Event_SetProj(idWeapon *this,char *param_1)

{
  int iVar1;
  
  iVar1 = idGameLocal::FindEntityDef((idGameLocal *)PTR_gameLocal_003e0cac,param_1,false);
  if (iVar1 != 0) {
    idDict::operator=((idDict *)(this + 0x798),(idDict *)(iVar1 + 8));
  }
  return;
}

