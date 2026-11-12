import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import "Singletons"

Window {
    id: root
    title: "AudiophileMiniPlayer"
    width: 320
    height: 440
    color: "transparent"
    visible: false
    flags: Qt.Window | Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint

    property var shellRoot: null
    readonly property string iconFont: shellRoot ? shellRoot.iconFontFamily : "sans-serif"
    readonly property string mainFont: "Inter"

    // Core track properties synced with Players singleton with shellRoot fallback
    readonly property bool hasPlayer: Players.has
    readonly property bool isPlaying: Players.has ? Players.playing : (shellRoot ? shellRoot.spotifyStatus === "playing" : false)
    readonly property string currentTitle: Players.has ? Players.title : (shellRoot && shellRoot.spotifyTitle ? shellRoot.spotifyTitle : "No Track")
    readonly property string currentArtist: Players.has ? Players.artist : (shellRoot && shellRoot.spotifyArtist ? shellRoot.spotifyArtist : "Unknown Artist")
    
    // Extracted / resolved art url
    property string backendArtUrl: ""
    readonly property string activeArtUrl: {
        if (backendArtUrl !== "") return backendArtUrl;
        if (Players.has && Players.artUrl) return Players.artUrl;
        if (shellRoot && shellRoot.spotifyArtUrl) return shellRoot.spotifyArtUrl;
        return "";
    }

    // Dynamic Palette & Audio Specs properties (Independent & Isolated)
    property color dominantColor: "#121218"
    property color accentColor: "#6366f1"
    property string audioBadge: "HI-FI"
    property bool isLossless: false

    // Vinyl / Square Artwork Toggle
    property bool artAsVinyl: true

    // High-Precision Delta Clock for Jitter-Free Playback
    property real anchorPosition: 0.0
    property real anchorTimestamp: 0.0
    property real currentPlaybackTime: 0.0
    readonly property real currentLength: {
        if (Players.has && Players.lengthSec > 0) return Players.lengthSec;
        if (shellRoot && shellRoot.audiophilePlayer && shellRoot.audiophilePlayer.currentLength > 0) {
            return shellRoot.audiophilePlayer.currentLength;
        }
        if (shellRoot && shellRoot.spotifyLength) {
            let l = parseFloat(shellRoot.spotifyLength);
            if (!isNaN(l) && l > 0) return l;
        }
        return 0.0;
    }
    property bool isScrubbing: false
    property real scrubTargetTime: 0.0

    // Metadata & Art Extractor Process
    Process {
        id: miniExtractorProcess
        stdout: SplitParser {
            onRead: data => {
                let line = data.trim();
                if (!line) return;
                try {
                    let parsedData = JSON.parse(line);
                    if (parsedData.dominant_color) root.dominantColor = parsedData.dominant_color;
                    if (parsedData.accent_color) root.accentColor = parsedData.accent_color;
                    if (parsedData.art_url) root.backendArtUrl = parsedData.art_url;
                    if (parsedData.audio_specs) {
                        if (parsedData.audio_specs.badge) root.audioBadge = parsedData.audio_specs.badge;
                        root.isLossless = parsedData.audio_specs.lossless || false;
                    }
                } catch (e) {}
            }
        }
    }

    Timer {
        id: miniDebounce
        interval: 100
        onTriggered: {
            if (miniExtractorProcess.running) {
                miniExtractorProcess.running = false;
            }
            let activeName = Players.has ? (Players.active.identity || Players.active.desktopEntry || "") : "";
            let args = [
                "/home/krishna/dotfiles/scripts/extract_lyrics.py",
                "--artist", root.currentArtist,
                "--title", root.currentTitle,
                "--duration", String(root.currentLength),
                "--player", activeName
            ];
            if (Players.has && Players.artUrl) {
                args.push("--art-url", Players.artUrl);
            }
            miniExtractorProcess.command = args;
            miniExtractorProcess.running = true;
        }
    }

    // Audio-reactive Cava Energy Pipeline
    property var cavaValues: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    property var cavaSmooth: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    property real cavaEnergy: (shellRoot && shellRoot.audiophilePlayer && shellRoot.audiophilePlayer.cavaEnergy > 0) ? shellRoot.audiophilePlayer.cavaEnergy : 0.0

    Process {
        id: cavaProcess
        running: root.visible && root.isPlaying && !(shellRoot && shellRoot.audiophilePlayer && shellRoot.audiophilePlayer.visible)
        command: ["cava", "-p", "/home/krishna/dotfiles/quickshell/lock/assets/cava.conf"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => {
                let trimmed = line.trim();
                if (!trimmed) return;
                let parts = trimmed.split(";");
                let vals = [];
                let sum = 0;
                for (let i = 0; i < 12; i++) {
                    let v = parseInt(parts[i]);
                    let f = isNaN(v) ? 0 : Math.max(0, Math.min(1.0, v / 100.0));
                    vals.push(f);
                    sum += f;
                }
                root.cavaValues = vals;
                root.cavaEnergy = sum / 12.0;
            }
        }
    }

    function syncPosition(newPosSec) {
        if (isNaN(newPosSec) || isScrubbing || newPosSec < 0) return;
        if (root.currentLength > 0 && newPosSec > root.currentLength + 2.0) {
            return;
        }
        let diff = Math.abs(newPosSec - root.currentPlaybackTime);
        if (diff > 0.8) {
            root.anchorPosition = newPosSec;
            root.anchorTimestamp = Date.now();
            root.currentPlaybackTime = newPosSec;
        } else if (newPosSec > root.currentPlaybackTime + 0.1) {
            root.anchorPosition = newPosSec;
            root.anchorTimestamp = Date.now();
        }
    }

    Connections {
        target: Players.has ? Players.active : null
        ignoreUnknownSignals: true
        function onPositionChanged() {
            if (Players.has && Players.active) {
                root.syncPosition(Players.active.position);
            }
        }
        function onPlayingChanged() {
            root.anchorTimestamp = Date.now();
            root.anchorPosition = root.currentPlaybackTime;
        }
    }

    Connections {
        target: shellRoot
        ignoreUnknownSignals: true
        function onSpotifyPositionChanged() {
            if (!Players.has && shellRoot) {
                let pos = parseFloat(shellRoot.spotifyPosition);
                root.syncPosition(pos);
            }
        }
    }

    // 60fps High Precision Clock Timer
    Timer {
        id: deltaClockTimer
        interval: 16 // ~60fps
        running: root.visible && root.isPlaying && !root.isScrubbing
        repeat: true
        onTriggered: {
            let elapsed = Math.max(0, (Date.now() - root.anchorTimestamp) / 1000.0);
            let computed = root.anchorPosition + elapsed;
            if (root.currentLength > 0) {
                root.currentPlaybackTime = Math.min(root.currentLength, Math.max(0.0, computed));
            } else {
                root.currentPlaybackTime = Math.max(0.0, computed);
            }
        }
    }

    function seekTo(seconds) {
        let clamped = Math.max(0.0, Math.min(seconds, currentLength > 0 ? currentLength : seconds));
        root.anchorPosition = clamped;
        root.anchorTimestamp = Date.now();
        root.currentPlaybackTime = clamped;
        if (Players.has && Players.active && Players.active.canSeek) {
            Players.active.position = clamped;
        } else if (shellRoot && shellRoot.spotifySeek) {
            shellRoot.spotifySeek(clamped);
        }
    }

    function formatTime(sec) {
        if (isNaN(sec) || sec < 0) return "0:00";
        let m = Math.floor(sec / 60);
        let s = Math.floor(sec % 60);
        return m + ":" + (s < 10 ? "0" : "") + s;
    }

    function expandToFullPlayer() {
        root.visible = false;
        if (shellRoot && shellRoot.audiophilePlayer) {
            shellRoot.audiophilePlayer.visible = true;
        }
    }

    onVisibleChanged: {
        if (visible) {
            root.requestActivate();
            bgCard.forceActiveFocus();
            root.anchorTimestamp = Date.now();
            if (Players.has && Players.active) {
                root.anchorPosition = Players.active.position;
                root.currentPlaybackTime = Players.active.position;
            } else if (shellRoot) {
                let p = parseFloat(shellRoot.spotifyPosition);
                root.anchorPosition = isNaN(p) ? 0 : p;
                root.currentPlaybackTime = root.anchorPosition;
            }
        }
    }

    property string trackIdentifier: currentTitle + "::" + currentArtist + "::" + (Players.has ? (Players.active.dbusName || "") : "")
    onTrackIdentifierChanged: {
        backendArtUrl = "";
        isLossless = false;
        let isBrowser = Players.has && (Players.active.identity || "").toLowerCase().indexOf("brave") >= 0;
        audioBadge = isBrowser ? "WEB AUDIO" : "HI-FI";
        dominantColor = "#121218";
        accentColor = "#6366f1";
        anchorPosition = (Players.has && Players.active && Players.active.position >= 0) ? Players.active.position : 0.0;
        anchorTimestamp = Date.now();
        currentPlaybackTime = anchorPosition;
        if (currentTitle !== "" && currentTitle !== "No Track") {
            miniDebounce.restart();
        }
    }

    // Outer Frameless Glass Window Container
    Rectangle {
        id: bgCard
        anchors.fill: parent
        radius: 20
        color: "#07070a"
        border.color: Qt.rgba(1, 1, 1, 0.12)
        border.width: 1
        clip: true
        antialiasing: true
        focus: true

        // Keyboard Navigation
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Space) {
                if (Players.has && Players.active) {
                    if (Players.active.canTogglePlaying) {
                        Players.active.togglePlaying();
                    } else if (Players.active.canPlay && !root.isPlaying) {
                        Players.active.play();
                    } else if (Players.active.canPause && root.isPlaying) {
                        Players.active.pause();
                    }
                } else if (shellRoot) {
                    shellRoot.spotifyToggle();
                }
                event.accepted = true;
            } else if (event.key === Qt.Key_Left) {
                root.seekTo(root.currentPlaybackTime - 5);
                event.accepted = true;
            } else if (event.key === Qt.Key_Right) {
                root.seekTo(root.currentPlaybackTime + 5);
                event.accepted = true;
            } else if (event.key === Qt.Key_J || event.key === Qt.Key_P) {
                if (Players.has && Players.active && Players.active.canGoPrevious) {
                    Players.active.previous();
                } else if (shellRoot) {
                    shellRoot.spotifyPrev();
                }
                event.accepted = true;
            } else if (event.key === Qt.Key_K || event.key === Qt.Key_N) {
                if (Players.has && Players.active && Players.active.canGoNext) {
                    Players.active.next();
                } else if (shellRoot) {
                    shellRoot.spotifyNext();
                }
                event.accepted = true;
            } else if (event.key === Qt.Key_C || event.key === Qt.Key_F) {
                root.expandToFullPlayer();
                event.accepted = true;
            } else if (event.key === Qt.Key_Escape) {
                root.visible = false;
                event.accepted = true;
            }
        }

        // Blurred Artwork Backdrop
        Image {
            id: bgArt
            anchors.fill: parent
            source: root.activeArtUrl
            fillMode: Image.PreserveAspectCrop
            visible: false
            asynchronous: true
        }

        MultiEffect {
            anchors.fill: parent
            source: bgArt
            blurEnabled: true
            blurMax: 95
            blur: 1.0
            colorizationColor: root.dominantColor
            colorization: 0.80
            opacity: 0.50
        }

        // Ambient Acoustic Wash
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.tint(root.dominantColor, Qt.rgba(0.02, 0.02, 0.04, 0.70)) }
                GradientStop { position: 0.5; color: Qt.tint(root.accentColor, Qt.rgba(0.03, 0.03, 0.05, 0.90)) }
                GradientStop { position: 1.0; color: Qt.rgba(0.02, 0.02, 0.04, 0.96) }
            }
        }

        // Frosted Glass Micro-Grain Texture
        Canvas {
            id: frostedNoise
            anchors.fill: parent
            opacity: 0.028
            renderTarget: Canvas.Image
            onPaint: {
                let ctx = getContext("2d");
                let img = ctx.createImageData(64, 64);
                let d = img.data;
                for (let i = 0; i < d.length; i += 4) {
                    let v = Math.random() > 0.5 ? 255 : 0;
                    d[i] = v;
                    d[i+1] = v;
                    d[i+2] = v;
                    d[i+3] = Math.floor(Math.random() * 255);
                }
                for (let x = 0; x < width; x += 64) {
                    for (let y = 0; y < height; y += 64) {
                        ctx.putImageData(img, x, y);
                    }
                }
            }
            Component.onCompleted: requestPaint()
        }

        // Layer 5: Suspended Floating Acoustic Particles (Music-Reactive Stardust)
        Canvas {
            id: particleCanvas
            anchors.fill: parent
            z: 0
            visible: root.isPlaying || root.visible
            
            property var particles: []
            property int count: 20

            Component.onCompleted: {
                let list = [];
                for (let i = 0; i < count; i++) {
                    list.push({
                        x: Math.random(),
                        y: Math.random(),
                        baseR: 1.2 + Math.random() * 1.6,
                        speedY: 0.0003 + Math.random() * 0.0006,
                        phase: Math.random() * Math.PI * 2,
                        phaseSpeed: 0.015 + Math.random() * 0.025,
                        baseAlpha: 0.18 + Math.random() * 0.35
                    });
                }
                particles = list;
            }

            FrameAnimation {
                running: root.visible && (root.isPlaying || particleCanvas.opacity > 0)
                onTriggered: {
                    let pts = particleCanvas.particles;
                    let len = pts.length;
                    for (let i = 0; i < len; i++) {
                        let p = pts[i];
                        p.y -= p.speedY * (1.0 + root.cavaEnergy * 1.5);
                        p.phase += p.phaseSpeed;
                        if (p.y < -0.05) {
                            p.y = 1.05;
                            p.x = Math.random();
                        }
                    }
                    particleCanvas.requestPaint();
                }
            }

            onPaint: {
                let ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);
                let pts = particles;
                let len = pts.length;
                let energy = root.cavaEnergy;
                let acc = root.accentColor;
                let r = Math.round(acc.r * 255);
                let g = Math.round(acc.g * 255);
                let b = Math.round(acc.b * 255);

                for (let i = 0; i < len; i++) {
                    let p = pts[i];
                    let px = (p.x + Math.sin(p.phase) * 0.02) * width;
                    let py = p.y * height;
                    let curR = p.baseR * (1.0 + energy * 0.9);
                    let curA = Math.min(0.85, p.baseAlpha + (energy * 0.40));

                    ctx.beginPath();
                    ctx.arc(px, py, curR, 0, Math.PI * 2);
                    ctx.fillStyle = "rgba(" + r + "," + g + "," + b + "," + curA.toFixed(2) + ")";
                    ctx.fill();
                }
            }
        }

        // Drag to Move Window
        MouseArea {
            anchors.fill: parent
            z: 0
            onPressed: root.startSystemMove()
        }

        // Main Column Layout
        ColumnLayout {
            z: 2
            anchors.fill: parent
            anchors.margins: 18
            spacing: 6

            // Top Header: Close Button + Expand to Full Player Button
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 28

                // Close Button
                Rectangle {
                    width: 28
                    height: 28
                    radius: 14
                    color: closeArea.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(1, 1, 1, 0.06)
                    border.color: Qt.rgba(1, 1, 1, 0.1)

                    Behavior on color { ColorAnimation { duration: 150 } }

                    Text {
                        anchors.centerIn: parent
                        text: "󰅖"
                        color: closeArea.containsMouse ? "#ffffff" : Qt.rgba(1, 1, 1, 0.6)
                        font.family: root.iconFont
                        font.pixelSize: 13
                    }

                    MouseArea {
                        id: closeArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.visible = false
                    }
                }

                // Expand to Full Player Button
                Rectangle {
                    width: 28
                    height: 28
                    radius: 14
                    color: expandArea.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(1, 1, 1, 0.06)
                    border.color: Qt.rgba(1, 1, 1, 0.1)

                    Behavior on color { ColorAnimation { duration: 150 } }

                    Text {
                        anchors.centerIn: parent
                        text: "󰩩"
                        color: expandArea.containsMouse ? root.accentColor : Qt.rgba(1, 1, 1, 0.6)
                        font.family: root.iconFont
                        font.pixelSize: 13
                    }

                    MouseArea {
                        id: expandArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.expandToFullPlayer()
                    }
                }

                Item { Layout.fillWidth: true }

                // Interactive Active Player Source Badge (MPD / Cider / Brave / Firefox)
                Rectangle {
                    id: sourceChip
                    height: 24
                    implicitWidth: sourceRow.implicitWidth + 12
                    radius: 12
                    color: sourceMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.05)
                    border.color: sourceMouse.containsMouse ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.50) : Qt.rgba(1, 1, 1, 0.08)

                    RowLayout {
                        id: sourceRow
                        anchors.centerIn: parent
                        spacing: 4

                        Text {
                            text: Players.playerIconOf(Players.active)
                            color: root.accentColor
                            font.family: root.iconFont
                            font.pixelSize: 10
                        }

                        Text {
                            text: Players.playerNameOf(Players.active)
                            color: Qt.rgba(1, 1, 1, 0.75)
                            font.pixelSize: 9
                            font.weight: Font.Medium
                            font.family: root.mainFont
                        }

                        Text {
                            visible: Players.pickable.length > 1
                            text: "󰅀"
                            color: Qt.rgba(1, 1, 1, 0.40)
                            font.family: root.iconFont
                            font.pixelSize: 8
                        }
                    }

                    MouseArea {
                        id: sourceMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Players.pickable.length > 1 ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: {
                            if (Players.pickable.length > 1) {
                                let list = Players.pickable;
                                let idx = list.indexOf(Players.active);
                                let nextIdx = (idx + 1) % list.length;
                                Players.select(list[nextIdx]);
                            }
                        }
                    }
                }
            }

            // Album Artwork (Click to Toggle Vinyl / Square Mode)
            Item {
                id: artContainer
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 170
                Layout.preferredHeight: 170

                // Audio-Reactive Beat Pulse Bottom Glow Shadow
                Rectangle {
                    id: tileAccentShadow
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: (artMouse.containsMouse ? 10 : 4) + (root.isPlaying ? root.cavaEnergy * 5 : 0)
                    width: parent.width - 6 + (root.isPlaying ? root.cavaEnergy * 10 : 0)
                    height: parent.height - 6 + (root.isPlaying ? root.cavaEnergy * 10 : 0)
                    radius: root.artAsVinyl ? width / 2 : 16
                    color: root.accentColor
                    opacity: artMouse.containsMouse ? 0.65 : (root.isPlaying ? 0.35 + (root.cavaEnergy * 0.25) : 0.15)

                    layer.enabled: true
                    layer.effect: MultiEffect {
                        blurEnabled: true
                        blurMax: 64
                        blur: 1.0
                    }

                    Behavior on radius { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                    Behavior on y { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                    Behavior on opacity { NumberAnimation { duration: 120 } }
                }

                Item {
                    id: vinylDisc
                    anchors.fill: parent
                    y: artMouse.containsMouse ? -4 : 0
                    Behavior on y { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                    Rectangle {
                        id: maskContainer
                        anchors.fill: parent
                        radius: root.artAsVinyl ? width / 2 : 16
                        color: "#ffffff"
                        visible: false
                        layer.enabled: true
                        layer.smooth: true
                        layer.textureSize: Qt.size(width * 2, height * 2)
                        antialiasing: true

                        Behavior on radius { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                    }

                    Item {
                        id: rotatingLayer
                        anchors.fill: parent
                        transformOrigin: Item.Center

                        layer.enabled: true
                        layer.smooth: true
                        layer.textureSize: Qt.size(width * 2, height * 2)
                        layer.effect: MultiEffect {
                            maskEnabled: true
                            maskSource: maskContainer
                            maskThresholdMin: 0.5
                            maskSpreadAtMin: 0.03
                        }

                        NumberAnimation {
                            id: squareReturnAnim
                            target: rotatingLayer
                            property: "rotation"
                            to: 0
                            duration: 450
                            easing.type: Easing.OutCubic
                        }

                        RotationAnimation {
                            id: vinylSpinAnim
                            target: rotatingLayer
                            property: "rotation"
                            running: root.artAsVinyl && root.isPlaying && root.visible
                            loops: Animation.Infinite
                            from: 0
                            to: 360
                            duration: 18000
                        }

                        Image {
                            id: artImg
                            anchors.fill: parent
                            source: root.activeArtUrl
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            smooth: true
                            mipmap: true
                        }

                        // Loading State
                        Rectangle {
                            anchors.fill: parent
                            radius: root.artAsVinyl ? width / 2 : 16
                            color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.15)
                            visible: artImg.status === Image.Loading

                            Text {
                                anchors.centerIn: parent
                                text: "󰑐"
                                color: Qt.rgba(1, 1, 1, 0.5)
                                font.family: root.iconFont
                                font.pixelSize: 32
                            }
                        }

                        // Fallback Missing Icon
                        Text {
                            anchors.centerIn: parent
                            text: "󰝚"
                            color: Qt.rgba(1, 1, 1, 0.25)
                            font.family: root.iconFont
                            font.pixelSize: 42
                            visible: artImg.status === Image.Error || artImg.status === Image.Null || root.activeArtUrl === ""
                        }

                        // Concentric Grooves (Vinyl mode only)
                        Repeater {
                            model: [0.90, 0.76, 0.62, 0.48]
                            Rectangle {
                                anchors.centerIn: parent
                                width: parent.width * modelData
                                height: parent.height * modelData
                                radius: width / 2
                                color: "transparent"
                                border.color: Qt.rgba(1, 1, 1, 0.07)
                                border.width: 1
                                antialiasing: true
                                visible: root.artAsVinyl
                            }
                        }

                        // Specular Light Sheen (Vinyl mode only)
                        Rectangle {
                            anchors.fill: parent
                            radius: width / 2
                            visible: root.artAsVinyl
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.14) }
                                GradientStop { position: 0.35; color: Qt.rgba(1, 1, 1, 0.02) }
                                GradientStop { position: 0.50; color: "transparent" }
                                GradientStop { position: 0.65; color: Qt.rgba(1, 1, 1, 0.02) }
                                GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.12) }
                            }
                        }

                        // Center Spindle Hub (Vinyl mode only)
                        Rectangle {
                            anchors.centerIn: parent
                            width: 30
                            height: width
                            radius: width / 2
                            color: "#0a0a0f"
                            border.color: root.accentColor
                            border.width: 1.5
                            antialiasing: true
                            visible: root.artAsVinyl

                            Rectangle {
                                anchors.centerIn: parent
                                width: 8
                                height: width
                                radius: width / 2
                                color: "#000000"
                                border.color: Qt.rgba(1, 1, 1, 0.35)
                                border.width: 1
                            }
                        }
                    }
                }

                MouseArea {
                    id: artMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.artAsVinyl = !root.artAsVinyl;
                        if (!root.artAsVinyl) {
                            squareReturnAnim.restart();
                        } else if (root.isPlaying) {
                            vinylSpinAnim.from = rotatingLayer.rotation % 360;
                            vinylSpinAnim.to = (rotatingLayer.rotation % 360) + 360;
                            vinylSpinAnim.restart();
                        }
                    }
                }
            }

            // Track Title & Artist
            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter
                spacing: 2

                Text {
                    text: root.currentTitle
                    color: "#ffffff"
                    font.pixelSize: 15
                    font.weight: Font.Bold
                    font.family: root.mainFont
                    font.letterSpacing: -0.2
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignHCenter
                    Layout.fillWidth: true
                }

                Text {
                    text: root.currentArtist
                    color: Qt.rgba(1, 1, 1, 0.6)
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    font.family: root.mainFont
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignHCenter
                    Layout.fillWidth: true
                }

                // Audio Quality Specs Badge (Under Artist in Mini Mode)
                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    height: 20
                    implicitWidth: specText.implicitWidth + 14
                    radius: 10
                    color: root.isLossless ? Qt.tint(root.accentColor, Qt.rgba(0, 0, 0, 0.78)) : Qt.rgba(1, 1, 1, 0.06)
                    border.color: root.isLossless ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.45) : Qt.rgba(1, 1, 1, 0.10)

                    Text {
                        id: specText
                        anchors.centerIn: parent
                        text: root.audioBadge
                        color: root.isLossless ? "#ffffff" : Qt.rgba(1, 1, 1, 0.75)
                        font.pixelSize: 9
                        font.bold: true
                        font.family: root.mainFont
                        font.letterSpacing: 0.4
                    }
                }
            }

            // Scrubber Bar
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 18

                    Rectangle {
                        id: progressTrack
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        height: scrubArea.containsMouse || root.isScrubbing ? 5 : 3
                        radius: height / 2
                        color: Qt.rgba(1, 1, 1, 0.12)
                        clip: true

                        Behavior on height { NumberAnimation { duration: 150 } }

                        Rectangle {
                            height: parent.height
                            width: {
                                let cur = root.isScrubbing ? root.scrubTargetTime : root.currentPlaybackTime;
                                return root.currentLength > 0 ? (cur / root.currentLength) * progressTrack.width : 0;
                            }
                            radius: height / 2
                            color: root.accentColor
                            Behavior on color { ColorAnimation { duration: 200 } }
                        }
                    }

                    Rectangle {
                        id: scrubHandle
                        x: {
                            let cur = root.isScrubbing ? root.scrubTargetTime : root.currentPlaybackTime;
                            let ratio = root.currentLength > 0 ? Math.min(1.0, Math.max(0.0, cur / root.currentLength)) : 0;
                            return (ratio * progressTrack.width) - (width / 2);
                        }
                        anchors.verticalCenter: parent.verticalCenter
                        width: scrubArea.containsMouse || root.isScrubbing ? 14 : 6
                        height: width
                        radius: width / 2
                        color: "#ffffff"
                        opacity: scrubArea.containsMouse || root.isScrubbing ? 1.0 : 0.65

                        Behavior on width { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                        Behavior on opacity { NumberAnimation { duration: 140 } }
                    }

                    MouseArea {
                        id: scrubArea
                        anchors.fill: parent
                        anchors.topMargin: -6
                        anchors.bottomMargin: -6
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        function updateScrub(mouseX) {
                            let ratio = Math.max(0.0, Math.min(1.0, mouseX / width));
                            root.scrubTargetTime = ratio * root.currentLength;
                        }

                        onPressed: mouse => {
                            root.isScrubbing = true;
                            updateScrub(mouse.x);
                        }
                        onPositionChanged: mouse => {
                            if (root.isScrubbing) {
                                updateScrub(mouse.x);
                            }
                        }
                        onReleased: {
                            if (root.isScrubbing) {
                                root.seekTo(root.scrubTargetTime);
                                root.isScrubbing = false;
                            }
                        }
                    }
                }

                // Time Labels
                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: root.formatTime(root.isScrubbing ? root.scrubTargetTime : root.currentPlaybackTime)
                        color: Qt.rgba(1, 1, 1, 0.45)
                        font.pixelSize: 9
                        font.family: root.mainFont
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        text: root.formatTime(root.currentLength)
                        color: Qt.rgba(1, 1, 1, 0.45)
                        font.pixelSize: 9
                        font.family: root.mainFont
                    }
                }
            }

            // Playback Controls Row with LiquidGlass Optics
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 16

                // Previous Button
                Item {
                    width: 38
                    height: 38
                    scale: prevMouse.pressed ? 0.90 : (prevMouse.containsMouse ? 1.08 : 1.0)
                    Behavior on scale { SpringAnimation { spring: 5.0; damping: 0.75; mass: 0.5 } }

                    SurfaceCard {
                        anchors.fill: parent
                        cornerRadius: height / 2
                        zRadius: height / 2
                        refraction: 0.38
                        edgeHighlight: 0.22
                        fresnel: 0.85
                        brightness: prevMouse.containsMouse ? 0.05 : -0.15
                        contentPadding: 0

                        Rectangle {
                            anchors.centerIn: parent
                            width: parent.width - 2
                            height: parent.height - 2
                            radius: width / 2
                            color: prevMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.06)
                            Behavior on color { ColorAnimation { duration: 150 } }

                            Text {
                                anchors.centerIn: parent
                                text: "󰒮"
                                color: "#ffffff"
                                font.family: root.iconFont
                                font.pixelSize: 16
                            }
                        }
                    }

                    MouseArea {
                        id: prevMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (Players.has && Players.active && Players.active.canGoPrevious) {
                                Players.active.previous();
                            } else if (shellRoot) {
                                shellRoot.spotifyPrev();
                            }
                        }
                    }
                }

                // Main Play/Pause Button with Liquid Glass Accent Dome
                Item {
                    width: 48
                    height: 48
                    scale: playMouse.pressed ? 0.92 : (playMouse.containsMouse ? 1.08 : 1.0)
                    Behavior on scale { SpringAnimation { spring: 5.0; damping: 0.75; mass: 0.5 } }

                    SurfaceCard {
                        anchors.fill: parent
                        cornerRadius: height / 2
                        zRadius: height / 2
                        refraction: 0.55
                        edgeHighlight: 0.32
                        fresnel: 1.0
                        brightness: playMouse.containsMouse ? 0.10 : 0.02
                        contentPadding: 0

                        Rectangle {
                            anchors.centerIn: parent
                            width: parent.width - 2
                            height: parent.height - 2
                            radius: width / 2
                            color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.88)
                            Behavior on color { ColorAnimation { duration: 200 } }

                            Text {
                                anchors.centerIn: parent
                                text: root.isPlaying ? "󰏤" : "󰐊"
                                color: (root.accentColor.r * 0.299 + root.accentColor.g * 0.587 + root.accentColor.b * 0.114 > 0.65) ? "#0c0c10" : "#ffffff"
                                font.family: root.iconFont
                                font.pixelSize: 19
                            }
                        }
                    }

                    MouseArea {
                        id: playMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (Players.has && Players.active && Players.active.canTogglePlaying) {
                                Players.active.togglePlaying();
                            } else if (shellRoot) {
                                shellRoot.spotifyPlay();
                            }
                        }
                    }
                }

                // Next Button
                Item {
                    width: 38
                    height: 38
                    scale: nextMouse.pressed ? 0.90 : (nextMouse.containsMouse ? 1.08 : 1.0)
                    Behavior on scale { SpringAnimation { spring: 5.0; damping: 0.75; mass: 0.5 } }

                    SurfaceCard {
                        anchors.fill: parent
                        cornerRadius: height / 2
                        zRadius: height / 2
                        refraction: 0.38
                        edgeHighlight: 0.22
                        fresnel: 0.85
                        brightness: nextMouse.containsMouse ? 0.05 : -0.15
                        contentPadding: 0

                        Rectangle {
                            anchors.centerIn: parent
                            width: parent.width - 2
                            height: parent.height - 2
                            radius: width / 2
                            color: nextMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.06)
                            Behavior on color { ColorAnimation { duration: 150 } }

                            Text {
                                anchors.centerIn: parent
                                text: "󰒭"
                                color: "#ffffff"
                                font.family: root.iconFont
                                font.pixelSize: 16
                            }
                        }
                    }

                    MouseArea {
                        id: nextMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (Players.has && Players.active && Players.active.canGoNext) {
                                Players.active.next();
                            } else if (shellRoot) {
                                shellRoot.spotifyNext();
                            }
                        }
                    }
                }
            }
        }
    }
}
