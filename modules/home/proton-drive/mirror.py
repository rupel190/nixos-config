"""Mirror /mnt/backup/current to Proton Drive with the official proton-drive CLI.

Each run makes the remote an exact copy of the local tree:
  1. upload everything (the CLI skips files whose content is unchanged)
  2. trash + permanently delete what disappeared locally since the last run

Quirks this works around:
  - a symlink fails the CLI's upload of its whole folder, so folders that
    contain one (anywhere below) are walked here and their symlinks skipped
  - rsync snapshots: only each job's `latest` is mirrored, under a fixed
    remote name, so weekly dated folders don't pile up as full copies
"""

import os
import subprocess
import sys

DRIVE = "/mnt/backup"  # /mnt/backup/recovery is historical data and deliberately NOT mirrored
LOCAL = os.environ.get("MIRROR_LOCAL", DRIVE + "/current")  # overrides are for testing
REMOTE = os.environ.get("MIRROR_REMOTE", "/my-files/backup")
SNAPSHOTS = "rsync-weekly-bak"
EXCLUDE = {"Passwords.key"}  # by name, anywhere: the keyfile must never sit next to its database
STATE = os.environ.get("MIRROR_STATE", os.path.expanduser("~/.local/state/proton-mirror/manifest"))
BATCH = 200  # local paths per upload call

failures = []


def cli(*args):
    r = subprocess.run(["proton-drive", *args], capture_output=True, text=True)
    return r.returncode, r.stdout + r.stderr


def remote(rel):
    return REMOTE if not rel else REMOTE + "/" + rel


def ensure_folder(rel):
    if cli("filesystem", "info", remote(rel))[0] == 0:
        return
    if rel:
        parent, _, name = rel.rpartition("/")
        ensure_folder(parent)
        rc, out = cli("filesystem", "create-folder", remote(parent), name)
    else:
        parent, _, name = REMOTE.rpartition("/")
        rc, out = cli("filesystem", "create-folder", parent, name)
    if rc != 0:
        failures.append(f"create-folder {rel}: {out.strip()}")


def scan(path, rel, manifest):
    """Record every mirrored path; return True if the tree holds only files and folders."""
    clean = True
    for e in os.scandir(path):
        child = f"{rel}/{e.name}" if rel else e.name
        if e.name in EXCLUDE or e.is_symlink() or not (e.is_file() or e.is_dir()):
            clean = False
        elif e.is_dir():
            manifest.add(child + "/")
            clean = scan(e.path, child, manifest) and clean
        else:
            manifest.add(child)
    return clean


def mirror_dir(path, rel, manifest, top=False):
    """Upload the contents of `path` into remote folder `rel`."""
    ensure_folder(rel)
    whole = []  # files and symlink-free folders: one upload call per batch
    for e in sorted(os.scandir(path), key=lambda e: e.name):
        child = f"{rel}/{e.name}" if rel else e.name
        if top and e.name == SNAPSHOTS:
            continue
        if e.name in EXCLUDE or e.is_symlink() or not (e.is_file() or e.is_dir()):
            continue
        if e.is_file():
            manifest.add(child)
            whole.append(e.path)
        else:
            manifest.add(child + "/")
            sub = set()
            if scan(e.path, child, sub):
                manifest |= sub
                whole.append(e.path)
            else:
                mirror_dir(e.path, child, manifest)
    for i in range(0, len(whole), BATCH):
        rc, out = cli("filesystem", "upload", "-f", "replace", "-d", "merge", "-t",
                      *whole[i:i + BATCH], remote(rel))
        print(out.strip(), flush=True)
        if rc != 0:
            failures.append(f"upload into {rel or '/'}: exit {rc}")


def mirror_snapshots(manifest):
    root = os.path.join(LOCAL, SNAPSHOTS)
    if not os.path.isdir(root):
        return
    for job in sorted(os.listdir(root)):
        latest = os.path.join(root, job, "latest")
        if os.path.isdir(latest):
            rel = f"{SNAPSHOTS}/{job}/latest"
            manifest.update({f"{SNAPSHOTS}/", f"{SNAPSHOTS}/{job}/", rel + "/"})
            mirror_dir(os.path.realpath(latest), rel, manifest)


def prune(old, new):
    # only the topmost path of each deleted subtree (a subtree sorts contiguously)
    tops = []
    for p in sorted(old - new):
        if not (tops and tops[-1].endswith("/") and p.startswith(tops[-1])):
            tops.append(p)
    for p in tops:
        rel = p.rstrip("/")
        rc, out = cli("filesystem", "trash", remote(rel))
        if rc != 0:
            failures.append(f"trash {rel}: {out.strip()}")
            continue
        rc, out = cli("filesystem", "delete", "/trash/" + rel.rsplit("/", 1)[-1])
        print(f"removed {rel}" if rc == 0 else f"trashed (not deleted) {rel}: {out.strip()}")


def main():
    if "MIRROR_LOCAL" not in os.environ and not (os.path.ismount(DRIVE) and os.path.isdir(LOCAL)):
        sys.exit(f"{DRIVE} is not mounted or {LOCAL} is missing")
    manifest = set()
    mirror_dir(LOCAL, "", manifest, top=True)
    mirror_snapshots(manifest)

    if os.path.exists(STATE):
        with open(STATE) as f:
            prune(set(f.read().splitlines()), manifest)
    os.makedirs(os.path.dirname(STATE), exist_ok=True)
    with open(STATE, "w") as f:
        f.write("\n".join(sorted(manifest)) + "\n")

    if failures:
        print("FAILURES:\n  " + "\n  ".join(failures), file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
