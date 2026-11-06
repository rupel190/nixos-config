#!/usr/bin/env python3
"""The Building's slow facts, as one JSON object on stdout. Read-only, except its cache.

Live terminals come from herdr-core. Claude Code sessions are found through
~/.claude/sessions/<pid>.json, by walking up from the session's process to its terminal.
Model, effort, last input and the dead all come from the transcripts, which are scanned once
and then only from where the last scan stopped. Opencode keeps the same facts in its own database.
"""
import datetime
import glob
import json
import os
import sqlite3
import subprocess
import sys
import time

HOME = os.path.expanduser("~")
PROJECTS = f"{HOME}/.claude/projects"
SESSIONS = f"{HOME}/.claude/sessions"
CACHE = f"{HOME}/.cache/herdr-building/state.json"
OPENCODE_DB = f"{os.environ.get('XDG_DATA_HOME') or HOME + '/.local/share'}/opencode/opencode.db"
OPENCODE_TITLE = "OC | "
LOCAL_PROVIDERS = {"ollama", "lmstudio", "llama.cpp"}
EFFORTS = {"low", "medium", "high", "xhigh", "max"}
WEEK_MS = 7 * 24 * 3600 * 1000
MAX_DEAD = 400
NOT_INPUT = ("<local-command", "<task-notification", "<system-reminder", "Caveat:")


def ms(stamp):
    try:
        return int(datetime.datetime.fromisoformat(stamp.replace("Z", "+00:00")).timestamp() * 1000)
    except (AttributeError, ValueError):
        return None


def first_line(text):
    for line in text.splitlines():
        line = line.strip(" \t`*#>-")
        if line:
            return line[:160]
    return None


def read_record(rec, o):
    kind = o.get("type")
    if kind in ("custom-title", "ai-title"):
        title = o.get("customTitle") or o.get("aiTitle")
        if title and (kind == "custom-title" or not rec.get("custom")):
            rec["title"] = title
            rec["custom"] = kind == "custom-title"
        return
    if kind not in ("user", "assistant") or o.get("isSidechain"):
        return
    at = ms(o.get("timestamp"))
    if at:
        rec["born_ms"] = rec.get("born_ms") or at
        rec["last_ms"] = at
    rec["cwd"] = o.get("cwd") or rec.get("cwd")
    content = (o.get("message") or {}).get("content")
    if kind == "user":
        if o.get("isMeta") or o.get("isCompactSummary"):
            return
        text = content if isinstance(content, str) else None
        if isinstance(content, list):
            parts = [c.get("text", "") for c in content if isinstance(c, dict) and c.get("type") == "text"]
            text = "\n".join(parts) if parts else None
        if not text or text.startswith(NOT_INPUT):
            return
        if text.startswith("[Request interrupted"):
            rec["ended"] = "interrupted"
            return
        rec["turns"] = rec.get("turns", 0) + 1
        rec["fed_ms"] = at or rec.get("fed_ms")
        rec["ended"] = "waiting"
        return
    model = (o.get("message") or {}).get("model")
    if model and not model.startswith("<"):
        rec["model"] = model
    if o.get("perTurnEffort") or o.get("effort"):
        rec["effort"] = o.get("perTurnEffort") or o.get("effort")
    rec["ended"] = "working" if (o.get("message") or {}).get("stop_reason") == "tool_use" else "answered"
    if isinstance(content, list):
        for c in content:
            if isinstance(c, dict) and c.get("type") == "text" and c.get("text"):
                rec["words"] = first_line(c["text"]) or rec.get("words")


def scan(path, rec):
    size = os.path.getsize(path)
    offset = rec.get("offset", 0)
    if size < offset:
        rec.clear()
        offset = 0
    if size == offset:
        return
    with open(path, "rb") as f:
        f.seek(offset)
        for raw in f:
            if not raw.endswith(b"\n"):
                break
            offset += len(raw)
            if b'"assistant"' in raw or b'"user"' in raw or b'-title"' in raw:
                try:
                    read_record(rec, json.loads(raw))
                except (ValueError, TypeError):
                    pass
    rec["offset"] = offset


def opencode_sessions():
    """Top-level opencode sessions as transcript-shaped records. Empty if the store has moved."""
    try:
        db = sqlite3.connect(f"file:{OPENCODE_DB}?mode=ro", uri=True, timeout=1)
    except sqlite3.Error:
        return {}
    out = {}
    try:
        inputs = {r[0]: r[1:] for r in db.execute(
            "select session_id, count(*), max(time_created) from session_message where type = 'user' group by session_id")}
        for sid, title, folder, model, born, last, outcome in db.execute(
                "select id, title, directory, model, time_created, time_updated, idle_outcome from session_v2"
                " where parent_id is null and time_archived is null"):
            model = json.loads(model) if model else {}
            turns, fed = inputs.get(sid, (0, None))
            rec = {"title": title, "cwd": folder, "model": model.get("id"), "provider": model.get("providerID"), "turns": turns,
                   "fed_ms": fed, "born_ms": born, "last_ms": last, "ended": "interrupted" if outcome and outcome != "succeeded" else "answered"}
            if model.get("variant") in EFFORTS:
                rec["effort"] = model["variant"]
            said = db.execute("select data from session_message where session_id = ? and type = 'assistant' order by seq desc limit 1", (sid,)).fetchone()
            for c in (json.loads(said[0]).get("content") or []) if said else []:
                if isinstance(c, dict) and c.get("type") == "text" and c.get("text"):
                    rec["words"] = first_line(c["text"]) or rec.get("words")
            out[sid] = rec
    except (sqlite3.Error, ValueError, TypeError):
        return {}
    finally:
        db.close()
    return out


def opencode_match(t, title, sessions, taken):
    """Nothing names a terminal's session: same folder, then the same title, then the newest."""
    wanted = (t.get("status") or {}).get("title") or title
    fresh = lambda r: r["title"] == wanted or (r["last_ms"] or 0) >= (t.get("created_ms") or 0)
    here = [(sid, r) for sid, r in sessions.items() if r["cwd"] == t.get("cwd") and sid not in taken and fresh(r)]
    here.sort(key=lambda kv: (kv[1]["title"] == wanted, kv[1]["last_ms"] or 0), reverse=True)
    return here[0][0] if here else None


def hc(*args):
    out = subprocess.run(["hc", *args, "--json"], capture_output=True, text=True, timeout=10).stdout
    return json.loads(out) if out.strip() else None


def parent_of(pid):
    try:
        with open(f"/proc/{pid}/stat") as f:
            return int(f.read().rsplit(")", 1)[1].split()[1])
    except (OSError, IndexError, ValueError):
        return 0


def billing(pid):
    """Where a Claude process runs. Reads two variable names, and never a key's value."""
    try:
        with open(f"/proc/{pid}/environ", "rb") as f:
            env = dict(v.split(b"=", 1) for v in f.read().split(b"\0") if b"=" in v)
    except OSError:
        return None
    url = env.get(b"ANTHROPIC_BASE_URL", b"")
    if b"localhost" in url or b"127.0.0.1" in url:
        return "local"
    if url and b"anthropic.com" not in url:
        return "api"
    return "api" if env.get(b"ANTHROPIC_API_KEY") else "subscription"


def resumed_from(pid):
    """A `claude --resume X --fork-session` has no transcript of its own until its first input."""
    try:
        with open(f"/proc/{pid}/cmdline", "rb") as f:
            argv = f.read().decode(errors="replace").split("\0")
    except OSError:
        return None
    return argv[argv.index("--resume") + 1] if "--resume" in argv[:-1] else None


def live_sessions(by_pid):
    """Terminal address -> (session id, process id), newest session first."""
    out = {}
    files = []
    for path in glob.glob(f"{SESSIONS}/*.json"):
        try:
            with open(path) as f:
                files.append(json.load(f))
        except (OSError, ValueError):
            pass
    for s in sorted(files, key=lambda s: s.get("startedAt", 0), reverse=True):
        pid = s.get("pid")
        if not pid or not os.path.exists(f"/proc/{pid}"):
            continue
        walk, hops = pid, 0
        while walk > 1 and walk not in by_pid and hops < 12:
            walk, hops = parent_of(walk), hops + 1
        if walk in by_pid and by_pid[walk] not in out:
            out[by_pid[walk]] = (s.get("sessionId"), pid)
    return out


def cause(rec, now):
    if (rec.get("title") or "").upper().startswith("RIP-"):
        return "Retired"
    if rec.get("ended") == "interrupted":
        return "Cut off mid-sentence"
    if rec.get("ended") == "working":
        return "Died on the job"
    if now - (rec.get("last_ms") or now) >= WEEK_MS:
        return "Starvation"
    return "Laid off"


def stone(sid, rec, now):
    return {
        "id": sid,
        "title": rec.get("title"),
        "project": os.path.basename(rec.get("cwd") or "") or "?",
        "model": rec.get("model"),
        "effort": rec.get("effort"),
        "turns": rec.get("turns", 0),
        "born_ms": rec.get("born_ms"),
        "last_ms": rec.get("last_ms"),
        "cause": cause(rec, now),
        "words": rec.get("words"),
    }


def main():
    now = int(time.time() * 1000)
    try:
        with open(CACHE) as f:
            state = json.load(f)
    except (OSError, ValueError):
        state = {}
    records = state.setdefault("records", {})
    tabs = state.setdefault("tabs", {})

    paths = {os.path.splitext(os.path.basename(p))[0]: p for p in glob.glob(f"{PROJECTS}/*/*.jsonl")}
    for sid, path in paths.items():
        try:
            scan(path, records.setdefault(sid, {}))
        except OSError:
            pass

    listed = hc("ls") or []
    listed = listed if isinstance(listed, list) else listed.get("terminals", [])
    full = {}
    for t in listed:
        record = hc("get", t["address"])
        if record:
            full[t["address"]] = {**t, **record}
    by_pid = {t["pid"]: a for a, t in full.items() if t.get("pid")}
    sessions = live_sessions(by_pid)
    opencode, taken = opencode_sessions(), set()

    terminals, live_ids, live_titles = {}, set(), set()
    for address, t in full.items():
        labels = t.get("labels") or {}
        status = t.get("status") or {}
        title = (t.get("title") or "").removeprefix(OPENCODE_TITLE)
        sid, pid = sessions.get(address, (None, None))
        source = resumed_from(pid) if pid else None
        rec = records.get(sid) or records.get(source) or {}
        if status.get("app") == "opencode" or t.get("agent") == "opencode":
            sid = opencode_match(t, title, opencode, taken)
            rec = opencode.get(sid, {})
            taken.add(sid)
        tab = labels.get("herdr.tab")
        fed = rec.get("fed_ms")
        if not rec:
            # No transcript: a word that changed after turn 0 is real, a restart's is not.
            if t.get("turn") and t.get("status_ms"):
                tabs[tab] = max(tabs.get(tab, 0), t["status_ms"])
            elif tab and tab not in tabs:
                tabs[tab] = now
            fed = tabs.get(tab)
        where = "local" if rec.get("provider") in LOCAL_PROVIDERS else "api" if rec.get("provider") else billing(pid) if pid else None
        if sid:
            live_ids.update(filter(None, (sid, source)))
            live_titles.add(title)
        terminals[address] = {
            "title": title,
            "tab": tab,
            "parent": t.get("parent"),
            "status": status.get("state"),
            "report": status.get("msg"),
            "app": status.get("app"),
            "session": sid,
            "model": labels.get("building.model") or rec.get("model"),
            "effort": labels.get("building.effort") or rec.get("effort"),
            "where": labels.get("building.where") or where,
            "fed_ms": fed,
            "turns": rec.get("turns", t.get("turn", 0)),
            "born_ms": rec.get("born_ms") or t.get("created_ms"),
            "retired": title.upper().startswith("RIP-"),
        }

    dead, seen = [], set(live_titles)
    ordered = sorted([*records.items(), *opencode.items()], key=lambda kv: kv[1].get("last_ms") or 0, reverse=True)
    for sid, rec in ordered:
        if (sid not in paths and sid not in opencode) or not rec.get("turns"):
            continue
        rip = (rec.get("title") or "").upper().startswith("RIP-")
        if sid in live_ids and not rip:
            continue
        # A resumed context leaves older sessions under the same name: one stone per name.
        title = rec.get("title")
        if title and title in seen and not rip:
            continue
        if title:
            seen.add(title)
        dead.append(stone(sid, rec, now))
        if len(dead) >= MAX_DEAD:
            break

    os.makedirs(os.path.dirname(CACHE), exist_ok=True)
    tmp = f"{CACHE}.{os.getpid()}"
    with open(tmp, "w") as f:
        json.dump(state, f)
    os.replace(tmp, CACHE)
    json.dump({"now": now, "terminals": terminals, "dead": dead}, sys.stdout, separators=(",", ":"))


if __name__ == "__main__":
    main()
