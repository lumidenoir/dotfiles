import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: f1CalendarPopup
    anchors.top: true
    anchors.left: true
    anchors.right: true
    anchors.bottom: true
    color: "transparent"

    property bool show: false
    property var shellRoot
    readonly property real fontScale: scaleFactor * (shellRoot ? shellRoot.fontSizeMultiplier : 1.0)
    property var groundControlWindow

    WlrLayershell.keyboardFocus: show ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    WlrLayershell.namespace: "quickshell_widgets"

    property real savedX: 0
    property real savedY: 0
    property real savedW: 0
    property real savedH: 0

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
        id: popupContent
        anchors.fill: parent
        focus: show

        Keys.onEscapePressed: show = false

        MouseArea {
            anchors.fill: parent
            enabled: show
            onClicked: show = false
        }

        Rectangle {
            id: animRectF1
            color: "transparent"
            x: (savedX > 0) ? (savedX - width - Math.round(8 * (shellRoot ? shellRoot.scaleFactor : 1.0))) : (groundControlWindow ? ((groundControlWindow.width - groundControlWindow.targetWidth) / 2 - width - Math.round(12 * (shellRoot ? shellRoot.scaleFactor : 1.0))) : Math.round((parent.width - width) / 2))
            y: (savedY > 0) ? savedY : Math.round((parent.height - height) / 2)
            width: Math.round(280 * (shellRoot ? shellRoot.scaleFactor : 1.0))
            height: Math.round(320 * (shellRoot ? shellRoot.scaleFactor : 1.0))
            radius: Math.round(4 * (shellRoot ? shellRoot.scaleFactor : 1.0))

            opacity: f1CalendarPopup.show ? 1.0 : 0.0
            scale: f1CalendarPopup.show ? 1.0 : 0.98

            Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }

            // SurfaceCard Base (Option B, Zero Shader Overhead)
            SurfaceCard {
                id: f1GlassCard
                anchors.fill: parent
                radius: animRectF1.radius
                contentPadding: 0
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
                        text: "󰞬"
                        color: "#E10600"
                        font.family: shellRoot ? shellRoot.nerdFontFamily : "Symbols Nerd Font"
                        font.pixelSize: 16
                        Layout.alignment: Qt.AlignVCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    Text {
                        text: "F1 Calendar (4 Weeks)"
                        color: shellRoot ? shellRoot.colFg : "#ffffff"
                        font {
                            family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                            pixelSize: 12
                            bold: true
                        }
                        Layout.alignment: Qt.AlignVCenter
                        verticalAlignment: Text.AlignVCenter
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
