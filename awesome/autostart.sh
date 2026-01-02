#!/bin/sh
picom -b &
feh --bg-fill $(cat ~/.cache/wallpaper)
killall -q polybar
polybar main -c ~/.config/polybar/awesome.ini &
killall -q dunst
dunst &
pidof -q polkit-gnome-authentication-agent-1 || { /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 & }
