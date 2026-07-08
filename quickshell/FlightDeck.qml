import Quickshell
import QtQuick
import QtQuick.Layouts
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick.Controls

PanelWindow {
    id: flightDeckWindow

    // Anchor to the bottom edge of the screen
    anchors.bottom: true
    anchors.left: true
    anchors.right: true

    // Dynamic height: expands when open, and stays tall during the sliding animation to prevent clipping glitches
    implicitHeight: (panelOpen || popupPanel.y < Math.round(190 * scaleFactor)) ? Math.round(200 * scaleFactor) : Math.round(8 * scaleFactor)
    color: "transparent"

    // Overlay layer: floats above all windows without affecting their layout
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "flight_deck"
    WlrLayershell.exclusiveZone: 0   // Don't steal space from tiling layouts
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    property var shellRoot: null
    property real scaleFactor: shellRoot ? shellRoot.scaleFactor : 1.0
    property var minimizedClients: []

    // Hover tracking with closing delay to prevent glitches
    property bool hovered: false
    property bool panelOpen: false

    onHoveredChanged: {
        if (hovered) {
            closeTimer.stop();
            panelOpen = true;
        } else {
            closeTimer.restart();
        }
    }

    Timer {
        id: closeTimer
        interval: 350 // Deliberate debounce prevents accidental re-open on quick mouse leave+re-enter
        repeat: false
        onTriggered: {
            flightDeckWindow.panelOpen = false;
        }
    }

    // ── Live window event listener (replaces polling) ──────────────────────────
    // Listens to socket2 for movewindow/minimized events and refreshes only when needed.
    // Falls back to a one-shot timer if the socket exits unexpectedly.
    Process {
        id: pDeckEvents
        command: ["sh", "-c",
            "socat - UNIX-CONNECT:/tmp/hypr/${HYPRLAND_INSTANCE_SIGNATURE}/.socket2.sock 2>/dev/null"]
        running: true
        stdout: SplitParser {
            onRead: function(data) {
                var ev = data.trim().split(">>")[0];
                if (ev === "openwindow" || ev === "closewindow" ||
                    ev === "movewindow" || ev === "createworkspace" ||
                    ev === "closeworkspace" || ev === "minimizewindow") {
                    pGetClients.running = true;
                }
            }
        }
        // Auto-restart on socket disconnect
        onExited: {
            pDeckRestartTimer.restart();
        }
    }
    Timer {
        id: pDeckRestartTimer
        interval: 750
        repeat: false
        onTriggered: { pDeckEvents.running = true; pGetClients.running = true; }
    }

    // Initial load and workspace-switch refresh
    Component.onCompleted: pGetClients.running = true
    Connections {
        target: Hyprland
        function onFocusedWorkspaceChanged() { pGetClients.running = true }
    }

    Process {
        id: pGetClients
        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var all = JSON.parse(text.trim());
                    var mins = [];
                    for (var i = 0; i < all.length; i++) {
                        var c = all[i];
                        if (c.workspace.name === "special:minimized" && c.mapped) {
                            mins.push(c);
                        }
                    }
                    flightDeckWindow.minimizedClients = mins;
                } catch(e) {
                    flightDeckWindow.minimizedClients = [];
                }
            }
        }
    }

    Item {
        anchors.fill: parent

        HoverHandler {
            id: windowHover
            onHoveredChanged: {
                flightDeckWindow.hovered = windowHover.hovered;
            }
        }

        // ── Closed Indicator Handle (horizontal, visible when collapsed and windows are minimized) ──
        Rectangle {
            visible: !flightDeckWindow.panelOpen && flightDeckWindow.minimizedClients.length > 0
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Math.round(2 * scaleFactor)
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.round(80 * scaleFactor)
            height: Math.round(4 * scaleFactor)
            radius: Math.round(2 * scaleFactor)
            color: Qt.rgba(1, 1, 1, 0.20)
            border.color: Qt.rgba(1, 1, 1, 0.15)
            border.width: 1
        }

        // ── Pulsing Blue Indicator Strip (horizontal, visible when collapsed and windows are minimized) ──
        Rectangle {
            id: blueIndicator
            visible: !flightDeckWindow.panelOpen && flightDeckWindow.minimizedClients.length > 0
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Math.round(2 * scaleFactor)
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.round(28 * scaleFactor)
            height: Math.round(4 * scaleFactor)
            radius: Math.round(2 * scaleFactor)
            color: "#007AFF"
            opacity: 0.85

            // Slow breathing pulse animation
            SequentialAnimation on opacity {
                loops: Animation.Infinite
                running: blueIndicator.visible
                NumberAnimation { from: 0.40; to: 0.95; duration: 1600; easing.type: Easing.InOutSine }
                NumberAnimation { from: 0.95; to: 0.40; duration: 1600; easing.type: Easing.InOutSine }
            }
        }

        // ── Sliding popup panel (rendered outside the 8px strip via y offset) ────
        Rectangle {
            id: popupPanel

            y: flightDeckWindow.panelOpen
               ? Math.round(80 * scaleFactor)
               : Math.round(200 * scaleFactor) + Math.round(10 * scaleFactor)

            anchors.horizontalCenter: parent.horizontalCenter
            height: Math.round(112 * scaleFactor)
            width: Math.round(520 * scaleFactor)

            radius: Math.round(16 * scaleFactor)
            clip: false

            // Glassmorphic background
            color: Qt.rgba(0.05, 0.05, 0.08, 0.88)
            border.color: Qt.rgba(1, 1, 1, 0.08)
            border.width: 1

            // Smooth spring sliding animation
            Behavior on y {
                SpringAnimation {
                    spring: 4.8
                    damping: 0.82
                    mass: 0.55
                }
            }

            // Opacity fade to match the slide animation
            opacity: flightDeckWindow.panelOpen ? 1.0 : 0.0
            Behavior on opacity {
                NumberAnimation {
                    duration: 180
                    easing.type: Easing.OutQuad
                }
            }

            // ── Empty state ────────────────────────────────────────────────────
            Row {
                anchors.centerIn: parent
                visible: flightDeckWindow.minimizedClients.length === 0
                         && flightDeckWindow.panelOpen
                spacing: Math.round(8 * scaleFactor)

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "~"
                    color: Qt.rgba(1, 1, 1, 0.20)
                    font.pixelSize: Math.round(25 * scaleFactor)
                    font.family: shellRoot ? shellRoot.iconFontFamily : "monospace"
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "DECK EMPTY"
                    color: Qt.rgba(1, 1, 1, 0.25)
                    font {
                        family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                        pixelSize: Math.round(9 * scaleFactor)
                        bold: true
                    }
                    horizontalAlignment: Text.AlignHCenter
                }
            }

            // ── Window cards ───────────────────────────────────────────────────
            ScrollView {
                anchors.fill: parent
                anchors.margins: Math.round(8 * scaleFactor)
                visible: flightDeckWindow.minimizedClients.length > 0
                ScrollBar.horizontal.policy: ScrollBar.AsNeeded
                ScrollBar.vertical.policy: ScrollBar.AlwaysOff
                clip: false

                Row {
                    height: parent.height
                    spacing: Math.round(10 * scaleFactor)
                    anchors.verticalCenter: parent.verticalCenter

                    // Header
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Deck"
                        color: Qt.rgba(1, 1, 1, 0.32)
                        font {
                            family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                            pixelSize: Math.round(8 * scaleFactor)
                            capitalization: Font.AllUppercase
                            letterSpacing: 0.8
                            bold: true
                        }
                        rightPadding: Math.round(4 * scaleFactor)
                    }

                    Repeater {
                        model: flightDeckWindow.minimizedClients
                        delegate: Rectangle {
                            id: card
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.round(78 * scaleFactor)
                            height: Math.round(78 * scaleFactor)
                            radius: Math.round(12 * scaleFactor)

                            color: cardMouse.containsMouse
                                   ? Qt.rgba(1, 1, 1, 0.12)
                                   : Qt.rgba(1, 1, 1, 0.05)
                            border.color: cardMouse.containsMouse
                                          ? Qt.rgba(0.0, 0.48, 1.0, 0.65) // Sleek blue border
                                          : Qt.rgba(1, 1, 1, 0.06)
                            border.width: 1

                            // High quality spring scale animations for the card
                            scale: cardMouse.containsPress ? 0.90 : (cardMouse.containsMouse ? 1.05 : 1.0)

                            Behavior on scale {
                                SpringAnimation { spring: 5.0; damping: 0.7; mass: 0.6 }
                            }
                            Behavior on color { ColorAnimation { duration: 120 } }

                            Column {
                                anchors.centerIn: parent
                                spacing: Math.round(4 * scaleFactor)

                                Image {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: Math.round(28 * scaleFactor)
                                    height: Math.round(28 * scaleFactor)
                                    source: "image://icon/" + modelData.class.toLowerCase()
                                    fillMode: Image.PreserveAspectFit
                                    smooth: true

                                    // Dynamic scale bounce on the app icon on hover
                                    scale: cardMouse.containsMouse ? 1.15 : 1.0
                                    Behavior on scale {
                                        SpringAnimation { spring: 4.5; damping: 0.65; mass: 0.6 }
                                    }
                                }

                                Text {
                                    width: Math.round(66 * scaleFactor)
                                    text: {
                                        var p = modelData.class.split(".");
                                        var n = p[p.length - 1];
                                        return n.charAt(0).toUpperCase() + n.slice(1);
                                    }
                                    color: cardMouse.containsMouse
                                           ? "#FFFFFF"
                                           : Qt.rgba(1, 1, 1, 0.60)
                                    font {
                                        family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                                        pixelSize: Math.round(9 * scaleFactor)
                                        bold: true
                                    }
                                    elide: Text.ElideRight
                                    horizontalAlignment: Text.AlignHCenter
                                }
                            }

                            MouseArea {
                                id: cardMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    var ws = Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1;
                                    Hyprland.dispatch("hl.dsp.window.move({ workspace = \"" + ws + "\", window = \"address:" + modelData.address + "\" })");
                                    pGetClients.running = true;
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
