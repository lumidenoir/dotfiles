#!/bin/sh
picom --corner-radius 12 &
killall -q polybar
polybar main -c ~/.config/polybar/gruvbox.ini &
killall -q dunst
dunst -startup_notification &
mpd &
mpDris2 &
pgrep -f auto_network_switch.sh >/dev/null || auto_network_switch.sh &
pgrep -f battery_notifier.sh >/dev/null || battery_notifier.sh &
pidof -q polkit-gnome-authentication-agent-1 || { /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 & }
