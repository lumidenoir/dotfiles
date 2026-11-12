#!/usr/bin/env bash

is_fiio_active() {
    if pgrep -x "mpd" >/dev/null; then
        if mpc outputs 2>/dev/null | grep -A 2 "FiiO" | grep -q "enabled" && mpc status 2>/dev/null | grep -q "\[playing\]"; then
            return 0
        fi
    fi
    return 1
}

action="$1"

if is_fiio_active; then
    case "$action" in
        up)
            amixer -q -c NANO sset PCM 1+
            ;;
        down)
            amixer -q -c NANO sset PCM 1-
            ;;
        toggle)
            amixer -q -c NANO sset PCM toggle
            ;;
        *)
            # Handle absolute volume values (e.g. from sliders outputting decimals like 0.60)
            if [[ "$action" =~ ^[0-9.]+$ ]]; then
                # Convert decimal to ALSA DAC scale (0 to 15) using awk
                val=$(awk -v act="$action" 'BEGIN {print int(act * 15)}')
                amixer -q -c NANO sset PCM "$val"
            fi
            ;;
    esac
else
    # Fallback to system-wide wpctl controls
    case "$action" in
        up)
            wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+
            ;;
        down)
            wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
            ;;
        toggle)
            wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
            ;;
        *)
            if [[ "$action" =~ ^[0-9.]+$ ]]; then
                wpctl set-volume @DEFAULT_AUDIO_SINK@ "$action"
            fi
            ;;
    esac
fi
