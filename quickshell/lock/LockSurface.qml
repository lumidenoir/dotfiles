pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "Singletons"

Item {
    id: surface
    property real s: 1
    property var auth: null
    property string screenName: ""

    property bool active: false
    property real revealP: 0

    readonly property bool shouldOpen: active
    onShouldOpenChanged: if (shouldOpen)
        openAnim.restart()
    onActiveChanged: if (!active)
        closeAnim.restart()

    readonly property bool isMain: {
        var scr = Quickshell.screens;
        if (scr.length === 0)
            return true;
        return surface.screenName === scr[0].name;
    }

    clip: true

    // Pure OLED Pitch Black Base Surface (#000000)
    Rectangle {
        id: oledBase
        anchors.fill: parent
        color: "#000000"
    }

    // Music Visualizer Shaders Layer (Glow, Fluid Mesh, Tide Waves)
    GlowField {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: parent.height
        opacity: surface.revealP
    }

    // Lock Content (Clock, Hollow Knight mascot, Auth input, Audiophile Mini Player)
    Content {
        anchors.fill: parent
        s: surface.s
        auth: surface.auth
        isMain: surface.isMain
        opacity: surface.revealP
        scale: 1.02 - (0.02 * surface.revealP)
        transformOrigin: Item.Center
    }

    NumberAnimation {
        id: openAnim
        target: surface
        property: "revealP"
        to: 1
        duration: 350
        easing.type: Easing.OutCubic
    }

    NumberAnimation {
        id: closeAnim
        target: surface
        property: "revealP"
        to: 0
        duration: 250
        easing.type: Easing.OutQuad
    }
}
