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
    property bool hideImmediately: false
    property var shellRoot
    readonly property real scaleFactor: shellRoot ? shellRoot.scaleFactor : 1.0
    readonly property real fontScale: scaleFactor * (shellRoot ? shellRoot.fontSizeMultiplier : 1.0)

    WlrLayershell.keyboardFocus: show ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    WlrLayershell.namespace: "quickshell_widgets" // gets automatic blur

    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    // visible stays active during fade-out animation unless hideImmediately is set during sibling handoff
    visible: (!hideImmediately) && (show || animRect.opacity > 0.01)

    onShowChanged: {
        if (show) {
            hideImmediately = false;
            if (shellRoot && shellRoot.pListSinks) {
                shellRoot.pListSinks.running = true;
            }
        } else {
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

        // Liquid Glass Card with Premium Slide-Fade Animation
        Rectangle {
            id: animRect
            color: "transparent"
            anchors.top: parent.top
            anchors.topMargin: show ? 46 * scaleFactor : 36 * scaleFactor
            anchors.right: parent.right
            anchors.rightMargin: 12 * scaleFactor

            readonly property int sinkCount: (shellRoot && shellRoot.sinkModel) ? shellRoot.sinkModel.count : 1
            readonly property bool showMic: shellRoot && shellRoot.isMicActive
            width: 320 * scaleFactor
            height: {
                var baseHeight = showMic ? 245 : 165;
                var listHeight = Math.min(sinkCount, 4) * 44;
                return Math.round((baseHeight + listHeight) * scaleFactor);
            }
            radius: Math.round(4 * scaleFactor)

            Behavior on height { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

            // Tactical opacity transitions
            opacity: show ? 1.0 : 0.0

            Behavior on opacity {
                NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
            }
            Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
            Behavior on anchors.topMargin {
                NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
            }

            // SurfaceCard Base (Option B, Zero Shader Overhead)
            SurfaceCard {
                id: popupGlassCard
                anchors.fill: parent
                radius: animRect.radius
                contentPadding: 0
            }
            // Card Inner Layout
            Item {
                anchors.fill: parent
                anchors.margins: 14 * scaleFactor
                clip: true

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 12 * scaleFactor

                    // Title
                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "Audio Output"
                            color: shellRoot ? shellRoot.colFg : "#ffffff"
                            font { family: shellRoot ? shellRoot.fontFamily : "sans-serif"; pixelSize: 13 * fontScale; bold: true }
                            Layout.fillWidth: true
                        }
                        Text {
                            text: shellRoot ? shellRoot.volumeOut : "0%"
                            color: shellRoot ? shellRoot.colMuted : "#888888"
                            font { family: shellRoot ? shellRoot.fontFamily : "sans-serif"; pixelSize: 11 * fontScale; bold: true }
                        }
                    }

                    // Slider + Mute
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10 * scaleFactor

                        // Mute button
                        MouseArea {
                            id: muteBtn
                            Layout.preferredWidth: 32 * scaleFactor
                            Layout.preferredHeight: 32 * scaleFactor
                            hoverEnabled: true

                            Rectangle {
                                anchors.fill: parent
                                radius: Math.round(4 * scaleFactor)
                                color: parent.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(1, 1, 1, 0.04)
                                border.color: Qt.rgba(1, 1, 1, 0.05)
                                border.width: 1
                            }

                            Text {
                                anchors.centerIn: parent
                                text: shellRoot && shellRoot.volumeMuted ? "󰖁" : "󰕾"
                                color: shellRoot && shellRoot.volumeMuted ? (shellRoot ? shellRoot.colCrit : "#ff3b30") : (shellRoot ? shellRoot.colAccent : "#007aff")
                                font { family: shellRoot ? shellRoot.iconFontFamily : "sans-serif"; pixelSize: 15 * fontScale }
                            }

                            onClicked: {
                                if (shellRoot) {
                                    shellRoot.pVolMute.running = true;
                                }
                            }
                        }

                        // Horizontal Volume Slider
                        ModernSlider {
                            id: volSlider
                            shellRoot: rootWindow.shellRoot
                            sliderAccent: shellRoot ? shellRoot.colAccent : "#007AFF"
                            value: shellRoot ? (parseInt(shellRoot.volumeOut) / 100.0) : 0
                            Layout.fillWidth: true

                            onMoved: {
                                if (shellRoot) {
                                    shellRoot.volumeOut = Math.round(value * 100) + "%";
                                    volDebounce.volValue = value;
                                    volDebounce.restart();
                                }
                            }

                            Timer {
                                id: volDebounce
                                property real volValue: 0
                                interval: 50
                                onTriggered: {
                                    if (shellRoot) {
                                        shellRoot.pVolSet.command = ["/home/krishna/dotfiles/scripts/set_volume.sh", volValue.toFixed(2)];
                                        shellRoot.pVolSet.running = true;
                                    }
                                }
                            }
                        }
                    }

                    // Microphone Input Section (Only visible when mic is active)
                    ColumnLayout {
                        id: micSection
                        Layout.fillWidth: true
                        spacing: 8 * scaleFactor
                        visible: shellRoot && shellRoot.isMicActive

                        // Divider
                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: Qt.rgba(1, 1, 1, 0.08)
                        }

                        // Title Row
                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: "Microphone Input"
                                color: shellRoot ? shellRoot.colFg : "#ffffff"
                                font { family: shellRoot ? shellRoot.fontFamily : "sans-serif"; pixelSize: 13 * fontScale; bold: true }
                                Layout.fillWidth: true
                            }
                            Text {
                                text: shellRoot ? shellRoot.volumeMic : "0%"
                                color: shellRoot ? shellRoot.colMuted : "#888888"
                                font { family: shellRoot ? shellRoot.fontFamily : "sans-serif"; pixelSize: 11 * fontScale; bold: true }
                            }
                        }

                        // Slider + Mute (Input)
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10 * scaleFactor

                            // Mute button
                            MouseArea {
                                id: micMuteBtn
                                Layout.preferredWidth: 32 * scaleFactor
                                Layout.preferredHeight: 32 * scaleFactor
                                hoverEnabled: true

                                Rectangle {
                                    anchors.fill: parent
                                    radius: Math.round(4 * scaleFactor)
                                    color: parent.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(1, 1, 1, 0.04)
                                    border.color: Qt.rgba(1, 1, 1, 0.05)
                                    border.width: 1
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: shellRoot && shellRoot.micMuted ? "󰍭" : "󰍬"
                                    color: shellRoot && shellRoot.micMuted ? (shellRoot ? shellRoot.colCrit : "#ff3b30") : (shellRoot ? shellRoot.colWarn : "#FFA500")
                                    font { family: shellRoot ? shellRoot.iconFontFamily : "sans-serif"; pixelSize: 15 * fontScale }
                                }

                                onClicked: {
                                    if (shellRoot) {
                                        shellRoot.pMicMute.running = true;
                                    }
                                }
                            }

                            // Horizontal Volume Slider (Input)
                            ModernSlider {
                                id: micVolSlider
                                shellRoot: rootWindow.shellRoot
                                sliderAccent: shellRoot ? shellRoot.colWarn : "#FFA500"
                                value: shellRoot ? (parseInt(shellRoot.volumeMic) / 100.0) : 0
                                Layout.fillWidth: true

                                onMoved: {
                                    if (shellRoot) {
                                        shellRoot.volumeMic = Math.round(value * 100) + "%";
                                        micVolDebounce.volValue = value;
                                        micVolDebounce.restart();
                                    }
                                }

                                Timer {
                                    id: micVolDebounce
                                    property real volValue: 0
                                    interval: 50
                                    onTriggered: {
                                        if (shellRoot) {
                                            shellRoot.pVolSetMic.command = ["wpctl", "set-volume", "@DEFAULT_AUDIO_SOURCE@", volValue.toFixed(2)];
                                            shellRoot.pVolSetMic.running = true;
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Divider
                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: Qt.rgba(1, 1, 1, 0.08)
                    }

                    // Sinks List Title
                    Text {
                        text: "Devices"
                        color: shellRoot ? shellRoot.colMuted : "#888888"
                        font { family: shellRoot ? shellRoot.fontFamily : "sans-serif"; pixelSize: 10 * fontScale; bold: true }
                    }

                    // Scrollable List of Sinks
                    ListView {
                        id: sinkListView
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        model: shellRoot ? shellRoot.sinkModel : null
                        spacing: 4 * scaleFactor

                        delegate: Rectangle {
                            width: sinkListView.width
                            height: 36 * scaleFactor
                            radius: Math.round(4 * scaleFactor)
                            color: model.isActive ? Qt.rgba(1, 1, 1, 0.08) : (delegateMa.containsMouse ? Qt.rgba(1, 1, 1, 0.04) : "transparent")
                            border.color: model.isActive ? Qt.rgba(1, 1, 1, 0.05) : "transparent"
                            border.width: 1

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8 * scaleFactor
                                anchors.rightMargin: 8 * scaleFactor
                                spacing: 8 * scaleFactor

                                Text {
                                    text: model.isActive ? "󰓃" : "󰓄"
                                    color: model.isActive ? (shellRoot ? shellRoot.colAccent : "#007aff") : (shellRoot ? shellRoot.colMuted : "#888888")
                                    font { family: shellRoot ? shellRoot.iconFontFamily : "sans-serif"; pixelSize: 13 * fontScale }
                                }

                                Text {
                                    text: model.name
                                    color: model.isActive ? (shellRoot ? shellRoot.colFg : "#ffffff") : (shellRoot ? shellRoot.colMuted : "#b8b8b8")
                                    font { family: shellRoot ? shellRoot.fontFamily : "sans-serif"; pixelSize: 11 * fontScale; bold: model.isActive }
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }

                                Text {
                                    text: model.isActive ? "Active" : ""
                                    color: shellRoot ? shellRoot.colAccent : "#007aff"
                                    font { family: shellRoot ? shellRoot.fontFamily : "sans-serif"; pixelSize: 9 * fontScale; bold: true }
                                    visible: model.isActive
                                }
                            }

                            MouseArea {
                                id: delegateMa
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    if (shellRoot && shellRoot.pSetSink) {
                                        shellRoot.pSetSink.sinkId = model.sinkId;
                                        shellRoot.pSetSink.running = true;
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
