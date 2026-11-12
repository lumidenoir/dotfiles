import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import "Singletons"
import "Character"

PanelWindow {
    id: blobWindow

    property var shellRoot: null
    property var mindPilot: null

    readonly property real scaleFactor: shellRoot ? shellRoot.scaleFactor : 1.0
    readonly property real fontScale: scaleFactor * (shellRoot ? shellRoot.fontSizeMultiplier : 1.0)

    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "quickshell_minimo_blob"
    WlrLayershell.layer: WlrLayer.Overlay

    anchors {
        bottom: true
        right: true
    }

    margins {
        bottom: 0
        right: 0
    }

    implicitWidth: Math.round(220 * scaleFactor)
    implicitHeight: Math.round(80 * scaleFactor)

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    Component.onCompleted: Cursor.acquire()
    Component.onDestruction: Cursor.release()

    // Click-through input mask: strictly only Minimo himself intercepts clicks when resting.
    // When dodging/hidden or teleported, the mask is completely NULL so 100% of clicks pass through!
    mask: Region {
        Region {
            item: (blobContainer.visible && !blobWindow.isTeleported && !blobWindow.isDodging) ? blobPill : null
        }
    }

    // ── Global Coordinates & Gaze Tracking Calculation ──
    readonly property real screenWidth: (blobWindow.screen && blobWindow.screen.width > 0) ? blobWindow.screen.width : (Screen.width > 0 ? Screen.width : 1920)
    readonly property real screenHeight: (blobWindow.screen && blobWindow.screen.height > 0) ? blobWindow.screen.height : (Screen.height > 0 ? Screen.height : 1080)

    readonly property real restingMargin: Math.round(18 * scaleFactor)
    readonly property real restingCenterX: screenWidth - restingMargin - (blobPill.width / 2)
    readonly property real restingCenterY: screenHeight - restingMargin - (blobPill.height / 2)

    readonly property real blobGlobalCenterX: restingCenterX + blobPillTranslate.x
    readonly property real blobGlobalCenterY: restingCenterY + blobPillTranslate.y

    // ── Teleport State Machine ──
    // When MindPilot opens, Minimo "teleports" from this corner into the center Raycast window!
    readonly property bool isTeleported: mindPilot && (mindPilot.show || mindPilot.isClosing)

    // ── Screen Edge Dodge / Hide State ──
    // Cursor proximity hysteresis: enters dodge mode at <65px, restores at >120px.
    // Immediately releases input mask to let all background clicks pass through!
    readonly property real cursorDist: (Cursor.ok && Cursor.x >= 0)
        ? Math.hypot(Cursor.x - restingCenterX, Cursor.y - restingCenterY)
        : 9999
    property bool isDodging: false
    onCursorDistChanged: {
        if (cursorDist < Math.round(65 * scaleFactor)) {
            if (!isDodging) isDodging = true;
        } else if (cursorDist > Math.round(120 * scaleFactor)) {
            if (isDodging) isDodging = false;
        }
    }

    Item {
        id: blobContainer
        anchors.fill: parent
        visible: opacity > 0.01

        opacity: blobWindow.isTeleported ? 0.0 : 1.0
        scale: blobWindow.isTeleported ? 0.2 : 1.0

        Behavior on opacity {
            NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
        }
        Behavior on scale {
            SpringAnimation { spring: 4.8; damping: 0.65; mass: 0.6 }
        }

        // ── 1. Floating Tooltip Pill (Shows when hovering near resting spot, hidden when tucked) ──
        Rectangle {
            id: tooltipPill
            anchors.right: blobPill.left
            anchors.rightMargin: Math.round(10 * scaleFactor)
            anchors.verticalCenter: blobPill.verticalCenter
            height: Math.round(28 * scaleFactor)
            width: tooltipLayout.implicitWidth + Math.round(18 * scaleFactor)
            radius: height / 2

            color: Qt.rgba(0.08, 0.09, 0.13, 0.88)
            border.color: Qt.rgba(203/255, 166/255, 247/255, 0.35) // Mauve highlight
            border.width: 1

            visible: opacity > 0.001
            opacity: (dodgeDetector.containsMouse && !blobWindow.isDodging) ? 1.0 : 0.0
            transform: Translate {
                x: (dodgeDetector.containsMouse && !blobWindow.isDodging) ? 0 : Math.round(12 * scaleFactor)
                Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
            }
            Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

            RowLayout {
                id: tooltipLayout
                anchors.centerIn: parent
                spacing: Math.round(6 * scaleFactor)

                Text {
                    text: "Kafka"
                    color: "#F5C2E7"
                    font {
                        family: shellRoot ? shellRoot.textFontFamily : "Inter"
                        pixelSize: Math.round(11 * fontScale)
                        weight: Font.DemiBold
                    }
                }

                Rectangle {
                    width: 3
                    height: 3
                    radius: 1.5
                    color: Qt.rgba(1, 1, 1, 0.35)
                }

                Text {
                    text: "Super+G"
                    color: Qt.rgba(248/255, 250/255, 252/255, 0.75)
                    font {
                        family: "JetBrains Mono"
                        pixelSize: Math.round(9.5 * fontScale)
                        weight: Font.Medium
                    }
                }
            }
        }


        // ── 3. Main Mascot Orb (No black background, dodges to screen edge on cursor proximity!) ──
        Rectangle {
            id: blobPill
            anchors.right: parent.right
            anchors.rightMargin: blobWindow.restingMargin
            anchors.bottom: parent.bottom
            anchors.bottomMargin: blobWindow.restingMargin
            width: Math.round(38 * scaleFactor)
            height: Math.round(38 * scaleFactor)
            radius: width / 2

            // Clean floating character without black background box
            color: "transparent"
            border.color: "transparent"
            border.width: 0

            // Disappears and completely relinquishes mouse clicks when dodging
            opacity: blobWindow.isDodging ? 0.0 : 1.0
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutQuad } }

            // Dynamic Dodge Translation into the Screen Edge Corner
            transform: Translate {
                id: blobPillTranslate
                x: blobWindow.isDodging ? (blobWindow.restingMargin + Math.round(20 * scaleFactor)) : 0
                y: blobWindow.isDodging ? (blobWindow.restingMargin + Math.round(20 * scaleFactor)) : 0

                Behavior on x { SpringAnimation { spring: 4.8; damping: 0.68; mass: 0.55 } }
                Behavior on y { SpringAnimation { spring: 4.8; damping: 0.68; mass: 0.55 } }
            }

            // ── 4. Minimo Mascot Inside ──
            Item {
                id: mascotContainer
                anchors.centerIn: parent
                width: Math.round(40 * scaleFactor)
                height: Math.round(40 * scaleFactor)

                // Subtle vertical sinusoidal bob float (idle breathing, runs continuously without snapping)
                property real bobY: 0
                transform: Translate { y: mascotContainer.bobY }

                SequentialAnimation on bobY {
                    running: blobContainer.visible && !blobWindow.isTeleported && !blobWindow.isDodging
                    loops: Animation.Infinite
                    NumberAnimation { from: -2.0; to: 2.0; duration: 2000; easing.type: Easing.InOutSine }
                    NumberAnimation { from: 2.0; to: -2.0; duration: 2000; easing.type: Easing.InOutSine }
                }

                Character {
                    id: characterMascot
                    anchors.centerIn: parent
                    size: Math.round(36 * scaleFactor)
                    active: blobContainer.visible && !blobWindow.isTeleported && !blobWindow.isDodging
                    globalOriginX: blobWindow.restingCenterX
                    globalOriginY: blobWindow.restingCenterY
                    sphereColor: (shellRoot && shellRoot.minimoBotMode === "light") ? "#FFFFFF" : "#1e1e2e"
                    eyeColor: blobWindow.isDodging ? "#CBA6F7" : ((shellRoot && shellRoot.minimoBotMode === "light") ? "#121215" : "#FFFFFF")
                    squint: blobWindow.isDodging ? 0.70 : ((mindPilot && mindPilot.isAgentRunning) ? 0.75 : 0.0)
                }
            }

            // ── 5. Mouse Interaction (Disabled when dodging so clicks hit background windows!) ──
            MouseArea {
                id: dodgeDetector
                anchors.fill: parent
                enabled: !blobWindow.isDodging && !blobWindow.isTeleported
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor

                onEntered: {
                    CharacterBus.react("curious");
                }

                onClicked: {
                    CharacterBus.react("hop");
                    if (shellRoot && typeof shellRoot.toggleMindPilot === "function") {
                        shellRoot.toggleMindPilot();
                    } else if (mindPilot) {
                        mindPilot.show = !mindPilot.show;
                    }
                }
            }
        }
    }
}
