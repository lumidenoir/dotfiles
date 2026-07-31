import Quickshell
import QtQuick
import QtQuick.Layouts
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick.Controls

// ─────────────────────────────────────────────────────────────────────────────
// FlightDeck — Reimagined Auto-Hiding Minimized Window Shelf
// Hidden by default; triggers on hover at bottom edge when minimized windows exist.
// ─────────────────────────────────────────────────────────────────────────────
PanelWindow {
    id: root

    anchors.bottom: true
    margins.bottom: Math.round(4 * scaleFactor)

    property var  shellRoot:   null
    property real scaleFactor: shellRoot ? shellRoot.scaleFactor : 1.0
    property var  clients:     []
    property bool shelfOpen:   false

    // Window size tightly wraps the dock zone at bottom center including floating tooltips
    visible:        clients.length > 0
    implicitWidth:  clients.length > 0 ? (dockPill.implicitWidth + Math.round(24 * scaleFactor)) : 0
    implicitHeight: clients.length > 0 ? Math.round(94 * scaleFactor) : 0
    color:          "transparent"


    WlrLayershell.layer:         WlrLayer.Overlay
    WlrLayershell.namespace:     "flight_deck"
    WlrLayershell.exclusiveZone: 0
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // Static input region matching dock bounds at bottom center
    mask: Region {
        Region {
            item: root.clients.length > 0 ? maskArea : null
        }
    }

    function requestOpen() {
        if (clients.length === 0) return;
        leaveTimer.stop();
        shelfOpen = true;
    }
    function requestClose() {
        leaveTimer.restart();
    }

    Timer {
        id: leaveTimer
        interval: 320
        repeat:   false
        onTriggered: { root.shelfOpen = false; root.hovIdx = -1; }
    }

    // ── Tracked hover state for tooltips ─────────────────────────────────────
    property int hovIdx: -1

    // ── Data Pipeline ─────────────────────────────────────────────────────────
    Process {
        id: evtSock
        command: ["sh", "-c",
            "socat - UNIX-CONNECT:/tmp/hypr/${HYPRLAND_INSTANCE_SIGNATURE}/.socket2.sock 2>/dev/null"]
        running: true
        stdout: SplitParser {
            onRead: function(data) {
                var ev = data.trim().split(">>")[0];
                if (ev === "openwindow"     || ev === "closewindow"   ||
                    ev === "movewindow"     || ev === "createworkspace" ||
                    ev === "closeworkspace" || ev === "minimizewindow") {
                    getClients.running = true;
                }
            }
        }
        onExited: { sockRestartTimer.restart(); }
    }

    Timer {
        id: sockRestartTimer
        interval: 750; repeat: false
        onTriggered: { evtSock.running = true; getClients.running = true; }
    }

    Component.onCompleted: getClients.running = true
    Connections {
        target: Hyprland
        function onFocusedWorkspaceChanged() { getClients.running = true; }
    }

    Process {
        id: getClients
        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var all = JSON.parse(text.trim());
                    var mins = [];
                    for (var i = 0; i < all.length; i++) {
                        if (all[i].workspace.name === "special:minimized" && all[i].mapped)
                            mins.push(all[i]);
                    }
                    root.clients = mins;
                    if (mins.length === 0 && root.shelfOpen) {
                        root.shelfOpen = false;
                        root.hovIdx = -1;
                    }
                } catch(e) { root.clients = []; }
            }
        }
    }

    function restoreWindow(modelData) {
        var ws = Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1;
        Hyprland.dispatch("hl.dsp.window.move({ workspace = \"" + ws + "\", window = \"address:" + modelData.address + "\" })");
        Hyprland.dispatch("hl.dsp.focus({ window = \"address:" + modelData.address + "\" })");
        getClients.running = true;
    }

    function closeWindow(modelData) {
        Hyprland.dispatch("hl.dsp.window.close({ window = \"address:" + modelData.address + "\" })");
        getClients.running = true;
    }

    // ── Main Content Container ───────────────────────────────────────────────
    Item {
        id: maskArea
        anchors.fill: parent

        HoverHandler {
            id: dockHover
            onHoveredChanged: {
                if (hovered) root.requestOpen();
                else         root.requestClose();
            }
        }

        // ── 1. Closed Indicator (subtle pill at bottom edge when hidden) ──────
        Rectangle {
            id: indicatorCapsule
            anchors.bottom:           parent.bottom
            anchors.bottomMargin:     Math.round(2 * scaleFactor)
            anchors.horizontalCenter: parent.horizontalCenter

            width:  dockHover.hovered ? Math.round(56 * scaleFactor) : Math.round(44 * scaleFactor)
            height: Math.round(4 * scaleFactor)
            radius: Math.round(2 * scaleFactor)

            color: dockHover.hovered
                   ? Qt.rgba(1, 1, 1, 0.85)
                   : Qt.rgba(1, 1, 1, 0.40)
            border.color: Qt.rgba(1, 1, 1, 0.15)
            border.width: 1

            opacity: (!root.shelfOpen && root.clients.length > 0) ? 1.0 : 0.0

            Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: 150 } }
            Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutQuad } }
        }

        // ── 2. Open Glass Dock Pill (slides up on trigger hover) ─────────────
        Rectangle {
            id: dockPill
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom:           parent.bottom

            implicitWidth:  iconRow.implicitWidth + Math.round(28 * scaleFactor)
            implicitHeight: Math.round(52 * scaleFactor)
            radius:         height / 2

            color:        Qt.rgba(0.07, 0.07, 0.11, 0.88)
            border.color: Qt.rgba(1, 1, 1, 0.12)
            border.width: 1

            // Smooth slide up & opacity transition
            transform: Translate {
                y: root.shelfOpen ? 0 : Math.round(24 * scaleFactor)
                Behavior on y {
                    NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                }
            }

            opacity: root.shelfOpen ? 1.0 : 0.0
            Behavior on opacity {
                NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
            }

            Behavior on implicitWidth {
                NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
            }

            // Inner top specular highlight
            Rectangle {
                anchors {
                    top:         parent.top
                    topMargin:   1
                    left:        parent.left
                    leftMargin:  Math.round(dockPill.radius * 0.5)
                    right:       parent.right
                    rightMargin: Math.round(dockPill.radius * 0.5)
                }
                height: 1
                color:  Qt.rgba(1, 1, 1, 0.09)
            }

            // Icons Row
            Row {
                id: iconRow
                anchors.centerIn: parent
                spacing: Math.round(12 * scaleFactor)

                Repeater {
                    model: root.clients

                    delegate: Item {
                        id: iconSlot
                        width:  Math.round(36 * scaleFactor)
                        height: Math.round(36 * scaleFactor)

                        readonly property bool isHov: root.hovIdx === index
                        readonly property bool isPrs: iconMouse.containsPress

                        // ── Tooltip ───────────────────────────────────────────
                        Rectangle {
                            id: tip
                            visible: iconSlot.isHov
                            z: 100
                            anchors.bottom: parent.top
                            anchors.bottomMargin: Math.round(12 * scaleFactor)
                            anchors.horizontalCenter: parent.horizontalCenter

                            width:  tipText.implicitWidth + Math.round(16 * scaleFactor)
                            height: Math.round(24 * scaleFactor)
                            radius: Math.round(6 * scaleFactor)

                            color: Qt.rgba(0.08, 0.08, 0.12, 0.94)
                            border.color: Qt.rgba(1, 1, 1, 0.16)
                            border.width: 1

                            Text {
                                id: tipText
                                anchors.centerIn: parent
                                text: {
                                    var p = (modelData.class || "App").split(".");
                                    var n = p[p.length - 1];
                                    return n.charAt(0).toUpperCase() + n.slice(1);
                                }
                                color: "#FFFFFF"
                                font {
                                    family:    shellRoot ? shellRoot.fontFamily : "sans-serif"
                                    pixelSize: Math.round(11 * scaleFactor)
                                    bold:      true
                                }
                            }
                        }

                        // ── Icon Image ────────────────────────────────────────
                        Image {
                            id: iconImg
                            anchors.centerIn: parent
                            width:  Math.round(36 * scaleFactor)
                            height: Math.round(36 * scaleFactor)
                            source: "image://icon/" + (modelData.class ? modelData.class.toLowerCase() : "application-x-executable")
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            antialiasing: true

                            y: iconSlot.isHov ? Math.round(-4 * scaleFactor) : 0
                            Behavior on y {
                                NumberAnimation { duration: 150; easing.type: Easing.OutBack; easing.overshoot: 0.4 }
                            }

                            scale: iconSlot.isPrs ? 0.88 : (iconSlot.isHov ? 1.18 : 1.0)
                            Behavior on scale {
                                NumberAnimation { duration: 150; easing.type: Easing.OutBack; easing.overshoot: 0.5 }
                            }
                        }

                        // ── Close Badge ───────────────────────────────────────
                        Rectangle {
                            id: closeBadge
                            visible: iconSlot.isHov
                            z: 50
                            width:  Math.round(14 * scaleFactor)
                            height: Math.round(14 * scaleFactor)
                            radius: width / 2

                            x: iconImg.x + iconImg.width - width / 2 + Math.round(2 * scaleFactor)
                            y: iconImg.y - height / 2 + Math.round(2 * scaleFactor)

                            color: closeMouse.containsMouse ? "#FF3B30" : Qt.rgba(0.12, 0.12, 0.16, 0.95)
                            border.color: Qt.rgba(1, 1, 1, 0.3)
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: "✕"
                                color: "#FFFFFF"
                                font.pixelSize: Math.round(7 * scaleFactor)
                                font.bold: true
                            }

                            MouseArea {
                                id: closeMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: function(mouse) {
                                    mouse.accepted = true;
                                    root.closeWindow(modelData);
                                }
                            }
                        }

                        // ── Primary Icon Mouse Area ────────────────────────────
                        MouseArea {
                            id: iconMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

                            onEntered: { root.requestOpen(); root.hovIdx = index; }
                            onExited:  { if (root.hovIdx === index) root.hovIdx = -1; root.requestClose(); }

                            onClicked: function(mouse) {
                                if (mouse.button === Qt.RightButton || mouse.button === Qt.MiddleButton) {
                                    root.closeWindow(modelData);
                                } else {
                                    root.restoreWindow(modelData);
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
