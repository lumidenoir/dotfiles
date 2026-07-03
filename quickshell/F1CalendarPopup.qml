import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io

PopupWindow {
    id: f1CalendarPopup
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
            pF1FourWeeks.running = false;
            pF1FourWeeks.running = true;
            if (groundControlWindow && groundControlWindow.cardF1) {
                var pos = groundControlWindow.cardF1.mapToItem(null, 0, 0);
                savedX = pos.x;
                savedY = pos.y;
                savedW = groundControlWindow.cardF1.width;
                savedH = groundControlWindow.cardF1.height;
            }
        }
    }

    visible: show || animRectF1.opacity > 0

    implicitWidth: 280
    implicitHeight: 320
    color: "transparent"

    ListModel {
        id: eventsModel
    }

    Process {
        id: pF1FourWeeks
        command: [shellRoot ? shellRoot.scriptsDir + "/f1_checker.py" : "", "--four-weeks"]
        running: false
        property var tempEvents: []
        stdout: SplitParser {
            onRead: data => {
                var line = data.trim();
                if (line === "")
                    return;
                var parts = line.split('|');
                if (parts.length >= 3) {
                    pF1FourWeeks.tempEvents.push({
                        summary: parts[0],
                        time: parts[1],
                        location: parts[2]
                    });
                }
            }
        }
        onRunningChanged: {
            if (running) {
                pF1FourWeeks.tempEvents = [];
            } else {
                eventsModel.clear();
                for (var i = 0; i < pF1FourWeeks.tempEvents.length; i++) {
                    eventsModel.append(pF1FourWeeks.tempEvents[i]);
                }
            }
        }
    }

    Item {
        anchors.fill: parent

        Rectangle {
            id: animRectF1
            anchors.fill: parent
            anchors.rightMargin: 12

            color: Qt.rgba(0.08, 0.08, 0.08, 0.95)
            radius: 16
            border.color: Qt.rgba(1, 1, 1, 0.1)
            border.width: 1

            opacity: f1CalendarPopup.show ? 1.0 : 0.0
            scale: f1CalendarPopup.show ? 1.0 : 0.95
            x: f1CalendarPopup.show ? 0 : -16

            Behavior on opacity {
                SequentialAnimation {
                    PauseAnimation {
                        duration: (shellRoot && shellRoot.batteryMode) ? 0 : ((shellRoot && !shellRoot.batteryCharging) ? (f1CalendarPopup.show ? 48 : 0) : (f1CalendarPopup.show ? 80 : 0))
                    }
                    NumberAnimation {
                        duration: (shellRoot && shellRoot.batteryMode) ? 100 : ((shellRoot && !shellRoot.batteryCharging) ? (f1CalendarPopup.show ? 108 : 90) : (f1CalendarPopup.show ? 180 : 150))
                        easing.type: f1CalendarPopup.show ? Easing.OutQuad : Easing.InQuad
                    }
                }
            }
            Behavior on scale {
                enabled: true
                SpringAnimation {
                    spring: 3.0
                    damping: 0.75
                    mass: 0.9
                }
            }
            Behavior on x {
                enabled: true
                SpringAnimation {
                    spring: 2.8
                    damping: 0.75
                    mass: 0.9
                }
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 10

                // Header
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Text {
                        text: "󰛄"
                        color: "#E10600"
                        font.family: shellRoot ? shellRoot.iconFontFamily : "sans-serif"
                        font.pixelSize: 16
                    }
                    Text {
                        text: "F1 Calendar (4 Weeks)"
                        color: shellRoot ? shellRoot.colFg : "#ffffff"
                        font {
                            family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                            pixelSize: 12
                            bold: true
                        }
                    }
                    Item {
                        Layout.fillWidth: true
                    }

                    // Loading indicator
                    Text {
                        text: "loading..."
                        color: shellRoot ? shellRoot.colMuted : "#88ffffff"
                        font.family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                        font.pixelSize: 10
                        visible: pF1FourWeeks.running
                    }
                }

                // Divider
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: Qt.rgba(1, 1, 1, 0.08)
                }

                // List View
                ListView {
                    id: listView
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    model: eventsModel
                    clip: true
                    spacing: 8

                    delegate: ColumnLayout {
                        width: listView.width
                        spacing: 2

                        Text {
                            text: model.summary
                            color: shellRoot ? shellRoot.colFg : "#ffffff"
                            font {
                                family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                                pixelSize: 10
                                bold: true
                            }
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 4
                            Text {
                                text: model.time
                                color: shellRoot ? Qt.rgba(shellRoot.colFg.r, shellRoot.colFg.g, shellRoot.colFg.b, 0.6) : "#99ffffff"
                                font {
                                    family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                                    pixelSize: 8
                                }
                            }
                            Item {
                                Layout.fillWidth: true
                            }
                            Text {
                                text: "📍 " + model.location
                                color: shellRoot ? Qt.rgba(shellRoot.colFg.r, shellRoot.colFg.g, shellRoot.colFg.b, 0.6) : "#99ffffff"
                                font {
                                    family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                                    pixelSize: 8
                                }
                                elide: Text.ElideRight
                                Layout.maximumWidth: 110
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 1
                            color: Qt.rgba(1, 1, 1, 0.04)
                            visible: index < (eventsModel.count - 1)
                        }
                    }
                }
            }
        }
    }
}
