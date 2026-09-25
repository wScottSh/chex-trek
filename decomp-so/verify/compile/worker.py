"""Check 3 worker: compiles group references against the stock DOOM-3 GPL game source.

Runs inside the check-3 container (Dockerfile next to this file), started by verify.py,
which sends this file's source and the jobs as JSON on stdin and reads JSON from stdout.
It uses only the standard library, and its splicing functions are imported by the tests.

For each job (one group's header block and implementation block):
  1. The stock tree /doom3/neo is copied to a scratch directory.
  2. A top-level `class X ... { ... };` in the header block whose X is defined by a stock
     header is an *addition* to that stock class ("// ... stock members ..."). Its members
     are spliced into the copy of the stock declaration, just before the closing brace.
     This is the only change made to stock files, and every splice is reported.
  3. The rest of the header block, then the implementation block, form one translation
     unit in game/ after the stock game prologue (precompiled.h, Game_local.h). Top-level
     forward declarations (`class idCustomUI;`) in the header block are placed before
     Game_local.h, so spliced members can name the new classes; so is a new class without
     a base class that a spliced member holds by value (`struct playerStats_s`).
     The header blocks of the groups the job depends on ("deps") are prepared the same way
     and come first; their implementation blocks are not compiled here.
  4. It is compiled 32-bit (FLAGS). `#line` directives map every diagnostic in the
     reference code, spliced members included, to the reference Markdown's line numbers.
"""
from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import sys
import tempfile

STOCK_ROOT = "/doom3"
# Where stock class declarations are looked up. d3xp/ (the expansion) and tools/ repeat
# many game/ classes and are not part of the base game build.
STOCK_DIRS = ("idlib", "framework", "cm", "renderer", "sound", "ui", "game")
# The Linux game build's flags from the stock SConstruct / SConscript.game that affect
# what compiles (-m32, GAME_DLL, the SDK configuration _D3SDK), with the language pinned to
# the source's era. No -fpermissive: the stock headers compile without it.
FLAGS = ["-m32", "-std=gnu++98", "-DGAME_DLL", "-D_D3SDK", "-fmessage-length=0",
         "-Wno-unknown-pragmas", "-c", "-o", "/dev/null"]
PROLOGUE = '#include "../idlib/precompiled.h"\n#pragma hdrstop\n\n{forwards}#include "Game_local.h"\n\n'
TU_NAME = "game/_reference.cpp"


# ---------------------------------------------------------------- scanning
# Deliberately a copy of verify.py's brace/comment matching: this file runs alone in the
# container, with only the standard library.


def _skip_comment_or_literal(text: str, i: int) -> int:
    """If text[i] starts a comment or a string/char literal, the index just past it; else i."""
    if text.startswith("//", i):
        j = text.find("\n", i)
        return len(text) if j < 0 else j
    if text.startswith("/*", i):
        j = text.find("*/", i + 2)
        if j < 0:
            raise ValueError("unterminated /* comment")
        return j + 2
    if text[i] in "\"'":
        q, j = text[i], i + 1
        while j < len(text) and text[j] != q:
            j += 2 if text[j] == "\\" else 1
        return j + 1
    return i


def match_brace(text: str, i: int) -> int:
    """Index of the `}` matching the `{` at text[i]."""
    depth = 0
    while i < len(text):
        j = _skip_comment_or_literal(text, i)
        if j != i:
            i = j
            continue
        if text[i] == "{":
            depth += 1
        elif text[i] == "}":
            depth -= 1
            if depth == 0:
                return i
        i += 1
    raise ValueError("unbalanced {}")


_CLASS_HEAD = re.compile(r"\b(?:class|struct)\s+(\w+)\b[^;{()]*\{")
_FORWARD = re.compile(r"\b(?:class|struct)\s+(\w+)\s*;")


def top_level_classes(text: str) -> list[dict]:
    """Class/struct declarations at namespace scope: name, span (`class` .. `;`), and for a
    definition the offsets of the `{` and `}` of the body (a forward declaration has
    "forward": True instead)."""
    out, i, depth = [], 0, 0
    while i < len(text):
        j = _skip_comment_or_literal(text, i)
        if j != i:
            i = j
            continue
        if depth == 0 and (i == 0 or not (text[i - 1].isalnum() or text[i - 1] == "_")):
            m = _FORWARD.match(text, i)
            if m:
                out.append({"name": m.group(1), "start": i, "end": m.end(), "forward": True})
                i = m.end()
                continue
            m = _CLASS_HEAD.match(text, i)
            if m:
                open_ = m.end() - 1
                close = match_brace(text, open_)
                # `};`, or a declarator first: `} g_a;`, `} *p, q;`
                d = re.compile(r"[\s\w*&,]*;").match(text, close + 1)
                if not d or re.search(r"\b(?:class|struct|union|enum|typedef|template)\b", d.group(0)):
                    raise ValueError(f"class {m.group(1)}: no ';' after the closing brace")
                semi = d.end() - 1
                out.append({"name": m.group(1), "start": i, "open": open_, "close": close, "end": semi + 1,
                            "forward": False})
                i = semi + 1
                continue
        if text[i] == "{":
            depth += 1
        elif text[i] == "}":
            depth -= 1
        i += 1
    return out


def line_of(text: str, offset: int) -> int:
    """1-based line number of `offset` in `text`."""
    return text.count("\n", 0, offset) + 1


def blank_out(text: str, start: int, end: int) -> str:
    """`text` with [start, end) replaced by its newlines only, so line numbers are kept."""
    return text[:start] + "\n" * text.count("\n", start, end) + text[end:]


# ---------------------------------------------------------------- splicing


def find_stock_class(neo: str, name: str) -> list[tuple[str, int, int]]:
    """(path relative to neo, offset of `{`, offset of `}`) of each stock definition of `name`."""
    head = re.compile(r"^[ \t]*(?:class|struct)\s+" + re.escape(name) + r"\b[^;{()]*\{", re.M)
    hits = []
    for top in STOCK_DIRS:
        for dirpath, _, files in os.walk(os.path.join(neo, top)):
            for f in sorted(files):
                if not f.endswith(".h"):
                    continue
                path = os.path.join(dirpath, f)
                with open(path, encoding="latin-1") as fh:
                    text = fh.read()
                for m in head.finditer(text):
                    hits.append((os.path.relpath(path, neo).replace(os.sep, "/"), m.end() - 1,
                                 match_brace(text, m.end() - 1)))
    return hits


def splice_members(stock_text: str, stock_close: int, stock_path: str, members: str,
                   members_line: int, source: str) -> str:
    """Insert `members` (a class body from the reference, first line = `members_line` of
    `source`) just before the stock class's closing brace at `stock_close`."""
    line_start = stock_text.rfind("\n", 0, stock_close) + 1
    prefix = stock_text[line_start:stock_close]
    # `#line` must start a line; the closing brace keeps its own line number afterwards.
    insert = f'\n#line {members_line} "{source}"\n{members}\n#line {line_of(stock_text, stock_close)} "{stock_path}"\n'
    if prefix.strip():  # `... };` on one line: cut before the brace
        return stock_text[:stock_close] + insert + stock_text[stock_close:]
    return stock_text[:line_start] + insert.lstrip("\n") + stock_text[line_start:]


def _has_base(header: str, cls: dict) -> bool:
    """Does the class head (`class X : public Y {`) name a base class?"""
    return ":" in header[cls["start"] : cls["open"]]


def prepare_header(neo: str, source: str, header: str, header_line: int) -> tuple[str, str, list[dict]]:
    """Splice one header block's stock-class additions into the tree at `neo`. Returns the
    text that must precede the stock game headers, the rest of the header block (lines kept),
    and the splices."""
    splices = []
    classes = top_level_classes(header)
    stock: set[int] = set()  # indexes (in classes) of additions to a stock class
    for i, cls in enumerate(classes):
        if cls["forward"]:
            continue
        hits = find_stock_class(neo, cls["name"])
        if len(hits) > 1:
            raise ValueError(f"class {cls['name']} is defined in more than one stock header: "
                             + ", ".join(h[0] for h in hits))
        if hits:
            stock.add(i)
    spliced = "\n".join(header[classes[i]["open"] + 1 : classes[i]["close"]] for i in stock)
    # Before the stock game headers go forward declarations, so that spliced members can name a
    # new class, and a new class without a base class that a spliced member holds by value (not
    # through `*` or `&`), which needs it complete (in the mod's source these would sit in the
    # stock header itself). Only this header block's own splices are searched, so a struct that
    # another group's splice holds by value is not hoisted (no group needs that yet).
    hoisted = [i for i, c in enumerate(classes) if c["forward"] or (
        i not in stock and not _has_base(header, c)
        and re.search(r"\b" + re.escape(c["name"]) + r"\b(?!\s*[*&])", spliced))]
    pre_game = "".join(f'#line {header_line + line_of(header, classes[i]["start"]) - 1} "{source}"\n'
                       f'{header[classes[i]["start"]:classes[i]["end"]]}\n' for i in hoisted)
    for i in reversed(range(len(classes))):
        cls = classes[i]
        if i in hoisted:
            header = blank_out(header, cls["start"], cls["end"])
            continue
        if i not in stock:
            continue  # a new class: stays in the translation unit
        # Looked up again: a splice made just before may have moved this class in its file.
        rel, _, close = find_stock_class(neo, cls["name"])[0]
        path = os.path.join(neo, rel)
        with open(path, encoding="latin-1") as fh:
            stock_text = fh.read()
        members = header[cls["open"] + 1 : cls["close"]]
        members_line = header_line + line_of(header, cls["open"]) - 1
        with open(path, "w", encoding="latin-1") as fh:
            fh.write(splice_members(stock_text, close, "../" + rel if not rel.startswith("game/") else rel[5:],
                                    members, members_line, source))
        splices.append({"class": cls["name"], "file": rel, "line": members_line})
        header = blank_out(header, cls["start"], cls["end"])
    return pre_game, header, list(reversed(splices))


def prepare(neo: str, job: dict) -> tuple[str, list[dict]]:
    """Splice stock-class additions into the tree at `neo`; return the TU text and the splices.
    The header blocks of the groups the job depends on ("deps") come first, in order; a splice
    made for one of them carries its source as "from"."""
    pre_game, headers, splices = [], [], []
    for block in job.get("deps", []) + [job]:
        text, rest, made = prepare_header(neo, block["source"], block["header"], block["header_line"])
        pre_game.append(text)
        headers.append(f'#line {block["header_line"]} "{block["source"]}"\n{rest}\n')
        splices += made if block is job else [dict(x, **{"from": block["source"]}) for x in made]
    tu = (PROLOGUE.format(forwards="".join(pre_game)) + "".join(headers)
          + f'#line {job["impl_line"]} "{job["source"]}"\n{job["impl"]}\n')
    return tu, splices


# ---------------------------------------------------------------- running


def toolchain() -> dict:
    gxx = subprocess.run(["g++", "--version"], capture_output=True, text=True).stdout.splitlines()[0]
    rev = subprocess.run(["git", "-C", STOCK_ROOT, "rev-parse", "HEAD"], capture_output=True, text=True).stdout.strip()
    return {"compiler": gxx, "doom3": rev, "flags": FLAGS}


_DIAG = re.compile(r": (?:fatal )?error: ")


def run_job(job: dict) -> dict:
    """Compile one job (verify.compile_job) in a scratch copy of the stock source."""
    scratch = tempfile.mkdtemp()
    try:
        neo = os.path.join(scratch, "neo")
        shutil.copytree(os.path.join(STOCK_ROOT, "neo"), neo)
        try:
            tu, splices = prepare(neo, job)
        except ValueError as exc:
            return {"group": job["group"], "ok": False, "errors": [f"{job['source']}: {exc}"], "splices": []}
        with open(os.path.join(neo, TU_NAME), "w", encoding="utf-8") as fh:
            fh.write(tu)
        proc = subprocess.run(["g++", *FLAGS, os.path.basename(TU_NAME)], cwd=os.path.join(neo, "game"),
                              capture_output=True, text=True, errors="replace",
                              env=dict(os.environ, LC_ALL="C"))  # plain ASCII quotes in messages
        errors = [l for l in proc.stderr.splitlines() if _DIAG.search(l)]
        if proc.returncode and not errors:
            errors = proc.stderr.splitlines()[-20:] or [f"g++ exited {proc.returncode}"]
        return {"group": job["group"], "ok": proc.returncode == 0, "errors": errors, "splices": splices}
    finally:
        shutil.rmtree(scratch, ignore_errors=True)


def run(jobs: list[dict]) -> None:
    json.dump({"toolchain": toolchain(), "results": [run_job(j) for j in jobs]}, sys.stdout)
