"""Mirror /mnt/backup/current to Proton Drive with the official proton-drive CLI.

Each run makes the remote an exact copy of the local tree:
  1. plan: walk the tree, list what should exist, create the remote folders the last run didn't have
  2. prune: trash + permanently delete what disappeared since the last run, in batches
  3. save the plan as the new manifest (a killed run loses nothing: the next one re-plans)
  4. upload in parallel (the CLI skips files whose content is unchanged)

Quirks this works around:
  - a symlink fails the CLI's upload of its whole folder, so folders that
    contain one (anywhere below) are walked here and their symlinks skipped
  - rsync snapshots: only each job's `latest` is mirrored, under a fixed
    remote name, so weekly dated folders don't pile up as full copies
  - parallel CLI processes race on the single-use refresh token after ~24h
    and the loser deletes the stored session, hence WORKERS = 1 (the package
    wrapper also serializes every CLI call, e.g. the daily backup watchdog's)
"""

import json
import os
import subprocess
import sys
import threading
import time
from concurrent.futures import ThreadPoolExecutor

DRIVE = "/mnt/backup"  # /mnt/backup/recovery is historical data and deliberately NOT mirrored
LOCAL = os.environ.get("MIRROR_LOCAL", DRIVE + "/current")  # overrides are for testing
REMOTE = os.environ.get("MIRROR_REMOTE", "/my-files/backup")
SNAPSHOTS = "rsync-weekly-bak"
EXCLUDE = {"Passwords.key"}  # by name, anywhere: the keyfile must never sit next to its database
CORE = f"{SNAPSHOTS}/home-core/latest"
EXCLUDE_PATHS = {  # by remote path: kept on the backup drive only
    f"{CORE}/.local/share/BeamNG/BeamNG.drive/current/mods/repo",  # downloaded mods, 31 GB
    f"{CORE}/.claude/projects",  # transcripts, 13 GB; the big ones change with every session
}
STATE = os.environ.get("MIRROR_STATE", os.path.expanduser("~/.local/state/proton-mirror/manifest"))
FOLDERS = STATE + ".folders"  # remote folders known to exist after the last run
BATCH = 200  # local paths per upload call
PRUNE_BATCH = 50  # remote paths per trash/delete call; each call walks the remote tree from the root
WORKERS = 1  # upload calls at a time; >1 logs the CLI out at token refresh (see top)
SPLIT = 2000  # folders with more files are split up, so the workers share them

LOGGED_OUT = 3  # exit code the wrapper turns into a "log in again" notification

failures = []
suspect = set()  # remote folders a create or upload failed for: not trusted to exist next run
logged_out = threading.Event()


def cli(*args):
    # a keyring read can come back empty for one call (nov 22), so only a repeated "login first" means logged out
    for wait in (0, 30, 120):
        time.sleep(wait)
        r = subprocess.run(["proton-drive", *args], capture_output=True, text=True)
        if "login first" not in r.stdout + r.stderr:
            break
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
                suspect.add(f)

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


def skipped(e, rel):
    return e.name in EXCLUDE or rel in EXCLUDE_PATHS or e.is_symlink() or not (e.is_file() or e.is_dir())


def scan(path, rel, manifest):
    """Record every mirrored path; return (only files and folders?, file count)."""
    clean, count = True, 0
    for e in entries(path):
        child = f"{rel}/{e.name}" if rel else e.name
        if skipped(e, child):
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
        if (top and e.name == SNAPSHOTS) or skipped(e, child):
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

    def each(cmd, batch, target, record=True):
        """Run cmd on the whole batch; if that fails, one path at a time. Returns the paths that succeeded."""
        if not batch:
            return []
        rc, out = cli("filesystem", cmd, *map(target, batch))
        if rc == 0:
            return batch
        if "login first" in out:
            logged_out.set()
            return []
        done = []
        for rel in batch:
            rc, out = cli("filesystem", cmd, target(rel))
            if "login first" in out:
                logged_out.set()
                break
            if rc == 0:
                done.append(rel)
            elif record:
                failures.append(f"{cmd} {rel}: {out.strip()}")
        return done

    for i in range(0, len(tops), PRUNE_BATCH):
        if logged_out.is_set():
            return
        trashed = each("trash", [p.rstrip("/") for p in tops[i:i + PRUNE_BATCH]], remote)
        deleted = set(each("delete", trashed, lambda rel: "/trash/" + rel.rsplit("/", 1)[-1], record=False))
        for rel in trashed:
            print(f"removed {rel}" if rel in deleted else f"trashed (not deleted) {rel}", flush=True)


def upload(job):
    if logged_out.is_set():
        return
    items, rel = job
    rc, out = cli("filesystem", "upload", "-f", "replace", "-d", "merge", "-t", *items, remote(rel))
    print(out.strip(), flush=True)
    if "login first" in out:
        logged_out.set()
    if rc != 0:
        failures.append(f"upload into {rel or '/'}: exit {rc}")
        suspect.add(rel)


def save_folders(folders):
    with open(FOLDERS, "w") as f:
        f.write("\n".join(sorted(folders - suspect)) + "\n")


def main():
    if "MIRROR_LOCAL" not in os.environ and not (os.path.ismount(DRIVE) and os.path.isdir(LOCAL)):
        sys.exit(f"{DRIVE} is not mounted or {LOCAL} is missing")
    manifest, jobs, folders = set(), [], set()
    plan_dir(LOCAL, "", manifest, jobs, folders, top=True)
    plan_snapshots(manifest, jobs, folders)
    known = set()
    if os.path.exists(FOLDERS):
        with open(FOLDERS) as f:
            known = set(f.read().splitlines())
    print(f"planned {len(manifest)} paths, {len(folders)} folders ({len(folders - known)} new), {len(jobs)} upload calls", flush=True)
    create_folders(folders - known)
    os.makedirs(os.path.dirname(STATE), exist_ok=True)
    save_folders(folders)

    if os.path.exists(STATE):
        with open(STATE) as f:
            prune(set(f.read().splitlines()), manifest)
    if logged_out.is_set():  # the old manifest stays, so the next run finishes the prune
        print("Proton Drive session lost mid-run; remaining work skipped", file=sys.stderr)
        sys.exit(LOGGED_OUT)
    with open(STATE, "w") as f:
        f.write("\n".join(sorted(manifest)) + "\n")

    with ThreadPoolExecutor(WORKERS) as pool:
        list(pool.map(upload, jobs))
    save_folders(folders)

    if logged_out.is_set():
        print("Proton Drive session lost mid-run; remaining uploads skipped", file=sys.stderr)
        sys.exit(LOGGED_OUT)
    if failures:
        print("FAILURES:\n  " + "\n  ".join(failures), file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
