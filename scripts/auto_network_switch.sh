#!/bin/bash
# Why is this script written:
# Enterprise Wi-Fi sessions rely on periodic re-authentication (EAPOL handshake).
# Some APs force a rekey / session timeout (often 30–60 min).
# If the client doesn’t handle it smoothly, the connection looks alive but traffic stops until reconnect.
# My campus network seems to have a sesion timeout of ~31min hence the reassociation at 30min and a backup switch logic

NETWORK_1="iitk-sec"
NETWORK_2="iitk-sec(Highspeed-5GHz)"
SWITCH_COOLDOWN=10
CHECK_INTERVAL=10
REASSOCIATE_INTERVAL=$((30 * 60))

last_switch_time=0
last_reassociate_time=0

log() { echo "$(date '+%F %T') - $1"; }
check_connection() { ping -c2 -W1 8.8.8.8 >/dev/null 2>&1; }
get_current_network() { nmcli -t -f active,ssid dev wifi | grep '^yes' | cut -d ':' -f2; }

switch_network() {
    local now=$(date +%s)
    ((now - last_switch_time < SWITCH_COOLDOWN)) && { log "Cooldown active"; return; }
    
    local current=$(get_current_network)
    local target=$([[ "$current" == "$NETWORK_1" ]] && echo "$NETWORK_2" || echo "$NETWORK_1")
    
    log "Switching: $current → $target"
    if nmcli con up "$target" &>/dev/null; then
        last_switch_time=$now
        log "Switched to $target"
        notify-send -u low "Network Assisst" "Connected to $target" -t 1500
    else
        log "Failed to connect to $target"
        notify-send -u normal "Network Assisst" "Failed to connect $target" -t 1500
    fi
}

reassociate_network() {
    local now=$(date +%s)
    local current=$(get_current_network)

    # Skip if no network is connected
    [[ -z "$current" ]] && return

    # Skip if we reassociated too recently
    ((now - last_reassociate_time < REASSOCIATE_INTERVAL)) && return

    log "Proactive re-association on $current"
    if nmcli con up "$current" &>/dev/null; then
        notify-send -u low "Network Assisst" "Reconnected to $current" -t 1500
        last_reassociate_time=$now
        log "Reassociated with $current"
    else
        notify-send -u normal "Network Assisst" "Failed to reconnect $current" -t 1500
        log "Failed to reassociate with $current"
    fi
}

monitor_loop() {
    while true; do
        # proactive re-association check
        reassociate_network

        # fallback failover check
        if ! check_connection; then
            log "Check failed, switching immediately..."
            switch_network
        fi

        sleep $CHECK_INTERVAL
    done
}

trap "log 'Exiting...'; exit 0" SIGINT SIGTERM 

log "Wi-Fi monitor started (ping 8.8.8.8 at ${CHECK_INTERVAL}s, reassociate at 30m)"
notify-send -u normal "Network Assisst" "Started operation ..." -t 1500
monitor_loop
