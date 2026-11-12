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
    id: leftCapsule
    property var root

    readonly property real scaleFactor: root ? root.scaleFactor : 1.0
    readonly property real fontScale: root ? root.fontScale : 1.0

    color: "transparent"
    z: 1
    anchors.left: parent.left
    anchors.leftMargin: Math.round(12 * scaleFactor)
    anchors.top: parent.top
    anchors.topMargin: (root && root.topHuggingStyle) ? 0 : Math.round(6 * scaleFactor)
    height: (root && root.topHuggingStyle) ? Math.round(36 * scaleFactor) : Math.round(34 * scaleFactor)
    width: leftLayout.implicitWidth + Math.round(28 * scaleFactor)
    radius: (root && root.topHuggingStyle) ? 2 : Math.round(4 * scaleFactor)

    SurfaceCard {
        id: leftGlassCard
        anchors.fill: parent
        useShader: false
        cornerRadius: (root && root.topHuggingStyle) ? 2 : Math.round(4 * scaleFactor)
        zRadius: (root && root.topHuggingStyle) ? 2 : Math.round(4 * scaleFactor)
        contentPadding: 0

        RowLayout {
            id: leftLayout
            anchors.centerIn: parent
            spacing: Math.round(8 * scaleFactor)

            // ── TE / Avionics Channel Header ─────────────────────────────────
            Text {
                text: "WS"
                color: "#FFB000"
                opacity: 0.75
                font {
                    family: root ? root.monoFontFamily : "Geist Mono"
                    pixelSize: Math.round(9 * fontScale)
                    weight: Font.Bold
                    features: { "tnum": 1 }
                }
                Layout.alignment: Qt.AlignVCenter
            }

            Rectangle {
                width: 1
                height: Math.round(12 * scaleFactor)
                color: Qt.rgba(1, 1, 1, 0.15)
                Layout.alignment: Qt.AlignVCenter
            }

            // ── Workspaces (Zero-Padded Telemetry Channels 01-07) ────────────
            Row {
                spacing: Math.round(4 * scaleFactor)
                Layout.alignment: Qt.AlignVCenter
                Repeater {
                    model: [1, 2, 3, 4, 5, 6, 7]
                    delegate: MouseArea {
                        property var ws: Hyprland.workspaces.values.find(w => w.id === modelData)
                        property bool isFocused: Hyprland.focusedWorkspace != null && Hyprland.focusedWorkspace.id === modelData
                        property bool hasWindows: ws !== undefined

                        visible: modelData <= 5 || isFocused || hasWindows
                        width: visible ? Math.round(22 * scaleFactor) : 0
                        height: Math.round(20 * scaleFactor)
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        // Tactical bracketed cell
                        Rectangle {
                            anchors.fill: parent
                            radius: 2
                            color: isFocused ? Qt.rgba(0.039, 0.518, 1.0, 0.20) : (parent.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent")
                            border.color: isFocused ? (root ? root.colAccent : "#0A84FF") : (hasWindows ? Qt.rgba(1, 1, 1, 0.12) : "transparent")
                            border.width: 1
                        }

                        Text {
                            anchors.centerIn: parent
                            text: (modelData < 10 ? "0" : "") + modelData.toString()
                            font {
                                family: root ? root.monoFontFamily : "Geist Mono"
                                pixelSize: Math.round(10 * fontScale)
                                weight: isFocused ? Font.Bold : Font.Medium
                                features: { "tnum": 1 }
                            }
                            color: isFocused ? (root ? root.colAccent : "#0A84FF") : (hasWindows ? "#E5E7EB" : "#6B7280")

                            scale: (parent.containsMouse && root && root.bootSettled) ? 1.05 : 1.0
                            Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
                        }

                        onClicked: Hyprland.dispatch("hl.dsp.focus({ workspace = \"" + modelData + "\" })")
                    }
                }
            }
        }
    }
}
