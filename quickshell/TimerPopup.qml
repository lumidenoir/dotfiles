import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell

PopupWindow {
    id: timerPopup
    property bool show: false
    property var shellRoot
    property var groundControlWindow
    grabFocus: show

    property real savedX: 0
    property real savedY: 0
    property real savedW: 0
    property real savedH: 0

    anchor {
        window: groundControlWindow
        rect: Qt.rect(savedX, savedY, savedW, savedH)
        edges: Edges.Left | Edges.Top
        gravity: Edges.Left | Edges.Bottom
    }

    onShowChanged: {
        if (show) {
            timerInput.text = "";
            timerInput.forceActiveFocus();
            if (groundControlWindow && groundControlWindow.btnTimer) {
                var pos = groundControlWindow.btnTimer.mapToItem(null, 0, 0);
                savedX = pos.x;
                savedY = pos.y;
                savedW = groundControlWindow.btnTimer.width;
                savedH = groundControlWindow.btnTimer.height;
            }
        }
    }
    property real animHeight: animRectTimer.height
    visible: show || animRectTimer.opacity > 0

    implicitWidth: 200
    implicitHeight: layoutTimer.implicitHeight + 32
    color: "transparent"

    Item {
        anchors.fill: parent

        Rectangle {
            id: animRectTimer
            anchors.fill: parent
            anchors.rightMargin: 12

            color: Qt.rgba(0.08, 0.08, 0.08, 0.95)
            radius: 16
            border.color: Qt.rgba(1, 1, 1, 0.1)
            border.width: 1

            opacity: timerPopup.show ? 1.0 : 0.0
            scale: timerPopup.show ? 1.0 : 0.95
            // A-4 FIX: slide in from left (negative x) since popup anchors to left of button
            x: timerPopup.show ? 0 : -16
            Behavior on opacity {
                SequentialAnimation {
                    // Open: let scale/x springs start first, then reveal
                    // Close: exit immediately so springs bounce back behind nothing
                    PauseAnimation {
                        duration: (shellRoot && shellRoot.batteryMode) ? 0 : (timerPopup.show ? 80 : 0)
                    }
                    NumberAnimation {
                        duration: (shellRoot && shellRoot.batteryMode) ? 0 : (timerPopup.show ? 180 : 150)
                        easing.type: timerPopup.show ? Easing.OutQuad : Easing.InQuad
                    }
                }
            }
            Behavior on scale {
                enabled: !(shellRoot && shellRoot.batteryMode)
                // Match damping to x so both settle at the same time
                SpringAnimation {
                    spring: 3.0
                    damping: 0.75
                    mass: 0.9
                }
            }
            Behavior on x {
                enabled: !(shellRoot && shellRoot.batteryMode)
                SpringAnimation {
                    spring: 2.8
                    damping: 0.75
                    mass: 0.9
                }
            }

            ColumnLayout {
                id: layoutTimer
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 16
                spacing: 8
                Text {
                    text: "Timer (MM or MM:SS)"
                    color: shellRoot ? Qt.rgba(shellRoot.colFg.r, shellRoot.colFg.g, shellRoot.colFg.b, 0.5) : "#88ffffff"
                    font.family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                    font.pixelSize: 12
                }

                TextField {
                    id: timerInput
                    Layout.fillWidth: true
                    placeholderText: "e.g. 5 or 1:30"
                    color: shellRoot ? shellRoot.colFg : "#ffffff"
                    background: Rectangle {
                        color: Qt.rgba(1, 1, 1, 0.1)
                        radius: 8
                        border.color: timerInput.activeFocus ? Qt.rgba(1, 1, 1, 0.3) : "transparent"
                    }
                    font.family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                    font.pixelSize: 14
                    onAccepted: {
                        var parts = text.split(":");
                        var totalSeconds = 0;
                        if (parts.length === 2) {
                            var mins = parseInt(parts[0]);
                            var secs = parseInt(parts[1]);
                            if (!isNaN(mins) && !isNaN(secs)) {
                                totalSeconds = (mins * 60) + secs;
                            }
                        } else if (parts.length === 1) {
                            var val = parseInt(parts[0]);
                            if (!isNaN(val)) {
                                totalSeconds = val * 60;
                            }
                        }
                        if (totalSeconds > 0 && shellRoot) {
                            shellRoot.pomodoroState = 0;
                            shellRoot.timerTotal = totalSeconds;
                            shellRoot.timerSeconds = totalSeconds;
                            shellRoot.timerText = shellRoot.formatTime(totalSeconds);
                            shellRoot.timerRunning = true;
                        }
                        timerPopup.show = false;
                    }
                }
            }
        }
    }
}
