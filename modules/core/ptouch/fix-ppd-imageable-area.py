#!/usr/bin/env python3
"""Filter a ptouch-driver PPD on stdin, fixing its zero-area ImageableArea.

Upstream declares *ImageableArea "0 0 0 0" for every tape size while
*PaperDimension is the real size. A zero-area imageable region makes the page
transform singular, so poppler's pdftops dies with /undefinedresult in
currentpoint and Ghostscript silently clips the label to nothing.
"""
import re
import sys

src = sys.stdin.read()

dims = {
    m.group(1): (m.group(3), m.group(4))
    for m in re.finditer(
        r'^\*PaperDimension ([^/:]+)(/[^:]*)?:\s*"([\d.]+) ([\d.]+)"', src, re.M
    )
}


def fix(m):
    name, suffix, value = m.group(1), m.group(2) or "", m.group(3)
    if value.split() == ["0", "0", "0", "0"] and name in dims:
        w, h = dims[name]
        return f'*ImageableArea {name}{suffix}: "0 0 {w} {h}"'
    return m.group(0)


sys.stdout.write(
    re.sub(r'^\*ImageableArea ([^/:]+)(/[^:]*)?:\s*"([^"]*)"', fix, src, flags=re.M)
)
