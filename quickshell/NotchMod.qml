import QtQuick
import QtQuick.Layouts

MouseArea {
    id: modRoot
    property var shellRoot: null
    property string text
    property color textColor: shellRoot ? shellRoot.colFg : "#ffffff"
    property color hoverColor: shellRoot ? shellRoot.colHover : "transparent"
    property color activeColor: Qt.rgba(1, 1, 1, 0.15)
    property color bgColor: containsPress ? activeColor : (containsMouse ? hoverColor : "transparent")
    property bool blink: false
    property bool show: true
    property real customWidth: 0
    default property alias customContent: contentBox.data

    // Custom content width/height measurement.
    property real contentWidth: customWidth > 0 ? 0 : (contentBox.children.length > 0 ? contentBox.childrenRect.width : modText.implicitWidth)
    property real contentHeight: customWidth > 0 ? 0 : (contentBox.children.length > 0 ? contentBox.childrenRect.height : modText.height)

    Layout.fillHeight: true
    Layout.preferredWidth: show ? (customWidth > 0 ? customWidth + 16 : contentWidth + 16) : 0
    Behavior on Layout.preferredWidth {
        NumberAnimation {
            duration: shellRoot && shellRoot.batteryMode ? 100 : ((shellRoot && !shellRoot.batteryCharging) ? 180 : 300)
            easing.type: Easing.OutExpo
        }
    }

    visible: Layout.preferredWidth > 0
    clip: true
    hoverEnabled: true

    Rectangle {
        id: bgRect
        anchors.fill: parent
        color: parent.bgColor
        radius: height / 2
        Behavior on color {
            ColorAnimation {
                duration: shellRoot && shellRoot.batteryMode ? 100 : ((shellRoot && !shellRoot.batteryCharging) ? 120 : 200)
            }
        }

        SequentialAnimation on opacity {
            id: blinkAnim
            running: modRoot.blink
            loops: Animation.Infinite
            NumberAnimation {
                to: 0.1
                duration: shellRoot && shellRoot.batteryMode ? 100 : ((shellRoot && !shellRoot.batteryCharging) ? 300 : 500)
            }
            NumberAnimation {
                to: 1.0
                duration: shellRoot && shellRoot.batteryMode ? 100 : ((shellRoot && !shellRoot.batteryCharging) ? 300 : 500)
            }
            onRunningChanged: {
                if (!running) {
                    bgRect.opacity = 1.0;
                }
            }
        }
    }

    Item {
        anchors.centerIn: parent
        width: modRoot.customWidth > 0 ? modRoot.customWidth : modRoot.contentWidth
        height: modRoot.customWidth > 0 ? Math.round(20 * (shellRoot ? shellRoot.scaleFactor : 1.0)) : modRoot.contentHeight
        scale: parent.containsPress ? 0.85 : (parent.containsMouse ? 1.12 : 1.0)
        Behavior on scale {
            enabled: shellRoot ? !shellRoot.batteryMode : true
            SpringAnimation {
                spring: 4.5
                damping: 0.65
                mass: 0.6
            }
        }

        Text {
            id: modText
            text: modRoot.text
            color: modRoot.textColor
            font {
                family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                pixelSize: shellRoot ? shellRoot.fontSize : 10
                bold: true
            }
            anchors.centerIn: parent
            visible: modRoot.text !== ""
            Behavior on color {
                ColorAnimation {
                    duration: shellRoot && shellRoot.batteryMode ? 100 : ((shellRoot && !shellRoot.batteryCharging) ? 120 : 200)
                }
            }
        }

        Item {
            id: contentBox
            anchors.fill: parent
        }
    }
}
