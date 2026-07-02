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
    // Snap to 36px circle on open, then spring-expand (avoids pop from pill width)
    property bool suppressOpenAnimation: false

    WlrLayershell.keyboardFocus: show ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    // Visibility managed by isClosing so both phases stay alive
    visible: show || isClosing

    onShowChanged: {
        if (show) {
            isClosing = false;
            suppressOpenAnimation = true;
            snapResetTimer.start();
            savedCloseTarget = Qt.binding(function() { return shellRoot ? shellRoot.closedNotchWidth : 120; });
            selectedIndex = 0;  // always reset highlight on open
            focusTimer.start();
        } else {
            savedCloseTarget = shellRoot ? shellRoot.closedNotchWidth : 120;
            isClosing = true;
        }
    }

    Timer {
        id: snapResetTimer
        interval: 16
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
        Keys.onEscapePressed: show = false
        Keys.onLeftPressed: selectedIndex = Math.max(0, selectedIndex - 1)
        Keys.onRightPressed: selectedIndex = Math.min(layout.children.length - 1, selectedIndex + 1)
        Keys.onReturnPressed: {
            show = false;
            if (selectedIndex === 0) pShutdown.running = true;
            else if (selectedIndex === 1) pReboot.running = true;
            else if (selectedIndex === 2) pSuspend.running = true;
            else if (selectedIndex === 3) pHibernate.running = true;
            else if (selectedIndex === 4) pLock.running = true;
            else if (selectedIndex === 5) pLogout.running = true;
        }

        MouseArea {
            anchors.fill: parent
            enabled: show
            onClicked: show = false
        }

        Rectangle {
            id: animRect
            anchors.top: parent.top
            anchors.topMargin: 4 * rootWindow.scaleFactor
            anchors.horizontalCenter: parent.horizontalCenter

            // Snap to circle on open, then spring to full size; collapse via isClosing on close
            width: rootWindow.suppressOpenAnimation ? 36 * rootWindow.scaleFactor : rootWindow.show ? (layout.implicitWidth + 48) : (rootWindow.isClosing ? 36 * rootWindow.scaleFactor : savedCloseTarget)

            height: rootWindow.suppressOpenAnimation ? 36 * rootWindow.scaleFactor : rootWindow.show ? (layout.implicitHeight + 36) : (rootWindow.isClosing ? 36 * rootWindow.scaleFactor : 40 * rootWindow.scaleFactor)

            color: Qt.rgba(0.02, 0.02, 0.02, 1.0)
            
            radius: rootWindow.suppressOpenAnimation ? 18 * rootWindow.scaleFactor : (rootWindow.show ? 24 * rootWindow.scaleFactor : (rootWindow.isClosing ? 18 * rootWindow.scaleFactor : 20 * rootWindow.scaleFactor))
            border.color: Qt.rgba(1, 1, 1, 0.08)
            border.width: 1

            // Shape always opaque during animation; window hide is via isClosing
            opacity: 1.0

            function checkCloseFinished() {
                if (!rootWindow.show && rootWindow.isClosing) {
                    var sf = rootWindow.scaleFactor;
                    var targetWidth = 36 * sf;
                    var targetHeight = 36 * sf;
                    if (Math.abs(width - targetWidth) < 1.0 && Math.abs(height - targetHeight) < 1.0) {
                        rootWindow.isClosing = false;
                    }
                }
            }

            onWidthChanged: checkCloseFinished()
            onHeightChanged: checkCloseFinished()

            // Shape springs — coherent mass feel (Dynamic Island)
            Behavior on radius {
                enabled: (show || isClosing) && !(shellRoot && shellRoot.batteryMode)
                SpringAnimation { spring: 4.8; damping: 0.8; mass: 0.6 }
            }
            Behavior on width {
                enabled: !rootWindow.suppressOpenAnimation && (show || isClosing) && !(shellRoot && shellRoot.batteryMode)
                SpringAnimation { spring: 4.8; damping: 0.8; mass: 0.6 }
            }
            Behavior on height {
                enabled: !rootWindow.suppressOpenAnimation && (show || isClosing) && !(shellRoot && shellRoot.batteryMode)
                SpringAnimation { spring: 4.8; damping: 0.8; mass: 0.6 }
            }

            Item {
                anchors.fill: parent
                clip: true

                opacity: show ? 1.0 : 0.0
                Behavior on opacity {
                    SequentialAnimation {
                        PauseAnimation { duration: (shellRoot && shellRoot.batteryMode) ? 0 : (show ? 120 : 0) }
                        NumberAnimation {
                            duration: (shellRoot && shellRoot.batteryMode) ? 0 : (show ? 300 : 80)
                            easing.type: show ? Easing.OutQuad : Easing.InQuad
                        }
                    }
                }

                scale: show ? 1.0 : 0.95
                Behavior on scale {
                    enabled: !(shellRoot && shellRoot.batteryMode)
                    SpringAnimation { spring: 3.5; damping: 0.8; mass: 0.8 }
                }

                RowLayout {
                    id: layout
                    anchors.centerIn: parent
                    spacing: 20

                    // Shutdown
                    Column {
                        spacing: 6
                        Rectangle {
                            width: 50; height: 50; radius: 25
                            anchors.horizontalCenter: parent.horizontalCenter
                            color: (sdMouse.containsMouse || selectedIndex === 0) ? Qt.rgba(1, 0.2, 0.2, 0.8) : Qt.rgba(1, 1, 1, 0.08)
                            scale: (sdMouse.containsMouse || selectedIndex === 0) ? 1.12 : 1.0
                            Behavior on scale {
                                enabled: !(shellRoot && shellRoot.batteryMode)
                                SpringAnimation { spring: 4.5; damping: 0.65; mass: 0.6 }
                            }
                            Text { anchors.centerIn: parent; text: "󰐥"; color: shellRoot ? shellRoot.colFg : "white"; font.family: shellRoot ? shellRoot.iconFontFamily : "sans-serif"; font.pixelSize: 20 }
                            MouseArea { id: sdMouse; anchors.fill: parent; hoverEnabled: true; onEntered: selectedIndex = 0; onClicked: { show = false; pShutdown.running = true } }
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Shut Down"
                            color: shellRoot ? shellRoot.colMuted : "#888888"
                            font.family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                            font.pixelSize: 9
                            font.bold: true
                        }
                    }
                    // Reboot
                    Column {
                        spacing: 6
                        Rectangle {
                            width: 50; height: 50; radius: 25
                            anchors.horizontalCenter: parent.horizontalCenter
                            color: (rbMouse.containsMouse || selectedIndex === 1) ? Qt.rgba(0.2, 0.8, 0.2, 0.8) : Qt.rgba(1, 1, 1, 0.08)
                            scale: (rbMouse.containsMouse || selectedIndex === 1) ? 1.12 : 1.0
                            Behavior on scale {
                                enabled: !(shellRoot && shellRoot.batteryMode)
                                SpringAnimation { spring: 4.5; damping: 0.65; mass: 0.6 }
                            }
                            Text { anchors.centerIn: parent; text: "󰑓"; color: shellRoot ? shellRoot.colFg : "white"; font.family: shellRoot ? shellRoot.iconFontFamily : "sans-serif"; font.pixelSize: 20 }
                            MouseArea { id: rbMouse; anchors.fill: parent; hoverEnabled: true; onEntered: selectedIndex = 1; onClicked: { show = false; pReboot.running = true } }
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Reboot"
                            color: shellRoot ? shellRoot.colMuted : "#888888"
                            font.family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                            font.pixelSize: 9
                            font.bold: true
                        }
                    }
                    // Suspend
                    Column {
                        spacing: 6
                        Rectangle {
                            width: 50; height: 50; radius: 25
                            anchors.horizontalCenter: parent.horizontalCenter
                            color: (spMouse.containsMouse || selectedIndex === 2) ? Qt.rgba(0.2, 0.2, 1.0, 0.8) : Qt.rgba(1, 1, 1, 0.08)
                            scale: (spMouse.containsMouse || selectedIndex === 2) ? 1.12 : 1.0
                            Behavior on scale {
                                enabled: !(shellRoot && shellRoot.batteryMode)
                                SpringAnimation { spring: 4.5; damping: 0.65; mass: 0.6 }
                            }
                            Text { anchors.centerIn: parent; text: "󰤄"; color: shellRoot ? shellRoot.colFg : "white"; font.family: shellRoot ? shellRoot.iconFontFamily : "sans-serif"; font.pixelSize: 20 }
                            MouseArea { id: spMouse; anchors.fill: parent; hoverEnabled: true; onEntered: selectedIndex = 2; onClicked: { show = false; pSuspend.running = true } }
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Sleep"
                            color: shellRoot ? shellRoot.colMuted : "#888888"
                            font.family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                            font.pixelSize: 9
                            font.bold: true
                        }
                    }
                    // Hibernate
                    Column {
                        spacing: 6
                        Rectangle {
                            width: 50; height: 50; radius: 25
                            anchors.horizontalCenter: parent.horizontalCenter
                            color: (hbMouse.containsMouse || selectedIndex === 3) ? Qt.rgba(0.2, 0.8, 0.8, 0.8) : Qt.rgba(1, 1, 1, 0.08)
                            scale: (hbMouse.containsMouse || selectedIndex === 3) ? 1.12 : 1.0
                            Behavior on scale {
                                enabled: !(shellRoot && shellRoot.batteryMode)
                                SpringAnimation { spring: 4.5; damping: 0.65; mass: 0.6 }
                            }
                            Text { anchors.centerIn: parent; text: "󰒲"; color: shellRoot ? shellRoot.colFg : "white"; font.family: shellRoot ? shellRoot.iconFontFamily : "sans-serif"; font.pixelSize: 20 }
                            MouseArea { id: hbMouse; anchors.fill: parent; hoverEnabled: true; onEntered: selectedIndex = 3; onClicked: { show = false; pHibernate.running = true } }
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Hibernate"
                            color: shellRoot ? shellRoot.colMuted : "#888888"
                            font.family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                            font.pixelSize: 9
                            font.bold: true
                        }
                    }
                    // Lock
                    Column {
                        spacing: 6
                        Rectangle {
                            width: 50; height: 50; radius: 25
                            anchors.horizontalCenter: parent.horizontalCenter
                            color: (lkMouse.containsMouse || selectedIndex === 4) ? Qt.rgba(0.8, 0.2, 0.8, 0.8) : Qt.rgba(1, 1, 1, 0.08)
                            scale: (lkMouse.containsMouse || selectedIndex === 4) ? 1.12 : 1.0
                            Behavior on scale {
                                enabled: !(shellRoot && shellRoot.batteryMode)
                                SpringAnimation { spring: 4.5; damping: 0.65; mass: 0.6 }
                            }
                            Text { anchors.centerIn: parent; text: "󰌾"; color: shellRoot ? shellRoot.colFg : "white"; font.family: shellRoot ? shellRoot.iconFontFamily : "sans-serif"; font.pixelSize: 20 }
                            MouseArea { id: lkMouse; anchors.fill: parent; hoverEnabled: true; onEntered: selectedIndex = 4; onClicked: { show = false; pLock.running = true } }
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Lock"
                            color: shellRoot ? shellRoot.colMuted : "#888888"
                            font.family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                            font.pixelSize: 9
                            font.bold: true
                        }
                    }
                    // Logout
                    Column {
                        spacing: 6
                        Rectangle {
                            width: 50; height: 50; radius: 25
                            anchors.horizontalCenter: parent.horizontalCenter
                            color: (loMouse.containsMouse || selectedIndex === 5) ? Qt.rgba(0.8, 0.8, 0.2, 0.8) : Qt.rgba(1, 1, 1, 0.08)
                            scale: (loMouse.containsMouse || selectedIndex === 5) ? 1.12 : 1.0
                            Behavior on scale {
                                enabled: !(shellRoot && shellRoot.batteryMode)
                                SpringAnimation { spring: 4.5; damping: 0.65; mass: 0.6 }
                            }
                            Text { anchors.centerIn: parent; text: "󰍃"; color: shellRoot ? shellRoot.colFg : "white"; font.family: shellRoot ? shellRoot.iconFontFamily : "sans-serif"; font.pixelSize: 20 }
                            MouseArea { id: loMouse; anchors.fill: parent; hoverEnabled: true; onEntered: selectedIndex = 5; onClicked: { show = false; pLogout.running = true } }
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Log Out"
                            color: shellRoot ? shellRoot.colMuted : "#888888"
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
