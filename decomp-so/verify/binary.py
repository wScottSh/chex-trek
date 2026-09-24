"""Facts read straight from gamex86.so: function byte ranges and their direct callees.

Only the ELF symbol table and the machine code are used -- never Ghidra output --
so the verification harness checks reconstructions against the binary itself.
"""
from __future__ import annotations

import re
import struct
from dataclasses import dataclass
from functools import cached_property
from pathlib import Path

import capstone
import itanium_demangler
from elftools.elf.elffile import ELFFile

# Ghidra loads this .so at image base 0x10000; ELF virtual addresses start at 0.
GHIDRA_IMAGE_BASE = 0x10000

# Callees check 1 never asks about (spec #16, "Testing Decisions").
IGNORED_EXACT = {"_Unwind_Resume"}
IGNORED_PREFIXES = ("__cxa_", "__i686.get_pc_thunk.")


def demangle(name: str) -> str:
    if not name.startswith("_Z"):
        return name
    try:
        return str(itanium_demangler.parse(name))
    except Exception:  # pragma: no cover - unknown mangling: keep raw
        return name


def is_ignored(raw_name: str) -> bool:
    return raw_name in IGNORED_EXACT or raw_name.startswith(IGNORED_PREFIXES)


@dataclass(frozen=True)
class Callee:
    raw: str  # mangled (or plain C) symbol name
    name: str  # demangled

    @property
    def ignored(self) -> bool:
        return is_ignored(self.raw)


@dataclass(frozen=True)
class Function:
    raw: str
    name: str
    vaddr: int  # ELF virtual address (Ghidra address minus GHIDRA_IMAGE_BASE)
    size: int  # st_size from .symtab -- the real byte range


class Binary:
    def __init__(self, path: Path):
        self.path = Path(path)
        self._fh = open(self.path, "rb")
        self.elf = ELFFile(self._fh)
        self.text = self.elf.get_section_by_name(".text")
        self._md = capstone.Cs(capstone.CS_ARCH_X86, capstone.CS_MODE_32)

    @cached_property
    def functions(self) -> dict[int, Function]:
        out: dict[int, Function] = {}
        for sym in self.elf.get_section_by_name(".symtab").iter_symbols():
            if sym["st_info"]["type"] != "STT_FUNC" or not sym["st_value"]:
                continue
            addr = sym["st_value"]
            if addr not in out or (out[addr].size == 0 and sym["st_size"]):
                out[addr] = Function(sym.name, demangle(sym.name), addr, sym["st_size"])
        return out

    @cached_property
    def by_raw(self) -> dict[str, Function]:
        """Every .symtab function symbol, including aliases that share an address."""
        out: dict[str, Function] = {}
        for sym in self.elf.get_section_by_name(".symtab").iter_symbols():
            if sym["st_info"]["type"] == "STT_FUNC" and sym["st_value"]:
                canon = self.functions[sym["st_value"]]
                out[sym.name] = Function(sym.name, demangle(sym.name), canon.vaddr, canon.size)
        return out

    @cached_property
    def plt(self) -> dict[int, str]:
        """PLT stub address -> imported symbol, via each stub's `push reloc_offset`."""
        plt = self.elf.get_section_by_name(".plt")
        relplt = self.elf.get_section_by_name(".rel.plt")
        dynsym = self.elf.get_section_by_name(".dynsym")
        relocs = list(relplt.iter_relocations())
        data = plt.data()
        out = {}
        for off in range(16, len(data), 16):  # entry 0 is the resolver stub
            stub = data[off : off + 16]
            if stub[6] != 0x68:  # push imm32
                continue
            (rel_off,) = struct.unpack_from("<I", stub, 7)
            rel = relocs[rel_off // 8]
            out[plt["sh_addr"] + off] = dynsym.get_symbol(rel["r_info_sym"]).name
        return out

    def find(self, name: str) -> list[Function]:
        """All functions whose demangled name (params stripped) or raw name equals `name`."""
        return [
            f for f in self.functions.values()
            if f.raw == name or strip_params(f.name) == name
        ]

    def callees(self, func: Function) -> list[Callee]:
        """Distinct direct callees (calls, and tail-jumps leaving the function), in first-seen order."""
        code = self._bytes(func.vaddr, func.size)
        end = func.vaddr + func.size
        seen: dict[str, Callee] = {}
        for ins in self._md.disasm(code, func.vaddr):
            if ins.mnemonic not in ("call", "jmp"):
                continue
            try:
                target = int(ins.op_str, 16)
            except ValueError:
                continue  # indirect (virtual / function-pointer) call: not nameable here
            if ins.mnemonic == "jmp" and func.vaddr <= target < end:
                continue  # local branch
            if ins.mnemonic == "call" and target == ins.address + ins.size:
                continue  # `call next; pop %ebx` PIC idiom
            raw = self._name_for(target)
            seen.setdefault(raw, Callee(raw, demangle(raw)))
        return list(seen.values())

    def _name_for(self, target: int) -> str:
        if target in self.plt:
            return self.plt[target]
        f = self.functions.get(target)
        return f.raw if f else f"sub_{target:x}"

    def _bytes(self, vaddr: int, size: int) -> bytes:
        for seg in self.elf.iter_segments():
            if seg["p_type"] == "PT_LOAD" and seg["p_vaddr"] <= vaddr < seg["p_vaddr"] + seg["p_filesz"]:
                self._fh.seek(seg["p_offset"] + vaddr - seg["p_vaddr"])
                return self._fh.read(size)
        raise ValueError(f"address {vaddr:#x} not in a loaded segment")


_OPERATOR_SYMBOL = re.compile(r"\boperator\s*(\(\)|[^\w\s(]+)")


def strip_params(demangled: str) -> str:
    """`idStr::operator=(char const*)` -> `idStr::operator=`; keeps template args."""
    op = _OPERATOR_SYMBOL.search(demangled)
    skip = range(op.start(1), op.end(1)) if op else range(0)
    depth = 0
    for i, ch in enumerate(demangled):
        if i in skip:
            continue  # `<`, `>`, `()` of operator<, operator->, operator() are not brackets
        if ch == "<":
            depth += 1
        elif ch == ">":
            depth -= 1
        elif ch == "(" and depth == 0:
            return demangled[:i].removesuffix(" const")
    return demangled.removesuffix(" const")


_CTOR = re.compile(r"^(.*?)(\w+)((?:<.*>)?)::\{(?:base |complete )?ctor\}$")
_DTOR = re.compile(r"^(.*?)(\w+)((?:<.*>)?)::\{(?:base |complete |deleting )?dtor\}$")


def source_name(demangled: str) -> str:
    """Name as written in C++ source: `idCustomUI::{base ctor}()` -> `idCustomUI::idCustomUI`,
    `idCustomUI::{deleting dtor}()` -> `idCustomUI::~idCustomUI` (GCC ABI clones collapse)."""
    bare = strip_params(demangled)
    m = _CTOR.match(bare)
    if m:
        return f"{m.group(1)}{m.group(2)}{m.group(3)}::{m.group(2)}"
    m = _DTOR.match(bare)
    if m:
        return f"{m.group(1)}{m.group(2)}{m.group(3)}::~{m.group(2)}"
    return bare


_TEMPLATE = re.compile(r"<[^<>]*>")


def split_qualified(name: str) -> tuple[str, str]:
    """`idList<idStr>::Append` -> (`idList`, `Append`) (template args removed)."""
    bare = source_name(name)
    while _TEMPLATE.search(bare):
        bare = _TEMPLATE.sub("", bare)
    if "::" not in bare:
        return "", bare
    cls, _, member = bare.rpartition("::")
    return cls.rpartition("::")[2], member
