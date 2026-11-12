#!/usr/bin/env bash

# Card name in pactl/pipewire
CARD="alsa_card.usb-FiiO_RETRO_NANO_ABCDEF0123456789-00"

case "$1" in
    on)
        # 1. Enable FiiO ALSA output, disable PipeWire output in MPD
        mpc disable 1 >/dev/null 2>&1
        mpc enable 2 >/dev/null 2>&1
        # 2. Release card from PipeWire
        pactl set-card-profile "$CARD" off >/dev/null 2>&1
        ;;
    off)
        # 1. Disable FiiO ALSA output, enable PipeWire output in MPD
        mpc disable 2 >/dev/null 2>&1
        mpc enable 1 >/dev/null 2>&1
        sleep 0.5
        # 2. Restore card to PipeWire
        pactl set-card-profile "$CARD" output:analog-stereo >/dev/null 2>&1
        ;;
    status)
        # Check if FiiO ALSA output is enabled
        if mpc outputs 2>/dev/null | grep -A 2 "FiiO" | grep -q "enabled"; then
            echo "on"
        else
            echo "off"
        fi
        ;;
esac
