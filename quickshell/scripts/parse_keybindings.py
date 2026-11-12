#!/usr/bin/env python3
import os
import re
import json

LUA_CONFIG = os.path.expanduser("~/dotfiles/hypr/.config/hypr/hyprland.lua")

def parse_keybindings():
    if not os.path.exists(LUA_CONFIG):
        return []

    with open(LUA_CONFIG, "r", encoding="utf-8") as f:
        content = f.read()

    lines = content.splitlines()

    command_desc_map = {
        "kitty -c ~/.config/kitty/mac-kitty.conf --class clipse": "Clipboard Manager (Clipse)",
        "kitty": "Terminal (Kitty)",
        "window.close": "Close Active Window",
        "fullscreen(0)": "Toggle Fullscreen",
        "fullscreen(1)": "Toggle Fake Fullscreen",
        "special:minimized": "Minimize Active Window",
        "toggleAudiophilePlayer": "Audiophile Music Player",
        "toggle_special(\"minimized\")": "Toggle Minimized Window Tray",
        "powermenu.sh": "Power / Session Menu",
        "screenlock.sh": "Lock Screen",
        "float": "Toggle Window Floating",
        "toggleAppLauncher": "Application Launcher",
        "toggleGroundControl": "Ground Control Center",
        "pseudo": "Toggle Pseudo Tiling Mode",
        "spotlight.sh": "Spotlight Global Search",
        "toggleAirspace": "Mission Control (Airspace)",
        "general:layout": "Toggle Dwindle / Master Layout",
        "toggleCheatsheet": "Keybindings Cheatsheet HUD",
        "keybindings.py": "Keybindings Cheatsheet HUD",
        "pkill quickshell": "Restart Quickshell & Lock",
        "hypridle": "Toggle Hypridle & Quickshell Stats",
        "toggle_special(\"scratchpad\")": "Toggle Scratchpad Terminal",
        "direction = \"l\"": "Focus Window Left",
        "direction = \"r\"": "Focus Window Right",
        "direction = \"u\"": "Focus Window Up",
        "direction = \"d\"": "Focus Window Down",
        "brightness_down": "Decrease Brightness",
        "brightness_up": "Increase Brightness",
        "volume_down": "Decrease Volume",
        "volume_up": "Increase Volume",
        "volume_mute": "Toggle Audio Mute",
        "play_pause": "Play / Pause Media",
        "play_prev": "Previous Track",
        "play_next": "Next Track",
        "screenshot.sh --sel": "Capture Selected Area",
        "toggleScreenshotMenu": "Open Screenshot Menu",
        "screenshot.sh --stop": "Stop Screen Recording",
        "submap(\"resize\")": "Enter Window Resize Mode",
        "drag()": "Move / Drag Window",
        "resize()": "Resize Window (Mouse)",
        "workspace = \"e+1\"": "Next Workspace (Scroll)",
        "workspace = \"e-1\"": "Previous Workspace (Scroll)",
    }

    categories = {
        "Window Management": [],
        "Launchers & Tools": [],
        "Workspaces & Navigation": [],
        "System & Media": []
    }

    def categorize(desc, raw):
        lower_desc = desc.lower()
        lower_raw = raw.lower()
        if any(x in lower_desc or x in lower_raw for x in ["volume", "brightness", "media", "mute", "screenshot", "screenlock", "lock", "power", "idle", "record", "restart"]):
            return "System & Media"
        if any(x in lower_desc or x in lower_raw for x in ["workspace", "scratchpad", "direction", "focus window", "scroll"]):
            return "Workspaces & Navigation"
        if any(x in lower_desc or x in lower_raw for x in ["launcher", "spotlight", "terminal", "kitty", "clipboard", "control", "airspace", "player", "cheatsheet"]):
            return "Launchers & Tools"
        return "Window Management"

    bind_pattern = re.compile(r'hl\.bind\(\s*([^,]+)\s*,\s*(.+?)\s*(?:,\s*\{.*?\})?\s*\)')
    main_mod = "Super"
    in_submap = False

    for i, line in enumerate(lines):
        line_clean = line.strip()
        if not line_clean or line_clean.startswith("--"):
            continue

        if "define_submap" in line_clean:
            in_submap = True
            continue
        if in_submap and line_clean == "end)":
            in_submap = False
            continue
        if in_submap:
            continue

        # Loop detection for workspaces 1-6
        if "for i = 1," in line_clean:
            categories["Workspaces & Navigation"].append({
                "keys": ["Super", "1..6"],
                "desc": "Switch to Workspace 1–6",
                "category": "Workspaces & Navigation"
            })
            categories["Workspaces & Navigation"].append({
                "keys": ["Super", "Shift", "1..6"],
                "desc": "Move Window to Workspace 1–6",
                "category": "Workspaces & Navigation"
            })
            continue

        if "tostring(i)" in line_clean:
            continue

        match = bind_pattern.search(line_clean)
        if match:
            raw_key, raw_action = match.groups()
            
            key_str = raw_key.replace("mainMod", main_mod).replace('"', '').replace("'", '').replace("..", "+").strip()
            key_str = re.sub(r'\s*\+\s*', ' + ', key_str)
            keys = [k.strip() for k in key_str.split('+') if k.strip()]
            
            friendly_keys = []
            for k in keys:
                k_upper = k.upper()
                if k_upper == "SUPER":
                    friendly_keys.append("Super")
                elif k_upper == "RETURN":
                    friendly_keys.append("↵ Enter")
                elif k_upper == "SPACE":
                    friendly_keys.append("Space")
                elif k_upper == "TAB":
                    friendly_keys.append("Tab")
                elif k_upper == "GRAVE":
                    friendly_keys.append("`")
                elif k_upper == "LEFT":
                    friendly_keys.append("←")
                elif k_upper == "RIGHT":
                    friendly_keys.append("→")
                elif k_upper == "UP":
                    friendly_keys.append("↑")
                elif k_upper == "DOWN":
                    friendly_keys.append("↓")
                elif k_upper == "PRINT":
                    friendly_keys.append("Print")
                elif "XF86MONBRIGHTNESSDOWN" in k_upper:
                    friendly_keys.append("☀ -")
                elif "XF86MONBRIGHTNESSUP" in k_upper:
                    friendly_keys.append("☀ +")
                elif "XF86AUDIOLOWERVOLUME" in k_upper or "XF86AUDIOVOLUMEDOWN" in k_upper:
                    friendly_keys.append("🔉 -")
                elif "XF86AUDIORAISEVOLUME" in k_upper or "XF86AUDIOVOLUMEUP" in k_upper:
                    friendly_keys.append("🔊 +")
                elif "XF86AUDIOMUTE" in k_upper:
                    friendly_keys.append("🔇 Mute")
                elif "XF86AUDIOPLAY" in k_upper:
                    friendly_keys.append("⏯ Play/Pause")
                elif "XF86AUDIONEXT" in k_upper:
                    friendly_keys.append("⏭ Next")
                elif "XF86AUDIOPREV" in k_upper:
                    friendly_keys.append("⏮ Prev")
                elif "MOUSE:272" in k_upper:
                    friendly_keys.append("Left Drag")
                elif "MOUSE:273" in k_upper:
                    friendly_keys.append("Right Drag")
                elif "MOUSE:SCROLL_DOWN" in k_upper:
                    friendly_keys.append("Scroll Down")
                elif "MOUSE:SCROLL_UP" in k_upper:
                    friendly_keys.append("Scroll Up")
                else:
                    friendly_keys.append(k.capitalize())

            desc = ""
            for pattern, text in command_desc_map.items():
                if pattern in raw_action:
                    desc = text
                    break
            
            if not desc:
                if i > 0 and lines[i-1].strip().startswith("--"):
                    desc = lines[i-1].strip().lstrip("-").strip()
                else:
                    desc = raw_action.replace("hl.dsp.exec_cmd(", "").replace("hl.dsp.", "").rstrip(")")
                    desc = desc.replace('"', '').replace("'", '')

            cat = categorize(desc, raw_action)
            categories[cat].append({
                "keys": friendly_keys,
                "desc": desc,
                "category": cat
            })

    category_icons = {
        "Window Management": "󱂬",
        "Launchers & Tools": "󰀻",
        "Workspaces & Navigation": "󰨇",
        "System & Media": "󰕾"
    }

    # Print line-by-line JSON for each category
    for cat_name in ["Window Management", "Launchers & Tools", "Workspaces & Navigation", "System & Media"]:
        items = categories.get(cat_name, [])
        if items:
            cat_obj = {
                "name": cat_name,
                "icon": category_icons.get(cat_name, "󰌌"),
                "items": items
            }
            print(json.dumps(cat_obj), flush=True)

if __name__ == "__main__":
    parse_keybindings()
