import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io

PopupWindow {
    id: emailsPopup
    property bool show: false
    property var shellRoot
    property var groundControlWindow
    grabFocus: show

    property real savedX: 0
    property real savedY: 0
    property real savedW: 0
    property real savedH: 0

    onShowChanged: {
        if (show && groundControlWindow && groundControlWindow.cardEmails) {
            var pos = groundControlWindow.cardEmails.mapToItem(null, 0, 0);
            savedX = pos.x;
            savedY = pos.y;
            savedW = groundControlWindow.cardEmails.width;
            savedH = groundControlWindow.cardEmails.height;

            pEmailsToday.running = false;
            pEmailsToday.running = true;
        }
    }

    anchor {
        window: groundControlWindow
        rect: Qt.rect(savedX, savedY, savedW, savedH)
        edges: Edges.Right | Edges.Top
        gravity: Edges.Right | Edges.Bottom
    }

    visible: show || animRectEmails.opacity > 0

    implicitWidth: 280
    implicitHeight: 320
    color: "transparent"

    ListModel {
        id: emailsModel
    }

    Process {
        id: pEmailsToday
        command: [shellRoot ? shellRoot.scriptsDir + "/emails_today.py" : ""]
        running: false
        property var tempEmails: []
        stdout: SplitParser {
            onRead: data => {
                var line = data.trim();
                if (line === "")
                    return;
                var parts = line.split('|');
                if (parts.length >= 2) {
                    pEmailsToday.tempEmails.push({
                        sender: parts[0],
                        subject: parts[1]
                    });
                }
            }
        }
        onRunningChanged: {
            if (running) {
                pEmailsToday.tempEmails = [];
            } else {
                emailsModel.clear();
                for (var i = 0; i < pEmailsToday.tempEmails.length; i++) {
                    emailsModel.append(pEmailsToday.tempEmails[i]);
                }
            }
        }
    }

    Item {
        anchors.fill: parent

        Rectangle {
            id: animRectEmails
            anchors.fill: parent
            anchors.leftMargin: 12

            color: Qt.rgba(0.08, 0.08, 0.08, 0.95)
            radius: 16
            border.color: Qt.rgba(1, 1, 1, 0.1)
            border.width: 1

            opacity: emailsPopup.show ? 1.0 : 0.0
            scale: emailsPopup.show ? 1.0 : 0.95
            x: emailsPopup.show ? 0 : 16

            Behavior on opacity {
                SequentialAnimation {
                    PauseAnimation {
                        duration: (shellRoot && shellRoot.batteryMode) ? 0 : (emailsPopup.show ? 80 : 0)
                    }
                    NumberAnimation {
                        duration: (shellRoot && shellRoot.batteryMode) ? 150 : (emailsPopup.show ? 180 : 150)
                        easing.type: emailsPopup.show ? Easing.OutQuad : Easing.InQuad
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
                        text: "󰇮"
                        color: "#007AFF"
                        font.family: shellRoot ? shellRoot.iconFontFamily : "sans-serif"
                        font.pixelSize: 16
                    }
                    Text {
                        text: "Today's Emails"
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
                        font.pixelSize: 12
                        visible: pEmailsToday.running
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
                    model: emailsModel
                    clip: true
                    spacing: 8

                    delegate: ColumnLayout {
                        width: listView.width
                        spacing: 2

                        Text {
                            text: model.sender
                            color: shellRoot ? shellRoot.colFg : "#ffffff"
                            font {
                                family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                                pixelSize: 11
                                bold: true
                            }
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        Text {
                            text: model.subject
                            color: shellRoot ? Qt.rgba(shellRoot.colFg.r, shellRoot.colFg.g, shellRoot.colFg.b, 0.6) : "#99ffffff"
                            font {
                                family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                                pixelSize: 10
                            }
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 1
                            color: Qt.rgba(1, 1, 1, 0.04)
                            visible: index < (emailsModel.count - 1)
                        }
                    }
                }
            }
        }
    }
}
