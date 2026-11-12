import QtQuick
import QtQuick.Layouts

Item {
    id: commsRoot
    width: 160
    height: 24
    property bool active: false

    // Telemetry simulation state for Teenage Engineering Field Meter
    property var levels: [2, 3, 1, 4, 3, 2, 4, 3, 1, 2, 3, 4, 2, 1]
    property real tickCount: 0

    Timer {
        id: teMeterTimer
        interval: 65
        running: commsRoot.active
        repeat: true
        onTriggered: {
            commsRoot.tickCount += 1;
            var newLevels = [];
            for (var i = 0; i < 14; i++) {
                // Procedural audio noise simulation matching speech cadence
                var base = Math.sin(commsRoot.tickCount * 0.4 + i * 0.8) * 0.5 + 0.5;
                var noise = (Math.random() * 0.4);
                var val = Math.min(4, Math.max(1, Math.round((base + noise) * 3.5)));
                newLevels.push(val);
            }
            commsRoot.levels = newLevels;
        }
    }

    RowLayout {
        anchors.centerIn: parent
        spacing: 6

        // Live recording indicator dot (blinking red LED)
        Rectangle {
            width: 6
            height: 6
            radius: 1
            color: "#FF453A"
            Layout.alignment: Qt.AlignVCenter
            SequentialAnimation on opacity {
                loops: Animation.Infinite
                running: commsRoot.active
                NumberAnimation { from: 1.0; to: 0.2; duration: 400; easing.type: Easing.InOutQuad }
                NumberAnimation { from: 0.2; to: 1.0; duration: 400; easing.type: Easing.InOutQuad }
            }
        }

        // Berkeley Monospace Label
        Text {
            text: "MIC"
            color: "#FF453A"
            font {
                family: "Geist Mono, JetBrains Mono, monospace"
                pixelSize: 10
                bold: true
            }
            Layout.alignment: Qt.AlignVCenter
        }

        Text {
            text: "│"
            color: Qt.rgba(1, 1, 1, 0.18)
            font.pixelSize: 11
            Layout.alignment: Qt.AlignVCenter
        }

        // Teenage Engineering 14-Column Segmented LED Ladder (Constant width)
        Row {
            spacing: 2
            Layout.alignment: Qt.AlignVCenter

            Repeater {
                model: 14
                Column {
                    spacing: 1
                    property int activeSegments: commsRoot.active ? (commsRoot.levels[index] || 1) : 0

                    // Segment 4 (Top Peak - Red)
                    Rectangle {
                        width: 4
                        height: 3
                        radius: 1
                        color: activeSegments >= 4 ? "#FF453A" : Qt.rgba(1, 1, 1, 0.08)
                        Behavior on color { ColorAnimation { duration: 60 } }
                    }

                    // Segment 3 (High Mid - Apple Orange)
                    Rectangle {
                        width: 4
                        height: 3
                        radius: 1
                        color: activeSegments >= 3 ? "#FF9F0A" : Qt.rgba(1, 1, 1, 0.08)
                        Behavior on color { ColorAnimation { duration: 60 } }
                    }

                    // Segment 2 (Mid - Apple Green)
                    Rectangle {
                        width: 4
                        height: 3
                        radius: 1
                        color: activeSegments >= 2 ? "#30D158" : Qt.rgba(1, 1, 1, 0.08)
                        Behavior on color { ColorAnimation { duration: 60 } }
                    }

                    // Segment 1 (Base - Apple Green)
                    Rectangle {
                        width: 4
                        height: 3
                        radius: 1
                        color: activeSegments >= 1 ? "#30D158" : Qt.rgba(1, 1, 1, 0.08)
                        Behavior on color { ColorAnimation { duration: 60 } }
                    }
                }
            }
        }

        Text {
            text: "│"
            color: Qt.rgba(1, 1, 1, 0.18)
            font.pixelSize: 11
            Layout.alignment: Qt.AlignVCenter
        }

        // Static Monospace Status Badge
        Text {
            text: "LIVE"
            color: "#30D158"
            font {
                family: "Geist Mono, JetBrains Mono, monospace"
                pixelSize: 9
                bold: true
            }
            Layout.alignment: Qt.AlignVCenter
        }
    }
}
