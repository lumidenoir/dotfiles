#!/bin/bash

# Apply wallpaper using wal
feh --bg-fill ~/Pictures/wallpaper/fog_forest_2.png &&

# Start picom
picom --config ~/.config/picom/picom.conf &
