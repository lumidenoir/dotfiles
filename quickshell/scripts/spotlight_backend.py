#!/usr/bin/env python3
import os
import sys
import re
import json
import subprocess
import math

BOOKMARK_FILE = os.path.expanduser("~/.cache/.bookmarks")
EMOJI_FILE = os.path.expanduser("~/dotfiles/misc/emojis.txt")
DOC_BASE = os.path.expanduser("~/org")
DOC_DIRS = ["books", "college"]
user = os.environ.get('USER', 'krishna')
MOVIE_DIRS = [
    os.path.expanduser("/mnt/shared/Movies"),
    os.path.expanduser(f"/run/media/{user}/7958-E812/movie"),
    os.path.expanduser("~/Videos"),
    os.path.expanduser("~/Movies"),
]
VIDEO_EXTS = ('.mkv', '.mp4', '.avi', '.webm', '.mov', '.m4v', '.wmv', '.flv', '.ts', '.mpg', '.mpeg')

def get_installed_apps(query=""):
    app_results = []
    try:
        import gi
        gi.require_version('Gio', '2.0')
        gi.require_version('Gtk', '3.0')
        from gi.repository import Gio, Gtk
        theme = Gtk.IconTheme.get_default()
        apps = Gio.AppInfo.get_all()
        q_lower = query.lower().strip()

        for app in apps:
            if not app.should_show():
                continue
            name = app.get_display_name() or app.get_name()
            if not name:
                continue
            desc = app.get_description() or ""
            app_id = app.get_id() or ""

            if not q_lower or q_lower in name.lower() or q_lower in desc.lower() or q_lower in app_id.lower():
                icon = app.get_icon()
                icon_path = ""
                if icon:
                    if hasattr(icon, 'get_names'):
                        names = icon.get_names()
                        icon_name = names[0] if names else ""
                    elif hasattr(icon, 'to_string'):
                        icon_name = icon.to_string()
                    else:
                        icon_name = ""
                    if icon_name:
                        if os.path.isabs(icon_name) and os.path.exists(icon_name):
                            icon_path = "file://" + icon_name
                        else:
                            info = theme.lookup_icon(icon_name, 48, 0)
                            if info:
                                icon_path = "file://" + info.get_filename()
                
                app_results.append({
                    "title": name,
                    "subtitle": desc if desc else app_id,
                    "icon": icon_path if icon_path else "󰀻",
                    "category": "Applications",
                    "action_type": "run_cmd",
                    "action_payload": f"gtk-launch {app_id}"
                })
                if len(app_results) >= 8:
                    break
    except Exception:
        pass
    return app_results

def eval_math(expr):
    clean = expr.strip().replace(" ", "").replace("^", "**")
    if not re.match(r'^[0-9+\-*/().,%eE_**|]+$', clean):
        clean = re.sub(r'\bsqrt\b', 'math.sqrt', clean)
        clean = re.sub(r'\bsin\b', 'math.sin', clean)
        clean = re.sub(r'\bcos\b', 'math.cos', clean)
        clean = re.sub(r'\btan\b', 'math.tan', clean)
        clean = re.sub(r'\blog\b', 'math.log', clean)
        clean = re.sub(r'\bpi\b', 'math.pi', clean)
        if not re.match(r'^[0-9+\-*/().,%eE_math.sqrtincolgpi ]+$', clean):
            return None

    try:
        res = eval(clean, {"__builtins__": None, "math": math})
        if isinstance(res, (int, float)):
            return f"{res:g}"
    except Exception:
        return None
    return None

def search_emojis(q="", limit=10):
    results = []
    if not os.path.exists(EMOJI_FILE):
        return results

    q_lower = q.lower().strip()
    try:
        with open(EMOJI_FILE, "r", encoding="utf-8", errors="ignore") as f:
            for line in f:
                parts = line.strip().split("\t")
                if len(parts) >= 2:
                    emoji = parts[0]
                    name = parts[3] if len(parts) > 3 else (parts[1] if len(parts) > 1 else "")
                    tags = parts[4] if len(parts) > 4 else ""
                    if not q_lower or q_lower in name.lower() or q_lower in tags.lower():
                        results.append({
                            "title": name.title(),
                            "subtitle": tags if tags else f"Copy {emoji} to clipboard",
                            "icon": emoji,
                            "category": "Emojis",
                            "action_type": "copy",
                            "action_payload": emoji
                        })
                        if len(results) >= limit:
                            break
    except Exception:
        pass
    return results

def search_library(q="", limit=10):
    results = []
    q_lower = q.lower().strip()
    for sub in DOC_DIRS:
        folder = os.path.join(DOC_BASE, sub)
        if not os.path.isdir(folder):
            continue
        for root, _, files in os.walk(folder):
            for file in files:
                if not q_lower or q_lower in file.lower():
                    icon = "󰂺" if sub == "books" else ("󰑴" if sub == "college" else "󰈙")
                    full_path = os.path.join(root, file)
                    results.append({
                        "title": file,
                        "subtitle": full_path,
                        "icon": icon,
                        "category": f"Library ({sub.capitalize()})",
                        "action_type": "open_file",
                        "action_payload": full_path
                    })
                    if len(results) >= limit:
                        return results
    return results

def search_movies(q="", limit=10):
    results = []
    q_lower = q.lower().strip()
    seen_paths = set()
    for m_dir in MOVIE_DIRS:
        if not os.path.isdir(m_dir):
            continue
        for root, _, files in os.walk(m_dir):
            for file in sorted(files):
                ext = os.path.splitext(file)[1].lower()
                if ext not in VIDEO_EXTS:
                    continue
                full_path = os.path.join(root, file)
                if full_path in seen_paths:
                    continue
                if not q_lower or q_lower in file.lower():
                    seen_paths.add(full_path)
                    results.append({
                        "title": file,
                        "subtitle": full_path,
                        "icon": "󰗚",
                        "category": "Movies",
                        "action_type": "play_media",
                        "action_payload": full_path
                    })
                    if len(results) >= limit:
                        return results
    return results

def search_bookmarks(q="", limit=8):
    results = []
    if not os.path.exists(BOOKMARK_FILE):
        return results
    q_lower = q.lower().strip()
    try:
        with open(BOOKMARK_FILE, "r", encoding="utf-8") as f:
            for line in f:
                bm = line.strip()
                if not bm:
                    continue
                if not q_lower or q_lower in bm.lower():
                    results.append({
                        "title": bm,
                        "subtitle": "Saved Bookmark",
                        "icon": "󰃁",
                        "category": "Bookmarks",
                        "action_type": "open_url",
                        "action_payload": bm
                    })
                    if len(results) >= limit:
                        break
    except Exception:
        pass
    return results

def run_spotlight_query(raw_query):
    query = raw_query.strip()

    # Default empty query: quick actions with clean titles
    if not query:
        quick_actions = [
            {"title": "Web Search", "subtitle": "Type any search term or '!w <query>'", "icon": "󰖟", "category": "Quick Actions", "action_type": "suggest", "action_payload": "!w "},
            {"title": "Library Books & Files", "subtitle": "Search college and books folder ('!l <query>')", "icon": "󱉟", "category": "Quick Actions", "action_type": "suggest", "action_payload": "!l "},
            {"title": "Movies", "subtitle": "Browse media folder ('!m <query>')", "icon": "󰗚", "category": "Quick Actions", "action_type": "suggest", "action_payload": "!m "},
            {"title": "Emoji Picker", "subtitle": "Search and copy emojis ('!e <query>')", "icon": "", "category": "Quick Actions", "action_type": "suggest", "action_payload": "!e "},
            {"title": "Screenshot Options", "subtitle": "Capture selected region or edit", "icon": "󰄀", "category": "System", "action_type": "run_cmd", "action_payload": "quickshell -p /home/krishna/dotfiles/quickshell ipc call qsIpc toggleScreenshotMenu"},
            {"title": "Screen OCR", "subtitle": "Extract text from selected region", "icon": "󰚢", "category": "System", "action_type": "run_cmd", "action_payload": "screenshot.sh --ocr"},
        ]
        bms = search_bookmarks("", limit=4)
        for itm in quick_actions + bms:
            print(json.dumps(itm), flush=True)
        return

    # 1. Prefix commands
    if query in ["!w", "!web"] or query.startswith("!w ") or query.startswith("!web "):
        term = query.split(" ", 1)[1].strip() if " " in query else ""
        if term:
            print(json.dumps({
                "title": f"Search Web for '{term}'",
                "subtitle": "DuckDuckGo Search",
                "icon": "󰖟",
                "category": "Web Search",
                "action_type": "open_url",
                "action_payload": f"https://duckduckgo.com/?q={term}"
            }), flush=True)
        for bm in search_bookmarks(term):
            print(json.dumps(bm), flush=True)
        return

    if query in ["!l", "!lib"] or query.startswith("!l ") or query.startswith("!lib "):
        term = query.split(" ", 1)[1].strip() if " " in query else ""
        for doc in search_library(term, limit=20):
            print(json.dumps(doc), flush=True)
        return

    if query in ["!m", "!movie"] or query.startswith("!m ") or query.startswith("!movie "):
        term = query.split(" ", 1)[1].strip() if " " in query else ""
        for mov in search_movies(term, limit=25):
            print(json.dumps(mov), flush=True)
        return

    if query in ["!e", "!emoji"] or query.startswith("!e ") or query.startswith("!emoji "):
        term = query.split(" ", 1)[1].strip() if " " in query else ""
        for em in search_emojis(term, limit=20):
            print(json.dumps(em), flush=True)
        return

    if query == "!ocr":
        print(json.dumps({
            "title": "Screen OCR",
            "subtitle": "Capture area and extract text",
            "icon": "󰚢",
            "category": "System Tools",
            "action_type": "run_cmd",
            "action_payload": "screenshot.sh --ocr"
        }), flush=True)
        return

    # 2. Math calculation
    calc_val = eval_math(query)
    if calc_val is not None:
        print(json.dumps({
            "title": f"= {calc_val}",
            "subtitle": f"Calculation: {query} (Press Enter to copy result)",
            "icon": "󰃬",
            "category": "Calculator",
            "action_type": "copy",
            "action_payload": str(calc_val)
        }), flush=True)

    # 3. Direct URL or Domain
    if re.match(r'^(http|www|https)', query) or re.search(r'\.(com|net|org|io|gov|edu|me|dev|sh|xyz|info|co)(/|$)', query):
        url = query
        if url.startswith("www."):
            url = "https://" + url
        elif not url.startswith("http://") and not url.startswith("https://"):
            url = "https://" + url
        print(json.dumps({
            "title": f"Open {url}",
            "subtitle": "Navigate directly in browser",
            "icon": "󰖟",
            "category": "Web Navigation",
            "action_type": "open_url",
            "action_payload": url
        }), flush=True)

    # 4. Search Applications
    for app in get_installed_apps(query):
        print(json.dumps(app), flush=True)

    # 5. Search Bookmarks
    for bm in search_bookmarks(query, limit=3):
        print(json.dumps(bm), flush=True)

    # 6. Search Library
    for doc in search_library(query, limit=3):
        print(json.dumps(doc), flush=True)

    # 7. Search Movies
    for mov in search_movies(query, limit=5):
        print(json.dumps(mov), flush=True)

    # 8. Search Mind Space
    for ms_item in search_mindspace(query, limit=3):
        print(json.dumps(ms_item), flush=True)

    # 9. Search Emojis
    for em in search_emojis(query, limit=3):
        print(json.dumps(em), flush=True)

    # 10. Web Search Fallback
    print(json.dumps({
        "title": f"Search DuckDuckGo for '{query}'",
        "subtitle": "Search web in browser",
        "icon": "󰖟",
        "category": "Web Search",
        "action_type": "open_url",
        "action_payload": f"https://duckduckgo.com/?q={query}"
    }), flush=True)

def spawn_detached(cmd):
    return subprocess.Popen(
        cmd,
        stdin=subprocess.DEVNULL,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        start_new_session=True
    )

def dispatch_via_hyprland(cmd_str):
    try:
        res = subprocess.run(
            ["hyprctl", "dispatch", f'hl.dsp.exec_cmd("{cmd_str}")'],
            capture_output=True,
            timeout=2,
            text=True
        )
        if res.returncode == 0 and "ok" in res.stdout:
            return True
    except Exception:
        pass
    return False

def execute_action(action_type, payload):
    if not action_type or not payload:
        return
    if action_type == "open_url":
        url = payload
        if not url.startswith("http://") and not url.startswith("https://"):
            url = "https://" + url
        cmd = f'systemd-run --user --scope xdg-open "{url}"'
        if not dispatch_via_hyprland(cmd):
            spawn_detached(["systemd-run", "--user", "--scope", "xdg-open", url])
    elif action_type == "copy":
        p = subprocess.Popen(["wl-copy"], stdin=subprocess.PIPE, start_new_session=True)
        p.communicate(input=payload.encode('utf-8'))
        spawn_detached(["notify-send", "-a", "Spotlight", "Copied to clipboard", payload])
    elif action_type == "open_file":
        cmd = f'systemd-run --user --scope xdg-open "{payload}"'
        if not dispatch_via_hyprland(cmd):
            spawn_detached(["systemd-run", "--user", "--scope", "xdg-open", payload])
    elif action_type == "play_media":
        spawn_detached(["mpv", payload])
    elif action_type == "run_cmd":
        if payload.startswith("quickshell"):
            cmd_to_run = payload
        elif not payload.startswith("systemd-run"):
            cmd_to_run = f"systemd-run --user --scope {payload}"
        else:
            cmd_to_run = payload

        if not dispatch_via_hyprland(cmd_to_run):
            subprocess.Popen(
                cmd_to_run,
                shell=True,
                stdin=subprocess.DEVNULL,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                start_new_session=True
            )

if __name__ == "__main__":
    if len(sys.argv) >= 4 and sys.argv[1] == "--exec":
        execute_action(sys.argv[2], sys.argv[3])
    elif len(sys.argv) >= 3 and sys.argv[1] == "--query":
        run_spotlight_query(sys.argv[2])
    elif len(sys.argv) >= 2 and sys.argv[1] == "--query":
        run_spotlight_query("")
    else:
        run_spotlight_query("")
