#!/usr/bin/env bash
# Hardware-aware Microphone Controller for HUD & GroundControl
# Fallback chain: PipeWire wpctl -> ALSA amixer (HDA Intel PCH ALC897)

action="${1:-get}"
value="${2:-}"

get_mic() {
    # 1. Try wpctl
    local wp_out
    wp_out=$(wpctl get-volume @DEFAULT_AUDIO_SOURCE@ 2>/dev/null)
    if [[ $? -eq 0 && -n "$wp_out" && "$wp_out" != *"Translate ID error"* ]]; then
        local vol
        vol=$(echo "$wp_out" | grep -Po '[0-9.]+' | head -1)
        local muted="false"
        if echo "$wp_out" | grep -q "\[MUTED\]"; then
            muted="true"
        fi
        local pct=$(awk -v v="$vol" 'BEGIN {printf "%d", v * 100}')
        echo "$pct|$muted"
        return 0
    fi

    # 2. Try ALSA Capture control (card 0 ALC897)
    local alsa_out
    alsa_out=$(amixer -c 0 sget Capture 2>/dev/null)
    if [[ $? -eq 0 && -n "$alsa_out" ]]; then
        local pct
        pct=$(echo "$alsa_out" | grep -Po '\[[0-9]+%\]' | head -1 | tr -d '[]%')
        local state
        state=$(echo "$alsa_out" | grep -Po '\[(on|off)\]' | head -1 | tr -d '[]')
        local muted="false"
        if [[ "$state" == "off" ]]; then
            muted="true"
        fi
        echo "${pct:-100}|$muted"
        return 0
    fi

    echo "100|false"
}

case "$action" in
    get)
        get_mic
        ;;
    set)
        if [[ -n "$value" ]]; then
            # Set wpctl
            wpctl set-volume @DEFAULT_AUDIO_SOURCE@ "$value" 2>/dev/null
            # Also set ALSA capture
            pct=$(awk -v v="$value" 'BEGIN {printf "%d", v * 100}')
            amixer -q -c 0 sset Capture "${pct}%" 2>/dev/null
        fi
        get_mic
        ;;
    toggle)
        wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle 2>/dev/null
        amixer -q -c 0 sset Capture toggle 2>/dev/null
        get_mic
        ;;
    *)
        echo "Usage: $0 {get|set <0.0-1.0>|toggle}"
        exit 1
        ;;
esac
