"""Packs files into a deterministic pk4 (a plain zip archive) for tools/package-linux.sh.

Usage: python3 -I make-pk4.py SRC_ROOT OUT_PK4 SOURCE_DATE_EPOCH DOOM3_BASE_DIR [SUPERSEDED...] < file-list

file-list is one path per line, relative to SRC_ROOT, using '/' separators - the same relative path
the engine looks the file up by. Entries are written in sorted order, each stamped with the same
timestamp (SOURCE_DATE_EPOCH, the packaged commit's time) and the same permissions, so packing the
same commit twice gives a byte-identical pk4. Everything is deflated: dhewm3's unzip reads stored
and deflated entries alike, and the many uncompressed .tga textures shrink a lot.

A few files the mod tracks are verbatim copies of id Software's own Doom 3 files, which the package
must not redistribute. Each one byte-identical (same CRC-32 and size) to the version the engine
would otherwise load from DOOM3_BASE_DIR/*.pk4 - the copy in the highest-sorting pak that has it,
since later paks take precedence - is left out: the engine then loads that same content from the
player's own Doom 3 install, so the game can't tell the difference. A copy identical only to a
version a later pak overrides is a mod file pinning old content; dropping it would change what
loads, so that stops the packing with an error instead - unless the path is one of the
SUPERSEDED arguments, each a reviewed case where the base copy that would load instead is known to
be equivalent for the game (tools/package-linux.sh names its own, with the reason).
"""

import glob
import sys
import time
import zipfile
import zlib


def effective_base_entries(base_dir: str) -> tuple[dict, set]:
    """(path -> (crc, size) the engine loads from base, every (path, crc, size) in any base pak)."""
    effective, every = {}, set()
    pk4s = sorted(glob.glob(f"{base_dir}/*.pk4"))
    if not pk4s:
        sys.exit(f"error: no pk4s under {base_dir} - needed to leave id's own files out")
    for pk4_path in pk4s:
        with zipfile.ZipFile(pk4_path) as pk4:
            for info in pk4.infolist():
                key = info.filename.lower()
                effective[key] = (info.CRC, info.file_size)
                every.add((key, info.CRC, info.file_size))
    return effective, every


def main() -> int:
    src_root, out_pk4, epoch, base_dir = sys.argv[1], sys.argv[2], int(sys.argv[3]), sys.argv[4]
    superseded_ok = set(sys.argv[5:])
    effective, every = effective_base_entries(base_dir)
    # Zip timestamps can't predate 1980.
    stamp = time.gmtime(max(epoch, 315532800))[:6]
    names = sorted({line.rstrip("\n") for line in sys.stdin if line.strip()})
    packed = 0
    with zipfile.ZipFile(out_pk4, "w") as pk4:
        for name in names:
            with open(f"{src_root}/{name}", "rb") as src:
                data = src.read()
            ident = (zlib.crc32(data), len(data))
            if effective.get(name.lower()) == ident:
                print(f"left out (identical to Doom 3's own copy): {name}")
                continue
            if (name.lower(), *ident) in every:
                if name in superseded_ok:
                    print(f"left out (an old Doom 3 copy; the reviewed newer base copy loads instead): {name}")
                    continue
                sys.exit(f"error: {name} is identical to a Doom 3 base file a later base pak overrides - "
                         "leaving it out would change what the engine loads")
            info = zipfile.ZipInfo(name, date_time=stamp)
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o644 << 16
            pk4.writestr(info, data, compresslevel=9)
            packed += 1
    print(f"packed {packed} of {len(names)} files into {out_pk4}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
