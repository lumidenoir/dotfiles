#!/bin/sh
feh --bg-fill ~/Pictures/wallpaper/onedark/neon.png &
xset r rate 200 50 &
dunst &
picom -b &
xrdb merge ~/dotfiles/st/xresources &
~/dotfiles/dwm/bar.sh &
clipse -listen &

while true; do
    # Log stderror to a file
    ~/dotfiles/dwm/dwm 2>~/.dwm.log
    # No error logging
    #~/dotfiles/dwm/dwm >/dev/null 2>&1
done
