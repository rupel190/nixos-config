#!/usr/bin/env python3
"""label - render text and print it on a Brother PT-P710BT over Bluetooth.

Speaks PT-CBP over RFCOMM directly, so a label is exactly as long as its text.
Going through CUPS instead forces every label to the PPD's fixed 100mm page and
drags the job through a PDF/PostScript chain this printer's PPD renders badly.
"""
import argparse
import os
import socket
import subprocess
import sys
import time

MAGICK = "magick"
FCMATCH = "fc-match"
FCLIST = "fc-list"
DEFAULT_MAC = ""

CHANNEL = 1
HEAD_PX = 128           # printhead is 128px on the P710BT
DPI = 180

# Printable width in 180dpi pixels, from ptouch-print's tape_info table.
TAPE_PX = {4: 24, 6: 32, 9: 52, 12: 76, 18: 120, 21: 124, 24: 128, 36: 192}

INVALIDATE = b"\x00" * 100
INIT = b"\x1b\x40"
STATUS_REQ = b"\x1b\x69\x53"
PACKBITS = b"M\x02"
RASTER_MODE = b"\x1b\x69\x52\x01"
PRECUT = b"\x1b\x69\x4d\x40"
PRINT_FEED = b"\x1a"


def margin_cmd(dots):
    """ESC i d {n1}{n2} - feed/margin amount, uint16 LE.

    5 bytes only. ptouch-print's D460BT blob appends 4D 00, but that is a
    separate command meaning *disable compression*, which would corrupt a
    PackBits raster - so PackBits is re-asserted after this.

    The P710BT honours this even though ptouch-print only sends it to the
    D460BT family. Measured on 12mm tape: no command and 14 both give a 24mm
    leader, 1 gives 22mm. That 13-dot saving is 13/180in = 1.83mm, so the
    remaining ~22mm is the mechanical head-to-cutter offset and is not
    reachable by any command - use --chain to amortise it over a batch.
    """
    return b"\x1b\x69\x64" + dots.to_bytes(2, "little")
PRINT_CHAIN = b"\x0c"


def list_fonts(pattern):
    """Installed families, deduped. fc-list is the right tool here: fc-match
    always falls back to *something*, so it can never tell you a name is wrong."""
    out = subprocess.run([FCLIST, ":", "family"], capture_output=True, text=True).stdout
    names = {n.strip() for line in out.splitlines() for n in line.split(",") if n.strip()}
    hits = sorted(n for n in names if pattern.lower() in n.lower())
    if not hits:
        die(f"no font family matching {pattern!r}")
    for n in hits:
        print(n)


def length_px(value, what):
    """Accept 6mm or 43px; a bare number means mm."""
    v = str(value).strip().lower()
    try:
        if v.endswith("px"):
            return round(float(v[:-2]))
        return round(float(v[:-2] if v.endswith("mm") else v) / 25.4 * DPI)
    except ValueError:
        die(f"{what}: expected something like 6mm or 43px, got {value!r}")


def die(msg):
    sys.exit(f"label: {msg}")


def connect(mac, attempts=10, backoff=2.0):
    """RFCOMM connect. The printer refuses the first attempts while the baseband
    link comes up - three were needed in practice - so retry.

    Budgeted for an interactive command: ~80s worst case. A printer that is
    simply off should report that quickly rather than retrying for minutes; the
    CUPS backend is the one that waits a long time, since queued jobs can.
    """
    last = None
    for n in range(1, attempts + 1):
        sock = socket.socket(socket.AF_BLUETOOTH, socket.SOCK_STREAM, socket.BTPROTO_RFCOMM)
        sock.settimeout(6)
        try:
            sock.connect((mac, CHANNEL))
            return sock
        except Exception as exc:
            last = exc
            sock.close()
            if n == 1:
                print("waiting for printer...", file=sys.stderr)
            elif n == 4:
                print("still nothing - is it switched on? it auto-powers-off when idle.",
                      file=sys.stderr)
            time.sleep(backoff)
    print(f"label: cannot reach printer at {mac}: {last}", file=sys.stderr)
    return None


def read_status(sock):
    sock.sendall(INVALIDATE + INIT)
    time.sleep(0.2)
    sock.sendall(STATUS_REQ)
    sock.settimeout(10)
    buf = b""
    while len(buf) < 32:
        try:
            chunk = sock.recv(32 - len(buf))
        except socket.timeout:
            break
        if not chunk:
            break
        buf += chunk
    if len(buf) < 32 or buf[0] != 0x80:
        die("no status from printer (got %d bytes)" % len(buf))
    if buf[8] or buf[9]:
        die(f"printer reports error flags {buf[8]:#04x}/{buf[9]:#04x} (tape jam? cover open?)")
    return buf[10]


def wait_done(sock, mm_long):
    """Hold the socket open long enough for the printer to consume the job.

    Two things had to be ruled out: closing a fixed 1s after sendall() truncated
    back-to-back jobs, but the P710BT also never sends an unsolicited
    "printing done" frame, so waiting for one just blocks until timeout. The
    printer runs at ~20mm/s, so bound the wait by the label's own length and
    exit early if a status frame does turn up.
    """
    deadline = time.time() + mm_long / 20.0 + 4.0
    sock.settimeout(1.0)
    while time.time() < deadline:
        try:
            d = sock.recv(32)
        except socket.timeout:
            continue
        except Exception:
            return
        if not d:
            return
        if len(d) >= 20 and d[0] == 0x80:
            if d[8] or d[9]:
                print(f"label: printer error flags {d[8]:#04x}/{d[9]:#04x}", file=sys.stderr)
                return
            if d[18] == 0x01:  # printing completed; any other type is just a phase change
                return


def render(lines, font, text_px, pad, invert):
    """Text -> 1-bit PBM, height == text_px, width == however long.

    Rendered large and scaled down so the glyphs stay crisp. text_px defaults to
    the tape's full printable width; smaller values leave a margin, since
    raster() centres whatever it is given in the 128px head.
    """
    text = "\n".join(lines)
    cmd = [
        MAGICK, "-background", "white", "-fill", "black",
        "-font", font, "-pointsize", "200", f"label:{text}",
        "-trim", "+repage",
        "-resize", f"x{text_px}",
    ]
    if pad:
        cmd += ["-bordercolor", "white", "-border", f"{pad}x0"]
    if invert:
        cmd += ["-negate"]
    cmd += ["-colorspace", "Gray", "-threshold", "60%", "-depth", "1", "pbm:-"]
    out = subprocess.run(cmd, capture_output=True).stdout
    if not out.startswith(b"P4"):
        die("ImageMagick produced no bitmap (bad font or empty text?)")
    return parse_pbm(out)


def _image_pbm(path, text_px, pad, invert, flatten):
    cmd = [MAGICK, path]
    if flatten:
        cmd += ["-background", "white", "-alpha", "remove", "-alpha", "off"]
    else:
        cmd += ["-alpha", "off"]
    cmd += ["-resize", f"x{text_px}"]
    if pad:
        cmd += ["-bordercolor", "white", "-border", f"{pad}x0"]
    if invert:
        cmd += ["-negate"]
    cmd += ["-colorspace", "Gray", "-threshold", "60%", "-depth", "1", "pbm:-"]
    out = subprocess.run(cmd, capture_output=True).stdout
    return out if out.startswith(b"P4") else b""


def render_image(path, text_px, pad, invert):
    """Any image file -> 1-bit PBM at the tape's printable height.

    Alpha has to be flattened onto white or a transparent icon thresholds to a
    solid black block. But ImageMagick's alpha metadata lies: a plain bilevel
    PNG can report a blend alpha it does not really have, and flattening it
    yields a blank image. %[opaque] and mean.a both fail to tell the two apart,
    so decide on the result instead - flatten, and fall back to ignoring alpha
    if that produced no ink at all.
    """
    if not os.path.exists(path):
        die(f"no such image: {path}")
    for flatten in (True, False):
        data = _image_pbm(path, text_px, pad, invert, flatten)
        if not data:
            continue
        w, h, rows = parse_pbm(data)
        if any(any(r) for r in rows):
            return w, h, rows
    die(f"{path} rendered with no ink - is it blank, or all transparent?")


def parse_batch(path):
    """One label per blank-line-separated block; its lines are the label's lines.

    A block that is just "@image <file>" prints that file instead of text.
    """
    try:
        text = sys.stdin.read() if path == "-" else open(path).read()
    except OSError as exc:
        die(f"--batch: {exc}")
    blocks, cur = [], []
    for line in text.splitlines():
        if line.strip():
            cur.append(line.rstrip())
        elif cur:
            blocks.append(cur)
            cur = []
    if cur:
        blocks.append(cur)
    if not blocks:
        die(f"--batch: {path} has no labels")
    return [
        ("image", b[0][7:].strip()) if len(b) == 1 and b[0].startswith("@image ") else ("text", b)
        for b in blocks
    ]


def parse_pbm(data):
    """Minimal binary PBM (P4) reader -> (width, height, rows of bytes)."""
    fields, pos = [], 2
    while len(fields) < 2:
        while pos < len(data) and data[pos : pos + 1].isspace():
            pos += 1
        if data[pos : pos + 1] == b"#":
            while data[pos : pos + 1] not in (b"\n", b""):
                pos += 1
            continue
        start = pos
        while pos < len(data) and not data[pos : pos + 1].isspace():
            pos += 1
        fields.append(int(data[start:pos]))
    pos += 1
    w, h = fields
    stride = (w + 7) // 8
    body = data[pos : pos + stride * h]
    return w, h, [body[r * stride : (r + 1) * stride] for r in range(h)]


def raster(w, h, rows, tape_px):
    """Emit one PT-CBP raster packet per image column.

    The head is 128px; a narrower tape is centred in it. Bit order follows
    ptouch-print: rasterline[15 - px/8] |= 1 << (px%8), and rows are read
    bottom-up so the label reads correctly as the tape feeds out.
    """
    if h > tape_px:
        die(f"rendered {h}px tall but tape only prints {tape_px}px")
    offset = HEAD_PX // 2 - h // 2
    stride = (w + 7) // 8
    out = bytearray()
    for col in range(w):
        line = bytearray(HEAD_PX // 8)
        byte_i, mask = col // 8, 0x80 >> (col % 8)
        for i in range(h):
            if rows[h - 1 - i][byte_i] & mask:
                px = offset + i
                line[len(line) - 1 - (px // 8)] |= 1 << (px % 8)
        n = len(line)
        out += b"\x47" + bytes([n + 1, 0, n - 1]) + bytes(line)
    return bytes(out)


def main():
    ap = argparse.ArgumentParser(prog="label", description="Print a text label on the PT-P710BT over Bluetooth.")
    ap.add_argument("text", nargs="*", help="label text; each argument is a line")
    ap.add_argument("--image", metavar="FILE",
                    help="print an image instead of text, scaled to the tape height")
    ap.add_argument("--batch", metavar="FILE",
                    help="print several labels as one chained strip; blank-line-separated "
                         "blocks in FILE (or - for stdin), one block per label")
    ap.add_argument("--list-fonts", nargs="?", const="", metavar="PATTERN",
                    help="list installed font families, optionally filtered, and exit")
    ap.add_argument("--mac", default=os.environ.get("PTOUCH_MAC", DEFAULT_MAC))
    ap.add_argument("--font", default="DejaVu Sans")
    ap.add_argument("--pad", default="1mm", metavar="SIZE",
                    help="blank tape at each end, as 1mm or 8px (default 1mm)")
    ap.add_argument("--margin", type=int, default=1, metavar="DOTS",
                    help="feed margin in dots (default 1 = 0.14mm; the printer's own "
                         "default is 14 = 2mm). The other ~22mm of leader is mechanical.")
    ap.add_argument("--fontsize", metavar="SIZE",
                    help="text height as 6mm or 43px; defaults to filling the tape "
                         "(12mm tape prints 10.7mm, the head is the limit, not the tape)")
    ap.add_argument("--copies", type=int, default=1)
    ap.add_argument("--invert", action="store_true", help="white text on black")
    ap.add_argument("--chain", action="store_true", help="skip feed+cut so labels can be chained")
    ap.add_argument("--precut", action="store_true", help="cut before printing (minimal waste when chaining)")
    ap.add_argument("--tape", type=int, help="tape width in mm; skips the printer probe")
    ap.add_argument("--preview", metavar="PNG", help="write a preview image instead of printing")
    args = ap.parse_args()

    if args.list_fonts is not None:
        list_fonts(args.list_fonts)
        return
    if not args.text and not args.image and not args.batch:
        ap.error("give some text, or --image FILE, or --batch FILE")

    font = args.font
    if not os.path.exists(font):
        got = subprocess.run([FCMATCH, "-f", "%{file}", font], capture_output=True, text=True).stdout.strip()
        fam = subprocess.run([FCMATCH, "-f", "%{family}", font], capture_output=True, text=True).stdout.strip()
        if not got:
            die(f"no font matching {args.font!r}")
        # fc-match always answers, falling back silently, so check we got what was asked for
        if args.font.lower() not in fam.lower():
            print(f"label: no font matching {args.font!r}, falling back to {fam!r}", file=sys.stderr)
        font = got

    sock = None
    if args.tape:
        mm = args.tape
    else:
        if not args.mac:
            die("no printer MAC; pass --mac or set PTOUCH_MAC")
        sock = connect(args.mac)
        if sock is None:
            if not args.preview:
                die("printer unreachable - is it switched on? it auto-powers-off when idle.")
            mm = 12
            print("label: printer unreachable, previewing as 12mm (--tape overrides)", file=sys.stderr)
        else:
            mm = read_status(sock)
            if mm == 0:
                die("no tape cassette detected")
    tape_px = TAPE_PX.get(mm)
    if tape_px is None:
        die(f"unknown tape width {mm}mm")

    pad_px = length_px(args.pad, "--pad")
    if args.fontsize:
        text_px = length_px(args.fontsize, "--fontsize")
        if text_px < 1:
            die(f"--fontsize {args.fontsize} rounds to nothing at {DPI}dpi")
    else:
        text_px = tape_px
    if text_px > tape_px:
        die(f"--fontsize {args.fontsize} exceeds what {mm}mm tape can print "
            f"({tape_px / DPI * 25.4:.1f}mm / {tape_px}px)")
    if args.batch:
        items = parse_batch(args.batch)
    elif args.image:
        items = [("image", args.image)]
    else:
        items = [("text", args.text)]

    labels = [
        render_image(v, text_px, pad_px, args.invert) if kind == "image"
        else render(v, font, text_px, pad_px, args.invert)
        for kind, v in items
    ]
    mm_long = sum(w for w, _, _ in labels) / DPI * 25.4
    if len(labels) == 1:
        w, h, _ = labels[0]
        print(f"{mm}mm tape, {w}x{h}px -> {mm_long:.0f}mm label", file=sys.stderr)
    else:
        for i, (w, h, _) in enumerate(labels, 1):
            print(f"  {i}. {w}x{h}px -> {w / DPI * 25.4:.0f}mm", file=sys.stderr)
        print(f"{mm}mm tape, {len(labels)} labels -> {mm_long:.0f}mm strip", file=sys.stderr)

    if args.preview:
        out_dir = os.path.dirname(os.path.abspath(args.preview))
        if sock:
            sock.close()
        if not os.path.isdir(out_dir):
            die(f"no such directory: {out_dir}")
        stem, ext = os.path.splitext(args.preview)
        for i, (w, h, rows) in enumerate(labels, 1):
            out = args.preview if len(labels) == 1 else f"{stem}-{i}{ext}"
            res = subprocess.run([MAGICK, "pbm:-", out], input=pbm_bytes(w, h, rows), capture_output=True)
            if res.returncode != 0:
                die(f"could not write {out}: {res.stderr.decode(errors='replace').strip()}")
            print(f"wrote {out}", file=sys.stderr)
        return

    if sock is None:
        if not args.mac:
            die("no printer MAC; pass --mac or set PTOUCH_MAC")
        sock = connect(args.mac)
        if sock is None:
            die("printer unreachable - is it switched on? it auto-powers-off when idle.")
        read_status(sock)

    bodies = [raster(w, h, rows, tape_px) for w, h, rows in labels]
    job = bytearray(PACKBITS + RASTER_MODE)
    if not 0 <= args.margin <= 0xFFFF:
        die("--margin must be 0..65535")
    job += margin_cmd(args.margin) + PACKBITS
    sequence = bodies * args.copies
    for i, body in enumerate(sequence):
        if args.precut:
            job += PRECUT
        job += body
        last = i == len(sequence) - 1
        job += PRINT_CHAIN if (args.chain or not last) else PRINT_FEED
    sock.sendall(bytes(job))
    wait_done(sock, mm_long)
    sock.close()
    print("sent", file=sys.stderr)


def pbm_bytes(w, h, rows):
    return b"P4\n%d %d\n" % (w, h) + b"".join(rows)


if __name__ == "__main__":
    main()
