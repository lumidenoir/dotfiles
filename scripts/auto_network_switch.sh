#!/bin/bash
#
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
    ((now - last_switch_time < SWITCH_COOLDOWN)) && {
        log "Cooldown active"
        return
    }

    local current=$(get_current_network)
    local target=$([[ "$current" == "$NETWORK_1" ]] && echo "$NETWORK_2" || echo "$NETWORK_1")

    log "Switching: $current → $target"
    if nmcli con up "$target" &>/dev/null; then
        last_switch_time=$now
        log "Switched to $target"
        notify-send -u low "Akashic Synchrony" \
            "Pathway realigned linked to [$target]" -t 2000
    else
        log "Failed to connect to $target"
        notify-send -u normal "Akashic Interruption" \
            "The ether rejects [$target]. Rebinding failed." -t 2000
    fi
}

reassociate_network() {
    local now=$(date +%s)
    local current=$(get_current_network)

    [[ -z "$current" ]] && return
    ((now - last_reassociate_time < REASSOCIATE_INTERVAL)) && return

    log "Proactive re-association on $current"
    if nmcli con up "$current" &>/dev/null; then
        notify-send -u low "Akashic Pulse" \
            "Resonance renewed threads aligned with [$current]" -t 2000
        last_reassociate_time=$now
        log "Reassociated with $current"
    else
        notify-send -u normal "Akashic Disruption" \
            "Resonance to [$current] failed, distortion in the flow." -t 2000
        log "Failed to reassociate with $current"
    fi
}

monitor_loop() {
    while true; do
        reassociate_network
        if ! check_connection; then
            log "Check failed, switching immediately..."
            notify-send -u critical "Akashic Disturbance" \
                "Signal resonance lost initiating path reweave..." -t 2000
            switch_network
        fi
        sleep $CHECK_INTERVAL
    done
}

trap "log 'Exiting...'; exit 0" SIGINT SIGTERM

log "Wi-Fi monitor started (ping 8.8.8.8 at ${CHECK_INTERVAL}s, reassociate at 30m)"
notify-send -u normal "Akashic Core" \
    "Link observer initiated attuning to network streams..." -t 2000
monitor_loop
