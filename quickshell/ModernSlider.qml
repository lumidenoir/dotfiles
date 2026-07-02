import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell

Slider {
    id: mSlider
    
    property var shellRoot: null
    property color colFg: shellRoot ? shellRoot.colFg : "#ffffff"
    property bool batteryMode: shellRoot ? shellRoot.batteryMode : false
    property color sliderAccent: colFg

    Layout.fillWidth: true
    from: 0; to: 1.0

    background: Rectangle {
        x: mSlider.leftPadding
        y: mSlider.topPadding + mSlider.availableHeight / 2 - height / 2
        implicitWidth: 200
        implicitHeight: 6
        width: mSlider.availableWidth
        height: implicitHeight
        radius: 4
        color: Qt.rgba(1, 1, 1, 0.1)
        Rectangle {
            width: mSlider.visualPosition * parent.width
            height: parent.height
            color: mSlider.sliderAccent
            radius: 4
        }
    }

    handle: Rectangle {
        x: mSlider.leftPadding + mSlider.visualPosition * (mSlider.availableWidth - width)
        y: mSlider.topPadding + mSlider.availableHeight / 2 - height / 2
        implicitWidth: 14
        implicitHeight: 14
        radius: 7
        color: mSlider.pressed ? Qt.rgba(0.8, 0.8, 0.8, 1) : "#ffffff"
        scale: mSlider.pressed || mSlider.hovered ? 1.2 : 1.0
        Behavior on scale { NumberAnimation { duration: mSlider.batteryMode ? 0 : 100 } }
    }
}
