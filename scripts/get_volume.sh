#!/usr/bin/env bash

is_fiio_active() {
    if pgrep -x "mpd" >/dev/null; then
        if mpc outputs 2>/dev/null | grep -A 2 "FiiO" | grep -q "enabled" && mpc status 2>/dev/null | grep -q "\[playing\]"; then
            return 0
        fi
    fi
    return 1
}

if is_fiio_active; then
    # Fetch PCM volume from amixer
    vol=$(amixer -c NANO sget PCM | grep -Po '\[[0-9]+%\]' | head -1 | tr -d '[]%')
    muted=$(amixer -c NANO sget PCM | grep -Po '\[(on|off)\]' | head -1 | tr -d '[]')
    
    # Scale to 0.00 - 1.00 format (e.g. 60 -> 0.60) using pure bash
    if [[ -z "$vol" ]]; then
        val="0.00"
    elif (( vol == 100 )); then
        val="1.00"
    elif (( vol < 10 )); then
        val="0.0$vol"
    else
        val="0.$vol"
    fi
    
    if [[ "$muted" == "off" ]]; then
        echo "Volume: $val [MUTED]"
    else
        echo "Volume: $val"
    fi
else
    # Fallback to system-wide wpctl
    wpctl get-volume @DEFAULT_AUDIO_SINK@
fi
