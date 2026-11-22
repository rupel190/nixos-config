"""Show a command's output as a Mirador panel, re-running it every few seconds.

usage: mirador-run [--every SECONDS] [--title TITLE] -- COMMAND [ARG...]

Speaks Mirador's external-panel protocol v1 (docs/plugin-protocol.md in its
source): JSON lines on stdin/stdout, `hello` in, `ready` out, then a `frame`
per run. The command prints plain text; ANSI colours become the theme's own
(green = success, red = error, yellow = warning, blue/cyan = accent,
faint = muted), so panels follow whatever theme `t` picks.
"""

import json
import os
import re
import select
import subprocess
import sys
import time

SGR = re.compile(r"\x1b\[([0-9;]*)m")
# cursor moves, OSC titles and charset switches: nothing a panel can draw
OTHER_ESCAPES = re.compile(r"\x1b\[[0-9;?]*[A-Za-z]|\x1b\][^\x07\x1b]*(\x07|\x1b\\)|\x1b[()][A-Za-z0-9]")
THEME = {31: "theme:error", 32: "theme:success", 33: "theme:warning", 34: "theme:accent", 36: "theme:accent"}
MAX_LINES = 500


def send(message):
    sys.stdout.write(json.dumps(message, ensure_ascii=False) + "\n")
    sys.stdout.flush()


def clean(text):
    # Mirador refuses any control character, tabs included
    text = OTHER_ESCAPES.sub("", text).expandtabs(4)
    return "".join(c for c in text if c.isprintable())


def spans(line):
    out, fg, bold, faint, pos = [], None, False, False, 0

    def add(text):
        text = clean(text)
        if text:
            span = {"text": text}
            colour = fg or ("theme:muted" if faint else None)
            if colour:
                span["fg"] = colour
            if bold:
                span["bold"] = True
            out.append(span)

    for match in SGR.finditer(line):
        add(line[pos:match.start()])
        codes = [int(c) if c else 0 for c in match.group(1).split(";")]
        i = 0
        while i < len(codes):
            code = codes[i]
            if code == 0:
                fg, bold, faint = None, False, False
            elif code == 1:
                bold = True
            elif code == 2:
                faint = True
            elif code == 22:
                bold, faint = False, False
            elif code == 39:
                fg = None
            elif code in THEME:
                fg = THEME[code]
            elif 30 <= code <= 37:
                fg = f"ansi:{code - 30}"
            elif 90 <= code <= 97:
                fg = f"ansi:{code - 82}"
            elif code == 38 and i + 2 < len(codes) and codes[i + 1] == 5:
                fg = f"ansi:{codes[i + 2]}"
                i += 2
            i += 1
        pos = match.end()
    add(line[pos:])
    return out


def run(command, timeout):
    try:
        result = subprocess.run(command, capture_output=True, text=True, errors="replace", timeout=timeout)
    except FileNotFoundError:
        return [f"\x1b[31mnot found: {command[0]}\x1b[0m"]
    except subprocess.TimeoutExpired:
        return [f"\x1b[31mno answer within {timeout:g} s: {' '.join(command)}\x1b[0m"]
    lines = result.stdout.splitlines()
    if result.returncode != 0:
        lines.append(f"\x1b[31mexit {result.returncode}\x1b[0m")
        lines += [f"\x1b[2m{line}\x1b[0m" for line in result.stderr.splitlines()[-5:]]
    return lines[:MAX_LINES]


def main():
    args = sys.argv[1:]
    every, title = 30.0, None
    while args and args[0] != "--":
        flag = args.pop(0)
        if flag == "--every":
            every = max(1.0, float(args.pop(0)))
        elif flag == "--title":
            title = args.pop(0)
        else:
            sys.exit(f"mirador-run: unknown option {flag}")
    command = args[1:]
    if not command:
        sys.exit("usage: mirador-run [--every SECONDS] [--title TITLE] -- COMMAND [ARG...]")
    title = title or os.path.basename(command[0])

    buffered = b""

    def messages():
        # one JSON line per message; select() only sees the raw fd, so read it directly
        nonlocal buffered
        chunk = os.read(0, 65536)
        if not chunk:
            raise EOFError
        buffered += chunk
        *complete, buffered = buffered.split(b"\n")
        return [json.loads(line) for line in complete if line.strip()]

    # hello comes first; ready has to follow within five seconds
    while not any(m.get("type") == "hello" for m in messages()):
        pass
    send({"type": "ready", "protocol": 1, "title": title, "refresh_ms": 1000})

    revision, due = 0, 0.0
    try:
        while True:
            if time.monotonic() >= due:
                revision += 1
                lines = run(command, timeout=min(every, 30.0))
                send({
                    "type": "frame",
                    "revision": revision,
                    "counter": time.strftime("%H:%M"),
                    "lines": [{"spans": spans(line)} for line in lines],
                })
                due = time.monotonic() + every
            readable, _, _ = select.select([0], [], [], max(0.0, due - time.monotonic()))
            if readable and any(m.get("type") == "shutdown" for m in messages()):
                return
    except EOFError:
        return


if __name__ == "__main__":
    main()
