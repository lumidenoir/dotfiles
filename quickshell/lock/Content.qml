pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Services.Mpris
import QtCore
import "Singletons"
import "Character"

Item {
    id: content
    property real s: 1
    property var auth: null
    property bool isMain: true

    readonly property bool authenticating: auth ? auth.authenticating : false
    property bool showError: false
    property bool showSuccess: false
    property bool reveal: false

    // Cyber-OLED Minimalist Palette (Aligned with Terminal HUD & Status Bar)
    readonly property color hkMask: "#F0F6FC"          // Crisp White-Silver Chitin Mask
    readonly property color hkVoid: "#000000"          // Pure OLED Pitch Black
    readonly property color hkSoulCyan: "#00E5FF"      // Cyber Electric Cyan / Sapphire Accent
    readonly property color hkSoulGlow: "#30D158"      // Emerald Green (Success State)
    readonly property color hkInfection: "#FF453A"     // Vivid Crimson Red (Error State)
    readonly property color hkMothwing: "#8B949E"      // Muted Metallic Silver
    readonly property color hkHallownestBg: Qt.rgba(0.04, 0.05, 0.07, 0.85) // Deep OLED Carbon Glass
    readonly property color hkBorder: Qt.rgba(0.18, 0.22, 0.30, 0.65)       // Razor HUD Border

    Connections {
        target: content.auth
        enabled: content.auth !== null
        function onFailed() {
            content.showError = true;
            content.showSuccess = false;
            content.reveal = false;
            input.text = "";
            shake.restart();
            if (minimoBot) {
                minimoBot.mood = "worried";
                botErrorShake.restart();
                errorRelaxTimer.restart();
            }
        }
        function onSucceeded() {
            content.showError = false;
            content.showSuccess = true;
            content.reveal = false;
            input.text = "";
            if (minimoBot) {
                minimoBot.mood = "";
                minimoBot.react("happyBounce");
            }
        }
    }

    Timer {
        id: errorRelaxTimer
        interval: 3500
        onTriggered: {
            if (minimoBot && minimoBot.mood === "worried")
                minimoBot.mood = "";
        }
    }

    SequentialAnimation {
        id: botErrorShake
        NumberAnimation { target: minimoBot; property: "rRot"; to: -14; duration: 60; easing.type: Easing.OutQuad }
        NumberAnimation { target: minimoBot; property: "rRot"; to: 14; duration: 90; easing.type: Easing.InOutQuad }
        NumberAnimation { target: minimoBot; property: "rRot"; to: -10; duration: 80; easing.type: Easing.InOutQuad }
        NumberAnimation { target: minimoBot; property: "rRot"; to: 10; duration: 80; easing.type: Easing.InOutQuad }
        NumberAnimation { target: minimoBot; property: "rRot"; to: 0; duration: 110; easing.type: Easing.OutBack }
    }

    Component.onCompleted: {
        if (minimoBot) minimoBot.react("greet");
    }

    readonly property var weekdays: ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    readonly property var months: ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
    readonly property string dateText: {
        var d = sysClock.date;
        return weekdays[d.getDay()] + ", " + months[d.getMonth()] + " " + d.getDate();
    }

    // MPRIS Player integration
    readonly property var player: {
        var list = Mpris.players.values;
        if (!list || list.length === 0)
            return null;
        var controllable = null;
        for (var i = 0; i < list.length; i++) {
            var p = list[i];
            if (!p)
                continue;
            if (p.isPlaying)
                return p;
            if (!controllable && p.canControl)
                controllable = p;
        }
        return controllable ? controllable : list[0];
    }

    readonly property bool hasPlayer: player !== null
    readonly property bool playing: hasPlayer && player.isPlaying

    readonly property string trackTitle: {
        if (!player)
            return "";
        return player.trackTitle ? player.trackTitle : "";
    }
    readonly property string trackArtist: {
        if (!player)
            return "";
        if (player.trackArtists && player.trackArtists.length > 0)
            return player.trackArtists;
        return player.trackArtist ? player.trackArtist : "";
    }
    readonly property string artUrl: {
        if (!player || !player.trackArtUrl)
            return "";
        var u = player.trackArtUrl;
        if (u.startsWith("/") && !u.startsWith("file://")) {
            return "file://" + u;
        }
        return u;
    }
    readonly property real lengthSec: hasPlayer && player.length > 0 ? player.length : 0
    readonly property real positionSec: hasPlayer ? player.position : 0
    readonly property real progress: lengthSec > 0 ? Math.max(0, Math.min(1, positionSec / lengthSec)) : 0

    function fmtTime(sec) {
        var m = Math.floor(sec / 60);
        var ss = Math.floor(sec % 60);
        return m + ":" + (ss < 10 ? "0" : "") + ss;
    }

    SystemClock {
        id: sysClock
        precision: SystemClock.Minutes
    }

    Timer {
        interval: 1000
        running: content.playing && content.isMain
        repeat: true
        onTriggered: if (content.player) content.player.positionChanged()
    }

    // Direct Fullscreen Pointer Tracker: feeds cursor coordinates directly to Cursor singleton at native refresh rate
    MouseArea {
        id: screenPointerTracker
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        propagateComposedEvents: true
        onPositionChanged: (mouse) => {
            Cursor.x = mouse.x;
            Cursor.y = mouse.y;
            Cursor.lastMove = Date.now();
            Cursor.ok = true;
        }
    }

    // =========================================================================
    // 1. TOP HEADER STATUS BAR (Date on left, Glass Status Capsule on right)
    // =========================================================================
    Item {
        id: topBar
        visible: content.isMain
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: 24 * content.s
        anchors.leftMargin: 32 * content.s
        anchors.rightMargin: 32 * content.s
        height: 36 * content.s

        // Left Date Display
        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8 * content.s

            Text {
                text: content.dateText
                color: Theme.bright
                opacity: 0.90
                font.family: Theme.font
                font.weight: 600
                font.pixelSize: 13 * content.s
                font.letterSpacing: 0.8 * content.s
                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: Qt.rgba(0, 0, 0, 0.45)
                    shadowBlur: 0.6
                    shadowVerticalOffset: 1
                }
            }
        }

        // Right Status Capsule (Mirrors quickshell bar's RightCapsule)
        Rectangle {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: 32 * content.s
            width: statusRow.implicitWidth + 24 * content.s
            radius: height / 2
            color: Theme.colBg
            border.width: 1
            border.color: Theme.colBorder

            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: Qt.rgba(0, 0, 0, 0.35)
                shadowBlur: 6 * content.s
                shadowVerticalOffset: 2 * content.s
            }

            Row {
                id: statusRow
                anchors.centerIn: parent
                spacing: 12 * content.s

                // CapsLock alert badge
                Rectangle {
                    visible: SysStatus.capsLock
                    anchors.verticalCenter: parent.verticalCenter
                    height: 20 * content.s
                    width: capsRow.implicitWidth + 12 * content.s
                    radius: height / 2
                    color: Qt.rgba(255 / 255, 69 / 255, 58 / 255, 0.25)
                    border.width: 1
                    border.color: Theme.crit

                    Row {
                        id: capsRow
                        anchors.centerIn: parent
                        spacing: 4 * content.s

                        GlyphIcon {
                            width: 11 * content.s
                            height: 11 * content.s
                            name: "alert-triangle"
                            color: Theme.crit
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: "CAPS LOCK"
                            color: Theme.crit
                            font.family: Theme.font
                            font.pixelSize: 9 * content.s
                            font.weight: 700
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }

                // Network indicator (Ethernet or Wi-Fi)
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 5 * content.s

                    GlyphIcon {
                        width: 13 * content.s
                        height: 13 * content.s
                        name: SysStatus.ethernetConnected ? "ethernet" : "wifi"
                        color: SysStatus.ethernetConnected ? Theme.success : (SysStatus.wifiSsid !== "" ? Theme.accent : Theme.dim)
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: SysStatus.ethernetConnected ? "Ethernet" : (SysStatus.wifiSsid !== "" ? SysStatus.wifiSsid : "Offline")
                        color: Theme.bright
                        opacity: 0.85
                        font.family: Theme.font
                        font.pixelSize: 11 * content.s
                        font.weight: 500
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                // Separator
                Rectangle {
                    width: 1
                    height: 12 * content.s
                    color: Qt.rgba(1, 1, 1, 0.15)
                    anchors.verticalCenter: parent.verticalCenter
                }

                // Volume indicator
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 5 * content.s

                    GlyphIcon {
                        width: 13 * content.s
                        height: 13 * content.s
                        name: SysStatus.volumeMuted ? "volume-x" : "volume"
                        color: SysStatus.volumeMuted ? Theme.crit : Theme.bright
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: SysStatus.volumeMuted ? "Muted" : SysStatus.volumeOut
                        color: Theme.bright
                        opacity: 0.85
                        font.family: Theme.font
                        font.pixelSize: 11 * content.s
                        font.weight: 500
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                // Bluetooth (if connected)
                Row {
                    visible: SysStatus.bluetoothStatus === "connected"
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 5 * content.s

                    Rectangle {
                        width: 1
                        height: 12 * content.s
                        color: Qt.rgba(1, 1, 1, 0.15)
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    GlyphIcon {
                        width: 13 * content.s
                        height: 13 * content.s
                        name: "bluetooth"
                        color: Theme.accent
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: SysStatus.bluetoothDevice
                        color: Theme.bright
                        opacity: 0.85
                        font.family: Theme.font
                        font.pixelSize: 11 * content.s
                        font.weight: 500
                        elide: Text.ElideRight
                        width: Math.min(100 * content.s, implicitWidth)
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }
    }

    // =========================================================================
    // 2. HERO CLOCK DISPLAY (Upper Stage)
    // =========================================================================
    Column {
        id: clockSection
        visible: content.isMain
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.max(48 * content.s, parent.height * 0.14)
        spacing: 6 * content.s

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 8 * content.s

            Text {
                id: clockText
                color: content.hkMask
                font.family: "Zen Kaku Gothic New"
                font.weight: 500
                font.pixelSize: 124 * content.s
                text: {
                    var d = sysClock.date;
                    if (!Flags.time12h)
                        return Qt.formatDateTime(d, "HH:mm");
                    var h = d.getHours() % 12;
                    if (h === 0) h = 12;
                    var m = d.getMinutes();
                    return h + ":" + (m < 10 ? "0" : "") + m;
                }
                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: Qt.rgba(0.10, 0.25, 0.45, 0.60)
                    shadowBlur: 1.4
                    shadowVerticalOffset: 3
                }
            }

            Text {
                visible: Flags.time12h
                anchors.baseline: clockText.baseline
                color: content.hkMothwing
                opacity: 0.75
                font.family: "Zen Kaku Gothic New"
                font.weight: 600
                font.pixelSize: 34 * content.s
                text: Qt.formatDateTime(sysClock.date, "AP")
            }
        }
    }

    // =========================================================================
    // 3. CENTER EMBODIED HOLLOW KNIGHT MASCOT (Visual Midpoint)
    // =========================================================================
    Item {
        id: minimoContainer
        visible: content.isMain
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.max(260 * content.s, Math.round(parent.height * 0.44 - height / 2))
        width: 128 * content.s
        height: 128 * content.s

        // Frosted Ambient Glass Aura Ring (Hollow Knight Soul Essence / Infection)
        Rectangle {
            anchors.centerIn: parent
            width: 128 * content.s
            height: 128 * content.s
            radius: width / 2
            color: content.showError ? Qt.rgba(1.0, 0.27, 0.23, 0.12)
                 : (content.showSuccess ? Qt.rgba(0.19, 0.82, 0.35, 0.15)
                 : Qt.rgba(0.0, 0.90, 1.0, 0.05))
            border.width: 1
            border.color: content.showError ? content.hkInfection
                        : (content.showSuccess ? content.hkSoulGlow
                        : Qt.rgba(0.0, 0.90, 1.0, 0.35))
            Behavior on border.color { ColorAnimation { duration: 250 } }
            Behavior on color { ColorAnimation { duration: 250 } }

            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: content.showError ? Qt.rgba(1.0, 0.27, 0.23, 0.45)
                           : (content.showSuccess ? Qt.rgba(0.19, 0.82, 0.35, 0.45)
                           : Qt.rgba(0.0, 0.90, 1.0, 0.25))
                shadowBlur: 20 * content.s
                shadowVerticalOffset: 4 * content.s
            }
        }

        // Hollow Knight Mask Character (Pale Porcelain Chitin Shell & Abyss Void Eyes)
        Character {
            id: minimoBot
            anchors.centerIn: parent
            size: Math.round(108 * content.s)
            active: content.isMain && content.opacity > 0.05
            sphereColor: content.hkMask          // Pale Chitin Shell of The Knight
            eyeColor: content.hkVoid             // Deep Abyss Void Black
            sphereBorderColor: Qt.rgba(0.22, 0.30, 0.40, 0.28)
        }

        // Interactive Mascot Area (Click, Right-Click, Middle-Click, Double-Click)
        MouseArea {
            id: minimoMouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            property var customReactions: ["dizzy", "yawn", "curious", "hop", "wink"]
            property int customIdx: 0
            onClicked: (mouse) => {
                if (mouse.button === Qt.MiddleButton) {
                    minimoBot.react("dizzy");
                } else if (mouse.button === Qt.RightButton) {
                    var rx = customReactions[customIdx % customReactions.length];
                    customIdx++;
                    minimoBot.react(rx);
                } else {
                    minimoBot.clicked(mouse.x > width / 2 ? 1 : -1);
                }
            }
            onDoubleClicked: {
                minimoBot.react("happyBounce");
            }
        }
    }

    // =========================================================================
    // 4. USER GREETING CAPSULE (Positioned immediately above Password Field)
    // =========================================================================
    Rectangle {
        id: userCapsule
        visible: content.isMain
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: capsule.top
        anchors.bottomMargin: 14 * content.s
        height: 28 * content.s
        width: userRow.implicitWidth + 24 * content.s
        radius: height / 2
        color: content.hkHallownestBg
        border.width: 1
        border.color: content.showError ? Qt.rgba(1.0, 0.48, 0.0, 0.35)
                    : (content.showSuccess ? content.hkSoulGlow
                    : content.hkBorder)
        Behavior on border.color { ColorAnimation { duration: 250 } }

        Row {
            id: userRow
            anchors.centerIn: parent
            spacing: 7 * content.s

            GlyphIcon {
                width: 12 * content.s
                height: 12 * content.s
                name: "lock"
                color: content.showError ? content.hkInfection : (content.showSuccess ? content.hkSoulGlow : content.hkSoulCyan)
                anchors.verticalCenter: parent.verticalCenter
                Behavior on color { ColorAnimation { duration: 250 } }
            }

            Text {
                text: SysStatus.currentUser
                color: content.hkMask
                opacity: 0.95
                font.family: Theme.font
                font.pixelSize: 12 * content.s
                font.weight: 600
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    // =========================================================================
    // 5. PASSWORD CAPSULE (Lowered to 75% from Top)
    // =========================================================================
    Rectangle {
        id: capsule
        visible: content.isMain
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(parent.height * 0.75)
        width: 360 * content.s
        height: 52 * content.s
        radius: height / 2
        color: content.hkHallownestBg
        border.width: 1
        border.color: content.showError ? content.hkInfection
                    : (content.showSuccess ? content.hkSoulGlow
                    : (input.activeFocus ? content.hkSoulCyan : content.hkBorder))
        opacity: content.isMain ? (content.authenticating ? 0.6 : 1) : 0
        Behavior on border.color { ColorAnimation { duration: 200 } }

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: content.showError ? Qt.rgba(1.0, 0.48, 0.0, 0.40)
                       : (content.showSuccess ? Qt.rgba(0.22, 0.74, 0.97, 0.40)
                       : Qt.rgba(0, 0, 0, 0.50))
            shadowBlur: 14 * content.s
            shadowVerticalOffset: 4 * content.s
        }

        transform: Translate { id: capsuleShift }

        SequentialAnimation {
            id: shake
            NumberAnimation { target: capsuleShift; property: "x"; to: 10 * content.s; duration: 45 }
            NumberAnimation { target: capsuleShift; property: "x"; to: -10 * content.s; duration: 45 }
            NumberAnimation { target: capsuleShift; property: "x"; to: 7 * content.s; duration: 45 }
            NumberAnimation { target: capsuleShift; property: "x"; to: -7 * content.s; duration: 45 }
            NumberAnimation { target: capsuleShift; property: "x"; to: 0; duration: 45 }
        }

        TextInput {
            id: input
            anchors.fill: parent
            anchors.leftMargin: 24 * content.s
            anchors.rightMargin: 52 * content.s
            verticalAlignment: TextInput.AlignVCenter
            horizontalAlignment: TextInput.AlignHCenter
            echoMode: TextInput.Normal
            color: content.reveal ? content.hkMask : "transparent"
            font.family: Theme.font
            font.pixelSize: 15 * content.s
            font.letterSpacing: 2 * content.s
            clip: true
            focus: true
            enabled: !content.authenticating
            onTextChanged: {
                if (text.length > 0) {
                    content.showError = false;
                    content.showSuccess = false;
                    if (minimoBot) {
                        minimoBot.mood = "";
                        minimoBot.squint = 1;
                    }
                } else {
                    if (minimoBot) minimoBot.squint = 0;
                }
                if (Pw.text !== text)
                    Pw.text = text;
                while (beadModel.count < text.length)
                    beadModel.append({});
                while (beadModel.count > text.length)
                    beadModel.remove(beadModel.count - 1);
            }

            Connections {
                target: Pw
                function onTextChanged() {
                    if (input.text !== Pw.text)
                        input.text = Pw.text;
                }
            }
            onAccepted: {
                if (content.auth && text.length > 0)
                    content.auth.submit(text);
            }

            cursorDelegate: Rectangle {
                visible: content.reveal && input.text.length > 0
                width: 2 * content.s
                height: input.cursorRectangle.height
                color: content.hkSoulCyan
                SequentialAnimation on opacity {
                    running: input.activeFocus
                    loops: Animation.Infinite
                    NumberAnimation { to: 0; duration: 0 }
                    PauseAnimation { duration: 550 }
                    NumberAnimation { to: 1; duration: 0 }
                    PauseAnimation { duration: 550 }
                }
            }
        }

        // Placeholder Text
        Text {
            anchors.centerIn: parent
            visible: input.text.length === 0
            text: {
                if (!content.showError)
                    return "Enter Password";
                var pamMsg = content.auth ? content.auth.lastError : "";
                return pamMsg.length > 0 ? pamMsg.toLowerCase() : "Authentication Failed";
            }
            color: content.showError ? content.hkInfection : content.hkMothwing
            font.family: Theme.font
            font.pixelSize: 14 * content.s
            font.letterSpacing: 0.5 * content.s
            font.weight: 500
        }

        // Bead Model for Character Input (Hollow Knight Lumafly Pearls)
        ListModel { id: beadModel }

        Row {
            anchors.centerIn: parent
            spacing: 9 * content.s
            visible: !content.reveal && input.text.length > 0

            Repeater {
                model: beadModel
                delegate: Rectangle {
                    id: bead
                    required property int index
                    width: 8 * content.s
                    height: width
                    radius: width / 2
                    color: bead.index === input.text.length - 1 ? content.hkMask : content.hkSoulCyan
                    scale: 0
                    Component.onCompleted: pop.start()
                    NumberAnimation { id: pop; target: bead; property: "scale"; to: 1; duration: 170; easing.type: Easing.OutBack }
                    SequentialAnimation on opacity {
                        running: bead.index === input.text.length - 1
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.40; duration: 480 }
                        NumberAnimation { to: 1.0; duration: 480 }
                    }
                }
            }
        }

        // Eye Reveal Toggle
        GlyphIcon {
            id: eye
            anchors.right: parent.right
            anchors.rightMargin: 18 * content.s
            anchors.verticalCenter: parent.verticalCenter
            width: 20 * content.s
            height: 20 * content.s
            name: content.reveal ? "eye-off" : "eye"
            color: eyeArea.containsMouse ? content.hkSoulCyan : content.hkMothwing
            stroke: 1.8

            MouseArea {
                id: eyeArea
                anchors.fill: parent
                anchors.margins: -6 * content.s
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: content.reveal = !content.reveal
            }
        }
    }

    // =========================================================================
    // 3. AUDIOPHILE-STYLE MEDIA PLAYER (Bottom Left)
    // =========================================================================

    // Interactive Shader Toggle
    Rectangle {
        visible: content.isMain && content.hasPlayer
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.leftMargin: 32 * content.s
        anchors.bottomMargin: 128 * content.s // Sits above the 84px player
        height: 26 * content.s
        width: shaderRow.implicitWidth + 24 * content.s
        radius: height / 2
        color: shaderMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Theme.colBg
        border.color: shaderMouse.containsMouse ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.50) : Theme.colBorder
        border.width: 1

        RowLayout {
            id: shaderRow
            anchors.centerIn: parent
            spacing: 6 * content.s

            GlyphIcon {
                width: 12 * content.s
                height: 12 * content.s
                name: "layers"
                color: Theme.accent
            }
            Text {
                text: {
                    switch (Prefs.visualizerShader) {
                        case 1: return "Fluid";
                        case 2: return "Tide";
                        default: return "Glow";
                    }
                }
                color: Theme.bright
                font.pixelSize: 11 * content.s
                font.weight: 500
                font.family: Theme.font
            }
        }

        MouseArea {
            id: shaderMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                Prefs.visualizerShader = (Prefs.visualizerShader + 1) % 3;
            }
        }
    }

    Rectangle {
        visible: content.isMain && content.hasPlayer
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.leftMargin: 32 * content.s
        anchors.bottomMargin: 32 * content.s
        width: 320 * content.s
        height: 84 * content.s
        radius: 18 * content.s
        color: Theme.colBg
        border.width: 1
        border.color: Theme.colBorder

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.rgba(0, 0, 0, 0.40)
            shadowBlur: 10 * content.s
            shadowVerticalOffset: 4 * content.s
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 12 * content.s
            spacing: 12 * content.s

            // Album Artwork with smooth mask
            Rectangle {
                Layout.preferredWidth: 60 * content.s
                Layout.preferredHeight: 60 * content.s
                radius: 12 * content.s
                color: Qt.rgba(0, 0, 0, 0.4)
                clip: true

                Image {
                    id: coverImg
                    anchors.fill: parent
                    visible: content.artUrl.length > 0
                    source: content.artUrl
                    fillMode: Image.PreserveAspectCrop
                    smooth: true
                    mipmap: true
                    cache: false
                    asynchronous: true
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        maskEnabled: true
                        maskSource: coverMask
                    }
                }

                Item {
                    id: coverMask
                    anchors.fill: parent
                    layer.enabled: true
                    visible: false
                    Rectangle {
                        anchors.fill: parent
                        radius: 12 * content.s
                        color: "black"
                    }
                }

                // Fallback music icon if no art
                GlyphIcon {
                    anchors.centerIn: parent
                    visible: content.artUrl.length === 0
                    width: 24 * content.s
                    height: 24 * content.s
                    name: "play"
                    color: Theme.dim
                }
            }

            // Track info and controls
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4 * content.s

                // Title and Artist
                Text {
                    Layout.fillWidth: true
                    text: content.trackTitle.length > 0 ? content.trackTitle : "No Track Playing"
                    color: Theme.bright
                    font.family: Theme.font
                    font.pixelSize: 13 * content.s
                    font.weight: 600
                    elide: Text.ElideRight
                }

                Text {
                    Layout.fillWidth: true
                    text: content.trackArtist.length > 0 ? content.trackArtist : "Unknown Artist"
                    color: Theme.dim
                    font.family: Theme.font
                    font.pixelSize: 11 * content.s
                    font.weight: 500
                    elide: Text.ElideRight
                }

                // Progress Bar and Controls
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8 * content.s

                    // Progress bar
                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 4 * content.s

                        Rectangle {
                            anchors.fill: parent
                            radius: 2 * content.s
                            color: Theme.trackBg
                        }

                        Rectangle {
                            width: parent.width * content.progress
                            height: parent.height
                            radius: 2 * content.s
                            color: Theme.accent
                        }
                    }

                    // Playback Buttons
                    Row {
                        spacing: 10 * content.s

                        GlyphIcon {
                            width: 14 * content.s
                            height: 14 * content.s
                            name: "skip-back"
                            color: backArea.containsMouse ? Theme.accent : Theme.bright
                            anchors.verticalCenter: parent.verticalCenter
                            MouseArea {
                                id: backArea
                                anchors.fill: parent
                                anchors.margins: -4 * content.s
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: if (content.player) content.player.previous()
                            }
                        }

                        GlyphIcon {
                            width: 15 * content.s
                            height: 15 * content.s
                            name: content.playing ? "pause" : "play"
                            color: playArea.containsMouse ? Theme.accent : Theme.bright
                            anchors.verticalCenter: parent.verticalCenter
                            MouseArea {
                                id: playArea
                                anchors.fill: parent
                                anchors.margins: -4 * content.s
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: if (content.player) content.player.togglePlaying()
                            }
                        }

                        GlyphIcon {
                            width: 14 * content.s
                            height: 14 * content.s
                            name: "skip-forward"
                            color: forwardArea.containsMouse ? Theme.accent : Theme.bright
                            anchors.verticalCenter: parent.verticalCenter
                            MouseArea {
                                id: forwardArea
                                anchors.fill: parent
                                anchors.margins: -4 * content.s
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: if (content.player) content.player.next()
                            }
                        }
                    }
                }
            }
        }
    }

    // =========================================================================
    // 4. POWER ACTIONS CAPSULE (Bottom Right)
    // =========================================================================
    Rectangle {
        id: powerCapsule
        visible: content.isMain
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: 32 * content.s
        anchors.bottomMargin: 32 * content.s
        height: 44 * content.s
        width: powerRow.implicitWidth + 24 * content.s
        radius: height / 2
        color: Theme.colBg
        border.width: 1
        border.color: Theme.colBorder

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.rgba(0, 0, 0, 0.35)
            shadowBlur: 8 * content.s
            shadowVerticalOffset: 3 * content.s
        }

        Row {
            id: powerRow
            anchors.centerIn: parent
            spacing: 12 * content.s

            // Display Off (DPMS)
            Rectangle {
                width: 30 * content.s
                height: 30 * content.s
                radius: 15 * content.s
                color: screenArea.containsMouse ? Theme.colHover : "transparent"
                anchors.verticalCenter: parent.verticalCenter

                GlyphIcon {
                    anchors.centerIn: parent
                    width: 16 * content.s
                    height: 16 * content.s
                    name: "monitor"
                    color: screenArea.containsMouse ? Theme.accent : Theme.bright
                }

                MouseArea {
                    id: screenArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: SysStatus.screenOff()
                }
            }

            // Sleep / Suspend
            Rectangle {
                width: 30 * content.s
                height: 30 * content.s
                radius: 15 * content.s
                color: sleepArea.containsMouse ? Theme.colHover : "transparent"
                anchors.verticalCenter: parent.verticalCenter

                GlyphIcon {
                    anchors.centerIn: parent
                    width: 16 * content.s
                    height: 16 * content.s
                    name: "moon"
                    color: sleepArea.containsMouse ? Theme.accent : Theme.bright
                }

                MouseArea {
                    id: sleepArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: SysStatus.suspend()
                }
            }

            // Reboot
            Rectangle {
                width: 30 * content.s
                height: 30 * content.s
                radius: 15 * content.s
                color: rebootArea.containsMouse ? Theme.colHover : "transparent"
                anchors.verticalCenter: parent.verticalCenter

                GlyphIcon {
                    anchors.centerIn: parent
                    width: 16 * content.s
                    height: 16 * content.s
                    name: "refresh"
                    color: rebootArea.containsMouse ? Theme.warn : Theme.bright
                }

                MouseArea {
                    id: rebootArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: SysStatus.reboot()
                }
            }

            // Power Off
            Rectangle {
                width: 30 * content.s
                height: 30 * content.s
                radius: 15 * content.s
                color: powerBtnArea.containsMouse ? Theme.colHover : "transparent"
                anchors.verticalCenter: parent.verticalCenter

                GlyphIcon {
                    anchors.centerIn: parent
                    width: 16 * content.s
                    height: 16 * content.s
                    name: "power"
                    color: powerBtnArea.containsMouse ? Theme.crit : Theme.bright
                }

                MouseArea {
                    id: powerBtnArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: SysStatus.powerOff()
                }
            }
        }
    }


}
