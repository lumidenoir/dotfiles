#!/bin/bash

# Apply wallpaper using wal
feh --bg-fill ~/Pictures/wallpaper/everforest/fog_forest_2.png &

# Start picom
picom --config ~/.config/picom/picom.conf --corner-radius 12 &

# Start dunst
dunst -startup_notification &
