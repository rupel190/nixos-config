"""Claude Code statusline: model, context use, and official subscription limits.

Claude Code pipes the session JSON on stdin; rate_limits.{five_hour,seven_day}
carry server-side percentages and are absent until the first API response.
"""
import datetime
import json
import os
import pathlib
import sys
import time

DIM, OFF = "\033[2m", "\033[0m"
GREEN, YELLOW, ORANGE, RED = "\033[32m", "\033[33m", "\033[38;5;208m", "\033[31m"
BAR_WIDTH = 8
EIGHTHS = "\u258f\u258e\u258d\u258c\u258b\u258a\u2589"  # 1/8 .. 7/8 of a cell


def hue(pct):
    return GREEN if pct < 50 else YELLOW if pct < 75 else ORANGE if pct < 90 else RED


def bar(pct):
    """Eighth-block meter: 8 cells addressed at 1/8 each, so low values stay distinct."""
    cells = max(0.0, min(pct, 100.0)) / 100 * BAR_WIDTH
    full = int(cells)
    rem = round((cells - full) * 8)
    if rem == 8:
        full, rem = full + 1, 0
    filled = "\u2588" * min(full, BAR_WIDTH)
    if rem and full < BAR_WIDTH:
        filled += EIGHTHS[rem - 1]
    return f"{hue(pct)}{filled}{OFF}{DIM}{'\u00b7' * (BAR_WIDTH - len(filled))}{OFF}"


def until(epoch):
    secs = int(epoch - time.time())
    if secs <= 0:
        return "now"
    if secs < 3600:
        return f"{secs // 60}m"
    if secs < 86400:
        return f"{secs // 3600}h{secs % 3600 // 60:02d}m"
    return f"{secs // 86400}d{secs % 86400 // 3600}h"


def branch(cwd):
    """Read .git/HEAD directly — no fork, and no dependency on git being on PATH."""
    start = pathlib.Path(cwd)
    for base in [start, *start.parents]:
        dot = base / ".git"
        if dot.is_dir():
            head = dot / "HEAD"
        elif dot.is_file():
            # Linked worktree: ".git" is a file holding "gitdir: <path>".
            pointer = dot.read_text(errors="replace").strip()
            if not pointer.startswith("gitdir:"):
                return None
            head = base / pointer[len("gitdir:"):].strip() / "HEAD"
        else:
            continue
        try:
            ref = head.read_text(errors="replace").strip()
        except OSError:
            return None
        return ref[16:] if ref.startswith("ref: refs/heads/") else ref[:7]
    return None


def save(path, payload):
    try:
        path.parent.mkdir(parents=True, exist_ok=True)
        tmp = path.with_suffix(".tmp")
        tmp.write_text(json.dumps(payload))
        tmp.replace(path)
    except OSError:
        pass


def capture(limits):
    """Mirror claude-monitor's capture file so its views report official, not estimated."""
    path = pathlib.Path.home() / ".claude-monitor" / "statusline" / "latest.json"
    save(path, {"captured_at_epoch": int(time.time()), "rate_limits": limits})


def last_reply(transcript, tail=2**20):
    """Epoch of the main thread's last reply: the prompt cache's hour counts from about there."""
    try:
        with open(transcript, "rb") as f:
            size = f.seek(0, os.SEEK_END)
            f.seek(max(0, size - tail))
            lines = f.read().splitlines()
        for line in reversed(lines):
            if b'"type":"assistant"' not in line:
                continue
            entry = json.loads(line)
            if entry.get("type") != "assistant" or entry.get("isSidechain"):
                continue
            if entry["message"].get("model") != "<synthetic>":
                return int(datetime.datetime.fromisoformat(entry["timestamp"]).timestamp())
    except (OSError, TypeError, ValueError, KeyError):
        return None
    # pictures Claude just read can fill the tail
    return last_reply(transcript, 2**24) if tail < min(size, 2**24) else None


def herdr_card(data, context, replied):
    """HP (cache warmth) and MP (context left) for this terminal's card in herdr-traveler-side.nix."""
    terminal = os.environ.get("HC_TERMINAL_ID", "")
    if not terminal.isalnum():
        return
    path = pathlib.Path.home() / ".config" / "herdr-app" / "data" / "traveler" / "sessions" / f"{terminal}.json"
    save(path, {
        "updatedAt": int(time.time()),
        "repliedAt": replied,
        "contextRemainingPct": None if context is None else round(100 - max(0, min(context, 100))),
        "model": (data.get("model") or {}).get("display_name"),
        "effort": (data.get("effort") or {}).get("level"),
    })


def main():
    try:
        data = json.load(sys.stdin)
    except (json.JSONDecodeError, UnicodeDecodeError):
        return
    if not isinstance(data, dict):
        return

    segments = [f"{DIM}{(data.get('model') or {}).get('display_name', '?')}{OFF}"]

    used = (data.get("context_window") or {}).get("used_percentage")
    if not isinstance(used, (int, float)) or isinstance(used, bool):
        used = None
    if used is not None:
        segments.append(f"{DIM}ctx{OFF} {bar(used)} {hue(used)}{used:.0f}%{OFF}")

    limits = data.get("rate_limits") or {}
    for key, label in (("five_hour", "5h"), ("seven_day", "7d")):
        window = limits.get(key) or {}
        pct, reset = window.get("used_percentage"), window.get("resets_at")
        # Guard upstream bug #52326, where used_percentage can carry the reset epoch.
        if not isinstance(pct, (int, float)) or isinstance(pct, bool) or not 0 <= pct <= 101:
            continue
        seg = f"{DIM}{label}{OFF} {bar(pct)} {hue(pct)}{min(pct, 100):.0f}%{OFF}"
        if isinstance(reset, (int, float)) and not isinstance(reset, bool) and reset > time.time():
            seg += f"{DIM} ↻{until(reset)}{OFF}"
        segments.append(seg)
    replied = last_reply(data.get("transcript_path"))
    if replied is None and used:
        replied = 0  # a fork: the parent's context, no reply of its own yet
    # an idle session keeps redrawing (refreshInterval) with the limits of its last reply
    if limits and time.time() - (replied or 0) < 120:
        capture(limits)
    herdr_card(data, used, replied)

    name = branch(data.get("cwd") or ".")
    if name:
        segments.append(f"{DIM}⎇ {name}{OFF}")

    print(f" {DIM}·{OFF} ".join(segments))


main()
