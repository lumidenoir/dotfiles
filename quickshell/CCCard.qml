import QtQuick
import QtQuick.Layouts

Rectangle {
    id: cardRoot
    property var shellRoot: null
    property bool groundControlShow: false
    property bool showCard: true
    property int cardDelay: 0
    property bool hovered: false

    Layout.fillWidth: true
    color: hovered ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(1, 1, 1, 0.04)
    radius: 16
    border.color: hovered ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(1, 1, 1, 0.08)
    border.width: 1

    Behavior on color { ColorAnimation { duration: 150 } }
    Behavior on border.color { ColorAnimation { duration: 150 } }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onEntered: cardRoot.hovered = true
        onExited: cardRoot.hovered = false
        propagateComposedEvents: true
        onPressed: mouse => mouse.accepted = false
    }

    opacity: (groundControlShow && showCard) ? 1.0 : 0.0
    transform: Translate {
        y: groundControlShow ? 0 : 15
        Behavior on y {
            enabled: (groundControlShow || !showCard) && (shellRoot ? !shellRoot.batteryMode : true)
            SequentialAnimation {
                PauseAnimation { duration: groundControlShow ? cardDelay : 0 }
                NumberAnimation {
                    duration: groundControlShow ? 400 : 350
                    easing.type: groundControlShow ? Easing.OutCubic : Easing.OutQuint
                }
            }
        }
    }

    Behavior on opacity {
        enabled: shellRoot ? !shellRoot.batteryMode : true
        SequentialAnimation {
            PauseAnimation { duration: groundControlShow ? cardDelay : 0 }
            NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
        }
    }

    // Staggered entrance spring (slow, matches card reveal)
    property real _openScale: (groundControlShow && showCard) ? 1.0 : 0.9
    scale: _openScale

    Behavior on _openScale {
        enabled: (groundControlShow || !showCard) && (shellRoot ? !shellRoot.batteryMode : true)
        SequentialAnimation {
            PauseAnimation { duration: groundControlShow ? cardDelay : 0 }
            SpringAnimation { spring: 3.5; damping: 0.70; mass: 0.8 }
        }
    }

    layer.enabled: (opacity > 0.0 && opacity < 1.0) && (shellRoot ? !shellRoot.batteryMode : true)
}

