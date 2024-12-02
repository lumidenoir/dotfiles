#!/bin/sh
feh --bg-fill ~/Pictures/wallpaper/onedark/neon.png &
xset r rate 200 50 &
~/.config/dwm/dwmrun.sh &
dunst &
picom &
battery_notifier.sh &
auto_network_switch.sh &
xrdb merge ~/dotfiles/st/xresources &
~/.config/dwm/bar.sh &
