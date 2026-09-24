// mkTrail::FadeTrail @ 002b5470
// undefined FadeTrail(mkTrail * this)

/* WARNING: Function: __i686.get_pc_thunk.bx replaced with injection: get_pc_thunk_bx */
/* mkTrail::FadeTrail() */

void __thiscall mkTrail::FadeTrail(mkTrail *this)

{
  int iVar1;
  int iVar2;
  undefined1 *puVar3;
  longdouble lVar4;
  
  *(undefined4 *)(this + 4) = 0;
  if (*(int *)(this + 0x34) != -1000) {
    iVar1 = *(int *)(PTR_gameLocal_003e0cac + 0x251884);
    iVar2 = idDict::FindKey((idDict *)(this + 8),"fadeDelay");
    puVar3 = &LAB_00372157_1;
    if (iVar2 != 0) {
      puVar3 = *(undefined1 **)(*(int *)(iVar2 + 4) + 4);
    }
    lVar4 = (longdouble)__strtod_internal(puVar3,0,0);
    iVar1 = iVar1 + (int)((float)lVar4 * *(float *)PTR_M_SEC2MS_003e0fc8);
    *(int *)(this + 0x68) = iVar1;
    *(int *)(this + 0x6c) = iVar1 + *(int *)(this + 0x34);
    return;
  }
  *(uint *)(this + 0x3c) = *(uint *)(this + 0x3c) & 0xfffffffe;
  return;
}

