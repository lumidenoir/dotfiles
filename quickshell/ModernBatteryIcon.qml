import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell

Item {
    id: battIcon
    property real level: 1.0
    property bool charging: false
    
    property var shellRoot: {
        var p = parent;
        while (p) {
            if (p.shellRoot !== undefined) return p.shellRoot;
            p = p.parent;
        }
        return null;
    }
    property color colFg: shellRoot ? shellRoot.colFg : "#ffffff"
    property bool batteryMode: shellRoot ? shellRoot.batteryMode : false

    implicitWidth: 32
    implicitHeight: 14

    Rectangle {
        id: outline
        width: 26
        height: 12
        anchors.verticalCenter: parent.verticalCenter
        color: "transparent"
        border.color: battIcon.colFg
        border.width: 1.5
        radius: 4
        opacity: 0.7

        Rectangle {
            id: fill
            x: 2
            y: 2
            width: Math.max(0, (parent.width - 4) * battIcon.level)
            height: parent.height - 4
            radius: 2
            clip: true
            color: {
                if (battIcon.charging) return "#76B900";
                if (battIcon.level <= 0.2) return "#FF3B30";
                return battIcon.colFg;
            }
            Behavior on width { NumberAnimation { duration: battIcon.batteryMode ? 0 : 300; easing.type: Easing.OutCubic } }

            // Shimmer Sweep
            Rectangle {
                width: 6
                height: parent.height
                visible: battIcon.charging
                color: Qt.rgba(1, 1, 1, 0.45)

                NumberAnimation on x {
                    from: -6
                    to: fill.width
                    duration: 1500
                    loops: Animation.Infinite
                    running: battIcon.charging && !battIcon.batteryMode
                }
            }
        }
    }

    // The nub
    Rectangle {
        id: nub
        width: 3
        height: 6
        anchors.left: outline.right
        anchors.leftMargin: 1
        anchors.verticalCenter: parent.verticalCenter
        color: battIcon.colFg
        opacity: 0.7
        radius: 1.5
    }

    // Charging bolt
    Text {
        visible: battIcon.charging
        text: ""
        font.pixelSize: 9
        color: "#ffffff"
        anchors.centerIn: outline
    }

    // Rising Charge Particles
    Repeater {
        model: battIcon.charging ? 6 : 0
        delegate: Rectangle {
            id: pBubble
            width: 2
            height: 2
            radius: 1
            color: "#76B900"
            opacity: 0.0
            x: outline.x + Math.random() * (outline.width - 4) + 2
            y: outline.y + outline.height / 2

            SequentialAnimation on y {
                loops: Animation.Infinite
                running: battIcon.charging && !battIcon.batteryMode

                PauseAnimation { duration: index * 450 + Math.random() * 200 }
                ParallelAnimation {
                    NumberAnimation { from: outline.y + outline.height / 2; to: outline.y - 14 - Math.random() * 8; duration: 1600; easing.type: Easing.OutQuad }
                    NumberAnimation { target: pBubble; property: "opacity"; from: 0.8; to: 0.0; duration: 1600 }
                }
                PropertyAction { target: pBubble; property: "opacity"; value: 0.0 }
            }
        }
    }
}
