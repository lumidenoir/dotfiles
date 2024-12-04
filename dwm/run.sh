#!/bin/sh
feh --bg-fill ~/Pictures/wallpaper/onedark/neon.png &
xset r rate 200 50 &
dunst &
picom &
pgrep -f auto_network_switch.sh >/dev/null || auto_network_switch.sh &
pgrep -f battery_notifier.sh >/dev/null || battery_notifier.sh &
xrdb merge ~/dotfiles/st/xresources &
~/.config/dwm/bar.sh &

while true; do
    # Log stderror to a file
    dwm 2> ~/.dwm.log
    # No error logging
    #dwm >/dev/null 2>&1
done
