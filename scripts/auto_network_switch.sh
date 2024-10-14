#!/bin/bash

# Set your network names (SSID or connection names)
NETWORK_1="iitk-sec"
NETWORK_2="iitk-sec 5GHz"

# Interval to check network status (in seconds)
CHECK_INTERVAL=10

# Function to check if we have internet connectivity
check_connection() {
    ping -c 1 8.8.8.8 &> /dev/null
    if [ $? -eq 0 ]; then
        return 0  # Connected
    else
        return 1  # No connection
    fi
}

# Function to switch network
switch_network() {
    local current_network=$(nmcli -t -f active,ssid dev wifi | grep '^yes' | cut -d ':' -f2)

    if [[ "$current_network" == "$NETWORK_1" ]]; then
        echo "Switching to $NETWORK_2..."
        nmcli con up "$NETWORK_2"
    else
        echo "Switching to $NETWORK_1..."
        nmcli con up "$NETWORK_1"
    fi
}

# Main loop
while true; do
    check_connection
    if [ $? -ne 0 ]; then
        echo "No internet connection, switching network..."
        switch_network
    fi
    sleep $CHECK_INTERVAL
done
