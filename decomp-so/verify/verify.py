#!/usr/bin/env python3
"""Verification harness: check group reference reconstructions against gamex86.so.

Check 1 -- callee coverage. For every function the coverage record marks `covered`,
disassemble its real byte range (symbol-table start + st_size), list its distinct direct
callees, and assert each one appears in the code of that function's definition in the
group's reference Markdown. Comments do not count, except for constructor/destructor
callees, whose calls are usually implicit. Indirect (virtual / function-pointer) calls
cannot be named from the binary alone and are not checked. Missing callees are reported per function.
A stock CLASS_DECLARATION( base, cls ) / ABSTRACT_DECLARATION stands for the GetType and
CreateInstance bodies it expands to; there `new cls` accounts for a call to base's constructor
(cls's own constructor, when it declares none, is inline and starts with base's).

Check 2 -- constants and strings. Every float/double constant and string literal the
function reads from .rodata, and every float stored as an instruction immediate
(`mov [x], 0x42000000` = 32.0; see binary.float_immediate for the rule), must appear, with
the same value, in the code of its definition: floats as a decimal-point literal (`32.0f`,
`-0.5f`, `.05`) equal at the binary's precision (a double constant must not carry an `f`
suffix; `x - 0.5f` is the constant 0.5, `x * -0.5f` is -0.5), strings as the exact text
(adjacent literals are joined). A string literal in the definition that the binary function
never reads is reported as mismatched. Integer-load x87 operands (`fild`) are integers, not
float constants, and are not checked.

Check 3 -- compile. The group's header block and implementation block are compiled, 32-bit,
against an unmodified checkout of the stock DOOM-3 GPL source (id-Software/DOOM-3 at
a9c49da5afb18201d31e3f0a429a037e56ce2b9a) inside a container: Debian bookworm g++ 12 with
-m32 (the toolchain is pinned in compile/Dockerfile; each run prints the exact g++ version
and SDK revision). The only change made to stock files: a header-block class that extends a
stock class (`class idPlayer : public idActor { // ... stock members ... };`) has its members
spliced into a scratch copy of that stock declaration; each such splice is reported. Compile
errors are reported per group, at the reference Markdown's line numbers (compile/worker.py).
Top-level forward declarations in the header block are compiled before the stock game headers,
and so is a new class without a base class that a spliced member holds by value (a stock
class can hold it only if it is complete), so the check does not show where in the stock
headers such a declaration has to go. A reference whose code builds on another group's
header block names that group on a `**Depends on:** `group`` line; the header blocks of
those groups (not their implementations) are compiled first, splices included.
This proves the code is well-formed SDK code, not that it behaves like the binary.
The container runs wherever `docker` points: locally, or on the Ghidra box with
DOCKER_HOST=ssh://qwen. The image is built on first use (tag = hash of the Dockerfile).

    python decomp-so/verify/verify.py              # every group with covered functions
    python decomp-so/verify/verify.py custom-ui    # one (or more) groups
    python decomp-so/verify/verify.py --no-compile # checks 1 and 2 only
    python decomp-so/verify/verify.py --callees custom-ui    # just list binary callees
    python decomp-so/verify/verify.py --literals custom-ui   # just list binary literals

Exit status is 0 only when nothing is missing or mismatched and every group compiles (a
check 3 that cannot run fails, unless --no-compile). Callees that are never checked
(_Unwind_Resume, __cxa_*, the PIC thunk) are listed in binary.py; exception-only,
ABI-implicit and stock-inline callees are on allowlist.tsv, literals that come from stock inline code on
literal-allowlist.tsv. Dependencies: requirements.txt.
"""
from __future__ import annotations

import argparse
import fnmatch
import hashlib
import json
import os
import re
import subprocess
import sys
from dataclasses import dataclass, field
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from binary import (  # noqa: E402
    Binary,
    Callee,
    Function,
    Literal,
    c_string,
    source_name,
    split_qualified,
    strip_params,
    to_precision,
)

VERIFY_DIR = Path(__file__).resolve().parent
DECOMP_DIR = VERIFY_DIR.parent
REPO_ROOT = DECOMP_DIR.parent
BINARY_PATH = REPO_ROOT / "gamex86.so"
REFERENCE_DIR = DECOMP_DIR / "reference"
COVERAGE_PATH = REFERENCE_DIR / "coverage.md"
ALLOWLIST_PATH = VERIFY_DIR / "allowlist.tsv"
LITERAL_ALLOWLIST_PATH = VERIFY_DIR / "literal-allowlist.tsv"
GHIDRA_DIR = DECOMP_DIR / "ghidra-full"
GHIDRA_INDEX = GHIDRA_DIR / "_index.tsv"

# Stock class-declaration macros (neo/game/gamesys/Class.h, DOOM-3 GPL a9c49da). When a
# reference writes one of these instead of a body, the macro's stock expansion is the body.
MACRO_BODIES = {
    "CLASS_DECLARATION": {
        # `new {cls}` runs {cls}'s constructor, which starts with its superclass's. A class that
        # declares no constructor gets an inline one, so the binary calls {base}'s directly.
        "CreateInstance": "idClass *{cls}::CreateInstance( void ) {{ try {{ {cls} *ptr = new {cls}; "
        "/* {cls}::{cls}() runs {base}::{base}() */ "
        "ptr->FindUninitializedMemory(); return ptr; }} catch( idAllocError & ) {{ return NULL; }} }}",
        "GetType": "idTypeInfo *{cls}::GetType( void ) const {{ return &( {cls}::Type ); }}",
    },
    "ABSTRACT_DECLARATION": {
        "CreateInstance": "idClass *{cls}::CreateInstance( void ) {{ "
        'gameLocal.Error( "Cannot instanciate abstract class %s.", "{cls}" ); return NULL; }}',  # #nameofclass
        "GetType": "idTypeInfo *{cls}::GetType( void ) const {{ return &( {cls}::Type ); }}",
    },
}

# Operator callees: how each may appear in source. Ghidra spells `operator new[]` as
# `operator_new__`, so both spellings are accepted (spec #16: `operator new[]` == `operator_new__`).
_OPERATOR_PATTERNS = {
    "new": r"\bnew\b(?![^;]*\[)|\boperator\s*new\b(?!\s*\[)|\boperator_new\b",
    "new[]": r"\bnew\b[^;]*\[|\boperator\s*new\s*\[\s*\]|\boperator_new__",
    "delete": r"\bdelete\b(?!\s*\[)|\boperator\s*delete\b(?!\s*\[)|\boperator_delete\b",
    "delete[]": r"\bdelete\s*\[\s*\]|\boperator\s*delete\s*\[\s*\]|\boperator_delete__",
}


def normalize_operator(member: str) -> str | None:
    """`operator new[]` / `operator_new__` -> `new[]`; `operator=` -> `=`; else None."""
    m = re.fullmatch(r"operator(?!_)\s*(.+)", member) or re.fullmatch(r"operator_(\w+?)(__)?", member)
    if not m:
        return None
    op = m.group(1).strip()
    if len(m.groups()) == 2 and m.group(2):
        op += "[]"
    return re.sub(r"\s+", "", op)


def callee_pattern(callee_name: str) -> re.Pattern:
    """Regex that finds a mention of this callee in reconstruction source text.

    Deliberately loose: the member name only (source writes `gameLocal.Printf`, not
    `idGameLocal::Printf`); a constructor is its class name; other operators match their
    symbol. The check asks "is the call there?", not "is it spelled a certain way?"."""
    _, member = split_qualified(callee_name)
    op = normalize_operator(member)
    if op is not None:
        pat = _OPERATOR_PATTERNS.get(op, r"\boperator\s*" + re.escape(op) + r"|" + re.escape(op))
    elif member.startswith("~"):
        pat = r"~\s*" + re.escape(member[1:]) + r"\b"
    else:
        pat = r"(?<![\w~])" + re.escape(member) + r"\b"
    return re.compile(pat)


@dataclass
class AllowEntry:
    function: str  # fnmatch pattern on the binary function's demangled name
    # fnmatch pattern on what is allowed: in allowlist.tsv the callee's demangled name
    # (params stripped); in literal-allowlist.tsv the literal as rendered (`float 1.5`)
    pattern: str
    kind: str
    reason: str


def load_allowlist(path: Path = ALLOWLIST_PATH) -> list[AllowEntry]:
    out = []
    for line in path.read_text(encoding="utf-8").splitlines():
        if not line.strip() or line.startswith("#"):
            continue
        parts = line.split("\t")
        if len(parts) != 4:
            raise ValueError(f"{path.name}: expected 4 tab-separated fields: {line!r}")
        out.append(AllowEntry(*parts))
    return out


def _allow_entry(func: Function, subject: str, allow: list[AllowEntry]) -> AllowEntry | None:
    for a in allow:
        if fnmatch.fnmatchcase(strip_params(func.name), a.function) and fnmatch.fnmatchcase(subject, a.pattern):
            return a
    return None


def allowed(func: Function, callee: Callee, allow: list[AllowEntry]) -> AllowEntry | None:
    return _allow_entry(func, strip_params(callee.name), allow)


def literal_allowed(func: Function, literal: Literal, allow: list[AllowEntry]) -> AllowEntry | None:
    return _allow_entry(func, literal.render(), allow)


# ---------------------------------------------------------------- coverage record


@dataclass
class CoverageRow:
    function: str
    symbol: str
    vaddr: int
    export: str
    group: str
    status: str


def load_coverage(path: Path = COVERAGE_PATH) -> list[CoverageRow]:
    rows = []
    for line in path.read_text(encoding="utf-8").splitlines():
        cells = [c.strip().strip("`") for c in line.strip().strip("|").split("|")]
        if len(cells) != 6 or not cells[2].startswith("0x"):
            continue
        rows.append(CoverageRow(cells[0], cells[1], int(cells[2], 16), cells[3], cells[4], cells[5]))
    return rows


# ---------------------------------------------------------------- reference parsing


_CPP_BLOCK = re.compile(r"^```(?:cpp|c\+\+)[ \t]*\n(.*?)^```", re.M | re.S)


def cpp_blocks(markdown: str) -> list[str]:
    return [m.group(1) for m in _CPP_BLOCK.finditer(markdown)]


def cpp_block_lines(markdown: str) -> list[int]:
    """1-based Markdown line number of each ```cpp block's first code line."""
    return [markdown.count("\n", 0, m.start(1)) + 1 for m in _CPP_BLOCK.finditer(markdown)]


def reference_blocks(markdown: str) -> tuple[str, str]:
    """(header block, implementation block) of a group reference."""
    blocks = cpp_blocks(markdown)
    if len(blocks) != 2:
        raise ValueError(f"reference must have exactly 2 ```cpp blocks (header, implementation); found {len(blocks)}")
    return blocks[0], blocks[1]


def implementation_block(markdown: str) -> str:
    return reference_blocks(markdown)[1]


def _comment_end(text: str, i: int) -> int:
    end = text.find("*/", i + 2)
    if end < 0:
        raise ValueError("unterminated /* comment")
    return end + 2


def _skip_ws_comments(text: str, i: int) -> int:
    while i < len(text):
        if text[i].isspace():
            i += 1
        elif text.startswith("//", i):
            i = text.find("\n", i)
            i = len(text) if i < 0 else i
        elif text.startswith("/*", i):
            i = _comment_end(text, i)
        else:
            break
    return i


def _match_close(text: str, i: int, open_ch: str, close_ch: str) -> int:
    """Index just past the bracket matching text[i]; skips comments and string/char literals."""
    depth = 0
    while i < len(text):
        if text.startswith("//", i):
            i = text.find("\n", i)
            if i < 0:
                break
            continue
        if text.startswith("/*", i):
            i = _comment_end(text, i)
            continue
        ch = text[i]
        if ch in "\"'":
            j = i + 1
            while j < len(text) and text[j] != ch:
                j += 2 if text[j] == "\\" else 1
            i = j + 1
            continue
        if ch == open_ch:
            depth += 1
        elif ch == close_ch:
            depth -= 1
            if depth == 0:
                return i + 1
        i += 1
    raise ValueError(f"unbalanced {open_ch}{close_ch}")


def find_definition(impl: str, name: str) -> str | None:
    """Text of `name`'s definition (signature, ctor-initializers and body) in `impl`, or None."""
    for m in re.finditer(r"(?<![\w:~])" + re.escape(name) + r"\s*\(", impl):
        close = _match_close(impl, m.end() - 1, "(", ")")
        j = _skip_ws_comments(impl, close)
        if impl.startswith("const", j):
            j = _skip_ws_comments(impl, j + 5)
        if j < len(impl) and impl[j] == ":" and not impl.startswith("::", j):
            j = impl.find("{", j)  # ctor-initializer list
        if j < 0 or j >= len(impl) or impl[j] != "{":
            continue  # a call or declaration, not a definition
        line_start = impl.rfind("\n", 0, m.start()) + 1
        return impl[line_start : _match_close(impl, j, "{", "}")]
    return None


_COMMENT_OR_LITERAL = re.compile(r'//[^\n]*|/\*.*?\*/|"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'', re.S)


def code_only(text: str) -> str:
    """`text` with comments and string/char literals blanked out."""
    return _COMMENT_OR_LITERAL.sub(" ", text)


_SIMPLE_ESCAPES = {"n": "\n", "t": "\t", "r": "\r", "\\": "\\", '"': '"', "'": "'", "?": "?",
                   "a": "\a", "b": "\b", "f": "\f", "v": "\v"}


def c_unescape(body: str) -> str:
    """Value of a C string literal's body (between the quotes)."""
    out, i = [], 0
    while i < len(body):
        ch = body[i]
        if ch != "\\" or i + 1 >= len(body):
            out.append(ch)
            i += 1
            continue
        nxt = body[i + 1]
        if nxt in _SIMPLE_ESCAPES:
            out.append(_SIMPLE_ESCAPES[nxt])
            i += 2
        elif nxt == "x":
            m = re.match(r"[0-9a-fA-F]+", body[i + 2 :])
            out.append(chr(int(m.group(0), 16) & 0xFF) if m else "x")
            i += 2 + (len(m.group(0)) if m else 0)
        elif nxt in "01234567":
            m = re.match(r"[0-7]{1,3}", body[i + 1 :])
            out.append(chr(int(m.group(0), 8)))
            i += 1 + len(m.group(0))
        else:
            out.append(nxt)
            i += 2
    return "".join(out)


def string_literals(text: str) -> list[str]:
    """Values of the string literals in `text`'s code (not comments). Adjacent literals,
    separated only by whitespace or comments, are joined as the compiler joins them."""
    out: list[str] = []
    joinable = False
    pos = 0
    for m in _COMMENT_OR_LITERAL.finditer(text):
        tok = m.group(0)
        gap_blank = not text[pos : m.start()].strip()
        if tok.startswith('"'):
            value = c_unescape(tok[1:-1])
            if joinable and gap_blank:
                out[-1] += value
            else:
                out.append(value)
            joinable = True
        elif tok.startswith("'"):
            joinable = False
        else:  # comment: transparent between adjacent literals
            joinable = joinable and gap_blank
        pos = m.end()
    return out


# A decimal floating literal (a point or an exponent is required), optional suffix, and an
# optional leading minus sign. Integer tokens never count as float constants.
_FLOAT_TOKEN = re.compile(r"(?<![\w.])((?:\d+\.\d*|\.\d+)(?:[eE][+-]?\d+)?|\d+[eE][+-]?\d+)([fFlL]?)(?![\w.])")


def _unary_minus_before(code: str, start: int) -> bool:
    """Is the token at `start` preceded by a unary minus? `-0.5f`, `( -0.5f`, `* -0.5f` are
    unary, and so is one after `return`, `case` or a cast like `(float)`; in `x - 0.5f`,
    `f() - 0.5f`, `a[i]-0.5f` the minus is binary subtraction."""
    i = start - 1
    while i >= 0 and code[i].isspace():
        i -= 1
    if i < 0 or code[i] != "-":
        return False
    before = code[:i].rstrip()
    if not before:
        return True
    if _KEYWORD_OR_CAST_END.search(before):
        return True  # `return -0.5f`, `case -1.0:`, `(float)-3.0`
    return not (before[-1].isalnum() or before[-1] in "_)]")


_KEYWORD_OR_CAST_END = re.compile(
    r"(?<![\w.])(?:return|case|throw|else|do)$"
    r"|\(\s*(?:const\s+)?(?:unsigned\s+|signed\s+)?(?:float|double|int|long|short|char|bool)\s*\)$"
)


def float_literals(code: str) -> list[tuple[float, bool]]:
    """(value, has an `f` suffix) for each float literal in `code` (comments and strings
    already blanked). A literal after a unary minus is negative (`-0.5f` is -0.5); after a
    binary minus it is not (`x - 0.5f` subtracts the constant 0.5)."""
    out = []
    for m in _FLOAT_TOKEN.finditer(code):
        value = float(m.group(1))
        if _unary_minus_before(code, m.start()):
            value = -value
        out.append((value, m.group(2) in ("f", "F")))
    return out


def literal_present(lit: Literal, strings: list[str], floats: list[tuple[float, bool]]) -> bool:
    if lit.kind == "string":
        return lit.value in strings
    for value, f_suffix in floats:
        if lit.kind == "double" and f_suffix:
            continue  # 0.001f is not the double 0.001
        if to_precision(value, lit.kind) == lit.value:
            return True
    return False


def is_structor(callee_name: str) -> bool:
    """Constructors/destructors: their calls are often implicit (base/member), so the
    reconstruction may only be able to name them in a comment."""
    cls, member = split_qualified(callee_name)
    return member in (cls, "~" + cls)


def find_macro_body(impl: str, name: str) -> str | None:
    cls, member = split_qualified(name)
    for macro, bodies in MACRO_BODIES.items():
        m = re.search(macro + r"\s*\(\s*(\w+)\s*,\s*" + re.escape(cls) + r"\s*\)", impl)
        if member in bodies and m:
            return bodies[member].format(cls=cls, base=m.group(1))
    return None


# ---------------------------------------------------------------- check 1


@dataclass
class FunctionResult:
    row: CoverageRow
    function: Function | None
    callees: list[Callee] = field(default_factory=list)
    missing: list[Callee] = field(default_factory=list)
    allowed: list[tuple[Callee, AllowEntry]] = field(default_factory=list)
    # check 2
    literals: list[Literal] = field(default_factory=list)
    missing_literals: list[Literal] = field(default_factory=list)
    mismatched_strings: list[str] = field(default_factory=list)  # in the source, not in the binary
    allowed_literals: list[tuple[Literal, AllowEntry]] = field(default_factory=list)
    error: str | None = None

    @property
    def ok(self) -> bool:
        return not self.missing and not self.missing_literals and not self.mismatched_strings and not self.error


def check_literals(res: FunctionResult, binary: Binary, body: str, literal_allow: list[AllowEntry]) -> None:
    """Check 2 for one function: fills res.literals / missing_literals / mismatched_strings."""
    strings = string_literals(body)
    floats = float_literals(code_only(body))
    res.literals = binary.literals(res.function)
    for lit in res.literals:
        if literal_present(lit, strings, floats):
            continue
        entry = literal_allowed(res.function, lit, literal_allow)
        if entry:
            res.allowed_literals.append((lit, entry))
        else:
            res.missing_literals.append(lit)
    in_binary = {lit.value for lit in res.literals if lit.kind == "string"}
    res.mismatched_strings = list(dict.fromkeys(s for s in strings if s not in in_binary))


def check_group(
    group: str,
    binary: Binary,
    rows: list[CoverageRow],
    allow: list[AllowEntry],
    reference_text: str | None = None,
    literal_allow: list[AllowEntry] | None = None,
) -> list[FunctionResult]:
    """Checks 1 and 2 for every `covered` function of `group`."""
    covered = [r for r in rows if r.group == group and r.status == "covered"]
    if literal_allow is None:
        literal_allow = load_allowlist(LITERAL_ALLOWLIST_PATH)
    if reference_text is None:
        reference_text = (REFERENCE_DIR / f"{group}.md").read_text(encoding="utf-8")
    impl = implementation_block(reference_text)
    results = []
    for row in covered:
        func = binary.by_raw.get(row.symbol)
        res = FunctionResult(row, func)
        results.append(res)
        if func is None:
            res.error = f"symbol {row.symbol} not in .symtab"
            continue
        if func.vaddr != row.vaddr:
            res.error = f"coverage record says {row.vaddr:#x}, symbol table says {func.vaddr:#x}"
            continue
        name = source_name(func.name)
        body = find_definition(impl, name) or find_macro_body(impl, name)
        if body is None:
            res.error = f"no definition of {name} in the implementation block"
            continue
        code = code_only(body)
        for callee in binary.callees(func):
            if callee.ignored:
                continue
            res.callees.append(callee)
            # A mention in a comment only counts for constructors/destructors (implicit calls).
            if callee_pattern(callee.name).search(body if is_structor(callee.name) else code):
                continue
            entry = allowed(func, callee, allow)
            if entry:
                res.allowed.append((callee, entry))
            else:
                res.missing.append(callee)
        check_literals(res, binary, body, literal_allow)
    return results


# ---------------------------------------------------------------- check 3

COMPILE_DIR = VERIFY_DIR / "compile"
DOCKERFILE = COMPILE_DIR / "Dockerfile"
WORKER = COMPILE_DIR / "worker.py"
# Runs in the container: loads worker.py's source from the JSON on stdin and runs the jobs.
_BOOTSTRAP = (
    "import json,sys;d=json.load(sys.stdin);g={'__name__':'worker'};"
    "exec(compile(d['worker'],'worker.py','exec'),g);g['run'](d['jobs'])"
)


class CompileUnavailable(RuntimeError):
    """Check 3 could not run (no docker, image build failed, worker crashed)."""


@dataclass
class CompileResult:
    group: str
    ok: bool
    errors: list[str]
    splices: list[dict]  # {"class", "file", "line"}: stock declarations the header extends


_DEPENDS_ON = re.compile(r"^\*\*Depends on:\*\*(.*)$", re.M)


def header_deps(markdown: str) -> list[str]:
    """Groups named (in backticks) on the reference's `**Depends on:**` line: groups whose
    header blocks this group's code builds on (a base class, a shared idPlayer member)."""
    m = _DEPENDS_ON.search(markdown)
    return re.findall(r"`([\w-]+)`", m.group(1)) if m else []


def _dep_headers(markdown: str, chain: tuple[str, ...], out: list[dict]) -> None:
    for dep in header_deps(markdown):
        if dep in chain:
            raise ValueError(f"circular **Depends on:** {' -> '.join(chain + (dep,))}")
        if any(d["source"] == reference_source(dep) for d in out):
            continue
        path = REFERENCE_DIR / f"{dep}.md"
        if not path.exists():
            raise ValueError(f"**Depends on:** names group {dep!r}, which has no reference file")
        text = path.read_text(encoding="utf-8")
        _dep_headers(text, chain + (dep,), out)  # its own dependencies first
        out.append(_header_part(dep, text))


def reference_source(group: str) -> str:
    return f"decomp-so/reference/{group}.md"


def _header_part(group: str, reference_text: str) -> dict:
    header = reference_blocks(reference_text)[0]
    return {"source": reference_source(group), "header": header, "header_line": cpp_block_lines(reference_text)[0]}


def compile_job(group: str, reference_text: str) -> dict:
    """What worker.py needs to compile one group: its two blocks and where they start, and
    the header blocks of the groups it depends on (compiled first, in dependency order)."""
    impl = reference_blocks(reference_text)[1]
    deps: list[dict] = []
    _dep_headers(reference_text, (group,), deps)
    return {"group": group, **_header_part(group, reference_text), "impl": impl,
            "impl_line": cpp_block_lines(reference_text)[1], "deps": deps}


def dockerfile() -> bytes:
    """The Dockerfile with LF line ends, whatever the checkout's (core.autocrlf)."""
    return DOCKERFILE.read_bytes().replace(b"\r\n", b"\n")


def image_tag() -> str:
    return "chex-decomp-compile:" + hashlib.sha256(dockerfile()).hexdigest()[:12]


DOCKER_TIMEOUT = 1800  # seconds; a first image build downloads the base image and the SDK


def docker(*args: str, stdin: bytes | None = None, timeout: float = DOCKER_TIMEOUT) -> subprocess.CompletedProcess:
    try:
        return subprocess.run(["docker", *args], input=stdin, capture_output=True, timeout=timeout)
    except FileNotFoundError as exc:
        raise CompileUnavailable("docker CLI not found") from exc
    except subprocess.TimeoutExpired as exc:
        raise CompileUnavailable(f"`docker {args[0]}` timed out after {timeout:.0f} s") from exc


def docker_reachable() -> bool:
    try:
        return docker("version", timeout=60).returncode == 0
    except CompileUnavailable:
        return False


def ensure_image() -> str:
    tag = image_tag()
    if docker("image", "inspect", tag).returncode == 0:
        return tag
    proc = docker("build", "-t", tag, "-", stdin=dockerfile())
    if proc.returncode:
        where = os.environ.get("DOCKER_HOST", "the local docker daemon")
        raise CompileUnavailable(f"building {tag} on {where} failed: "
                                 + proc.stderr.decode(errors="replace").strip()[-800:])
    return tag


def run_compile(jobs: list[dict]) -> tuple[dict, list[CompileResult]]:
    """Check 3 for `jobs` (from compile_job) in one container run: (toolchain, results)."""
    tag = ensure_image()
    payload = json.dumps({"worker": WORKER.read_text(encoding="utf-8"), "jobs": jobs}).encode()
    proc = docker("run", "--rm", "-i", "--network", "none", tag, "python3", "-c", _BOOTSTRAP, stdin=payload)
    if proc.returncode:
        raise CompileUnavailable("compile worker failed: " + proc.stderr.decode(errors="replace").strip()[-800:])
    try:
        out = json.loads(proc.stdout)
        return out["toolchain"], [CompileResult(**r) for r in out["results"]]
    except (ValueError, KeyError, TypeError) as exc:
        raise CompileUnavailable(f"unreadable compile worker output: {exc}") from exc


def format_toolchain(tc: dict) -> str:
    return f"check 3 toolchain: {tc['compiler']}, {' '.join(tc['flags'])}; DOOM-3 GPL {tc['doom3']}"


def format_compile(res: CompileResult) -> list[str]:
    splices = "".join(f"; {s['class']} members spliced into stock {s['file']}"
                      + (f" (from {Path(s['from']).name})" if s.get("from") else "") for s in res.splices)
    if res.ok:
        return [f"  ok       compiles (check 3){splices}"]
    return [f"  COMPILE  {e}" for e in res.errors] + [f"  => does not compile: {len(res.errors)} error(s){splices}"]


def format_results(results: list[FunctionResult]) -> list[str]:
    """Per-function report lines, then a one-line summary."""
    lines = []
    for res in results:
        label = f"{res.row.function} @ {res.row.vaddr:#x}"
        if res.error:
            lines.append(f"  FAIL     {label}: {res.error}")
            continue
        lines.extend(f"  MISSING  {label}: {c.name}" for c in res.missing)
        lines.extend(f"  LITERAL  {label}: missing {lit.render()}" for lit in res.missing_literals)
        lines.extend(
            f"  LITERAL  {label}: mismatched {c_string(s)} (the binary function reads no such string)"
            for s in res.mismatched_strings
        )
        if res.ok:
            extra = "".join(f"; allow-listed {c.name} ({a.kind})" for c, a in res.allowed)
            extra += "".join(f"; allow-listed {lit.render()} ({a.kind})" for lit, a in res.allowed_literals)
            lines.append(f"  ok       {label}: {len(res.callees)} callee(s), {len(res.literals)} literal(s){extra}")
    n_missing = sum(len(r.missing) for r in results)
    n_lit = sum(len(r.missing_literals) + len(r.mismatched_strings) for r in results)
    n_err = sum(1 for r in results if r.error)
    lines.append(
        f"  => {len(results)} functions, {n_missing} missing callee(s), "
        f"{n_lit} missing/mismatched literal(s), {n_err} error(s)"
    )
    return lines


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("groups", nargs="*", help="group names (default: every group with covered functions)")
    ap.add_argument("--callees", action="store_true", help="list each function's binary callees and exit")
    ap.add_argument("--literals", action="store_true", help="list each function's binary literals and exit")
    ap.add_argument("--no-compile", action="store_true", help="skip check 3 (compile)")
    args = ap.parse_args(argv)

    binary = Binary(BINARY_PATH)
    rows = load_coverage()
    allow = load_allowlist()
    known = sorted({r.group for r in rows if r.group})
    groups = args.groups or sorted({r.group for r in rows if r.status == "covered"})
    unknown = [g for g in groups if g not in known]
    if unknown:
        print(f"unknown group(s): {', '.join(unknown)}; known: {', '.join(known)}", file=sys.stderr)
        return 2

    if args.callees:
        for g in groups:
            for r in (r for r in rows if r.group == g):
                f = binary.by_raw[r.symbol]
                print(f"{g}\t{source_name(f.name)}\t{f.vaddr:#x}+{f.size}")
                for c in binary.callees(f):
                    print(f"\t{'(ignored) ' if c.ignored else ''}{c.name}")
        return 0
    if args.literals:
        sys.stdout.reconfigure(encoding="utf-8")
        for g in groups:
            for r in (r for r in rows if r.group == g):
                f = binary.by_raw[r.symbol]
                print(f"{g}\t{source_name(f.name)}\t{f.vaddr:#x}+{f.size}")
                for lit in binary.literals(f):
                    print(f"\t{lit.render()}")
        return 0

    failed = False
    compiled: dict[str, CompileResult] = {}
    compile_error: str | None = None
    job_errors: dict[str, str] = {}
    if not args.no_compile:
        jobs = []
        for g in groups:
            ref = REFERENCE_DIR / f"{g}.md"
            try:
                jobs.append(compile_job(g, ref.read_text(encoding="utf-8")))
            except (OSError, ValueError) as exc:
                job_errors[g] = f"check 3 not run: {exc}"  # a missing/malformed file also fails checks 1-2
        try:
            toolchain, results3 = run_compile(jobs) if jobs else ({}, [])
            compiled = {r.group: r for r in results3}
            if toolchain:
                print(format_toolchain(toolchain))
        except CompileUnavailable as exc:
            compile_error = (f"check 3 not run: {exc} (point DOCKER_HOST at a docker host, "
                             "e.g. ssh://qwen, or pass --no-compile)")
    for g in groups:
        ref = REFERENCE_DIR / f"{g}.md"
        print(f"[{g}] {ref.relative_to(REPO_ROOT).as_posix()}")
        if not ref.exists():
            print("  FAIL  reference file missing")
            failed = True
            continue
        try:
            results = check_group(g, binary, rows, allow)
        except ValueError as exc:  # malformed reference
            print(f"  FAIL  {exc}")
            failed = True
            continue
        if not results:
            print("  FAIL  no covered functions in coverage record")
            failed = True
            continue
        for line in format_results(results):
            print(line)
        failed |= any(not r.ok for r in results)
        if args.no_compile:
            continue
        if g in compiled:
            for line in format_compile(compiled[g]):
                print(line)
            failed |= not compiled[g].ok
        else:
            print(f"  FAIL     {job_errors.get(g) or compile_error or 'check 3 produced no result'}")
            failed = True
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
