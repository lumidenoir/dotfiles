"""
Minimo Brain Suite - Deep System Context & Telemetry Provider
Provides real-time situational awareness: Hyprland focus, hardware stats,
media playback, clipboard, and ambient environment.
"""

import os
import re
import json
import time
import subprocess
import psutil
from typing import Dict, Any, Optional

USER = os.environ.get('USER', 'krishna')

def get_hyprland_context() -> Dict[str, Any]:
    """Retrieve active window and workspace from Hyprland via hyprctl IPC."""
    out = {
        "active_window": {
            "title": "",
            "class": "",
            "pid": None,
            "workspace": 1
        },
        "workspace": 1,
        "monitor": "DP-1"
    }
    try:
        raw_win = subprocess.check_output(["hyprctl", "activewindow", "-j"], text=True, timeout=1.0)
        win_data = json.loads(raw_win)
        if win_data:
            ws_obj = win_data.get("workspace", {})
            out["active_window"] = {
                "title": win_data.get("title", ""),
                "class": win_data.get("class", ""),
                "pid": win_data.get("pid"),
                "workspace": ws_obj.get("id", 1) if isinstance(ws_obj, dict) else ws_obj
            }
    except Exception:
        pass

    try:
        raw_ws = subprocess.check_output(["hyprctl", "activeworkspace", "-j"], text=True, timeout=1.0)
        ws_data = json.loads(raw_ws)
        if ws_data:
            out["workspace"] = ws_data.get("id", 1)
            out["monitor"] = ws_data.get("monitor", "DP-1")
    except Exception:
        pass

    return out

def get_hardware_telemetry() -> Dict[str, Any]:
    """Retrieve real-time CPU, RAM, and Disk metrics via psutil."""
    try:
        cpu = psutil.cpu_percent(interval=None)
        mem = psutil.virtual_memory()
        disk = psutil.disk_usage('/')
        
        # Check battery if available (laptops)
        battery = None
        batt = psutil.sensors_battery()
        if batt:
            battery = {
                "percent": round(batt.percent, 1),
                "power_plugged": batt.power_plugged
            }

        return {
            "cpu_percent": cpu,
            "ram_used_gb": round(mem.used / (1024 ** 3), 2),
            "ram_total_gb": round(mem.total / (1024 ** 3), 2),
            "ram_percent": mem.percent,
            "disk_free_gb": round(disk.free / (1024 ** 3), 2),
            "disk_percent": disk.percent,
            "battery": battery
        }
    except Exception as e:
        return {"error": str(e)}

def get_media_telemetry() -> Dict[str, Any]:
    """Retrieve active MPRIS playback and system audio volume."""
    media = {
        "player": "None",
        "status": "Stopped",
        "artist": "",
        "title": "",
        "volume_percent": 100
    }
    try:
        out = subprocess.check_output(
            ["playerctl", "metadata", "--format", "{{playerName}}:::{{status}}:::{{artist}}:::{{title}}"],
            text=True, stderr=subprocess.DEVNULL, timeout=1.0
        ).strip()
        if out and ":::" in out:
            parts = out.split(":::")
            media["player"] = parts[0]
            media["status"] = parts[1]
            media["artist"] = parts[2] if len(parts) > 2 else ""
            media["title"] = parts[3] if len(parts) > 3 else ""
    except Exception:
        pass

    try:
        vol_raw = subprocess.check_output(
            ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"],
            text=True, stderr=subprocess.DEVNULL, timeout=1.0
        ).strip()
        m = re.search(r'Volume:\s+([0-9\.]+)', vol_raw)
        if m:
            media["volume_percent"] = int(float(m.group(1)) * 100)
    except Exception:
        pass

    return media

def get_ambient_context() -> Dict[str, Any]:
    """Retrieve date, time, and system uptime."""
    now = time.localtime()
    uptime_seconds = time.time() - psutil.boot_time()
    hours = int(uptime_seconds // 3600)
    mins = int((uptime_seconds % 3600) // 60)

    return {
        "current_time": time.strftime("%I:%M %p", now),
        "current_date": time.strftime("%A, %B %d, %Y", now),
        "timezone": time.strftime("%Z", now),
        "uptime": f"{hours}h {mins}m"
    }

_SYS_CTX_CACHE = {"data": None, "ts": 0}

def get_full_system_context(ttl_seconds: float = 1.5) -> Dict[str, Any]:
    """Aggregate full situational telemetry with 1.5s in-memory caching."""
    now = time.time()
    if _SYS_CTX_CACHE["data"] and (now - _SYS_CTX_CACHE["ts"]) < ttl_seconds:
        return _SYS_CTX_CACHE["data"]

    ctx = {
        "desktop": get_hyprland_context(),
        "hardware": get_hardware_telemetry(),
        "media": get_media_telemetry(),
        "ambient": get_ambient_context()
    }
    _SYS_CTX_CACHE["data"] = ctx
    _SYS_CTX_CACHE["ts"] = now
    return ctx

def get_active_window_info() -> Dict[str, Any]:
    """Shortcut for focused window details on Hyprland desktop."""
    return get_hyprland_context().get("active_window", {})

def get_daily_horizon_data() -> Dict[str, Any]:
    """Gather live weather, email, tasks, f1 telemetry, and music for morning briefing."""
    horizon = {
        "weather": "21° Clear",
        "weather_city": "Kanpur",
        "weather_feels": "24°",
        "weather_desc": "Clear",
        "emails_count": 0,
        "email_samples": [],
        "tasks": [],
        "f1_race": "",
        "music": ""
    }
    # 1. Weather
    try:
        w_proc = subprocess.run(["/home/krishna/dotfiles/scripts/weather.sh", "current_temp"], capture_output=True, text=True, timeout=2.0)
        if w_proc.returncode == 0 and w_proc.stdout.strip():
            horizon["weather"] = w_proc.stdout.strip()
        w_desc = subprocess.run(["/home/krishna/dotfiles/scripts/weather.sh", "weather_desc"], capture_output=True, text=True, timeout=1.5)
        if w_desc.returncode == 0 and w_desc.stdout.strip():
            horizon["weather_desc"] = w_desc.stdout.strip()
        w_feels = subprocess.run(["/home/krishna/dotfiles/scripts/weather.sh", "feels_like"], capture_output=True, text=True, timeout=1.5)
        if w_feels.returncode == 0 and w_feels.stdout.strip():
            horizon["weather_feels"] = f"{w_feels.stdout.strip()}°"
        w_city = subprocess.run(["/home/krishna/dotfiles/scripts/weather.sh", "city"], capture_output=True, text=True, timeout=1.5)
        if w_city.returncode == 0 and w_city.stdout.strip():
            horizon["weather_city"] = w_city.stdout.strip()
    except Exception:
        pass

    # 2. Emails
    try:
        e_proc = subprocess.run(["/home/krishna/dotfiles/scripts/emails_today.py"], capture_output=True, text=True, timeout=2.0)
        if e_proc.returncode == 0 and e_proc.stdout.strip():
            e_lines = [l.strip() for l in e_proc.stdout.strip().split("\n") if l.strip()]
            horizon["emails_count"] = len(e_lines)
            for line in e_lines[:3]:
                if "|" in line:
                    sndr, subj = line.split("|", 1)
                    horizon["email_samples"].append(f"**{sndr.strip()}**: {subj.strip()}")
                else:
                    horizon["email_samples"].append(line)
    except Exception:
        pass

    # 3. Tasks
    try:
        from .tasks import get_tasks
        horizon["tasks"] = [t for t in get_tasks() if not t.get("is_completed")][:5]
    except Exception:
        pass

    # 4. F1 Telemetry
    try:
        f1_proc = subprocess.run(["/home/krishna/dotfiles/scripts/f1_checker.py", "--this-week-race"], capture_output=True, text=True, timeout=2.0)
        if f1_proc.returncode == 0 and f1_proc.stdout.strip():
            horizon["f1_race"] = f1_proc.stdout.strip().replace("|", " • ")
    except Exception:
        pass

    # 5. Media
    try:
        m = get_media_telemetry()
        if m.get("title"):
            horizon["music"] = f"{m.get('artist')} - {m.get('title')}".strip(" -")
    except Exception:
        pass

    return horizon

def format_system_context_prompt(ctx: Optional[Dict[str, Any]] = None) -> str:
    """Format situational context for system prompt injection."""
    if ctx is None:
        ctx = get_full_system_context()

    desk = ctx.get("desktop", {})
    win = desk.get("active_window", {})
    hw = ctx.get("hardware", {})
    med = ctx.get("media", {})
    amb = ctx.get("ambient", {})

    lines = [
        "### CURRENT DESKTOP & SYSTEM STATE:",
        f"- **Local Time:** {amb.get('current_date')}, {amb.get('current_time')} ({amb.get('timezone')}) · Uptime: {amb.get('uptime')}",
    ]

    if win.get("class") or win.get("title"):
        lines.append(f"- **Active Focused Window:** `{win.get('class', 'Unknown')}` — \"{win.get('title', '')}\" (Workspace {win.get('workspace', 1)})")
    
    if hw and "cpu_percent" in hw:
        lines.append(f"- **Hardware Resources:** CPU {hw.get('cpu_percent')}% · RAM {hw.get('ram_used_gb')}/{hw.get('ram_total_gb')} GB ({hw.get('ram_percent')}%) · Disk Free {hw.get('disk_free_gb')} GB")

    if med and med.get("status") in ("Playing", "Paused"):
        lines.append(f"- **Audio Playback:** [{med.get('status')}] {med.get('title')} {('by ' + med.get('artist')) if med.get('artist') else ''} (via {med.get('player')})")

    return "\n".join(lines)
