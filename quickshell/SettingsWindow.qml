import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

Window {
    id: settingsWin
    title: "Ground Control Settings"
    width: Math.round(480 * scaleFactor)
    height: Math.round(620 * scaleFactor)
    color: "#0a0a0c"
    visible: false

    property var shellRoot: null
    readonly property real scaleFactor: shellRoot ? shellRoot.scaleFactor : 1.0
    readonly property string fontFamily: shellRoot ? shellRoot.fontFamily : "sans-serif"
    readonly property string iconFontFamily: shellRoot ? shellRoot.iconFontFamily : "sans-serif"

    // Background gradient for a premium look
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#0d0d11" }
            GradientStop { position: 1.0; color: "#060608" }
        }
    }

    // Scrollable container for settings
    Flickable {
        anchors.fill: parent
        contentHeight: mainCol.implicitHeight + 40 * scaleFactor
        anchors.margins: 20 * scaleFactor
        clip: true

        ColumnLayout {
            id: mainCol
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: 16 * scaleFactor

            // Header Section
            RowLayout {
                Layout.fillWidth: true
                spacing: 12 * scaleFactor

                Text {
                    text: "󰒓"
                    color: "#3b82f6"
                    font { family: settingsWin.iconFontFamily; pixelSize: 26 * scaleFactor; bold: true }
                }

                ColumnLayout {
                    spacing: 2 * scaleFactor
                    Text {
                        text: "Quickshell Settings"
                        color: "#ffffff"
                        font { family: settingsWin.fontFamily; pixelSize: 18 * scaleFactor; bold: true }
                    }
                    Text {
                        text: "Customize dynamic island physics, delays, and desktop styles"
                        color: "#6b7280"
                        font { family: settingsWin.fontFamily; pixelSize: 10 * scaleFactor }
                    }
                }
            }

            // Separator
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Qt.rgba(1, 1, 1, 0.08)
            }

            // GROUP 1: Dynamic Island Physics
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6 * scaleFactor

                Text {
                    text: "DYNAMIC ISLAND SPRINGS"
                    color: "#3b82f6"
                    font { family: settingsWin.fontFamily; pixelSize: 9 * scaleFactor; bold: true }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: physicsCol.implicitHeight + 24 * scaleFactor
                    color: Qt.rgba(1, 1, 1, 0.03)
                    radius: 12 * scaleFactor
                    border.color: Qt.rgba(1, 1, 1, 0.08)
                    border.width: 1

                    ColumnLayout {
                        id: physicsCol
                        anchors.fill: parent
                        anchors.margins: 12 * scaleFactor
                        spacing: 12 * scaleFactor

                        // Stiffness (Spring)
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4 * scaleFactor
                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Stiffness / Tension"; color: "#ffffff"; font { family: settingsWin.fontFamily; pixelSize: 11 * scaleFactor; bold: true } }
                                Spacer {}
                                Text { text: (shellRoot ? shellRoot.notchSpringStiffness.toFixed(1) : "3.5"); color: "#3b82f6"; font { family: settingsWin.fontFamily; pixelSize: 11 * scaleFactor } }
                            }
                            ModernSlider {
                                shellRoot: settingsWin.shellRoot
                                sliderAccent: "#3b82f6"
                                from: 1.0; to: 10.0
                                value: shellRoot ? shellRoot.notchSpringStiffness : 3.5
                                onMoved: {
                                    if (shellRoot) shellRoot.notchSpringStiffness = value;
                                }
                            }
                        }

                        // Damping
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4 * scaleFactor
                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Damping / Bounce"; color: "#ffffff"; font { family: settingsWin.fontFamily; pixelSize: 11 * scaleFactor; bold: true } }
                                Spacer {}
                                Text { text: (shellRoot ? shellRoot.notchSpringDamping.toFixed(2) : "0.62"); color: "#3b82f6"; font { family: settingsWin.fontFamily; pixelSize: 11 * scaleFactor } }
                            }
                            ModernSlider {
                                shellRoot: settingsWin.shellRoot
                                sliderAccent: "#3b82f6"
                                from: 0.3; to: 1.0
                                value: shellRoot ? shellRoot.notchSpringDamping : 0.62
                                onMoved: {
                                    if (shellRoot) shellRoot.notchSpringDamping = value;
                                }
                            }
                        }

                        // Mass
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4 * scaleFactor
                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Inertia / Mass"; color: "#ffffff"; font { family: settingsWin.fontFamily; pixelSize: 11 * scaleFactor; bold: true } }
                                Spacer {}
                                Text { text: (shellRoot ? shellRoot.notchSpringMass.toFixed(2) : "0.75"); color: "#3b82f6"; font { family: settingsWin.fontFamily; pixelSize: 11 * scaleFactor } }
                            }
                            ModernSlider {
                                shellRoot: settingsWin.shellRoot
                                sliderAccent: "#3b82f6"
                                from: 0.1; to: 2.0
                                value: shellRoot ? shellRoot.notchSpringMass : 0.75
                                onMoved: {
                                    if (shellRoot) shellRoot.notchSpringMass = value;
                                }
                            }
                        }
                    }
                }
            }

            // GROUP 2: Timings & Delays
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6 * scaleFactor

                Text {
                    text: "TIMINGS & DELAYS"
                    color: "#10b981"
                    font { family: settingsWin.fontFamily; pixelSize: 9 * scaleFactor; bold: true }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: timingsCol.implicitHeight + 24 * scaleFactor
                    color: Qt.rgba(1, 1, 1, 0.03)
                    radius: 12 * scaleFactor
                    border.color: Qt.rgba(1, 1, 1, 0.08)
                    border.width: 1

                    ColumnLayout {
                        id: timingsCol
                        anchors.fill: parent
                        anchors.margins: 12 * scaleFactor
                        spacing: 12 * scaleFactor

                        // LocalSend Dismiss
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4 * scaleFactor
                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "LocalSend Success Duration"; color: "#ffffff"; font { family: settingsWin.fontFamily; pixelSize: 11 * scaleFactor; bold: true } }
                                Spacer {}
                                Text { text: (shellRoot ? (shellRoot.localSendDismissDelay / 1000.0).toFixed(1) + "s" : "2.0s"); color: "#10b981"; font { family: settingsWin.fontFamily; pixelSize: 11 * scaleFactor } }
                            }
                            ModernSlider {
                                shellRoot: settingsWin.shellRoot
                                sliderAccent: "#10b981"
                                from: 1000; to: 5000
                                value: shellRoot ? shellRoot.localSendDismissDelay : 2000
                                onMoved: {
                                    if (shellRoot) shellRoot.localSendDismissDelay = Math.round(value);
                                }
                            }
                        }

                        // LocalSend Text Reveal Delay
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4 * scaleFactor
                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "LocalSend Drop text Delay"; color: "#ffffff"; font { family: settingsWin.fontFamily; pixelSize: 11 * scaleFactor; bold: true } }
                                Spacer {}
                                Text { text: (shellRoot ? shellRoot.localSendRevealDelay + "ms" : "140ms"); color: "#10b981"; font { family: settingsWin.fontFamily; pixelSize: 11 * scaleFactor } }
                            }
                            ModernSlider {
                                shellRoot: settingsWin.shellRoot
                                sliderAccent: "#10b981"
                                from: 50; to: 400
                                value: shellRoot ? shellRoot.localSendRevealDelay : 140
                                onMoved: {
                                    if (shellRoot) shellRoot.localSendRevealDelay = Math.round(value);
                                }
                            }
                        }

                        // Notification dismiss time
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4 * scaleFactor
                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Notification Banner Duration"; color: "#ffffff"; font { family: settingsWin.fontFamily; pixelSize: 11 * scaleFactor; bold: true } }
                                Spacer {}
                                Text { text: (shellRoot ? (shellRoot.notifDismissDelay / 1000.0).toFixed(1) + "s" : "4.5s"); color: "#10b981"; font { family: settingsWin.fontFamily; pixelSize: 11 * scaleFactor } }
                            }
                            ModernSlider {
                                shellRoot: settingsWin.shellRoot
                                sliderAccent: "#10b981"
                                from: 2000; to: 10000
                                value: shellRoot ? shellRoot.notifDismissDelay : 4500
                                onMoved: {
                                    if (shellRoot) shellRoot.notifDismissDelay = Math.round(value);
                                }
                            }
                        }
                    }
                }
            }

            // GROUP 3: Layout Behaviors
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6 * scaleFactor

                Text {
                    text: "LAYOUT STYLE"
                    color: "#f59e0b"
                    font { family: settingsWin.fontFamily; pixelSize: 9 * scaleFactor; bold: true }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: behaviorsCol.implicitHeight + 24 * scaleFactor
                    color: Qt.rgba(1, 1, 1, 0.03)
                    radius: 12 * scaleFactor
                    border.color: Qt.rgba(1, 1, 1, 0.08)
                    border.width: 1

                    ColumnLayout {
                        id: behaviorsCol
                        anchors.fill: parent
                        anchors.margins: 12 * scaleFactor

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12 * scaleFactor

                            ColumnLayout {
                                spacing: 2 * scaleFactor
                                Text { text: "Top-Hugging Notch style"; color: "#ffffff"; font { family: settingsWin.fontFamily; pixelSize: 11 * scaleFactor; bold: true } }
                                Text { text: "Removes margin to dock the Dynamic Island directly at screen edge"; color: "#6b7280"; font { family: settingsWin.fontFamily; pixelSize: 9 * scaleFactor } }
                            }

                            Spacer {}

                            // Custom toggle switch
                            Item {
                                id: hugSwitch
                                implicitWidth: 44 * scaleFactor
                                implicitHeight: 24 * scaleFactor
                                property bool checked: shellRoot ? shellRoot.topHuggingStyle : false

                                Rectangle {
                                    anchors.fill: parent
                                    radius: 12 * scaleFactor
                                    color: hugSwitch.checked ? "#3b82f6" : Qt.rgba(1, 1, 1, 0.15)
                                    Behavior on color { ColorAnimation { duration: 150 } }

                                    Rectangle {
                                        x: hugSwitch.checked ? 22 * scaleFactor : 2 * scaleFactor
                                        y: 2 * scaleFactor
                                        width: 20 * scaleFactor
                                        height: 20 * scaleFactor
                                        radius: 10 * scaleFactor
                                        color: "#ffffff"
                                        Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        if (shellRoot) {
                                            shellRoot.topHuggingStyle = !shellRoot.topHuggingStyle;
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Spacer
            Item { Layout.preferredHeight: 12 * scaleFactor }

            // Action Buttons Footer
            RowLayout {
                Layout.fillWidth: true
                spacing: 12 * scaleFactor

                // Reset Button
                ModernButton {
                    text: "Reset Defaults"
                    iconText: "󰁯"
                    accent: "#ef4444"
                    Layout.fillWidth: true
                    onClicked: {
                        if (shellRoot) {
                            shellRoot.topHuggingStyle = false;
                            shellRoot.notchSpringStiffness = 3.5;
                            shellRoot.notchSpringDamping = 0.62;
                            shellRoot.notchSpringMass = 0.75;
                            shellRoot.localSendDismissDelay = 2000;
                            shellRoot.localSendRevealDelay = 140;
                            shellRoot.notifDismissDelay = 4500;
                        }
                    }
                }

                // Close Button
                ModernButton {
                    text: "Close Settings"
                    iconText: "󰅖"
                    accent: "#3b82f6"
                    Layout.fillWidth: true
                    onClicked: {
                        settingsWin.close();
                    }
                }
            }
        }
    }

    // Helper item for layout alignment spacing
    component Spacer : Item {
        Layout.fillWidth: true
        Layout.fillHeight: true
    }
}
