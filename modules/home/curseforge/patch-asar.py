#!/usr/bin/env python3
"""Rewrite CurseForge's app.asar with the ad column collapsed.

The main window is a grid whose right column is `--aside-width` (420px) and holds every ad
slot in one `.curseforge-ad` element; subscribers get the same column at width 0. The CSS is
appended to the main window's stylesheet and every other entry (order, unpacked flags,
integrity hashes) is carried over byte for byte: without the append, the output is identical
to the input.

Usage: patch-asar.py SRC_ASAR DST_ASAR. Exits non-zero if the stylesheet has moved.
"""
import hashlib
import json
import struct
import sys

TARGET = ["dist", "desktop", "desktop.css"]
CSS = b"""
/* curseforge-noads: collapse the ad column */
.cf-app{--aside-width:0px!important}
.curseforge-ad,.title-bar .window-actions .swap-ads-location{display:none!important}
"""
BLOCK = 4 * 1024 * 1024


def integrity(data):
    blocks = [data[i:i + BLOCK] for i in range(0, len(data), BLOCK)] or [b""]
    return {
        "algorithm": "SHA256",
        "hash": hashlib.sha256(data).hexdigest(),
        "blockSize": BLOCK,
        "blocks": [hashlib.sha256(b).hexdigest() for b in blocks],
    }


def packed_files(node):
    for ent in node.get("files", {}).values():
        if "files" in ent:
            yield from packed_files(ent)
        elif not ent.get("unpacked") and "link" not in ent:
            yield ent


def main(src, dst):
    with open(src, "rb") as f:
        data = f.read()
    header_size = struct.unpack_from("<I", data, 4)[0]
    json_len = struct.unpack_from("<I", data, 12)[0]
    header = json.loads(data[16:16 + json_len])
    base = 8 + header_size

    target = header
    for part in TARGET:
        target = target.get("files", {}).get(part)
        if target is None:
            sys.exit(f"patch_asar: {'/'.join(TARGET)} not found in {src}")
    if target.get("unpacked"):
        sys.exit(f"patch_asar: {'/'.join(TARGET)} is unpacked, nothing to patch")

    body = []
    pos = 0
    for ent in sorted(packed_files(header), key=lambda e: int(e["offset"])):
        start = base + int(ent["offset"])
        content = data[start:start + ent["size"]]
        if ent is target:
            content += CSS
            ent["size"] = len(content)
            if "integrity" in ent:
                ent["integrity"] = integrity(content)
        ent["offset"] = str(pos)
        body.append(content)
        pos += len(content)

    raw = json.dumps(header, separators=(",", ":"), ensure_ascii=False).encode()
    padded = raw + b"\0" * (-len(raw) % 4)
    pickle = struct.pack("<II", 4 + len(padded), len(raw)) + padded
    with open(dst, "wb") as f:
        f.write(struct.pack("<II", 4, len(pickle)))
        f.write(pickle)
        f.writelines(body)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
