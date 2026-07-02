import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell

MouseArea {
    id: root
    
    implicitWidth: 56 * (shellRoot ? shellRoot.scaleFactor : 1.0)
    implicitHeight: 56 * (shellRoot ? shellRoot.scaleFactor : 1.0)
    Layout.fillWidth: true
    
    property string label: ""
    property string iconText: ""
    property bool active: false
    property color accent: "#007AFF"
    
    required property var shellRoot
    
    property color colFg: shellRoot ? shellRoot.colFg : "#ffffff"
    property bool batteryMode: shellRoot ? shellRoot.batteryMode : false
    property string fontFamily: shellRoot ? shellRoot.fontFamily : "sans-serif"
    property string iconFontFamily: shellRoot ? shellRoot.iconFontFamily : "sans-serif"
    
    hoverEnabled: true
    
    ColumnLayout {
        anchors.fill: parent
        spacing: 4
        
        // Circular Button
        Rectangle {
            id: circle
            Layout.preferredWidth: 36 * (shellRoot ? shellRoot.scaleFactor : 1.0)
            Layout.preferredHeight: 36 * (shellRoot ? shellRoot.scaleFactor : 1.0)
            Layout.alignment: Qt.AlignHCenter
            radius: 18 * (shellRoot ? shellRoot.scaleFactor : 1.0)
            clip: true
            
            color: root.active 
                ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.45)
                : (root.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.10))
            
            border.color: root.active ? "transparent" : Qt.rgba(1, 1, 1, 0.05)
            border.width: 1

            Behavior on color { ColorAnimation { duration: root.batteryMode ? 0 : 150 } }
            
            Rectangle {
                anchors.centerIn: parent
                width: 36 * (shellRoot ? shellRoot.scaleFactor : 1.0)
                height: 36 * (shellRoot ? shellRoot.scaleFactor : 1.0)
                radius: parent.radius
                color: Qt.rgba(1, 1, 1, 0.25)
                scale: root.containsPress ? 1.0 : 0.0
                opacity: root.containsPress ? 1.0 : 0.0
                Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
                Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
            }

            Text {
                anchors.centerIn: parent
                text: root.iconText
                color: root.active ? "#ffffff" : root.colFg
                font {
                    family: root.iconFontFamily
                    pixelSize: 15 * (shellRoot ? shellRoot.scaleFactor : 1.0)
                }
            }

            // Coffee steam particles for Caffeine mode
            Repeater {
                model: (root.active && root.label === "Caffeine" && !root.batteryMode) ? 2 : 0
                delegate: Text {
                    id: steamParticle
                    text: "~"
                    font {
                        family: root.fontFamily
                        pixelSize: 10 * (shellRoot ? shellRoot.scaleFactor : 1.0)
                    }
                    color: "#ffffff"
                    opacity: 0.0
                    x: circle.width / 2 + (index - 1) * 4 - 3
                    y: circle.height / 2 - 8
 
                    SequentialAnimation on y {
                        loops: Animation.Infinite
                        running: root.active && root.label === "Caffeine" && !root.batteryMode

                        PauseAnimation { duration: index * 400 }
                        ParallelAnimation {
                            NumberAnimation { from: circle.height / 2 - 8; to: circle.height / 2 - 20; duration: 1200; easing.type: Easing.OutSine }
                            NumberAnimation { from: steamParticle.x; to: steamParticle.x + Math.sin(index + 1) * 3; duration: 1200; target: steamParticle; property: "x" }
                            NumberAnimation { target: steamParticle; property: "opacity"; from: 0.6; to: 0.0; duration: 1200 }
                        }
                        PropertyAction { target: steamParticle; property: "opacity"; value: 0.0 }
                    }
                }
            }
        }
        
        // Label underneath the circle
        Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: root.label
            color: root.active ? root.colFg : (shellRoot ? shellRoot.colMuted : "#888888")
            font {
                family: root.fontFamily
                pixelSize: 9 * (shellRoot ? shellRoot.scaleFactor : 1.0)
                bold: true
            }
            elide: Text.ElideRight
            
            Behavior on color { ColorAnimation { duration: root.batteryMode ? 0 : 150 } }
        }
    }
    
    scale: containsPress ? 0.92 : 1.0
    Behavior on scale { NumberAnimation { duration: root.batteryMode ? 0 : 120; easing.type: Easing.OutCubic } }
}
