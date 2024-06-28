#!/bin/sh

feh --bg-fill ~/Pictures/wallpaper/onedark/neon.png &
xset r rate 200 50 &
dunst &
picom &
~/dotfiles/scripts/battery_notifier.sh &
xrdb merge ~/dotfiles/st/xresources &
xsettingsd &

~/.config/dwm/bar.sh &
while type dwm >/dev/null; do dwm && continue || break; done
