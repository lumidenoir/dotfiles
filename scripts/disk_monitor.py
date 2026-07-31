#!/usr/bin/env python3
"""
USB block device monitor using sysfs polling.
Works without udev socket access. Detects USB drives by checking
that their /sys/block/<dev> symlink path contains 'usb'.
Outputs:  add|<label>|Connected (<size>)
          remove|<label>|Disconnected
"""
import subprocess
import time
import os
import json

POLL_INTERVAL = 1.5  # seconds


def get_usb_devices():
    """Return dict of {devname: info} for all USB block disks currently present."""
    try:
        res = subprocess.check_output(
            ["lsblk", "-J", "-o", "NAME,LABEL,MODEL,SIZE,TYPE"],
            text=True, stderr=subprocess.DEVNULL
        )
        devices = json.loads(res).get("blockdevices", [])
    except Exception:
        return {}

    usb = {}
    for dev in devices:
        if dev.get("type") != "disk":
            continue
        name = dev.get("name", "")
        sys_path = f"/sys/block/{name}"
        try:
            link = os.readlink(sys_path)
        except OSError:
            continue
        if "usb" not in link:
            continue
        label = dev.get("label") or dev.get("model") or name
        size = dev.get("size") or ""
        usb[name] = {"label": label, "size": size}
    return usb


def main():
    previous = get_usb_devices()

    while True:
        time.sleep(POLL_INTERVAL)
        current = get_usb_devices()

        added = set(current) - set(previous)
        removed = set(previous) - set(current)

        for dev in added:
            info = current[dev]
            label = info["label"]
            size = info["size"]
            sub = f"Connected ({size})" if size else "Connected"
            print(f"add|{label}|{sub}", flush=True)

        for dev in removed:
            info = previous[dev]
            label = info["label"]
            print(f"remove|{label}|Disconnected", flush=True)

        previous = current


if __name__ == "__main__":
    main()
