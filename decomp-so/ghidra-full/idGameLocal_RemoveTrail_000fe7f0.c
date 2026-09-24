// idGameLocal::RemoveTrail @ 000fe7f0
// undefined RemoveTrail(idGameLocal * this, mkTrail * param_1)

/* idGameLocal::RemoveTrail(mkTrail*) */

void __thiscall idGameLocal::RemoveTrail(idGameLocal *this,mkTrail *param_1)

{
  int iVar1;
  int iVar2;
  
  iVar2 = *(int *)(this + 4);
  if (0 < iVar2) {
    iVar1 = 0;
    if ((mkTrail *)**(int **)(this + 0x10) != param_1) {
      iVar1 = 0;
      do {
        iVar1 = iVar1 + 1;
        if (iVar1 == iVar2) {
          return;
        }
      } while ((mkTrail *)(*(int **)(this + 0x10))[iVar1] != param_1);
    }
    *(int *)(this + 4) = iVar2 + -1;
    if (iVar1 < iVar2 + -1) {
      iVar2 = iVar1 * 4;
      do {
        iVar1 = iVar1 + 1;
        *(undefined4 *)(iVar2 + *(int *)(this + 0x10)) =
             ((undefined4 *)(iVar2 + *(int *)(this + 0x10)))[1];
        iVar2 = iVar2 + 4;
      } while (iVar1 < *(int *)(this + 4));
      return;
    }
  }
  return;
}

