import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell

MouseArea {
    id: mbtn
    implicitWidth: 80
    implicitHeight: 40
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

    Layout.fillWidth: true
    Layout.preferredHeight: 40
    hoverEnabled: true

    Rectangle {
        anchors.fill: parent
        radius: 12
        color: mbtn.isActive ? Qt.rgba(mbtn.accent.r, mbtn.accent.g, mbtn.accent.b, 0.15)
                             : (mbtn.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(1, 1, 1, 0.1))
        border.color: "transparent"
        Behavior on color { ColorAnimation { duration: mbtn.batteryMode ? 100 : ((shellRoot && !shellRoot.batteryCharging) ? 90 : 150) } }
    }

    RowLayout {
        anchors.centerIn: parent
        width: Math.min(parent.width - 12, implicitWidth)
        spacing: 4
        Text { text: mbtn.iconText; color: mbtn.isActive ? mbtn.accent : mbtn.colFg; font.family: mbtn.fontFamily; font.pixelSize: 14 }
        Text {
            text: mbtn.text
            color: mbtn.isActive ? mbtn.accent : mbtn.colFg
            font.family: mbtn.fontFamily
            font.pixelSize: 11
            font.bold: true
            elide: Text.ElideRight
            Layout.fillWidth: true
        }
    }

    scale: containsPress ? 0.95 : 1.0
    Behavior on scale { NumberAnimation { duration: mbtn.batteryMode ? 100 : ((shellRoot && !shellRoot.batteryCharging) ? 90 : 150); easing.type: Easing.OutCubic } }
}
