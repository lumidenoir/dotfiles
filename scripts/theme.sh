#!/bin/bash

# Paths
wallselect_script="${HOME}/dotfiles/scripts/WallSelect.sh"
waybar_adjust_script="${HOME}/dotfiles/scripts/waybar-detection.sh"
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

# Map wallpaper folder → bspwm theme
declare -A bspwm_theme_map=(
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

# WM-specific logic
case "$wm" in
*lg3d*)
    mapped_theme="${bspwm_theme_map[$theme_folder]}"
    echo "BSPWM Theme ${mapped_theme:-custom}"

    if [[ -n "$mapped_theme" ]]; then
        wallust theme "$mapped_theme"
        if [[ -f "$rofi_theme" ]]; then
            echo "Wallpaper patching with $theme_folder and $selected_wall"
            sed -i "s|\"$mapped_theme\"|\"$selected_wall\"|" "$rofi_theme" "$spotlight_theme"
        fi
    else
        wallust run "$selected_wall"
    fi

    polybar-msg cmd restart >/dev/null 2>&1
    restart_dunst
    ;;

*hyprland*)
    echo "Hyprland Theme, Not adjusting Waybar...(change in script)"
    # [[ -x "$waybar_adjust_script" ]] && "$waybar_adjust_script" "$selected_wall"
    wallust run "$selected_wall"
    restart_dunst
    pkill -USR2 -x waybar 2>/dev/null
    ;;

*)
    echo "Unsupported WM Wallpaper applied only"
    ;;
esac

exit 0
