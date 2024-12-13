#!/bin/bash
playerctl pause
mpc pause-if-playing
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
    # Glitching screen lock script by xzvf
    fg="#D9E0EE"
    unlocker="#00000000"
    ring="#1E1E2E"
    wrong="#F28FAD"
    highlight="#B5E8E0"
    date="#DDB6F2"
    verify="#DDB6F2"
    ring_out="#ABE9B3"

    pngfile="/tmp/sclock.png"
    bmpfile="/tmp/sclock.bmp"
    glitchedfile="/tmp/sclock_g.bmp"
    sleep 0.5 # give time for rofi to close so it won't be captured
    # Capture screenshot using maim
    maim $pngfile

    # Convert to BMP format and rotate 90 degrees
    convert $pngfile -rotate -90 $bmpfile

    # Glitch effect loop
    for a in {1,2,4,5,10}; do
        # Glitch with sox, ensuring proper format
        sox -t raw -r 48k -e unsigned -b 8 -c 1 $bmpfile -t raw $glitchedfile trim 0 100s : echo 1 1 $((a * 2)) 0.05
        # Scale and rotate for glitch effect
        convert $glitchedfile -scale $((100 / a))% -scale $((100 * a))% -rotate 90 $bmpfile
    done

    # Add lock icon and text
    convert $bmpfile -gravity center -pointsize 200 -channel RGBA -fill '#bf616a' -annotate +0+0 "" $pngfile

    # Lock the screen with glitched image
    i3lock \
        -n \
        --force-clock \
        -i $pngfile \
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
        --time-pos="960:560" \
        --date-pos="960:630" \
        --ind-pos="960:820" \
        --greeter-pos="960:930" \
        --wrong-pos="960:970" \
        --verif-pos="960:970" \
        --date-color=$date \
        --time-color=$date \
        --greeter-color=$fg \
        --wrong-color=$wrong \
        --verif-color=$verify \
        --pointer=default \
        --refresh-rate=0 \
        --pass-media-keys \
        --pass-volume-keys

    # Clean up temporary files
    rm $pngfile $bmpfile $glitchedfile
fi
