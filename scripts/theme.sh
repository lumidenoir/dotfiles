#!/usr/bin/env sh
DOTFILES_PATH="$HOME/dotfiles"
CONFIG_PATH="$HOME/.config"
THEMES_PATH="$DOTFILES_PATH/themes"

KITTY_CONFIG_LINK="$CONFIG_PATH/kitty/kitty.conf"
POLYBAR_CONFIG_LINK="$CONFIG_PATH/polybar/colors.ini"
ROFI_CONFIG_LINK="$CONFIG_PATH/rofi/config.rasi"
WAYBAR_CONFIG_LINK="$CONFIG_PATH/waybar/colors.css"

apply_theme() {
  local theme_name="$1"

  if [ -z "$theme_name" ] || [ ! -d "$THEMES_PATH/$theme_name" ]; then
    echo "Error: Invalid theme name '$theme_name'."
    return 1
  fi

  echo "Applying theme: $theme_name"

  # --- Kitty ---
  local kitty_theme_file="$THEMES_PATH/$theme_name/${theme_name}.conf"
  if [ -f "$kitty_theme_file" ]; then
    echo "Symlinking Kitty config to: $kitty_theme_file"
    ln -sf "$kitty_theme_file" "$KITTY_CONFIG_LINK"
    sleep 0.5
    kill -s USR1 $(pgrep kitty)
    echo "Kitty theme updated."
  else
    echo "Warning: Kitty config file not found for theme '$theme_name'."
  fi

  # --- Polybar ---
  local polybar_theme_file="$THEMES_PATH/$theme_name/${theme_name}.ini"
  if [ -f "$polybar_theme_file" ]; then
    echo "Symlinking Polybar config to: $polybar_theme_file"
    ln -sf "$polybar_theme_file" "$POLYBAR_CONFIG_LINK"
    polybar-msg cmd restart
    echo "Polybar theme updated."
  else
    echo "Warning: Polybar config file not found for theme '$theme_name'."
  fi

  # --- Rofi ---
  local rofi_theme_file="$THEMES_PATH/$theme_name/${theme_name}.rasi"
  if [ -f "$rofi_theme_file" ]; then
    echo "Symlinking Rofi config to: $rofi_theme_file"
    ln -sf "$rofi_theme_file" "$ROFI_CONFIG_LINK"
    echo "Rofi theme updated."
  else
    echo "Warning: Rofi config file not found for theme '$theme_name'."
  fi

  # --- waybar ---
  local waybar_theme_file="$THEMES_PATH/$theme_name/${theme_name}.css"
  if [ -f "$waybar_theme_file" ]; then
    echo "Symlinking Waybar config to: $waybar_theme_file"
    ln -sf "$waybar_theme_file" "$WAYBAR_CONFIG_LINK"
    killall -s USR2 waybar
    echo "Waybar theme uploaded"
  else
    echo "Warning: Waybar config file not found for theme '$theme_name'."
  fi

  # --- Wallpaper ---
  if [ "$XDG_SESSION_TYPE" = "wayland" ]; then
    pkill swaybg
    swaybg -i "$(find "$HOME/Pictures/wallpaper/$theme_name" -type f | shuf -n 1)" -m fill &
  else
    feh --bg-scale "$(find "$HOME/Pictures/wallpaper/$theme_name" -type f | shuf -n 1)"
  fi
  echo "Theme '$theme_name' applied."
}

if [ "$1" == "--rofi" ]; then
  available_themes=$(find "$THEMES_PATH" -maxdepth 1 -mindepth 1 -type d -printf "%f\n" | sort)
  selected_theme=$(echo "$available_themes" | rofi -dmenu -p "Select Theme:")

  if [ -n "$selected_theme" ]; then
    apply_theme "$selected_theme"
  fi

elif [ -n "$1" ]; then
  apply_theme "$1"

else
  selected_theme=$(find "$THEMES_PATH" -maxdepth 1 -mindepth 1 -type d -printf "%f\n" | sort | gum choose --header "🎨 Choose a Theme:")
  if [ -n "$selected_theme" ]; then
    apply_theme "$selected_theme"
  fi
fi

exit 0
