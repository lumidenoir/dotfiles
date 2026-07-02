#!/usr/bin/env bash

# Fetch battery info from acpi
acpi_out=$(acpi -b 2>/dev/null | head -n1)

# Default values if acpi fails or is missing
if [ -z "$acpi_out" ]; then
    # Fallback to sysfs
    cap=$(cat /sys/class/power_supply/BAT0/capacity 2>/dev/null || echo 100)
    if [ "$cap" -gt 100 ]; then
        cap=100
    fi
    status=$(cat /sys/class/power_supply/BAT0/status 2>/dev/null || echo "Unknown")
    online=$(cat /sys/class/power_supply/AC0/online 2>/dev/null || echo 0)
    
    if [ "$status" = "Charging" ]; then
        echo "$cap|1|Charging"
    elif [ "$status" = "Full" ] || [ "$cap" -eq 100 ]; then
        echo "$cap|$online|Full"
    else
        echo "$cap|$online|Discharging"
    fi
    exit 0
fi

# Example acpi output: Battery 0: Charging, 88%, 00:16:46 until charged
# Example acpi output: Battery 0: Discharging, 88%, 01:23:45 remaining
# Example acpi output: Battery 0: Full, 100%

# Parse capacity (percentage)
cap=$(echo "$acpi_out" | grep -oP '\d+(?=%)' | head -n1)
if [ -z "$cap" ]; then
    cap=$(cat /sys/class/power_supply/BAT0/capacity 2>/dev/null)
fi
[ -z "$cap" ] && cap=100
if [ "$cap" -gt 100 ]; then
    cap=100
fi

# Parse status
status=$(echo "$acpi_out" | cut -d: -f2 | cut -d, -f1 | xargs)

# Check online status (1 if Charging or Full with AC, 0 otherwise)
online=0
if [[ "$status" == "Charging" || "$status" == "Full" ]]; then
    online=1
fi

# Check if AC adapter is online from sysfs to be absolutely sure
if [ -f /sys/class/power_supply/AC0/online ]; then
    online=$(cat /sys/class/power_supply/AC0/online 2>/dev/null)
fi

# Parse time
time_str=""
if echo "$acpi_out" | grep -q "until charged"; then
    t=$(echo "$acpi_out" | grep -oP '\d{2}:\d{2}:\d{2}')
    if [ ! -z "$t" ]; then
        h_raw=$(echo "$t" | cut -d: -f1)
        m_raw=$(echo "$t" | cut -d: -f2)
        h=$((10#$h_raw))
        m=$((10#$m_raw))
        if [ "$h" -eq 0 ]; then
            time_str="${m}m to full"
        else
            time_str="${h}h ${m}m to full"
        fi
    else
        time_str="Charging"
    fi
elif echo "$acpi_out" | grep -q "remaining"; then
    t=$(echo "$acpi_out" | grep -oP '\d{2}:\d{2}:\d{2}')
    if [ ! -z "$t" ]; then
        h_raw=$(echo "$t" | cut -d: -f1)
        m_raw=$(echo "$t" | cut -d: -f2)
        h=$((10#$h_raw))
        m=$((10#$m_raw))
        if [ "$h" -eq 0 ]; then
            time_str="${m}m left"
        else
            time_str="${h}h ${m}m left"
        fi
    else
        time_str="Discharging"
    fi
fi

# Override status if full/charging as requested: "if full and charging say its full"
if [ "$cap" -eq 100 ] || [ "$status" = "Full" ]; then
    time_str="Full"
    status="Full"
fi

# Output format: capacity|online|time_str
if [ -z "$time_str" ]; then
    if [ "$online" -eq 1 ]; then
        if [ "$cap" -eq 100 ]; then
            time_str="Full"
        else
            time_str="Charging"
        fi
    else
        time_str="Discharging"
    fi
fi

echo "$cap|$online|$time_str"
