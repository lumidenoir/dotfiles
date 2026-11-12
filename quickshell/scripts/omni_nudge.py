#!/usr/bin/env python3
"""
Omni Nudge Daemon — Proactive In-Context Action Dispatcher
Watches Wayland clipboard events (and Kitty sockets) to trigger
micro-action pills inside Quickshell's Center Notch Dynamic Island.
"""

import sys
import os
import re
import json
import subprocess
import time

QS_DIR = os.path.expanduser("~/dotfiles/quickshell")

def trigger_nudge(title, subtitle="", icon="󰐊", action_cmd="", action_label="Open", color="#89B4FA", timeout_ms=8000, category="NOW NUDGE"):
    payload = {
        "title": title,
        "subtitle": subtitle,
        "icon": icon,
        "action_cmd": action_cmd,
        "action_label": action_label,
        "color": color,
        "timeout_ms": timeout_ms,
        "category": category
    }
    payload_str = json.dumps(payload)
    # 1. Output to stdout (consumed instantly by Quickshell Process runner)
    print(payload_str, flush=True)

    # 2. If executed from standalone or sub-call, also try IPC directly
    if not sys.stdout.isatty():
        cmd = ["quickshell", "-p", QS_DIR, "ipc", "call", "qsIpc", "showNudge", payload_str]
        try:
            subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        except Exception:
            pass

last_clipboard_nudged = {}

def evaluate_clip(text):
    if not text:
        return
    text = text.strip()
    if len(text) < 3 or len(text) > 4000:
        return

    now = time.time()
    clip_hash = hash(text)
    if now - last_clipboard_nudged.get(clip_hash, 0) < 180:
        return
    last_clipboard_nudged[clip_hash] = now

    # ── 1. Video / Streaming Media URLs ────────────────────────────────────────
    # Matches YouTube, Twitch, Vimeo, direct video streams
    video_patterns = [
        r'^(https?:\/\/(?:www\.)?(?:youtube\.com\/watch\?v=|youtu\.be\/|youtube\.com\/shorts\/)[^\s&]+)',
        r'^(https?:\/\/(?:www\.)?twitch\.tv\/[^\s\/]+)',
        r'^(https?:\/\/(?:www\.)?vimeo\.com\/\d+)',
        r'^(https?:\/\/[^\s]+\.(mp4|mkv|webm|mov))'
    ]
    for pat in video_patterns:
        m = re.match(pat, text)
        if m:
            url = m.group(1)
            trigger_nudge(
                title="Stream Media in MPV",
                subtitle=url[:42] + ("..." if len(url) > 42 else ""),
                icon="󰐊",
                action_cmd=f'mpv "{url}" >/dev/null 2>&1 &',
                action_label="Stream",
                color="#EA6962",
                timeout_ms=9000,
                category="STREAM"
            )
            return

    # ── 2. Git Clone URLs ───────────────────────────────────────────────────────
    if (text.startswith("git@github.com:") or text.startswith("git@gitlab.com:") or 
       ((text.startswith("https://github.com/") or text.startswith("https://gitlab.com/")) and text.endswith(".git"))):
        repo_name = text.split("/")[-1].replace(".git", "")
        trigger_nudge(
            title="Git Repository URL",
            subtitle=f"Clone {repo_name} to ~/Projects",
            icon="󰊢",
            action_cmd=f'mkdir -p ~/Projects && git -C ~/Projects clone "{text}" && notify-send "Cloned {repo_name} to ~/Projects"',
            action_label="Clone",
            color="#A9B665",
            timeout_ms=9000,
            category="GIT"
        )
        return

    # ── 3. Hex Color Codes ──────────────────────────────────────────────────────
    hex_match = re.match(r'^#([0-9a-fA-F]{6}|[0-9a-fA-F]{3})$', text)
    if hex_match:
        hex_val = text.lstrip("#")
        if len(hex_val) == 3:
            hex_val = "".join([c*2 for c in hex_val])
        r = int(hex_val[0:2], 16)
        g = int(hex_val[2:4], 16)
        b = int(hex_val[4:6], 16)
        rgb_str = f"rgb({r}, {g}, {b})"
        trigger_nudge(
            title=f"Color {text}",
            subtitle=rgb_str,
            icon="",
            action_cmd=f'printf "%s" "{rgb_str}" | wl-copy && notify-send "Copied RGB" "{rgb_str}"',
            action_label="Copy RGB",
            color=text,
            timeout_ms=8000,
            category="COLOR"
        )
        return

    # ── 4. Localhost URL / Port ─────────────────────────────────────────────────
    lh_match = re.match(r'^(https?:\/\/(localhost|127\.0\.0\.1)(:\d+)?(\/[^\s]*)?)', text)
    if lh_match:
        url = lh_match.group(1)
        trigger_nudge(
            title="Local Server URL",
            subtitle=url,
            icon="󰖟",
            action_cmd=f'xdg-open "{url}" >/dev/null 2>&1 &',
            action_label="Open",
            color="#7DAEA3",
            timeout_ms=8000,
            category="DEV"
        )
        return

    # ── 5. Formattable JSON Object/Array ────────────────────────────────────────
    if (text.startswith("{") and text.endswith("}")) or (text.startswith("[") and text.endswith("]")):
        if "\n" not in text and len(text) > 15:
            try:
                parsed = json.loads(text)
                formatted = json.dumps(parsed, indent=2)
                trigger_nudge(
                    title="Minified JSON",
                    subtitle=f"{len(text)} chars • Format & Prettify",
                    icon="󰘦",
                    action_cmd=f'printf "%s" {json.dumps(formatted)} | wl-copy && notify-send "Formatted JSON copied"',
                    action_label="Prettify",
                    color="#D3869B",
                    timeout_ms=8000,
                    category="JSON"
                )
                return
            except Exception:
                pass

# ── Terminal & Hyprland Context Intelligence (Phase 3) ───────────────────────
import glob
import socket
import threading

last_git_check = {}
last_error_notified = {}

def check_terminal_status():
    """Checks active kitty window for git status and last command failures."""
    sockets = glob.glob("/tmp/kitty-*")
    if not sockets:
        return

    try:
        res = subprocess.run(["hyprctl", "activewindow", "-j"], capture_output=True, text=True, timeout=1.0)
        if res.returncode != 0 or not res.stdout.strip():
            return
        wdata = json.loads(res.stdout)
        wclass = wdata.get("class", "").lower()
        if "kitty" not in wclass:
            return
        pid = wdata.get("pid")
        if not pid:
            return
        sock_path = f"/tmp/kitty-{pid}"
        if not os.path.exists(sock_path):
            sock_path = sockets[0]
            
        ls_res = subprocess.run(["kitty", "@", "--to", f"unix:{sock_path}", "ls"], capture_output=True, text=True, timeout=1.2)
        if ls_res.returncode != 0 or not ls_res.stdout:
            return
        windows = json.loads(ls_res.stdout)
        if not windows:
            return
            
        for os_win in windows:
            for tab in os_win.get("tabs", []):
                for win in tab.get("windows", []):
                    if not win.get("is_focused"):
                        continue
                    
                    cwd = win.get("cwd", "")
                    fg_procs = win.get("foreground_processes", [])
                    if not cwd and fg_procs:
                        cwd = fg_procs[0].get("cwd", "")
                        
                    last_exit = win.get("last_cmd_exit_status", 0)
                    win_id = win.get("id")
                    
                    # 1. Check Git Status in CWD (Polite 15-minute cooldown per repo)
                    if cwd and os.path.isdir(cwd):
                        now = time.time()
                        last_t, last_count = last_git_check.get(cwd, (0, -1))
                        if now - last_t > 900: # 15 minutes
                            git_res = subprocess.run(["git", "-C", cwd, "status", "--porcelain"], capture_output=True, text=True, timeout=0.8)
                            if git_res.returncode == 0 and git_res.stdout.strip():
                                lines = git_res.stdout.strip().splitlines()
                                mod_count = len(lines)
                                repo_name = os.path.basename(cwd)
                                if mod_count != last_count or now - last_t > 1800:
                                    last_git_check[cwd] = (now, mod_count)
                                    trigger_nudge(
                                        title=f"Git: {repo_name}",
                                        subtitle=f"{mod_count} uncommitted changes",
                                        icon="󰊢",
                                        action_cmd=f'kitty @ --to unix:{sock_path} send-text "git status\\n"',
                                        action_label="Status",
                                        color="#A9B665",
                                        timeout_ms=7000,
                                        category="GIT"
                                    )
                                    return
                                
                    # 2. Check Command Failures
                    if last_exit != 0:
                        err_key = f"{sock_path}_{win_id}_{last_exit}"
                        if err_key not in last_error_notified:
                            last_error_notified[err_key] = time.time()
                            out_res = subprocess.run(["kitty", "@", "--to", f"unix:{sock_path}", "get-text", "--extent", "last_cmd_output"], capture_output=True, text=True, timeout=1.0)
                            if out_res.returncode == 0 and out_res.stdout:
                                err_text = out_res.stdout.strip()
                                m_cnf = re.search(r'(?:command not found|zsh: command not found:)\s*([a-zA-Z0-9_\-]+)', err_text)
                                if m_cnf:
                                    miss_cmd = m_cnf.group(1)
                                    trigger_nudge(
                                        title=f"Missing: '{miss_cmd}'",
                                        subtitle="Install via pacman?",
                                        icon="󰅚",
                                        action_cmd=f'kitty @ --to unix:{sock_path} send-text "sudo pacman -S {miss_cmd}\\n"',
                                        action_label="Install",
                                        color="#EA6962",
                                        timeout_ms=10000,
                                        category="TERMINAL"
                                    )
                                    return
    except Exception:
        pass

def start_hyprland_listener():
    """Listens to Hyprland socket2 for activewindow events to trigger terminal intelligence."""
    runtime = os.environ.get("XDG_RUNTIME_DIR")
    sig = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
    if not runtime or not sig:
        return
    sock_path = f"{runtime}/hypr/{sig}/.socket2.sock"
    if not os.path.exists(sock_path):
        return

    def listener_thread():
        while True:
            try:
                s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
                s.connect(sock_path)
                buf = ""
                while True:
                    data = s.recv(1024).decode("utf-8", errors="ignore")
                    if not data:
                        break
                    buf += data
                    while "\n" in buf:
                        line, buf = buf.split("\n", 1)
                        if line.startswith("activewindow>>") or line.startswith("activewindowv2>>"):
                            time.sleep(0.1) # brief settle
                            check_terminal_status()
            except Exception:
                time.sleep(2)

    t = threading.Thread(target=listener_thread, daemon=True)
    t.start()

import fcntl
import signal
import atexit

def run_watch_loop():
    """Runs wl-paste in watch mode continuously with Hyprland & Terminal intelligence."""
    # Singleton lock for daemon mode
    lock_fd = open("/tmp/omni_nudge_daemon.lock", "w")
    try:
        fcntl.flock(lock_fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except IOError:
        # Another daemon is already running; exit cleanly
        sys.exit(0)

    # Clean up any previously orphaned wl-paste watch processes
    try:
        subprocess.run(["pkill", "-f", "wl-paste --watch.*omni_nudge"], stderr=subprocess.DEVNULL)
        time.sleep(0.1)
    except Exception:
        pass

    start_hyprland_listener()
    cmd = ["wl-paste", "--watch", sys.executable, os.path.abspath(__file__), "--eval-stdin"]
    
    try:
        proc = subprocess.Popen(cmd)
    except Exception:
        return

    def cleanup(signum=None, frame=None):
        try:
            proc.terminate()
            proc.kill()
        except Exception:
            pass
        if signum is not None:
            sys.exit(0)

    atexit.register(cleanup)
    signal.signal(signal.SIGTERM, cleanup)
    signal.signal(signal.SIGINT, cleanup)
    signal.signal(signal.SIGHUP, cleanup)

    try:
        proc.wait()
    except (KeyboardInterrupt, SystemExit):
        cleanup()

if __name__ == "__main__":
    if len(sys.argv) >= 2 and sys.argv[1] == "--eval-stdin":
        clip_content = sys.stdin.read()
        evaluate_clip(clip_content)
    elif len(sys.argv) >= 3 and sys.argv[1] == "--eval":
        evaluate_clip(sys.argv[2])
    elif len(sys.argv) >= 2 and sys.argv[1] == "--check-terminal":
        check_terminal_status()
    elif len(sys.argv) >= 2 and sys.argv[1] == "--test":
        trigger_nudge(
            title="Shell Nudge Online",
            subtitle="Ambient Brain Active",
            icon="󰄬",
            action_cmd='notify-send "Shell Nudge is working!"',
            action_label="Test",
            color="#84C98F"
        )
    else:
        # Start daemon watch loop
        run_watch_loop()
