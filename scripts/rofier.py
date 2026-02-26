#!/usr/bin/env python3
import json
import subprocess
import sys
from datetime import datetime, timezone


def get_boot_time():
    with open("/proc/uptime") as f:
        uptime = float(f.readline().split()[0])
    return datetime.now(timezone.utc).timestamp() - uptime


boot_time = get_boot_time()


def relative_time(ts):
    notif_time = datetime.fromtimestamp(boot_time + ts / 1_000_000, timezone.utc)
    diff = int((datetime.now(timezone.utc) - notif_time).total_seconds())

    if diff < 60:
        return f"{diff}s ago"
    elif diff < 3600:
        m, s = divmod(diff, 60)
        return f"{m}m {s}s ago"
    elif diff < 86400:
        h, rem = divmod(diff, 3600)
        m = rem // 60
        return f"{h}h {m}m ago"
    else:
        d, rem = divmod(diff, 86400)
        h = rem // 3600
        return f"{d}d {h}h ago"


def get_notifications():
    try:
        result = subprocess.run(
            ["dunstctl", "history"], capture_output=True, text=True, check=True
        )
        history = json.loads(result.stdout)
        if not history or "data" not in history or not history["data"][0]:
            return [], {}

        entries = []
        id_map = {}

        for msg in history["data"][0]:
            notif_id = msg["id"]["data"]
            appname = msg.get("appname", {}).get("data", "System").upper()
            summary = msg.get("summary", {}).get("data", "")
            body = msg.get("body", {}).get("data", "")
            timestamp = msg.get("timestamp", {}).get("data")
            rel_time = relative_time(timestamp) if timestamp else ""

            entry_text = (
                f"<span size='small' alpha='70%'>{appname} • {rel_time}</span>\n"
                f"<b>{summary}</b>\n"
                f"<span size='small' alpha='80%'>{body[:80]}...</span>"
            )

            entries.append(entry_text)
            id_map[entry_text] = notif_id

        return entries, id_map
    except Exception:
        return [], {}


entries, id_map = get_notifications()

if not entries:
    subprocess.run(["notify-send", "No notifications in history"])
    sys.exit(0)

rofi_proc = subprocess.run(
    [
        "rofi",
        "-dmenu",
        "-markup-rows",
        "-eh",
        "3",
        "-i",
        "-p",
        " ",
        "-sep",
        "|",
        "-theme",
        "/home/lumi/.config/rofi/notification.rasi",
    ],
    input="|".join(entries),
    text=True,
    capture_output=True,
)

selected = rofi_proc.stdout.strip()
if selected and selected in id_map:
    subprocess.run(["dunstctl", "history-pop", str(id_map[selected])])
