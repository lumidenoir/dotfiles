import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

PanelWindow {
    id: rootWindow

    property bool show: false
    property var shellRoot // Reference to the main shell root for colors/fonts
    readonly property real scaleFactor: shellRoot ? shellRoot.scaleFactor : 1.0
    property real animHeight: animRect.height
    property alias animWidth: animRect.width
    property int selectedIndex: 0
    property bool isClosing: false
    property real savedCloseTarget: 120
    // Snap to 32px circle on open, then spring-expand (avoids pop from pill width)
    property bool suppressOpenAnimation: false

    property int pendingAction: -1

    WlrLayershell.keyboardFocus: show ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    WlrLayershell.namespace: "quickshell"

    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    // Visibility managed by isClosing so both phases stay alive
    visible: show || isClosing

    function triggerAction(idx) {
        pendingAction = idx;
        show = false;
        actionTimer.restart();
    }

    Timer {
        id: actionTimer
        interval: 220
        repeat: false
        onTriggered: {
            rootWindow.isClosing = false;
            var act = rootWindow.pendingAction;
            rootWindow.pendingAction = -1;
            if (act === 0) pShutdown.running = true;
            else if (act === 1) pReboot.running = true;
            else if (act === 2) pSuspend.running = true;
            else if (act === 3) pHibernate.running = true;
            else if (act === 4) pLock.running = true;
            else if (act === 5) pLogout.running = true;
        }
    }

    // Safety watchdog: ensures isClosing never stays stuck if sleep/DPMS interrupts animation
    Timer {
        id: closeWatchdog
        interval: 1000
        repeat: false
        onTriggered: {
            if (rootWindow.isClosing) {
                rootWindow.isClosing = false;
            }
        }
    }

    onShowChanged: {
        if (show) {
            isClosing = false;
            closeWatchdog.stop();
            suppressOpenAnimation = true;
            snapResetTimer.start();
            savedCloseTarget = Qt.binding(function() { return shellRoot ? shellRoot.closedNotchWidth : 120; });
            selectedIndex = 0;  // always reset highlight on open
            focusTimer.start();
        } else {
            savedCloseTarget = shellRoot ? shellRoot.closedNotchWidth : 120;
            isClosing = true;
            closeWatchdog.restart();
        }
    }

    Timer {
        id: snapResetTimer
        interval: 32
        repeat: false
        onTriggered: rootWindow.suppressOpenAnimation = false
    }

    Timer {
        id: focusTimer
        interval: 50
        onTriggered: powerMenuContent.forceActiveFocus()
    }

    Item {
        id: powerMenuContent
        anchors.fill: parent
        focus: show
        Keys.onEscapePressed: {
            rootWindow.pendingAction = -1;
            show = false;
        }
        Keys.onLeftPressed: selectedIndex = Math.max(0, selectedIndex - 1)
        Keys.onRightPressed: selectedIndex = Math.min(layout.children.length - 1, selectedIndex + 1)
        Keys.onReturnPressed: rootWindow.triggerAction(selectedIndex)

        MouseArea {
            anchors.fill: parent
            enabled: show
            onClicked: {
                rootWindow.pendingAction = -1;
                show = false;
            }
        }

        Rectangle {
            id: animRect
            anchors.top: parent.top
            anchors.topMargin: 4 * rootWindow.scaleFactor
            anchors.horizontalCenter: parent.horizontalCenter

            // Snap to circle on open, then spring to full size; collapse via isClosing on close
            width: rootWindow.suppressOpenAnimation ? 32 * rootWindow.scaleFactor : rootWindow.show ? (layout.implicitWidth + 48) : (rootWindow.isClosing ? 32 * rootWindow.scaleFactor : savedCloseTarget)
            height: rootWindow.suppressOpenAnimation ? 32 * rootWindow.scaleFactor : rootWindow.show ? (layout.implicitHeight + 36) : (rootWindow.isClosing ? 32 * rootWindow.scaleFactor : 32 * rootWindow.scaleFactor)
            radius: Math.round(4 * (typeof scaleFactor !== "undefined" ? scaleFactor : (typeof s !== "undefined" ? s : 1.0)))
            color: "transparent"

            SurfaceCard {
                id: pmGlassCard
                anchors.fill: parent
                radius: animRect.radius
                contentPadding: 0
            }
            opacity: 1.0

            function checkCloseFinished() {
                if (!rootWindow.show && rootWindow.isClosing) {
                    var sf = rootWindow.scaleFactor;
                    var target = Math.round(32 * sf);
                    if (Math.abs(width - target) < 1.8 && Math.abs(height - target) < 1.8) {
                        rootWindow.isClosing = false;
                        closeWatchdog.stop();
                    }
                }
            }

            onWidthChanged: checkCloseFinished()
            onHeightChanged: checkCloseFinished()

            // Liquid spring animation
            Behavior on radius { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
            Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutBack; easing.overshoot: 1.15 } }
            Behavior on height { NumberAnimation { duration: 250; easing.type: Easing.OutBack; easing.overshoot: 1.15 } }

            Item {
                anchors.fill: parent
                clip: true

                opacity: show ? 1.0 : 0.0
                Behavior on opacity {
                    SequentialAnimation {
                        PauseAnimation { duration: (shellRoot && shellRoot.batteryMode) ? 0 : (show ? 120 : 0) }
                        NumberAnimation {
                            duration: (shellRoot && shellRoot.batteryMode) ? 150 : (show ? 300 : 80)
                            easing.type: show ? Easing.OutQuad : Easing.InQuad
                        }
                    }
                }

                scale: show ? 1.0 : 0.95
                Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }

                RowLayout {
                    id: layout
                    anchors.centerIn: parent
                    spacing: 20

                    // Shutdown
                    Column {
                        spacing: 6
                        Rectangle {
                            width: 50; height: 50; radius: 4
                            anchors.horizontalCenter: parent.horizontalCenter
                            color: (sdMouse.containsMouse || selectedIndex === 0) ? Qt.rgba(1, 0.2, 0.2, 0.85) : ((shellRoot && shellRoot.isPearlMode) ? Qt.rgba(0, 0, 0, 0.06) : Qt.rgba(1, 1, 1, 0.08))
                            border.color: (sdMouse.containsMouse || selectedIndex === 0) ? Qt.rgba(1, 1, 1, 0.3) : ((shellRoot && shellRoot.isPearlMode) ? Qt.rgba(0, 0, 0, 0.10) : Qt.rgba(1, 1, 1, 0.12))
                            border.width: 1
                            scale: (sdMouse.containsMouse || selectedIndex === 0) ? 1.12 : 1.0
                            Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
                            Text { anchors.centerIn: parent; text: "󰐥"; color: (sdMouse.containsMouse || selectedIndex === 0) ? "#ffffff" : (shellRoot ? shellRoot.colFgPrimary : "white"); font.family: shellRoot ? shellRoot.iconFontFamily : "sans-serif"; font.pixelSize: 20 }
                            MouseArea { id: sdMouse; anchors.fill: parent; hoverEnabled: true; onEntered: selectedIndex = 0; onClicked: rootWindow.triggerAction(0) }
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Shut Down"
                            color: shellRoot ? shellRoot.colFgSecondary : "#888888"
                            font.family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                            font.pixelSize: 9
                            font.bold: true
                        }
                    }
                    // Reboot
                    Column {
                        spacing: 6
                        Rectangle {
                            width: 50; height: 50; radius: 4
                            anchors.horizontalCenter: parent.horizontalCenter
                            color: (rbMouse.containsMouse || selectedIndex === 1) ? Qt.rgba(0.2, 0.8, 0.2, 0.85) : ((shellRoot && shellRoot.isPearlMode) ? Qt.rgba(0, 0, 0, 0.06) : Qt.rgba(1, 1, 1, 0.08))
                            border.color: (rbMouse.containsMouse || selectedIndex === 1) ? Qt.rgba(1, 1, 1, 0.3) : ((shellRoot && shellRoot.isPearlMode) ? Qt.rgba(0, 0, 0, 0.10) : Qt.rgba(1, 1, 1, 0.12))
                            border.width: 1
                            scale: (rbMouse.containsMouse || selectedIndex === 1) ? 1.12 : 1.0
                            Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
                            Text { anchors.centerIn: parent; text: "󰑓"; color: (rbMouse.containsMouse || selectedIndex === 1) ? "#ffffff" : (shellRoot ? shellRoot.colFgPrimary : "white"); font.family: shellRoot ? shellRoot.iconFontFamily : "sans-serif"; font.pixelSize: 20 }
                            MouseArea { id: rbMouse; anchors.fill: parent; hoverEnabled: true; onEntered: selectedIndex = 1; onClicked: rootWindow.triggerAction(1) }
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Reboot"
                            color: shellRoot ? shellRoot.colFgSecondary : "#888888"
                            font.family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                            font.pixelSize: 9
                            font.bold: true
                        }
                    }
                    // Suspend
                    Column {
                        spacing: 6
                        Rectangle {
                            width: 50; height: 50; radius: 4
                            anchors.horizontalCenter: parent.horizontalCenter
                            color: (spMouse.containsMouse || selectedIndex === 2) ? Qt.rgba(0.2, 0.4, 1.0, 0.85) : ((shellRoot && shellRoot.isPearlMode) ? Qt.rgba(0, 0, 0, 0.06) : Qt.rgba(1, 1, 1, 0.08))
                            border.color: (spMouse.containsMouse || selectedIndex === 2) ? Qt.rgba(1, 1, 1, 0.3) : ((shellRoot && shellRoot.isPearlMode) ? Qt.rgba(0, 0, 0, 0.10) : Qt.rgba(1, 1, 1, 0.12))
                            border.width: 1
                            scale: (spMouse.containsMouse || selectedIndex === 2) ? 1.12 : 1.0
                            Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
                            Text { anchors.centerIn: parent; text: "󰤄"; color: (spMouse.containsMouse || selectedIndex === 2) ? "#ffffff" : (shellRoot ? shellRoot.colFgPrimary : "white"); font.family: shellRoot ? shellRoot.iconFontFamily : "sans-serif"; font.pixelSize: 20 }
                            MouseArea { id: spMouse; anchors.fill: parent; hoverEnabled: true; onEntered: selectedIndex = 2; onClicked: rootWindow.triggerAction(2) }
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Sleep"
                            color: shellRoot ? shellRoot.colFgSecondary : "#888888"
                            font.family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                            font.pixelSize: 9
                            font.bold: true
                        }
                    }
                    // Hibernate
                    Column {
                        spacing: 6
                        Rectangle {
                            width: 50; height: 50; radius: 4
                            anchors.horizontalCenter: parent.horizontalCenter
                            color: (hbMouse.containsMouse || selectedIndex === 3) ? Qt.rgba(0.2, 0.8, 0.8, 0.85) : ((shellRoot && shellRoot.isPearlMode) ? Qt.rgba(0, 0, 0, 0.06) : Qt.rgba(1, 1, 1, 0.08))
                            border.color: (hbMouse.containsMouse || selectedIndex === 3) ? Qt.rgba(1, 1, 1, 0.3) : ((shellRoot && shellRoot.isPearlMode) ? Qt.rgba(0, 0, 0, 0.10) : Qt.rgba(1, 1, 1, 0.12))
                            border.width: 1
                            scale: (hbMouse.containsMouse || selectedIndex === 3) ? 1.12 : 1.0
                            Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
                            Text { anchors.centerIn: parent; text: "󰒲"; color: (hbMouse.containsMouse || selectedIndex === 3) ? "#ffffff" : (shellRoot ? shellRoot.colFgPrimary : "white"); font.family: shellRoot ? shellRoot.iconFontFamily : "sans-serif"; font.pixelSize: 20 }
                            MouseArea { id: hbMouse; anchors.fill: parent; hoverEnabled: true; onEntered: selectedIndex = 3; onClicked: rootWindow.triggerAction(3) }
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Hibernate"
                            color: shellRoot ? shellRoot.colFgSecondary : "#888888"
                            font.family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                            font.pixelSize: 9
                            font.bold: true
                        }
                    }
                    // Lock
                    Column {
                        spacing: 6
                        Rectangle {
                            width: 50; height: 50; radius: 4
                            anchors.horizontalCenter: parent.horizontalCenter
                            color: (lkMouse.containsMouse || selectedIndex === 4) ? Qt.rgba(0.8, 0.2, 0.8, 0.85) : ((shellRoot && shellRoot.isPearlMode) ? Qt.rgba(0, 0, 0, 0.06) : Qt.rgba(1, 1, 1, 0.08))
                            border.color: (lkMouse.containsMouse || selectedIndex === 4) ? Qt.rgba(1, 1, 1, 0.3) : ((shellRoot && shellRoot.isPearlMode) ? Qt.rgba(0, 0, 0, 0.10) : Qt.rgba(1, 1, 1, 0.12))
                            border.width: 1
                            scale: (lkMouse.containsMouse || selectedIndex === 4) ? 1.12 : 1.0
                            Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
                            Text { anchors.centerIn: parent; text: "󰌾"; color: (lkMouse.containsMouse || selectedIndex === 4) ? "#ffffff" : (shellRoot ? shellRoot.colFgPrimary : "white"); font.family: shellRoot ? shellRoot.iconFontFamily : "sans-serif"; font.pixelSize: 20 }
                            MouseArea { id: lkMouse; anchors.fill: parent; hoverEnabled: true; onEntered: selectedIndex = 4; onClicked: rootWindow.triggerAction(4) }
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Lock"
                            color: shellRoot ? shellRoot.colFgSecondary : "#888888"
                            font.family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                            font.pixelSize: 9
                            font.bold: true
                        }
                    }
                    // Logout
                    Column {
                        spacing: 6
                        Rectangle {
                            width: 50; height: 50; radius: 4
                            anchors.horizontalCenter: parent.horizontalCenter
                            color: (loMouse.containsMouse || selectedIndex === 5) ? Qt.rgba(0.8, 0.8, 0.2, 0.85) : ((shellRoot && shellRoot.isPearlMode) ? Qt.rgba(0, 0, 0, 0.06) : Qt.rgba(1, 1, 1, 0.08))
                            border.color: (loMouse.containsMouse || selectedIndex === 5) ? Qt.rgba(1, 1, 1, 0.3) : ((shellRoot && shellRoot.isPearlMode) ? Qt.rgba(0, 0, 0, 0.10) : Qt.rgba(1, 1, 1, 0.12))
                            border.width: 1
                            scale: (loMouse.containsMouse || selectedIndex === 5) ? 1.12 : 1.0
                            Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
                            Text { anchors.centerIn: parent; text: "󰍃"; color: (loMouse.containsMouse || selectedIndex === 5) ? "#ffffff" : (shellRoot ? shellRoot.colFgPrimary : "white"); font.family: shellRoot ? shellRoot.iconFontFamily : "sans-serif"; font.pixelSize: 20 }
                            MouseArea { id: loMouse; anchors.fill: parent; hoverEnabled: true; onEntered: selectedIndex = 5; onClicked: rootWindow.triggerAction(5) }
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Log Out"
                            color: shellRoot ? shellRoot.colFgSecondary : "#888888"
                            font.family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                            font.pixelSize: 9
                            font.bold: true
                        }
                    }
                }
            }
        }
    }

    Process { id: pShutdown; command: ["systemctl", "poweroff"] }
    Process { id: pReboot; command: ["systemctl", "reboot"] }
    Process { id: pSuspend; command: ["systemctl", "suspend"] }
    Process { id: pHibernate; command: ["systemctl", "hibernate"] }
    Process { id: pLock; command: [shellRoot ? (shellRoot.scriptsDir + "/screenlock.sh") : "screenlock.sh"] }
    Process { id: pLogout; command: ["sh", "-c", "loginctl terminate-session ${XDG_SESSION_ID-}"] }
}
