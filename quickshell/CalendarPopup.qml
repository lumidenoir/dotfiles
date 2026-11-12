import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: rootWindow

    property bool show: false
    property var shellRoot
    readonly property real scaleFactor: shellRoot ? shellRoot.scaleFactor : 1.0
    readonly property real fontScale: scaleFactor * (shellRoot ? shellRoot.fontSizeMultiplier : 1.0)

    WlrLayershell.keyboardFocus: show ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    WlrLayershell.namespace: "quickshell_widgets"

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    exclusionMode: ExclusionMode.Ignore
    visible: show || isClosing
    color: "transparent"

    property bool isClosing: false
    property real savedCloseTarget: 120
    property bool suppressOpenAnimation: false

    onShowChanged: {
        if (show) {
            isClosing = false;
            suppressOpenAnimation = true;
            snapResetTimer.start();
            savedCloseTarget = Qt.binding(function () {
                return shellRoot ? shellRoot.closedNotchWidth : 120;
            });
            currentDate = new Date();
            selectedYear = currentDate.getFullYear();
            selectedMonth = currentDate.getMonth();
            popupContent.forceActiveFocus();
        } else {
            savedCloseTarget = shellRoot ? shellRoot.closedNotchWidth : 120;
            isClosing = true;
        }
    }

    Timer {
        id: snapResetTimer
        interval: 32
        repeat: false
        onTriggered: rootWindow.suppressOpenAnimation = false
    }

    property date currentDate: new Date()
    property int selectedYear: currentDate.getFullYear()
    property int selectedMonth: currentDate.getMonth() // 0-indexed

    function daysInMonth(year, month) {
        return new Date(year, month + 1, 0).getDate();
    }

    function firstDayOfWeek(year, month) {
        // 0 = Sun, 1 = Mon... Convert so Mon = 0, Sun = 6
        var day = new Date(year, month, 1).getDay();
        return (day === 0) ? 6 : day - 1;
    }

    function monthName(month) {
        var months = ["January", "February", "March", "April", "May", "June",
                      "July", "August", "September", "October", "November", "December"];
        return months[month];
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

        // SurfaceCard Calendar Popup with Liquid Spring Animation
        Rectangle {
            id: animRect
            anchors.top: parent.top
            anchors.topMargin: rootWindow.show ? Math.round(38 * scaleFactor) : Math.round(28 * scaleFactor)
            anchors.horizontalCenter: parent.horizontalCenter

            width: Math.round(340 * scaleFactor)
            height: Math.round(350 * scaleFactor)
            radius: Math.round(4 * scaleFactor)
            clip: true

            opacity: rootWindow.show ? 1.0 : 0.0
            scale: rootWindow.show ? 1.0 : 0.94

            function checkCloseFinished() {
                if (!rootWindow.show && rootWindow.isClosing && opacity < 0.01) {
                    rootWindow.isClosing = false;
                }
            }

            onOpacityChanged: checkCloseFinished()

            Behavior on opacity {
                NumberAnimation {
                    duration: rootWindow.show ? 220 : 150
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on scale {
                NumberAnimation {
                    duration: rootWindow.show ? 260 : 150
                    easing.type: rootWindow.show ? Easing.OutBack : Easing.OutCubic
                    easing.overshoot: 1.15
                }
            }
            Behavior on anchors.topMargin {
                NumberAnimation {
                    duration: rootWindow.show ? 260 : 150
                    easing.type: rootWindow.show ? Easing.OutBack : Easing.OutCubic
                    easing.overshoot: 1.15
                }
            }

            color: "transparent"
            border.color: Qt.rgba(1, 1, 1, 0.08)
            border.width: 1

            // SurfaceCard Base (Option B, Zero Shader Overhead)
            SurfaceCard {
                id: calGlassCard
                anchors.fill: parent
                radius: animRect.radius
                contentPadding: 0
            }

            // Top highlight line
            Rectangle {
                anchors.top: parent.top
                anchors.topMargin: 1
                anchors.left: parent.left
                anchors.leftMargin: parent.radius
                anchors.right: parent.right
                anchors.rightMargin: parent.radius
                height: 1
                color: Qt.rgba(1, 1, 1, 0.12)
            }

            // Content container
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14 * scaleFactor
                spacing: 10 * scaleFactor

                // Header Row (Month Year + Prev/Today/Next controls)
                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: rootWindow.monthName(rootWindow.selectedMonth) + " " + rootWindow.selectedYear
                        color: shellRoot ? shellRoot.colFg : "#ffffff"
                        font {
                            family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                            pixelSize: 14 * fontScale
                            bold: true
                        }
                        Layout.fillWidth: true
                    }

                    RowLayout {
                        spacing: 4 * scaleFactor

                        // Prev Month Button
                        MouseArea {
                            width: 26 * scaleFactor
                            height: 26 * scaleFactor
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (rootWindow.selectedMonth === 0) {
                                    rootWindow.selectedMonth = 11;
                                    rootWindow.selectedYear -= 1;
                                } else {
                                    rootWindow.selectedMonth -= 1;
                                }
                            }

                            Rectangle {
                                anchors.fill: parent
                                radius: 6 * scaleFactor
                                color: parent.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(1, 1, 1, 0.04)
                            }
                            Text {
                                anchors.centerIn: parent
                                text: "󰅁"
                                color: "#ffffff"
                                font { family: shellRoot ? shellRoot.iconFontFamily : "sans-serif"; pixelSize: 13 * fontScale }
                            }
                        }

                        // Today Reset Button
                        MouseArea {
                            width: 26 * scaleFactor
                            height: 26 * scaleFactor
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                var now = new Date();
                                rootWindow.selectedYear = now.getFullYear();
                                rootWindow.selectedMonth = now.getMonth();
                            }

                            Rectangle {
                                anchors.fill: parent
                                radius: 6 * scaleFactor
                                color: parent.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(1, 1, 1, 0.04)
                            }
                            Text {
                                anchors.centerIn: parent
                                text: "󰃭"
                                color: shellRoot ? shellRoot.colAccent : "#007aff"
                                font { family: shellRoot ? shellRoot.iconFontFamily : "sans-serif"; pixelSize: 12 * fontScale }
                            }
                        }

                        // Next Month Button
                        MouseArea {
                            width: 26 * scaleFactor
                            height: 26 * scaleFactor
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (rootWindow.selectedMonth === 11) {
                                    rootWindow.selectedMonth = 0;
                                    rootWindow.selectedYear += 1;
                                } else {
                                    rootWindow.selectedMonth += 1;
                                }
                            }

                            Rectangle {
                                anchors.fill: parent
                                radius: 6 * scaleFactor
                                color: parent.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(1, 1, 1, 0.04)
                            }
                            Text {
                                anchors.centerIn: parent
                                text: "󰅂"
                                color: "#ffffff"
                                font { family: shellRoot ? shellRoot.iconFontFamily : "sans-serif"; pixelSize: 13 * fontScale }
                            }
                        }
                    }
                }

                // Days of Week Header
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Repeater {
                        model: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
                        delegate: Item {
                            Layout.fillWidth: true
                            height: 20 * scaleFactor

                            Text {
                                anchors.centerIn: parent
                                text: modelData
                                color: shellRoot ? shellRoot.colMuted : "#888888"
                                font {
                                    family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                                    pixelSize: 10 * fontScale
                                    bold: true
                                }
                            }
                        }
                    }
                }

                // Divider Line
                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: Qt.rgba(1, 1, 1, 0.08)
                }

                // 6x7 Calendar Grid
                GridLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    columns: 7
                    rowSpacing: 4 * scaleFactor
                    columnSpacing: 4 * scaleFactor

                    Repeater {
                        model: 42
                        delegate: Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            readonly property int startOffset: rootWindow.firstDayOfWeek(rootWindow.selectedYear, rootWindow.selectedMonth)
                            readonly property int totalDaysInMonth: rootWindow.daysInMonth(rootWindow.selectedYear, rootWindow.selectedMonth)
                            readonly property int prevMonthDays: rootWindow.daysInMonth(
                                rootWindow.selectedMonth === 0 ? rootWindow.selectedYear - 1 : rootWindow.selectedYear,
                                rootWindow.selectedMonth === 0 ? 11 : rootWindow.selectedMonth - 1
                            )

                            readonly property int dayNum: {
                                var idx = index - startOffset;
                                if (idx < 0) {
                                    return prevMonthDays + idx + 1;
                                } else if (idx < totalDaysInMonth) {
                                    return idx + 1;
                                } else {
                                    return idx - totalDaysInMonth + 1;
                                }
                            }

                            readonly property bool isCurrentMonth: (index >= startOffset) && (index < startOffset + totalDaysInMonth)
                            readonly property bool isToday: {
                                var now = new Date();
                                return isCurrentMonth &&
                                       dayNum === now.getDate() &&
                                       rootWindow.selectedMonth === now.getMonth() &&
                                       rootWindow.selectedYear === now.getFullYear();
                            }

                            Rectangle {
                                id: dayBg
                                anchors.centerIn: parent
                                width: Math.min(parent.width, parent.height)
                                height: width
                                radius: 4

                                color: isToday ? (shellRoot ? shellRoot.colAccent : "#007aff") : (dayMa.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent")
                                border.color: isToday ? Qt.rgba(1, 1, 1, 0.3) : "transparent"
                                border.width: 1

                                Text {
                                    anchors.centerIn: parent
                                    text: dayNum.toString()
                                    color: isToday ? "#ffffff" : (isCurrentMonth ? (shellRoot ? shellRoot.colFg : "#ffffff") : Qt.rgba(1, 1, 1, 0.25))
                                    font {
                                        family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                                        pixelSize: 11 * fontScale
                                        bold: isToday || isCurrentMonth
                                    }
                                }
                            }

                            MouseArea {
                                id: dayMa
                                anchors.fill: parent
                                hoverEnabled: true
                            }
                        }
                    }
                }
            }
        }
    }
}
