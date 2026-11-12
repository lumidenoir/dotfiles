#!/usr/bin/env bash

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Consolidated statistics collector for Quickshell
# Loops every 5 seconds, querying metrics using bash built-ins (no fork) where possible.

prev_total=0
prev_idle=0
prev_rx=0
prev_tx=0
prev_time=0
cache_file="$HOME/.cache/$(whoami)/redshift_state"
emails_json='{"today_count":0,"latest":[]}'
loop_count=0
bt_status="off"
bt_device=""
wifi_enabled=false
wifi_ssid=""
wifi_strength="0"
wifi_ip=""
power_profile="balanced"
cpu_thermal_zone=""

# Trap signals to clean up background processes on exit
cleanup() {
    if [ -n "$sleep_pid" ]; then
        kill "$sleep_pid" 2>/dev/null
    fi
    exit 0
}
trap cleanup SIGINT SIGTERM EXIT

# Trap USR1 signal to instantly trigger stats updates
triggered_by_signal=false
trap "triggered_by_signal=true" USR1

while true; do
    is_triggered="$triggered_by_signal"
    triggered_by_signal=false
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
    BAT_DIR=""
    for d in /sys/class/power_supply/BAT*; do
        if [ -d "$d" ]; then
            BAT_DIR="$d"
            break
        fi
    done

    has_battery=false
    if [ -n "$BAT_DIR" ]; then
        has_battery=true
        if [ -f "$BAT_DIR/capacity" ]; then
            read -r cap < "$BAT_DIR/capacity"
        else
            cap=100
        fi
        if [ -f "$BAT_DIR/status" ]; then
            read -r status < "$BAT_DIR/status"
        else
            status="Unknown"
        fi
    else
        cap=100
        status="Unknown"
    fi

    if [ "$cap" -gt 100 ]; then
        cap=100
    fi

    if [ -f /sys/class/power_supply/AC/online ]; then
        read -r online < /sys/class/power_supply/AC/online
    elif [ -f /sys/class/power_supply/AC0/online ]; then
        read -r online < /sys/class/power_supply/AC0/online
    elif [ -f /sys/class/power_supply/ADP1/online ]; then
        read -r online < /sys/class/power_supply/ADP1/online
    else
        online=0
    fi

    if [ "$online" -eq 1 ] || [ "$status" = "Charging" ]; then
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
    power_draw="0.0"
    if [ -n "$BAT_DIR" ]; then
        if [ -f "$BAT_DIR/power_now" ]; then
            read -r p_now < "$BAT_DIR/power_now"
            if [ "$p_now" -ge 1000000 ]; then
                integer=$(( p_now / 1000000 ))
                fraction=$(( (p_now % 1000000) / 100000 ))
                power_draw="${integer}.${fraction}"
            else
                fraction=$(( p_now / 100000 ))
                power_draw="0.${fraction}"
            fi
        elif [ -f "$BAT_DIR/current_now" ] && [ -f "$BAT_DIR/voltage_now" ]; then
            read -r c_now < "$BAT_DIR/current_now"
            read -r v_now < "$BAT_DIR/voltage_now"
            # power_uw = (current_now * voltage_now)
            # To avoid integer overflow in bash, divide each by 1000 first
            p_now=$(( (c_now / 1000) * (v_now / 1000) ))
            if [ "$p_now" -ge 1000000 ]; then
                integer=$(( p_now / 1000000 ))
                fraction=$(( (p_now % 1000000) / 100000 ))
                power_draw="${integer}.${fraction}"
            else
                fraction=$(( p_now / 100000 ))
                power_draw="0.${fraction}"
            fi
        fi
    fi

    # --- Temperature ---
    if [ -z "$cpu_thermal_zone" ]; then
        for zone in /sys/class/thermal/thermal_zone*; do
            type=$(cat "$zone/type" 2>/dev/null)
            if [ "$type" = "x86_pkg_temp" ] || [ "$type" = "k10temp" ] || [[ "$type" == *"cpu"* ]] || [ "$type" = "cpu-thermal" ]; then
                cpu_thermal_zone="$zone"
                break
            fi
        done
        [ -z "$cpu_thermal_zone" ] && cpu_thermal_zone="/sys/class/thermal/thermal_zone0"
    fi

    if [ -f "$cpu_thermal_zone/temp" ]; then
        read -r temp_raw < "$cpu_thermal_zone/temp"
        temperature=$(( temp_raw / 1000 ))
    else
        temperature=0
    fi

    # --- Bluetooth, Wifi & Power Profile (heavy checks, run every 15s or on trigger) ---
    if [ "$loop_count" -eq 0 ] || [ $((loop_count % 3)) -eq 0 ] || [ "$is_triggered" = "true" ]; then
        # --- Bluetooth ---
        bt_present=false
        bt_status="off"
        bt_device=""
        if command -v bluetoothctl >/dev/null 2>&1; then
            bt_info=$(timeout 2 bluetoothctl show 2>/dev/null)
            if [ -n "$bt_info" ] && ! echo "$bt_info" | grep -q "No default controller available"; then
                bt_present=true
                if echo "$bt_info" | grep -q 'Powered: yes'; then
                    bt_status="on"
                    bt_device=$(timeout 2 bluetoothctl devices Connected 2>/dev/null | head -n1 | cut -d' ' -f3-)
                fi
            fi
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

        # --- Power Profile ---
        power_profile=$(powerprofilesctl get 2>/dev/null || echo "balanced")
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

    # --- Audiophile Mode ---
    if mpc outputs 2>/dev/null | grep -A 2 "FiiO" | grep -q "enabled"; then
        audiophile_active=true
    else
        audiophile_active=false
    fi

    # --- Disk Usage ---
    disk_usage=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//' 2>/dev/null || echo 0)

    # --- Ethernet ---
    ethernet_connected=false
    for eth in /sys/class/net/e*; do
        if [ -f "$eth/carrier" ] && [ "$(cat "$eth/carrier" 2>/dev/null)" = "1" ]; then
            ethernet_connected=true
            break
        fi
    done

    # --- Network Speed ---
    rx=0
    tx=0
    while read -r line; do
        [[ "$line" =~ : ]] || continue
        iface=$(echo "$line" | cut -d: -f1 | tr -d ' ')
        if [ "$iface" != "lo" ] && [[ ! "$iface" =~ ^(docker|br-|veth|anycast) ]]; then
            stats=$(echo "$line" | cut -d: -f2)
            read -r r_bytes _ _ _ _ _ _ _ t_bytes _ <<< "$stats"
            rx=$((rx + r_bytes))
            tx=$((tx + t_bytes))
        fi
    done < /proc/net/dev

    if [ "$prev_rx" -gt 0 ] 2>/dev/null; then
        now_time=$(date +%s)
        time_diff=$((now_time - prev_time))
        if [ "$time_diff" -le 0 ]; then
            time_diff=5
        fi
        speed_rx=$(( (rx - prev_rx) / time_diff ))
        speed_tx=$(( (tx - prev_tx) / time_diff ))
    else
        speed_rx=0
        speed_tx=0
        now_time=$(date +%s)
    fi
    prev_rx=$rx
    prev_tx=$tx
    prev_time=$now_time

    if [ "$speed_rx" -lt 1024 ]; then
        network_down="${speed_rx} B/s"
    elif [ "$speed_rx" -lt 1048576 ]; then
        network_down="$((speed_rx / 1024)) K/s"
    else
        mb=$((speed_rx / 1048576))
        frac=$(( (speed_rx % 1048576) / 104857 ))
        network_down="${mb}.${frac} M/s"
    fi

    if [ "$speed_tx" -lt 1024 ]; then
        network_up="${speed_tx} B/s"
    elif [ "$speed_tx" -lt 1048576 ]; then
        network_up="$((speed_tx / 1024)) K/s"
    else
        mb=$((speed_tx / 1048576))
        frac=$(( (speed_tx % 1048576) / 104857 ))
        network_up="${mb}.${frac} M/s"
    fi

    # --- Escape string variables for JSON ---
    wifi_ssid=${wifi_ssid//\\/\\\\}
    wifi_ssid=${wifi_ssid//\"/\\\"}
    bt_device=${bt_device//\\/\\\\}
    bt_device=${bt_device//\"/\\\"}
    time_str=${time_str//\\/\\\\}
    time_str=${time_str//\"/\\\"}

    # --- Fetch Emails via python3 helper ---
    emails_json=$(python3 "$SCRIPT_DIR/emails_today.py" --json 2>/dev/null || echo '{"today_count":0,"hour_count":0,"latest":[]}')
    loop_count=$((loop_count + 1))

    # --- Print JSON Output ---
    printf '{"cpu":%d,"ram":%d,"has_battery":%s,"battery_cap":%s,"battery_charging":%s,"battery_time":"%s","brightness":"%d%%","power_draw":"%s","temperature":"%s","bluetooth_status":"%s","bluetooth_device":"%s","bluetooth_present":%s,"wifi_enabled":%s,"wifi_ssid":"%s","wifi_strength":"%s","wifi_ip":"%s","ethernet_connected":%s,"network_down":"%s","network_up":"%s","redshift_active":%s,"caffeine_active":%s,"audiophile_active":%s,"power_profile":"%s","disk_usage":%d,"emails":%s}\n' \
        "$cpu" \
        "$ram" \
        "$has_battery" \
        "$cap" \
        "$charging" \
        "$time_str" \
        "$brightness" \
        "$power_draw" \
        "$temperature" \
        "$bt_status" \
        "$bt_device" \
        "$bt_present" \
        "$wifi_enabled" \
        "$wifi_ssid" \
        "$wifi_strength" \
        "$wifi_ip" \
        "$ethernet_connected" \
        "$network_down" \
        "$network_up" \
        "$redshift_active" \
        "$caffeine_active" \
        "$audiophile_active" \
        "$power_profile" \
        "$disk_usage" \
        "$emails_json"

    sleep 5 &
    sleep_pid=$!
    wait "$sleep_pid"
done
