#!/usr/bin/env python3
"""CUPS backend: stream a print job to a Bluetooth RFCOMM (SPP) printer.

Device URI: bluetooth://<MAC-with-hyphens>/<rfcomm-channel>
e.g.        bluetooth://98-6E-E8-47-89-65/1
"""
import os
import socket
import subprocess
import sys
import time

CUPS_OK, CUPS_FAILED, CUPS_RETRY = 0, 1, 6

# Absolute path substituted by Nix; plain name works when run by hand.
BLUETOOTHCTL = "bluetoothctl"

CONNECT_ATTEMPTS = 15
CONNECT_BACKOFF = 3.0
CONNECT_TIMEOUT = 25.0


def log(level, msg):
    print(f"{level}: {msg}", file=sys.stderr, flush=True)


def discover():
    """List paired P-touch/Brother devices for `lpinfo -v`."""
    try:
        out = subprocess.run(
            [BLUETOOTHCTL, "devices", "Paired"],
            capture_output=True, text=True, timeout=10,
        ).stdout
    except Exception:
        return CUPS_OK
    for line in out.splitlines():
        parts = line.split(maxsplit=2)
        if len(parts) < 3 or parts[0] != "Device":
            continue
        mac, name = parts[1], parts[2]
        if not (name.startswith("PT-") or "Brother" in name):
            continue
        uri = f"bluetooth://{mac.replace(':', '-')}/1"
        print(f'direct {uri} "Brother {name}" "{name} (Bluetooth)" ""')
    return CUPS_OK


def parse_uri(uri):
    rest = uri[len("bluetooth://"):]
    host, _, chan = rest.partition("/")
    return host.replace("-", ":").upper(), int(chan or 1)


def connect(mac, channel):
    """RFCOMM connect. The printer often refuses the first attempts while the
    baseband link comes up, so retry rather than failing the job."""
    last = None
    for attempt in range(1, CONNECT_ATTEMPTS + 1):
        sock = socket.socket(socket.AF_BLUETOOTH, socket.SOCK_STREAM, socket.BTPROTO_RFCOMM)
        sock.settimeout(CONNECT_TIMEOUT)
        try:
            sock.connect((mac, channel))
            log("INFO", f"connected to {mac} channel {channel} (attempt {attempt})")
            return sock
        except Exception as exc:
            last = exc
            sock.close()
            # INFO, not DEBUG: cupsd's default LogLevel drops DEBUG, which made a
            # sleeping printer look like a silently hung job.
            log("INFO", f"waiting for printer (attempt {attempt}/{CONNECT_ATTEMPTS}): {exc}")
            time.sleep(CONNECT_BACKOFF)
    log("ERROR", f"cannot reach printer at {mac}: {last}")
    return None


def drain(sock, payload_len):
    """Hold the socket open while the printer consumes the job.

    The P710BT never sends an unsolicited "printing done" frame, so waiting for
    one burned the full timeout on every job (~74s for a short label). Each
    raster line is 20 bytes on the wire and the printer runs at ~20mm/s, so
    bound the wait by the job's own size instead.
    """
    est_mm = (payload_len / 20.0) / 180.0 * 25.4
    sock.settimeout(1.0)
    deadline = time.time() + est_mm / 20.0 + 4.0
    while time.time() < deadline:
        try:
            data = sock.recv(32)
        except socket.timeout:
            continue
        except Exception:
            return
        if not data:
            return
        if len(data) >= 20 and data[0] == 0x80:
            err1, err2, stype = data[8], data[9], data[18]
            if err1 or err2:
                log("ERROR", f"printer error flags {err1:#04x}/{err2:#04x}")
                return
            if stype == 0x01:  # any other type is a phase change, not completion
                log("INFO", "printing completed")
                return


def main():
    if len(sys.argv) == 1:
        return discover()

    uri = os.environ.get("DEVICE_URI", "")
    if not uri.startswith("bluetooth://"):
        log("ERROR", f"bad DEVICE_URI {uri!r}")
        return CUPS_FAILED
    mac, channel = parse_uri(uri)

    if len(sys.argv) > 6:
        with open(sys.argv[6], "rb") as fh:
            payload = fh.read()
    else:
        payload = sys.stdin.buffer.read()
    if not payload:
        log("ERROR", "empty job")
        return CUPS_FAILED

    sock = connect(mac, channel)
    if sock is None:
        return CUPS_RETRY
    try:
        log("INFO", f"sending {len(payload)} bytes")
        sock.sendall(payload)
        drain(sock, len(payload))
    except Exception as exc:
        log("ERROR", f"send failed: {exc}")
        return CUPS_RETRY
    finally:
        sock.close()
    return CUPS_OK


if __name__ == "__main__":
    sys.exit(main())
