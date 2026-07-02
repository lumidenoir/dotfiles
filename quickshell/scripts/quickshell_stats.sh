#!/usr/bin/env bash

# Consolidated statistics collector for Quickshell
# Loops every 5 seconds, querying metrics using bash built-ins (no fork) where possible.

prev_total=0
prev_idle=0
cache_file="$HOME/.cache/$(whoami)/redshift_state"
emails_json='{"today_count":0,"latest":[]}'
loop_count=0

# Trap signals to clean up background processes on exit
cleanup() {
    if [ -n "$sleep_pid" ]; then
        kill "$sleep_pid" 2>/dev/null
    fi
    exit 0
}
trap cleanup SIGINT SIGTERM EXIT

# Trap USR1 signal to instantly trigger stats updates
trap ":" USR1

while true; do
    # --- CPU and RAM ---
    if read -r _ u n s id io ir so st _ < /proc/stat 2>/dev/null; then
        total=$((u+n+s+id+io+ir+so+st))
        idle=$((id+io))
        if [ "$prev_total" -gt 0 ]; then
            diff_total=$((total-prev_total))
            diff_idle=$((idle-prev_idle))
            cpu=$((100*(diff_total-diff_idle)/diff_total))
        else
            cpu=0
        fi
        prev_total=$total
        prev_idle=$idle
    else
        cpu=0
    fi

    t_mem=0
    a_mem=0
    while IFS= read -r line; do
        if [[ $line =~ ^MemTotal:[[:space:]]*([0-9]+) ]]; then
            t_mem=${BASH_REMATCH[1]}
        elif [[ $line =~ ^MemAvailable:[[:space:]]*([0-9]+) ]]; then
            a_mem=${BASH_REMATCH[1]}
        fi
    done < /proc/meminfo
    if [ "$t_mem" -gt 0 ]; then
        ram=$((100*(t_mem-a_mem)/t_mem))
    else
        ram=0
    fi

    # --- Battery ---
    if [ -f /sys/class/power_supply/BAT0/capacity ]; then
        read -r cap < /sys/class/power_supply/BAT0/capacity
    else
        cap=100
    fi
    if [ "$cap" -gt 100 ]; then
        cap=100
    fi

    if [ -f /sys/class/power_supply/BAT0/status ]; then
        read -r status < /sys/class/power_supply/BAT0/status
    else
        status="Unknown"
    fi

    if [ -f /sys/class/power_supply/AC0/online ]; then
        read -r online < /sys/class/power_supply/AC0/online
    else
        online=0
    fi

    if [ "$online" -eq 1 ]; then
        charging=true
    else
        charging=false
    fi

    time_str=""
    if command -v acpi >/dev/null 2>&1; then
        acpi_out=$(acpi -b 2>/dev/null | head -n1)
        if [ -n "$acpi_out" ]; then
            if echo "$acpi_out" | grep -q "until charged"; then
                t=$(echo "$acpi_out" | grep -oP '\d{2}:\d{2}:\d{2}')
                if [ -n "$t" ]; then
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
                if [ -n "$t" ]; then
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
        fi
    fi

    if [ "$cap" -eq 100 ] || [ "$status" = "Full" ]; then
        time_str="Full"
    fi

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

    # --- Brightness ---
    if [ -f /sys/class/backlight/intel_backlight/brightness ] && [ -f /sys/class/backlight/intel_backlight/max_brightness ]; then
        read -r b_val < /sys/class/backlight/intel_backlight/brightness
        read -r b_max < /sys/class/backlight/intel_backlight/max_brightness
        brightness=$(( 100 * b_val / b_max ))
    else
        brightness=0
    fi

    # --- Power Draw ---
    if [ -f /sys/class/power_supply/BAT0/power_now ]; then
        read -r p_now < /sys/class/power_supply/BAT0/power_now
        if [ "$p_now" -ge 1000000 ]; then
            integer=$(( p_now / 1000000 ))
            fraction=$(( (p_now % 1000000) / 100000 ))
            power_draw="${integer}.${fraction}"
        else
            fraction=$(( p_now / 100000 ))
            power_draw="0.${fraction}"
        fi
    else
        power_draw="0.0"
    fi

    # --- Temperature ---
    if [ -f /sys/class/thermal/thermal_zone0/temp ]; then
        read -r temp_raw < /sys/class/thermal/thermal_zone0/temp
        temperature=$(( temp_raw / 1000 ))
    else
        temperature=0
    fi

    # --- Bluetooth ---
    bt_info=$(bluetoothctl show 2>/dev/null)
    if echo "$bt_info" | grep -q 'Powered: yes'; then
        bt_status="on"
        bt_device=$(bluetoothctl devices Connected 2>/dev/null | head -n1 | cut -d' ' -f3-)
    else
        bt_status="off"
        bt_device=""
    fi

    # --- Wifi ---
    wifi_radio=$(nmcli radio wifi 2>/dev/null)
    if [ "$wifi_radio" = "enabled" ]; then
        wifi_enabled=true
        wifi_conn=$(LC_ALL=C nmcli -t -f active,ssid,signal dev wifi 2>/dev/null | grep '^yes' | head -n1)
        if [ -n "$wifi_conn" ]; then
            sig_str="${wifi_conn##*:}"
            ssid_part="${wifi_conn#yes:}"
            wifi_ssid="${ssid_part%:$sig_str}"
            wifi_strength="$sig_str"
            wifi_ip=$(ip route get 1.1.1.1 2>/dev/null | grep -oP 'src \K\S+')
            [ -z "$wifi_ip" ] && wifi_ip=$(ip -o -4 addr show | grep -v '127.0.0.1' | awk '{print $4}' | cut -d/ -f1 | head -n1)
        else
            wifi_ssid=""
            wifi_strength="0"
            wifi_ip=""
        fi
    else
        wifi_enabled=false
        wifi_ssid=""
        wifi_strength="0"
        wifi_ip=""
    fi

    # --- Redshift ---
    if [ -f "$cache_file" ]; then
        read -r redshift_state < "$cache_file"
    else
        redshift_state="off"
    fi
    if [ "$redshift_state" = "on" ]; then
        redshift_active=true
    else
        redshift_active=false
    fi

    # --- Caffeine ---
    if pgrep -x hypridle >/dev/null 2>&1; then
        caffeine_active=false
    else
        caffeine_active=true
    fi

    # --- Power Profile ---
    power_profile=$(powerprofilesctl get 2>/dev/null || echo "balanced")

    # --- Escape string variables for JSON ---
    wifi_ssid=${wifi_ssid//\\/\\\\}
    wifi_ssid=${wifi_ssid//\"/\\\"}
    bt_device=${bt_device//\\/\\\\}
    bt_device=${bt_device//\"/\\\"}
    time_str=${time_str//\\/\\\\}
    time_str=${time_str//\"/\\\"}

    # --- Fetch Emails via python3 helper ---
    # Query emails every 60 seconds (every 12 loops of 5s) or on startup
    if [ "$loop_count" -eq 0 ] || [ $((loop_count % 720)) -eq 0 ]; then
        emails_json=$(python3 -c '
import subprocess, json
try:
    res_today = subprocess.run(["mu", "find", "date:today..now", "-q"], capture_output=True, text=True)
    today_count = len([l for l in res_today.stdout.split("\n") if l.strip()])
except Exception:
    today_count = 0

try:
    res_hour = subprocess.run(["mu", "find", "date:1h..now", "-q"], capture_output=True, text=True)
    hour_count = len([l for l in res_hour.stdout.split("\n") if l.strip()])
except Exception:
    hour_count = 0

try:
    res_latest = subprocess.run(["mu", "find", "maildir:/INBOX", "-n", "3", "-s", "date", "-z", "-o", "json"], capture_output=True, text=True)
    raw_emails = json.loads(res_latest.stdout) if res_latest.returncode == 0 else []
    emails = []
    for item in raw_emails:
        subj = item.get(":subject", "(No Subject)")
        from_list = item.get(":from", [])
        from_name = ""
        if from_list:
            from_name = from_list[0].get(":name", "")
            if not from_name:
                from_name = from_list[0].get(":email", "")
                if from_name and "@" in from_name:
                    from_name = from_name.split("@")[0]
        if not from_name:
            from_name = "Unknown"
        emails.append({"from": from_name, "subject": subj})
except Exception:
    emails = []

print(json.dumps({"today_count": today_count, "hour_count": hour_count, "latest": emails}))
' 2>/dev/null)
        if [ -z "$emails_json" ]; then
            emails_json='{"today_count":0,"hour_count":0,"latest":[]}'
        fi
    fi
    loop_count=$((loop_count + 1))

    # --- Print JSON Output ---
    printf '{"cpu":%d,"ram":%d,"battery_cap":%s,"battery_charging":%s,"battery_time":"%s","brightness":"%d%%","power_draw":"%s","temperature":"%s","bluetooth_status":"%s","bluetooth_device":"%s","wifi_enabled":%s,"wifi_ssid":"%s","wifi_strength":"%s","wifi_ip":"%s","redshift_active":%s,"caffeine_active":%s,"power_profile":"%s","emails":%s}\n' \
        "$cpu" \
        "$ram" \
        "$cap" \
        "$charging" \
        "$time_str" \
        "$brightness" \
        "$power_draw" \
        "$temperature" \
        "$bt_status" \
        "$bt_device" \
        "$wifi_enabled" \
        "$wifi_ssid" \
        "$wifi_strength" \
        "$wifi_ip" \
        "$redshift_active" \
        "$caffeine_active" \
        "$power_profile" \
        "$emails_json"

    sleep 5 &
    sleep_pid=$!
    wait "$sleep_pid"
done
