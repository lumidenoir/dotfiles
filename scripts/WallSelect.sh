#!/bin/bash

# Check for required packages
if ! command -v xdpyinfo >/dev/null 2>&1; then
    dunstify "Missing package" "Please install the xorg-xdpyinfo package to continue" -u critical
    exit 1
elif ! command -v convert >/dev/null 2>&1; then
    dunstify "Missing package" "Please install the imagemagick package to continue" -u critical
    exit 1
fi
# Define the wallpaper directory
wallpaper_dir="${HOME}/Pictures/wallpaper"

# Get the list of theme directories
theme_dirs=($(find "$wallpaper_dir" -maxdepth 1 -mindepth 1 -type d -not -path '*/\.*' | sort))

# Extract just the folder names from the paths
theme_names=()
for dir in "${theme_dirs[@]}"; do
    theme_names+=("$(basename "$dir")")
done

# Combine predefined options and dynamic theme directories
all_themes=("${theme_options[@]}" "${theme_names[@]}")

# Get user input for wallpaper theme
theme=$(printf '%s\n' "${all_themes[@]}" | rofi -dmenu -p "Select wallpaper theme: " -lines 10 -no-custom -theme ~/.config/rofi/spotlight.rasi)

# Exit if no theme is provided
if [ -z "$theme" ]; then
    dunstify "Missing theme" "No theme was selected" -u critical -t 2000
    exit 0
fi

# Set some variables
wall_dir="${HOME}/Pictures/wallpaper/${theme}"
cacheDir="${HOME}/.cache/$(whoami)/wallpaper/${theme}"
rofi_command="rofi -dmenu -theme ${HOME}/old-dots/themes/WallSelect.rasi -theme-str ${rofi_override}"

monitor_res=$(xdpyinfo | awk '/dimensions/{print $2}' | cut -d 'x' -f1)
monitor_scale=$(xdpyinfo | awk '/resolution/{print $2}' | cut -d 'x' -f1)
monitor_res=$((monitor_res * 17 / monitor_scale))
rofi_override="element-icon{size:${monitor_res}px;border-radius:0px;}"

# Create cache dir if not exists
if [ ! -d "${cacheDir}" ]; then
    mkdir -p "${cacheDir}"
fi

# Convert images in directory and save to cache dir
for imagen in "$wall_dir"/*.{jpg,jpeg,png,webp}; do
    if [ -f "$imagen" ]; then
        nombre_archivo=$(basename "$imagen")
        if [ ! -f "${cacheDir}/${nombre_archivo}" ]; then
            convert -strip "$imagen" -thumbnail 500x500^ -gravity center -extent 500x500 "${cacheDir}/${nombre_archivo}"
        fi
    fi
done

# Launch rofi
wall_selection=$(find "${wall_dir}" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) -exec basename {} \; | sort | while read -r A; do echo -en "$A\x00icon\x1f""${cacheDir}"/"$A\n"; done | $rofi_command)

# Set wallpaper
[[ -n "$wall_selection" ]] || exit 1
wall_path="${wall_dir}/${wall_selection}"

# Apply wallpaper in background so parent script continues
if [ "$XDG_SESSION_TYPE" = "wayland" ]; then
    pkill swaybg
    (swww img -t center "$wall_path") >/dev/null 2>&1 &
else
    (feh --no-fehbg --bg-fill "$wall_path" &) >/dev/null 2>&1 &
fi

# Echo full wallpaper path BEFORE applying wallpaper
echo "$wall_path" >~/.cache/wallpaper
exit 0

# 869545069722878
