#!/usr/bin/env python3
import sys
import os
import re
import json
import time
import subprocess
from datetime import datetime
from pathlib import Path

CACHE_DIR = Path.home() / ".cache" / "quickshell"
DATA_FILE = CACHE_DIR / "app_time.json"

APP_METADATA = {
    "antigravity-ide": {"name": "Antigravity IDE", "icon": "󰘑", "color": "#38BDF8"},
    "todoist": {"name": "Todoist", "icon": "󰝘", "color": "#E44332"},
    "notion": {"name": "Notion", "icon": "󰠮", "color": "#FFFFFF"},
    "youtube": {"name": "YouTube", "icon": "󰗃", "color": "#FF0000"},
    "github": {"name": "GitHub", "icon": "󰊤", "color": "#FFFFFF"},
    "chatgpt": {"name": "ChatGPT", "icon": "󰚩", "color": "#10A37F"},
    "claude": {"name": "Claude", "icon": "󰚩", "color": "#D97706"},
    "gmail": {"name": "Gmail", "icon": "󰊫", "color": "#EA4335"},
    "code": {"name": "VS Code", "icon": "󰨞", "color": "#007ACC"},
    "brave-browser": {"name": "Brave", "icon": "󰖟", "color": "#FB542B"},
    "zen-browser": {"name": "Zen Browser", "icon": "󰖟", "color": "#FF9500"},
    "firefox": {"name": "Firefox", "icon": "󰖟", "color": "#FF7139"},
    "google-chrome": {"name": "Chrome", "icon": "󰊯", "color": "#4285F4"},
    "chromium": {"name": "Chromium", "icon": "󰊯", "color": "#4285F4"},
    "emacs": {"name": "Emacs", "icon": "", "color": "#7F5AB6"},
    "kitty": {"name": "Kitty", "icon": "󰞷", "color": "#30D158"},
    "foot": {"name": "Foot", "icon": "󰞷", "color": "#22C55E"},
    "alacritty": {"name": "Alacritty", "icon": "󰞷", "color": "#F97316"},
    "wezterm": {"name": "WezTerm", "icon": "󰞷", "color": "#51A0CF"},
    "st": {"name": "Terminal", "icon": "󰞷", "color": "#22C55E"},
    "spotify": {"name": "Spotify", "icon": "󰓇", "color": "#1DB954"},
    "discord": {"name": "Discord", "icon": "󰙯", "color": "#5865F2"},
    "telegram-desktop": {"name": "Telegram", "icon": "󰈹", "color": "#229ED9"},
    "org.gnome.nautilus": {"name": "Files", "icon": "󰉋", "color": "#3B82F6"},
    "thunar": {"name": "Thunar", "icon": "󰉋", "color": "#3B82F6"},
    "xflr5": {"name": "XFLR5", "icon": "󰘑", "color": "#38BDF8"},
    "xflr": {"name": "XFLR5", "icon": "󰘑", "color": "#38BDF8"},
    "freecad": {"name": "FreeCAD", "icon": "󰘑", "color": "#CB171E"},
    "cider": {"name": "Cider", "icon": "󰎆", "color": "#FA2D48"},
    "rmpc": {"name": "rmpc", "icon": "󰎆", "color": "#30D158"},
    "octave": {"name": "Octave", "icon": "󰈦", "color": "#F08726"},
    "org.octave.octave": {"name": "Octave", "icon": "󰈦", "color": "#F08726"},
    "android-studio": {"name": "Android Studio", "icon": "󰘑", "color": "#3DDC84"},
    "localsend": {"name": "LocalSend", "icon": "󰄡", "color": "#2196F3"},
    "sunshine": {"name": "Sunshine", "icon": "󰕼", "color": "#F59E0B"},
    "pavucontrol": {"name": "Audio Control", "icon": "󰕾", "color": "#10B981"},
    "org.pulseaudio.pavucontrol": {"name": "Audio Control", "icon": "󰕾", "color": "#10B981"},
    "helvum": {"name": "Helvum", "icon": "󰎆", "color": "#6366F1"},
    "org.pipewire.helvum": {"name": "Helvum", "icon": "󰎆", "color": "#6366F1"},
    "qbittorrent": {"name": "qBittorrent", "icon": "󰇚", "color": "#2F679D"},
    "org.qbittorrent.qbittorrent": {"name": "qBittorrent", "icon": "󰇚", "color": "#2F679D"},
    "nvim": {"name": "Neovim", "icon": "", "color": "#57A143"},
    "vim": {"name": "Vim", "icon": "", "color": "#019833"},
    "satty": {"name": "Satty", "icon": "󰹑", "color": "#EC4899"},
    "feh": {"name": "Feh", "icon": "󰋩", "color": "#A855F7"},
    "peazip": {"name": "PeaZip", "icon": "󰉋", "color": "#3B82F6"},
    "scrcpy": {"name": "Scrcpy", "icon": "󰄡", "color": "#06B6D4"},
    "btop": {"name": "btop", "icon": "󰞷", "color": "#00E5FF"},
    "libreoffice": {"name": "LibreOffice", "icon": "󰈙", "color": "#18A303"},
    "libreoffice-writer": {"name": "Writer", "icon": "󰈙", "color": "#18A303"},
    "libreoffice-calc": {"name": "Calc", "icon": "󰈙", "color": "#207245"},
    "libreoffice-impress": {"name": "Impress", "icon": "󰈙", "color": "#C93610"},
    "org.pwmt.zathura": {"name": "Zathura", "icon": "󰈦", "color": "#E06C75"},
    "obsidian": {"name": "Obsidian", "icon": "󰠮", "color": "#A855F7"},
    "slack": {"name": "Slack", "icon": "󰒱", "color": "#ECB22E"},
    "steam": {"name": "Steam", "icon": "󰓓", "color": "#171A21"},
    "zathura": {"name": "Zathura", "icon": "󰈦", "color": "#E06C75"},
    "matlab": {"name": "MATLAB", "icon": "󰈦", "color": "#E65100"},
    "mpv": {"name": "MPV", "icon": "󰕼", "color": "#A855F7"},
    "gimp": {"name": "GIMP", "icon": "󰈦", "color": "#E06C75"},
    "inkscape": {"name": "Inkscape", "icon": "󰈦", "color": "#FF7139"}
}

def format_seconds(sec):
    if sec < 60:
        return f"{sec}s"
    m = sec // 60
    if m < 60:
        return f"{m}m"
    h = m // 60
    rem_m = m % 60
    return f"{h}h {rem_m}m" if rem_m > 0 else f"{h}h"

def normalize_app_id(app_id, window_title=""):
    if not app_id:
        return None
    raw_lower = app_id.lower().strip()
    tit_lower = (window_title or "").lower().strip()

    # Detect known desktop and engineering apps
    if "xflr" in raw_lower or "xflr" in tit_lower:
        return "xflr5"
    if "freecad" in raw_lower or "freecad" in tit_lower:
        return "freecad"
    if "thunar" in raw_lower or "thunar" in tit_lower:
        return "thunar"
    if "octave" in raw_lower or "octave" in tit_lower:
        return "octave"
    if "cider" in raw_lower or "cider" in tit_lower:
        return "cider"
    if "rmpc" in raw_lower or "rmpc" in tit_lower:
        return "rmpc"
    if "localsend" in raw_lower or "localsend" in tit_lower:
        return "localsend"
    if "sunshine" in raw_lower or "sunshine" in tit_lower:
        return "sunshine"
    if "qbittorrent" in raw_lower or "qbittorrent" in tit_lower:
        return "qbittorrent"
    if "pavucontrol" in raw_lower or "volume control" in tit_lower:
        return "pavucontrol"
    if "helvum" in raw_lower or "helvum" in tit_lower:
        return "helvum"
    if "zathura" in raw_lower:
        return "zathura"
    if "satty" in raw_lower:
        return "satty"
    if "scrcpy" in raw_lower:
        return "scrcpy"
    if "peazip" in raw_lower:
        return "peazip"
    if "writer" in tit_lower or "libreoffice-writer" in raw_lower:
        return "libreoffice-writer"
    if "calc" in tit_lower or "libreoffice-calc" in raw_lower:
        return "libreoffice-calc"
    if "libreoffice" in raw_lower:
        return "libreoffice"

    # Detect known web PWAs from title or class
    if "todoist" in raw_lower or "todoist" in tit_lower:
        return "todoist"
    if "notion" in raw_lower or "notion" in tit_lower:
        return "notion"
    if "youtube" in tit_lower:
        return "youtube"
    if "github" in tit_lower:
        return "github"
    if "chatgpt" in tit_lower:
        return "chatgpt"
    if "claude" in tit_lower:
        return "claude"
    if "gmail" in tit_lower or "mail" in tit_lower:
        return "gmail"

    # Normalize browser main processes
    if raw_lower.startswith("brave-") or raw_lower == "brave":
        # Check if it was a PWA with a clean title
        if window_title and not window_title.endswith("- Brave") and len(window_title) < 30:
            return window_title.strip()
        return "brave-browser"
    if raw_lower.startswith("google-chrome-") or raw_lower.startswith("chrome-") or raw_lower == "chrome":
        if window_title and not window_title.endswith("- Google Chrome") and len(window_title) < 30:
            return window_title.strip()
        return "google-chrome"
    if raw_lower.startswith("chromium-") or raw_lower == "chromium":
        return "chromium"

    # Strip any long extension/PWA hashes (e.g. crx_...)
    clean_id = re.sub(r"-[a-p0-9]{16,}", "", raw_lower)
    clean_id = re.sub(r"^crx_[a-p0-9]+", "chrome-app", clean_id)
    return clean_id

def is_screen_locked_or_asleep():
    # 1. Quickshell lock triggers in runtime dir or /tmp
    runtime_dir = os.environ.get("XDG_RUNTIME_DIR") or "/tmp"
    lock_trigger = os.path.join(runtime_dir, "ricelin-lock-trigger")
    unlock_trigger = os.path.join(runtime_dir, "ricelin-unlock-trigger")
    if os.path.exists(lock_trigger):
        try:
            lock_mtime = os.path.getmtime(lock_trigger)
            unlock_mtime = os.path.getmtime(unlock_trigger) if os.path.exists(unlock_trigger) else 0
            if lock_mtime > unlock_mtime:
                return True
        except Exception:
            pass

    # 2. Check running screenlock processes
    try:
        res = subprocess.run(["pgrep", "-x", "hyprlock|swaylock|i3lock|waylock|gtklock"], capture_output=True)
        if res.returncode == 0:
            return True
    except Exception:
        pass

    # 3. Check Hyprland monitors DPMS status (screen off/sleep)
    try:
        res = subprocess.run(["hyprctl", "monitors", "-j"], capture_output=True, text=True, timeout=1.2)
        if res.returncode == 0 and res.stdout.strip():
            monitors = json.loads(res.stdout)
            if isinstance(monitors, list) and len(monitors) > 0:
                active_monitors = [m for m in monitors if not m.get("disabled", False)]
                if active_monitors and not any(m.get("dpmsStatus", True) for m in active_monitors):
                    return True
    except Exception:
        pass

    # 4. Check loginctl LockedHint
    try:
        res = subprocess.run(["loginctl", "show-session", "self", "-p", "LockedHint"], capture_output=True, text=True, timeout=1.0)
        if res.returncode == 0 and "LockedHint=yes" in res.stdout:
            return True
    except Exception:
        pass

    return False

def get_active_window():
    if is_screen_locked_or_asleep():
        return None
    try:
        res = subprocess.run(["hyprctl", "activewindow", "-j"], capture_output=True, text=True, timeout=1.5)
        if res.returncode == 0 and res.stdout.strip():
            data = json.loads(res.stdout)
            if not data.get("mapped", True) or data.get("hidden", False):
                return None
            raw_id = (data.get("initialClass") or data.get("class") or "").strip()
            win_title = (data.get("title") or "").strip()
            return normalize_app_id(raw_id, win_title)
    except Exception:
        pass
    return None

def load_data():
    today = datetime.now().strftime("%Y-%m-%d")
    data = {
        "date": today,
        "last_tick": int(time.time()),
        "days": {}
    }
    if DATA_FILE.exists():
        try:
            with open(DATA_FILE, "r") as f:
                loaded = json.load(f)
                if isinstance(loaded, dict):
                    if "days" in loaded and isinstance(loaded["days"], dict):
                        data["days"] = loaded["days"]
                    elif "raw_seconds" in loaded and "date" in loaded:
                        data["days"][loaded["date"]] = {"raw_seconds": loaded["raw_seconds"]}
                    data["last_tick"] = loaded.get("last_tick", int(time.time()))
        except Exception:
            pass
    
    if today not in data["days"]:
        data["days"][today] = {"raw_seconds": {}}
    data["date"] = today
    return data

def build_app_list(raw_dict):
    total_sec = sum(raw_dict.values())
    apps_list = []
    sorted_apps = sorted(raw_dict.items(), key=lambda x: x[1], reverse=True)
    for app_id, sec in sorted_apps:
        if sec <= 0:
            continue
        meta = APP_METADATA.get(app_id)
        if not meta:
            clean_name = re.sub(r"[a-p0-9]{16,}", "", app_id)
            clean_name = clean_name.replace("-", " ").replace("_", " ").strip().title()
            meta = {
                "name": clean_name if clean_name else "App",
                "icon": "󰣆",
                "color": "#94A3B8"
            }
        pct = (sec / total_sec) if total_sec > 0 else 0.0
        apps_list.append({
            "id": app_id,
            "name": meta["name"],
            "icon": meta["icon"],
            "color": meta["color"],
            "seconds": sec,
            "formatted": format_seconds(sec),
            "pct": round(pct, 3)
        })
    return total_sec, apps_list

def save_data(data):
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    today = data.get("date", datetime.now().strftime("%Y-%m-%d"))
    days = data.get("days", {})

    # Prune days older than 14 days
    all_dates = sorted(days.keys())
    if len(all_dates) > 14:
        for old_date in all_dates[:-14]:
            days.pop(old_date, None)

    # 1. Today Stats
    today_raw = days.get(today, {}).get("raw_seconds", {})
    today_total, today_apps = build_app_list(today_raw)

    # 2. 7-Day Weekly Stats
    week_raw = {}
    for d in all_dates[-7:]:
        day_dict = days.get(d, {}).get("raw_seconds", {})
        for app_id, sec in day_dict.items():
            week_raw[app_id] = week_raw.get(app_id, 0) + sec
    week_total, week_apps = build_app_list(week_raw)

    out = {
        "date": today,
        "last_tick": data.get("last_tick", int(time.time())),
        "total_seconds": today_total,
        "total_formatted": format_seconds(today_total),
        "raw_seconds": today_raw,
        "apps": today_apps,
        "week": {
            "total_seconds": week_total,
            "total_formatted": format_seconds(week_total),
            "apps": week_apps
        },
        "days": days
    }

    with open(DATA_FILE, "w") as f:
        json.dump(out, f, indent=2)
    return out

def tick(interval=5):
    data = load_data()
    now = int(time.time())
    last_tick = data.get("last_tick", now)
    elapsed = max(1, min(60, now - last_tick))

    # If screen locked or asleep, do not accumulate active app time
    if is_screen_locked_or_asleep():
        data["last_tick"] = now
        return save_data(data)

    active_app = get_active_window()
    if active_app and active_app not in ["quickshell", "hyprland", "lockscreen"]:
        today = data["date"]
        raw = data["days"][today].setdefault("raw_seconds", {})
        raw[active_app] = raw.get(active_app, 0) + elapsed

    data["last_tick"] = now
    return save_data(data)

def main():
    if len(sys.argv) > 1 and sys.argv[1] == "--tick":
        res = tick()
        print(json.dumps(res))
    elif len(sys.argv) > 1 and sys.argv[1] == "--daemon":
        while True:
            try:
                tick(5)
            except Exception:
                pass
            time.sleep(5)
    else:
        # Default: read and output current json or tick once
        if DATA_FILE.exists():
            try:
                with open(DATA_FILE, "r") as f:
                    print(f.read())
                    return
            except Exception:
                pass
        res = tick()
        print(json.dumps(res))

if __name__ == "__main__":
    main()
