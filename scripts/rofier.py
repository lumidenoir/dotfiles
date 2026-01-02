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


if len(sys.argv) > 1:
    subprocess.run(["dunstctl", "history-pop", sys.argv[1]])
    sys.exit(0)

try:
    result = subprocess.run(
        ["dunstctl", "history"], capture_output=True, text=True, check=True
    )
    history = json.loads(result.stdout)
except (subprocess.CalledProcessError, json.JSONDecodeError, KeyError) as e:
    print(f"Error fetching notification history: {e}", file=sys.stderr)
    sys.exit(1)

entries = []
id_map = {}

for msg in history["data"][0]:
    notif_id = msg["id"]["data"]
    appname = msg.get("appname", {}).get("data", "Unknown")
    summary = msg.get("summary", {}).get("data", "(no summary)")
    body = msg.get("body", {}).get("data", "")
    timestamp = msg.get("timestamp", {}).get("data")
    rel_time = relative_time(timestamp) if timestamp else "(no timestamp)"

    body = (body[:100] + "…") if len(body) > 100 else body
    entry_text = f"<b>{appname}</b> — {summary}  <i>({rel_time})</i>\n{body}"

    entries.append(entry_text)
    id_map[entry_text] = notif_id

if not entries:
    sys.exit(0)

result = subprocess.run(
    [
        "rofi",
        "-dmenu",
        "-markup-rows",
        "-i",
        "-p",
        "󰛩 ",
        "-sep",
        "|",
        "-eh",
        "2",
        "-config",
        "/home/lumi/.config/rofi/notification.rasi",
    ],
    input="|".join(entries),
    text=True,
    capture_output=True,
)

selected = result.stdout.strip()
if selected and selected in id_map:
    subprocess.run(["dunstctl", "history-pop", str(id_map[selected])])
