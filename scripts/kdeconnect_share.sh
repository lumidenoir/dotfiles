#!/usr/bin/env bash
# QuickShell KDE Connect Share Helper
# Dispatches shared files or text to all currently reachable paired devices.

mode="$1"
shift

devices=$(kdeconnect-cli -a --id-only 2>/dev/null)

if [ -z "$devices" ]; then
    # Fallback to any paired device if -a didn't catch it
    devices=$(kdeconnect-cli -l --id-only 2>/dev/null | head -n1)
fi

if [ -z "$devices" ]; then
    notify-send -u critical "KDE Connect" "No paired device found to share with."
    exit 1
fi

for dev in $devices; do
    if [ "$mode" = "--text" ]; then
        kdeconnect-cli -d "$dev" --share-text "$*"
    else
        for file in "$@"; do
            kdeconnect-cli -d "$dev" --share "$file"
        done
    fi
done
