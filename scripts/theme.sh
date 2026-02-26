#!/bin/bash

# Paths
wallselect_script="${HOME}/dotfiles/scripts/WallSelect.sh"
rofi_theme="$HOME/.config/rofi/bspwm.rasi"
spotlight_theme="$HOME/.config/rofi/spotlight.rasi"

# Dependency checks
command -v wallust >/dev/null 2>&1 || {
    notify-send "wallust not found"
    exit 1
}
[[ -x "$wallselect_script" ]] || {
    notify-send "WallSelect missing"
    exit 1
}

declare -A theme_map=(
    [gruvbox]="gruvbox"
    [nord]="base16-nord"
    [onedark]="base16-onedark"
    [rosepine]="Rosé-Pine"
    [everforest]="Everforest-Dark-Medium"
    [catppuccin]="Catppuccin-Mocha"
    [tokyonight]="Tokyo-Night"
    [kanagawa]="Kanagawa-Wave"
)

# Detect WM
wm=$(echo "$XDG_CURRENT_DESKTOP" | tr '[:upper:]' '[:lower:]' 2>/dev/null)
[[ -z "$wm" ]] && wm=$(wmctrl -m 2>/dev/null | awk '/Name:/ {print tolower($2)}')

# Run WallSelect and get wallpaper
"$wallselect_script"
selected_wall=$(cat ~/.cache/wallpaper 2>/dev/null)
[[ -z "$selected_wall" ]] && exit 0

theme_folder=$(basename "$(dirname "$selected_wall")")

# Helper functions
restart_dunst() {
    pkill -x dunst
    dunst &
}

mapped_theme="${theme_map[$theme_folder]}"

if [[ -n "$mapped_theme" ]]; then
    echo "Applying mapped theme: $mapped_theme"
    wallust theme "$mapped_theme"
    if [[ -f "$rofi_theme" ]]; then
        echo "Wallpaper patching with $theme_folder and $selected_wall"
        sed -i "s|\"$mapped_theme\"|\"$selected_wall\"|" "$rofi_theme" "$spotlight_theme"
    fi
else
    echo "No map found, generating colors from image"
    wallust run "$selected_wall"
fi

polybar-msg cmd restart >/dev/null 2>&1
restart_dunst
pkill -USR2 -x waybar 2>/dev/null
pkill -SIGUSR1 -x qtile 2>/dev/null

exit 0
