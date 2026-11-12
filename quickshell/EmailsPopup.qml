import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: emailsPopup
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
            if (groundControlWindow && groundControlWindow.cardEmails) {
                var pos = groundControlWindow.cardEmails.mapToItem(null, 0, 0);
                savedX = pos.x;
                savedY = pos.y;
                savedW = groundControlWindow.cardEmails.width;
                savedH = groundControlWindow.cardEmails.height;
            }
            pEmailsToday.running = false;
            pEmailsToday.running = true;
        }
    }

    visible: show || animRectEmails.opacity > 0

    ListModel {
        id: emailsModel
    }

    Process {
        id: pEmailsToday
        command: shellRoot ? ["python3", shellRoot.scriptsDir + "/emails_today.py"] : []
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
            id: animRectEmails
            color: "transparent"
            x: (savedX > 0) ? (savedX + savedW + Math.round(8 * (shellRoot ? shellRoot.scaleFactor : 1.0))) : (groundControlWindow ? (((groundControlWindow.width - groundControlWindow.targetWidth) / 2) + groundControlWindow.targetWidth + Math.round(12 * (shellRoot ? shellRoot.scaleFactor : 1.0))) : Math.round((parent.width - width) / 2))
            y: (savedY > 0) ? savedY : Math.round((parent.height - height) / 2)
            width: Math.round(280 * (shellRoot ? shellRoot.scaleFactor : 1.0))
            height: Math.round(320 * (shellRoot ? shellRoot.scaleFactor : 1.0))
            radius: Math.round(4 * (shellRoot ? shellRoot.scaleFactor : 1.0))

            opacity: emailsPopup.show ? 1.0 : 0.0
            scale: emailsPopup.show ? 1.0 : 0.98

            Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }

            // SurfaceCard Base (Option B, Zero Shader Overhead)
            SurfaceCard {
                id: emailsGlassCard
                anchors.fill: parent
                radius: animRectEmails.radius
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
                        text: "󰇮"
                        color: "#007AFF"
                        font.family: shellRoot ? shellRoot.iconFontFamily : "sans-serif"
                        font.pixelSize: 16
                    }
                    Text {
                        text: "Recent Emails"
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
                            maximumLineCount: 1
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
                            maximumLineCount: 1
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
