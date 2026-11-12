import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell

Slider {
    id: mSlider
    
    property var shellRoot: null
    property color colFg: shellRoot ? shellRoot.colFg : "#ffffff"
    property bool batteryMode: shellRoot ? shellRoot.batteryMode : false
    property color sliderAccent: shellRoot ? shellRoot.colAccent : "#3B82F6"

    Layout.fillWidth: true
    from: 0; to: 1.0

    // Enable active focus for keyboard navigation
    activeFocusOnTab: true

    background: Rectangle {
        x: mSlider.leftPadding
        y: mSlider.topPadding + mSlider.availableHeight / 2 - height / 2
        implicitWidth: 200
        implicitHeight: 2 // Thread-like thin track
        width: mSlider.availableWidth
        height: implicitHeight
        radius: 1
        color: (shellRoot && shellRoot.isPearlMode) ? Qt.rgba(0, 0, 0, 0.12) : Qt.rgba(1, 1, 1, 0.12)
        
        Rectangle {
            width: mSlider.visualPosition * parent.width
            height: parent.height
            color: mSlider.sliderAccent
            radius: 1
        }
    }

    handle: Rectangle {
        x: mSlider.leftPadding + mSlider.visualPosition * (mSlider.availableWidth - width)
        y: mSlider.topPadding + mSlider.availableHeight / 2 - height / 2
        implicitWidth: 2.5 // Elegant tick line
        implicitHeight: (mSlider.hovered || mSlider.pressed || mSlider.activeFocus) ? 14 : 8
        radius: 1.25
        color: (mSlider.hovered || mSlider.pressed || mSlider.activeFocus) ? mSlider.colFg : Qt.rgba(mSlider.colFg.r, mSlider.colFg.g, mSlider.colFg.b, 0.5)
        
        Behavior on implicitHeight { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }
        Behavior on color { ColorAnimation { duration: 120 } }
    }

    // Scroll wheel adjustment
    WheelHandler {
        onWheel: event => {
            var step = event.angleDelta.y > 0 ? 0.05 : -0.05;
            mSlider.value = Math.max(0.0, Math.min(1.0, mSlider.value + step));
            mSlider.moved();
        }
    }

    // Keyboard navigation to emit moved()
    Keys.onLeftPressed: {
        mSlider.value = Math.max(0.0, mSlider.value - 0.05);
        mSlider.moved();
    }
    Keys.onRightPressed: {
        mSlider.value = Math.min(1.0, mSlider.value + 0.05);
        mSlider.moved();
    }
    Keys.onDownPressed: {
        mSlider.value = Math.max(0.0, mSlider.value - 0.05);
        mSlider.moved();
    }
    Keys.onUpPressed: {
        mSlider.value = Math.min(1.0, mSlider.value + 0.05);
        mSlider.moved();
    }
}
