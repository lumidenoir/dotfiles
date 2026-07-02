import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Widgets

PanelWindow {
    id: notifPopup
    property var shellRoot
    
    anchors.top: true
    implicitWidth: 380
    implicitHeight: 168
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // C-5 FIX: removed y-position guard — spring overshoot kept the window alive
    // (and blocking input) even after the notif appeared to have slid off screen.
    // Opacity > 0.01 is the reliable "animation still running" signal.
    visible: (shellRoot && shellRoot.notifActive) || notifRect.opacity > 0.01

    Rectangle {
        id: notifRect
        anchors.horizontalCenter: parent.horizontalCenter
        y: (shellRoot && shellRoot.notifActive) ? ((shellRoot && shellRoot.topHuggingStyle) ? 48 : 52) : -height

        width: 360
        
        property bool hasActions: shellRoot && shellRoot.currentNotif && shellRoot.currentNotif.actions && shellRoot.currentNotif.actions.length > 0
        height: Math.max(72, Math.min(160, 44 + bodyText.implicitHeight + (hasActions ? 32 : 0)))

        color: Qt.rgba(0.04, 0.04, 0.04, 0.96)
        radius: 18
        border.color: Qt.rgba(1, 1, 1, borderAlpha)
        border.width: 1

        property real borderAlpha: 0.3
        SequentialAnimation on borderAlpha {
            loops: Animation.Infinite
            running: shellRoot && shellRoot.notifActive
            NumberAnimation { to: 0.6; duration: 1200; easing.type: Easing.InOutSine }
            NumberAnimation { to: 0.2; duration: 1200; easing.type: Easing.InOutSine }
        }

        opacity: (shellRoot && shellRoot.notifActive) ? 1.0 : 0.0
        clip: true

        Behavior on y {
            enabled: shellRoot ? !shellRoot.batteryMode : true
            SpringAnimation { spring: 4.0; damping: 0.75 }
        }
        Behavior on opacity {
            NumberAnimation { duration: 200 }
        }

        // Shimmer Sweep Overlay on Entry
        Rectangle {
            id: entryShimmer
            width: 80
            height: parent.height * 2
            y: -parent.height / 2
            rotation: 25
            visible: shimmerAnim.running

            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.15) }
                GradientStop { position: 1.0; color: "transparent" }
            }

            NumberAnimation on x {
                id: shimmerAnim
                from: -150
                to: notifRect.width + 150
                duration: 900
                easing.type: Easing.InOutSine
                running: false
            }
        }

        Connections {
            target: shellRoot
            function onNotifActiveChanged() {
                if (shellRoot && shellRoot.notifActive && !shellRoot.batteryMode) {
                    shimmerAnim.restart();
                }
                if (shellRoot && !shellRoot.notifActive) {
                    resetPosTimer.restart();
                    notifRect.borderAlpha = 0.3;
                }
            }
        }

        Timer {
            id: resetPosTimer
            interval: 300
            onTriggered: dragTranslate.x = 0
        }

        transform: Translate {
            id: dragTranslate
            x: 0
            Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
        }

        DragHandler {
            target: null
            xAxis.enabled: true
            yAxis.enabled: false
            onActiveTranslationChanged: {
                if (active) {
                    if (activeTranslation.x > 0) dragTranslate.x = activeTranslation.x;
                }
            }
            onActiveChanged: {
                if (!active) {
                    if (activeTranslation.x > 80) {
                        if (shellRoot) {
                            shellRoot.notifActive = false;
                            shellRoot.notifCloseTimer.stop();
                        }
                    } else {
                        dragTranslate.x = 0;
                    }
                }
            }
        }

        // Click to trigger default action and dismiss popup
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: mouse => {
                if (shellRoot) {
                    if (mouse.button === Qt.LeftButton && shellRoot.currentNotif) {
                        shellRoot.currentNotif.invokeAction("default");
                    }
                    shellRoot.notifActive = false;
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

                Rectangle {
                    width: 36
                    height: 36
                    radius: 10
                    color: Qt.rgba(1, 1, 1, 0.08)
                    Layout.alignment: Qt.AlignVCenter
                    clip: true

                    IconImage {
                        id: popupIconImg
                        anchors.fill: parent
                        source: shellRoot ? shellRoot.notifIcon : ""
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
                    model: (shellRoot && shellRoot.currentNotif) ? shellRoot.currentNotif.actions : null
                    delegate: MouseArea {
                        id: btn
                        implicitWidth: lbl.implicitWidth + 20
                        implicitHeight: 22
                        hoverEnabled: true

                        Rectangle {
                            anchors.fill: parent
                            radius: 6
                            color: parent.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(1, 1, 1, 0.08)
                            border.color: Qt.rgba(1, 1, 1, 0.1)
                            border.width: 1
                        }

                        Text {
                            id: lbl
                            anchors.centerIn: parent
                            text: modelData.text
                            color: shellRoot ? shellRoot.colFg : "white"
                            font { family: shellRoot ? shellRoot.fontFamily : "sans-serif"; pixelSize: 9; bold: true }
                        }

                        onClicked: {
                            if (shellRoot && shellRoot.currentNotif) {
                                shellRoot.currentNotif.invokeAction(modelData.identifier);
                                shellRoot.notifActive = false;
                                shellRoot.notifCloseTimer.stop();
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
