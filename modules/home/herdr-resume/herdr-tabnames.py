#!/usr/bin/env python3
"""Name herdr-app tabs after their agent's context (the session name Claude Code or opencode
puts in the terminal title) instead of 1, 2, 3.

A tab is renamed only while its name is empty, a number, or a default an agent menu gave it,
or while it still carries the name this script set last. Rename a tab yourself and it is left
alone from then on.

  herdr-tabnames run     the service: look every 15 s
  herdr-tabnames once    one pass; --dry-run prints what it would rename
"""
import json
import os
import re
import subprocess
import sys
import time

HOME = os.path.expanduser("~")
STATE = os.environ.get("HERDR_TABNAMES_STATE", f"{HOME}/.local/state/herdr-tabnames/names.json")
DEFAULTS = {"claude", "opencode", "codex", "gemini", "terminal"}
GENERIC = {"", "claude code", "opencode", "codex", "gemini", "fish", "bash", "zsh", "sh"}


def run_json(*cmd):
    r = subprocess.run(cmd, capture_output=True, text=True, timeout=20)
    return json.loads(r.stdout) if r.returncode == 0 and r.stdout.strip() else None


def load():
    try:
        with open(STATE) as f:
            return json.load(f)
    except (OSError, ValueError):
        return {}


def save(names):
    os.makedirs(os.path.dirname(STATE), exist_ok=True)
    with open(STATE + ".new", "w") as f:
        json.dump(names, f, indent=1)
    os.replace(STATE + ".new", STATE)


def context_name(address):
    """The agent's own name for this terminal's work, or None while it has none."""
    info = run_json("hc", "get", address, "--json")
    if not info:
        return None
    title = info.get("title") or (info.get("status") or {}).get("title") or ""
    title = re.sub(r"^[^\w]+", "", title).strip()  # a status glyph or spinner before the name
    return None if title.lower() in GENERIC else title[:40]


def once(dry):
    app = run_json("herdr-app", "ls")
    if not app:
        return
    names = load()
    live = set()
    for space in app.get("spaces", []):
        for tab in space.get("tabs", []):
            tid, cur = tab["id"], tab.get("name")
            live.add(tid)
            auto = not cur or cur.isdigit() or cur.lower() in DEFAULTS or cur == names.get(tid)
            if not auto:
                names.pop(tid, None)  # renamed by hand: stop managing it
                continue
            want = next(filter(None, (context_name(t["terminal"]) for t in tab.get("terminals", []))), None)
            if not want or want == cur:
                continue
            print(f"{space['name']}: {cur!r} -> {want!r}")
            if not dry:
                r = subprocess.run(["herdr-app", "do", "tab.rename", "--id", tid, "--name", want],
                                   capture_output=True, text=True, timeout=20)
                if r.returncode == 0:
                    names[tid] = want
    for tid in [t for t in names if t not in live]:
        del names[tid]
    if not dry:
        save(names)


if __name__ == "__main__":
    mode = sys.argv[1] if len(sys.argv) > 1 else "run"
    if mode == "once":
        once("--dry-run" in sys.argv)
    else:
        while True:
            try:
                once(False)
            except Exception as e:  # keep the service alive across a restarting app or core
                print("tabnames:", e, file=sys.stderr)
            time.sleep(15)
