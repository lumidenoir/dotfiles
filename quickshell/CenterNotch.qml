import Quickshell
import QtQuick
import QtCore
import QtQuick.Shapes
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Io
import Quickshell.Services.Notifications
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import QtQuick.Effects
import Quickshell.Services.Mpris
import "Singletons"
import "Character"

Rectangle {
    id: notchRect
    property var root
    property alias notchLayout: notchLayout

    SystemClock {
        id: sysClock
        precision: SystemClock.Minutes
    }

    property bool isMaximized: false

    readonly property bool isContinuous: (root.islandState === root.stateMedia ||
                                          root.islandState === root.stateTimer ||
                                          root.islandState === root.stateStopwatch ||
                                          root.islandState === root.stateRecording ||
                                          root.islandState === root.statePomodoro ||
                                          root.islandState === root.stateComms)

    readonly property bool isExpandedContinuous: isContinuous && isMaximized

    readonly property real minimizedNotchWidth: {
        if (root.islandState === root.stateMedia) return Math.round(280 * scaleFactor);
        if (root.islandState === root.stateTimer) return Math.round(240 * scaleFactor);
        if (root.islandState === root.statePomodoro) return Math.round(260 * scaleFactor);
        if (root.islandState === root.stateStopwatch) return Math.round(220 * scaleFactor);
        if (root.islandState === root.stateRecording) return Math.round(210 * scaleFactor);
        if (root.islandState === root.stateComms) return Math.round(190 * scaleFactor);
        return root.closedNotchWidth;
    }

    readonly property real targetHeight: (root.islandState === root.stateDragLocalSend || root.islandState === root.stateLocalSendSuccess)
            ? 64 * scaleFactor
            : (root.islandState === root.stateNudge ? 52 * scaleFactor : (isExpandedContinuous ? 66 * scaleFactor : (root.topHuggingStyle ? 36 * scaleFactor : 32 * scaleFactor)))
    readonly property real targetWidth: root.isCenterPopupOpen
            ? (32 * scaleFactor)
            : (root.islandState === root.stateCompact
                ? root.closedNotchWidth
                : (isContinuous && !isMaximized
                    ? minimizedNotchWidth
                    : (root._notchWidths[root.islandState] || root.closedNotchWidth)))

    readonly property real morphCloseness: {
        var d = Math.max(Math.abs(width - targetWidth), Math.abs(height - targetHeight));
        return 1.0 - Math.min(1.0, d / (70 * scaleFactor));
    }

    readonly property real scaleFactor: root ? root.scaleFactor : 1.0
    readonly property real fontScale: root ? root.fontScale : 1.0

    color: "transparent"
    z: 10
    opacity: root.isCenterPopupOpen ? 0.0 : 1.0
    visible: opacity > 0.0

    anchors.top: parent.top
    anchors.topMargin: root.topHuggingStyle ? 0 : Math.round(4 * scaleFactor)
    anchors.horizontalCenter: parent.horizontalCenter // Managed by dynamicIslandContainer
    // Dynamic heights and widths matching Apple Dynamic Island transitions
    clip: true
    // LocalSend expands taller for a dramatic dock-style pop
    height: (root.islandState === root.stateDragLocalSend || root.islandState === root.stateLocalSendSuccess)
            ? Math.round(64 * scaleFactor)
            : (root.islandState === root.stateNudge ? Math.round(52 * scaleFactor) : (isExpandedContinuous ? Math.round(66 * scaleFactor) : (root.topHuggingStyle ? Math.round(36 * scaleFactor) : Math.round(32 * scaleFactor))))
    width: targetWidth
    radius: (root.topHuggingStyle && !isExpandedContinuous) ? 2 : Math.round(4 * scaleFactor)

    // flareSize: smoothly tracks radius so the flare shapes don't jump
    // when the spring reverses direction during close animation.
    property real flareSize: radius
    Behavior on flareSize {
        enabled: true
        SmoothedAnimation {
            velocity: 140
            easing.type: Easing.InOutQuad
        }
    }
    onRadiusChanged: flareSize = radius

    // Pill pop: suppressed for LocalSend — the spring overshoot IS the pop.
    property real popScale: 1.0
    scale: popScale
    transformOrigin: Item.Center
    onPopScaleChanged: {}

    // Fluid Surface Tension dynamics driven by SpringAnimation velocity
    property real _lastWidth: width
    property real _lastWidthTime: Date.now()
    property real rawFluidTension: 0.0
    property real fluidTension: rawFluidTension

    Behavior on fluidTension {
        SmoothedAnimation {
            velocity: 6.5
            easing.type: Easing.OutQuad
        }
    }

    Timer {
        id: tensionDecayTimer
        interval: 75
        running: Math.abs(notchRect.rawFluidTension) > 0.001
        repeat: false
        onTriggered: {
            notchRect.rawFluidTension = 0.0;
        }
    }

    onWidthChanged: {
        var now = Date.now();
        var dt = (now - _lastWidthTime) / 1000.0;
        if (dt > 0.003 && dt < 0.09) {
            var v = (width - _lastWidth) / dt; // px/sec (+ when expanding, - when contracting)
            if (Math.abs(v) < 25.0 && Math.abs(width - targetWidth) < 2.0) {
                rawFluidTension = 0.0;
            } else {
                // Peak velocity during dynamic island spring is ~900-1400 px/sec
                var normV = v / (1000.0 * Math.max(0.5, scaleFactor));
                rawFluidTension = Math.max(-1.0, Math.min(1.0, normV));
                tensionDecayTimer.restart();
            }
        }
        _lastWidth = width;
        _lastWidthTime = now;
    }

    // MultiEffect drop shadow enabled only when settled (morphCloseness > 0.99)
    layer.enabled: root.bootSettled && morphCloseness > 0.7 && !root.batteryMode
    layer.effect: MultiEffect {
        shadowEnabled: true
        shadowColor: Qt.rgba(0, 0, 0, 0.35)
        shadowBlur: 10 * scaleFactor
        shadowVerticalOffset: 3 * scaleFactor
        shadowHorizontalOffset: 0
    }

    // Tracks the real frame-by-frame previous islandState.
    // root.prevIslandState is only updated by safeSavePrev() (transient alerts),
    // so it stays "compact" even during active→active swaps, causing false bounces.
    property int _prevLocalState: root.stateCompact

    Connections {
        target: root
        function onIslandStateChanged() {
            notchRect.isMaximized = false;
            var prev = notchRect._prevLocalState;
            var s    = root.islandState;
            notchRect._prevLocalState = s;   // update before any early returns

            if (root.batteryMode) return;
            if (s === root.stateStopwatch && !root.stopwatchRunning && root.stopwatchSeconds === 0) {
                root.stopwatchRunning = true;
            }
            if (s === root.stateDragLocalSend || s === root.stateLocalSendSuccess) return;
            // Only bounce when exactly one side of the transition is compact.
            // Active ↔ active transitions skip the bounce entirely.
            var toCompact   = (s    === root.stateCompact);
            var fromCompact = (prev === root.stateCompact);
            if (fromCompact && !toCompact) {
                CharacterBus.react("greet");
            }
            if (toCompact || fromCompact) {
                popSequence.restart();
            }
        }
    }
    SequentialAnimation {
        id: popSequence
        NumberAnimation { target: notchRect; property: "popScale"; to: 1.055; duration: 120; easing.type: Easing.OutQuad }
        NumberAnimation { target: notchRect; property: "popScale"; to: 0.975; duration: 90; easing.type: Easing.InOutQuad }
        NumberAnimation { target: notchRect; property: "popScale"; to: 1.00; duration: 130; easing.type: Easing.OutElastic }
    }

    // DOCK-STYLE: low damping gives visible overshoot so the pill "pops" open
    // like a macOS dock expanding — no separate scale bounce needed.
    Behavior on width {
        enabled: true
        SpringAnimation {
            spring: root.notchSpringStiffness
            damping: root.notchSpringDamping
            mass: root.notchSpringMass
        }
    }
    Behavior on height {
        enabled: true
        SpringAnimation {
            spring: root.notchSpringStiffness
            damping: root.notchSpringDamping
            mass: root.notchSpringMass
        }
    }
    Behavior on radius {
        enabled: true
        SpringAnimation {
            spring: root.notchSpringStiffness
            damping: root.notchSpringDamping
            mass: root.notchSpringMass
        }
    }
    Behavior on anchors.topMargin {
        NumberAnimation {
            duration: root.batteryMode ? 250 : 400
            easing.type: Easing.OutExpo
        }
    }
    Behavior on opacity {
        NumberAnimation {
            // For top hugging style, opening and closing should be smooth to match GroundControl
            duration: root.batteryMode ? 150 : (root.topHuggingStyle ? 150 : (root.isAnyPopupOpen ? 150 : 50))
            easing.type: Easing.OutQuad
        }
    }

    SurfaceCard {
        id: notchRectBody
        anchors.fill: parent
        useShader: false
        cornerRadius: Math.round(4 * scaleFactor)
        zRadius: Math.round(4 * scaleFactor)
        contentPadding: 0
        clip: true
        
        // Click Clock/Pill in compact state to toggle GroundControl
        MouseArea {
            anchors.fill: parent
            enabled: root.islandState === root.stateCompact && !root.isAnyPopupOpen
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (root.togglePopup) root.togglePopup(root.groundControl);
                else root.groundControl.show = !root.groundControl.show;
            }
        }

        MouseArea {
            anchors.fill: parent
            // For minimized continuous pills: clicking body collapses to compact notch.
            // For maximized continuous card: clicking body collapses back to active pill version.
            enabled: root.islandState !== root.stateCompact
            onClicked: {
                if (notchRect.isContinuous && !notchRect.isMaximized) {
                    root.islandState = root.stateCompact;
                } else if (notchRect.isExpandedContinuous) {
                    notchRect.isMaximized = false;
                } else {
                    root.islandState = root.stateCompact;
                }
            }
        }

        RowLayout {
            id: notchLayout
            opacity: ((root.islandState === root.stateCompact && !root.isCenterPopupOpen) ? 1.0 : 0.0)
            visible: (root.islandState === root.stateCompact && !root.isCenterPopupOpen) || opacity > 0.001
            enabled: root.islandState === root.stateCompact && !root.isCenterPopupOpen
            scale: (root.islandState === root.stateCompact && !root.isCenterPopupOpen) ? 1.0 : 0.9
            Behavior on opacity {
                NumberAnimation {
                    duration: root.batteryMode ? 100 : 140
                    easing.type: Easing.OutQuad
                }
            }
            Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
            layer.enabled: (opacity > 0.0 && opacity < 1.0) && !root.batteryMode
            anchors.centerIn: parent
            height: parent.height
            spacing: Math.round(8 * scaleFactor)

            // DND Icon
            Text {
                text: "󰂛"
                color: root.colCrit
                font { family: root.iconFontFamily; pixelSize: Math.round(11 * fontScale) }
                visible: root.dndActive
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: visible ? implicitWidth : 0
                verticalAlignment: Text.AlignVCenter
            }

            // DND Separator Dot
            Text {
                text: "•"
                color: (root && root.glassMode === "apple_light") ? Qt.rgba(0, 0, 0, 0.3) : Qt.rgba(1, 1, 1, 0.3)
                font { family: root.fontFamily; pixelSize: Math.round(11 * fontScale) }
                visible: root.dndActive
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: visible ? implicitWidth : 0
                verticalAlignment: Text.AlignVCenter
            }

            // Clock Area (Clicks open GroundControl)
            MouseArea {
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: clockRow.implicitWidth
                implicitHeight: clockRow.implicitHeight
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (root.togglePopup) root.togglePopup(root.groundControl);
                    else root.groundControl.show = !root.groundControl.show;
                }

                RowLayout {
                    id: clockRow
                    spacing: Math.round(4 * scaleFactor)
                    anchors.verticalCenter: parent.verticalCenter

                    // Clock Icon
                    Text {
                        text: "󰥔"
                        color: (root && root.isPearlMode) ? root.colFgPrimary : root.colAccent
                        font { family: root.iconFontFamily; pixelSize: Math.round(11 * fontScale) }
                        Layout.alignment: Qt.AlignVCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    // Clock
                    Text {
                        id: clockText
                        text: Qt.formatTime(sysClock.date, "HH:mm")
                        color: root.colFg
                        font { family: root ? root.monoFontFamily : "Geist Mono"; pixelSize: Math.round(11 * fontScale); weight: Font.Bold; features: { "tnum": 1 } }
                        Layout.alignment: Qt.AlignVCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }

            // Separator Dot
            Text {
                text: "•"
                color: (root && root.isPearlMode) ? Qt.rgba(0, 0, 0, 0.3) : Qt.rgba(1, 1, 1, 0.3)
                font { family: root.textFontFamily; pixelSize: Math.round(11 * fontScale) }
                Layout.alignment: Qt.AlignVCenter
                verticalAlignment: Text.AlignVCenter
            }


            // Date Area (Clicks open Calendar Popup)
            MouseArea {
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: dateText.implicitWidth
                implicitHeight: dateText.implicitHeight
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (root.togglePopup) root.togglePopup(root.calendarPopup);
                    else root.calendarPopup.show = !root.calendarPopup.show;
                }

                Text {
                    id: dateText
                    anchors.centerIn: parent
                    text: Qt.formatDate(sysClock.date, "ddd, MMM d")
                    color: root.colFg
                    font { family: root.textFontFamily; pixelSize: Math.round(11 * fontScale); weight: Font.Medium }
                    verticalAlignment: Text.AlignVCenter
                }
            }

            // Separator Dot (Active Process Indicator)
            Text {
                text: "•"
                color: Qt.rgba(1, 1, 1, 0.3)
                font { family: root.fontFamily; pixelSize: Math.round(11 * fontScale) }
                visible: root.activeActivities.length > 0
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: visible ? implicitWidth : 0
            }

            // Active Process Badges Inline (Music, Timer, Stopwatch, Recording)
            RowLayout {
                spacing: Math.round(6 * scaleFactor)
                visible: root.activeActivities.length > 0
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: visible ? implicitWidth : 0

                Repeater {
                    model: root.activeActivities
                    delegate: MouseArea {
                        id: activeActBtn
                        width: actBadgeRect.width
                        height: Math.round(18 * scaleFactor)
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        property string act: modelData

                        onClicked: {
                            if (act === "media") { root.islandState = root.stateMedia; notchRect.isMaximized = false; }
                            else if (act === "timer") { root.islandState = root.stateTimer; notchRect.isMaximized = false; }
                            else if (act === "stopwatch") { root.islandState = root.stateStopwatch; notchRect.isMaximized = false; }
                            else if (act === "recording") { root.islandState = root.stateRecording; notchRect.isMaximized = false; }
                            else if (act === "pomodoro") { root.islandState = root.statePomodoro; notchRect.isMaximized = false; }
                        }

                        Rectangle {
                            id: actBadgeRect
                            width: actRow.implicitWidth + Math.round(10 * scaleFactor)
                            height: parent.height
                            radius: 2
                            // Teenage Engineering tactile micro-key frame
                            color: activeActBtn.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.06)
                            border.color: activeActBtn.containsMouse ? Qt.rgba(1, 1, 1, 0.25) : Qt.rgba(1, 1, 1, 0.12)
                            border.width: 1
                            transformOrigin: Item.Center
                            scale: activeActBtn.containsPress ? 0.94 : ((activeActBtn.containsMouse && root.bootSettled) ? 1.02 : 1.0)
                            Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutQuad } }

                            RowLayout {
                                id: actRow
                                anchors.centerIn: parent
                                spacing: Math.round(4 * scaleFactor)

                                // Square LED activity pip
                                Rectangle {
                                    width: Math.round(3 * scaleFactor)
                                    height: Math.round(3 * scaleFactor)
                                    radius: 0.5
                                    color: act === "media" ? root.colSpotify : (act === "recording" ? root.colCrit : (act === "pomodoro" ? "#EF4444" : (act === "comms" ? root.colAccentSecondary : root.colWarn)))
                                    Layout.alignment: Qt.AlignVCenter

                                    SequentialAnimation on opacity {
                                        loops: Animation.Infinite
                                        running: true
                                        NumberAnimation { to: 0.2; duration: 800; easing.type: Easing.InOutSine }
                                        NumberAnimation { to: 1.0; duration: 800; easing.type: Easing.InOutSine }
                                    }
                                }

                                Text {
                                    text: act === "media" ? "󰝚" : (act === "timer" ? "󰔛" : (act === "stopwatch" ? "󱎫" : (act === "pomodoro" ? "🍅" : (act === "comms" ? "󰍬" : "󰑊"))))
                                    color: act === "media" ? root.colSpotify : (act === "recording" ? root.colCrit : (act === "pomodoro" ? "#EF4444" : (act === "comms" ? root.colAccentSecondary : root.colWarn)))
                                    font {
                                        family: root.nerdFontFamily || root.iconFontFamily
                                        pixelSize: Math.round(10 * fontScale)
                                    }
                                    Layout.alignment: Qt.AlignVCenter
                                    verticalAlignment: Text.AlignVCenter
                                }

                                Text {
                                    text: {
                                        var raw = "";
                                        if (act === "media") {
                                            raw = (root.displayPlayerName !== "" ? root.displayPlayerName : "MPD");
                                        } else if (act === "timer") {
                                            raw = root.timerText;
                                        } else if (act === "stopwatch") {
                                            raw = root.stopwatchText;
                                        } else if (act === "pomodoro") {
                                            raw = root.pomodoroTimeStr;
                                        } else if (act === "recording") {
                                            raw = root.formatTime(root.recordingSeconds || 0);
                                        } else if (act === "comms") {
                                            raw = "MIC";
                                        }
                                        return raw.toUpperCase();
                                    }
                                    color: root.colFg
                                    font {
                                        family: root.monoFontFamily || "Geist Mono, monospace"
                                        pixelSize: Math.round(9 * fontScale)
                                        weight: Font.DemiBold
                                        features: { "tnum": 1 }
                                    }
                                    Layout.alignment: Qt.AlignVCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }
                        }
                    }
                }
            }
        }

        MouseArea {
            anchors.fill: mediaLayout
            visible: mediaLayout.visible && notchRect.isMaximized
            z: -1
            onClicked: notchRect.isMaximized = false
        }

        // ── 🎵 MEDIA AURA & SHARP COMET HEAD ─────────────────────────────
        Item {
            id: mediaAuraFill
            anchors.fill: parent
            z: 0
            opacity: ((root.islandState === root.stateMedia && !root.isCenterPopupOpen && (root.spotifyStatus === "playing" || root.spotifyPosition > 0)) ? 1.0 : 0.0)
            visible: opacity > 0.001
            Behavior on opacity {
                NumberAnimation {
                    duration: root.batteryMode ? 140 : 250
                    easing.type: Easing.OutQuad
                }
            }

            readonly property real trackProgress: (root && root.spotifyLength > 0)
                ? Math.min(1.0, Math.max(0.0, root.spotifyPosition / root.spotifyLength))
                : 0.0

            // Audio breathing pulse
            property real pulse: 0.0
            SequentialAnimation on pulse {
                running: root.islandState === root.stateMedia && root.spotifyStatus === "playing" && !root.batteryMode
                loops: Animation.Infinite
                NumberAnimation { to: 1.0; duration: 1800; easing.type: Easing.InOutSine }
                NumberAnimation { to: 0.0; duration: 1800; easing.type: Easing.InOutSine }
            }

            // Single Canvas: capsule-clipped, zero-bleed, strictly follows trackProgress
            Canvas {
                id: cometCanvas
                anchors.fill: parent
                visible: mediaAuraFill.trackProgress >= 0.0 && mediaAuraFill.trackProgress <= 1.0

                property real p: mediaAuraFill.trackProgress
                property real pulseVal: mediaAuraFill.pulse
                onPChanged: requestPaint()
                onPulseValChanged: requestPaint()

                onPaint: {
                    var ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);

                    var baseH = height;
                    var cr = Math.max(2.0, notchRect.radius);

                    // 1. Strict Rounded Rect Clipping matching notchRect.radius (ZERO bleeding outside chassis)
                    ctx.save();
                    ctx.beginPath();
                    ctx.moveTo(cr, 0);
                    ctx.lineTo(width - cr, 0);
                    ctx.arcTo(width, 0, width, cr, cr);
                    ctx.lineTo(width, baseH - cr);
                    ctx.arcTo(width, baseH, width - cr, baseH, cr);
                    ctx.lineTo(cr, baseH);
                    ctx.arcTo(0, baseH, 0, baseH - cr, cr);
                    ctx.lineTo(0, cr);
                    ctx.arcTo(0, 0, cr, 0, cr);
                    ctx.closePath();
                    ctx.clip();

                    // 2. Precise progress coordinate mapping from exact start (x = 0) to end (x = width)
                    var startX = 0;
                    var endX = width;
                    var headX = Math.round(startX + (endX - startX) * p);
                    var cometY = baseH - 2.0 * scaleFactor;
                    var tailLen = Math.min(headX - startX, 42 * scaleFactor);

                    // 3. Ambient Baseline Track along the entire bottom width
                    ctx.fillStyle = "rgba(255, 255, 255, 0.08)";
                    ctx.fillRect(0, baseH - 1.5 * scaleFactor, width, 1.5 * scaleFactor);

                    // 4. Upward Ambient Underglow along played section
                    if (headX > 0) {
                        var auraGrad = ctx.createLinearGradient(0, baseH - 7 * scaleFactor, 0, baseH);
                        auraGrad.addColorStop(0.0, "rgba(48, 209, 88, 0.0)");
                        auraGrad.addColorStop(0.5, "rgba(48, 209, 88, 0.06)");
                        auraGrad.addColorStop(1.0, "rgba(48, 209, 88, " + (0.24 + 0.08 * pulseVal) + ")");
                        ctx.fillStyle = auraGrad;
                        ctx.fillRect(0, baseH - 7 * scaleFactor, headX, 7 * scaleFactor);
                    }

                    // 5. Active Solid Seeker Line (Starts flush at x = 0)
                    if (headX > 0) {
                        ctx.fillStyle = "#30D158";
                        ctx.fillRect(0, baseH - 2.0 * scaleFactor, headX, 2.0 * scaleFactor);
                    }

                    // 6. Trailing Luminous Wake
                    if (tailLen > 2) {
                        var tailGrad = ctx.createLinearGradient(headX - tailLen, cometY, headX, cometY);
                        tailGrad.addColorStop(0.0, "rgba(48, 209, 88, 0.0)");
                        tailGrad.addColorStop(0.6, "rgba(48, 209, 88, 0.40)");
                        tailGrad.addColorStop(1.0, "rgba(52, 211, 153, 0.95)");

                        ctx.beginPath();
                        ctx.moveTo(headX - tailLen, cometY);
                        ctx.lineTo(headX - 5.0 * scaleFactor, cometY - 1.8 * scaleFactor);
                        ctx.lineTo(headX, cometY);
                        ctx.lineTo(headX - 5.0 * scaleFactor, cometY + 1.8 * scaleFactor);
                        ctx.closePath();
                        ctx.fillStyle = tailGrad;
                        ctx.fill();
                    }

                    // 7. Sharp Needle Tip Spark
                    if (p > 0.002 && p < 0.998) {
                        ctx.beginPath();
                        ctx.arc(headX, cometY, 1.5 * scaleFactor, 0, 2 * Math.PI);
                        ctx.fillStyle = "#FFFFFF";
                        ctx.shadowColor = "#30D158";
                        ctx.shadowBlur = 4 * scaleFactor;
                        ctx.fill();
                    }

                    ctx.restore();
                }
            }
        }

        // Compact Media Layout (32px Minimized Pill)
        RowLayout {
            id: mediaLayoutCompact
            z: 1
            opacity: ((root.islandState === root.stateMedia && !root.isCenterPopupOpen && !notchRect.isMaximized) ? 1.0 : 0.0)
            visible: (root.islandState === root.stateMedia && !root.isCenterPopupOpen && !notchRect.isMaximized) || opacity > 0.001
            enabled: root.islandState === root.stateMedia && !root.isCenterPopupOpen && !notchRect.isMaximized
            scale: opacity > 0.5 ? 1.0 : 0.92
            Behavior on opacity { NumberAnimation { duration: root.batteryMode ? 100 : 140; easing.type: Easing.OutQuad } }
            Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
            anchors.fill: parent
            anchors.leftMargin: Math.round(14 * scaleFactor)
            anchors.rightMargin: Math.round(14 * scaleFactor)
            spacing: Math.round(10 * scaleFactor)

            // Clickable Music Icon Badge (Click to expand)
            MouseArea {
                width: Math.round(18 * scaleFactor)
                height: Math.round(18 * scaleFactor)
                Layout.alignment: Qt.AlignVCenter
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: notchRect.isMaximized = true
                scale: containsPress ? 0.9 : (containsMouse ? 1.12 : 1.0)
                Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }

                Text {
                    anchors.centerIn: parent
                    text: "󰝚"
                    color: root.spotifyStatus === "playing" ? root.colSpotify : root.colFg
                    font {
                        family: root.nerdFontFamily || root.iconFontFamily
                        pixelSize: Math.round(13 * fontScale)
                    }
                }
            }

            // Marquee / Title Area (Click to collapse to compact notch)
            MouseArea {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                height: Math.round(20 * scaleFactor)
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.islandState = root.stateCompact

                Item {
                    id: tickerClip
                    anchors.fill: parent
                    clip: true

                    readonly property real rollGap: Math.round(48 * scaleFactor)
                    readonly property real singleTextW: tickerText1.implicitWidth
                    readonly property real cycleWidth: singleTextW + rollGap
                    readonly property bool needsScroll: singleTextW > (width - 4)
                    readonly property bool shouldRoll: needsScroll && (root.spotifyStatus === "playing") && !root.batteryMode

                    property real scrollOffset: 0

                    function resetRoll() {
                        rollAnim.stop();
                        initialPauseTimer.stop();
                        tickerClip.scrollOffset = 0;
                        if (shouldRoll) {
                            rollAnim.from = 0;
                            rollAnim.to = -tickerClip.cycleWidth;
                            rollAnim.duration = Math.max(1500, Math.round(tickerClip.cycleWidth * 34));
                            initialPauseTimer.restart();
                        }
                    }

                    onCycleWidthChanged: resetRoll()

                    Connections {
                        target: root
                        function onSpotifyStatusChanged() {
                            if (root.spotifyStatus !== "playing") {
                                rollAnim.stop();
                                initialPauseTimer.stop();
                                tickerClip.scrollOffset = 0;
                            } else {
                                tickerClip.resetRoll();
                            }
                        }
                        function onSpotifyTextChanged() {
                            tickerClip.resetRoll();
                        }
                        function onBatteryModeChanged() {
                            if (root.batteryMode) {
                                rollAnim.stop();
                                initialPauseTimer.stop();
                                tickerClip.scrollOffset = 0;
                            } else {
                                tickerClip.resetRoll();
                            }
                        }
                    }

                    onWidthChanged: {
                        if (!needsScroll) {
                            rollAnim.stop();
                            initialPauseTimer.stop();
                            scrollOffset = 0;
                        } else if (!rollAnim.running && shouldRoll && !initialPauseTimer.running) {
                            tickerClip.resetRoll();
                        }
                    }

                    Component.onCompleted: resetRoll()

                    Text {
                        id: tickerText1
                        anchors.verticalCenter: parent.verticalCenter
                        x: tickerClip.needsScroll
                            ? Math.round(tickerClip.scrollOffset)
                            : Math.round((tickerClip.width - implicitWidth) / 2)
                        text: root.spotifyText ? root.spotifyText : "No Title"
                        color: root.colFg
                        font {
                            family: root.monoFontFamily || root.fontFamily
                            pixelSize: Math.round(11 * fontScale)
                            weight: Font.Medium
                        }
                    }

                    Text {
                        id: tickerText2
                        anchors.verticalCenter: parent.verticalCenter
                        x: Math.round(tickerClip.scrollOffset + tickerClip.cycleWidth)
                        visible: tickerClip.needsScroll && tickerClip.scrollOffset < -5
                        text: tickerText1.text
                        color: tickerText1.color
                        font: tickerText1.font
                    }

                    NumberAnimation {
                        id: rollAnim
                        target: tickerClip
                        property: "scrollOffset"
                        from: 0
                        to: -tickerClip.cycleWidth
                        duration: Math.max(1500, Math.round(tickerClip.cycleWidth * 34))
                        loops: Animation.Infinite
                        easing.type: Easing.Linear
                    }

                    Timer {
                        id: initialPauseTimer
                        interval: 1400
                        repeat: false
                        onTriggered: {
                            if (tickerClip.shouldRoll) {
                                rollAnim.from = 0;
                                rollAnim.to = -tickerClip.cycleWidth;
                                rollAnim.duration = Math.max(1500, Math.round(tickerClip.cycleWidth * 34));
                                rollAnim.restart();
                            }
                        }
                    }
                }
            }

            // Quick Play/Pause
            MouseArea {
                id: compactPillPlayBtn
                width: Math.round(24 * scaleFactor)
                height: Math.round(24 * scaleFactor)
                Layout.alignment: Qt.AlignVCenter
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                scale: containsPress ? 0.88 : ((containsMouse && root.bootSettled) ? 1.12 : 1.0)
                Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
                onClicked: {
                    if (root.pSpotPlay) root.pSpotPlay.running = true;
                }

                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: parent.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
                    Behavior on color { ColorAnimation { duration: 100 } }
                }

                Text {
                    anchors.centerIn: parent
                    anchors.horizontalCenterOffset: root.spotifyStatus === "playing" ? 0 : 1
                    text: root.spotifyStatus === "playing" ? "󰏤" : "󰐊"
                    color: parent.containsMouse ? root.colSpotify : root.colFg
                    font {
                        family: root.nerdFontFamily || root.iconFontFamily
                        pixelSize: Math.round(14 * fontScale)
                    }
                }
            }
        }

        // Media Layout (Expanded 66px Floating Capsule)
        RowLayout {
            id: mediaLayout
            z: 1
            opacity: ((root.islandState === root.stateMedia && !root.isCenterPopupOpen && notchRect.isMaximized) ? 1.0 : 0.0)
            visible: (root.islandState === root.stateMedia && !root.isCenterPopupOpen && notchRect.isMaximized) || opacity > 0.001
            scale: (root.islandState === root.stateMedia && !root.isCenterPopupOpen && notchRect.isMaximized) ? 1.0 : 0.9
            Behavior on opacity {
                NumberAnimation {
                    duration: root.batteryMode ? 100 : 140
                    easing.type: Easing.OutQuad
                }
            }
            Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
            layer.enabled: (opacity > 0.0 && opacity < 1.0) && !root.batteryMode
            anchors.fill: parent
            anchors.leftMargin: Math.round(14 * scaleFactor)
            anchors.rightMargin: Math.round(12 * scaleFactor)
            spacing: Math.round(10 * scaleFactor)

            // Left: Album Art or Styled Music Badge
            Item {
                Layout.preferredWidth: Math.round(40 * scaleFactor)
                Layout.preferredHeight: Math.round(40 * scaleFactor)
                Layout.alignment: Qt.AlignVCenter

                Rectangle {
                    anchors.fill: parent
                    radius: Math.round(3 * scaleFactor)
                    color: Qt.rgba(0.11, 0.73, 0.33, 0.18)
                    border.color: Qt.rgba(0.11, 0.73, 0.33, 0.40)
                    border.width: 1.2
                    clip: true

                    Image {
                        anchors.fill: parent
                        source: (root.spotifyArtUrl && root.spotifyArtUrl.length > 8) ? root.spotifyArtUrl : ""
                        fillMode: Image.PreserveAspectCrop
                        visible: status === Image.Ready
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "󰝚"
                        color: root.colSpotify
                        font {
                            family: root.nerdFontFamily || root.iconFontFamily
                            pixelSize: Math.round(18 * fontScale)
                        }
                        visible: !(root.spotifyArtUrl && root.spotifyArtUrl.length > 8)
                    }

                    // Mini dancing visualizer bars overlay when playing
                    Row {
                        anchors.bottom: parent.bottom
                        anchors.right: parent.right
                        anchors.margins: 3
                        spacing: 2
                        visible: root.spotifyStatus === "playing" && !root.batteryMode

                        Repeater {
                            model: [0.6, 1.0, 0.4]
                            Rectangle {
                                width: 2
                                height: 8 * modelData
                                radius: 1
                                color: root.colSpotify
                                SequentialAnimation on height {
                                    loops: Animation.Infinite
                                    running: root.spotifyStatus === "playing"
                                    NumberAnimation { to: 8 * (1.2 - modelData); duration: 250 + index * 80; easing.type: Easing.InOutSine }
                                    NumberAnimation { to: 8 * modelData; duration: 250 + index * 80; easing.type: Easing.InOutSine }
                                }
                            }
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.audiophileMiniPlayer) root.audiophileMiniPlayer.visible = !root.audiophileMiniPlayer.visible;
                    }
                }
            }

            // Center: Track Title & Artist Typography
            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 2

                Text {
                    text: root.spotifyTitle ? root.spotifyTitle : (root.spotifyText ? root.spotifyText : "No Media")
                    color: root.colFg
                    font {
                        family: root.fontFamily
                        pixelSize: Math.round(12.5 * fontScale)
                        weight: Font.SemiBold
                    }
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                Text {
                    text: root.spotifyArtist ? root.spotifyArtist : (root.displayPlayerName ? root.displayPlayerName : "Now Playing")
                    color: root.colMuted
                    font {
                        family: root.textFontFamily
                        pixelSize: Math.round(10.5 * fontScale)
                    }
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }

            // Right: Playback Controls & Close Button
            RowLayout {
                spacing: Math.round(4 * scaleFactor)
                Layout.alignment: Qt.AlignVCenter

                // Prev Button
                MouseArea {
                    id: compactPrevBtn
                    Layout.preferredWidth: Math.round(26 * scaleFactor)
                    Layout.preferredHeight: Math.round(26 * scaleFactor)
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    scale: containsPress ? 0.88 : ((containsMouse && root.bootSettled) ? 1.12 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
                    onClicked: root.pSpotPrev.running = true

                    Rectangle {
                        anchors.fill: parent
                        radius: 2
                        color: parent.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.06)
                        border.color: parent.containsMouse ? Qt.rgba(1, 1, 1, 0.25) : Qt.rgba(1, 1, 1, 0.10)
                        border.width: 1
                    }
                    Text {
                        anchors.centerIn: parent
                        text: "󰒮"
                        color: parent.containsMouse ? root.colFg : root.colMuted
                        font { family: root.nerdFontFamily || root.iconFontFamily; pixelSize: Math.round(13 * fontScale) }
                    }
                }

                // Play/Pause Button
                MouseArea {
                    id: compactPlayBtn
                    Layout.preferredWidth: Math.round(30 * scaleFactor)
                    Layout.preferredHeight: Math.round(30 * scaleFactor)
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    scale: containsPress ? 0.88 : ((containsMouse && root.bootSettled) ? 1.10 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
                    onClicked: root.pSpotPlay.running = true

                    Rectangle {
                        anchors.fill: parent
                        radius: 2
                        color: parent.containsMouse ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(1, 1, 1, 0.10)
                        border.color: Qt.rgba(1, 1, 1, 0.22)
                        border.width: 1
                    }
                    Text {
                        anchors.centerIn: parent
                        anchors.horizontalCenterOffset: root.spotifyStatus === "playing" ? 0 : 1
                        text: root.spotifyStatus === "playing" ? "󰏤" : "󰐊"
                        color: root.colFg
                        font { family: root.nerdFontFamily || root.iconFontFamily; pixelSize: Math.round(14 * fontScale) }
                    }
                }

                // Next Button
                MouseArea {
                    id: compactNextBtn
                    Layout.preferredWidth: Math.round(26 * scaleFactor)
                    Layout.preferredHeight: Math.round(26 * scaleFactor)
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    scale: containsPress ? 0.88 : ((containsMouse && root.bootSettled) ? 1.12 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
                    onClicked: root.pSpotNext.running = true

                    Rectangle {
                        anchors.fill: parent
                        radius: 2
                        color: parent.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.06)
                        border.color: parent.containsMouse ? Qt.rgba(1, 1, 1, 0.25) : Qt.rgba(1, 1, 1, 0.10)
                        border.width: 1
                    }
                    Text {
                        anchors.centerIn: parent
                        text: "󰒭"
                        color: parent.containsMouse ? root.colFg : root.colMuted
                        font { family: root.nerdFontFamily || root.iconFontFamily; pixelSize: Math.round(13 * fontScale) }
                    }
                }

                // Close / Dismiss Button
                MouseArea {
                    Layout.preferredWidth: Math.round(24 * scaleFactor)
                    Layout.preferredHeight: Math.round(24 * scaleFactor)
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    scale: containsPress ? 0.88 : (containsMouse ? 1.08 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
                    onClicked: notchRect.isMaximized = false

                    Rectangle {
                        anchors.fill: parent
                        radius: 2
                        color: parent.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.06)
                        border.color: parent.containsMouse ? Qt.rgba(1, 1, 1, 0.25) : Qt.rgba(1, 1, 1, 0.10)
                        border.width: 1
                    }
                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        color: parent.containsMouse ? root.colFg : root.colMuted
                        font { family: root.fontFamily; pixelSize: Math.round(11 * fontScale); weight: Font.Medium }
                    }
                }
            }
        }

        MouseArea {
            anchors.fill: timerLayout
            visible: timerLayout.visible && notchRect.isMaximized
            z: -1
            onClicked: notchRect.isMaximized = false
        }

        // Compact Timer Layout (32px Minimized Pill)
        RowLayout {
            id: timerLayoutCompact
            opacity: ((root.islandState === root.stateTimer && !root.isCenterPopupOpen && !notchRect.isMaximized) ? 1.0 : 0.0)
            visible: (root.islandState === root.stateTimer && !root.isCenterPopupOpen && !notchRect.isMaximized) || opacity > 0.001
            enabled: root.islandState === root.stateTimer && !root.isCenterPopupOpen && !notchRect.isMaximized
            scale: opacity > 0.5 ? 1.0 : 0.92
            Behavior on opacity { NumberAnimation { duration: root.batteryMode ? 100 : 140; easing.type: Easing.OutQuad } }
            Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
            anchors.fill: parent
            anchors.leftMargin: Math.round(14 * scaleFactor)
            anchors.rightMargin: Math.round(14 * scaleFactor)
            spacing: Math.round(10 * scaleFactor)

            // Clickable Timer Icon Badge (Click to expand)
            MouseArea {
                width: Math.round(22 * scaleFactor)
                height: Math.round(22 * scaleFactor)
                Layout.alignment: Qt.AlignVCenter
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: notchRect.isMaximized = true
                scale: containsPress ? 0.9 : (containsMouse ? 1.12 : 1.0)
                Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }

                Text {
                    anchors.centerIn: parent
                    text: "󰔛"
                    color: root.timerRunning ? root.colWarn : root.colFg
                    font {
                        family: root.nerdFontFamily || root.iconFontFamily
                        pixelSize: Math.round(16 * fontScale)
                    }
                }
            }

            // Flexible spacer to push center content to middle
            Item { Layout.fillWidth: true }

            // Center Countdown (Berkeley Terminal Monospace Readout)
            MouseArea {
                implicitWidth: timerCompactLabel.implicitWidth
                implicitHeight: Math.round(22 * scaleFactor)
                Layout.alignment: Qt.AlignVCenter
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.islandState = root.stateCompact

                Text {
                    id: timerCompactLabel
                    anchors.centerIn: parent
                    text: "[ " + root.timerText + " ]"
                    color: root.timerRunning ? root.colWarn : root.colFg
                    font {
                        family: root.monoFontFamily || "Geist Mono, JetBrains Mono, monospace"
                        pixelSize: Math.round(13 * fontScale)
                        bold: true
                        features: { "tnum": 1 }
                    }
                }
            }

            // Right spacer to balance left icon
            Item { Layout.fillWidth: true }

            // Quick Play/Pause & Reset (Tactile Micro-Keys)
            RowLayout {
                spacing: Math.round(4 * scaleFactor)
                Layout.alignment: Qt.AlignVCenter

                MouseArea {
                    width: Math.round(24 * scaleFactor)
                    height: Math.round(22 * scaleFactor)
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    scale: containsPress ? 0.90 : (containsMouse ? 1.05 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 80; easing.type: Easing.OutCubic } }
                    onClicked: root.timerRunning = !root.timerRunning

                    Rectangle {
                        anchors.fill: parent
                        radius: 2
                        color: parent.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.06)
                        border.color: parent.containsMouse ? Qt.rgba(1, 1, 1, 0.25) : Qt.rgba(1, 1, 1, 0.10)
                        border.width: 1
                    }

                    Text {
                        anchors.centerIn: parent
                        text: root.timerRunning ? "󰏤" : "󰐊"
                        color: root.colFg
                        font { family: root.nerdFontFamily || root.iconFontFamily; pixelSize: Math.round(13 * fontScale) }
                    }
                }

                MouseArea {
                    width: Math.round(24 * scaleFactor)
                    height: Math.round(22 * scaleFactor)
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    scale: containsPress ? 0.90 : (containsMouse ? 1.05 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 80; easing.type: Easing.OutCubic } }
                    onClicked: {
                        root.timerRunning = false;
                        root.timerSeconds = root.timerTotal;
                        root.timerText = root.formatTime(root.timerTotal);
                        root.islandState = root.stateCompact;
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: 2
                        color: parent.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.06)
                        border.color: parent.containsMouse ? Qt.rgba(1, 1, 1, 0.25) : Qt.rgba(1, 1, 1, 0.10)
                        border.width: 1
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "󰜉"
                        color: root.colMuted
                        font { family: root.nerdFontFamily || root.iconFontFamily; pixelSize: Math.round(13 * fontScale) }
                    }
                }
            }
        }

        // Timer Layout (Expanded 66px Floating Capsule)
        RowLayout {
            id: timerLayout
            opacity: ((root.islandState === root.stateTimer && !root.isCenterPopupOpen && notchRect.isMaximized) ? 1.0 : 0.0)
            visible: (root.islandState === root.stateTimer && !root.isCenterPopupOpen && notchRect.isMaximized) || opacity > 0.001
            scale: (root.islandState === root.stateTimer && !root.isCenterPopupOpen && notchRect.isMaximized) ? 1.0 : 0.9
            Behavior on opacity {
                NumberAnimation {
                    duration: root.batteryMode ? 100 : 140
                    easing.type: Easing.OutQuad
                }
            }
            Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
            anchors.fill: parent
            anchors.leftMargin: Math.round(14 * scaleFactor)
            anchors.rightMargin: Math.round(12 * scaleFactor)
            spacing: Math.round(12 * scaleFactor)

            // Left: Timer Icon Badge
            Item {
                Layout.preferredWidth: Math.round(40 * scaleFactor)
                Layout.preferredHeight: Math.round(40 * scaleFactor)
                Layout.alignment: Qt.AlignVCenter

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: Qt.rgba(1.0, 0.62, 0.04, 0.20)
                    border.color: Qt.rgba(1.0, 0.62, 0.04, 0.45)
                    border.width: 1.2

                    Text {
                        anchors.centerIn: parent
                        text: "󰔛"
                        color: root.colWarn
                        font {
                            family: root.nerdFontFamily || root.iconFontFamily
                            pixelSize: Math.round(18 * fontScale)
                        }
                        transformOrigin: Item.Center

                        SequentialAnimation on rotation {
                            loops: Animation.Infinite
                            running: root.timerRunning && !root.batteryMode
                            NumberAnimation { from: 0; to: -14; duration: 150; easing.type: Easing.InOutQuad }
                            NumberAnimation { from: -14; to: 14; duration: 300; easing.type: Easing.InOutQuad }
                            NumberAnimation { from: 14; to: 0; duration: 150; easing.type: Easing.InOutQuad }
                            PauseAnimation { duration: 500 }
                        }
                    }
                }
            }

            // Center: Two-line Typography
            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 1

                Text {
                    text: root.timerText
                    color: root.colFg
                    font {
                        family: root.fontFamily
                        pixelSize: Math.round(17 * fontScale)
                        bold: true
                        features: { "tnum": 1 }
                    }
                }

                Text {
                    text: root.timerRunning ? "Timer counting down…" : "Timer paused"
                    color: root.colMuted
                    font {
                        family: root.textFontFamily
                        pixelSize: Math.round(10.5 * fontScale)
                    }
                }
            }

            // Right: Play/Pause, Reset, Close
            RowLayout {
                spacing: Math.round(6 * scaleFactor)
                Layout.alignment: Qt.AlignVCenter

                // Play / Pause Toggle
                MouseArea {
                    Layout.preferredWidth: Math.round(30 * scaleFactor)
                    Layout.preferredHeight: Math.round(30 * scaleFactor)
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    scale: containsPress ? 0.88 : ((containsMouse && root.bootSettled) ? 1.10 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
                    onClicked: root.timerRunning = !root.timerRunning

                    Rectangle {
                        anchors.fill: parent
                        radius: height / 2
                        color: root.timerRunning ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1.0, 0.62, 0.04, 0.25)
                        border.color: root.timerRunning ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(1.0, 0.62, 0.04, 0.50)
                        border.width: 1
                    }
                    Text {
                        anchors.centerIn: parent
                        anchors.horizontalCenterOffset: root.timerRunning ? 0 : 1
                        text: root.timerRunning ? "󰏤" : "󰐊"
                        color: root.timerRunning ? root.colFg : root.colWarn
                        font {
                            family: root.nerdFontFamily || root.iconFontFamily
                            pixelSize: Math.round(14 * fontScale)
                        }
                    }
                }

                // Reset Button
                MouseArea {
                    Layout.preferredWidth: Math.round(26 * scaleFactor)
                    Layout.preferredHeight: Math.round(26 * scaleFactor)
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    scale: containsPress ? 0.88 : ((containsMouse && root.bootSettled) ? 1.12 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
                    onClicked: {
                        root.timerRunning = false;
                        root.timerSeconds = root.timerTotal;
                        root.timerText = root.formatTime(root.timerTotal);
                        root.islandState = root.stateCompact;
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: height / 2
                        color: parent.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
                    }
                    Text {
                        anchors.centerIn: parent
                        text: "󰜉"
                        color: parent.containsMouse ? root.colFg : root.colMuted
                        font {
                            family: root.nerdFontFamily || root.iconFontFamily
                            pixelSize: Math.round(14 * fontScale)
                        }
                    }
                }

                // Close Button
                MouseArea {
                    Layout.preferredWidth: Math.round(24 * scaleFactor)
                    Layout.preferredHeight: Math.round(24 * scaleFactor)
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    scale: containsPress ? 0.88 : (containsMouse ? 1.08 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
                    onClicked: notchRect.isMaximized = false

                    Rectangle {
                        anchors.fill: parent
                        radius: height / 2
                        color: parent.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : "transparent"
                    }
                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        color: parent.containsMouse ? root.colFg : root.colMuted
                        font { family: root.fontFamily; pixelSize: Math.round(11 * fontScale); weight: Font.Medium }
                    }
                }
            }
        }

        MouseArea {
            anchors.fill: stopwatchLayout
            visible: stopwatchLayout.visible && notchRect.isMaximized
            z: -1
            onClicked: notchRect.isMaximized = false
        }

        // Compact Stopwatch Layout (32px Minimized Pill)
        RowLayout {
            id: stopwatchLayoutCompact
            opacity: ((root.islandState === root.stateStopwatch && !root.isCenterPopupOpen && !notchRect.isMaximized) ? 1.0 : 0.0)
            visible: (root.islandState === root.stateStopwatch && !root.isCenterPopupOpen && !notchRect.isMaximized) || opacity > 0.001
            enabled: root.islandState === root.stateStopwatch && !root.isCenterPopupOpen && !notchRect.isMaximized
            scale: opacity > 0.5 ? 1.0 : 0.92
            Behavior on opacity { NumberAnimation { duration: root.batteryMode ? 100 : 140; easing.type: Easing.OutQuad } }
            Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
            anchors.fill: parent
            anchors.leftMargin: Math.round(14 * scaleFactor)
            anchors.rightMargin: Math.round(14 * scaleFactor)
            spacing: Math.round(10 * scaleFactor)

            // Clickable Stopwatch Icon Badge (Click to expand)
            MouseArea {
                width: Math.round(22 * scaleFactor)
                height: Math.round(22 * scaleFactor)
                Layout.alignment: Qt.AlignVCenter
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: notchRect.isMaximized = true
                scale: containsPress ? 0.9 : (containsMouse ? 1.12 : 1.0)
                Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }

                Text {
                    anchors.centerIn: parent
                    text: "󱎫"
                    color: root.stopwatchRunning ? root.colWarn : root.colFg
                    font {
                        family: root.nerdFontFamily || root.iconFontFamily
                        pixelSize: Math.round(16 * fontScale)
                    }
                }
            }

            // Balanced left spacer
            Item { Layout.fillWidth: true }

            // Center Stopwatch Readout (Berkeley Terminal Monospace Readout)
            MouseArea {
                implicitWidth: swCompactLabel.implicitWidth
                implicitHeight: Math.round(22 * scaleFactor)
                Layout.alignment: Qt.AlignVCenter
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.islandState = root.stateCompact

                Text {
                    id: swCompactLabel
                    anchors.centerIn: parent
                    text: "[ " + root.stopwatchText + " ]"
                    color: root.stopwatchRunning ? root.colWarn : root.colFg
                    font {
                        family: root.monoFontFamily || "Geist Mono, JetBrains Mono, monospace"
                        pixelSize: Math.round(13 * fontScale)
                        bold: true
                        features: { "tnum": 1 }
                    }
                }
            }

            // Balanced right spacer
            Item { Layout.fillWidth: true }

            // Quick Play/Pause & Reset (Tactile Micro-Keys)
            RowLayout {
                spacing: Math.round(4 * scaleFactor)
                Layout.alignment: Qt.AlignVCenter

                MouseArea {
                    width: Math.round(24 * scaleFactor)
                    height: Math.round(22 * scaleFactor)
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    scale: containsPress ? 0.90 : (containsMouse ? 1.05 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 80; easing.type: Easing.OutCubic } }
                    onClicked: root.stopwatchRunning = !root.stopwatchRunning

                    Rectangle {
                        anchors.fill: parent
                        radius: 2
                        color: parent.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.06)
                        border.color: parent.containsMouse ? Qt.rgba(1, 1, 1, 0.25) : Qt.rgba(1, 1, 1, 0.10)
                        border.width: 1
                    }

                    Text {
                        anchors.centerIn: parent
                        text: root.stopwatchRunning ? "󰏤" : "󰐊"
                        color: root.colFg
                        font { family: root.nerdFontFamily || root.iconFontFamily; pixelSize: Math.round(13 * fontScale) }
                    }
                }

                MouseArea {
                    width: Math.round(24 * scaleFactor)
                    height: Math.round(22 * scaleFactor)
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    scale: containsPress ? 0.90 : (containsMouse ? 1.05 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 80; easing.type: Easing.OutCubic } }
                    onClicked: {
                        root.stopwatchRunning = false;
                        root.stopwatchSeconds = 0;
                        root.stopwatchText = "00:00";
                        root.islandState = root.stateCompact;
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: 2
                        color: parent.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.06)
                        border.color: parent.containsMouse ? Qt.rgba(1, 1, 1, 0.25) : Qt.rgba(1, 1, 1, 0.10)
                        border.width: 1
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "󰜉"
                        color: root.colMuted
                        font { family: root.nerdFontFamily || root.iconFontFamily; pixelSize: Math.round(13 * fontScale) }
                    }
                }
            }
        }

        // Stopwatch Layout (Expanded 66px Floating Capsule)
        RowLayout {
            id: stopwatchLayout
            opacity: ((root.islandState === root.stateStopwatch && !root.isCenterPopupOpen && notchRect.isMaximized) ? 1.0 : 0.0)
            visible: (root.islandState === root.stateStopwatch && !root.isCenterPopupOpen && notchRect.isMaximized) || opacity > 0.001
            scale: (root.islandState === root.stateStopwatch && !root.isCenterPopupOpen && notchRect.isMaximized) ? 1.0 : 0.9
            Behavior on opacity {
                NumberAnimation {
                    duration: root.batteryMode ? 100 : 140
                    easing.type: Easing.OutQuad
                }
            }
            Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
            anchors.fill: parent
            anchors.leftMargin: Math.round(14 * scaleFactor)
            anchors.rightMargin: Math.round(12 * scaleFactor)
            spacing: Math.round(12 * scaleFactor)

            // Left: Stopwatch Icon Badge
            Item {
                Layout.preferredWidth: Math.round(40 * scaleFactor)
                Layout.preferredHeight: Math.round(40 * scaleFactor)
                Layout.alignment: Qt.AlignVCenter

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: Qt.rgba(0.04, 0.52, 1.0, 0.20)
                    border.color: Qt.rgba(0.04, 0.52, 1.0, 0.45)
                    border.width: 1.2

                    Text {
                        anchors.centerIn: parent
                        text: "󱎫"
                        color: root.colAccent
                        font {
                            family: root.nerdFontFamily || root.iconFontFamily
                            pixelSize: Math.round(18 * fontScale)
                        }
                    }
                }
            }

            // Center: Two-line Typography
            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 1

                Text {
                    text: root.stopwatchText
                    color: root.colFg
                    font {
                        family: root.fontFamily
                        pixelSize: Math.round(17 * fontScale)
                        bold: true
                        features: { "tnum": 1 }
                    }
                }

                Text {
                    text: root.stopwatchRunning ? "Stopwatch running" : "Stopwatch paused"
                    color: root.colMuted
                    font {
                        family: root.textFontFamily
                        pixelSize: Math.round(10.5 * fontScale)
                    }
                }
            }

            // Right: Play/Pause, Reset, Close
            RowLayout {
                spacing: Math.round(6 * scaleFactor)
                Layout.alignment: Qt.AlignVCenter

                // Play / Pause Toggle
                MouseArea {
                    Layout.preferredWidth: Math.round(30 * scaleFactor)
                    Layout.preferredHeight: Math.round(30 * scaleFactor)
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    scale: containsPress ? 0.88 : ((containsMouse && root.bootSettled) ? 1.10 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
                    onClicked: root.stopwatchRunning = !root.stopwatchRunning

                    Rectangle {
                        anchors.fill: parent
                        radius: height / 2
                        color: root.stopwatchRunning ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(0.04, 0.52, 1.0, 0.25)
                        border.color: root.stopwatchRunning ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(0.04, 0.52, 1.0, 0.50)
                        border.width: 1
                    }
                    Text {
                        anchors.centerIn: parent
                        anchors.horizontalCenterOffset: root.stopwatchRunning ? 0 : 1
                        text: root.stopwatchRunning ? "󰏤" : "󰐊"
                        color: root.stopwatchRunning ? root.colFg : root.colAccent
                        font {
                            family: root.nerdFontFamily || root.iconFontFamily
                            pixelSize: Math.round(14 * fontScale)
                        }
                    }
                }

                // Reset Button
                MouseArea {
                    Layout.preferredWidth: Math.round(26 * scaleFactor)
                    Layout.preferredHeight: Math.round(26 * scaleFactor)
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    scale: containsPress ? 0.88 : ((containsMouse && root.bootSettled) ? 1.12 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
                    onClicked: {
                        root.stopwatchRunning = false;
                        root.stopwatchSeconds = 0;
                        root.stopwatchText = "00:00";
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: height / 2
                        color: parent.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
                    }
                    Text {
                        anchors.centerIn: parent
                        text: "󰜉"
                        color: parent.containsMouse ? root.colFg : root.colMuted
                        font {
                            family: root.nerdFontFamily || root.iconFontFamily
                            pixelSize: Math.round(14 * fontScale)
                        }
                    }
                }

                // Close Button
                MouseArea {
                    Layout.preferredWidth: Math.round(24 * scaleFactor)
                    Layout.preferredHeight: Math.round(24 * scaleFactor)
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    scale: containsPress ? 0.88 : (containsMouse ? 1.08 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
                    onClicked: notchRect.isMaximized = false

                    Rectangle {
                        anchors.fill: parent
                        radius: height / 2
                        color: parent.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : "transparent"
                    }
                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        color: parent.containsMouse ? root.colFg : root.colMuted
                        font { family: root.fontFamily; pixelSize: Math.round(11 * fontScale); weight: Font.Medium }
                    }
                }
            }
        }

        MouseArea {
            anchors.fill: recordingLayout
            visible: recordingLayout.visible && notchRect.isMaximized
            z: -1
            onClicked: notchRect.isMaximized = false
        }

        // Compact Recording Layout (32px Minimized Pill)
        RowLayout {
            id: recordingLayoutCompact
            opacity: ((root.islandState === root.stateRecording && !root.isCenterPopupOpen && !notchRect.isMaximized) ? 1.0 : 0.0)
            visible: (root.islandState === root.stateRecording && !root.isCenterPopupOpen && !notchRect.isMaximized) || opacity > 0.001
            enabled: root.islandState === root.stateRecording && !root.isCenterPopupOpen && !notchRect.isMaximized
            scale: opacity > 0.5 ? 1.0 : 0.92
            Behavior on opacity { NumberAnimation { duration: root.batteryMode ? 100 : 140; easing.type: Easing.OutQuad } }
            Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
            anchors.fill: parent
            anchors.leftMargin: Math.round(14 * scaleFactor)
            anchors.rightMargin: Math.round(14 * scaleFactor)
            spacing: Math.round(10 * scaleFactor)

            // Clickable REC dot badge (Click to expand)
            MouseArea {
                width: Math.round(20 * scaleFactor)
                height: Math.round(20 * scaleFactor)
                Layout.alignment: Qt.AlignVCenter
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: notchRect.isMaximized = true

                Item {
                    anchors.centerIn: parent
                    width: Math.round(10 * scaleFactor)
                    height: Math.round(10 * scaleFactor)

                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width
                        height: parent.height
                        radius: width / 2
                        color: "transparent"
                        border.color: "#EF4444"
                        border.width: 1
                        ParallelAnimation on scale {
                            loops: Animation.Infinite
                            running: root.islandState === root.stateRecording && !root.batteryMode
                            NumberAnimation { from: 1.0; to: 2.2; duration: 1600; easing.type: Easing.OutQuad }
                        }
                        ParallelAnimation on opacity {
                            loops: Animation.Infinite
                            running: root.islandState === root.stateRecording && !root.batteryMode
                            NumberAnimation { from: 0.8; to: 0.0; duration: 1600; easing.type: Easing.OutQuad }
                        }
                    }
                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: "#EF4444"
                    }
                }
            }

            // Balanced left spacer
            Item { Layout.fillWidth: true }

            // Time Readout (Click to collapse to compact notch)
            MouseArea {
                implicitWidth: recCompactRow.implicitWidth
                implicitHeight: Math.round(22 * scaleFactor)
                Layout.alignment: Qt.AlignVCenter
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.islandState = root.stateCompact

                RowLayout {
                    id: recCompactRow
                    anchors.centerIn: parent
                    spacing: Math.round(4 * scaleFactor)

                    Text {
                        text: "[ REC │ " + root.recordingTime + " ]"
                        color: "#FF453A"
                        font {
                            family: root.monoFontFamily || "Geist Mono, JetBrains Mono, monospace"
                            pixelSize: Math.round(11 * fontScale)
                            bold: true
                            features: { "tnum": 1 }
                        }
                    }
                }
            }

            // Balanced right spacer
            Item { Layout.fillWidth: true }

            // Quick Stop Button (Tactile micro-key)
            MouseArea {
                width: Math.round(24 * scaleFactor)
                height: Math.round(22 * scaleFactor)
                Layout.alignment: Qt.AlignVCenter
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                scale: containsPress ? 0.90 : (containsMouse ? 1.05 : 1.0)
                Behavior on scale { NumberAnimation { duration: 80; easing.type: Easing.OutCubic } }
                onClicked: {
                    root.pStopRecord.running = true;
                    root.isRecording = false;
                    root.recordingTimer.stop();
                    root.recordingSeconds = 0;
                    root.recordingTime = "0:00";
                    root.islandState = root.stateCompact;
                }

                Rectangle {
                    anchors.fill: parent
                    radius: 2
                    color: parent.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.06)
                    border.color: parent.containsMouse ? Qt.rgba(1, 1, 1, 0.25) : Qt.rgba(1, 1, 1, 0.10)
                    border.width: 1
                }

                Text {
                    anchors.centerIn: parent
                    text: "󰓛"
                    color: "#FF453A"
                    font { family: root.nerdFontFamily || root.iconFontFamily; pixelSize: Math.round(13 * fontScale) }
                }
            }
        }

        // Recording Layout (Expanded 66px Floating Capsule)
        RowLayout {
            id: recordingLayout
            opacity: ((root.islandState === root.stateRecording && !root.isCenterPopupOpen && notchRect.isMaximized) ? 1.0 : 0.0)
            visible: (root.islandState === root.stateRecording && !root.isCenterPopupOpen && notchRect.isMaximized) || opacity > 0.001
            scale: (root.islandState === root.stateRecording && !root.isCenterPopupOpen && notchRect.isMaximized) ? 1.0 : 0.9
            Behavior on opacity {
                NumberAnimation {
                    duration: root.batteryMode ? 100 : 140
                    easing.type: Easing.OutQuad
                }
            }
            Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
            anchors.fill: parent
            anchors.leftMargin: Math.round(14 * scaleFactor)
            anchors.rightMargin: Math.round(12 * scaleFactor)
            spacing: Math.round(12 * scaleFactor)

            // Left: Recording Radar Badge
            Item {
                Layout.preferredWidth: Math.round(40 * scaleFactor)
                Layout.preferredHeight: Math.round(40 * scaleFactor)
                Layout.alignment: Qt.AlignVCenter

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: Qt.rgba(0.94, 0.27, 0.27, 0.20)
                    border.color: Qt.rgba(0.94, 0.27, 0.27, 0.45)
                    border.width: 1.2

                    // Pulsing radar ring
                    Rectangle {
                        anchors.centerIn: parent
                        width: 14
                        height: 14
                        radius: 7
                        color: "transparent"
                        border.color: "#EF4444"
                        border.width: 1.2
                        ParallelAnimation on scale {
                            loops: Animation.Infinite
                            running: root.islandState === root.stateRecording && !root.batteryMode
                            NumberAnimation { from: 1.0; to: 2.2; duration: 1400; easing.type: Easing.OutQuad }
                        }
                        ParallelAnimation on opacity {
                            loops: Animation.Infinite
                            running: root.islandState === root.stateRecording && !root.batteryMode
                            NumberAnimation { from: 0.8; to: 0.0; duration: 1400; easing.type: Easing.OutQuad }
                        }
                    }

                    // Core red dot
                    Rectangle {
                        anchors.centerIn: parent
                        width: 10
                        height: 10
                        radius: 5
                        color: "#EF4444"
                        SequentialAnimation on opacity {
                            loops: Animation.Infinite
                            running: root.islandState === root.stateRecording
                            NumberAnimation { from: 1.0; to: 0.35; duration: 700; easing.type: Easing.InOutQuad }
                            NumberAnimation { from: 0.35; to: 1.0; duration: 700; easing.type: Easing.InOutQuad }
                        }
                    }
                }
            }

            // Center: Two-line Typography
            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 1

                Text {
                    text: root.recordingTime
                    color: "#EF4444"
                    font {
                        family: root.fontFamily
                        pixelSize: Math.round(17 * fontScale)
                        bold: true
                        features: { "tnum": 1 }
                    }
                }

                Text {
                    text: "Screen Recording"
                    color: root.colMuted
                    font {
                        family: root.textFontFamily
                        pixelSize: Math.round(10.5 * fontScale)
                    }
                }
            }

            // Right: Stop Pill Button & Close
            RowLayout {
                spacing: Math.round(6 * scaleFactor)
                Layout.alignment: Qt.AlignVCenter

                // Stop Pill Button
                MouseArea {
                    Layout.preferredWidth: Math.round(68 * scaleFactor)
                    Layout.preferredHeight: Math.round(28 * scaleFactor)
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    scale: containsPress ? 0.92 : (containsMouse ? 1.04 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
                    onClicked: {
                        root.pStopRecord.running = true;
                        root.isRecording = false;
                        root.recordingTimer.stop();
                        root.recordingSeconds = 0;
                        root.recordingTime = "0:00";
                        root.islandState = root.stateCompact;
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: height / 2
                        color: parent.containsMouse ? Qt.rgba(0.94, 0.27, 0.27, 0.35) : Qt.rgba(0.94, 0.27, 0.27, 0.20)
                        border.color: Qt.rgba(0.94, 0.27, 0.27, 0.55)
                        border.width: 1
                    }

                    Row {
                        anchors.centerIn: parent
                        spacing: 4
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "󰓛"
                            color: "#EF4444"
                            font { family: root.nerdFontFamily || root.iconFontFamily; pixelSize: Math.round(11 * fontScale) }
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Stop"
                            color: "#EF4444"
                            font { family: root.fontFamily; pixelSize: Math.round(11 * fontScale); weight: Font.SemiBold }
                        }
                    }
                }

                // Close Button
                MouseArea {
                    Layout.preferredWidth: Math.round(24 * scaleFactor)
                    Layout.preferredHeight: Math.round(24 * scaleFactor)
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    scale: containsPress ? 0.88 : (containsMouse ? 1.08 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
                    onClicked: notchRect.isMaximized = false

                    Rectangle {
                        anchors.fill: parent
                        radius: height / 2
                        color: parent.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : "transparent"
                    }
                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        color: parent.containsMouse ? root.colFg : root.colMuted
                        font { family: root.fontFamily; pixelSize: Math.round(11 * fontScale); weight: Font.Medium }
                    }
                }
            }
        }

        // ── LIQUID-FILL OSD BACKGROUND ──────────────────────────────
        Canvas {
            id: osdLiquidCanvas
            anchors.fill: parent
            clip: true
            visible: root.islandState === root.stateOsd && !root.isCenterPopupOpen

            property real fillRatio: root.osdValue / 100
            property real wavePhase: 0.0
            property real waveAmp: 3.0 * scaleFactor   // wave amplitude in px

            onFillRatioChanged: requestPaint()
            onWavePhaseChanged: requestPaint()

            Behavior on fillRatio {
                NumberAnimation {
                    duration: 300
                    easing.type: Easing.OutCubic
                }
            }

            // Continuous wave ticker
            NumberAnimation on wavePhase {
                running: root.islandState === root.stateOsd && !root.batteryMode
                loops: Animation.Infinite
                from: 0
                to: Math.PI * 2
                duration: 1400
                easing.type: Easing.Linear
            }

            onPaint: {
                var ctx = getContext("2d");
                ctx.reset();

                var w = width;
                var h = height;
                var fillX = w * fillRatio;
                var amp = waveAmp;
                var r = notchRect.radius;

                // Clipping rounded rect path (matches notchRect)
                ctx.beginPath();
                ctx.moveTo(r, 0);
                ctx.lineTo(w - r, 0);
                ctx.quadraticCurveTo(w, 0, w, r);
                ctx.lineTo(w, h - r);
                ctx.quadraticCurveTo(w, h, w - r, h);
                ctx.lineTo(r, h);
                ctx.quadraticCurveTo(0, h, 0, h - r);
                ctx.lineTo(0, r);
                ctx.quadraticCurveTo(0, 0, r, 0);
                ctx.closePath();
                ctx.clip();

                // Fill from x = 0 to x = fillX with vertical meniscus wave
                ctx.beginPath();
                ctx.moveTo(0, 0);

                var steps = Math.ceil(h);
                for (var i = 0; i <= steps; i++) {
                    var py = i;
                    var wave = Math.sin(wavePhase + (py / h) * Math.PI * 2) * amp;
                    var px = fillX + wave;
                    ctx.lineTo(px, py);
                }
                ctx.lineTo(0, h);
                ctx.closePath();

                // Glassmorphic translucent gradient fill
                var grad = ctx.createLinearGradient(0, 0, fillX, 0);
                grad.addColorStop(0, Qt.rgba(1, 1, 1, 0.18).toString());
                grad.addColorStop(1.0, Qt.rgba(1, 1, 1, 0.32).toString());
                ctx.fillStyle = grad;
                ctx.fill();

                // Bright sheen line at wave crest
                ctx.beginPath();
                for (var j = 0; j <= steps; j++) {
                    var qy = j;
                    var qwave = Math.sin(wavePhase + (qy / h) * Math.PI * 2) * amp;
                    var qx = fillX + qwave;
                    if (j === 0)
                        ctx.moveTo(qx, qy);
                    else
                        ctx.lineTo(qx, qy);
                }
                ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.75).toString();
                ctx.lineWidth = 1.8;
                ctx.stroke();
            }
        }

        MouseArea {
            anchors.fill: osdLayout
            visible: osdLayout.visible
            z: -1
            onClicked: root.islandState = root.stateCompact
        }

        // OSD Layout
        RowLayout {
            id: osdLayout
            opacity: ((root.islandState === root.stateOsd && !root.isCenterPopupOpen) ? 1.0 : 0.0)
            visible: (root.islandState === root.stateOsd && !root.isCenterPopupOpen) || opacity > 0.001
            scale: (root.islandState === root.stateOsd && !root.isCenterPopupOpen) ? 1.0 : 0.9
            Behavior on opacity {
                NumberAnimation {
                    duration: root.batteryMode ? 100 : 140
                    easing.type: Easing.OutQuad
                }
            }
            Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            spacing: 10

            Text {
                text: root.osdIcon
                color: root.colFg
                font {
                    family: root.iconFontFamily
                    pixelSize: 15
                }
                Layout.alignment: Qt.AlignVCenter
            }

            // Spacer filling the middle area so icon/text float at left/right edges
            Item {
                Layout.fillWidth: true
                height: 1
            }

            Text {
                text: root.osdText
                color: root.colFg
                font {
                    family: root.fontFamily
                    pixelSize: 11
                    bold: true
                }
                Layout.alignment: Qt.AlignVCenter
                Layout.minimumWidth: 28
                horizontalAlignment: Text.AlignRight
            }
        }

        RowLayout {
            id: lowBatLayout
            opacity: ((root.islandState === root.stateBatteryLow && !root.isCenterPopupOpen) ? 1.0 : 0.0)
            visible: (root.islandState === root.stateBatteryLow && !root.isCenterPopupOpen) || opacity > 0.001
            scale: (root.islandState === root.stateBatteryLow && !root.isCenterPopupOpen) ? 1.0 : 0.9
            Behavior on opacity {
                NumberAnimation {
                    duration: root.batteryMode ? 100 : 140
                    easing.type: Easing.OutQuad
                }
            }
            Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            spacing: 0

            Text {
                text: "󰂃"
                color: root.colCrit
                font {
                    family: root.iconFontFamily
                    pixelSize: 15
                }
                Layout.alignment: Qt.AlignVCenter
            }
            Item {
                Layout.fillWidth: true
            }
            Text {
                text: "Battery Low (" + root.batteryCap + "%)"
                color: root.colFg
                font {
                    family: root.fontFamily
                    pixelSize: 12
                    bold: true
                }
                Layout.alignment: Qt.AlignVCenter
            }
        }

        // Charging alert pill
        RowLayout {
            id: chargingLayout
            opacity: ((root.islandState === root.stateCharging && !root.isCenterPopupOpen) ? 1.0 : 0.0)
            visible: (root.islandState === root.stateCharging && !root.isCenterPopupOpen) || opacity > 0.001
            scale: (root.islandState === root.stateCharging && !root.isCenterPopupOpen) ? 1.0 : 0.9
            Behavior on opacity {
                NumberAnimation {
                    duration: root.batteryMode ? 100 : 140
                    easing.type: Easing.OutQuad
                }
            }
            Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            spacing: 0

            Text {
                text: ""
                color: "#76B900"
                font {
                    family: root.iconFontFamily
                    pixelSize: 15
                }
                Layout.alignment: Qt.AlignVCenter
            }
            Item {
                Layout.fillWidth: true
            }
            Text {
                text: "Charging (" + root.batteryCap + "%)"
                color: root.colFg
                font {
                    family: root.fontFamily
                    pixelSize: 12
                    bold: true
                }
                Layout.alignment: Qt.AlignVCenter
            }
        }

        // DND Alert Pill
        RowLayout {
            id: dndLayout
            opacity: ((root.islandState === root.stateDnd && !root.isCenterPopupOpen) ? 1.0 : 0.0)
            visible: (root.islandState === root.stateDnd && !root.isCenterPopupOpen) || opacity > 0.001
            scale: (root.islandState === root.stateDnd && !root.isCenterPopupOpen) ? 1.0 : 0.9
            Behavior on opacity {
                NumberAnimation {
                    duration: root.batteryMode ? 100 : 140
                    easing.type: Easing.OutQuad
                }
            }
            Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            spacing: 0

            Item {
                id: dndIconContainer
                Layout.preferredWidth: Math.round(16 * root.scaleFactor)
                Layout.preferredHeight: Math.round(16 * root.scaleFactor)
                Layout.alignment: Qt.AlignVCenter

                Text {
                    anchors.centerIn: parent
                    text: root.dndActive ? "󰂛" : "󰂚"
                    color: root.dndActive ? "#E02424" : root.colFg
                    font {
                        family: root.iconFontFamily
                        pixelSize: Math.round(15 * root.scaleFactor)
                    }
                }

                // Sleepy "Zzz" floating particles
                Repeater {
                    model: (root.dndActive && !root.batteryMode && root.islandState === root.stateDnd) ? 3 : 0
                    delegate: Text {
                        id: zParticle
                        text: index === 0 ? "z" : (index === 1 ? "Z" : "z")
                        font {
                            family: root.fontFamily
                            pixelSize: Math.round((index === 1 ? 8 : 6) * root.scaleFactor)
                            bold: index === 1
                        }
                        color: "#FFCC00"
                        opacity: 0.0
                        x: Math.round((8 + (index - 1) * 6) * root.scaleFactor)
                        y: Math.round(8 * root.scaleFactor)

                        SequentialAnimation on y {
                            running: root.dndActive && !root.batteryMode && root.islandState === root.stateDnd
                            loops: Animation.Infinite

                            PauseAnimation {
                                duration: index * 600
                            }
                            ParallelAnimation {
                                NumberAnimation {
                                    from: Math.round(8 * root.scaleFactor)
                                    to: Math.round(-16 * root.scaleFactor)
                                    duration: 1500
                                    easing.type: Easing.OutQuad
                                }
                                NumberAnimation {
                                    from: zParticle.x
                                    to: zParticle.x + Math.round((index === 0 ? -6 : (index === 2 ? 6 : 0)) * root.scaleFactor)
                                    duration: 1500
                                    target: zParticle
                                    property: "x"
                                }
                                NumberAnimation {
                                    target: zParticle
                                    property: "opacity"
                                    from: 0.7
                                    to: 0.0
                                    duration: 1500
                                }
                            }
                            PropertyAction {
                                target: zParticle
                                property: "opacity"
                                value: 0.0
                            }
                        }
                    }
                }
            }
            Item {
                Layout.fillWidth: true
            }
            Text {
                text: root.dndActive ? "Do Not Disturb" : "Notifications Enabled"
                color: root.colFg
                font {
                    family: root.fontFamily
                    pixelSize: 12
                    bold: true
                }
                Layout.alignment: Qt.AlignVCenter
            }
        }

        MouseArea {
            anchors.fill: pomodoroLayout
            visible: pomodoroLayout.visible && notchRect.isMaximized
            z: -1
            onClicked: notchRect.isMaximized = false
        }

        // Compact Pomodoro Layout (32px Minimized Pill)
        RowLayout {
            id: pomodoroLayoutCompact
            opacity: ((root.islandState === root.statePomodoro && !root.isCenterPopupOpen && !notchRect.isMaximized) ? 1.0 : 0.0)
            visible: (root.islandState === root.statePomodoro && !root.isCenterPopupOpen && !notchRect.isMaximized) || opacity > 0.001
            enabled: root.islandState === root.statePomodoro && !root.isCenterPopupOpen && !notchRect.isMaximized
            scale: opacity > 0.5 ? 1.0 : 0.92
            Behavior on opacity { NumberAnimation { duration: root.batteryMode ? 100 : 140; easing.type: Easing.OutQuad } }
            Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
            anchors.fill: parent
            anchors.leftMargin: Math.round(14 * scaleFactor)
            anchors.rightMargin: Math.round(14 * scaleFactor)
            spacing: Math.round(8 * scaleFactor)

            // Clickable Tomato Icon Badge (Click to expand)
            MouseArea {
                width: Math.round(22 * scaleFactor)
                height: Math.round(22 * scaleFactor)
                Layout.alignment: Qt.AlignVCenter
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: notchRect.isMaximized = true
                scale: containsPress ? 0.9 : (containsMouse ? 1.12 : 1.0)
                Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }

                Text {
                    anchors.centerIn: parent
                    text: root.pomodoroMode === "focus" ? "🍅" : (root.pomodoroMode === "short_break" ? "☕" : "🌿")
                    font.pixelSize: Math.round(14 * fontScale)
                }
            }

            // Balanced left spacer
            Item { Layout.fillWidth: true }

            // Center Metrics (Click to collapse to compact notch)
            MouseArea {
                implicitWidth: pomCompactRow.implicitWidth
                implicitHeight: Math.round(24 * scaleFactor)
                Layout.alignment: Qt.AlignVCenter
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.islandState = root.stateCompact

                RowLayout {
                    id: pomCompactRow
                    anchors.centerIn: parent
                    spacing: Math.round(5 * scaleFactor)

                    Text {
                        text: root.pomodoroMode === "focus" ? "Focus" : "Break"
                        color: root.pomodoroMode === "focus" ? "#FF6B6B" : "#38BDF8"
                        font { family: root.fontFamily; pixelSize: Math.round(11 * fontScale); bold: true }
                    }
                    Text {
                        text: "•"
                        color: Qt.rgba(1, 1, 1, 0.4)
                        font { family: root.fontFamily; pixelSize: Math.round(9 * fontScale) }
                    }
                    Text {
                        text: root.pomodoroTimeStr
                        color: root.colFg
                        font { family: root.fontFamily; pixelSize: Math.round(12 * fontScale); bold: true; features: { "tnum": 1 } }
                    }
                }
            }

            // Balanced right spacer
            Item { Layout.fillWidth: true }

            // Quick Play/Pause & Exit
            RowLayout {
                spacing: Math.round(6 * scaleFactor)
                Layout.alignment: Qt.AlignVCenter

                MouseArea {
                    width: Math.round(22 * scaleFactor)
                    height: Math.round(22 * scaleFactor)
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    scale: containsPress ? 0.88 : (containsMouse ? 1.12 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
                    onClicked: root.togglePomodoro()

                    Text {
                        anchors.centerIn: parent
                        text: root.pomodoroRunning ? "󰏤" : "󰐊"
                        color: root.colFg
                        font { family: root.nerdFontFamily || root.iconFontFamily; pixelSize: Math.round(14 * fontScale) }
                    }
                }

                MouseArea {
                    width: Math.round(20 * scaleFactor)
                    height: Math.round(20 * scaleFactor)
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    scale: containsPress ? 0.88 : (containsMouse ? 1.12 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
                    onClicked: root.exitPomodoro()

                    Text {
                        anchors.centerIn: parent
                        text: "󰅖"
                        color: parent.containsMouse ? "#EF4444" : root.colMuted
                        font { family: root.nerdFontFamily || root.iconFontFamily; pixelSize: Math.round(12 * fontScale) }
                    }
                }
            }
        }

        // Pomodoro Deep-Work Layout (Expanded 66px Floating Capsule)
        RowLayout {
            id: pomodoroLayout
            opacity: ((root.islandState === root.statePomodoro && !root.isCenterPopupOpen && notchRect.isMaximized) ? 1.0 : 0.0)
            visible: (root.islandState === root.statePomodoro && !root.isCenterPopupOpen && notchRect.isMaximized) || opacity > 0.001
            scale: (root.islandState === root.statePomodoro && !root.isCenterPopupOpen && notchRect.isMaximized) ? 1.0 : 0.9
            Behavior on opacity {
                NumberAnimation {
                    duration: root.batteryMode ? 100 : 140
                    easing.type: Easing.OutQuad
                }
            }
            Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
            anchors.fill: parent
            anchors.leftMargin: Math.round(14 * scaleFactor)
            anchors.rightMargin: Math.round(12 * scaleFactor)
            spacing: Math.round(12 * scaleFactor)

            // Left: Focus Mode Badge
            Item {
                Layout.preferredWidth: Math.round(40 * scaleFactor)
                Layout.preferredHeight: Math.round(40 * scaleFactor)
                Layout.alignment: Qt.AlignVCenter

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: root.pomodoroMode === "focus" ? Qt.rgba(0.94, 0.27, 0.27, 0.20) : Qt.rgba(0.22, 0.74, 0.97, 0.20)
                    border.color: root.pomodoroMode === "focus" ? Qt.rgba(0.94, 0.27, 0.27, 0.45) : Qt.rgba(0.22, 0.74, 0.97, 0.45)
                    border.width: 1.2

                    Text {
                        anchors.centerIn: parent
                        text: root.pomodoroMode === "focus" ? "🍅" : (root.pomodoroMode === "short_break" ? "☕" : "🌿")
                        font.pixelSize: Math.round(18 * fontScale)
                    }
                }
            }

            // Center: Two-line Typography
            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 1

                Text {
                    text: root.pomodoroTimeStr
                    color: root.pomodoroMode === "focus" ? "#FF6B6B" : "#38BDF8"
                    font {
                        family: root.fontFamily
                        pixelSize: Math.round(17 * fontScale)
                        bold: true
                        features: { "tnum": 1 }
                    }
                }

                Text {
                    text: (root.pomodoroTitle || "Focus Session") + (root.pomodoroRunning ? " • Active" : " • Paused")
                    color: root.colMuted
                    font {
                        family: root.textFontFamily
                        pixelSize: Math.round(10.5 * fontScale)
                    }
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }

            // Right: Pause/Start, Skip, Exit, Close
            RowLayout {
                spacing: Math.round(6 * scaleFactor)
                Layout.alignment: Qt.AlignVCenter

                // Play / Pause Toggle Button
                MouseArea {
                    Layout.preferredWidth: Math.round(56 * scaleFactor)
                    Layout.preferredHeight: Math.round(28 * scaleFactor)
                    Layout.alignment: Qt.AlignVCenter
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    scale: containsPress ? 0.92 : (containsMouse ? 1.04 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }

                    Rectangle {
                        anchors.fill: parent
                        color: root.pomodoroRunning
                            ? (parent.containsMouse ? Qt.rgba(1, 0.42, 0.42, 0.35) : Qt.rgba(1, 0.42, 0.42, 0.20))
                            : (parent.containsMouse ? Qt.rgba(0.2, 0.8, 0.3, 0.35) : Qt.rgba(0.2, 0.8, 0.3, 0.20))
                        radius: height / 2
                        border.color: root.pomodoroRunning ? Qt.rgba(1, 0.42, 0.42, 0.5) : Qt.rgba(0.2, 0.8, 0.3, 0.5)
                        border.width: 1
                    }
                    Text {
                        anchors.centerIn: parent
                        text: root.pomodoroRunning ? "Pause" : "Start"
                        color: "#FFFFFF"
                        font { family: root.fontFamily; pixelSize: Math.round(10 * fontScale); weight: Font.SemiBold }
                    }
                    onClicked: root.togglePomodoro()
                }

                // Skip Button
                MouseArea {
                    Layout.preferredWidth: Math.round(26 * scaleFactor)
                    Layout.preferredHeight: Math.round(26 * scaleFactor)
                    Layout.alignment: Qt.AlignVCenter
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    scale: containsPress ? 0.88 : (containsMouse ? 1.10 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }

                    Rectangle {
                        anchors.fill: parent
                        radius: height / 2
                        color: parent.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : "transparent"
                    }
                    Text {
                        anchors.centerIn: parent
                        text: "󰒭"
                        color: parent.containsMouse ? root.colFg : root.colMuted
                        font { family: root.nerdFontFamily || root.iconFontFamily; pixelSize: Math.round(13 * fontScale) }
                    }
                    onClicked: root.skipPomodoro()
                }

                // Close / Dismiss Button
                MouseArea {
                    Layout.preferredWidth: Math.round(24 * scaleFactor)
                    Layout.preferredHeight: Math.round(24 * scaleFactor)
                    Layout.alignment: Qt.AlignVCenter
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    scale: containsPress ? 0.88 : (containsMouse ? 1.08 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
                    onClicked: notchRect.isMaximized = false

                    Rectangle {
                        anchors.fill: parent
                        radius: height / 2
                        color: parent.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : "transparent"
                    }
                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        color: parent.containsMouse ? root.colFg : root.colMuted
                        font { family: root.fontFamily; pixelSize: Math.round(11 * fontScale); weight: Font.Medium }
                    }
                }
            }
        }

        // F1 Alert Pill
        RowLayout {
            id: f1Layout
            opacity: ((root.islandState === root.stateF1Alert && !root.isCenterPopupOpen) ? 1.0 : 0.0)
            visible: (root.islandState === root.stateF1Alert && !root.isCenterPopupOpen) || opacity > 0.001
            scale: (root.islandState === root.stateF1Alert && !root.isCenterPopupOpen) ? 1.0 : 0.9
            Behavior on opacity {
                NumberAnimation {
                    duration: root.batteryMode ? 100 : 140
                    easing.type: Easing.OutQuad
                }
            }
            Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            spacing: 8

            Item {
                id: f1IconContainer
                Layout.preferredWidth: 16
                Layout.preferredHeight: 16
                Layout.alignment: Qt.AlignVCenter

                Text {
                    id: f1Icon
                    anchors.centerIn: parent
                    text: "󰞹"
                    color: "#E10600"
                    font {
                        family: root.iconFontFamily
                        pixelSize: 15
                    }

                    transform: Translate {
                        id: f1Translate
                    }

                    SequentialAnimation {
                        running: (root.islandState === 12 && !root.batteryMode)
                        loops: Animation.Infinite

                        NumberAnimation {
                            target: f1Translate
                            property: "x"
                            from: 0
                            to: -2
                            duration: 40
                            easing.type: Easing.Linear
                        }
                        NumberAnimation {
                            target: f1Translate
                            property: "x"
                            from: -2
                            to: 2
                            duration: 80
                            easing.type: Easing.Linear
                        }
                        NumberAnimation {
                            target: f1Translate
                            property: "x"
                            from: 2
                            to: 0
                            duration: 40
                            easing.type: Easing.Linear
                        }
                        PauseAnimation {
                            duration: 100
                        }

                        NumberAnimation {
                            target: f1Translate
                            property: "x"
                            from: 0
                            to: -1
                            duration: 30
                            easing.type: Easing.Linear
                        }
                        NumberAnimation {
                            target: f1Translate
                            property: "x"
                            from: -1
                            to: 1
                            duration: 60
                            easing.type: Easing.Linear
                        }
                        NumberAnimation {
                            target: f1Translate
                            property: "x"
                            from: 1
                            to: 0
                            duration: 30
                            easing.type: Easing.Linear
                        }
                        PauseAnimation {
                            duration: 800
                        }
                    }
                }
            }
            Text {
                text: root.f1AlertName !== "" ? root.f1AlertName + " in " + root.f1AlertMins + "m!" : "F1 Session Starting!"
                color: "#E10600"
                font {
                    family: root.fontFamily
                    pixelSize: 11
                    bold: true
                }
                Layout.alignment: Qt.AlignVCenter
                Layout.fillWidth: true
                elide: Text.ElideRight
            }
            MouseArea {
                width: 50
                height: 24
                Layout.alignment: Qt.AlignVCenter
                hoverEnabled: true
                Rectangle {
                    anchors.fill: parent
                    color: parent.containsMouse ? Qt.rgba(0.88, 0.02, 0.0, 0.2) : Qt.rgba(0.88, 0.02, 0.0, 0.1)
                    radius: 12
                    border.color: Qt.rgba(0.88, 0.02, 0.0, 0.3)
                    border.width: 1
                }
                Text {
                    anchors.centerIn: parent
                    text: "Dismiss"
                    color: "#E10600"
                    font {
                        family: root.fontFamily
                        pixelSize: 10
                        bold: true
                    }
                }
                onClicked: {
                    root.islandState = root.prevIslandState;
                }
            }
        }

        // CPU Hot Alert Pill
        RowLayout {
            id: cpuLayout
            opacity: ((root.islandState === root.stateCpuAlert && !root.isCenterPopupOpen) ? 1.0 : 0.0)
            visible: (root.islandState === root.stateCpuAlert && !root.isCenterPopupOpen) || opacity > 0.001
            scale: (root.islandState === root.stateCpuAlert && !root.isCenterPopupOpen) ? 1.0 : 0.9
            Behavior on opacity {
                NumberAnimation {
                    duration: root.batteryMode ? 100 : 140
                    easing.type: Easing.OutQuad
                }
            }
            Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            spacing: 8

            Text {
                text: "󰈸"
                color: "#FFA500"
                font {
                    family: root.iconFontFamily
                    pixelSize: 15
                }
                Layout.alignment: Qt.AlignVCenter
            }
            Text {
                text: root.temperature + "°C | Top: " + (root.topCpuProcess !== "" ? root.topCpuProcess : "Loading...")
                color: "#FFA500"
                font {
                    family: root.fontFamily
                    pixelSize: 10
                    bold: true
                }
                Layout.alignment: Qt.AlignVCenter
                Layout.fillWidth: true
                elide: Text.ElideRight
            }
            MouseArea {
                width: 50
                height: 24
                Layout.alignment: Qt.AlignVCenter
                hoverEnabled: true
                Rectangle {
                    anchors.fill: parent
                    color: parent.containsMouse ? Qt.rgba(1.0, 0.65, 0.0, 0.2) : Qt.rgba(1.0, 0.65, 0.0, 0.1)
                    radius: 12
                    border.color: Qt.rgba(1.0, 0.65, 0.0, 0.3)
                    border.width: 1
                }
                Text {
                    anchors.centerIn: parent
                    text: "Dismiss"
                    color: "#FFA500"
                    font {
                        family: root.fontFamily
                        pixelSize: 10
                        bold: true
                    }
                }
                onClicked: {
                    root.islandState = root.prevIslandState;
                }
            }
        }

        // Disk / USB Plugged Alert Pill (stateDiskAlert: 17) — single line
        RowLayout {
            id: diskAlertLayout
            opacity: ((root.islandState === root.stateDiskAlert && !root.isCenterPopupOpen) ? 1.0 : 0.0)
            visible: (root.islandState === root.stateDiskAlert && !root.isCenterPopupOpen) || opacity > 0.001
            scale: (root.islandState === root.stateDiskAlert && !root.isCenterPopupOpen) ? 1.0 : 0.9
            Behavior on opacity {
                NumberAnimation {
                    duration: root.batteryMode ? 100 : 140
                    easing.type: Easing.OutQuad
                }
            }
            Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            spacing: 7

            // Device icon (Phone / Bluetooth / USB Storage)
            Text {
                text: {
                    if (root.diskAlertType === "phone") {
                        return root.diskAlertMounted ? "󰄡" : "󰄢";
                    } else if (root.diskAlertType === "bluetooth") {
                        return root.diskAlertMounted ? "󰂯" : "󰂲";
                    } else {
                        return root.diskAlertMounted ? "󰋊" : "󱊞";
                    }
                }
                color: {
                    if (!root.diskAlertMounted) return "#FFA500";
                    if (root.diskAlertType === "phone") return "#0A84FF";
                    if (root.diskAlertType === "bluetooth") return "#5E5CE6";
                    return "#76B900";
                }
                font {
                    family: root.iconFontFamily
                    pixelSize: 13
                }
                Layout.alignment: Qt.AlignVCenter
            }

            // Device name — fills remaining space, truncates with ellipsis
            Text {
                text: root.diskAlertTitle !== "" ? root.diskAlertTitle : (root.diskAlertType === "phone" ? "Mobile Device" : (root.diskAlertType === "bluetooth" ? "Bluetooth Device" : "USB Drive"))
                color: root.colFg
                font {
                    family: root.fontFamily
                    pixelSize: 10
                    bold: true
                }
                elide: Text.ElideRight
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
            }

            // Separator dot
            Text {
                text: "·"
                color: root.colMuted
                font {
                    family: root.fontFamily
                    pixelSize: 10
                }
                Layout.alignment: Qt.AlignVCenter
            }

            // Status label — fixed width, never truncated
            Text {
                text: {
                    if (!root.diskAlertMounted) return "Disconnected";
                    if (root.diskAlertSubtitle !== "") return root.diskAlertSubtitle;
                    return "Connected";
                }
                color: {
                    if (!root.diskAlertMounted) return "#FFA500";
                    if (root.diskAlertType === "phone") return "#0A84FF";
                    if (root.diskAlertType === "bluetooth") return "#5E5CE6";
                    return "#76B900";
                }
                font {
                    family: root.fontFamily
                    pixelSize: 10
                    bold: true
                }
                Layout.alignment: Qt.AlignVCenter
            }
        }

        // Click device alert pill to mount/open device or open settings
        MouseArea {
            anchors.fill: parent
            enabled: root.islandState === root.stateDiskAlert && !root.isAnyPopupOpen
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (root.diskAlertMounted) {
                    if (root.diskAlertType === "bluetooth") {
                        root.togglePopup(root.bluetoothMenuPopup);
                    } else if (root.diskAlertType === "phone") {
                        root.pMountAndOpen.command = ["bash", root.scriptsDir + "/mount_and_open.sh", "--phone", root.diskAlertDev, root.diskAlertTitle];
                        root.pMountAndOpen.running = true;
                    } else if (root.diskAlertDev !== "") {
                        root.pMountAndOpen.command = ["bash", root.scriptsDir + "/mount_and_open.sh", root.diskAlertDev];
                        root.pMountAndOpen.running = true;
                    } else {
                        root.pMountAndOpen.command = ["thunar"];
                        root.pMountAndOpen.running = true;
                    }
                }
                root.islandState = root.stateCompact;
            }
        }

        // Shell Nudge Pill (stateNudge: 19) — Premium Ambient Liquid Glass
        Item {
            id: nudgeLayout
            opacity: ((root.islandState === root.stateNudge && !root.isCenterPopupOpen) ? 1.0 : 0.0)
            visible: (root.islandState === root.stateNudge && !root.isCenterPopupOpen) || opacity > 0.001
            scale: (root.islandState === root.stateNudge && !root.isCenterPopupOpen) ? 1.0 : 0.94
            anchors.fill: parent

            readonly property color accentColor: root.nudgeAccentColor || "#89B4FA"

            Behavior on opacity {
                NumberAnimation { duration: root.batteryMode ? 120 : 180; easing.type: Easing.OutQuad }
            }
            Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }

            // Ambient inner glow reflecting category accent
            Rectangle {
                anchors.fill: parent
                radius: notchRectBody.cornerRadius
                color: nudgeLayout.accentColor
                opacity: 0.09
                z: 0
            }

            // Hover guard: pause auto-dismiss countdown on hover
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onEntered: root.pauseNudgeTimer()
                onExited: root.resumeNudgeTimer()
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Math.round(12 * scaleFactor)
                anchors.rightMargin: Math.round(12 * scaleFactor)
                spacing: Math.round(10 * scaleFactor)
                z: 1

                // 1. Grokbot Character Mascot inside Frosted Orb
                Rectangle {
                    Layout.preferredWidth: Math.round(34 * scaleFactor)
                    Layout.preferredHeight: Math.round(34 * scaleFactor)
                    Layout.alignment: Qt.AlignVCenter
                    radius: width / 2
                    color: Qt.rgba(1, 1, 1, 0.08)
                    border.color: Qt.rgba(1, 1, 1, 0.16)
                    border.width: 1

                    Character {
                        id: nudgeGrokbot
                        anchors.centerIn: parent
                        size: Math.round(24 * scaleFactor)
                        active: root.islandState === root.stateNudge && !root.isCenterPopupOpen
                        sphereColor: (root && root.minimoBotMode === "light")
                            ? "#FFFFFF"
                            : ((root && root.isPearlMode) ? "#202022" : "#121214")
                        eyeColor: (root && root.minimoBotMode === "light")
                            ? "#121215"
                            : ((root && root.isPearlMode) ? "#FFFFFF" : "#F5F5F7")
                    }

                    Connections {
                        target: root
                        function onIslandStateChanged() {
                            if (root.islandState === root.stateNudge) {
                                nudgeGrokbot.react("curious");
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: (mouse) => nudgeGrokbot.clicked(mouse.x > width / 2 ? 1 : -1)
                    }
                }

                // 2. Icon Badge Squircle
                Rectangle {
                    Layout.preferredWidth: Math.round(30 * scaleFactor)
                    Layout.preferredHeight: Math.round(30 * scaleFactor)
                    Layout.alignment: Qt.AlignVCenter
                    radius: Math.round(9 * scaleFactor)
                    color: Qt.rgba(nudgeLayout.accentColor.r, nudgeLayout.accentColor.g, nudgeLayout.accentColor.b, 0.18)
                    border.color: Qt.rgba(nudgeLayout.accentColor.r, nudgeLayout.accentColor.g, nudgeLayout.accentColor.b, 0.45)
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: root.nudgeIcon || "󰐊"
                        color: nudgeLayout.accentColor
                        font {
                            family: root.iconFontFamily
                            pixelSize: Math.round(15 * fontScale)
                        }
                    }
                }

                // 3. Central Title & Subtitle Stack with Category Tag
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 2

                    RowLayout {
                        spacing: Math.round(6 * scaleFactor)
                        Layout.fillWidth: true

                        // Category Micro Tag
                        Rectangle {
                            height: Math.round(14 * scaleFactor)
                            width: catText.implicitWidth + Math.round(8 * scaleFactor)
                            radius: Math.round(3 * scaleFactor)
                            color: Qt.rgba(nudgeLayout.accentColor.r, nudgeLayout.accentColor.g, nudgeLayout.accentColor.b, 0.22)
                            border.color: Qt.rgba(nudgeLayout.accentColor.r, nudgeLayout.accentColor.g, nudgeLayout.accentColor.b, 0.5)
                            border.width: 1
                            Layout.alignment: Qt.AlignVCenter

                            Text {
                                id: catText
                                anchors.centerIn: parent
                                text: root.nudgeCategory || "NOW NUDGE"
                                color: nudgeLayout.accentColor
                                font {
                                    family: root.fontFamily
                                    pixelSize: Math.round(8 * fontScale)
                                    bold: true
                                    capitalization: Font.AllUppercase
                                }
                            }
                        }

                        Text {
                            text: root.nudgeTitle || "Action Detected"
                            color: "#FFFFFF"
                            font {
                                family: root.fontFamily
                                pixelSize: Math.round(12 * fontScale)
                                bold: true
                            }
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }
                    }

                    Text {
                        visible: root.nudgeSubtitle !== ""
                        text: root.nudgeSubtitle
                        color: Qt.rgba(1, 1, 1, 0.72)
                        font {
                            family: root.fontFamily
                            pixelSize: Math.round(10 * fontScale)
                        }
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }
                }

                // 4. Action Button with Gradient Pill & Keyboard Enter Badge
                MouseArea {
                    id: btnNudgeAction
                    visible: root.nudgeActionCmd !== ""
                    implicitWidth: nudgeActionRow.implicitWidth + Math.round(22 * scaleFactor)
                    implicitHeight: Math.round(28 * scaleFactor)
                    Layout.alignment: Qt.AlignVCenter
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor

                    Rectangle {
                        anchors.fill: parent
                        radius: height / 2
                        color: parent.containsMouse
                            ? Qt.rgba(nudgeLayout.accentColor.r, nudgeLayout.accentColor.g, nudgeLayout.accentColor.b, 0.32)
                            : Qt.rgba(nudgeLayout.accentColor.r, nudgeLayout.accentColor.g, nudgeLayout.accentColor.b, 0.18)
                        border.color: parent.containsMouse 
                            ? nudgeLayout.accentColor 
                            : Qt.rgba(1, 1, 1, 0.25)
                        border.width: parent.containsMouse ? 1.5 : 1

                        scale: parent.pressed ? 0.95 : (parent.containsMouse ? 1.04 : 1.0)
                        Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
                        Behavior on color { ColorAnimation { duration: 140 } }
                        Behavior on border.color { ColorAnimation { duration: 140 } }

                        RowLayout {
                            id: nudgeActionRow
                            anchors.centerIn: parent
                            spacing: Math.round(6 * scaleFactor)

                            Text {
                                text: root.nudgeActionLabel || "Run"
                                color: "#FFFFFF"
                                font {
                                    family: root.fontFamily
                                    pixelSize: Math.round(11 * fontScale)
                                    bold: true
                                }
                            }

                            // Shortcut hint badge [↵]
                            Rectangle {
                                width: Math.round(16 * scaleFactor)
                                height: Math.round(14 * scaleFactor)
                                radius: Math.round(3 * scaleFactor)
                                color: Qt.rgba(1, 1, 1, 0.20)
                                border.color: Qt.rgba(1, 1, 1, 0.35)
                                border.width: 1
                                Layout.alignment: Qt.AlignVCenter

                                Text {
                                    anchors.centerIn: parent
                                    text: "↵"
                                    color: "#FFFFFF"
                                    font {
                                        pixelSize: Math.round(9 * fontScale)
                                        bold: true
                                    }
                                }
                            }
                        }
                    }

                    onClicked: {
                        nudgeGrokbot.react("happyBounce");
                        root.executeNudgeAction();
                    }
                }

                // 5. Dismiss Button
                MouseArea {
                    id: btnNudgeDismiss
                    Layout.preferredWidth: Math.round(26 * scaleFactor)
                    Layout.preferredHeight: Math.round(26 * scaleFactor)
                    Layout.alignment: Qt.AlignVCenter
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor

                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: parent.containsMouse ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(1, 1, 1, 0.08)
                        border.color: parent.containsMouse ? Qt.rgba(1, 1, 1, 0.35) : Qt.rgba(1, 1, 1, 0.12)
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "✕"
                            color: parent.parent.containsMouse ? "#FFFFFF" : Qt.rgba(1, 1, 1, 0.55)
                            font {
                                family: root.fontFamily
                                pixelSize: Math.round(10 * fontScale)
                                bold: true
                            }
                            rotation: parent.parent.containsMouse ? 90 : 0
                            Behavior on rotation { NumberAnimation { duration: 180; easing.type: Easing.OutQuad } }
                        }
                    }

                    onClicked: {
                        root.dismissNudgeAlert();
                    }
                }
            }

            // 6. Glowing Countdown Line at the Bottom with Rounded Caps
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Math.round(2 * scaleFactor)
                anchors.left: parent.left
                anchors.leftMargin: Math.round(12 * scaleFactor)
                height: Math.round(2.5 * scaleFactor)
                width: Math.max(0, (parent.width - Math.round(24 * scaleFactor)) * root.nudgeProgress)
                color: nudgeLayout.accentColor
                opacity: root.nudgePaused ? 0.45 : 0.90
                radius: height / 2
                Behavior on opacity { NumberAnimation { duration: 150 } }
            }
        }
    }


    // LocalSend Drag & Drop Layout
    Item {
        id: localSendDragLayout
        // Stays visible whenever in a LocalSend state — avoids layout destroy/create during transition
        visible: root.islandState === root.stateDragLocalSend || root.islandState === root.stateLocalSendSuccess
        width: implicitWidth
        height: implicitHeight
        anchors.centerIn: parent
        implicitWidth: lsDragRow.implicitWidth
        implicitHeight: lsDragRow.implicitHeight
        layer.enabled: true
        z: 20

        property real slideY: 10 * scaleFactor
        property real contentOpacity: 0.0

        transform: Translate { y: localSendDragLayout.slideY }
        opacity: localSendDragLayout.contentOpacity

        Behavior on slideY {
            NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
        }
        Behavior on contentOpacity {
            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
        }

        Connections {
            target: root
            function onIslandStateChanged() {
                if (root.islandState === root.stateDragLocalSend) {
                    // Reset to below-position, then slide up after the pill opens
                    localSendDragLayout.slideY = 10 * scaleFactor;
                    localSendDragLayout.contentOpacity = 0.0;
                    lsDragShowTimer.restart();
                } else {
                    lsDragShowTimer.stop();
                    localSendDragLayout.contentOpacity = 0.0;
                    localSendDragLayout.slideY = 10 * scaleFactor;
                }
            }
        }
        Timer {
            id: lsDragShowTimer
            interval: root.localSendRevealDelay
            repeat: false
            onTriggered: {
                localSendDragLayout.slideY = 0;
                localSendDragLayout.contentOpacity = 1.0;
            }
        }

        RowLayout {
            id: lsDragRow
            spacing: 12 * scaleFactor

            Text {
                text: "󰌹"
                color: root.colAccent
                font { family: root.iconFontFamily; pixelSize: 20 * fontScale; bold: true }
                Layout.alignment: Qt.AlignVCenter
            }
            ColumnLayout {
                spacing: 2 * scaleFactor
                Layout.alignment: Qt.AlignVCenter
                Text {
                    text: "Send via KDE Connect"
                    color: root.colFg
                    font { family: root.fontFamily; pixelSize: 12 * fontScale; bold: true }
                }
                Text {
                    text: "Drop files here to share"
                    color: root.colMuted
                    font { family: root.fontFamily; pixelSize: 10 * fontScale }
                }
            }
        }
    }

    // LocalSend Success Layout
    Item {
        id: localSendSuccessLayout
        visible: root.islandState === root.stateLocalSendSuccess
        width: implicitWidth
        height: implicitHeight
        anchors.centerIn: parent
        implicitWidth: lsSuccessRow.implicitWidth
        implicitHeight: lsSuccessRow.implicitHeight
        layer.enabled: true
        z: 20

        property real slideY: 10 * scaleFactor
        property real contentOpacity: 0.0

        transform: Translate { y: localSendSuccessLayout.slideY }
        opacity: localSendSuccessLayout.contentOpacity

        Behavior on slideY {
            NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
        }
        Behavior on contentOpacity {
            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
        }

        Connections {
            target: root
            function onIslandStateChanged() {
                if (root.islandState === root.stateLocalSendSuccess) {
                    localSendSuccessLayout.slideY = 10 * scaleFactor;
                    localSendSuccessLayout.contentOpacity = 0.0;
                    lsSuccessShowTimer.restart();
                } else {
                    lsSuccessShowTimer.stop();
                    localSendSuccessLayout.contentOpacity = 0.0;
                    localSendSuccessLayout.slideY = 10 * scaleFactor;
                }
            }
        }
        Timer {
            id: lsSuccessShowTimer
            interval: root.localSendRevealDelay
            repeat: false
            onTriggered: {
                localSendSuccessLayout.slideY = 0;
                localSendSuccessLayout.contentOpacity = 1.0;
            }
        }

        RowLayout {
            id: lsSuccessRow
            spacing: 12 * scaleFactor

            Text {
                text: "󰗡"
                color: root.colSuccess
                font { family: root.iconFontFamily; pixelSize: 20 * fontScale; bold: true }
                Layout.alignment: Qt.AlignVCenter
            }
            ColumnLayout {
                spacing: 2 * scaleFactor
                Layout.alignment: Qt.AlignVCenter
                Text {
                    text: "Sending..."
                    color: root.colSuccess
                    font { family: root.fontFamily; pixelSize: 12 * fontScale; bold: true }
                }
                Text {
                    text: "Sent to paired device"
                    color: root.colMuted
                    font { family: root.fontFamily; pixelSize: 10 * fontScale }
                }
            }
        }
    }

    // Teenage Engineering Field Mic VU Telemetry Layout inside Notch
    RowLayout {
        id: commsLayout
        z: 50
        opacity: ((root.islandState === root.stateComms && !root.isCenterPopupOpen) ? 1.0 : 0.0)
        visible: (root.islandState === root.stateComms && !root.isCenterPopupOpen) || opacity > 0.001
        scale: (root.islandState === root.stateComms && !root.isCenterPopupOpen) ? 1.0 : 0.94
        Behavior on opacity {
            NumberAnimation {
                duration: 220
                easing.type: Easing.OutCubic
            }
        }
        Behavior on scale { NumberAnimation { duration: 240; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }
        anchors.centerIn: notchRect
        spacing: 6 * scaleFactor

        CommsVisualizer {
            id: commsWaves
            width: 160 * scaleFactor
            height: 24 * scaleFactor
            Layout.preferredWidth: width
            Layout.preferredHeight: height
            active: root.islandState === root.stateComms && !root.isAnyPopupOpen
            Layout.alignment: Qt.AlignVCenter
        }
    }
}
