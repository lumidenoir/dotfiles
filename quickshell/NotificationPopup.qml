import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Widgets

PanelWindow {
    id: notifPopup
    property var shellRoot
    readonly property real fontScale: scaleFactor * (shellRoot ? shellRoot.fontSizeMultiplier : 1.0)
    
    anchors.top: true
    anchors.left: true
    anchors.right: true
    implicitWidth: 380
    implicitHeight: 168
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    visible: (shellRoot && shellRoot.notifActive) || notifRect.opacity > 0.01

    Connections {
        target: shellRoot ? shellRoot : null
        function onNotifActiveChanged() {
            if (shellRoot && shellRoot.notifActive) {
            } else {
            }
        }
    }


    Rectangle {
        id: notifRect
        color: "transparent"
        anchors.horizontalCenter: parent.horizontalCenter
        y: (shellRoot && shellRoot.notifActive) ? ((shellRoot && shellRoot.topHuggingStyle) ? 48 : 52) : -height

        // --- Option B Tactical Monospace Notification Frame ---
        radius: 4
        width: 360
        
        property bool hasActions: shellRoot ? shellRoot.notifHasActions : false
        height: Math.max(72, Math.min(160, 44 + bodyText.implicitHeight + (hasActions ? 32 : 0)))
        opacity: (shellRoot && shellRoot.notifActive) ? 1.0 : 0.0

        Behavior on y {
            NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 1.15 }
        }
        Behavior on opacity {
            NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
        }

        transform: Translate {
            id: dragTranslate
            x: 0
            Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
        }

        Connections {
            target: shellRoot
            function onNotifActiveChanged() {
                if (shellRoot && !shellRoot.notifActive) {
                    resetPosTimer.restart();
                }
            }
        }

        Timer {
            id: resetPosTimer
            interval: 300
            onTriggered: dragTranslate.x = 0
        }

        DragHandler {
            target: null
            xAxis.enabled: true
            yAxis.enabled: false
            onActiveTranslationChanged: {
                if (active) {
                    dragTranslate.x = activeTranslation.x;
                }
            }
            onActiveChanged: {
                if (!active) {
                    // DPI-aware swipe threshold
                    var threshold = 80 * (shellRoot ? shellRoot.scaleFactor : 1.0);
                    if (Math.abs(activeTranslation.x) > threshold) {
                        // Fly card off-screen in swipe direction before dismissing
                        var flyDir = activeTranslation.x > 0 ? 1 : -1;
                        dragTranslate.x = flyDir * 320;
                        if (shellRoot) {
                            shellRoot.dismissFrontNotification();
                            shellRoot.notifCloseTimer.stop();
                        }
                    } else {
                        dragTranslate.x = 0;
                    }
                }
            }
        }

        // --- Inner solid black glass body (1px inset from bevel) ---
        Rectangle {
            id: notifBody
            anchors.fill: parent
            anchors.margins: 0
            radius: parent.radius
            color: "transparent"
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.08)

            // SurfaceCard Base (Option B, Zero Shader Overhead)
            SurfaceCard {
                id: notifGlassCard
                anchors.fill: parent
                radius: notifBody.radius
                contentPadding: 0
            }
            // Click to trigger default action and dismiss popup
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: mouse => {
                    if (shellRoot && shellRoot.currentNotifId !== null) {
                        if (mouse.button === Qt.LeftButton) {
                            shellRoot.invokeNotificationAction(shellRoot.currentNotifId, "default");
                        } else {
                            shellRoot.dismissNotificationSafely(shellRoot.currentNotifId);
                        }
                        shellRoot.notifCloseTimer.stop();
                    }
                }
            }

            // Close / Dismiss Button
            MouseArea {
                id: closeBtn
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: 6
                width: 20
                height: 20
                z: 30
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor

                Rectangle {
                    anchors.fill: parent
                    radius: 2
                    color: parent.containsMouse ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(1, 1, 1, 0.08)
                    border.color: parent.containsMouse ? Qt.rgba(1, 1, 1, 0.35) : Qt.rgba(1, 1, 1, 0.12)
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 100 } }

                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        color: parent.parent.containsMouse ? "#ffffff" : Qt.rgba(1, 1, 1, 0.6)
                        font { pixelSize: 9; bold: true }
                    }
                }

                onClicked: {
                    if (shellRoot) {
                        shellRoot.dismissFrontNotification();
                        shellRoot.notifCloseTimer.stop();
                    }
                }
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                RowLayout {
                    id: notifContentRow
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 10
                    opacity: 1.0

                    Item {
                        width: 36
                        height: 36
                        Layout.alignment: Qt.AlignVCenter
                        clip: false

                        // Arc countdown ring
                        Canvas {
                            id: timerArc
                            anchors.centerIn: parent
                            width: parent.width + 8
                            height: parent.height + 8

                            property real progress: shellRoot ? shellRoot.notifProgress : 1.0
                            property color arcColor: shellRoot ? shellRoot.colAccent : "#0A84FF"

                            onProgressChanged: requestPaint()
                            onArcColorChanged: requestPaint()

                            onPaint: {
                                var ctx = getContext("2d");
                                ctx.clearRect(0, 0, width, height);

                                var cx = width / 2;
                                var cy = height / 2;
                                var r = Math.min(cx, cy) - 1.5;

                                // Track
                                ctx.beginPath();
                                ctx.arc(cx, cy, r, 0, Math.PI * 2);
                                ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.06);
                                ctx.lineWidth = 1.5;
                                ctx.stroke();

                                // Filled arc (clockwise depletion: starts top, shrinks)
                                var startAngle = -Math.PI / 2;
                                var endAngle = startAngle + progress * Math.PI * 2;
                                if (progress > 0.005) {
                                    ctx.beginPath();
                                    ctx.arc(cx, cy, r, startAngle, endAngle);
                                    ctx.strokeStyle = arcColor;
                                    ctx.lineWidth = 1.5;
                                    ctx.lineCap = "round";
                                    ctx.stroke();
                                }
                            }
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: 4
                            color: Qt.rgba(1, 1, 1, 0.08)
                            clip: true

                            IconImage {
                                id: popupIconImg
                                anchors.fill: parent
                                anchors.margins: 4
                                source: (shellRoot && (shellRoot.notifIcon.indexOf("/") !== -1 || shellRoot.notifIcon.indexOf("file://") === 0)) ? shellRoot.notifIcon : (shellRoot && shellRoot.notifIcon !== "" ? "icon:" + shellRoot.notifIcon : "")
                                visible: shellRoot && shellRoot.notifIcon !== ""
                            }

                            Text {
                                anchors.centerIn: parent
                                text: "󰂚"
                                color: shellRoot ? shellRoot.colFg : "white"
                                font { family: shellRoot ? shellRoot.iconFontFamily : "sans-serif"; pixelSize: 18 }
                                visible: !popupIconImg.visible
                            }
                        }

                        // Badge count overlay
                        Rectangle {
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.topMargin: -6
                            anchors.rightMargin: -6
                            width: 16
                            height: 16
                            radius: 2
                            color: shellRoot ? shellRoot.colAccent : "#0A84FF"
                            border.color: shellRoot ? shellRoot.colBg : "#000000"
                            border.width: 1.5
                            visible: shellRoot && shellRoot.currentNotifGroup && shellRoot.currentNotifGroup.notifications.length > 1

                            Text {
                                anchors.centerIn: parent
                                text: shellRoot && shellRoot.currentNotifGroup ? shellRoot.currentNotifGroup.notifications.length : ""
                                color: "#ffffff"
                                font { family: shellRoot ? shellRoot.fontFamily : "sans-serif"; pixelSize: 9; bold: true }
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 3

                        Text {
                            text: (shellRoot && shellRoot.notifTitle !== "") ? shellRoot.notifTitle : "Notification"
                            color: shellRoot ? shellRoot.colFg : "white"
                            font { family: shellRoot ? shellRoot.fontFamily : "sans-serif"; pixelSize: 12; bold: true }
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Text {
                            id: bodyText
                            text: shellRoot ? shellRoot.notifBody : ""
                            color: shellRoot ? shellRoot.colMuted : "gray"
                            font { family: shellRoot ? shellRoot.fontFamily : "sans-serif"; pixelSize: 10 }
                            elide: Text.ElideRight
                            wrapMode: Text.Wrap
                            maximumLineCount: 3
                            Layout.fillWidth: true
                        }
                    }
                }

                RowLayout {
                    id: popupActionsRow
                    visible: notifRect.hasActions
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredHeight: visible ? 24 : 0
                    spacing: 8

                    Repeater {
                        model: (shellRoot && shellRoot.notifActions) ? shellRoot.notifActions : null
                        delegate: MouseArea {
                            id: btn
                            implicitWidth: lbl.implicitWidth + 20
                            implicitHeight: 22
                            hoverEnabled: true

                            Rectangle {
                                anchors.fill: parent
                                radius: 4
                                color: parent.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(1, 1, 1, 0.08)
                                border.color: Qt.rgba(1, 1, 1, 0.1)
                                border.width: 1
                            }

                            Text {
                                id: lbl
                                anchors.centerIn: parent
                                text: modelData.text
                                color: (notifPopup.shellRoot) ? notifPopup.shellRoot.colFg : "white"
                                font { family: (notifPopup.shellRoot) ? notifPopup.shellRoot.fontFamily : "sans-serif"; pixelSize: 9; bold: true }
                            }

                            onClicked: {
                                if (notifPopup.shellRoot && notifPopup.shellRoot.currentNotifId !== null) {
                                    notifPopup.shellRoot.invokeNotificationAction(notifPopup.shellRoot.currentNotifId, modelData.identifier);
                                    notifPopup.shellRoot.notifCloseTimer.stop();
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Connections {
        target: shellRoot ? shellRoot : null
        ignoreUnknownSignals: true
        function onNotifTitleChanged() { triggerNotifFade(); }
        function onNotifBodyChanged() { triggerNotifFade(); }
        function onNotificationReceived() { triggerNotifFade(); }
    }

    function triggerNotifFade() {
        if (shellRoot && shellRoot.notifActive) {
            notifFadeAnim.restart();
        }
    }

    SequentialAnimation {
        id: notifFadeAnim
        NumberAnimation { target: notifContentRow; property: "opacity"; to: 0.0; duration: 100; easing.type: Easing.InQuad }
        PropertyAction { target: notifContentRow; property: "opacity"; value: 0.0 }
        NumberAnimation { target: notifContentRow; property: "opacity"; to: 1.0; duration: 180; easing.type: Easing.OutQuad }
    }
}
