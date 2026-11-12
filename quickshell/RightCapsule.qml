import Quickshell
import QtQuick
import QtCore
import QtQuick.Shapes
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Io
import Quickshell.Services.Notifications
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import QtQuick.Effects
import Quickshell.Services.Mpris
import "Singletons"

Rectangle {
    id: rightCapsule
    property var root

    readonly property real scaleFactor: root ? root.scaleFactor : 1.0
    readonly property real fontScale: root ? root.fontScale : 1.0

    color: "transparent"
    z: 1
    anchors.right: parent.right
    anchors.rightMargin: Math.round(12 * scaleFactor)
    anchors.top: parent.top
    anchors.topMargin: (root && root.topHuggingStyle) ? 0 : Math.round(6 * scaleFactor)

    height: (root && root.topHuggingStyle) ? Math.round(36 * scaleFactor) : Math.round(34 * scaleFactor)
    width: contentRow.implicitWidth + Math.round(20 * scaleFactor)
    radius: (root && root.topHuggingStyle) ? 2 : Math.round(4 * scaleFactor)
    Behavior on width {
        NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
    }

    SurfaceCard {
        id: rightGlassCard
        anchors.fill: parent
        useShader: false
        cornerRadius: (root && root.topHuggingStyle) ? 2 : Math.round(4 * scaleFactor)
        zRadius: (root && root.topHuggingStyle) ? 2 : Math.round(4 * scaleFactor)
        contentPadding: 0

        Row {
            id: contentRow
            anchors.centerIn: parent
            spacing: Math.round(8 * scaleFactor)

            // ── 1. Privacy indicator chip (mic / cam dots) ─────────────────
            Item {
                id: privacyChip
                anchors.verticalCenter: parent.verticalCenter

                readonly property real chipWidth: (root.isMicActive || root.isCamActive)
                    ? ((root.isMicActive && root.isCamActive)
                       ? Math.round(28 * scaleFactor)
                       : Math.round(14 * scaleFactor))
                    : 0
                width:  chipWidth
                height: Math.round(16 * scaleFactor)
                visible: chipWidth > 0
                clip: true
                Behavior on width { SpringAnimation { spring: 4.0; damping: 0.72; mass: 0.5 } }

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Math.round(4 * scaleFactor)

                    Text {
                        id: micDot
                        text: "󰍬"
                        color: "#FF9500"
                        font { family: root.iconFontFamily; pixelSize: Math.round(12 * fontScale) }
                        visible: root.isMicActive
                        opacity: root.isMicActive ? 1.0 : 0.0
                        scale:   root.isMicActive ? 1.0 : 0.0
                        anchors.verticalCenter: parent.verticalCenter
                        Behavior on scale   { SpringAnimation { spring: 3.5; damping: 0.7; mass: 0.8 } }
                        Behavior on opacity { NumberAnimation { duration: 150 } }
                    }

                    Text {
                        id: camDot
                        text: ""
                        color: "#34C759"
                        font { family: root.iconFontFamily; pixelSize: Math.round(12 * fontScale) }
                        visible: root.isCamActive
                        opacity: root.isCamActive ? 1.0 : 0.0
                        scale:   root.isCamActive ? 1.0 : 0.0
                        anchors.verticalCenter: parent.verticalCenter
                        Behavior on scale   { SpringAnimation { spring: 3.5; damping: 0.7; mass: 0.8 } }
                        Behavior on opacity { NumberAnimation { duration: 150 } }
                    }
                }
            }

            // ── 2. System Tray icons ───────────────────────────────────────────────
            Repeater {
                id: sysTray
                model: SystemTray.items
                delegate: Item {
                    id: trayItemRoot
                    width:  Math.round(22 * scaleFactor)
                    height: Math.round(22 * scaleFactor)

                    QsMenuAnchor {
                        id: menuAnchor
                        menu: modelData.menu
                        anchor {
                            window: root.barWindow
                            rect: Qt.rect(0, 0, trayItemRoot.width, trayItemRoot.height)
                        }
                    }

                    IconImage {
                        anchors.centerIn: parent
                        width: Math.round(16 * scaleFactor)
                        height: Math.round(16 * scaleFactor)
                        source: modelData.icon
                    }

                    // Floating tooltip above icon
                    QSTooltip {
                        show: sysTrayMouse.containsMouse && (modelData.tooltip.title !== "" || modelData.title !== "")
                        text: modelData.tooltip.title !== "" ? modelData.tooltip.title : modelData.title
                        subtitle: modelData.tooltip.description ?? ""
                        fontScale: root.fontScale
                        fontFamily: root.fontFamily
                    }

                    MouseArea {
                        id: sysTrayMouse
                        anchors.fill:    parent
                        hoverEnabled:    true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: mouse => {
                            if (mouse.button === Qt.RightButton && modelData.hasMenu) {
                                var pos = trayItemRoot.mapToItem(root.barWindow.contentItem, 0, 0);
                                menuAnchor.anchor.rect = Qt.rect(pos.x, pos.y, trayItemRoot.width, trayItemRoot.height);
                                menuAnchor.open();
                            } else {
                                modelData.activate();
                            }
                        }
                    }
                }
            }

            // Vertical separator after system tray
            Rectangle {
                width: 1
                height: Math.round(14 * scaleFactor)
                color: (root && root.isPearlMode) ? Qt.rgba(0, 0, 0, 0.12) : Qt.rgba(1, 1, 1, 0.15)
                visible: sysTray.count > 0 || privacyChip.visible
                anchors.verticalCenter: parent.verticalCenter
            }

            // ── 3. Network Status Indicator (Ethernet / Wi-Fi) ───────────────────
            MouseArea {
                id: networkIndicator
                width: netRow.implicitWidth + Math.round(10 * scaleFactor)
                height: Math.round(22 * scaleFactor)
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor

                Row {
                    id: netRow
                    anchors.centerIn: parent
                    spacing: Math.round(4 * scaleFactor)

                    Text {
                        text: root.ethernetConnected ? "󰈀" : root.wifiIcon
                        color: (root && root.isPearlMode) ? root.colFgPrimary : (root.ethernetConnected ? "#34C759" : ((root.wifiEnabled && root.wifiText !== "Disconnected") ? "#007AFF" : root.colMuted))
                        font { family: root.iconFontFamily; pixelSize: Math.round(13 * fontScale) }
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    // Fixed-width container for Download speed (hidden on dashboard to avoid redundancy)
                    Item {
                        width: Math.round(60 * scaleFactor)
                        height: Math.round(16 * scaleFactor)
                        visible: (root.activeWindowTitle !== "") && (root.networkDown !== "")
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: "↓ " + (root.networkDown !== "" ? root.networkDown : "0 B/s")
                            color: root.colFg
                            font { family: root.textFontFamily; pixelSize: Math.round(10 * fontScale); weight: Font.Medium; features: { "tnum": 1 } }
                            elide: Text.ElideRight
                        }
                    }

                    // Fixed-width container for Upload speed (hidden on dashboard to avoid redundancy)
                    Item {
                        width: Math.round(50 * scaleFactor)
                        height: Math.round(16 * scaleFactor)
                        visible: (root.activeWindowTitle !== "") && (root.networkUp !== "")
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: "↑ " + (root.networkUp !== "" ? root.networkUp : "0 B/s")
                            color: root.colFg
                            font { family: root.textFontFamily; pixelSize: Math.round(10 * fontScale); weight: Font.Medium; features: { "tnum": 1 } }
                            elide: Text.ElideRight
                        }
                    }
                }

                // Floating Tooltip for Network Status
                QSTooltip {
                    show: networkIndicator.containsMouse
                    text: {
                        if (root.ethernetConnected) return "Ethernet Connected";
                        if (!root.wifiEnabled) return "Wi-Fi Disabled";
                        if (root.wifiSsid === "") return "Wi-Fi Disconnected";
                        return "Wi-Fi: " + root.wifiSsid;
                    }
                    subtitle: {
                        if (root.ethernetConnected || !root.wifiEnabled || root.wifiSsid === "") return "";
                        return "(" + root.wifiText + ")" + (root.wifiIp !== "" ? (" IP: " + root.wifiIp) : "");
                    }
                    fontScale: root.fontScale
                    fontFamily: root.fontFamily
                }

                onClicked: {
                    if (root.togglePopup) root.togglePopup(root.wifiMenuPopup);
                    else root.wifiMenuPopup.show = !root.wifiMenuPopup.show;
                }
            }

            // Vertical separator between Network and Bluetooth
            Rectangle {
                width: 1
                height: Math.round(14 * scaleFactor)
                color: (root && root.isPearlMode) ? Qt.rgba(0, 0, 0, 0.25) : Qt.rgba(1, 1, 1, 0.35)
                visible: bluetoothIndicator.visible
                anchors.verticalCenter: parent.verticalCenter
            }

            // ── 4. Bluetooth Status Indicator ──────────────────────────────────
            MouseArea {
                id: bluetoothIndicator
                width: Math.round(24 * scaleFactor)
                height: Math.round(22 * scaleFactor)
                visible: root.bluetoothPresent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor

                Text {
                    anchors.centerIn: parent
                    text: root.bluetoothStatus === "powered-off" ? "󰂲" : "󰂯"
                    color: (root && root.isPearlMode) ? root.colFgPrimary : (root.bluetoothStatus === "connected" ? "#007AFF" : (root.bluetoothStatus === "powered-on" ? root.colFg : root.colMuted))
                    font { family: root.iconFontFamily; pixelSize: Math.round(13 * fontScale) }
                }

                // Floating Tooltip for Bluetooth Status
                QSTooltip {
                    show: bluetoothIndicator.containsMouse
                    text: {
                        if (root.bluetoothStatus === "powered-off") return "Bluetooth Disabled";
                        if (root.bluetoothStatus === "connected") return "Bluetooth Connected";
                        return "Bluetooth Powered On";
                    }
                    subtitle: root.bluetoothStatus === "connected" ? root.bluetoothDevice : ""
                    fontScale: root.fontScale
                    fontFamily: root.fontFamily
                }

                onClicked: {
                    if (root.togglePopup) root.togglePopup(root.bluetoothMenuPopup);
                    else root.bluetoothMenuPopup.show = !root.bluetoothMenuPopup.show;
                }
            }

            // Vertical separator before Volume (always visible and crisp)
            Rectangle {
                width: 1
                height: Math.round(14 * scaleFactor)
                color: (root && root.isPearlMode) ? Qt.rgba(0, 0, 0, 0.25) : Qt.rgba(1, 1, 1, 0.35)
                anchors.verticalCenter: parent.verticalCenter
            }

            // ── 5. Volume Indicator (Output) ────────────────────────────────────
            MouseArea {
                id: volumeIndicator
                width: volumeRow.implicitWidth + Math.round(12 * scaleFactor)
                height: Math.round(22 * scaleFactor)
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor

                Row {
                    id: volumeRow
                    spacing: Math.round(4 * scaleFactor)
                    anchors.centerIn: parent
                    Text {
                        text: {
                            if (root.volumeMuted) return "󰖁";
                            let vol = parseInt(root.volumeOut);
                            if (vol === 0) return "󰕿";
                            if (vol < 30) return "󰕿";
                            if (vol < 70) return "󰖀";
                            return "󰕾";
                        }
                        color: root.volumeMuted ? root.colCrit : root.colFg
                        font { family: root.iconFontFamily; pixelSize: Math.round(13 * fontScale) }
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: root.volumeOut
                        color: root.colFg
                        font { family: root ? root.monoFontFamily : "Geist Mono"; pixelSize: Math.round(10 * fontScale); weight: Font.Bold; features: { "tnum": 1 } }
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                // Floating Tooltip for Volume Status
                QSTooltip {
                    show: volumeIndicator.containsMouse
                    text: "Volume: " + (root.volumeMuted ? "Muted" : root.volumeOut)
                    subtitle: root.activeSinkName ? root.activeSinkName : ""
                    fontScale: root.fontScale
                    fontFamily: root.fontFamily
                }

                onClicked: {
                    if (root.togglePopup) root.togglePopup(root.audioPopup);
                    else root.audioPopup.show = !root.audioPopup.show;
                }
            }

            // Vertical separator before Power Profile
            Rectangle {
                width: 1
                height: Math.round(14 * scaleFactor)
                color: (root && root.isPearlMode) ? Qt.rgba(0, 0, 0, 0.12) : Qt.rgba(1, 1, 1, 0.15)
                anchors.verticalCenter: parent.verticalCenter
            }

            // ── 6. Power Profile indicator ─────────────────────────────────────
            MouseArea {
                id: powerProfileIndicator
                width: Math.round(24 * scaleFactor)
                height: Math.round(22 * scaleFactor)
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor

                Text {
                    anchors.centerIn: parent
                    text: root.powerProfile === "performance" ? "󰓅" : (root.powerProfile === "power-saver" ? "󰾆" : "󰾅")
                    color: (root && root.isPearlMode) ? root.colFgPrimary : ((root.powerProfile === "performance") ? "#FF3B30" : ((root.powerProfile === "power-saver") ? "#FFCC00" : "#34C759"))
                    font { family: root.iconFontFamily; pixelSize: Math.round(13 * fontScale) }
                }

                onClicked: {
                    if (root.togglePopup && root.powerProfilePopup)
                        root.togglePopup(root.powerProfilePopup);
                    else if (root.powerProfilePopup)
                        root.powerProfilePopup.show = !root.powerProfilePopup.show;
                }
            }
        }
    }
}
