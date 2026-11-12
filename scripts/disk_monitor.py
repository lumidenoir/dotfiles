#!/usr/bin/env python3
"""
QuickShell Hardware & Mobile Connection Monitor
Announces connection and disconnection events for:
1. USB Storage (flash drives, external SSD/HDDs, SD cards) via UDisks2 / lsblk
2. Mobile Phones (MTP, Android, Apple iOS via USB) via udev & GIO
3. Mobile Connection over Wi-Fi (KDE Connect) via DBus
4. Bluetooth Peripherals (headphones, earbuds, phones) via BlueZ DBus

Protocol output to stdout:
  add|Title|Subtitle|DevPath|DevType
  remove|Title|Subtitle|DevPath|DevType

  DevType: "usb" | "phone" | "bluetooth"
"""

import subprocess
import sys
import os
import re
import json
import time
import threading
import fcntl
import signal
import atexit

# Singleton lock to prevent duplicate disk_monitor processes
lock_fd = open("/tmp/disk_monitor.lock", "w")
try:
    fcntl.flock(lock_fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
except IOError:
    # Another instance is already running; exit silently
    sys.exit(0)

# Track child subprocesses for guaranteed cleanup
child_procs = []

def cleanup_children(signum=None, frame=None):
    for p in child_procs:
        try:
            p.terminate()
            p.kill()
        except Exception:
            pass
    # Clean up any orphaned udisksctl monitor processes
    try:
        subprocess.run(["pkill", "-u", str(os.getuid()), "-x", "udisksctl"], stderr=subprocess.DEVNULL)
    except Exception:
        pass
    if signum is not None:
        sys.exit(0)

atexit.register(cleanup_children)
signal.signal(signal.SIGTERM, cleanup_children)
signal.signal(signal.SIGINT, cleanup_children)
signal.signal(signal.SIGHUP, cleanup_children)

# Kill any existing orphaned udisksctl before starting
try:
    subprocess.run(["pkill", "-u", str(os.getuid()), "-x", "udisksctl"], stderr=subprocess.DEVNULL)
except Exception:
    pass

# Thread-safe emitter with deduplication
lock = threading.Lock()
last_emitted = {}
device_cache = {}

def emit(action, title, subtitle, dev_path="", dev_type="usb"):
    with lock:
        now = time.time()
        title = title.strip() if title else ""
        if not title:
            if dev_type == "phone":
                title = "Mobile Device"
            elif dev_type == "bluetooth":
                title = "Bluetooth Device"
            else:
                title = "USB Drive"

        # Deduplicate identical events within 2.5 seconds
        key = f"{action}|{title}|{dev_type}"
        if key in last_emitted and (now - last_emitted[key]) < 2.5:
            return
        last_emitted[key] = now

        msg = f"{action}|{title}|{subtitle}|{dev_path}|{dev_type}"
        print(msg, flush=True)


# ─── 1. UDisks2 / USB Storage Monitor ──────────────────────────────────────────
def inspect_block_device(dev_name):
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
            "path": f"/dev/{name}",
            "is_usb": True
        }
    except Exception:
        return None

def run_udisks_monitor():
    dev_cache = {}
    try:
        proc = subprocess.Popen(
            ["udisksctl", "monitor"],
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            text=True
        )
        child_procs.append(proc)
    except Exception:
        return

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
            time.sleep(0.2)
            info = inspect_block_device(dev_name)
            if info:
                dev_cache[dev_name] = info
                title = info["label"]
                size = info["size"]
                sub = f"Connected ({size})" if size else "Connected"
                emit("add", title, sub, info["path"], "usb")
        elif action == "remove":
            info = dev_cache.pop(dev_name, None)
            if info:
                title = info["label"]
                emit("remove", title, "Disconnected", info.get("path", ""), "usb")


# ─── 2. udev USB Phone Monitor (Android / iPhone / MTP) ───────────────────────
KNOWN_PHONE_VENDORS = {
    "apple", "google", "samsung", "oneplus", "xiaomi", "oppo", "vivo",
    "motorola", "huawei", "sony", "realme", "nothing", "asus", "htc", "lg",
    "poco", "redmi", "meizu", "zte"
}

def clean_device_name(name):
    if not name:
        return ""
    # Replace escaped spaces and underscores
    name = re.sub(r"\\x20", " ", name)
    name = name.replace("_", " ")
    return " ".join(name.split())

def run_udev_monitor():
    phone_cache = {}
    try:
        proc = subprocess.Popen(
            ["udevadm", "monitor", "--environment", "--subsystem-match=usb"],
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            text=True
        )
    except Exception:
        return

    curr_event = {}
    for line in proc.stdout:
        line = line.strip()
        if not line:
            # End of an event block
            if curr_event.get("DEVTYPE") == "usb_device":
                action = curr_event.get("ACTION", "")
                devpath = curr_event.get("DEVPATH", "")
                vendor = (curr_event.get("ID_VENDOR") or curr_event.get("ID_USB_VENDOR") or "").lower()
                model = clean_device_name(curr_event.get("ID_MODEL_ENC") or curr_event.get("ID_MODEL") or curr_event.get("ID_USB_MODEL"))
                interfaces = curr_event.get("ID_USB_INTERFACES", "")
                is_mtp = curr_event.get("ID_MTP_DEVICE") == "1" or ":060101:" in interfaces
                is_adb = curr_event.get("ID_DEBUG_APPLIANCE") == "android" or ":ff4201:" in interfaces
                is_phone_vendor = any(v in vendor for v in KNOWN_PHONE_VENDORS)

                is_phone = is_mtp or is_adb or (is_phone_vendor and "mouse" not in model.lower() and "keyboard" not in model.lower())

                if is_phone and action == "add":
                    title = model if model else (vendor.capitalize() + " Phone" if vendor else "Mobile Device")
                    phone_cache[devpath] = title
                    devname = curr_event.get("DEVNAME", "")
                    emit("add", title, "Connected (USB)", devname, "phone")
                elif action == "remove":
                    title = phone_cache.pop(devpath, None)
                    if title:
                        emit("remove", title, "Disconnected", "", "phone")

            curr_event = {}
            continue

        if "=" in line:
            k, v = line.split("=", 1)
            curr_event[k] = v


# ─── 3. GLib Loop: GIO VolumeMonitor + KDE Connect & BlueZ DBus ────────────────
def run_glib_services():
    try:
        import dbus
        from dbus.mainloop.glib import DBusGMainLoop
        from gi.repository import GLib, Gio
    except ImportError:
        return

    DBusGMainLoop(set_as_default=True)
    loop = GLib.MainLoop()

    # 3a. GIO Volume Monitor (MTP Volumes)
    try:
        vm = Gio.VolumeMonitor.get()
        def on_vol_added(monitor, vol):
            name = vol.get_name()
            icon = vol.get_icon()
            icon_names = icon.get_names() if icon and hasattr(icon, 'get_names') else []
            act_root = vol.get_activation_root()
            uri = act_root.get_uri() if act_root else ""
            dev_path = vol.get_identifier('unix-device') or ""
            is_phone = any('phone' in i.lower() for i in icon_names) or uri.startswith('mtp://')
            if is_phone:
                emit("add", name, "Connected (USB)", uri or dev_path, "phone")

        def on_vol_removed(monitor, vol):
            name = vol.get_name()
            icon = vol.get_icon()
            icon_names = icon.get_names() if icon and hasattr(icon, 'get_names') else []
            is_phone = any('phone' in i.lower() for i in icon_names)
            if is_phone:
                emit("remove", name, "Disconnected", "", "phone")

        vm.connect("volume-added", on_vol_added)
        vm.connect("volume-removed", on_vol_removed)
    except Exception:
        pass

    # 3b. KDE Connect DBus Listener
    try:
        s_bus = dbus.SessionBus()
        # Pre-seed initial states so we don't spam notifications on startup
        known_reachable = {}
        try:
            mgr = s_bus.get_object('org.kde.kdeconnect', '/modules/kdeconnect')
            dev_ids = mgr.devices(dbus_interface='org.kde.kdeconnect.daemon')
            for dev_id in dev_ids:
                dev_obj = s_bus.get_object('org.kde.kdeconnect', f'/modules/kdeconnect/devices/{dev_id}')
                props = dbus.Interface(dev_obj, 'org.freedesktop.DBus.Properties')
                known_reachable[str(dev_id)] = bool(props.Get('org.kde.kdeconnect.device', 'isReachable'))
        except Exception:
            pass

        def on_kde_reachable(val, sender=None, path=None):
            try:
                dev_obj = s_bus.get_object('org.kde.kdeconnect', path)
                props = dbus.Interface(dev_obj, 'org.freedesktop.DBus.Properties')
                name = str(props.Get('org.kde.kdeconnect.device', 'name'))
                paired = bool(props.Get('org.kde.kdeconnect.device', 'isPaired'))
                if paired:
                    dev_id = path.split('/')[-1]
                    was_reachable = known_reachable.get(dev_id)
                    known_reachable[dev_id] = val
                    if was_reachable != val:
                        action = "add" if val else "remove"
                        sub = "Connected (KDE Connect)" if val else "Disconnected"
                        emit(action, name, sub, "", "phone")
            except Exception:
                pass

        s_bus.add_signal_receiver(
            on_kde_reachable,
            signal_name='reachableChanged',
            dbus_interface='org.kde.kdeconnect.device',
            path_keyword='path'
        )
    except Exception:
        pass

    # 3c. BlueZ DBus Listener (Bluetooth Peripherals)
    try:
        sys_bus = dbus.SystemBus()
        def on_bt_props(interface, changed_props, invalidated_props, path=None):
            if interface == "org.bluez.Device1" and "Connected" in changed_props:
                connected = bool(changed_props["Connected"])
                try:
                    dev_obj = sys_bus.get_object("org.bluez", path)
                    props = dbus.Interface(dev_obj, "org.freedesktop.DBus.Properties")
                    name = str(props.Get("org.bluez.Device1", "Name") or props.Get("org.bluez.Device1", "Alias") or "Bluetooth Device")
                    action = "add" if connected else "remove"
                    sub = "Connected (Bluetooth)" if connected else "Disconnected"
                    emit(action, name, sub, "", "bluetooth")
                except Exception:
                    pass

        sys_bus.add_signal_receiver(
            on_bt_props,
            signal_name="PropertiesChanged",
            dbus_interface="org.freedesktop.DBus.Properties",
            path_keyword="path"
        )
    except Exception:
        pass

    loop.run()


# ─── Main Orchestrator ────────────────────────────────────────────────────────
def main():
    t_udisks = threading.Thread(target=run_udisks_monitor, daemon=True)
    t_udev = threading.Thread(target=run_udev_monitor, daemon=True)
    t_glib = threading.Thread(target=run_glib_services, daemon=True)

    t_udisks.start()
    t_udev.start()
    t_glib.start()

    # Keep main thread alive
    while True:
        time.sleep(1)

if __name__ == "__main__":
    main()
