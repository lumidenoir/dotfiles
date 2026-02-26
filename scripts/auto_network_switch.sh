#!/bin/bash
NETWORK_1="iitk-sec"
NETWORK_2="iitk-sec(Highspeed-5GHz)"
SWITCH_COOLDOWN=30
CHECK_INTERVAL=10
REASSOCIATE_INTERVAL=1800

last_switch_time=0
last_reassociate_time=$(date +%s)

log() { echo "$(date '+%F %T') - $1"; }

check_connection() {
    ip route | grep -q default || return 1
    ping -c 2 -W 1 -i 0.3 8.8.8.8 >/dev/null 2>&1 || \
    ping -c 2 -W 1 -i 0.3 1.1.1.1 >/dev/null 2>&1
}

get_current_network() {
    nmcli -t -f ACTIVE,SSID dev wifi list | while IFS='' read -r line; do
        if [[ "$line" == yes:* ]]; then
            echo "${line#yes:}"
            return
        fi
    done
}

is_known_network() {
    local net="$1"
    [[ "$net" == "$NETWORK_1" || "$net" == "$NETWORK_2" ]]
}

connect_to() {
    local target="$1"
    local now="$2"
    local current
    current=$(get_current_network)

    if [[ -n "$current" && "$current" != "$target" ]]; then
        log "Bringing down $current"
        nmcli con down "$current" &>/dev/null
        sleep 2
    fi

    local attempt
    for attempt in 1 2 3; do
        log "Connecting to $target (attempt $attempt/3)"
        if nmcli --wait 15 con up "$target" &>/dev/null; then
            last_switch_time=$now
            last_reassociate_time=$now
            log "Connected to $target"
            notify-send -u low "WiFi" "Connected to $target" -t 1500
            return 0
        fi
        sleep 3
    done

    log "Failed to connect to $target: $(nmcli --wait 10 con up "$target" 2>&1 | tail -1)"
    return 1
}

handle_no_network() {
    local now="$1"
    (( now - last_switch_time < SWITCH_COOLDOWN )) && { log "Cooldown active, waiting..."; return; }

    log "No network — attempting $NETWORK_1"
    local attempt
    for attempt in 1 2 3; do
        if nmcli --wait 15 con up "$NETWORK_1" &>/dev/null; then
            last_switch_time=$now
            last_reassociate_time=$now
            log "Connected to $NETWORK_1"
            notify-send -u low "WiFi" "Connected to $NETWORK_1" -t 1500
            return
        fi
        sleep 3
    done

    log "Fallback: attempting $NETWORK_2"
    for attempt in 1 2 3; do
        if nmcli --wait 15 con up "$NETWORK_2" &>/dev/null; then
            last_switch_time=$now
            last_reassociate_time=$now
            log "Connected to $NETWORK_2"
            notify-send -u low "WiFi" "Connected to $NETWORK_2" -t 1500
            return
        fi
        sleep 3
    done

    log "Could not connect to any known network"
}

switch_network() {
    local now="$1"
    local current="$2"
    (( now - last_switch_time < SWITCH_COOLDOWN )) && { log "Switch on cooldown"; return; }

    local target
    [[ "$current" == "$NETWORK_1" ]] && target="$NETWORK_2" || target="$NETWORK_1"

    log "Switching: $current -> $target"
    connect_to "$target" "$now" || {
        log "Switch failed, restoring $current"
        connect_to "$current" "$now"
    }
}

reassociate() {
    local current="$1"
    local now="$2"
    log "Reassociating: $current (EAPOL refresh)"
    nmcli con down "$current" &>/dev/null
    sleep 2
    if nmcli --wait 15 con up "$current" &>/dev/null; then
        last_reassociate_time=$now
        last_switch_time=$now
        log "Reassociation OK"
        notify-send -u low "WiFi" "Reassociated $current" -t 1500
    else
        log "Reassociation failed — switching"
        switch_network "$now" "$current"
    fi
}

monitor_loop() {
    local fail_count=0

    while true; do
        local now
        now=$(date +%s)
        local current
        current=$(get_current_network)

        if [[ -z "$current" ]]; then
            log "No active network"
            handle_no_network "$now"
            fail_count=0
            sleep "$CHECK_INTERVAL"
            continue
        fi

        if ! is_known_network "$current"; then
            log "Unknown network '$current' — not interfering"
            sleep "$CHECK_INTERVAL"
            continue
        fi

        if (( now - last_reassociate_time >= REASSOCIATE_INTERVAL )); then
            reassociate "$current" "$now"
            fail_count=0
            sleep "$CHECK_INTERVAL"
            continue
        fi

        if ! check_connection; then
            (( fail_count++ ))
            log "Check failed (count: $fail_count) on $current"
            if (( fail_count >= 2 )); then
                notify-send -u critical "WiFi" "Connection lost, switching..." -t 1500
                switch_network "$now" "$current"
                fail_count=0
            fi
        else
            fail_count=0
        fi

        sleep "$CHECK_INTERVAL"
    done
}

trap "log 'Stopped'; exit 0" SIGINT SIGTERM
log "Wi-Fi monitor started (EAPOL refresh every $((REASSOCIATE_INTERVAL/60)) min)"
monitor_loop
