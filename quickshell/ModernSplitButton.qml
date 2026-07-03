import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell

Item {
    id: mbtn
    implicitWidth: 120
    implicitHeight: 40
    property string title: ""
    property string text
    property string iconText
    property bool isActive: false
    
    property var shellRoot: {
        if (parent && parent.shellRoot !== undefined) return parent.shellRoot;
        if (parent && parent.parent && parent.parent.shellRoot !== undefined) return parent.parent.shellRoot;
        if (parent && parent.parent && parent.parent.parent && parent.parent.parent.shellRoot !== undefined) return parent.parent.parent.shellRoot;
        return null;
    }
    property color colFg: shellRoot ? shellRoot.colFg : "#ffffff"
    property bool batteryMode: shellRoot ? shellRoot.batteryMode : false
    property string fontFamily: shellRoot ? shellRoot.fontFamily : "sans-serif"
    property color accent: colFg

    signal mainClicked()
    signal iconClicked()
    signal rightIconClicked()
    signal scrolled(int angle)

    Layout.fillWidth: true
    Layout.preferredHeight: 40

    Rectangle {
        anchors.fill: parent
        radius: 12
        color: (mainMouse.containsMouse || iconMouse.containsMouse || rightIconMouse.containsMouse) ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(1, 1, 1, 0.1)
        border.color: "transparent"
        Behavior on color { ColorAnimation { duration: mbtn.batteryMode ? 100 : ((shellRoot && !shellRoot.batteryCharging) ? 90 : 150) } }
    }

    MouseArea {
        id: mainMouse
        anchors.fill: parent
        hoverEnabled: true
        onClicked: mbtn.mainClicked()
        onWheel: wheel => mbtn.scrolled(wheel.angleDelta.y)
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        spacing: 8

        // Icon Circle Box
        Rectangle {
            Layout.preferredWidth: 32
            Layout.preferredHeight: 32
            radius: 16
            color: mbtn.isActive ? mbtn.accent : Qt.rgba(1, 1, 1, 0.15)

            Text {
                anchors.centerIn: parent
                text: mbtn.iconText
                color: mbtn.isActive ? "#ffffff" : mbtn.colFg
                font.family: mbtn.fontFamily
                font.pixelSize: 16
            }

            MouseArea {
                id: iconMouse
                anchors.fill: parent
                hoverEnabled: true
                // Consume the press so mainMouse doesn't also scale the whole button
                onPressed: mouse => mouse.accepted = true
                onClicked: mbtn.iconClicked()
            }

            scale: iconMouse.containsPress ? 0.9 : (iconMouse.containsMouse ? 1.05 : 1.0)
            Behavior on scale { NumberAnimation { duration: mbtn.batteryMode ? 100 : ((shellRoot && !shellRoot.batteryCharging) ? 90 : 150) } }
            Behavior on color { ColorAnimation { duration: mbtn.batteryMode ? 100 : ((shellRoot && !shellRoot.batteryCharging) ? 90 : 150) } }
        }

        // Text Column Stack (Vertical Redesigned Layout)
        ColumnLayout {
            spacing: 0
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter

            Text {
                text: mbtn.title !== "" ? mbtn.title : mbtn.text
                color: mbtn.colFg
                font.family: mbtn.fontFamily
                font.pixelSize: mbtn.title !== "" ? 11 : 13
                font.bold: true
                Layout.fillWidth: true
                elide: Text.ElideRight
            }

            Text {
                visible: mbtn.title !== ""
                text: mbtn.text
                color: mbtn.isActive ? mbtn.accent : Qt.rgba(mbtn.colFg.r, mbtn.colFg.g, mbtn.colFg.b, 0.65)
                font.family: mbtn.fontFamily
                font.pixelSize: 10
                Layout.fillWidth: true
                elide: Text.ElideRight
                Behavior on color { ColorAnimation { duration: mbtn.batteryMode ? 100 : ((shellRoot && !shellRoot.batteryCharging) ? 90 : 150) } }
            }
        }

        // Right Arrow
        Item {
            Layout.preferredWidth: 20
            Layout.preferredHeight: 20
            Layout.alignment: Qt.AlignVCenter

            Text {
                anchors.centerIn: parent
                text: ""
                color: rightIconMouse.containsMouse ? mbtn.colFg : Qt.rgba(mbtn.colFg.r, mbtn.colFg.g, mbtn.colFg.b, 0.3)
                font.family: mbtn.fontFamily
                font.pixelSize: 14
                Behavior on color { ColorAnimation { duration: mbtn.batteryMode ? 100 : ((shellRoot && !shellRoot.batteryCharging) ? 90 : 150) } }
            }

            MouseArea {
                id: rightIconMouse
                anchors.fill: parent
                hoverEnabled: true
                // Consume the press so mainMouse doesn't also scale the whole button
                onPressed: mouse => mouse.accepted = true
                onClicked: mbtn.rightIconClicked()
            }
        }
    }

    scale: mainMouse.containsPress ? 0.98 : 1.0
    Behavior on scale { NumberAnimation { duration: mbtn.batteryMode ? 100 : ((shellRoot && !shellRoot.batteryCharging) ? 90 : 150); easing.type: Easing.OutBack } }
}
