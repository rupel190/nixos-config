#!/usr/bin/env python3
"""Bring Claude conversations back after the herdr core restarts.

The core keeps spaces, tabs and folders across a reboot but gives each lost terminal a plain
shell and never reruns its program. This remembers which Claude session each terminal ran and
types `claude --resume <id>` (or `opencode --session <id>`) into the recovered shell.

  herdr-resume run         the service: snapshot every 30 s, restore once per core start
  herdr-resume snapshot    one snapshot
  herdr-resume restore     one restore; --dry-run prints what it would type
"""
import glob
import json
import os
import sqlite3
import subprocess
import sys
import time

HOME = os.path.expanduser("~")
STATE = os.environ.get("HERDR_RESUME_STATE", f"{HOME}/.local/state/herdr-resume")
SNAP = f"{STATE}/snapshot.json"
DONE = f"{STATE}/restored-for"
SESSIONS = f"{HOME}/.claude/sessions"
OPENCODE_DB = f"{HOME}/.local/share/opencode/opencode.db"
SHELLS = {"fish", "bash", "zsh", "sh", "dash", "nu"}


def hc(*args):
    r = subprocess.run(["hc", *args, "--json"], capture_output=True, text=True, timeout=20)
    return json.loads(r.stdout) if r.returncode == 0 and r.stdout.strip() else None


def load():
    try:
        with open(SNAP) as f:
            return json.load(f)
    except (OSError, ValueError):
        return {"entries": {}}


def save(snap):
    os.makedirs(STATE, exist_ok=True)
    with open(SNAP + ".new", "w") as f:
        json.dump(snap, f, indent=1)
    os.replace(SNAP + ".new", SNAP)


def ppids():
    out = {}
    for d in glob.glob("/proc/[0-9]*"):
        try:
            with open(f"{d}/stat") as f:
                out[int(d[6:])] = int(f.read().rsplit(")", 1)[1].split()[1])
        except (OSError, ValueError, IndexError):
            pass
    return out


def has_transcript(sid):
    return bool(glob.glob(f"{HOME}/.claude/projects/*/{sid}.jsonl"))


def resumed_from(pid):
    """`claude --resume X --fork-session` has no transcript of its own until its first input."""
    try:
        with open(f"/proc/{pid}/cmdline", "rb") as f:
            argv = f.read().decode(errors="replace").split("\0")
    except OSError:
        return None
    return argv[argv.index("--resume") + 1] if "--resume" in argv[:-1] else None


def claude_session(root, parents):
    """(session id, is_fork) of the Claude running under terminal pid `root`, or None."""
    for pid in parents:
        p = pid
        while p and p != root:
            p = parents.get(p)
        if p != root:
            continue
        try:
            with open(f"{SESSIONS}/{pid}.json") as f:
                sid = json.load(f)["sessionId"]
        except (OSError, ValueError, KeyError):
            continue
        if has_transcript(sid):
            return sid, False
        src = resumed_from(pid)
        return (src, True) if src else None
    return None


def under(root, parents, match):
    """First process below terminal pid `root` whose cmdline satisfies `match`."""
    for pid in parents:
        p = pid
        while p and p != root:
            p = parents.get(p)
        if p != root:
            continue
        try:
            with open(f"/proc/{pid}/cmdline", "rb") as f:
                argv = f.read().decode(errors="replace").split("\0")
        except OSError:
            continue
        if match(argv):
            return pid
    return None


def opencode_sessions():
    try:
        db = sqlite3.connect(f"file:{OPENCODE_DB}?mode=ro", uri=True, timeout=1)
        rows = db.execute("select id, title, directory, time_updated from session_v2"
                          " where parent_id is null and time_archived is null").fetchall()
        db.close()
    except sqlite3.Error:
        return []
    return rows


def opencode_session(info, parents, taken):
    """Nothing names a terminal's opencode session: same folder, then the same title, then the newest."""
    if not under(info.get("pid"), parents, lambda a: os.path.basename(a[0]).lstrip(".").startswith("opencode")):
        return None
    title = (info.get("status") or {}).get("title") or info.get("title") or ""
    title = title.removeprefix("OC | ")  # opencode titles its terminal "OC | <session title>"
    born = info.get("created_ms") or 0
    here = [r for r in opencode_sessions() if r[2] == info.get("cwd") and r[0] not in taken
            and (r[1] == title or (r[3] or 0) >= born)]
    here.sort(key=lambda r: (r[1] == title, r[3] or 0), reverse=True)
    return here[0][0] if here else None


def snapshot():
    live = hc("ls")
    if live is None:
        return
    terminals = live.get("terminals", live)
    snap, now, core = load(), time.time(), core_start()
    parents = ppids()
    seen, taken = set(), set()
    for t in terminals:
        if t.get("state") != "live":
            continue
        addr = t["address"]
        seen.add(addr)
        info = hc("get", addr)
        if not info or not info.get("keep"):
            continue
        found = claude_session(info.get("pid"), parents)
        agent = "claude"
        if not found:
            oc = opencode_session(info, parents, taken)
            found, agent = ((oc, False), "opencode") if oc else (None, agent)
        entry = snap["entries"].get(addr)
        if found:
            taken.add(found[0])
            snap["entries"][addr] = {"agent": agent, "session": found[0], "fork": found[1], "cwd": info.get("cwd"),
                                     "core": core, "seen": now, "where": info.get("labels", {}).get("where")}
        elif entry and entry.get("core") == core:
            # Seen running Claude under this same core and now a shell: the person quit it.
            del snap["entries"][addr]
    for addr in [a for a in snap["entries"] if a not in seen]:
        del snap["entries"][addr]
    save(snap)


def core_start():
    """Identity of the running core server: pid and start time, or None."""
    for d in glob.glob("/proc/[0-9]*"):
        try:
            with open(f"{d}/cmdline", "rb") as f:
                argv = f.read().split(b"\0")
            if os.path.basename(argv[0].decode()) == "herdr-core" and argv[1:2] == [b"serve"]:
                with open(f"{d}/stat") as f:
                    return f"{d[6:]}:{f.read().rsplit(')', 1)[1].split()[19]}"
        except (OSError, IndexError, UnicodeDecodeError):
            pass
    return None


def restore(dry):
    snap = load()
    live = hc("ls")
    if live is None:
        return 0
    n, used = 0, set()
    for t in live.get("terminals", live):
        entry = snap["entries"].get(t["address"])
        if not entry or t.get("state") != "live" or t.get("agent") not in SHELLS:
            continue
        if entry.get("core") == core_start():
            continue  # same core: nothing was lost
        # A fork re-forks; a session two tabs share must not run twice, so the second forks too.
        fork = entry.get("fork") or entry["session"] in used
        used.add(entry["session"])
        if entry.get("agent") == "opencode":
            cmd = f"opencode --session {entry['session']}"
        else:
            cmd = f"claude --resume {entry['session']}" + (" --fork-session" if fork else "")
        print(f"{t['address']} ({entry.get('where')}): {cmd}")
        if not dry:
            subprocess.run(["hc", "send", t["address"], cmd], capture_output=True, timeout=30)
            time.sleep(0.5)
        n += 1
    return n


def run():
    last_snap = 0
    while True:
        start = core_start()
        if start and hc("ls") is not None:
            try:
                with open(DONE) as f:
                    done = f.read().strip()
            except OSError:
                done = None
            if done != start:
                time.sleep(10)  # let the core finish giving shells back
                restore(False)
                os.makedirs(STATE, exist_ok=True)
                with open(DONE, "w") as f:
                    f.write(start)
                snapshot()
            elif time.time() - last_snap >= 30:
                snapshot()
                last_snap = time.time()
        time.sleep(10)


if __name__ == "__main__":
    mode = sys.argv[1] if len(sys.argv) > 1 else "run"
    if mode == "snapshot":
        snapshot()
    elif mode == "restore":
        print(restore("--dry-run" in sys.argv), "terminals", file=sys.stderr)
    else:
        run()
