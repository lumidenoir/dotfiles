import QtQuick
import QtQuick.Effects

Item {
    id: root

    property string text: ""
    property string subtitle: ""
    property bool show: false
    property string placement: "below" // "above" or "below"
    property real fontScale: 1.0
    property string fontFamily: "SF Pro Display"

    property color colBg: Qt.rgba(0.05, 0.05, 0.10, 0.96)
    property color colBorder: Qt.rgba(1, 1, 1, 0.18)
    property color colFg: "#ffffff"
    property color colMuted: Qt.rgba(1, 1, 1, 0.60)

    readonly property bool isBelow: placement === "below"
    readonly property real pointerHeight: 4
    readonly property real gapMargin: 6

    property bool armed: false

    width: bubbleRect.width
    height: bubbleRect.height + pointerHeight
    z: 9999

    anchors.horizontalCenter: parent ? parent.horizontalCenter : undefined
    anchors.bottom: isBelow ? undefined : (parent ? parent.top : undefined)
    anchors.bottomMargin: isBelow ? 0 : gapMargin
    anchors.top: isBelow ? (parent ? parent.bottom : undefined) : undefined
    anchors.topMargin: isBelow ? gapMargin : 0

    visible: armed || opacity > 0.01
    opacity: armed ? 1.0 : 0.0
    Behavior on opacity { NumberAnimation { duration: root.armed ? 120 : 80; easing.type: Easing.OutQuad } }

    Timer {
        id: delayTimer
        interval: 350
        onTriggered: root.armed = true
    }

    onShowChanged: {
        if (show && root.text !== "") {
            delayTimer.restart();
        } else {
            delayTimer.stop();
            armed = false;
        }
    }

    Rectangle {
        id: bubbleRect
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: root.isBelow ? parent.top : undefined
        anchors.bottom: root.isBelow ? undefined : parent.bottom
        width: Math.max(titleLabel.implicitWidth, subtitleLabel.implicitWidth) + Math.round(16 * fontScale)
        height: textColumn.implicitHeight + Math.round(8 * fontScale)
        radius: Math.round(6 * fontScale)
        color: root.colBg
        border.width: 1
        border.color: root.colBorder
        antialiasing: true

        Column {
            id: textColumn
            anchors.centerIn: parent
            spacing: Math.round(2 * fontScale)

            Text {
                id: titleLabel
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.text
                color: root.colFg
                font {
                    family: root.fontFamily
                    pixelSize: Math.round(11 * fontScale)
                    weight: Font.Medium
                }
            }

            Text {
                id: subtitleLabel
                anchors.horizontalCenter: parent.horizontalCenter
                visible: root.subtitle !== ""
                text: root.subtitle
                color: root.colMuted
                font {
                    family: root.fontFamily
                    pixelSize: Math.round(10 * fontScale)
                }
            }
        }
    }

    Canvas {
        width: 10
        height: root.pointerHeight
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: root.isBelow ? parent.top : undefined
        anchors.bottom: root.isBelow ? undefined : parent.bottom
        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            ctx.fillStyle = root.colBg;
            ctx.beginPath();
            if (root.isBelow) {
                ctx.moveTo(0, height);
                ctx.lineTo(width, height);
                ctx.lineTo(width / 2, 0);
            } else {
                ctx.moveTo(0, 0);
                ctx.lineTo(width, 0);
                ctx.lineTo(width / 2, height);
            }
            ctx.closePath();
            ctx.fill();
        }
    }
}
