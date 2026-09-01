"""Drive a ComfyUI edit workflow from the shell: swap image, prompt, seed; get a file back."""
import argparse
import json
import mimetypes
import os
import random
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

TEXT_NODES = ("TextEncodeQwenImageEditPlus", "TextEncodeQwenImageEdit", "CLIPTextEncode")
SAMPLERS = ("KSampler", "KSamplerAdvanced", "SamplerCustomAdvanced")


def call(base, path, data=None, headers=None, raw=False):
    req = urllib.request.Request(base + path, data=data, headers=headers or {})
    with urllib.request.urlopen(req, timeout=600) as r:
        return r.read() if raw else json.loads(r.read())


def upload(base, path):
    """POST /upload/image as multipart; returns the server-side filename."""
    name = os.path.basename(path)
    ctype = mimetypes.guess_type(name)[0] or "application/octet-stream"
    bnd = "----comfyedit%s" % random.randrange(1 << 48)
    body = b"".join([
        ("--%s\r\nContent-Disposition: form-data; name=\"image\"; filename=\"%s\"\r\n"
         "Content-Type: %s\r\n\r\n" % (bnd, name, ctype)).encode(),
        open(path, "rb").read(),
        ("\r\n--%s\r\nContent-Disposition: form-data; name=\"overwrite\"\r\n\r\ntrue\r\n"
         "--%s--\r\n" % (bnd, bnd)).encode(),
    ])
    r = call(base, "/upload/image", body,
             {"Content-Type": "multipart/form-data; boundary=" + bnd})
    return (r.get("subfolder") + "/" + r["name"]) if r.get("subfolder") else r["name"]


def positive_node(wf):
    """Follow the sampler's `positive` link so we never edit the negative prompt."""
    for node in wf.values():
        if node.get("class_type") in SAMPLERS:
            link = node.get("inputs", {}).get("positive")
            if isinstance(link, list) and link:
                return str(link[0])
    hits = [k for k, v in wf.items() if v.get("class_type") in TEXT_NODES]
    return hits[0] if len(hits) == 1 else None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--workflow", required=True, help="workflow exported in API format")
    ap.add_argument("--image", action="append", default=[], help="repeat for multi-image edits")
    ap.add_argument("--prompt")
    ap.add_argument("--seed", type=int)
    ap.add_argument("--steps", type=int)
    ap.add_argument("--out", default=".")
    ap.add_argument("--host", default=os.environ.get("COMFY_HOST", "http://127.0.0.1:8188"))
    a = ap.parse_args()
    base = a.host.rstrip("/")

    wf = json.load(open(a.workflow))
    if "nodes" in wf:
        sys.exit("This is a UI workflow. Re-export via Workflow > Export (API).")

    loaders = [k for k, v in sorted(wf.items()) if v.get("class_type") == "LoadImage"]
    for slot, img in enumerate(a.image):
        if slot >= len(loaders):
            sys.exit("workflow has %d LoadImage node(s), got %d --image" % (len(loaders), len(a.image)))
        wf[loaders[slot]]["inputs"]["image"] = upload(base, img)

    if a.prompt is not None:
        pos = positive_node(wf)
        if pos is None:
            sys.exit("could not identify the positive prompt node; set it in the workflow")
        wf[pos]["inputs"]["prompt" if "prompt" in wf[pos]["inputs"] else "text"] = a.prompt

    seed = a.seed if a.seed is not None else random.randrange(2**53)
    for node in wf.values():
        ins = node.get("inputs", {})
        for key in ("seed", "noise_seed"):
            if key in ins and not isinstance(ins[key], list):
                ins[key] = seed
        if a.steps is not None and "steps" in ins and not isinstance(ins["steps"], list):
            ins["steps"] = a.steps

    pid = call(base, "/prompt", json.dumps({"prompt": wf}).encode(),
               {"Content-Type": "application/json"})["prompt_id"]
    print("queued %s (seed %d)" % (pid, seed), file=sys.stderr)

    while True:
        hist = call(base, "/history/" + pid)
        if pid in hist:
            entry = hist[pid]
            status = entry.get("status", {})
            if status.get("status_str") == "error":
                sys.exit("ComfyUI reported: %s" % json.dumps(status.get("messages", []))[:2000])
            if status.get("completed") or entry.get("outputs"):
                break
        time.sleep(1)

    os.makedirs(a.out, exist_ok=True)
    wrote = 0
    for node_out in entry.get("outputs", {}).values():
        for img in node_out.get("images", []):
            if img.get("type") == "temp":
                continue
            q = urllib.parse.urlencode({k: img.get(k, "") for k in ("filename", "subfolder", "type")})
            dest = os.path.join(a.out, img["filename"])
            open(dest, "wb").write(call(base, "/view?" + q, raw=True))
            print(dest)
            wrote += 1
    if not wrote:
        sys.exit("run finished but produced no saved image (is there a SaveImage node?)")


if __name__ == "__main__":
    main()
