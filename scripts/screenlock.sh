#!/usr/bin/env bash
pkill rofi
if [ "$WAYLAND_DISPLAY" ]; then
    swaylock --screenshots --clock --indicator-idle-visible \
        --indicator-radius 100 \
        --indicator-thickness 7 \
        --ignore-empty-password \
        --ring-color 282c34 \
        --ring-ver-color 61afef \
        --ring-wrong-color e06c75 \
        --ring-clear-color d19a66 \
        --key-hl-color 61afef \
        --text-color abb2bf \
        --text-ver-color abb2bf \
        --text-wrong-color abb2bf \
        --text-clear-color abb2bf \
        --text-caps-lock-color d19a66 \
        --line-uses-inside \
        --inside-color 12151d \
        --inside-ver-color 12151d \
        --inside-wrong-color 12151d \
        --inside-clear-color 12151d \
        --layout-bg 12151d \
        --layout-border-color 282c34 \
        --layout-text-color abb2bf \
        --separator-color 00000000 \
        --fade-in 0.3 \
        --effect-scale 2 --effect-pixelate 20 -F
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
