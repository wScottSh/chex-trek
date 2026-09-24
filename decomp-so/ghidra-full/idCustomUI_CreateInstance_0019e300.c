// idCustomUI::CreateInstance @ 0019e300
// undefined CreateInstance(void)
// literals (read from .rodata; Ghidra address, type, value):
//   00373d14  string "idCustomUI"
//   0036c5ec  string "Cannot instanciate abstract class %s."

/* WARNING: Function: __i686.get_pc_thunk.bx replaced with injection: get_pc_thunk_bx */
/* idCustomUI::CreateInstance() */

undefined4 idCustomUI::CreateInstance(void)

{
  idGameLocal::Error((idGameLocal *)PTR_gameLocal_003e0cac,"Cannot instanciate abstract class %s.",
                     "idCustomUI");
  return 0;
}

