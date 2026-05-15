#!/bin/bash
mpd &
mpDris2 &
picom -b &
dunst &
pidof -q polkit-gnome-authentication-agent-1 || { /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 & }
