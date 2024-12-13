#!/usr/bin/env bash
pkill rofi
playerctl pause
mpc pause-if-playing

if [ "$WAYLAND_DISPLAY" ]; then
        swaylock --clock --indicator-idle-visible \
                -i ~/Pictures/wallpaper/other/lockscreen.jpg \
                --font="JetBrainsMono Nerd Font" \
                --indicator-radius 120 \
                --indicator-thickness 15 \
                --indicator-x-position 1620 \
                --indicator-y-position 500 \
                --ignore-empty-password \
                --inside-color 00000000 \
                --ring-color d9e0ee \
                --inside-ver-color DDB6F2 \
                --ring-ver-color DDB6F2 \
                --ring-clear-color f28fad \
                --inside-wrong-color f28fad \
                --ring-wrong-color f28fad \
                --line-uses-inside \
                --key-hl-color 1E1E2E \
                --separator-color DDB6F2 \
                --bs-hl-color 1E1E2E \
                --text-color abb2bf \
                --text-ver-color 1e1e2e \
                --text-wrong-color 1e1e2e \
                --text-clear-color 1e1e2e \
                --text-caps-lock-color d19a66 \
                --line-uses-inside \
                --inside-color 00000000 \
                --inside-wrong-color f28fad \
                --inside-clear-color abe9b3 \
                --layout-bg-color 00000000 \
                --layout-border-color d9e0ee \
                --layout-text-color d9e0ee \
                --timestr "%H:%M" \
                --datestr "%a, %d %b" \
                --separator-color 00000000
else
        fg="#D9E0EE"
        unlocker="#00000000"
        ring="#1E1E2E"
        wrong="#F28FAD"
        highlight="#B5E8E0"
        date="#DDB6F2"
        verify="#DDB6F2"
        ring_out="#ABE9B3"

        i3lock \
                -n \
                --force-clock \
                -i ~/Pictures/wallpaper/other/lockscreen.jpg \
                -e \
                --indicator \
                --radius=40 \
                --ring-width=8 \
                --inside-color=$unlocker \
                --ring-color=$fg \
                --insidever-color=$verify \
                --ringver-color=$verify \
                --insidewrong-color=$wrong \
                --ringwrong-color=$wrong \
                --line-uses-inside \
                --keyhl-color=$ring \
                --separator-color=$verify \
                --bshl-color=$ring \
                --time-str="%H:%M" \
                --time-size=140 \
                --date-str="%a, %d %b" \
                --date-size=45 \
                --verif-text="Verifying Password..." \
                --wrong-text="Wrong Password!" \
                --noinput-text="" \
                --greeter-text="Type the password to unlock" \
                --time-font="JetBrainsMono Nerd Font" \
                --date-font="JetBrainsMono Nerd Font" \
                --verif-font="JetBrainsMono Nerd Font" \
                --greeter-font="JetBrainsMono Nerd Font" \
                --wrong-font="JetBrainsMono Nerd Font" \
                --verif-size=23 \
                --greeter-size=23 \
                --wrong-size=23 \
                --time-pos="300:560" \
                --date-pos="300:630" \
                --ind-pos="1620:520" \
                --greeter-pos="1620:630" \
                --wrong-pos="1620:670" \
                --verif-pos="1620:670" \
                --date-color=$date \
                --time-color=$date \
                --greeter-color=$fg \
                --wrong-color=$wrong \
                --verif-color=$verify \
                --pointer=default \
                --refresh-rate=0 \
                --pass-media-keys \
                --pass-volume-keys
fi
