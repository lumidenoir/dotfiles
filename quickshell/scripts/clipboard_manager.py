#!/usr/bin/env python3
import subprocess
import json
import sys
import os
import re

def ensure_watchers():
    """Ensure wl-paste watchers for cliphist are running in background."""
    try:
        res_txt = subprocess.run(["pgrep", "-f", "wl-paste --type text --watch cliphist store"], stdout=subprocess.DEVNULL)
        if res_txt.returncode != 0:
            subprocess.Popen(
                ["wl-paste", "--type", "text", "--watch", "cliphist", "store"],
                start_new_session=True,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL
            )
    except Exception:
        pass

    try:
        res_img = subprocess.run(["pgrep", "-f", "wl-paste --type image --watch cliphist store"], stdout=subprocess.DEVNULL)
        if res_img.returncode != 0:
            subprocess.Popen(
                ["wl-paste", "--type", "image", "--watch", "cliphist", "store"],
                start_new_session=True,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL
            )
    except Exception:
        pass

def get_clips():
    ensure_watchers()
    res = subprocess.run(["cliphist", "list"], capture_output=True, text=True)
    if res.returncode != 0:
        return

    lines = res.stdout.strip().splitlines()
    for line in lines:
        if not line.strip():
            continue
        parts = line.split("\t", 1)
        if len(parts) == 2:
            clip_id = parts[0].strip()
            preview = parts[1].strip()
            
            is_image = "binary data" in preview.lower() or "image/" in preview.lower()
            is_url = bool(re.match(r'^https?:\/\/[^\s]+$', preview))
            is_code = bool(re.search(r'[{};()=><\[\]$#]|function|const|let|var|def |import |class ', preview))

            clip_type = "image" if is_image else ("url" if is_url else ("code" if is_code else "text"))

            item = {
                "id": clip_id,
                "preview": preview,
                "type": clip_type
            }
            try:
                print(json.dumps(item), flush=True)
            except BrokenPipeError:
                devnull = os.open(os.devnull, os.O_WRONLY)
                os.dup2(devnull, sys.stdout.fileno())
                return

def copy_clip(clip_id):
    if not clip_id:
        return
    p_decode = subprocess.Popen(["cliphist", "decode", str(clip_id)], stdout=subprocess.PIPE)
    subprocess.run(["wl-copy"], stdin=p_decode.stdout)
    p_decode.wait()

def delete_clip(clip_id):
    if not clip_id:
        return
    # cliphist delete-query matches by string, or delete specific ID
    res = subprocess.run(["cliphist", "list"], capture_output=True, text=True)
    if res.returncode == 0:
        for line in res.stdout.splitlines():
            if line.startswith(str(clip_id) + "\t"):
                p_del = subprocess.Popen(["cliphist", "delete-query"], stdin=subprocess.PIPE)
                p_del.communicate(input=line.encode('utf-8'))
                break

def clear_all():
    subprocess.run(["cliphist", "wipe"])

if __name__ == "__main__":
    if len(sys.argv) >= 3 and sys.argv[1] == "--copy":
        copy_clip(sys.argv[2])
    elif len(sys.argv) >= 3 and sys.argv[1] == "--delete":
        delete_clip(sys.argv[2])
    elif len(sys.argv) >= 2 and sys.argv[1] == "--recent":
        res = subprocess.run(["cliphist", "list"], capture_output=True, text=True)
        if res.returncode == 0:
            for line in res.stdout.splitlines()[:20]:
                parts = line.split("\t", 1)
                if len(parts) == 2 and not parts[1].startswith("[[ binary data"):
                    print(json.dumps({"id": parts[0].strip(), "preview": parts[1].strip(), "type": "text"}))
                    break
    elif len(sys.argv) >= 2 and sys.argv[1] == "--clear":
        clear_all()
    elif len(sys.argv) >= 2 and sys.argv[1] == "--ensure-daemon":
        ensure_watchers()
    else:
        get_clips()

