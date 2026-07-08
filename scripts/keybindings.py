#!/usr/bin/env python3
import os
import subprocess
import sys

# Define the unified keybindings for each WM
# Format: { "Keybinding": "Description" }

COMMON_KEYS = {
    "Super + Return": "Terminal (kitty)",
    "Super + Space": "App Launcher (rofi)",
    "Alt + Q": "Kill Window",
    "Super + P": "Powermenu",
    "Super + L": "Screenlock",
    "Super + S": "Spotlight",
    "Super + F": "File Manager (nemo)",
    "Super + B": "Browser (firefox)",
    "Super + V": "Clipboard Manager (clipse)",
    "Super + A": "Keybindings Cheatsheet",
    "Print": "Screenshot (Full)",
    "Super + Print": "Screenshot (Area)",
    "Super + Ctrl + Print": "Stop Recording",
    "Super + [1-9]": "Switch Workspace",
    "Super + Shift + [1-9]": "Move Window to Workspace",
}

WM_SPECIFIC_KEYS = {
    "bspwm": {
        "Super + {Left,Down,Up,Right}": "Focus Window",
        "Super + Shift + {Left,Down,Up,Right}": "Swap Window",
        "Super + Alt + {Left,Down,Up,Right}": "Resize Window",
        "Super + Ctrl + {Left,Down,Up,Right}": "Preselect Direction",
        "Super + t / Shift+t": "Tiled / Pseudo-tiled",
        "Super + f / Shift+f": "Floating / Fullscreen",
        "Super + Escape": "Reload sxhkd",
        "Super + Ctrl + {q,r}": "Quit / Restart bspwm",
    },
    "qtile": {
        "Super + {Left,Down,Up,Right}": "Focus Window",
        "Super + Shift + {Left,Down,Up,Right}": "Move Window",
        "Super + Alt + {Left,Down,Up,Right}": "Resize Window",
        "Super + Tab": "Next Layout",
        "Super + Shift + r": "Restart Qtile",
        "Super + m": "Toggle Maximize",
        "Super + i": "Toggle Floating",
        "Super + grave": "Dropdown Terminal",
    },
    "hyprland": {
        "Super + {Left,Down,Up,Right}": "Focus Window",
        "Super + Shift + f": "Toggle Floating",
        "Super + f": "File Manager",
        "Super + b": "Browser",
        "Super + r": "Resize Submap",
        "Super + w": "Reload Waybar",
    },
    "mango": {
        "Super + {Left,Down,Up,Right}": "Focus Window",
        "Super + Shift + f": "Toggle Floating",
        "Super + f": "File Manager",
        "Super + b": "Browser",
        "Super + Shift + r": "Reload Config",
        "Super + Tab": "Next Layout",
    },
    "awesome": {
        "Super + {Left,Right}": "Focus Next/Prev Window",
        "Super + {Up,Down}": "Next/Prev Tag",
        "Super + f": "Toggle Fullscreen",
        "Super + m": "Toggle Maximize",
        "Super + Control + r": "Restart Awesome",
    },
    "dwm": {
        "Super + {j,k}": "Focus Stack",
        "Super + {h,l}": "Resize Master",
        "Super + f": "Toggle Fullscreen",
        "Super + b": "Toggle Bar",
        "Super + Shift + r": "Restart DWM",
        "Super + Shift + c": "Toggle Floating",
    }
}

def get_current_wm():
    # Try XDG_CURRENT_DESKTOP first
    desktop = os.environ.get("XDG_CURRENT_DESKTOP", "").lower()
    if desktop:
        if "mango" in desktop: return "mango"
        if "hyprland" in desktop: return "hyprland"
        if "awesome" in desktop: return "awesome"
        if "qtile" in desktop: return "qtile"
        if "bspwm" in desktop: return "bspwm"
    
    # Try checking processes
    try:
        output = subprocess.check_output(["ps", "-e"], text=True)
        if "bspwm" in output: return "bspwm"
        if "dwm" in output: return "dwm"
        if "awesome" in output: return "awesome"
        if "qtile" in output: return "qtile"
        if "hypr" in output: return "hyprland"
        if "mango" in output: return "mango"
    except Exception:
        pass
        
    return "unknown"

def show_keys():
    wm = get_current_wm()
    keys = COMMON_KEYS.copy()
    if wm in WM_SPECIFIC_KEYS:
        keys.update(WM_SPECIFIC_KEYS[wm])
    
    # Format for Rofi
    max_len = max(len(k) for k in keys.keys())
    output = []
    for k, v in sorted(keys.items()):
        output.append(f"{k:<{max_len + 2}} {v}")
    
    rofi_input = "\n".join(output)
    
    try:
        subprocess.run([
            "rofi", "-dmenu", 
            "-i", 
            "-p", f" {wm.upper()} Keys",
            "-theme", os.path.expanduser("~/dotfiles/rofi/hotkeys.rasi")
        ], input=rofi_input, text=True)
    except Exception as e:
        print(f"Error running rofi: {e}")
        # Fallback to simple print
        print(rofi_input)

if __name__ == "__main__":
    show_keys()