#!/usr/bin/env python3
"""Verification harness: check group reference reconstructions against gamex86.so.

Check 1 -- callee coverage. For every function the coverage record marks `covered`,
disassemble its real byte range (symbol-table start + st_size), list its distinct direct
callees, and assert each one appears in the code of that function's definition in the
group's reference Markdown. Comments do not count, except for constructor/destructor
callees, whose calls are usually implicit. Indirect (virtual / function-pointer) calls
cannot be named from the binary alone and are not checked. Missing callees are reported per function.

    python decomp-so/verify/verify.py              # every group with covered functions
    python decomp-so/verify/verify.py custom-ui    # one (or more) groups
    python decomp-so/verify/verify.py --callees custom-ui   # just list binary callees

Exit status is 0 only when nothing is missing. Callees that are never checked
(_Unwind_Resume, __cxa_*, the PIC thunk) are listed in binary.py; exception-only and
ABI-implicit callees are on allowlist.tsv. Dependencies: requirements.txt.
"""
from __future__ import annotations

import argparse
import fnmatch
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from binary import Binary, Callee, Function, source_name, split_qualified, strip_params  # noqa: E402

VERIFY_DIR = Path(__file__).resolve().parent
DECOMP_DIR = VERIFY_DIR.parent
REPO_ROOT = DECOMP_DIR.parent
BINARY_PATH = REPO_ROOT / "gamex86.so"
REFERENCE_DIR = DECOMP_DIR / "reference"
COVERAGE_PATH = REFERENCE_DIR / "coverage.md"
ALLOWLIST_PATH = VERIFY_DIR / "allowlist.tsv"
GHIDRA_DIR = DECOMP_DIR / "ghidra-full"
GHIDRA_INDEX = GHIDRA_DIR / "_index.tsv"

# Stock class-declaration macros (neo/game/gamesys/Class.h, DOOM-3 GPL a9c49da). When a
# reference writes one of these instead of a body, the macro's stock expansion is the body.
MACRO_BODIES = {
    "CLASS_DECLARATION": {
        "CreateInstance": "idClass *{cls}::CreateInstance( void ) {{ try {{ {cls} *ptr = new {cls}; "
        "ptr->FindUninitializedMemory(); return ptr; }} catch( idAllocError & ) {{ return NULL; }} }}",
        "GetType": "idTypeInfo *{cls}::GetType( void ) const {{ return &( {cls}::Type ); }}",
    },
    "ABSTRACT_DECLARATION": {
        "CreateInstance": "idClass *{cls}::CreateInstance( void ) {{ "
        'gameLocal.Error( "Cannot instanciate abstract class %s.", #{cls} ); return NULL; }}',
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
    callee: str  # fnmatch pattern on the callee's demangled name (params stripped)
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


def allowed(func: Function, callee: Callee, allow: list[AllowEntry]) -> AllowEntry | None:
    for a in allow:
        if fnmatch.fnmatchcase(strip_params(func.name), a.function) and fnmatch.fnmatchcase(
            strip_params(callee.name), a.callee
        ):
            return a
    return None


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


def cpp_blocks(markdown: str) -> list[str]:
    return re.findall(r"^```(?:cpp|c\+\+)\s*\n(.*?)^```", markdown, re.M | re.S)


def implementation_block(markdown: str) -> str:
    blocks = cpp_blocks(markdown)
    if len(blocks) != 2:
        raise ValueError(f"reference must have exactly 2 ```cpp blocks (header, implementation); found {len(blocks)}")
    return blocks[1]


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


def is_structor(callee_name: str) -> bool:
    """Constructors/destructors: their calls are often implicit (base/member), so the
    reconstruction may only be able to name them in a comment."""
    cls, member = split_qualified(callee_name)
    return member in (cls, "~" + cls)


def find_macro_body(impl: str, name: str) -> str | None:
    cls, member = split_qualified(name)
    for macro, bodies in MACRO_BODIES.items():
        if member in bodies and re.search(macro + r"\s*\(\s*\w+\s*,\s*" + re.escape(cls) + r"\s*\)", impl):
            return bodies[member].format(cls=cls)
    return None


# ---------------------------------------------------------------- check 1


@dataclass
class FunctionResult:
    row: CoverageRow
    function: Function | None
    callees: list[Callee] = field(default_factory=list)
    missing: list[Callee] = field(default_factory=list)
    allowed: list[tuple[Callee, AllowEntry]] = field(default_factory=list)
    error: str | None = None

    @property
    def ok(self) -> bool:
        return not self.missing and not self.error


def check_group(
    group: str,
    binary: Binary,
    rows: list[CoverageRow],
    allow: list[AllowEntry],
    reference_text: str | None = None,
) -> list[FunctionResult]:
    covered = [r for r in rows if r.group == group and r.status == "covered"]
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
    return results


def format_results(results: list[FunctionResult]) -> list[str]:
    """Per-function report lines, then a one-line summary."""
    lines = []
    for res in results:
        label = f"{res.row.function} @ {res.row.vaddr:#x}"
        if res.error:
            lines.append(f"  FAIL     {label}: {res.error}")
        elif res.missing:
            lines.extend(f"  MISSING  {label}: {c.name}" for c in res.missing)
        else:
            extra = "".join(f"; allow-listed {c.name} ({a.kind})" for c, a in res.allowed)
            lines.append(f"  ok       {label}: {len(res.callees)} callee(s){extra}")
    n_missing = sum(len(r.missing) for r in results)
    n_err = sum(1 for r in results if r.error)
    lines.append(f"  => {len(results)} functions, {n_missing} missing callee(s), {n_err} error(s)")
    return lines


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("groups", nargs="*", help="group names (default: every group with covered functions)")
    ap.add_argument("--callees", action="store_true", help="list each function's binary callees and exit")
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

    failed = False
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
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
