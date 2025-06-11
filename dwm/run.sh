#!/bin/sh
feh --bg-fill ~/Pictures/wallpaper/onedark/neon.png &
xset r rate 200 50 &
dunst &
picom --corner-radius 0 &
xrdb merge ~/dotfiles/st/xresources &
~/.config/dwm/bar.sh &
sudo pkill -f gnome-shell & # needed in my case

while true; do
    # Log stderror to a file
    dwm 2>~/.dwm.log
    # No error logging
    #dwm >/dev/null 2>&1
done
