#!/bin/bash
mpd &
mpDris2 &
dunst -startup_notification &
pidof -q polkit-gnome-authentication-agent-1 || { /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 & }
