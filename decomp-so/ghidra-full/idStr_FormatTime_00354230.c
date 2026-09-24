// idStr::FormatTime @ 00354230
// undefined FormatTime(idStr * this, char * param_1, int param_2)
// literals (read from .rodata; Ghidra address, type, value):
//   00371002  string "%i"
//   00385bfa  string "%0"

/* WARNING: Function: __i686.get_pc_thunk.bx replaced with injection: get_pc_thunk_bx */
/* idStr::FormatTime(char const*, int) */

idStr * __thiscall idStr::FormatTime(idStr *this,char *param_1,int param_2)

{
  char cVar1;
  char *pcVar2;
  size_t sVar3;
  int iVar4;
  char cVar5;
  int iVar6;
  int iVar7;
  int local_68;
  int local_64;
  int local_60;
  int local_5c;
  char cStack_55;
  int local_54;
  int iStack_50;
  int iStack_4c;
  int iStack_34;
  int iStack_30;
  char *pcStack_2c;
  int iStack_28;
  char acStack_24 [20];
  
  *(undefined4 *)this = 0;
  *(undefined4 *)(this + 8) = 0x14;
  *(idStr **)(this + 4) = this + 0xc;
  this[0xc] = (idStr)0x0;
  local_60 = 0;
  iVar7 = 0;
  local_68 = 0;
  local_64 = 0;
  local_5c = 0;
  do {
    while( true ) {
      while( true ) {
        while( true ) {
          while( true ) {
            cVar5 = param_1[iVar7];
            iVar7 = iVar7 + 1;
            if (cVar5 != 'h') break;
            local_68 = local_68 + 1;
          }
          if (cVar5 != 'm') break;
          local_64 = local_64 + 1;
        }
        if (cVar5 != 's') break;
        local_60 = local_60 + 1;
      }
      if (cVar5 != 'M') break;
      local_5c = local_5c + 1;
                    /* try { // try from 003548b8 to 003649a3 has its CatchHandler @ 00354eed */
    }
  } while (cVar5 != '\0');
  local_54 = 0;
  if (local_68 != 0) {
    local_54 = param_2 / 3600000;
    param_2 = param_2 % 3600000;
  }
                    /* try { // try from 00354301 to 0036432d has its CatchHandler @ 00354433 */
  iStack_50 = 0;
  if (local_64 != 0) {
    iStack_50 = param_2 / 60000;
    param_2 = param_2 % 60000;
  }
  iStack_4c = 0;
  if (local_60 != 0) {
    iStack_4c = param_2 / 1000;
    param_2 = param_2 % 1000;
  }
  pcStack_2c = acStack_24;
                    /* try { // try from 00354379 to 0036437d has its CatchHandler @ 003543b7 */
  iStack_34 = 0;
                    /* try { // try from 00354381 to 00364385 has its CatchHandler @ 00354433 */
  iStack_30 = 0;
  iStack_28 = 0x14;
  acStack_24[0] = '\0';
  do {
    FreeData((idStr *)&iStack_30);
                    /* try { // try from 003543ee to 003643f2 has its CatchHandler @ 00354437 */
    operator=((idStr *)&iStack_30,"%0");
    cStack_55 = param_1[iStack_34];
    iVar7 = iStack_34 + 1;
    if (cStack_55 == 'h') {
      pcVar2 = (char *)va("%i",local_68);
      if (pcVar2 != (char *)0x0) {
                    /* try { // try from 0035449d to 003644a1 has its CatchHandler @ 0035479f */
        sVar3 = strlen(pcVar2);
        iVar4 = sVar3 + iStack_30;
        if (iStack_28 < iVar4 + 1) {
          ReAllocate((idStr *)&iStack_30,iVar4 + 1,true);
        }
        cVar5 = *pcVar2;
        if (cVar5 != '\0') {
          iVar6 = 0;
          do {
            pcStack_2c[iStack_30 + iVar6] = cVar5;
            cVar5 = pcVar2[iVar6 + 1];
            iVar6 = iVar6 + 1;
          } while (cVar5 != '\0');
        }
        pcStack_2c[iVar4] = '\0';
        iStack_30 = iVar4;
      }
      if (iStack_28 < iStack_30 + 2) {
        ReAllocate((idStr *)&iStack_30,iStack_30 + 2,true);
      }
                    /* try { // try from 0035450e to 0036460d has its CatchHandler @ 003547a3 */
      pcStack_2c[iStack_30] = 'i';
      iStack_30 = iStack_30 + 1;
      pcStack_2c[iStack_30] = '\0';
      pcVar2 = (char *)va(pcStack_2c,local_54);
      if (pcVar2 != (char *)0x0) {
        sVar3 = strlen(pcVar2);
        iVar4 = sVar3 + *(int *)this;
        if (*(int *)(this + 8) < iVar4 + 1) {
          ReAllocate(this,iVar4 + 1,true);
        }
        cVar5 = *pcVar2;
        if (cVar5 != '\0') {
          iVar6 = 0;
          do {
            *(char *)(*(int *)(this + 4) + *(int *)this + iVar6) = cVar5;
            iVar6 = iVar6 + 1;
            cVar5 = pcVar2[iVar6];
          } while (cVar5 != '\0');
        }
        *(int *)this = iVar4;
        *(undefined1 *)(*(int *)(this + 4) + iVar4) = 0;
      }
      pcVar2 = param_1 + iStack_34;
      do {
        cStack_55 = pcVar2[1];
        iVar7 = iVar7 + 1;
        pcVar2 = pcVar2 + 1;
      } while (cStack_55 == 'h');
    }
    else if (cStack_55 == 'm') {
      pcVar2 = (char *)va("%i",local_64);
      if (pcVar2 != (char *)0x0) {
        sVar3 = strlen(pcVar2);
        iVar4 = sVar3 + iStack_30;
        if (iStack_28 < iVar4 + 1) {
          ReAllocate((idStr *)&iStack_30,iVar4 + 1,true);
        }
        cVar5 = *pcVar2;
        if (cVar5 != '\0') {
          iVar6 = 0;
          do {
            pcStack_2c[iVar6 + iStack_30] = cVar5;
            iVar6 = iVar6 + 1;
            cVar5 = pcVar2[iVar6];
          } while (cVar5 != '\0');
        }
        pcStack_2c[iVar4] = '\0';
        iStack_30 = iVar4;
      }
      if (iStack_28 < iStack_30 + 2) {
        ReAllocate((idStr *)&iStack_30,iStack_30 + 2,true);
      }
                    /* try { // try from 00354669 to 0036466d has its CatchHandler @ 00354727 */
                    /* try { // try from 00354671 to 0036469d has its CatchHandler @ 003547a3 */
      pcStack_2c[iStack_30] = 'i';
      iStack_30 = iStack_30 + 1;
      pcStack_2c[iStack_30] = '\0';
      pcVar2 = (char *)va(pcStack_2c,iStack_50);
      if (pcVar2 != (char *)0x0) {
        sVar3 = strlen(pcVar2);
        iVar4 = sVar3 + *(int *)this;
        if (*(int *)(this + 8) < iVar4 + 1) {
          ReAllocate(this,iVar4 + 1,true);
        }
        cVar5 = *pcVar2;
        if (cVar5 != '\0') {
          iVar6 = 0;
          do {
                    /* try { // try from 003546e9 to 003646ed has its CatchHandler @ 00354727 */
                    /* try { // try from 003546f1 to 003646f5 has its CatchHandler @ 003547a3 */
            *(char *)(iVar6 + *(int *)(this + 4) + *(int *)this) = cVar5;
            cVar5 = pcVar2[iVar6 + 1];
            iVar6 = iVar6 + 1;
          } while (cVar5 != '\0');
        }
        *(int *)this = iVar4;
        *(undefined1 *)(*(int *)(this + 4) + iVar4) = 0;
      }
      pcVar2 = param_1 + iStack_34;
                    /* catch() { ... } // from try @ 003546e9 with catch @ 00354727 */
      do {
        cStack_55 = pcVar2[1];
        iVar7 = iVar7 + 1;
        pcVar2 = pcVar2 + 1;
      } while (cStack_55 == 'm');
    }
    else if (cStack_55 == 's') {
      pcVar2 = (char *)va("%i",local_60);
      if (pcVar2 != (char *)0x0) {
        sVar3 = strlen(pcVar2);
        iVar4 = sVar3 + iStack_30;
        if (iStack_28 < iVar4 + 1) {
          ReAllocate((idStr *)&iStack_30,iVar4 + 1,true);
        }
                    /* try { // try from 0035479a to 0036479e has its CatchHandler @ 00354450 */
        cVar5 = *pcVar2;
        if (cVar5 != '\0') {
                    /* catch() { ... } // from try @ 0035449d with catch @ 0035479f */
          iVar6 = 0;
          do {
                    /* try { // try from 003547b4 to 003647b8 has its CatchHandler @ 00354450 */
            pcStack_2c[iStack_30 + iVar6] = cVar5;
                    /* catch() { ... } // from try @ 003547e7 with catch @ 003547c0
                       catch() { ... } // from try @ 00354a11 with catch @ 003547c0
                       catch() { ... } // from try @ 00354ed2 with catch @ 003547c0
                       catch() { ... } // from try @ 00354ee8 with catch @ 003547c0 */
            cVar5 = pcVar2[iVar6 + 1];
            iVar6 = iVar6 + 1;
          } while (cVar5 != '\0');
        }
        pcStack_2c[iVar4] = '\0';
        iStack_30 = iVar4;
      }
                    /* try { // try from 003547e7 to 0036486b has its CatchHandler @ 003547c0 */
      if (iStack_28 < iStack_30 + 2) {
                    /* try { // try from 00354a05 to 00364a09 has its CatchHandler @ 00354ed7 */
                    /* try { // try from 00354a11 to 00364a15 has its CatchHandler @ 003547c0 */
        ReAllocate((idStr *)&iStack_30,iStack_30 + 2,true);
      }
      pcStack_2c[iStack_30] = 'i';
      iStack_30 = iStack_30 + 1;
      pcStack_2c[iStack_30] = '\0';
      pcVar2 = (char *)va(pcStack_2c,iStack_4c);
      if (pcVar2 != (char *)0x0) {
        sVar3 = strlen(pcVar2);
        iVar4 = sVar3 + *(int *)this;
        if (*(int *)(this + 8) < iVar4 + 1) {
          ReAllocate(this,iVar4 + 1,true);
        }
        cVar5 = *pcVar2;
        if (cVar5 != '\0') {
          iVar6 = 0;
          do {
            *(char *)(iVar6 + *(int *)(this + 4) + *(int *)this) = cVar5;
            cVar5 = pcVar2[iVar6 + 1];
            iVar6 = iVar6 + 1;
          } while (cVar5 != '\0');
        }
        *(int *)this = iVar4;
        *(undefined1 *)(*(int *)(this + 4) + iVar4) = 0;
      }
      pcVar2 = param_1 + iStack_34;
      do {
        cStack_55 = pcVar2[1];
        iVar7 = iVar7 + 1;
        pcVar2 = pcVar2 + 1;
      } while (cStack_55 == 's');
    }
    else {
                    /* try { // try from 0035442a to 0036442e has its CatchHandler @ 003540e0 */
      if (cStack_55 == 'M') {
        pcVar2 = (char *)va("%i",local_5c);
        if (pcVar2 != (char *)0x0) {
          sVar3 = strlen(pcVar2);
          iVar4 = sVar3 + iStack_30;
          if (iStack_28 < iVar4 + 1) {
            ReAllocate((idStr *)&iStack_30,iVar4 + 1,true);
            cVar5 = *pcVar2;
            cVar1 = acStack_24[0];
          }
          else {
            cVar5 = *pcVar2;
            cVar1 = acStack_24[0];
          }
          if (cVar5 != '\0') {
            iVar6 = 0;
            do {
              pcStack_2c[iStack_30 + iVar6] = cVar5;
              cVar5 = pcVar2[iVar6 + 1];
              iVar6 = iVar6 + 1;
            } while (cVar5 != '\0');
          }
          pcStack_2c[iVar4] = '\0';
          iStack_30 = iVar4;
          acStack_24[0] = cVar1;
        }
        if (iStack_28 < iStack_30 + 2) {
          ReAllocate((idStr *)&iStack_30,iStack_30 + 2,true);
        }
        pcStack_2c[iStack_30] = 'i';
        iStack_30 = iStack_30 + 1;
        pcStack_2c[iStack_30] = '\0';
        pcVar2 = (char *)va(pcStack_2c,param_2);
        if (pcVar2 != (char *)0x0) {
          sVar3 = strlen(pcVar2);
          iVar4 = sVar3 + *(int *)this;
          if (*(int *)(this + 8) < iVar4 + 1) {
            ReAllocate(this,iVar4 + 1,true);
            cVar5 = *pcVar2;
          }
          else {
            cVar5 = *pcVar2;
          }
          if (cVar5 != '\0') {
            iVar6 = 0;
            do {
              *(char *)(*(int *)(this + 4) + *(int *)this + iVar6) = cVar5;
              iVar6 = iVar6 + 1;
              cVar5 = pcVar2[iVar6];
            } while (cVar5 != '\0');
          }
          *(int *)this = iVar4;
          *(undefined1 *)(*(int *)(this + 4) + iVar4) = 0;
        }
        pcVar2 = param_1 + iStack_34;
        do {
          cStack_55 = pcVar2[1];
          iVar7 = iVar7 + 1;
          pcVar2 = pcVar2 + 1;
        } while (cStack_55 == 'M');
      }
    }
                    /* try { // try from 00354444 to 00364448 has its CatchHandler @ 003540e0 */
    if (*(int *)(this + 8) < *(int *)this + 2) {
                    /* catch() { ... } // from try @ 0035479a with catch @ 00354450
                       catch() { ... } // from try @ 003547b4 with catch @ 00354450 */
      ReAllocate(this,*(int *)this + 2,true);
    }
                    /* catch() { ... } // from try @ 00354379 with catch @ 003543b7 */
    *(char *)(*(int *)(this + 4) + *(int *)this) = cStack_55;
    iVar4 = *(int *)this;
    *(int *)this = iVar4 + 1;
    *(undefined1 *)(*(int *)(this + 4) + iVar4 + 1) = 0;
    iStack_34 = iVar7;
  } while (cStack_55 != '\0');
  FreeData((idStr *)&iStack_30);
                    /* try { // try from 0035475e to 00364762 has its CatchHandler @ 003547a7 */
  return this;
}

