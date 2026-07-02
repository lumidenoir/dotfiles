import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

PanelWindow {
    id: rootWindow

    property bool show: false
    property var shellRoot

    WlrLayershell.keyboardFocus: show ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    exclusionMode: ExclusionMode.Ignore
    // Visibility driven by isClosing so both animation phases stay alive
    visible: show || isClosing
    color: "transparent"

    property bool isClosing: false
    property real savedCloseTarget: 120
    // Snap to 36px circle on open, then spring-expand (avoids pop from pill width)
    property bool suppressOpenAnimation: false

    onShowChanged: {
        if (show) {
            isClosing = false;
            suppressOpenAnimation = true;
            snapResetTimer.start();
            savedCloseTarget = Qt.binding(function () {
                return shellRoot ? shellRoot.closedNotchWidth : 120;
            });
            popupContent.forceActiveFocus();
        } else {
            savedCloseTarget = shellRoot ? shellRoot.closedNotchWidth : 120;
            isClosing = true;
        }
    }

    Timer {
        id: snapResetTimer
        interval: 16
        repeat: false
        onTriggered: rootWindow.suppressOpenAnimation = false
    }

    property string albumArtUrl: ""
    property real trackPosition: 0
    property real trackLength: 1
    property string trackTitle: "No Title"
    property string trackArtist: "Unknown Artist"

    property string playerName: ""
    property color accentColor: {
        var name = playerName.toLowerCase();
        if (name === "mpd")
            return "#2ecc71"; // green
        if (name.includes("brave") || name.includes("chrome") || name.includes("chromium"))
            return "#ff8c00"; // orange
        if (name === "firefox" || name === "mozilla")
            return "#9c27b0"; // purple
        return "#ff3b30"; // any other as red
    }
    property string playerIcon: {
        var name = playerName.toLowerCase();
        if (name === "spotify")
            return "󰓇";
        if (name === "mpd")
            return "󰎆";
        if (name === "firefox" || name === "mozilla")
            return "󰈹";
        if (name.includes("brave") || name.includes("chrome") || name.includes("chromium"))
            return "󰖟";
        return "󰝚";
    }

    property string shuffleMode: "Off"
    property string loopMode: "None"

    function formatTime(ms) {
        if (isNaN(ms) || ms < 0)
            return "0:00";
        var totalSec = Math.floor(ms / 1000000);
        var min = Math.floor(totalSec / 60);
        var sec = totalSec % 60;
        return min + ":" + (sec < 10 ? "0" : "") + sec;
    }

    Process {
        id: pMetadata
        command: ["sh", "-c", "P=\"spotify,Brave,brave,Chromium,chromium,Firefox,firefox,mpd\"; M=$(playerctl -p $P metadata --format '{{playerName}}//DELIM//{{mpris:artUrl}}//DELIM//{{xesam:title}}//DELIM//{{xesam:artist}}//DELIM//{{position}}//DELIM//{{mpris:length}}' 2>/dev/null); S=$(playerctl -p $P shuffle 2>/dev/null || echo 'Off'); L=$(playerctl -p $P loop 2>/dev/null || echo 'None'); if [ ! -z \"$M\" ]; then echo \"$M//DELIM//${S}//DELIM//${L}\"; fi"]
        stdout: SplitParser {
            onRead: data => {
                var d = data.trim();
                if (d === "")
                    return;
                var parts = d.split("//DELIM//");
                if (parts.length >= 8) {
                    playerName = parts[0].trim();
                    albumArtUrl = parts[1].trim();
                    trackTitle = parts[2].trim() !== "" ? parts[2].trim() : "No Title";
                    trackArtist = parts[3].trim() !== "" ? parts[3].trim() : "Unknown Artist";
                    var pos = parseFloat(parts[4].trim());
                    trackPosition = isNaN(pos) ? 0 : pos;
                    var len = parseFloat(parts[5].trim());
                    trackLength = isNaN(len) || len <= 0 ? 1 : len;
                    shuffleMode = parts[6].trim();
                    loopMode = parts[7].trim();
                }
            }
        }
    }

    Process {
        id: pSeek
        onExited: pMetadata.running = true
    }

    Process {
        id: pControlPrev
        command: ["playerctl", "-p", rootWindow.playerName !== "" ? rootWindow.playerName : "spotify,Brave,brave,Chromium,chromium,Firefox,firefox,mpd", "previous"]
        onExited: pMetadata.running = true
    }
    Process {
        id: pControlPlay
        command: ["playerctl", "-p", rootWindow.playerName !== "" ? rootWindow.playerName : "spotify,Brave,brave,Chromium,chromium,Firefox,firefox,mpd", "play-pause"]
        onExited: pMetadata.running = true
    }
    Process {
        id: pControlNext
        command: ["playerctl", "-p", rootWindow.playerName !== "" ? rootWindow.playerName : "spotify,Brave,brave,Chromium,chromium,Firefox,firefox,mpd", "next"]
        onExited: pMetadata.running = true
    }
    Process {
        id: pControlShuffle
        onExited: pMetadata.running = true
    }
    Process {
        id: pControlLoop
        onExited: pMetadata.running = true
    }

    Timer {
        interval: 1000
        running: rootWindow.show
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            pMetadata.running = true;
        }
    }

    Timer {
        id: interpolationTimer
        interval: 50
        repeat: true
        running: rootWindow.show && (shellRoot && shellRoot.spotifyStatus === "playing") && !rootWindow.isClosing
        property var lastTime: 0
        property bool isUpdatingLocally: false
        onTriggered: {
            var now = Date.now();
            if (lastTime > 0) {
                var elapsedMs = now - lastTime;
                var newPos = rootWindow.trackPosition + (elapsedMs * 1000);
                if (newPos <= rootWindow.trackLength) {
                    isUpdatingLocally = true;
                    rootWindow.trackPosition = newPos;
                    isUpdatingLocally = false;
                }
            }
            lastTime = now;
        }
        onRunningChanged: {
            if (running) {
                lastTime = Date.now();
            } else {
                lastTime = 0;
            }
        }
    }

    onTrackPositionChanged: {
        if (!interpolationTimer.isUpdatingLocally && interpolationTimer.running) {
            interpolationTimer.lastTime = Date.now();
        }
    }

    Item {
        id: popupContent
        anchors.fill: parent
        focus: rootWindow.show

        Keys.onEscapePressed: event => {
            rootWindow.show = false;
            event.accepted = true;
        }

        // Click outside the card to close it
        MouseArea {
            anchors.fill: parent
            enabled: rootWindow.show
            onClicked: {
                rootWindow.show = false;
            }
        }

        Rectangle {
            id: animRect
            anchors.top: parent.top
            anchors.topMargin: 4
            anchors.horizontalCenter: parent.horizontalCenter

            width: rootWindow.suppressOpenAnimation ? 36 : rootWindow.show ? 360 : (rootWindow.isClosing ? 36 : rootWindow.savedCloseTarget)
            height: rootWindow.suppressOpenAnimation ? 36 : rootWindow.show ? 200 : (rootWindow.isClosing ? 36 : 40)
            radius: rootWindow.suppressOpenAnimation ? 18 : rootWindow.show ? 24 : (rootWindow.isClosing ? 18 : 20)

            onWidthChanged: {
                if (!rootWindow.show && rootWindow.isClosing && width <= 40) {
                    rootWindow.isClosing = false;
                }
            }

            color: "#12131a"
            border.color: Qt.rgba(1, 1, 1, 0.12)
            border.width: 1

            // Rounded corner clipping using offscreen FBO
            Rectangle {
                id: roundedMask
                anchors.fill: parent
                radius: parent.radius
                visible: false
                layer.enabled: true
            }

            layer.enabled: true
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: roundedMask
            }
            clip: true

            // Click body of the expanded card to close it
            MouseArea {
                anchors.fill: parent
                enabled: rootWindow.show
                onClicked: rootWindow.show = false
            }

            // Shape springs
            Behavior on radius {
                enabled: (rootWindow.show || rootWindow.isClosing) && !(shellRoot && shellRoot.batteryMode)
                SpringAnimation {
                    spring: 4.8
                    damping: 0.8
                    mass: 0.6
                }
            }
            Behavior on width {
                enabled: !rootWindow.suppressOpenAnimation && (rootWindow.show || rootWindow.isClosing) && !(shellRoot && shellRoot.batteryMode)
                SpringAnimation {
                    spring: 4.8
                    damping: 0.8
                    mass: 0.6
                }
            }
            Behavior on height {
                enabled: !rootWindow.suppressOpenAnimation && (rootWindow.show || rootWindow.isClosing) && !(shellRoot && shellRoot.batteryMode)
                SpringAnimation {
                    spring: 4.8
                    damping: 0.8
                    mass: 0.6
                }
            }

            // Clipping wrapper for expanded media content
            Item {
                anchors.fill: parent

                // Expanded Media Layout (Éxtasis style)
                RowLayout {
                    id: mediaExpandedLayout
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 12
                    opacity: rootWindow.show ? 1.0 : 0.0
                    Behavior on opacity {
                        SequentialAnimation {
                            PauseAnimation {
                                duration: (shellRoot && shellRoot.batteryMode) ? 0 : (rootWindow.show ? 120 : 0)
                            }
                            NumberAnimation {
                                duration: (shellRoot && shellRoot.batteryMode) ? 0 : (rootWindow.show ? 280 : 80)
                                easing.type: rootWindow.show ? Easing.OutQuad : Easing.InQuad
                            }
                        }
                    }
                    visible: opacity > 0

                    scale: rootWindow.show ? 1.0 : 0.9
                    Behavior on scale {
                        enabled: !(shellRoot && shellRoot.batteryMode)
                        SpringAnimation {
                            spring: 3.0
                            damping: 0.8
                            mass: 0.8
                        }
                    }

                    // Left Side Container: Album Art & Metadata (inside rounded rectangle)
                    Rectangle {
                        id: albumArtContainer
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 16
                        color: "#1e1e2e"
                        border.color: Qt.rgba(1, 1, 1, 0.1)
                        border.width: 1

                        // Rounded corner mask to clip blurred album art and overlays
                        Rectangle {
                            id: albumArtMask
                            anchors.fill: parent
                            radius: parent.radius
                            visible: false
                            layer.enabled: true
                        }

                        layer.enabled: true
                        layer.effect: MultiEffect {
                            maskEnabled: true
                            maskSource: albumArtMask
                        }

                        // Album Art Image
                        Image {
                            id: albumArt
                            anchors.fill: parent
                            anchors.margins: -32 // Bleed out to avoid edge artifacts
                            source: rootWindow.albumArtUrl
                            fillMode: Image.PreserveAspectCrop
                            sourceSize.width: 320 // Larger size for slightly sharper details in the background
                            sourceSize.height: 320
                            opacity: 0.0
                        }

                        // Beautiful gradient blur
                        MultiEffect {
                            source: albumArt
                            anchors.fill: parent
                            blurEnabled: true
                            blur: 0.2 // Reduced blur to keep shape details recognizable
                            opacity: 1.0
                            visible: rootWindow.albumArtUrl !== ""
                        }

                        // Horizontal gradient overlay for left-side readability
                        Rectangle {
                            anchors.fill: parent
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop {
                                    position: 0.0
                                    color: Qt.rgba(0.05, 0.05, 0.08, 0.9)
                                }
                                GradientStop {
                                    position: 0.5
                                    color: Qt.rgba(0.05, 0.05, 0.08, 0.60)
                                }
                                GradientStop {
                                    position: 1.0
                                    color: Qt.rgba(0.05, 0.05, 0.08, 0.20)
                                }
                            }
                        }

                        // Additional vertical gradient overlay for dark bottom area
                        Rectangle {
                            anchors.fill: parent
                            gradient: Gradient {
                                orientation: Gradient.Vertical
                                GradientStop {
                                    position: 0.0
                                    color: Qt.rgba(0, 0, 0, 0.1)
                                }
                                GradientStop {
                                    position: 1.0
                                    color: Qt.rgba(0, 0, 0, 0.45)
                                }
                            }
                        }

                        // Inner text and controls column layout
                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 6

                            // Top controls & badge row
                            RowLayout {
                                Layout.fillWidth: true

                                RowLayout {
                                    spacing: 8
                                    // Shuffle
                                    MouseArea {
                                        id: expandedShuffleBtn
                                        width: 20
                                        height: 20
                                        hoverEnabled: true
                                        onClicked: {
                                            pControlShuffle.command = ["playerctl", "-p", rootWindow.playerName !== "" ? rootWindow.playerName : "spotify,Brave,brave,Chromium,chromium,Firefox,firefox,mpd", "shuffle", "Toggle"];
                                            pControlShuffle.running = true;
                                        }
                                        scale: containsPress ? 0.85 : (containsMouse ? 1.15 : 1.0)
                                        Behavior on scale {
                                            SpringAnimation {
                                                spring: 4.5
                                                damping: 0.65
                                                mass: 0.6
                                            }
                                        }
                                        Text {
                                            anchors.centerIn: parent
                                            text: "󰒞"
                                            color: rootWindow.shuffleMode === "On" ? rootWindow.accentColor : (parent.containsMouse ? "white" : Qt.rgba(1, 1, 1, 0.6))
                                            font {
                                                family: shellRoot ? shellRoot.iconFontFamily : "sans-serif"
                                                pixelSize: 13
                                            }
                                        }
                                    }

                                    // Loop
                                    MouseArea {
                                        id: expandedLoopBtn
                                        width: 20
                                        height: 20
                                        hoverEnabled: true
                                        onClicked: {
                                            var nextMode = "None";
                                            if (rootWindow.loopMode === "None")
                                                nextMode = "Playlist";
                                            else if (rootWindow.loopMode === "Playlist")
                                                nextMode = "Track";
                                            else if (rootWindow.loopMode === "Track")
                                                nextMode = "None";

                                            pControlLoop.command = ["playerctl", "-p", rootWindow.playerName !== "" ? rootWindow.playerName : "spotify,Brave,brave,Chromium,chromium,Firefox,firefox,mpd", "loop", nextMode];
                                            pControlLoop.running = true;
                                        }
                                        scale: containsPress ? 0.85 : (containsMouse ? 1.15 : 1.0)
                                        Behavior on scale {
                                            SpringAnimation {
                                                spring: 4.5
                                                damping: 0.65
                                                mass: 0.6
                                            }
                                        }
                                        Text {
                                            anchors.centerIn: parent
                                            text: rootWindow.loopMode === "Track" ? "󰑘" : (rootWindow.loopMode === "Playlist" ? "󰑖" : "󰑗")
                                            color: rootWindow.loopMode !== "None" ? rootWindow.accentColor : (parent.containsMouse ? "white" : Qt.rgba(1, 1, 1, 0.6))
                                            font {
                                                family: shellRoot ? shellRoot.iconFontFamily : "sans-serif"
                                                pixelSize: 13
                                            }
                                        }
                                    }
                                }

                                Item {
                                    Layout.fillWidth: true
                                }

                                // Player Source Badge in top-right
                                Rectangle {
                                    width: 20
                                    height: 20
                                    radius: 10
                                    color: rootWindow.accentColor
                                    opacity: 0.95
                                    Text {
                                        anchors.centerIn: parent
                                        text: rootWindow.playerIcon
                                        color: "white"
                                        font {
                                            family: shellRoot ? shellRoot.iconFontFamily : "sans-serif"
                                            pixelSize: 11
                                        }
                                    }
                                }
                            }

                            Item {
                                Layout.fillHeight: true
                            }

                            // Song Title
                            Text {
                                text: rootWindow.trackTitle
                                color: "white"
                                font {
                                    family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                                    pixelSize: 14
                                    bold: true
                                }
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                elide: Text.ElideRight
                            }

                            // Artist Name
                            Text {
                                text: rootWindow.trackArtist
                                color: Qt.rgba(1, 1, 1, 0.6)
                                font {
                                    family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                                    pixelSize: 11
                                }
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                elide: Text.ElideRight
                            }

                            // Thick Interactive Progress Bar
                            Item {
                                id: progressBarContainer
                                Layout.fillWidth: true
                                height: 6

                                Rectangle {
                                    id: bgBar
                                    anchors.fill: parent
                                    radius: 3
                                    color: Qt.rgba(1, 1, 1, 0.15)
                                }

                                Rectangle {
                                    id: fillBar
                                    anchors.left: parent.left
                                    anchors.top: parent.top
                                    anchors.bottom: parent.bottom
                                    width: Math.min(progressBarContainer.width, Math.max(0, (rootWindow.trackPosition / rootWindow.trackLength) * progressBarContainer.width))
                                    radius: 3
                                    color: rootWindow.accentColor
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: mouse => {
                                        var pct = mouse.x / width;
                                        var targetPos = Math.round(pct * rootWindow.trackLength);
                                        pSeek.command = ["playerctl", "-p", rootWindow.playerName !== "" ? rootWindow.playerName : "spotify,Brave,brave,Chromium,chromium,Firefox,firefox,mpd", "position", (targetPos / 1000000).toFixed(6)];
                                        pSeek.running = true;
                                    }
                                }
                            }

                            // Time Progress Row
                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    text: rootWindow.formatTime(rootWindow.trackPosition) + " / " + rootWindow.formatTime(rootWindow.trackLength)
                                    color: Qt.rgba(1, 1, 1, 0.5)
                                    font {
                                        family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                                        pixelSize: 9
                                        bold: true
                                    }
                                }
                            }
                        }
                    }

                    // Right Side: Controls and close button centered vertically (sitting directly on solid background)
                    ColumnLayout {
                        spacing: 12
                        Layout.alignment: Qt.AlignVCenter
                        Layout.fillHeight: true
                        Layout.preferredWidth: 32

                        // Previous
                        MouseArea {
                            id: expandedPrevBtn
                            width: 32
                            height: 32
                            hoverEnabled: true
                            onClicked: pControlPrev.running = true
                            scale: containsPress ? 0.85 : (containsMouse ? 1.15 : 1.0)
                            Behavior on scale {
                                SpringAnimation {
                                    spring: 4.5
                                    damping: 0.65
                                    mass: 0.6
                                }
                            }
                            Text {
                                anchors.centerIn: parent
                                text: "󰒮"
                                color: parent.containsMouse ? "white" : Qt.rgba(1, 1, 1, 0.6)
                                font {
                                    family: shellRoot ? shellRoot.iconFontFamily : "sans-serif"
                                    pixelSize: 18
                                }
                            }
                        }

                        // Play/Pause
                        MouseArea {
                            id: expandedPlayBtn
                            width: 32
                            height: 32
                            hoverEnabled: true
                            onClicked: pControlPlay.running = true
                            scale: containsPress ? 0.85 : (containsMouse ? 1.15 : 1.0)
                            Behavior on scale {
                                SpringAnimation {
                                    spring: 4.5
                                    damping: 0.65
                                    mass: 0.6
                                }
                            }
                            Text {
                                anchors.centerIn: parent
                                text: (shellRoot && shellRoot.spotifyStatus === "playing") ? "󰏤" : "󰐊"
                                color: "white"
                                font {
                                    family: shellRoot ? shellRoot.iconFontFamily : "sans-serif"
                                    pixelSize: 20
                                }
                            }
                        }

                        // Next
                        MouseArea {
                            id: expandedNextBtn
                            width: 32
                            height: 32
                            hoverEnabled: true
                            onClicked: pControlNext.running = true
                            scale: containsPress ? 0.85 : (containsMouse ? 1.15 : 1.0)
                            Behavior on scale {
                                SpringAnimation {
                                    spring: 4.5
                                    damping: 0.65
                                    mass: 0.6
                                }
                            }
                            Text {
                                anchors.centerIn: parent
                                text: "󰒭"
                                color: parent.containsMouse ? "white" : Qt.rgba(1, 1, 1, 0.6)
                                font {
                                    family: shellRoot ? shellRoot.iconFontFamily : "sans-serif"
                                    pixelSize: 18
                                }
                            }
                        }

                        Item {
                            Layout.fillHeight: true
                        }

                        // Pink circular Close button at bottom right
                        MouseArea {
                            id: closeBtn
                            width: 28
                            height: 28
                            hoverEnabled: true
                            onClicked: rootWindow.show = false
                            scale: containsPress ? 0.85 : (containsMouse ? 1.15 : 1.0)
                            Behavior on scale {
                                SpringAnimation {
                                    spring: 4.5
                                    damping: 0.65
                                    mass: 0.6
                                }
                            }

                            Rectangle {
                                anchors.fill: parent
                                radius: 14
                                color: parent.containsMouse ? Qt.rgba(1, 0.4, 0.4, 0.25) : Qt.rgba(1, 0.4, 0.4, 0.15)
                                border.color: Qt.rgba(1, 0.4, 0.4, 0.8)
                                border.width: 1
                                Behavior on color {
                                    ColorAnimation {
                                        duration: 150
                                    }
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: "󰅖"
                                color: Qt.rgba(1, 0.4, 0.4, 1.0)
                                font {
                                    family: shellRoot ? shellRoot.iconFontFamily : "sans-serif"
                                    pixelSize: 12
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
