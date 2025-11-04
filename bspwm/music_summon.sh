#!/bin/zsh
mpd
st -e ncmpcpp &
sleep 2
bspc node -p south & bspc node -o 0.7
st -e cava &
