// idCustomUI::CreateInstance @ 0019e300
// undefined CreateInstance(void)

/* WARNING: Function: __i686.get_pc_thunk.bx replaced with injection: get_pc_thunk_bx */
/* idCustomUI::CreateInstance() */

undefined4 idCustomUI::CreateInstance(void)

{
  idGameLocal::Error((idGameLocal *)PTR_gameLocal_003e0cac,"Cannot instanciate abstract class %s.",
                     &LAB_00373d0d_7);
  return 0;
}

