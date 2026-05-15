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
    [gruvbox]="Gruvbox-Material-Dark"
    [nord]="base16-nord"
    [onedark]="base16-onedark"
    [rosepine]="Rosé-Pine"
    [everforest]="Everforest-Dark-Medium"
    [catppuccin]="Catppuccin-Mocha"
    [tokyonight]="Tokyo-Night"
    [kanagawa]="Kanagawa-Wave"
)

# Run WallSelect and get wallpaper
"$wallselect_script"
selected_wall=$(cat ~/.cache/wallpaper 2>/dev/null)
[[ -z "$selected_wall" ]] && exit 0

theme_folder=$(basename "$(dirname "$selected_wall")")

restart_dunst() {
    pkill -x dunst
    dunst &
}

mapped_theme="${theme_map[$theme_folder]}"

if [[ -n "$mapped_theme" ]]; then
    echo "Applying mapped theme: $mapped_theme"
    wallust theme "$mapped_theme"
else
    echo "No map found, generating colors from image"
    wallust run "$selected_wall"
fi

exit 0
