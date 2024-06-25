#!/bin/sh

feh --bg-fill ~/Pictures/wallpaper/arch.png &
xset r rate 200 50 &
dunst &
picom &

~/.config/dwm/bar.sh &
while type dwm >/dev/null; do dwm && continue || break; done
