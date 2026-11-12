import QtQuick
import QtQuick.Layouts

Item {
    id: chamber
    property real radius: 4
    property bool isFocused: false
    property color accentColor: "#FFB000"
    property real depthPx: 0.0
    property real absorption: 0.0
    property alias depthOpacity: chamber.absorption
    property real specular: 0.0
    property real ambientOcclusion: 0.0
    property var backdropSource: null

    default property alias content: innerContainer.data
    property alias contentItem: innerContainer

    property var shellRoot: null
    readonly property bool isPearl: false

    // Option B Tactical Stealth Recessed Chamber (Zero Shaders, Zero Draw-Calls)
    Rectangle {
        id: tacticalChamber
        anchors.fill: parent
        radius: chamber.radius
        color: Qt.rgba(0.06, 0.07, 0.09, 0.75)
        border.color: chamber.isFocused ? chamber.accentColor : Qt.rgba(1, 1, 1, 0.08)
        border.width: 1
        clip: true

        Behavior on border.color { ColorAnimation { duration: 120 } }
    }

    // Inner Child Content Container
    Item {
        id: innerContainer
        anchors.fill: parent
    }
}
