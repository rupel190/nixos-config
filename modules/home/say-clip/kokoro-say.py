#!/usr/bin/env python3
"""Kokoro TTS as raw s16le PCM on stdout — the piper --output-raw contract.

Import + model load costs ~3.2 s, so the model lives in a lazily-spawned daemon
behind a unix socket and the client stays import-light (~30 ms to first byte).
Daemon exits after SAY_KOKORO_IDLE seconds so its ~1.3 GB is not resident all day.
"""
import argparse
import json
import os
import signal
import socket
import subprocess
import sys
import time

_RUN = os.environ.get("XDG_RUNTIME_DIR", "/tmp")
SOCK = os.path.join(_RUN, "kokoro-say.sock")
PIDF = os.path.join(_RUN, "kokoro-say.pid")
RATE = 24000
IDLE = float(os.environ.get("SAY_KOKORO_IDLE", "600"))


def serve():
    import threading

    import numpy as np
    from kokoro import KPipeline

    pipelines = {}
    last = [time.monotonic()]

    def reaper():
        while True:
            time.sleep(15)
            if time.monotonic() - last[0] > IDLE:
                os._exit(0)

    threading.Thread(target=reaper, daemon=True).start()

    # Bind before warming the model: the client can connect and block on read
    # instead of racing a spawn loop while torch imports.
    if os.path.exists(SOCK):
        os.unlink(SOCK)
    srv = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    srv.bind(SOCK)
    srv.listen(4)
    with open(PIDF, "w") as f:
        f.write(str(os.getpid()))

    def pipeline(lang):
        if lang not in pipelines:
            pipelines[lang] = KPipeline(lang_code=lang)
        return pipelines[lang]

    pipeline(os.environ.get("SAY_KOKORO_LANG", "b"))

    while True:
        conn, _ = srv.accept()
        last[0] = time.monotonic()
        try:
            buf = b""
            while True:
                b = conn.recv(65536)
                if not b:
                    break
                buf += b
            head, _, text = buf.partition(b"\n")
            req = json.loads(head or b"{}")
            text = text.decode("utf-8", "replace")
            if text.strip():
                for _gs, _ps, audio in pipeline(req.get("lang", "b"))(
                    text, voice=req.get("voice", "bf_emma"),
                    speed=float(req.get("speed", 1.0)),
                ):
                    pcm = np.clip(np.asarray(audio, dtype="float32"), -1.0, 1.0)
                    conn.sendall((pcm * 32767).astype("<i2").tobytes())
        except (BrokenPipeError, ConnectionResetError):
            pass
        except Exception as e:  # a bad request must not take the daemon down
            print(f"kokoro-say: {e}", file=sys.stderr)
        finally:
            conn.close()
            last[0] = time.monotonic()


def spawn_daemon():
    subprocess.Popen(
        [sys.executable, os.path.abspath(__file__), "--daemon"],
        start_new_session=True,
        stdin=subprocess.DEVNULL,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


def connect(timeout):
    """Connect, spawning the daemon if nothing is listening yet."""
    deadline = time.monotonic() + timeout
    spawned = False
    while time.monotonic() < deadline:
        s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        try:
            s.connect(SOCK)
            return s
        except (FileNotFoundError, ConnectionRefusedError):
            s.close()
            if not spawned:
                spawn_daemon()
                spawned = True
            time.sleep(0.25)
    return None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--daemon", action="store_true")
    ap.add_argument("--rate", action="store_true", help="print sample rate, exit")
    ap.add_argument("--stop", action="store_true", help="shut the daemon down")
    ap.add_argument("--voice", default=os.environ.get("SAY_KOKORO_VOICE", "bf_emma"))
    ap.add_argument("--lang", default=os.environ.get("SAY_KOKORO_LANG", "b"))
    ap.add_argument("--speed", type=float, default=1.0)
    ap.add_argument("-i", "--input")
    a = ap.parse_args()

    if a.rate:
        print(RATE)
        return 0
    if a.daemon:
        serve()
        return 0
    if a.stop:
        # By recorded pid, never by name — pkill on a shared name is a footgun.
        try:
            with open(PIDF) as f:
                os.kill(int(f.read().strip()), signal.SIGTERM)
        except (OSError, ValueError):
            pass
        for p in (SOCK, PIDF):
            if os.path.exists(p):
                os.unlink(p)
        return 0

    text = open(a.input, encoding="utf-8").read() if a.input else sys.stdin.read()
    if not text.strip():
        return 0

    # First ever run also downloads the model, hence the generous ceiling.
    s = connect(float(os.environ.get("SAY_KOKORO_WAIT", "120")))
    if s is None:
        print("kokoro-say: daemon did not come up", file=sys.stderr)
        return 1

    hdr = json.dumps({"voice": a.voice, "speed": a.speed, "lang": a.lang})
    s.sendall(hdr.encode() + b"\n" + text.encode("utf-8"))
    s.shutdown(socket.SHUT_WR)
    out = sys.stdout.buffer
    total = 0
    while True:
        chunk = s.recv(65536)
        if not chunk:
            break
        total += len(chunk)
        out.write(chunk)
        out.flush()
    s.close()
    # The daemon keeps serving after a bad request, so a clean EOF with no audio
    # is its only way of reporting failure. Never let that pass as success.
    if total == 0:
        print("kokoro-say: daemon returned no audio", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
