#!/bin/bash

while true; do
    # Check if battery is charging
    charging=$(acpi -b | grep -c "Charging")

    # If battery is not charging and battery level is less than 15%
    if [[ "$charging" -eq 0 ]]; then
        battery_level=$(acpi -b | grep -P -o '[0-9]+(?=%)')
        if [[ "$battery_level" -lt 20 ]]; then
            dunstify -i "/usr/share/icons/Papirus-Dark/48x48/status/battery-empty.svg" -u critical -a "Battery" -t 6000 "Battery Low" "Battery level is ${battery_level}%"
        fi
    fi
    sleep 20  # Check battery level every 20 seconds
done
