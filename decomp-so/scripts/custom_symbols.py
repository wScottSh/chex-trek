#!/usr/bin/env python3
"""Check the target set: list gamex86.so's functions that a build of the stock source lacks.

The stock DOOM-3 GPL game and idlib sources (the check-3 container's unmodified checkout, see
decomp-so/verify/compile/Dockerfile) are compiled 32-bit, -O0, one object per file. Every function
symbol gamex86.so defines is then looked up among the defined symbols of those objects. Names the
compilers spell differently are normalized: a static function is `_ZL...` in GCC 12 and `_Z...` in
GCC 3, and constructor / destructor variants (C1 C2, D0 D1 D2) are one name. Left out: the five
custom classes (all their functions are in the export), static-initialization entries
(`_GLOBAL__I_*`), atexit destructors (`__tcf_*`) and the C runtime stubs.

Every remaining function must be a `covered` row of reference/coverage.md or be on NOT_CUSTOM,
with its reason. Exit status 0 only then.

    DOCKER_HOST=ssh://qwen python decomp-so/scripts/custom_symbols.py
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

from elftools.elf.elffile import ELFFile

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "verify"))
import verify  # noqa: E402
from binary import demangle  # noqa: E402

CUSTOM_CLASSES = ("mkTrail", "mkObjective", "matt_func_envshot", "idCustomUI", "idTarget_EndLevelGUI")
CRT = {"_init", "_fini", "call_gmon_start", "frame_dummy", "__do_global_ctors_aux", "__do_global_dtors_aux",
       "__i686.get_pc_thunk.bx", "__i686.get_pc_thunk.cx"}
# Functions not in the GPL source that are not the mod's code either: symbol pattern -> reason.
NOT_CUSTOM = {
    r"_Z\d+CRC16_\w+": "idlib/hashing/CRC16.cpp, checksum code that only calls itself (nothing else in the .so "
                       "calls it); in the mod's first SVN import (ChexTrek_SDK_ChangeLog.txt r1) next to the stock "
                       "CRC32 / MD4 / MD5, not in the GPL release. UNCERTAIN: taken as id's SDK code",
    r"_Z\d+Honeyman_\w+": "idlib/hashing/Honeyman.cpp, as CRC16.cpp",
}

# Runs in the container: compile every stock game and idlib source file, print their defined symbols.
STOCK_BUILD = r"""
cd /doom3/neo
mkdir -p /tmp/o
ls game/*.cpp game/*/*.cpp idlib/*.cpp idlib/*/*.cpp idlib/*/*/*.cpp 2>/dev/null |
  xargs -P "$(nproc)" -I{} sh -c 'g++ -m32 -std=gnu++98 -DGAME_DLL -D_D3SDK -w -O0 -c {} -o "/tmp/o/$(echo {} | tr / _).o" 2>/dev/null || echo "not compiled: {}" >&2'
for f in /tmp/o/*.o; do nm --defined-only -P "$f"; done | awk '$2 ~ /^[TtWwVv]$/ {print $1}' | sort -u
"""


def normalize(symbol: str) -> str:
    return re.sub(r"([CD])[0-2]E", r"\1xE", re.sub(r"^_ZL", "_Z", symbol))


def stock_symbols() -> set[str]:
    tag = verify.ensure_image()
    proc = verify.docker("run", "--rm", "-i", "--network", "none", tag, "sh", stdin=STOCK_BUILD.encode())
    if proc.returncode:
        raise SystemExit("stock build failed: " + proc.stderr.decode(errors="replace")[-800:])
    for line in proc.stderr.decode(errors="replace").splitlines():
        print(f"  ({line})", file=sys.stderr)  # files that are not standalone translation units
    return {normalize(s) for s in proc.stdout.decode().split()}


def binary_functions() -> list[tuple[str, str, int, int]]:
    """(symbol, binding, address, size) of every function gamex86.so defines."""
    with open(verify.BINARY_PATH, "rb") as fh:
        symtab = ELFFile(fh).get_section_by_name(".symtab")
        return [(s.name, s["st_info"]["bind"], s["st_value"], s["st_size"]) for s in symtab.iter_symbols()
                if s["st_info"]["type"] == "STT_FUNC" and s["st_shndx"] != "SHN_UNDEF"]


def main() -> int:
    stock = stock_symbols()
    covered = {r.symbol for r in verify.load_coverage() if r.status == "covered"}
    unexplained = 0
    for name, bind, addr, size in sorted(binary_functions(), key=lambda f: f[2]):
        pretty = demangle(name) if name.startswith("_Z") else name
        if (normalize(name) in stock or name in CRT or name.startswith(("_GLOBAL__I_", "__tcf_"))
                or pretty.startswith(tuple(c + "::" for c in CUSTOM_CLASSES))):
            continue
        reason = next((r for pat, r in NOT_CUSTOM.items() if re.fullmatch(pat, name)), None)
        status = "covered" if name in covered else f"not custom: {reason}" if reason else "UNEXPLAINED"
        unexplained += status == "UNEXPLAINED"
        print(f"{addr:#x}\t{size}\t{bind[4:]}\t{pretty}\t{status}")
    print(f"=> {unexplained} unexplained function(s)")
    return 1 if unexplained else 0


if __name__ == "__main__":
    sys.exit(main())
