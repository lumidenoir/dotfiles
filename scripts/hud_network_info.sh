#!/usr/bin/env bash
# Quick network & bluetooth telemetry helper for HUD Card [09]
mode="${1:-network}"

if [[ "$mode" == "network" ]]; then
    python3 -c '
import json, subprocess, re

data = {"interfaces": [], "default_gw": "192.168.1.1", "ping_ms": -1, "dns": []}

try:
    # Get default gateway
    gw_res = subprocess.run(["ip", "route", "show", "default"], capture_output=True, text=True, timeout=1.0)
    for line in gw_res.stdout.splitlines():
        parts = line.split()
        if "via" in parts:
            data["default_gw"] = parts[parts.index("via") + 1]
            break
except Exception:
    pass

try:
    # Ping check
    p_res = subprocess.run(["ping", "-c", "1", "-W", "1", "1.1.1.1"], capture_output=True, text=True, timeout=1.5)
    m = re.search(r"time=([0-9.]+)\s*ms", p_res.stdout)
    if m:
        data["ping_ms"] = round(float(m.group(1)), 1)
except Exception:
    pass

try:
    # IP info
    ip_res = subprocess.run(["ip", "-j", "addr", "show"], capture_output=True, text=True, timeout=1.0)
    raw = json.loads(ip_res.stdout)
    for iface in raw:
        ifname = iface.get("ifname", "")
        if ifname == "lo":
            continue
        operstate = iface.get("operstate", "DOWN")
        ip_addr = ""
        for addr_info in iface.get("addr_info", []):
            if addr_info.get("family") == "inet":
                ip_addr = addr_info.get("local", "")
                break
        data["interfaces"].append({
            "name": ifname,
            "state": operstate,
            "ip": ip_addr or "NO IPv4",
            "type": "VPN" if "tailscale" in ifname else ("WIRED" if ifname.startswith("e") else "WIRELESS")
        })
except Exception:
    pass

print(json.dumps(data))
'
elif [[ "$mode" == "bluetooth" ]]; then
    python3 -c '
import json, subprocess

data = {"powered": False, "devices": []}
try:
    # Check power
    show_res = subprocess.run(["bluetoothctl", "show"], capture_output=True, text=True, timeout=1.5)
    data["powered"] = "Powered: yes" in show_res.stdout
    
    # Paired devices
    dev_res = subprocess.run(["bluetoothctl", "devices", "Paired"], capture_output=True, text=True, timeout=1.5)
    for line in dev_res.stdout.splitlines():
        parts = line.strip().split(maxsplit=2)
        if len(parts) >= 3 and parts[0] == "Device":
            mac = parts[1]
            name = parts[2]
            # Check if connected
            info_res = subprocess.run(["bluetoothctl", "info", mac], capture_output=True, text=True, timeout=1.0)
            connected = "Connected: yes" in info_res.stdout
            data["devices"].append({
                "mac": mac,
                "name": name,
                "connected": connected
            })
except Exception:
    pass

print(json.dumps(data))
'
fi

