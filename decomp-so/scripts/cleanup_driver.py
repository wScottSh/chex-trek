#!/usr/bin/env python3
"""Cleanup driver: build the input packet for cleaning up one group's Ghidra pseudo-C.

The packet is the whole brief that Claude Opus 5.5 is given for one group: the spec #16
rules, the output format, and for each function in the group its real byte range, its
direct callees and the float constants / string literals it reads (both read from
gamex86.so by the verification harness) and its complete enriched Ghidra export. The model writes `decomp-so/reference/<group>.md`, then the harness is
re-run until it passes.

    python decomp-so/scripts/cleanup_driver.py custom-ui            # packet to stdout
    python decomp-so/scripts/cleanup_driver.py custom-ui -o p.md    # packet to a file

Pipeline, for reproduction:
    1. NoReturnOff.java (pre-script) + ExportCustom.java -> decomp-so/ghidra-full/  (Ghidra 12.1.4, headless)
    2. cleanup_driver.py <group> -> packet -> Claude Opus 5.5 -> decomp-so/reference/<group>.md
    3. python decomp-so/verify/verify.py <group>   (must exit 0), then mark rows `covered`
       in decomp-so/reference/coverage.md
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "verify"))
import verify  # noqa: E402
from binary import GHIDRA_IMAGE_BASE, Binary  # noqa: E402

RULES = """\
## Rules (spec #16)

- Output is reference material, not a drop-in replacement for the lost source.
- Every uncertain reconstruction gets an `UNCERTAIN` marker with a reason.
- No behavior unsupported by the pseudo-C or the binary. Context sources may name and
  explain code but may not add logic.
- Do not repeat stock header contents. Output only new or changed code.
- Collapse GCC ABI clones into one source function (C1/C2 constructors, D0/D1/D2 destructors).
- Recognize stock SDK idioms and write them idiomatically (idList, idDict::GetString,
  CLASS_DECLARATION / ABSTRACT_DECLARATION, EVENT tables, renderEntity_t, ...).
- State each custom class's base class with evidence.
- Call out Ghidra artifacts (misnamed `this`, missing exception-cleanup paths, x87 compare
  noise, stray `unaff_*` arguments) instead of turning them into behavior.
- Show float constants as real values and strings as the literal text read from the binary.
  Every literal listed below for a function must appear in its definition with the same
  value (check 2), including floats the binary stores as immediates (`0x42000000` = 32.0):
  floats as decimal literals (`32.0f`, `-0.5f`; a `double` without an `f`
  suffix), strings exactly, including stock defaults the call inlines (write
  `spawnArgs.GetFloat( "key", "0" )` when the binary reads "0"). Do not add string literals
  the function does not read. Literals from stock inline code go on
  decomp-so/verify/literal-allowlist.tsv instead.
- Cross-check spawnArg keys and GUI command names against the mod's def/, script/, guis/
  and maps/; record in Notes which keys the data uses and which it never sets.
- Every direct callee listed below must appear in that function's definition (a comment
  counts, e.g. for implicit base-destructor calls). Exception-only and ABI-implicit callees
  are on decomp-so/verify/allowlist.tsv.
- New `idPlayer` members go in decomp-so/reference/idPlayer-additions.md with offsets.
- The 2026 entries in Stnynotes.txt are not a trusted source.

## Context you may use

- Stock DOOM-3 GPL game and idlib source (github.com/id-Software/DOOM-3, a9c49da).
- The other groups' Ghidra exports (decomp-so/ghidra-full/) and finished references.
- The mod's own data in this repo: def/, script/, guis/, maps/ (spawnArg keys, script
  event names, GUI commands).
- The SVN-era changelogs (ChexTrek_ChangeLog.txt, ChexTrek_SDK_ChangeLog.txt) and the
  R6/R7 findings (GitHub issues #7, #8).
- Constants and strings read directly from gamex86.so's data sections.

## Output format: decomp-so/reference/<group>.md

1. A title, then a **Provenance** line naming the model (Claude Opus 5.5) and the Ghidra
   export files used.
2. `## Header`: exactly one ```cpp block with class declarations (member offsets as comments).
3. `## Implementation`: exactly one ```cpp block with every function definition.
4. `## Notes`: open questions, Ghidra artifacts, cross-group links.
"""


def build_packet(group: str) -> str:
    binary = Binary(verify.BINARY_PATH)
    rows = [r for r in verify.load_coverage() if r.group == group]
    if not rows:
        raise SystemExit(f"no functions for group {group!r} in {verify.COVERAGE_PATH.name}")
    out = [f"# Cleanup packet: group `{group}`\n", RULES]
    additions = verify.REFERENCE_DIR / "idPlayer-additions.md"
    if additions.exists():
        out.append("## Current idPlayer additions list\n\n" + additions.read_text(encoding="utf-8"))
    out.append(f"## Functions ({len(rows)})\n")
    for r in rows:
        f = binary.by_raw[r.symbol]
        callees = [c for c in binary.callees(f) if not c.ignored]
        export = (verify.GHIDRA_DIR / r.export).read_text(encoding="utf-8")
        out.append(
            f"### {r.function} ({f.name})\n\n"
            f"- symbol `{r.symbol}`, ELF {f.vaddr:#x}, {f.size} bytes (Ghidra address "
            f"{f.vaddr + GHIDRA_IMAGE_BASE:#x}), export `{r.export}`, status `{r.status}`\n"
            f"- direct callees (binary): "
            + (", ".join(f"`{c.name}`" for c in callees) or "none")
            + "\n- literals (binary): "
            + (", ".join(f"`{lit.render()}`" for lit in binary.literals(f)) or "none")
            + f"\n\n```c\n{export.rstrip()}\n```\n"
        )
    return "\n".join(out)


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("group")
    ap.add_argument("-o", "--out", type=Path, help="write the packet here instead of stdout")
    args = ap.parse_args(argv)
    packet = build_packet(args.group)
    if args.out:
        args.out.write_text(packet, encoding="utf-8")
    else:
        sys.stdout.reconfigure(encoding="utf-8")
        sys.stdout.write(packet)
    return 0


if __name__ == "__main__":
    sys.exit(main())
