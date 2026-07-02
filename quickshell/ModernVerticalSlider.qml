import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell

Item {
    id: root

    property var shellRoot: null
    property color colFg: shellRoot ? shellRoot.colFg : "#ffffff"
    property bool batteryMode: shellRoot ? shellRoot.batteryMode : false

    property bool isMuted: false
    property color customAccent: colFg
    property color sliderAccent: isMuted ? Qt.rgba(colFg.r, colFg.g, colFg.b, 0.2) : customAccent

    property string iconText: ""
    property string labelText: ""

    // Forward Slider properties
    property alias value: slider.value
    property alias from: slider.from
    property alias to: slider.to
    signal moved
    signal iconClicked
    property bool showAirPlayButton: false
    signal airPlayClicked

    implicitWidth: 54
    implicitHeight: 110

    // Liquid fill animation properties
    property real wavePhase: 0.0
    property real waveAmp: 2.0 // wave amplitude in px

    NumberAnimation on wavePhase {
        running: !root.batteryMode && ((typeof groundControl !== "undefined") ? groundControl.show : true)
        loops: Animation.Infinite
        from: 0
        to: Math.PI * 2
        duration: 1400
        easing.type: Easing.Linear
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 4

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Slider {
                id: slider
                anchors.fill: parent
                orientation: Qt.Vertical
                from: 0
                to: 1.0

                background: Canvas {
                    id: sliderCanvas
                    anchors.fill: parent

                    // Repaint when visual properties change
                    property real val: slider.value
                    property bool gov: slider.hovered
                    property color acc: root.sliderAccent
                    property bool mut: root.isMuted
                    property real phs: root.wavePhase
                    onValChanged: requestPaint()
                    onGovChanged: requestPaint()
                    onAccChanged: requestPaint()
                    onMutChanged: requestPaint()
                    onPhsChanged: requestPaint()

                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.reset();
                        ctx.clearRect(0, 0, width, height);

                        var trackWidth = 32;
                        var trackHeight = height;
                        var rx = (width - trackWidth) / 2;
                        var ry = 0;
                        var radius = trackWidth / 2;

                        // 1. Draw capsule track background
                        ctx.fillStyle = slider.hovered ? "rgba(255, 255, 255, 0.12)" : "rgba(255, 255, 255, 0.08)";
                        ctx.beginPath();
                        ctx.arc(rx + radius, ry + radius, radius, Math.PI, 1.5 * Math.PI);
                        ctx.arc(rx + trackWidth - radius, ry + radius, radius, 1.5 * Math.PI, 2 * Math.PI);
                        ctx.arc(rx + trackWidth - radius, ry + trackHeight - radius, radius, 0, 0.5 * Math.PI);
                        ctx.arc(rx + radius, ry + trackHeight - radius, radius, 0.5 * Math.PI, Math.PI);
                        ctx.closePath();
                        ctx.fill();

                        // 2. Clip future drawings to this capsule shape
                        ctx.clip();

                        // 3. Draw active level fill from bottom with liquid wave meniscus
                        if (slider.value > 0) {
                            ctx.fillStyle = root.sliderAccent;
                            var fillHeight = slider.value * trackHeight;
                            var fillY = trackHeight - fillHeight;

                            ctx.beginPath();
                            ctx.moveTo(rx, trackHeight);
                            ctx.lineTo(rx + trackWidth, trackHeight);
                            ctx.lineTo(rx + trackWidth, fillY);

                            var steps = Math.ceil(trackWidth);
                            for (var i = steps; i >= 0; i--) {
                                var px = rx + i;
                                // Smoothly fade the wave amplitude to 0 as the value gets close to 0 or 1
                                var ampFactor = 1.0;
                                if (slider.value < 0.1) {
                                    ampFactor = slider.value / 0.1;
                                } else if (slider.value > 0.9) {
                                    ampFactor = (1.0 - slider.value) / 0.1;
                                }
                                var wave = Math.sin(root.wavePhase + (i / trackWidth) * Math.PI * 2) * root.waveAmp * ampFactor;
                                var py = fillY + wave;
                                ctx.lineTo(px, py);
                            }
                            ctx.closePath();
                            ctx.fill();

                            // Draw a subtle bright sheen line at the wave crest/interface
                            ctx.beginPath();
                            for (var j = 0; j <= steps; j++) {
                                var qx = rx + j;
                                var qampFactor = 1.0;
                                if (slider.value < 0.1) {
                                    qampFactor = slider.value / 0.1;
                                } else if (slider.value > 0.9) {
                                    qampFactor = (1.0 - slider.value) / 0.1;
                                }
                                var qwave = Math.sin(root.wavePhase + (j / trackWidth) * Math.PI * 2) * root.waveAmp * qampFactor;
                                var qy = fillY + qwave;
                                if (j === 0)
                                    ctx.moveTo(qx, qy);
                                else
                                    ctx.lineTo(qx, qy);
                            }
                            ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.35).toString();
                            ctx.lineWidth = 1.5;
                            ctx.stroke();
                        }
                    }

                    // Top Percentage Text overlayed inside the capsule
                    Text {
                        anchors.top: parent.top
                        anchors.topMargin: 8
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Math.round(slider.value * 100) + "%"
                        color: root.colFg
                        font {
                            family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                            pixelSize: 8
                            bold: true
                        }
                        opacity: root.isMuted ? 0.4 : 0.8
                        Behavior on opacity {
                            NumberAnimation {
                                duration: 150
                            }
                        }
                    }
                }

                handle: Item {
                    implicitWidth: 0
                    implicitHeight: 0
                }

                onMoved: root.moved()
            }

            // AirPlay Output switcher icon button
            Item {
                id: airPlayBtn
                visible: root.showAirPlayButton
                width: 24
                height: 24
                anchors.top: parent.top
                anchors.topMargin: 4
                anchors.left: parent.left
                anchors.leftMargin: 4
                z: 10

                Rectangle {
                    anchors.fill: parent
                    radius: 12
                    color: airPlayMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : "transparent"
                    Behavior on color { ColorAnimation { duration: 150 } }
                }

                Text {
                    anchors.centerIn: parent
                    text: "󰓃" // AirPlay/Output Icon
                    color: root.colFg
                    font {
                        family: shellRoot ? shellRoot.iconFontFamily : "sans-serif"
                        pixelSize: 12
                    }
                    opacity: airPlayMouse.containsMouse ? 1.0 : 0.6
                    Behavior on opacity { NumberAnimation { duration: 150 } }
                }

                MouseArea {
                    id: airPlayMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: root.airPlayClicked()
                }
            }

            // Interactive Icon overlayed on top of the Slider's bottom area
            Item {
                id: iconOverlay
                width: 32
                height: 32
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 2
                anchors.horizontalCenter: parent.horizontalCenter

                Rectangle {
                    anchors.centerIn: parent
                    width: 26
                    height: 26
                    radius: 13
                    color: iconMouseArea.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
                    Behavior on color {
                        ColorAnimation {
                            duration: 150
                        }
                    }
                }

                Text {
                    id: iconItem
                    anchors.centerIn: parent
                    text: root.iconText
                    color: root.colFg
                    font {
                        family: shellRoot ? shellRoot.iconFontFamily : "sans-serif"
                        pixelSize: 13
                    }
                    opacity: root.isMuted ? 0.5 : 1.0
                    Behavior on opacity {
                        NumberAnimation {
                            duration: 150
                        }
                    }
                }

                MouseArea {
                    id: iconMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton
                    onClicked: {
                        root.iconClicked();
                    }
                }
            }
        }

        // Label underneath the slider
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: root.labelText
            color: shellRoot ? shellRoot.colMuted : "#888888"
            font {
                family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                pixelSize: 9
                bold: true
            }
        }
    }
}
