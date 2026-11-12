pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string currentUser: Quickshell.env("USER") || Quickshell.env("LOGNAME") || "User"

    // Caps Lock state
    property bool capsLock: false

    // Audio status
    property string volumeOut: "50%"
    property bool volumeMuted: false

    // Network status
    property bool ethernetConnected: false
    property bool wifiEnabled: false
    property string wifiSsid: ""
    property string wifiStrength: "0"

    // Bluetooth status
    property bool bluetoothPresent: false
    property string bluetoothStatus: "off" // "off", "powered-on", "connected"
    property string bluetoothDevice: ""

    // Poller timer for fast, non-blocking telemetry refresh
    Timer {
        id: telemetryTimer
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            pVolume.running = true;
            pCapsLock.running = true;
            pQuickNet.running = true;
        }
    }

    // Volume fetcher
    Process {
        id: pVolume
        command: [Quickshell.env("HOME") + "/dotfiles/scripts/get_volume.sh"]
        stdout: SplitParser {
            onRead: data => {
                var d = data.trim();
                root.volumeMuted = d.includes("[MUTED]");
                var m = d.match(/[0-9.]+/);
                if (m) {
                    root.volumeOut = Math.round(parseFloat(m[0]) * 100) + "%";
                }
            }
        }
    }

    // PipeWire subscription for instant volume changes
    Process {
        id: pVolumeSub
        running: true
        command: ["pactl", "subscribe"]
        stdout: SplitParser {
            onRead: data => {
                if (data.includes("sink") || data.includes("source")) {
                    pVolume.running = true;
                }
            }
        }
    }

    // Caps Lock detection via hyprctl
    Process {
        id: pCapsLock
        command: ["sh", "-c", "hyprctl devices -j | jq -r '.keyboards[] | select(.main == true) | .capsLock'"]
        stdout: SplitParser {
            onRead: data => {
                var d = data.trim();
                root.capsLock = (d === "true");
            }
        }
    }

    // Fast network and bluetooth state query
    Process {
        id: pQuickNet
        command: ["sh", "-c", "
            # Check default route for ethernet vs wifi
            eth_state=false
            wifi_ssid=\"\"
            wifi_strength=\"0\"
            if ip route show default 2>/dev/null | grep -q 'dev e'; then
                eth_state=true
            fi
            if command -v nmcli >/dev/null 2>&1; then
                active_wifi=$(nmcli -t -f active,ssid,bars dev wifi 2>/dev/null | grep '^yes:')
                if [ -n \"$active_wifi\" ]; then
                    wifi_ssid=$(echo \"$active_wifi\" | cut -d: -f2)
                fi
            fi
            bt_status=\"off\"
            bt_device=\"\"
            if command -v bluetoothctl >/dev/null 2>&1; then
                if timeout 1 bluetoothctl show 2>/dev/null | grep -q 'Powered: yes'; then
                    bt_status=\"powered-on\"
                    info=$(timeout 1 bluetoothctl info 2>/dev/null | grep 'Name:' | head -n1 | cut -d: -f2 | xargs)
                    if [ -n \"$info\" ]; then
                        bt_status=\"connected\"
                        bt_device=\"$info\"
                    fi
                fi
            fi
            echo \"$eth_state|$wifi_ssid|$bt_status|$bt_device\"
        "]
        stdout: SplitParser {
            onRead: data => {
                var line = data.trim();
                if (line === "") return;
                var parts = line.split("|");
                if (parts.length >= 4) {
                    root.ethernetConnected = (parts[0] === "true");
                    root.wifiSsid = parts[1];
                    root.bluetoothStatus = parts[2];
                    root.bluetoothDevice = parts[3];
                }
            }
        }
    }

    // Session control actions
    function screenOff() {
        pScreenOff.running = true;
    }
    function suspend() {
        pSuspend.running = true;
    }
    function reboot() {
        pReboot.running = true;
    }
    function powerOff() {
        pPowerOff.running = true;
    }

    Process { id: pScreenOff; command: ["hyprctl", "dispatch", "dpms", "off"] }
    Process { id: pSuspend; command: ["systemctl", "suspend"] }
    Process { id: pReboot; command: ["systemctl", "reboot"] }
    Process { id: pPowerOff; command: ["systemctl", "poweroff"] }
}
