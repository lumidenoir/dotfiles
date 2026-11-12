#!/usr/bin/env python3
import gi
import json
import os
import sys
import time

gi.require_version('Gtk', '3.0')
gi.require_version('Gio', '2.0')
from gi.repository import Gio, Gtk

CACHE_FILE = os.path.expanduser("~/.cache/quickshell_app_usage.json")

def load_usage():
    if os.path.exists(CACHE_FILE):
        try:
            with open(CACHE_FILE, "r") as f:
                return json.load(f)
        except Exception:
            return {}
    return {}

def record_launch(app_id):
    if not app_id:
        return
    usage = load_usage()
    entry = usage.get(app_id, {"count": 0, "last_used": 0})
    entry["count"] = entry.get("count", 0) + 1
    entry["last_used"] = int(time.time())
    usage[app_id] = entry
    os.makedirs(os.path.dirname(CACHE_FILE), exist_ok=True)
    try:
        with open(CACHE_FILE, "w") as f:
            json.dump(usage, f, indent=2)
    except Exception as e:
        pass

def get_icon_path(theme, icon_str):
    if not icon_str:
        return ""
    # If absolute path already
    if os.path.isabs(icon_str) and os.path.exists(icon_str):
        return icon_str
    
    # Try Gtk IconTheme lookup
    info = theme.lookup_icon(icon_str, 64, 0)
    if info:
        return info.get_filename()
    
    # Strip common extension if present and try again
    base = os.path.splitext(icon_str)[0]
    if base != icon_str:
        info = theme.lookup_icon(base, 64, 0)
        if info:
            return info.get_filename()

    # Search in pixmaps as fallback
    for ext in ['.png', '.svg', '.xpm']:
        pixmap_path = os.path.join('/usr/share/pixmaps', icon_str + ext)
        if os.path.exists(pixmap_path):
            return pixmap_path
            
    return ""

def get_apps():
    theme = Gtk.IconTheme.get_default()
    fallback_icon_path = ""
    for fb_name in ["application-x-executable", "application-default-icon", "system-run"]:
        info = theme.lookup_icon(fb_name, 64, 0)
        if info:
            fallback_icon_path = info.get_filename()
            break

    usage = load_usage()
    apps = Gio.AppInfo.get_all()
    app_list = []
    
    for app in apps:
        if not app.should_show():
            continue
        
        name = app.get_display_name() or app.get_name()
        if not name:
            continue
            
        app_id = app.get_id()
        icon = app.get_icon()
        icon_str = ""
        if icon:
            if hasattr(icon, 'get_names'):
                names = icon.get_names()
                icon_str = names[0] if names else ""
            elif hasattr(icon, 'to_string'):
                icon_str = icon.to_string()
                
        icon_path = get_icon_path(theme, icon_str) or fallback_icon_path
        if icon_path and not icon_path.startswith("file://"):
            icon_url = "file://" + icon_path
        else:
            icon_url = icon_path

        app_usage = usage.get(app_id, {"count": 0, "last_used": 0})
        count = app_usage.get("count", 0)
        last_used = app_usage.get("last_used", 0)

        app_list.append({
            "name": name,
            "id": app_id,
            "icon": icon_url,
            "description": app.get_description() or "",
            "count": count,
            "last_used": last_used
        })
        
    # Sort by: usage count (descending), last used timestamp (descending), then name (ascending)
    app_list.sort(key=lambda x: (-x["count"], -x["last_used"], x["name"].lower()))
    
    for item in app_list:
        print(json.dumps(item), flush=True)

if __name__ == "__main__":
    if len(sys.argv) >= 3 and sys.argv[1] == "--record":
        record_launch(sys.argv[2])
    else:
        get_apps()
