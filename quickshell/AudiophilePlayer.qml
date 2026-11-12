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
    title: "AudiophilePlayer"
    width: 820
    height: 500
    color: "transparent"
    visible: false
    flags: Qt.Window | Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint

    // Dynamic UI Sizing Ratios for Windowed & Full-Screen fluidity
    readonly property real uiScale: Math.max(0.85, Math.min(2.8, root.height / 480.0))
    readonly property real responsiveArtSize: Math.max(120, Math.min(650, Math.min((root.width * 0.38) - 48, root.height * 0.38)))
    readonly property int lyricBaseFontSize: Math.round(22 * Math.max(0.9, Math.min(2.2, root.height / 480.0)))

    property var shellRoot: null
    readonly property string iconFont: shellRoot ? shellRoot.iconFontFamily : "sans-serif"
    // Premium Typography: Prefer Inter, then Geist, then shellRoot font
    readonly property string lyricsFont: "Inter"
    readonly property string mainFont: "Inter"
    readonly property string monoFont: shellRoot ? shellRoot.monoFontFamily : "Geist Mono, JetBrains Mono, monospace"
    
    // Core track properties synced with Players singleton with shellRoot fallback
    readonly property bool hasPlayer: Players.has
    readonly property bool isPlaying: Players.has ? Players.playing : (shellRoot ? shellRoot.spotifyStatus === "playing" : false)
    readonly property string currentTitle: Players.has ? Players.title : (shellRoot && shellRoot.spotifyTitle ? shellRoot.spotifyTitle : "No Track")
    readonly property string currentArtist: Players.has ? Players.artist : (shellRoot && shellRoot.spotifyArtist ? shellRoot.spotifyArtist : "Unknown Artist")
    
    // Extracted / resolved art url from backend or MPRIS
    property string backendArtUrl: ""
    readonly property string activeArtUrl: {
        if (backendArtUrl !== "") return backendArtUrl;
        if (Players.has && Players.artUrl) return Players.artUrl;
        if (shellRoot && shellRoot.spotifyArtUrl) return shellRoot.spotifyArtUrl;
        return "";
    }

    readonly property real currentLength: {
        if (Players.has && Players.lengthSec > 0) return Players.lengthSec;
        if (shellRoot && shellRoot.spotifyLength) {
            let l = parseFloat(shellRoot.spotifyLength);
            if (!isNaN(l) && l > 0) return l;
        }
        return 1.0;
    }

    // Dynamic Palette properties
    property color dominantColor: "#121218"
    property color accentColor: "#0A84FF"
    property color blendedBgColor: Qt.tint(dominantColor, Qt.rgba(0.04, 0.04, 0.06, 0.96))

    // Audio Quality & Format Specs
    property string audioBadge: "HI-FI"
    property bool isLossless: false
    property bool artAsVinyl: true

    // High-Precision Delta Clock for Jitter-Free Lyrics
    property real anchorPosition: 0.0
    property real anchorTimestamp: 0.0
    property real currentPlaybackTime: 0.0
    property bool isScrubbing: false
    property real scrubTargetTime: 0.0

    // Lyrics metadata
    property bool isSynced: false
    property string lyricsSource: "none"
    property int activeLyricIndex: -1

    // Real-Time Lockscreen Cava Glow Pipeline
    property var cavaValues: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    property var cavaSmooth: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    property real cavaEnergy: 0.0
    property real visualizerTime: 0.0

    Process {
        id: cavaProcess
        running: root.visible && root.isPlaying
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

    // 60fps Lockscreen-Style Smooth Level Interpolation
    FrameAnimation {
        running: root.visible
        onTriggered: {
            root.visualizerTime += frameTime;
            let next = [];
            let dt = Math.min(frameTime, 0.05);
            let src = root.isPlaying ? root.cavaValues : [];
            for (let i = 0; i < 12; i++) {
                let cur = root.cavaSmooth[i] !== undefined ? root.cavaSmooth[i] : 0;
                let target = Math.min(1.0, (src && src[i] !== undefined ? src[i] : 0) * 1.6);
                // Musical ocean swell attack (0.32s) and graceful physical wave decay (1.35s)
                let tau = target > cur ? 0.4 : 1.6;
                let k = 1 - Math.exp(-dt / tau);
                next.push(cur + (target - cur) * k);
            }
            root.cavaSmooth = next;
        }
    }

    // Update anchor on external position updates
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

    // Format seconds into mm:ss
    function formatTime(sec) {
        if (isNaN(sec) || sec < 0) return "0:00";
        let m = Math.floor(sec / 60);
        let s = Math.floor(sec % 60);
        return m + ":" + (s < 10 ? "0" : "") + s;
    }

    // Track Change Detection & Debounced Lyrics Fetching
    property string trackIdentifier: currentTitle + "::" + currentArtist + "::" + (Players.has ? (Players.active.dbusName || "") : "")
    onTrackIdentifierChanged: {
        backendArtUrl = "";
        lyricsDataModel.clear();
        isSynced = false;
        activeLyricIndex = -1;
        isLossless = false;
        let isBrowser = Players.has && (Players.active.identity || "").toLowerCase().indexOf("brave") >= 0;
        audioBadge = isBrowser ? "WEB AUDIO" : "HI-FI";
        dominantColor = "#121218";
        accentColor = "#6366f1";
        anchorPosition = (Players.has && Players.active && Players.active.position >= 0) ? Players.active.position : 0.0;
        anchorTimestamp = Date.now();
        currentPlaybackTime = anchorPosition;
        if (currentTitle !== "" && currentTitle !== "No Track") {
            trackChangeDebounce.restart();
        } else {
            lyricsDataModel.append({time: -1, text: "No Active Track"});
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
            trackChangeDebounce.restart();
        }
    }

    Timer {
        id: trackChangeDebounce
        interval: 100
        onTriggered: {
            if (lyricsProcess.running) {
                lyricsProcess.running = false;
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
            } else if (shellRoot && shellRoot.spotifyArtUrl) {
                args.push("--art-url", shellRoot.spotifyArtUrl);
            }
            lyricsProcess.command = args;
            lyricsProcess.running = true;
        }
    }

    ListModel {
        id: lyricsDataModel
    }

    Process {
        id: lyricsProcess
        stdout: SplitParser {
            onRead: data => {
                let line = data.trim();
                if (!line) return;
                try {
                    let parsedData = JSON.parse(line);
                    if (parsedData.dominant_color) root.dominantColor = parsedData.dominant_color;
                    if (parsedData.accent_color) root.accentColor = parsedData.accent_color;
                    if (parsedData.art_url) root.backendArtUrl = parsedData.art_url;
                    root.isSynced = parsedData.synced || false;
                    root.lyricsSource = parsedData.source || "online";

                    if (parsedData.audio_specs) {
                        if (parsedData.audio_specs.badge) root.audioBadge = parsedData.audio_specs.badge;
                        root.isLossless = parsedData.audio_specs.lossless || false;
                    }

                    lyricsDataModel.clear();
                    if (!parsedData.lyrics || parsedData.lyrics.length === 0) {
                        lyricsDataModel.append({time: -1, text: "Instrumental / No Lyrics Available"});
                    } else {
                        for (let i = 0; i < parsedData.lyrics.length; i++) {
                            lyricsDataModel.append({
                                time: parsedData.lyrics[i].time,
                                text: parsedData.lyrics[i].text
                            });
                        }
                    }
                    root.updateActiveLyricIndex(false);
                } catch(e) {
                    console.log("Error parsing lyrics data:", e);
                }
            }
        }
    }

    // Binary search / Scan for active lyric index
    function updateActiveLyricIndex(forceJump) {
        if (!root.isSynced || lyricsDataModel.count === 0) {
            root.activeLyricIndex = -1;
            return;
        }
        let curTime = root.isScrubbing ? root.scrubTargetTime : root.currentPlaybackTime;
        let matchedIdx = -1;
        for (let i = 0; i < lyricsDataModel.count; i++) {
            let itemTime = lyricsDataModel.get(i).time;
            if (itemTime <= curTime + 0.15) {
                matchedIdx = i;
            } else {
                break;
            }
        }
        if (matchedIdx !== root.activeLyricIndex) {
            root.activeLyricIndex = matchedIdx;
            if (forceJump && matchedIdx >= 0) {
                lyricsView.positionViewAtIndex(matchedIdx, ListView.Center);
            }
        }
    }

    onCurrentPlaybackTimeChanged: {
        if (root.isSynced) {
            root.updateActiveLyricIndex(false);
        }
    }

    // Seek execution helper
    function seekTo(seconds) {
        let clamped = Math.max(0.0, Math.min(seconds, currentLength > 0 ? currentLength : seconds));
        if (Players.has && Players.active && Players.active.canSeek) {
            Players.active.position = clamped;
        } else if (shellRoot && shellRoot.spotifySeek) {
            shellRoot.spotifySeek(clamped);
        }
    }

    function switchToMiniPlayer() {
        root.visible = false;
        if (shellRoot && shellRoot.audiophileMiniPlayer) {
            shellRoot.audiophileMiniPlayer.visible = true;
        }
    }

    // Helper for status badge text
    function getStatusBadgeText() {
        if (root.isSynced) {
            if (root.lyricsSource.indexOf("lrclib") >= 0) return "LRCLIB SYNC";
            if (root.lyricsSource.indexOf("local") >= 0) return "LOCAL SYNC";
            return "SYNCED";
        } else {
            if (root.lyricsSource === "local_unsynced" || root.lyricsSource === "local") return "LOCAL TAGS";
            if (lyricsDataModel.count > 0 && lyricsDataModel.get(0).time >= 0) return "UNSYNCED";
            return "NO LYRICS";
        }
    }

    // UI Frame & Tactical Studio Chassis
    Rectangle {
        id: bgCard
        anchors.fill: parent
        radius: 6
        color: "#07070a"
        border.color: Qt.rgba(1, 1, 1, 0.12)
        border.width: 1
        clip: true
        antialiasing: true
        focus: true

        // Comprehensive Keyboard Support
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
            } else if (event.key === Qt.Key_Up) {
                if (shellRoot && shellRoot.pVolSet) {
                    let cur = parseInt(shellRoot.volumeOut) || 0;
                    let target = Math.min(100, cur + 5) / 100.0;
                    shellRoot.pVolSet.command = ["/home/krishna/dotfiles/scripts/set_volume.sh", target.toFixed(2)];
                    shellRoot.pVolSet.running = true;
                }
                event.accepted = true;
            } else if (event.key === Qt.Key_Down) {
                if (shellRoot && shellRoot.pVolSet) {
                    let cur = parseInt(shellRoot.volumeOut) || 0;
                    let target = Math.max(0, cur - 5) / 100.0;
                    shellRoot.pVolSet.command = ["/home/krishna/dotfiles/scripts/set_volume.sh", target.toFixed(2)];
                    shellRoot.pVolSet.running = true;
                }
                event.accepted = true;
            } else if (event.key === Qt.Key_C || event.key === Qt.Key_M) {
                root.switchToMiniPlayer();
                event.accepted = true;
            } else if (event.key === Qt.Key_Escape) {
                root.visible = false;
                event.accepted = true;
            }
        }

        // Background Blurred Album Art Layer
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

        // Layer 1: Ambient Horizontal Living Acoustic Wash
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { 
                    position: 0.0
                    color: Qt.tint(root.dominantColor, Qt.rgba(0.02, 0.02, 0.04, 0.70))
                }
                GradientStop { 
                    position: 0.48
                    color: Qt.tint(root.accentColor, Qt.rgba(0.03, 0.03, 0.05, 0.90))
                }
                GradientStop { 
                    position: 1.0
                    color: Qt.rgba(0.02, 0.02, 0.04, 0.96)
                }
            }
        }

        // Layer 2: Audio-Reactive Spectral Visualizer Field (Dynamic Multi-Shader Engine)
        ShaderEffect {
            id: glowField
            anchors.fill: parent
            property color accent: root.accentColor
            property color dominant: root.dominantColor
            property real time: root.visualizerTime
            property vector4d band0: Qt.vector4d(
                root.cavaSmooth[0] !== undefined ? root.cavaSmooth[0] : 0,
                root.cavaSmooth[1] !== undefined ? root.cavaSmooth[1] : 0,
                root.cavaSmooth[2] !== undefined ? root.cavaSmooth[2] : 0,
                root.cavaSmooth[3] !== undefined ? root.cavaSmooth[3] : 0
            )
            property vector4d band1: Qt.vector4d(
                root.cavaSmooth[4] !== undefined ? root.cavaSmooth[4] : 0,
                root.cavaSmooth[5] !== undefined ? root.cavaSmooth[5] : 0,
                root.cavaSmooth[6] !== undefined ? root.cavaSmooth[6] : 0,
                root.cavaSmooth[7] !== undefined ? root.cavaSmooth[7] : 0
            )
            property vector4d band2: Qt.vector4d(
                root.cavaSmooth[8] !== undefined ? root.cavaSmooth[8] : 0,
                root.cavaSmooth[9] !== undefined ? root.cavaSmooth[9] : 0,
                root.cavaSmooth[10] !== undefined ? root.cavaSmooth[10] : 0,
                root.cavaSmooth[11] !== undefined ? root.cavaSmooth[11] : 0
            )
            fragmentShader: {
                let s = (shellRoot && shellRoot.visualizerShader !== undefined) ? shellRoot.visualizerShader : 0;
                switch (s) {
                    case 1: return "shaders/fluid_mesh.frag.qsb";
                    case 2: return "shaders/waves.frag.qsb";
                    default: return "shaders/glow.frag.qsb";
                }
            }
            opacity: root.isPlaying ? 0.66 : 0.48

            Behavior on opacity {
                NumberAnimation { duration: 1200; easing.type: Easing.InOutQuad }
            }
        }

        // Layer 3: Atmospheric Corner Glow Drift
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop {
                    position: 0.0
                    color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.10)
                }
                GradientStop {
                    position: 0.50
                    color: "transparent"
                }
                GradientStop {
                    position: 1.0
                    color: Qt.rgba(root.dominantColor.r, root.dominantColor.g, root.dominantColor.b, 0.12)
                }
            }
        }

        // Layer 4: Horizontal Typography Reading Scrim (Protects lyrics legibility over shaders)
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop {
                    position: 0.0
                    color: "transparent"
                }
                GradientStop {
                    position: 0.40
                    color: "transparent"
                }
                GradientStop {
                    position: 0.70
                    color: Qt.rgba(0.03, 0.03, 0.05, 0.48)
                }
                GradientStop {
                    position: 1.0
                    color: Qt.rgba(0.03, 0.03, 0.05, 0.78)
                }
            }
        }


        // Layer 5: Suspended Floating Acoustic Particles (Music-Reactive Stardust - Glow Only)
        Canvas {
            id: particleCanvas
            anchors.fill: parent
            z: 0
            
            readonly property int currentShader: (shellRoot && shellRoot.visualizerShader !== undefined) ? shellRoot.visualizerShader : 0
            readonly property bool isGlow: currentShader === 0
            visible: opacity > 0.001
            opacity: isGlow ? (root.isPlaying ? 1.0 : 0.45) : 0.0
            
            Behavior on opacity {
                NumberAnimation { duration: 500; easing.type: Easing.InOutQuad }
            }
            
            property var particles: []
            property int count: 28

            Component.onCompleted: {
                let list = [];
                for (let i = 0; i < count; i++) {
                    list.push({
                        x: Math.random(),
                        y: Math.random(),
                        baseR: 1.2 + Math.random() * 1.8,
                        speedY: 0.0003 + Math.random() * 0.0007,
                        phase: Math.random() * Math.PI * 2,
                        phaseSpeed: 0.015 + Math.random() * 0.025,
                        baseAlpha: 0.18 + Math.random() * 0.35
                    });
                }
                particles = list;
            }

            FrameAnimation {
                running: root.visible && particleCanvas.isGlow && (root.isPlaying || particleCanvas.opacity > 0.01)
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

        // Main Horizontal Split Layout
        RowLayout {
            z: 2
            anchors.fill: parent
            anchors.topMargin: Math.round(18 * root.uiScale)
            anchors.leftMargin: Math.round(24 * root.uiScale)
            anchors.rightMargin: Math.round(24 * root.uiScale)
            anchors.bottomMargin: Math.round(18 * root.uiScale)
            spacing: Math.round(24 * root.uiScale)

            // LEFT PANEL: Album Art, Info & Hi-Fi Controls (Responsive Width)
            ColumnLayout {
                Layout.preferredWidth: Math.max(280, responsiveArtSize + Math.round(48 * root.uiScale))
                Layout.fillWidth: false
                Layout.fillHeight: true
                Layout.alignment: Qt.AlignTop
                spacing: Math.round(6 * root.uiScale)

                // Top Header Row (Close Button, Refetch Icon, and Lyric Status Badge)
                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 28
                    Layout.alignment: Qt.AlignTop
                    spacing: 8

                    // Close Button
                    Rectangle {
                        width: 28
                        height: 28
                        radius: 3
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

                    // Compact Mini-Player Button
                    Rectangle {
                        width: 28
                        height: 28
                        radius: 3
                        color: compactArea.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(1, 1, 1, 0.06)
                        border.color: Qt.rgba(1, 1, 1, 0.1)

                        Behavior on color { ColorAnimation { duration: 150 } }

                        Text {
                            anchors.centerIn: parent
                            text: "󰩨"
                            color: compactArea.containsMouse ? root.accentColor : Qt.rgba(1, 1, 1, 0.6)
                            font.family: root.iconFont
                            font.pixelSize: 13
                        }

                        MouseArea {
                            id: compactArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.switchToMiniPlayer()
                        }
                    }

                    // Visualizer Mode Switcher Chip
                    Rectangle {
                        id: visualizerChip
                        height: 28
                        implicitWidth: vizRow.implicitWidth + 16
                        radius: 3
                        color: vizMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(1, 1, 1, 0.06)
                        border.color: vizMouse.containsMouse ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.50) : Qt.rgba(1, 1, 1, 0.1)

                        Behavior on color { ColorAnimation { duration: 150 } }

                        RowLayout {
                            id: vizRow
                            anchors.centerIn: parent
                            spacing: 5

                            Text {
                                text: {
                                    let s = (shellRoot && shellRoot.visualizerShader !== undefined) ? shellRoot.visualizerShader : 0;
                                    switch(s) {
                                        case 1: return "󰑈";
                                        case 2: return "󰐐";
                                        case 3: return "󰓃";
                                        case 4: return "󰻂";
                                        default: return "󰝚";
                                    }
                                }
                                color: Qt.rgba(1, 1, 1, 0.90)
                                font.family: root.iconFont
                                font.pixelSize: 12
                            }

                            Text {
                                text: {
                                    let s = (shellRoot && shellRoot.visualizerShader !== undefined) ? shellRoot.visualizerShader : 0;
                                    switch(s) {
                                        case 1: return "Fluid";
                                        case 2: return "Tide";
                                        default: return "Glow";
                                    }
                                }
                                color: Qt.rgba(1, 1, 1, 0.75)
                                font.pixelSize: 10
                                font.weight: Font.Medium
                                font.family: root.mainFont
                            }
                        }

                        MouseArea {
                            id: vizMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (shellRoot) {
                                    shellRoot.visualizerShader = (shellRoot.visualizerShader + 1) % 3;
                                }
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // Interactive Active Player Source Badge (Teenage Engineering Tactile Micro-Key)
                    Rectangle {
                        id: sourceChip
                        height: 24
                        implicitWidth: sourceRow.implicitWidth + 12
                        radius: 2
                        color: sourceMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.05)
                        border.color: sourceMouse.containsMouse ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.60) : Qt.rgba(1, 1, 1, 0.12)
                        border.width: 1

                        RowLayout {
                            id: sourceRow
                            anchors.centerIn: parent
                            spacing: 5

                            Rectangle {
                                width: 3
                                height: 3
                                radius: 0.5
                                color: root.isPlaying ? "#30D158" : "#FF9F0A"
                                Layout.alignment: Qt.AlignVCenter
                            }

                            Text {
                                text: Players.playerIconOf(Players.active)
                                color: Qt.rgba(1, 1, 1, 0.90)
                                font.family: root.iconFont
                                font.pixelSize: 11
                                Layout.alignment: Qt.AlignVCenter
                            }

                            Text {
                                text: Players.playerNameOf(Players.active).toUpperCase()
                                color: Qt.rgba(1, 1, 1, 0.85)
                                font.pixelSize: 9
                                font.weight: Font.DemiBold
                                font.family: root.monoFont
                                font.letterSpacing: 0.5
                                Layout.alignment: Qt.AlignVCenter
                            }

                            Text {
                                visible: Players.pickable.length > 1
                                text: "󰅀"
                                color: Qt.rgba(1, 1, 1, 0.40)
                                font.family: root.iconFont
                                font.pixelSize: 9
                                Layout.alignment: Qt.AlignVCenter
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

                // Rotating Vinyl CD Record with Album Art & Ambient Shadow
                Item {
                    id: artContainer
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: Math.round(20 * root.uiScale)
                    Layout.bottomMargin: Math.round(20 * root.uiScale)
                    Layout.preferredWidth: root.responsiveArtSize
                    Layout.preferredHeight: root.responsiveArtSize

                    // Deep Accent Bottom Drop Shadow (Audio-Reactive Beat Pulse)
                    Rectangle {
                        id: tileAccentShadow
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: (artMouse.containsMouse ? 10 : 4) + (root.isPlaying ? root.cavaEnergy * 5 : 0)
                        width: parent.width - 6 + (root.isPlaying ? root.cavaEnergy * 10 : 0)
                        height: parent.height - 6 + (root.isPlaying ? root.cavaEnergy * 10 : 0)
                        radius: root.artAsVinyl ? width / 2 : Math.round(18 * root.uiScale)
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

                    // Hover Lift Container
                    Item {
                        id: vinylDisc
                        anchors.fill: parent
                        y: artMouse.containsMouse ? -4 : 0
                        Behavior on y { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                        // Circular / Rounded Mask Definition
                        Rectangle {
                            id: maskContainer
                            anchors.fill: parent
                            radius: root.artAsVinyl ? width / 2 : Math.round(16 * root.uiScale)
                            color: "#ffffff"
                            visible: false
                            layer.enabled: true
                            layer.smooth: true
                            layer.textureSize: Qt.size(width * 2, height * 2)
                            antialiasing: true

                            Behavior on radius { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                        }

                        // Rotating Masked Art Layer
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

                            // 360° Smooth Vinyl Continuous Spin (active in vinyl mode and playing)
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

                            // Center Album Artwork
                            Image {
                                id: artImg
                                anchors.fill: parent
                                source: root.activeArtUrl
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                smooth: true
                                mipmap: true
                            }

                            // Loading State: Subtle Ambient Pulse / Shimmer Ring
                            Rectangle {
                                anchors.fill: parent
                                radius: root.artAsVinyl ? width / 2 : Math.round(16 * root.uiScale)
                                color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.15)
                                visible: artImg.status === Image.Loading
                                antialiasing: true

                                SequentialAnimation on opacity {
                                    running: artImg.status === Image.Loading
                                    loops: Animation.Infinite
                                    NumberAnimation { from: 0.25; to: 0.75; duration: 750; easing.type: Easing.InOutSine }
                                    NumberAnimation { from: 0.75; to: 0.25; duration: 750; easing.type: Easing.InOutSine }
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰑐"
                                    color: Qt.rgba(1, 1, 1, 0.5)
                                    font.family: root.iconFont
                                    font.pixelSize: Math.round(36 * root.uiScale)

                                    RotationAnimation on rotation {
                                        running: artImg.status === Image.Loading
                                        from: 0
                                        to: 360
                                        duration: 1200
                                        loops: Animation.Infinite
                                    }
                                }
                            }

                            // Error / Missing Art State: Static Vinyl Icon
                            Text {
                                anchors.centerIn: parent
                                text: "󰝚"
                                color: Qt.rgba(1, 1, 1, 0.25)
                                font.family: root.iconFont
                                font.pixelSize: Math.round(52 * root.uiScale)
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
                                width: Math.round(34 * root.uiScale)
                                height: width
                                radius: width / 2
                                color: "#0a0a0f"
                                border.color: root.accentColor
                                border.width: 1.5
                                antialiasing: true
                                visible: root.artAsVinyl

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: Math.round(9 * root.uiScale)
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

                // Track Title, Artist, & Audio Quality Badge (e.g. FLAC • 24-bit • 96 kHz)
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 2

                    Text {
                        text: root.currentTitle
                        color: "#ffffff"
                        font.pixelSize: Math.round(16 * root.uiScale)
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
                        font.pixelSize: Math.round(13 * root.uiScale)
                        font.weight: Font.Medium
                        font.family: root.mainFont
                        elide: Text.ElideRight
                        horizontalAlignment: Text.AlignHCenter
                        Layout.fillWidth: true
                    }

                    // Primary Audio Quality / Format Specs Badge (Teenage Engineering CAD Telemetry)
                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: 6
                        height: Math.round(20 * root.uiScale)
                        implicitWidth: specRow.implicitWidth + Math.round(16 * root.uiScale)
                        radius: 2
                        color: Qt.rgba(0.06, 0.07, 0.09, 0.85)
                        border.color: root.isLossless ? Qt.rgba(0.04, 0.52, 1.0, 0.60) : Qt.rgba(1, 1, 1, 0.16)
                        border.width: 1

                        RowLayout {
                            id: specRow
                            anchors.centerIn: parent
                            spacing: 5

                            Rectangle {
                                width: 3
                                height: 3
                                radius: 0.5
                                color: root.isLossless ? "#30D158" : root.accentColor
                                Layout.alignment: Qt.AlignVCenter
                            }

                            Text {
                                id: specText
                                text: "[ " + root.audioBadge.toUpperCase() + " ]"
                                color: root.isLossless ? "#ffffff" : Qt.rgba(1, 1, 1, 0.85)
                                font.pixelSize: 9
                                font.bold: true
                                font.family: root.monoFont
                                font.letterSpacing: 0.6
                                Layout.alignment: Qt.AlignVCenter
                            }
                        }
                    }
                }

                // Interactive Scrubber Timeline (Precision Calibrated Audio Track)
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 20

                        Rectangle {
                            id: progressTrack
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width
                            height: scrubArea.containsMouse || root.isScrubbing ? 4 : 2
                            radius: 1
                            color: Qt.rgba(1, 1, 1, 0.12)
                            clip: true

                            Behavior on height { NumberAnimation { duration: 150 } }

                            Rectangle {
                                height: parent.height
                                width: {
                                    let cur = root.isScrubbing ? root.scrubTargetTime : root.currentPlaybackTime;
                                    return root.currentLength > 0 ? (cur / root.currentLength) * progressTrack.width : 0;
                                }
                                radius: 1
                                color: root.accentColor

                                Behavior on color { ColorAnimation { duration: 200 } }
                            }
                        }

                        // Precision Hardware Scrubber Needle Cursor (TE Index Marker)
                        Rectangle {
                            id: scrubHandle
                            x: {
                                let cur = root.isScrubbing ? root.scrubTargetTime : root.currentPlaybackTime;
                                let ratio = root.currentLength > 0 ? Math.min(1.0, Math.max(0.0, cur / root.currentLength)) : 0;
                                return (ratio * progressTrack.width) - (width / 2);
                            }
                            anchors.verticalCenter: parent.verticalCenter
                            width: scrubArea.containsMouse || root.isScrubbing ? 4 : 3
                            height: Math.round(12 * root.uiScale)
                            radius: 0.5
                            color: "#ffffff"
                            opacity: scrubArea.containsMouse || root.isScrubbing ? 1.0 : 0.75

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
                            onReleased: mouse => {
                                if (root.isScrubbing) {
                                    updateScrub(mouse.x);
                                    root.seekTo(root.scrubTargetTime);
                                    root.isScrubbing = false;
                                }
                            }
                            onCanceled: root.isScrubbing = false
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            text: "[ " + root.formatTime(root.isScrubbing ? root.scrubTargetTime : root.currentPlaybackTime) + " ]"
                            color: Qt.rgba(1, 1, 1, 0.55)
                            font {
                                family: root.monoFont
                                pixelSize: 9
                                weight: Font.DemiBold
                                features: { "tnum": 1 }
                            }
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            text: "[ " + root.formatTime(root.currentLength) + " ]"
                            color: Qt.rgba(1, 1, 1, 0.55)
                            font {
                                family: root.monoFont
                                pixelSize: 9
                                weight: Font.DemiBold
                                features: { "tnum": 1 }
                            }
                        }
                    }
                }

                // Focused Hi-Fi Playback Controls (Previous, Play/Pause, Next) with Pure LiquidGlass Optics
                RowLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignHCenter
                    spacing: Math.round(20 * root.uiScale)

                    // Previous Button
                    Item {
                        width: Math.round(42 * root.uiScale)
                        height: Math.round(42 * root.uiScale)
                        scale: prevMouse.pressed ? 0.90 : (prevMouse.containsMouse ? 1.08 : 1.0)
                        Behavior on scale { SpringAnimation { spring: 5.0; damping: 0.75; mass: 0.5 } }

                        SurfaceCard {
                            anchors.fill: parent
                            cornerRadius: 4
                            zRadius: 4
                            refraction: 0.38
                            edgeHighlight: 0.22
                            fresnel: 0.85
                            brightness: prevMouse.containsMouse ? 0.05 : -0.15
                            contentPadding: 0

                            Rectangle {
                                anchors.centerIn: parent
                                width: parent.width - 2
                                height: parent.height - 2
                                radius: 3
                                color: prevMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.06)
                                border.color: Qt.rgba(1, 1, 1, 0.10)
                                border.width: 1
                                Behavior on color { ColorAnimation { duration: 150 } }

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰒮"
                                    color: "#ffffff"
                                    font.family: root.iconFont
                                    font.pixelSize: Math.round(18 * root.uiScale)
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

                    // Main Play/Pause Button with Tactile Accent Key
                    Item {
                        width: Math.round(54 * root.uiScale)
                        height: Math.round(54 * root.uiScale)
                        scale: playMouse.pressed ? 0.92 : (playMouse.containsMouse ? 1.06 : 1.0)
                        Behavior on scale { SpringAnimation { spring: 5.0; damping: 0.75; mass: 0.5 } }

                        SurfaceCard {
                            anchors.fill: parent
                            cornerRadius: 6
                            zRadius: 6
                            refraction: 0.55
                            edgeHighlight: 0.32
                            fresnel: 1.0
                            brightness: playMouse.containsMouse ? 0.10 : 0.02
                            contentPadding: 0

                            Rectangle {
                                anchors.centerIn: parent
                                width: parent.width - 2
                                height: parent.height - 2
                                radius: 4
                                color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.88)
                                border.color: Qt.rgba(1, 1, 1, 0.20)
                                border.width: 1
                                Behavior on color { ColorAnimation { duration: 200 } }

                                Text {
                                    anchors.centerIn: parent
                                    text: root.isPlaying ? "󰏤" : "󰐊"
                                    color: (root.accentColor.r * 0.299 + root.accentColor.g * 0.587 + root.accentColor.b * 0.114 > 0.65) ? "#0c0c10" : "#ffffff"
                                    font.family: root.iconFont
                                    font.pixelSize: Math.round(22 * root.uiScale)
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
                        width: Math.round(42 * root.uiScale)
                        height: Math.round(42 * root.uiScale)
                        scale: nextMouse.pressed ? 0.90 : (nextMouse.containsMouse ? 1.08 : 1.0)
                        Behavior on scale { SpringAnimation { spring: 5.0; damping: 0.75; mass: 0.5 } }

                        SurfaceCard {
                            anchors.fill: parent
                            cornerRadius: 4
                            zRadius: 4
                            refraction: 0.38
                            edgeHighlight: 0.22
                            fresnel: 0.85
                            brightness: nextMouse.containsMouse ? 0.05 : -0.15
                            contentPadding: 0

                            Rectangle {
                                anchors.centerIn: parent
                                width: parent.width - 2
                                height: parent.height - 2
                                radius: 3
                                color: nextMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.06)
                                border.color: Qt.rgba(1, 1, 1, 0.10)
                                border.width: 1
                                Behavior on color { ColorAnimation { duration: 150 } }

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰒭"
                                    color: "#ffffff"
                                    font.family: root.iconFont
                                    font.pixelSize: Math.round(18 * root.uiScale)
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

            // Vertical Divider
            Rectangle {
                Layout.fillHeight: true
                Layout.preferredWidth: 1
                color: Qt.rgba(1, 1, 1, 0.06)
            }

            // RIGHT PANEL: Borderless Fluid Apple Music Lyrics Canvas with Spring Physics & Edge Fade
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.alignment: Qt.AlignTop
                spacing: 6

                // Top Lyrics Header: Status Badge + Refetch Button
                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 28
                    Layout.alignment: Qt.AlignTop
                    spacing: 8

                    Item { Layout.fillWidth: true }

                    // Refetch Lyrics Button (Tactile Micro-Key)
                    Rectangle {
                        width: 24
                        height: 22
                        radius: 2
                        color: refetchArea.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.06)
                        border.color: refetchArea.containsMouse ? Qt.rgba(1, 1, 1, 0.25) : Qt.rgba(1, 1, 1, 0.12)
                        border.width: 1

                        Text {
                            id: refetchIcon
                            anchors.centerIn: parent
                            text: "󰑐"
                            color: refetchArea.containsMouse ? root.accentColor : Qt.rgba(1, 1, 1, 0.6)
                            font.family: root.iconFont
                            font.pixelSize: 12

                            RotationAnimation on rotation {
                                running: lyricsProcess.running
                                from: 0
                                to: 360
                                duration: 800
                                loops: Animation.Infinite
                            }
                        }

                        MouseArea {
                            id: refetchArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: trackChangeDebounce.restart()
                        }
                    }

                    // Diagnostic Synced / Status Badge (TE CAD Telemetry Tag)
                    Rectangle {
                        height: 22
                        implicitWidth: statusLabel.implicitWidth + 16
                        radius: 2
                        color: Qt.rgba(0.06, 0.07, 0.09, 0.85)
                        border.color: root.isSynced ? Qt.rgba(0.04, 0.52, 1.0, 0.50) : Qt.rgba(1, 1, 1, 0.12)
                        border.width: 1

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 5

                            Rectangle {
                                width: 3
                                height: 3
                                radius: 0.5
                                color: root.isSynced ? "#30D158" : Qt.rgba(1, 1, 1, 0.35)
                                Layout.alignment: Qt.AlignVCenter
                                
                                SequentialAnimation on opacity {
                                    loops: Animation.Infinite
                                    running: root.isSynced && root.isPlaying
                                    NumberAnimation { to: 0.2; duration: 800; easing.type: Easing.InOutSine }
                                    NumberAnimation { to: 1.0; duration: 800; easing.type: Easing.InOutSine }
                                }
                            }

                            Text {
                                id: statusLabel
                                text: "[ " + root.getStatusBadgeText().toUpperCase() + " ]"
                                color: root.isSynced ? Qt.rgba(1, 1, 1, 0.85) : Qt.rgba(1, 1, 1, 0.45)
                                font.pixelSize: 8
                                font.bold: true
                                font.family: root.monoFont
                                font.letterSpacing: 0.5
                                Layout.alignment: Qt.AlignVCenter
                            }
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                // Dedicated Instrumental / Empty Lyrics State
                Item {
                    anchors.centerIn: parent
                    visible: lyricsDataModel.count === 0 || (lyricsDataModel.count === 1 && lyricsDataModel.get(0).time < 0)
                    width: parent.width * 0.85
                    height: 140

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 10

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: "󰝚"
                            color: Qt.rgba(1, 1, 1, 0.18)
                            font.family: root.iconFont
                            font.pixelSize: Math.round(44 * root.uiScale)
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: "Instrumental Piece"
                            color: Qt.rgba(1, 1, 1, 0.70)
                            font.pixelSize: Math.round(18 * root.uiScale)
                            font.weight: Font.Bold
                            font.family: root.lyricsFont
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: "No synchronized lyrics available"
                            color: Qt.rgba(1, 1, 1, 0.35)
                            font.pixelSize: Math.round(12 * root.uiScale)
                            font.family: root.mainFont
                        }
                    }
                }

                ListView {
                    id: lyricsView
                    anchors.fill: parent
                    clip: true
                    spacing: Math.round(20 * root.uiScale)
                    model: lyricsDataModel
                    visible: lyricsDataModel.count > 0 && lyricsDataModel.get(0).time >= 0

                    currentIndex: root.activeLyricIndex
                    preferredHighlightBegin: height * 0.38
                    preferredHighlightEnd: height * 0.42
                    highlightRangeMode: ListView.StrictlyEnforceRange
                    highlightMoveDuration: 600
                    highlightMoveVelocity: -1

                    delegate: Item {
                        id: lyricRow
                        width: lyricsView.width
                        height: lyricText.implicitHeight + Math.round(12 * root.uiScale)
                        clip: false

                        property bool isActive: index === root.activeLyricIndex
                        property bool isPast: root.isSynced && model.time >= 0 && model.time < root.currentPlaybackTime && !isActive

                        Item {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 16

                            Text {
                                id: lyricText
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                text: model.text.trim() === "" ? "♪" : model.text
                                color: "#ffffff"
                                opacity: lyricRow.isActive ? 1.0 : (lyricMouse.containsMouse ? 0.70 : (lyricRow.isPast ? 0.40 : 0.22))
                                font.pixelSize: root.lyricBaseFontSize
                                font.weight: lyricRow.isActive ? Font.Bold : Font.DemiBold
                                font.family: root.lyricsFont
                                font.letterSpacing: -0.3
                                wrapMode: Text.WordWrap
                                horizontalAlignment: Text.AlignLeft

                                scale: lyricRow.isActive ? 1.06 : (lyricMouse.containsMouse ? 0.99 : 0.94)
                                transformOrigin: Item.Left

                                Behavior on scale {
                                    SpringAnimation {
                                        spring: 3.4
                                        damping: 0.65
                                        mass: 0.8
                                        epsilon: 0.001
                                    }
                                }
                                Behavior on opacity {
                                    NumberAnimation { duration: 350; easing.type: Easing.OutCubic }
                                }
                            }
                        }

                        // Click to Seek
                        MouseArea {
                            id: lyricMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: (root.isSynced && model.time >= 0) ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: {
                                if (root.isSynced && model.time >= 0) {
                                    root.seekTo(model.time);
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
}