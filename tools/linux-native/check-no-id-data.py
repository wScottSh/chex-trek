"""Fails if a packaged pk4 contains any of id Software's own Doom 3 files, byte for byte.

Usage: python3 -I check-no-id-data.py OUR_PK4 DOOM3_BASE_DIR

Compares every entry of OUR_PK4 against every entry of DOOM3_BASE_DIR/*.pk4 by path (lowercased,
as the engine looks files up) and CRC-32 plus size, both read from the zip directories, so nothing
is decompressed. A match means the package would redistribute id's data, which the Chex Trek
AppImage must never do; the mod's own files that merely override a base file by name differ in
content and pass. Exits 0 clean, 1 with the offending paths listed.
"""

import glob
import sys
import zipfile


def entries(pk4_path: str) -> set[tuple[str, int, int]]:
    with zipfile.ZipFile(pk4_path) as pk4:
        return {(i.filename.lower(), i.CRC, i.file_size) for i in pk4.infolist() if not i.is_dir()}


def main() -> int:
    ours_path, base_dir = sys.argv[1], sys.argv[2]
    base_pk4s = sorted(glob.glob(f"{base_dir}/*.pk4"))
    if not base_pk4s:
        print(f"error: no pk4s under {base_dir} to compare against", file=sys.stderr)
        return 1
    ids = set().union(*(entries(p) for p in base_pk4s))
    clashes = sorted(e[0] for e in entries(ours_path) & ids)
    for name in clashes:
        print(f"id Doom 3 file in package: {name}")
    print(f"checked {ours_path} against {len(base_pk4s)} base pk4s: {len(clashes)} id files found")
    return 1 if clashes else 0


if __name__ == "__main__":
    sys.exit(main())
