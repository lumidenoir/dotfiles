#!/usr/bin/env python3
import subprocess
import sys
import re
import json
import time

def inspect_device(dev_name):
    try:
        res = subprocess.check_output(
            ["lsblk", "-J", "-o", "NAME,LABEL,MODEL,SIZE,RM,TYPE,TRAN", f"/dev/{dev_name}"],
            text=True, stderr=subprocess.DEVNULL
        )
        data = json.loads(res).get("blockdevices", [])
        if not data:
            return None
            
        item = data[0]
        name = item.get("name", dev_name)
        label = item.get("label") or item.get("model") or name
        size = item.get("size", "")
        rm = bool(item.get("rm"))
        tran = item.get("tran", "")
        
        is_usb = rm or tran == "usb"
        if not is_usb:
            return None
            
        return {
            "name": name,
            "label": label,
            "size": size,
            "is_usb": True
        }
    except Exception:
        return None

def main():
    # Cache device details so remove events retain human-readable names
    dev_cache = {}
    
    proc = subprocess.Popen(
        ["udisksctl", "monitor"],
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        text=True
    )
    
    last_emitted = {}
    
    for line in proc.stdout:
        line = line.strip()
        if "block_devices/" not in line:
            continue
            
        match = re.search(
            r"block_devices/([a-zA-Z0-9_]+):\s+(Added|Removed)\s+interface\s+org\.freedesktop\.UDisks2\.(Filesystem|Block)",
            line
        )
        if not match:
            continue
            
        dev_name = match.group(1)
        action_str = match.group(2)
        action = "add" if action_str == "Added" else "remove"
        
        if action == "add":
            # Give system a tiny moment to finish populating label/mount properties
            time.sleep(0.15)
            info = inspect_device(dev_name)
            if info:
                dev_cache[dev_name] = info
                title = info["label"]
                size = info["size"]
                sub = f"Connected ({size})" if size else "Connected"
                msg = f"add|{title}|{sub}"
                
                now = time.time()
                if msg != last_emitted.get("msg") or (now - last_emitted.get("time", 0)) > 2.0:
                    last_emitted = {"msg": msg, "time": now}
                    print(msg, flush=True)
        elif action == "remove":
            info = dev_cache.pop(dev_name, None)
            if info:
                title = info["label"]
                msg = f"remove|{title}|Disconnected"
                now = time.time()
                if msg != last_emitted.get("msg") or (now - last_emitted.get("time", 0)) > 2.0:
                    last_emitted = {"msg": msg, "time": now}
                    print(msg, flush=True)

if __name__ == "__main__":
    main()
