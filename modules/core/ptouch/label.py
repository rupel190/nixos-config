#!/usr/bin/env python3
"""label - render text and print it on a Brother PT-P710BT over Bluetooth.

Speaks PT-CBP over RFCOMM directly, so a label is exactly as long as its text.
Going through CUPS instead forces every label to the PPD's fixed 100mm page and
drags the job through a PDF/PostScript chain this printer's PPD renders badly.
"""
import argparse
import math
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
    ap.add_argument("--list-fonts", nargs="?", const="", metavar="PATTERN",
                    help="list installed font families, optionally filtered, and exit")
    ap.add_argument("--mac", default=os.environ.get("PTOUCH_MAC", DEFAULT_MAC))
    ap.add_argument("--font", default="DejaVu Sans")
    ap.add_argument("--pad", type=int, default=8,
                    help="blank tape at each end, in pixels (180dpi: 8px is about 1mm)")
    ap.add_argument("--margin", type=int, default=1, metavar="DOTS",
                    help="feed margin in dots (default 1 = 0.14mm; the printer's own "
                         "default is 14 = 2mm). The other ~22mm of leader is mechanical.")
    ap.add_argument("--fontsize", type=int, metavar="PX",
                    help="text height in pixels; defaults to filling the tape (12mm tape = 76px)")
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
    if not args.text:
        ap.error("no text given")

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

    text_px = args.fontsize or tape_px
    if text_px > tape_px:
        die(f"--fontsize {text_px} exceeds the {mm}mm tape's {tape_px}px printable width")
    w, h, rows = render(args.text, font, text_px, args.pad, args.invert)
    mm_long = w / DPI * 25.4
    print(f"{mm}mm tape, {w}x{h}px -> {mm_long:.0f}mm label", file=sys.stderr)

    if args.preview:
        out_dir = os.path.dirname(os.path.abspath(args.preview))
        if sock:
            sock.close()
        if not os.path.isdir(out_dir):
            die(f"no such directory: {out_dir}")
        res = subprocess.run([MAGICK, "pbm:-", args.preview], input=pbm_bytes(w, h, rows), capture_output=True)
        if res.returncode != 0:
            die(f"could not write {args.preview}: {res.stderr.decode(errors='replace').strip()}")
        print(f"wrote {args.preview}", file=sys.stderr)
        return

    if sock is None:
        if not args.mac:
            die("no printer MAC; pass --mac or set PTOUCH_MAC")
        sock = connect(args.mac)
        if sock is None:
            die("printer unreachable - is it switched on? it auto-powers-off when idle.")
        read_status(sock)

    body = raster(w, h, rows, tape_px)
    job = bytearray(PACKBITS + RASTER_MODE)
    if not 0 <= args.margin <= 0xFFFF:
        die("--margin must be 0..65535")
    job += margin_cmd(args.margin) + PACKBITS
    if args.precut:
        job += PRECUT
    for c in range(args.copies):
        last = c == args.copies - 1
        job += body
        job += PRINT_CHAIN if (args.chain or not last) else PRINT_FEED
    sock.sendall(bytes(job))
    wait_done(sock, mm_long)
    sock.close()
    print("sent", file=sys.stderr)


def pbm_bytes(w, h, rows):
    return b"P4\n%d %d\n" % (w, h) + b"".join(rows)


if __name__ == "__main__":
    main()
