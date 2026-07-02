#!/bin/bash

NETWORK_1="iitk-sec"
NETWORK_2="iitk-sec(Highspeed-5GHz)"
SWITCH_COOLDOWN=10
CHECK_INTERVAL=10
REASSOCIATE_INTERVAL=$((30 * 60))
FAILURE_THRESHOLD=3        # consecutive failures before switching
PING_COUNT=3               # pings per check
PING_TIMEOUT=3             # seconds per ping attempt

last_switch_time=0
last_reassociate_time=0
consecutive_failures=0     # track streak of failures

log() { echo "$(date '+%F %T') - $1"; }

get_current_network() { nmcli -t -f active,ssid dev wifi | grep '^yes' | cut -d ':' -f2; }

is_traffic_flowing() {
    # Check if bytes are actively being transferred on the wifi interface
    local iface
    iface=$(nmcli -t -f DEVICE,TYPE dev | grep ':wifi' | cut -d: -f1 | head -1)
    [[ -z "$iface" ]] && return 1

    local rx1 tx1 rx2 tx2
    rx1=$(cat /sys/class/net/"$iface"/statistics/rx_bytes 2>/dev/null)
    tx1=$(cat /sys/class/net/"$iface"/statistics/tx_bytes 2>/dev/null)
    sleep 2
    rx2=$(cat /sys/class/net/"$iface"/statistics/rx_bytes 2>/dev/null)
    tx2=$(cat /sys/class/net/"$iface"/statistics/tx_bytes 2>/dev/null)

    local delta=$(( (rx2 - rx1) + (tx2 - tx1) ))
    log "Traffic delta: $delta bytes/2s"
    (( delta > 10240 ))  # >10KB/2s = active transfer, don't switch
}

check_connection() {
    ping -c "$PING_COUNT" -W "$PING_TIMEOUT" iitk.ac.in >/dev/null 2>&1
}

switch_network() {
    local now=$(date +%s)
    (( now - last_switch_time < SWITCH_COOLDOWN )) && {
        log "Cooldown active, skipping switch"
        return
    }

    local current
    current=$(get_current_network)
    local target
    target=$([[ "$current" == "$NETWORK_1" ]] && echo "$NETWORK_2" || echo "$NETWORK_1")

    log "Switching: $current → $target"
    if nmcli con up "$target" &>/dev/null; then
        last_switch_time=$now
        consecutive_failures=0
        log "Switched to $target"
        notify-send -u low "Network Monitor" "Connected to $target" -t 1000
    else
        log "Failed to connect to $target"
        notify-send -u normal "Network Error" "Failed to connect to $target. Retrying soon." -t 1000
    fi
}

reassociate_network() {
    local now=$(date +%s)
    local current
    current=$(get_current_network)
    [[ -z "$current" ]] && return
    (( now - last_reassociate_time < REASSOCIATE_INTERVAL )) && return

    log "Proactive re-association on $current"
    if nmcli con up "$current" &>/dev/null; then
        notify-send -u low "Network Monitor" "Connection refreshed: $current" -t 1000
        last_reassociate_time=$now
        log "Reassociated with $current"
    else
        notify-send -u normal "Network Warning" "Refresh failed for $current" -t 1000
        log "Failed to reassociate with $current"
    fi
}

monitor_loop() {
    while true; do
        reassociate_network

        if ! check_connection; then
            (( consecutive_failures++ ))
            log "Ping failed (streak: $consecutive_failures/$FAILURE_THRESHOLD)"

            if (( consecutive_failures >= FAILURE_THRESHOLD )); then
                # Final guard: don't switch if data is actively flowing
                if is_traffic_flowing; then
                    log "Traffic still flowing despite ping failures — skipping switch (load-induced latency?)"
                    consecutive_failures=0
                else
                    log "Connection genuinely lost, switching networks..."
                    notify-send -u critical "Network Lost" \
                        "Internet unreachable after $FAILURE_THRESHOLD checks. Switching..." -t 2000
                    switch_network
                fi
            else
                log "Waiting for more failures before switching..."
            fi
        else
            if (( consecutive_failures > 0 )); then
                log "Connection recovered after $consecutive_failures failure(s)"
                consecutive_failures=0
            fi
        fi

        sleep $CHECK_INTERVAL
    done
}

trap "log 'Exiting...'; exit 0" SIGINT SIGTERM
log "Wi-Fi monitor started — checks every ${CHECK_INTERVAL}s, switches after ${FAILURE_THRESHOLD} consecutive failures, reassociates every 30m"
notify-send -u normal "Network Monitor" "Wi-Fi monitoring service started." -t 1000
monitor_loop
