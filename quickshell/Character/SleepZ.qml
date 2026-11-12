// SPDX-License-Identifier: MIT
// Sleep "Z" Particle for Grokbot
import QtQuick
import "../Singletons"

Item {
    id: zItem
    property real size: 11
    property real rise: 32
    property real drift: 12
    property int delay: 0
    property color textColor: Qt.rgba(0.75, 0.82, 1.0, 0.85)

    width: size
    height: size
    scale: 0.4
    opacity: 0
    transformOrigin: Item.Center

    Text {
        anchors.centerIn: parent
        text: "z"
        color: zItem.textColor
        font {
            family: "sans-serif"
            pixelSize: Math.round(zItem.size)
            bold: true
        }
    }

    readonly property int life: 1600 + Math.round(Math.random() * 400)
    readonly property real sway: 8 + Math.random() * 6

    SequentialAnimation {
        running: true
        PauseAnimation { duration: zItem.delay }
        ParallelAnimation {
            NumberAnimation { target: zItem; property: "y"; to: zItem.y - zItem.rise; duration: zItem.life; easing.type: Easing.OutCubic }
            NumberAnimation { target: zItem; property: "x"; to: zItem.x + zItem.drift; duration: zItem.life; easing.type: Easing.InOutSine }
            NumberAnimation { target: zItem; property: "scale"; to: 1.15; duration: 400; easing.type: Easing.OutBack }
            SequentialAnimation {
                NumberAnimation { target: zItem; property: "rotation"; to: zItem.sway; duration: 400; easing.type: Easing.InOutSine }
                NumberAnimation { target: zItem; property: "rotation"; to: -zItem.sway * 0.7; duration: 500; easing.type: Easing.InOutSine }
                NumberAnimation { target: zItem; property: "rotation"; to: zItem.sway * 0.3; duration: 600; easing.type: Easing.InOutSine }
            }
            SequentialAnimation {
                NumberAnimation { target: zItem; property: "opacity"; to: 0.9; duration: 250; easing.type: Easing.OutQuad }
                PauseAnimation { duration: zItem.life - 800 }
                NumberAnimation { target: zItem; property: "opacity"; to: 0; duration: 550; easing.type: Easing.InOutSine }
            }
        }
        ScriptAction { script: zItem.destroy() }
    }
}
