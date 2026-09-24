// mkObjective::Event_Activate @ 001a56a0
// undefined Event_Activate(mkObjective * this, idEntity * param_1)

/* WARNING: Function: __i686.get_pc_thunk.bx replaced with injection: get_pc_thunk_bx */
/* mkObjective::Event_Activate(idEntity*) */

void __thiscall mkObjective::Event_Activate(mkObjective *this,idEntity *param_1)

{
  mkObjective mVar1;
  int iVar2;
  undefined1 *puVar3;
  
  if ((this[0x2e4] == (mkObjective)0x0) || (this == (mkObjective *)param_1)) {
    mVar1 = (mkObjective)AttachToLocalPlayer(this,(bool)((byte)this[0x2e4] ^ 1));
    this[0x2e4] = mVar1;
  }
  else {
    RemoveFromLocalPlayer(this,true);
    this[0x2e4] = (mkObjective)0x0;
    iVar2 = idDict::FindKey((idDict *)(this + 100),"remove");
    puVar3 = &LAB_00372157_1;
    if (iVar2 != 0) {
      puVar3 = *(undefined1 **)(*(int *)(iVar2 + 4) + 4);
    }
    iVar2 = __strtol_internal(puVar3,0,10,0);
    if (iVar2 != 0) {
      idClass::ProcessEvent((idClass *)this,(idEventDef *)PTR_EV_Remove_003e02dc);
      return;
    }
  }
  return;
}

