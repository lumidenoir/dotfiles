#!/bin/bash
mpd &
mpDris2 &
picom --config ~/.config/picom/picom.conf --corner-radius 12 &
dunst -startup_notification &
pidof -q polkit-gnome-authentication-agent-1 || { /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 & }
battery_notifier.sh &
auto_network_switch.sh &
