"""Facts read straight from gamex86.so: function byte ranges, their direct callees, and
the float constants and string literals they reference.

Only the ELF symbol table, section contents and the machine code are used -- never
Ghidra output -- so the verification harness checks reconstructions against the binary itself.
"""
from __future__ import annotations

import math
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
class Literal:
    """A constant a function uses: `float`/`double` read from .rodata by x87 code, a
    `float` stored as an instruction immediate (`mov [x], 0x42000000`), or a `string`
    (.rodata address taken with `lea`, NUL-terminated printable text)."""

    kind: str  # "float" | "double" | "string"
    value: float | str

    def render(self) -> str:
        """`float 0.5`, `double 0.001`, `string "32"` -- shortest text that round-trips."""
        if self.kind == "string":
            return f"string {c_string(self.value)}"
        return f"{self.kind} {shortest_float(self.value, self.kind)}"


@dataclass(frozen=True)
class RodataRef:
    """One PIC-relative read of .rodata; `kind` is `unclassified` when it is neither."""

    at: int  # instruction address
    target: int
    kind: str
    literal: Literal | None


def to_precision(value: float, kind: str) -> float:
    """Round a Python float to the binary's precision (`float` = IEEE single)."""
    if kind == "float":
        return struct.unpack("<f", struct.pack("<f", value))[0]
    return value


def _shortest_digits(value: float, kind: str) -> int:
    for digits in range(1, 18):
        if to_precision(float(f"{value:.{digits}g}"), kind) == value:
            return digits
    return 17


def shortest_float(value: float, kind: str) -> str:
    """Fewest significant digits that read back as `value` at the binary's precision,
    written positionally where Python would (`32.0`, `0.001`, `-100.0`)."""
    return repr(float(f"{value:.{_shortest_digits(value, kind)}g}"))


# An imm32 moved into a 4-byte destination is taken as a float constant when its bits read
# as a float with 1/65536 <= |x| <= 2^24 and at most 6 significant digits (32.0, 73.74).
# Integers in that bit range are 0x37800000 and up (>= ~15 million), and the ones that occur
# -- magic reciprocal multipliers such as 0x4a90be59 for / 3600000 -- need 7+ digits.
FLOAT_IMM_MIN, FLOAT_IMM_MAX, FLOAT_IMM_DIGITS = 2.0**-16, 2.0**24, 6


def float_immediate(imm: int) -> float | None:
    """The float an instruction immediate encodes, or None if it does not look like one."""
    bits = imm & 0xFFFFFFFF
    (value,) = struct.unpack("<f", struct.pack("<I", bits))
    if not math.isfinite(value) or not FLOAT_IMM_MIN <= abs(value) <= FLOAT_IMM_MAX:
        return None
    return value if _shortest_digits(value, "float") <= FLOAT_IMM_DIGITS else None


_C_ESCAPES = {"\\": "\\\\", '"': '\\"', "\n": "\\n", "\t": "\\t", "\r": "\\r"}


def c_string(text: str) -> str:
    return '"' + "".join(_C_ESCAPES.get(ch, ch) for ch in text) + '"'


# x87 instructions whose memory operand is a floating-point value that is read.
_X87_READS = {"fld", "fadd", "fsub", "fsubr", "fmul", "fdiv", "fdivr", "fcom", "fcomp"}
_PRINTABLE = set(range(0x20, 0x7F)) | {0x09, 0x0A, 0x0D}


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

    @cached_property
    def _rodata(self) -> tuple[int, bytes]:
        ro = self.elf.get_section_by_name(".rodata")
        return ro["sh_addr"], ro.data()

    @cached_property
    def _got(self) -> int:
        """_GLOBAL_OFFSET_TABLE_ (start of .got.plt): what the PIC register holds."""
        return self.elf.get_section_by_name(".got.plt")["sh_addr"]

    @cached_property
    def _md_detail(self) -> capstone.Cs:
        md = capstone.Cs(capstone.CS_ARCH_X86, capstone.CS_MODE_32)
        md.detail = True
        return md

    def rodata_refs(self, func: Function) -> list[RodataRef]:
        """Every read of .rodata through the PIC register, in instruction order.

        i386 PIC code sets the GOT address with `call __i686.get_pc_thunk.<reg>` (or
        `call next; pop <reg>`) then `add <reg>, imm`; `.rodata` is then addressed as
        `[<reg> + disp]`. x87 memory operands there are float/double constants; `lea`
        of a NUL-terminated printable run is a string literal -- unless an x87 instruction
        later reads through the lea's register before it is overwritten: then the lea took
        a float's address (kind `pointer`) and the read is the float constant.

        The scan is linear (it does not follow control flow), so once a register is seen
        to receive the GOT address it stays marked for the rest of the function -- epilogue
        `pop`s on early-return paths are followed by more code. A reuse of that register
        for something else cannot fake a literal: small displacements land in the GOT,
        and only PIC addressing reaches .rodata (~0x70000 below it)."""
        from capstone import x86

        ro_addr, ro = self._rodata
        pic: set[int] = set()  # capstone register ids seen to receive the GOT address
        pending: tuple[int | None, int] | None = None  # (register, value it was given)
        lea_regs: dict[int, tuple[int, int]] = {}  # register -> (index in out, .rodata address)
        out: list[RodataRef] = []
        for ins in self._md_detail.disasm(self._bytes(func.vaddr, func.size), func.vaddr):
            if ins.mnemonic == "call":
                for reg in (x86.X86_REG_EAX, x86.X86_REG_ECX, x86.X86_REG_EDX):  # caller-saved
                    lea_regs.pop(reg, None)
                op = ins.operands[0]
                if op.type == x86.X86_OP_IMM:
                    name = self._name_for(op.imm)
                    if name.startswith("__i686.get_pc_thunk."):
                        # the thunk loads the return address into e<suffix> (bx -> ebx)
                        reg = getattr(x86, "X86_REG_E" + name.rsplit(".", 1)[1].upper())
                        pending = (reg, ins.address + ins.size)
                    elif op.imm == ins.address + ins.size:
                        pending = (None, op.imm)  # `call next; pop <reg>`
                continue
            if pending and pending[0] is None and ins.mnemonic == "pop" and ins.operands[0].type == x86.X86_OP_REG:
                pending = (ins.operands[0].reg, pending[1])
                continue
            if (
                pending
                and ins.mnemonic == "add"
                and ins.operands[0].type == x86.X86_OP_REG
                and ins.operands[0].reg == pending[0]
                and ins.operands[1].type == x86.X86_OP_IMM
            ):
                reg, value = pending
                pending = None
                if (value + ins.operands[1].imm) & 0xFFFFFFFF == self._got:
                    pic.add(reg)
                continue
            for op in ins.operands:
                if op.type != x86.X86_OP_MEM or op.mem.index:
                    continue
                if op.mem.base in lea_regs and ins.mnemonic in _X87_READS:
                    # `lea reg, [pic + disp]` then an x87 read through `reg`: the lea took the
                    # address of a float constant, not of a string.
                    i, target = lea_regs[op.mem.base]
                    out[i] = RodataRef(out[i].at, target, "pointer", None)
                    target += op.mem.disp
                    if ro_addr <= target < ro_addr + len(ro):
                        out.append(self._classify(ins.mnemonic, op.size, target, ins.address))
                    continue
                if op.mem.base not in pic:
                    continue
                target = (self._got + op.mem.disp) & 0xFFFFFFFF
                if not ro_addr <= target < ro_addr + len(ro):
                    continue  # GOT slot, .data, .bss: not a literal
                out.append(self._classify(ins.mnemonic, op.size, target, ins.address))
            _, written = ins.regs_access()
            for reg in written:
                lea_regs.pop(reg, None)
            if ins.mnemonic == "lea" and out and out[-1].at == ins.address:
                lea_regs[ins.operands[0].reg] = (len(out) - 1, out[-1].target)
        return out

    def _classify(self, mnemonic: str, size: int, target: int, at: int) -> RodataRef:
        ro_addr, ro = self._rodata
        off = target - ro_addr
        if mnemonic in _X87_READS and size in (4, 8):
            kind = "float" if size == 4 else "double"
            (value,) = struct.unpack_from("<f" if size == 4 else "<d", ro, off)
            return RodataRef(at, target, kind, Literal(kind, value))
        if mnemonic == "lea":
            end = ro.find(b"\0", off)
            text = ro[off:end]
            if end >= 0 and all(c in _PRINTABLE for c in text):
                return RodataRef(at, target, "string", Literal("string", text.decode("ascii")))
        return RodataRef(at, target, "unclassified", None)

    def literals(self, func: Function) -> list[Literal]:
        """Distinct float constants and string literals the function uses, in address order."""
        found = [(ref.at, ref.literal) for ref in self.rodata_refs(func) if ref.literal is not None]
        found += self.immediate_floats(func)
        seen: dict[Literal, None] = {}
        for _, lit in sorted(found, key=lambda x: x[0]):
            seen.setdefault(lit, None)
        return list(seen)

    def immediate_floats(self, func: Function) -> list[tuple[int, Literal]]:
        """(instruction address, float) for each `mov <4-byte dest>, imm32` whose immediate
        looks like a float constant (see float_immediate)."""
        from capstone import x86

        out = []
        for ins in self._md_detail.disasm(self._bytes(func.vaddr, func.size), func.vaddr):
            if ins.mnemonic != "mov" or len(ins.operands) != 2:
                continue
            dest, src = ins.operands
            if src.type != x86.X86_OP_IMM or dest.size != 4:
                continue
            value = float_immediate(src.imm)
            if value is not None:
                out.append((ins.address, Literal("float", value)))
        return out

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
