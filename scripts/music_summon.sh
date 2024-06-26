#!/bin/zsh
mpd
kitty --config ~/.config/kitty/tokyonight.conf -e ncmpcpp &
sleep 2
bspc node -p south & bspc node -o 0.7
kitty --config ~/.config/kitty/tokyonight.conf -o window_padding_width=0 -e cava &
