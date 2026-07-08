#!/usr/bin/env bash

# Paths
wallselect_script="${HOME}/dotfiles/scripts/WallSelect.sh"
DOTFILES="$HOME/dotfiles"

THEME=$1

if [ -z "$THEME" ]; then
    # If in Hyprland and quickshell is running, trigger its theme switcher via IPC and exit
    if [[ "$XDG_CURRENT_DESKTOP" == "Hyprland" ]] && pgrep -x "quickshell" >/dev/null; then
        if quickshell -p "$HOME/dotfiles/quickshell" ipc call qsIpc toggleThemeSwitcher 2>/dev/null; then
            exit 0
        elif quickshell ipc call qsIpc toggleThemeSwitcher 2>/dev/null; then
            exit 0
        fi
    fi

    # Dependency check for WallSelect
    [[ -x "$wallselect_script" ]] || {
        notify-send "WallSelect missing"
        exit 1
    }

    # Run WallSelect and get wallpaper
    sleep 0.2
    "$wallselect_script"
    selected_wall=$(cat ~/.cache/wallpaper 2>/dev/null)
    [[ -z "$selected_wall" ]] && exit 0

    THEME=$(basename "$(dirname "$selected_wall")")
fi

if [ -z "$THEME" ]; then
    echo "Usage: $0 [theme-name]"
    exit 1
fi

# Check if theme exists
if [ ! -f "$DOTFILES/dwm/themes/${THEME}.h" ]; then
    echo "Theme $THEME not found."
    exit 1
fi

echo "Switching theme to $THEME..."

# Set up symlinks
ln -sf "$DOTFILES/dwm/themes/${THEME}.h" "$DOTFILES/dwm/themes/active.h"
ln -sf "$DOTFILES/rofi/themes/${THEME}.rasi" "$DOTFILES/rofi/themes/active.rasi"
ln -sf "$DOTFILES/st/themes/${THEME}.xresources" "$DOTFILES/st/themes/active.xresources"
ln -sf "$DOTFILES/dwm/bar_themes/${THEME}" "$DOTFILES/dwm/bar_themes/active"

# Extract colors from dwm theme file for Dunst
DWM_THEME_FILE="$DOTFILES/dwm/themes/${THEME}.h"

get_color() {
    grep "static const char $1\[\]" "$DWM_THEME_FILE" | grep -o '#[0-9a-fA-F]*' | head -n 1
}

bg_color=$(get_color black)
fg_color=$(get_color white)
blue_color=$(get_color blue)
red_color=$(get_color red)
yellow_color=$(get_color yellow)
green_color=$(get_color green)

# Template dunstrc
sed -e "s|@frame_color@|$blue_color|g" \
    -e "s|@highlight@|$fg_color|g" \
    -e "s|@separator_color@|$fg_color|g" \
    -e "s|@urgency_low_bg@|$bg_color|g" \
    -e "s|@urgency_low_fg@|$fg_color|g" \
    -e "s|@urgency_low_frame@|$green_color|g" \
    -e "s|@urgency_normal_bg@|$bg_color|g" \
    -e "s|@urgency_normal_fg@|$fg_color|g" \
    -e "s|@urgency_normal_frame@|$yellow_color|g" \
    -e "s|@urgency_critical_bg@|$bg_color|g" \
    -e "s|@urgency_critical_fg@|$fg_color|g" \
    -e "s|@urgency_critical_frame@|$red_color|g" \
    "$DOTFILES/dunst/dunstrc.template" > "$HOME/.config/dunst/dunstrc"


# Rebuild dwm
echo "Rebuilding dwm..."
make -C "$DOTFILES/dwm" clean > /dev/null
make -C "$DOTFILES/dwm" all > /dev/null
cp "$DOTFILES/dwm/dwm" "$HOME/.local/bin/dwm"

# Apply Xresources
echo "Applying Xresources..."
(cd "$DOTFILES/st" && xrdb -merge xresources)
kill -USR1 $(pidof st) 2>/dev/null || true

# Restart dunst
echo "Restarting dunst..."
killall dunst 2>/dev/null
dunst & disown

# Restart dwm (since it is running in a loop in run.sh, killing it will restart it)
echo "Restarting dwm..."
killall dwm 2>/dev/null

# Restart bar
echo "Restarting bar..."
killall bar.sh 2>/dev/null
~/dotfiles/dwm/bar.sh & disown

echo "Theme switched successfully!"
