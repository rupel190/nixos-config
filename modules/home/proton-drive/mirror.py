"""Mirror /mnt/backup/current to Proton Drive with the official proton-drive CLI.

Each run makes the remote an exact copy of the local tree:
  1. plan: walk the tree, list what should exist, create the remote folders (in parallel)
  2. prune: trash + permanently delete what disappeared since the last run
  3. save the plan as the new manifest (a killed run loses nothing: the next one re-plans)
  4. upload in parallel (the CLI skips files whose content is unchanged)

Quirks this works around:
  - a symlink fails the CLI's upload of its whole folder, so folders that
    contain one (anywhere below) are walked here and their symlinks skipped
  - rsync snapshots: only each job's `latest` is mirrored, under a fixed
    remote name, so weekly dated folders don't pile up as full copies
  - uploads are bound by per-file round trips, not bandwidth, hence WORKERS
"""

import json
import os
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor

DRIVE = "/mnt/backup"  # /mnt/backup/recovery is historical data and deliberately NOT mirrored
LOCAL = os.environ.get("MIRROR_LOCAL", DRIVE + "/current")  # overrides are for testing
REMOTE = os.environ.get("MIRROR_REMOTE", "/my-files/backup")
SNAPSHOTS = "rsync-weekly-bak"
EXCLUDE = {"Passwords.key"}  # by name, anywhere: the keyfile must never sit next to its database
STATE = os.environ.get("MIRROR_STATE", os.path.expanduser("~/.local/state/proton-mirror/manifest"))
BATCH = 200  # local paths per upload call
WORKERS = 3  # parallel upload calls: overlaps per-file round trips; more only crowds the uplink
SPLIT = 2000  # folders with more files are split up, so the workers share them

failures = []


def cli(*args):
    r = subprocess.run(["proton-drive", *args], capture_output=True, text=True)
    return r.returncode, r.stdout + r.stderr


def remote(rel):
    return REMOTE if not rel else REMOTE + "/" + rel


def remote_children(rel):
    rc, out = cli("filesystem", "list", "-j", remote(rel))
    if rc != 0:
        return None
    return {n["name"]["value"] for n in json.loads(out) if n.get("name", {}).get("ok")}


def create_folders(folders):
    """Create the remote folders level by level; one listing per parent finds the existing ones."""
    if cli("filesystem", "info", REMOTE)[0] != 0:
        parent, _, name = REMOTE.rpartition("/")
        cli("filesystem", "create-folder", parent, name)
    created = set()
    by_depth = {}
    for f in folders:
        if f:
            by_depth.setdefault(f.count("/"), {}).setdefault(f.rpartition("/")[0], []).append(f)

    def fill(item):
        parent, children = item
        existing = set() if parent in created else remote_children(parent)
        for f in children:
            name = f.rpartition("/")[2]
            if existing is not None and name in existing:
                continue
            rc, out = cli("filesystem", "create-folder", remote(parent), name)
            if rc == 0:
                created.add(f)
            else:
                failures.append(f"create-folder {f}: {out.strip()}")

    with ThreadPoolExecutor(WORKERS) as pool:
        for depth in sorted(by_depth):
            list(pool.map(fill, by_depth[depth].items()))


def entries(path):
    """Directory entries; an unreadable folder is reported and treated as empty."""
    try:
        return list(os.scandir(path))
    except PermissionError as err:
        failures.append(f"unreadable, skipped: {err.filename}")
        return []


def skipped(e):
    return e.name in EXCLUDE or e.is_symlink() or not (e.is_file() or e.is_dir())


def scan(path, rel, manifest):
    """Record every mirrored path; return (only files and folders?, file count)."""
    clean, count = True, 0
    for e in entries(path):
        child = f"{rel}/{e.name}" if rel else e.name
        if skipped(e):
            clean = False
        elif e.is_dir():
            manifest.add(child + "/")
            c, n = scan(e.path, child, manifest)
            clean, count = clean and c, count + n
        else:
            manifest.add(child)
            count += 1
    return clean, count


def plan_dir(path, rel, manifest, jobs, folders, top=False):
    """Queue uploads for the contents of `path` into remote folder `rel`."""
    folders.add(rel)
    whole = []  # files and symlink-free folders: uploaded together in batches
    for e in sorted(entries(path), key=lambda e: e.name):
        child = f"{rel}/{e.name}" if rel else e.name
        if (top and e.name == SNAPSHOTS) or skipped(e):
            continue
        if e.is_file():
            manifest.add(child)
            whole.append(e.path)
        else:
            manifest.add(child + "/")
            sub = set()
            clean, count = scan(e.path, child, sub)
            if clean and count <= SPLIT:
                manifest |= sub
                whole.append(e.path)
            else:
                plan_dir(e.path, child, manifest, jobs, folders)
    for i in range(0, len(whole), BATCH):
        jobs.append((whole[i:i + BATCH], rel))


def plan_snapshots(manifest, jobs, folders):
    root = os.path.join(LOCAL, SNAPSHOTS)
    if not os.path.isdir(root):
        return
    for job in sorted(os.listdir(root)):
        latest = os.path.join(root, job, "latest")
        if os.path.isdir(latest):
            rel = f"{SNAPSHOTS}/{job}/latest"
            manifest.update({f"{SNAPSHOTS}/", f"{SNAPSHOTS}/{job}/", rel + "/"})
            folders.update({SNAPSHOTS, f"{SNAPSHOTS}/{job}"})
            plan_dir(os.path.realpath(latest), rel, manifest, jobs, folders)


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
        print(f"removed {rel}" if rc == 0 else f"trashed (not deleted) {rel}: {out.strip()}", flush=True)


def upload(job):
    items, rel = job
    rc, out = cli("filesystem", "upload", "-f", "replace", "-d", "merge", "-t", *items, remote(rel))
    print(out.strip(), flush=True)
    if rc != 0:
        failures.append(f"upload into {rel or '/'}: exit {rc}")


def main():
    if "MIRROR_LOCAL" not in os.environ and not (os.path.ismount(DRIVE) and os.path.isdir(LOCAL)):
        sys.exit(f"{DRIVE} is not mounted or {LOCAL} is missing")
    manifest, jobs, folders = set(), [], set()
    plan_dir(LOCAL, "", manifest, jobs, folders, top=True)
    plan_snapshots(manifest, jobs, folders)
    print(f"planned {len(manifest)} paths, {len(folders)} folders, {len(jobs)} upload calls", flush=True)
    create_folders(folders)

    if os.path.exists(STATE):
        with open(STATE) as f:
            prune(set(f.read().splitlines()), manifest)
    os.makedirs(os.path.dirname(STATE), exist_ok=True)
    with open(STATE, "w") as f:
        f.write("\n".join(sorted(manifest)) + "\n")

    with ThreadPoolExecutor(WORKERS) as pool:
        list(pool.map(upload, jobs))

    if failures:
        print("FAILURES:\n  " + "\n  ".join(failures), file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
