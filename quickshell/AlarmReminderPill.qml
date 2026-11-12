import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

PanelWindow {
    id: rootWindow

    property bool show: false
    property var shellRoot
    readonly property real scaleFactor: shellRoot ? shellRoot.scaleFactor : 1.0
    readonly property real fontScale: scaleFactor * (shellRoot ? shellRoot.fontSizeMultiplier : 1.0)

    property var currentAlert: null
    property var alertQueue: []
    property bool isClosing: false
    property real savedCloseTarget: 120
    property bool suppressOpenAnimation: false

    // Countdown: seconds remaining before auto-timeout
    property int remainingSeconds: 300
    property bool isRinging: false

    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell_alarm_pill"

    anchors.top: true
    anchors.left: true
    anchors.right: true
    anchors.bottom: true
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    // ── Screencopy for glass refraction ─────────────────────────────────
    ScreencopyView {
        id: localScreenBackdrop
        property bool revealContent: false
        captureSource: Quickshell.screens[0]
        live: false
        paintCursor: false
        width: Screen.width > 0 ? Screen.width : 1920
        height: Screen.height > 0 ? Screen.height : 1080
        z: -999
        visible: false
    }

    Timer {
        id: screencopySnapshotTimer
        interval: 40
        repeat: false
        onTriggered: localScreenBackdrop.revealContent = true
    }

    Timer {
        id: preCaptureDelayTimer
        interval: 35
        repeat: false
        onTriggered: {
            localScreenBackdrop.captureFrame();
            screencopySnapshotTimer.restart();
        }
    }

    // Click-through mask: only animRect is interactive
    mask: Region {
        Region { item: (rootWindow.show || rootWindow.isClosing) ? animRect : null }
    }

    visible: show || isClosing

    // ── Auto-Timeout (5 min for ringing alarm, 12-15s for transient alerts) ─
    Timer {
        id: autoTimeoutTimer
        interval: 300000
        repeat: false
        onTriggered: {
            rootWindow.stopAlertLoop();
            rootWindow.dismissPill();
        }
    }

    // ── Alert Lifecycle ──────────────────────────────────────────────────
    function triggerAlert(alertData) {
        if (!alertData) return;

        // History-only — never fires a desktop toast
        logToNotificationHistory(alertData);

        var aType = alertData.type || (alertData.is_alarm ? "alarm" : "task");

        if (show) {
            // Morph in-place smoothly
            currentAlert = alertData;
            if (alertData.is_warning || aType === "water" || aType === "stretch" || aType === "f1") {
                isRinging = false;
                if (pAlarmLoop.running) pAlarmLoop.running = false;
                pWarningChime.running = true;
                autoTimeoutTimer.interval = alertData.timeout_ms || 15000;
                autoTimeoutTimer.restart();
            } else {
                isRinging = true;
                remainingSeconds = 300;
                pAlarmLoop.running = true;
                autoTimeoutTimer.interval = 300000;
                autoTimeoutTimer.restart();
            }
            return;
        }

        currentAlert = alertData;
        show = true;

        if (alertData.is_warning || aType === "water" || aType === "stretch" || aType === "f1") {
            isRinging = false;
            pWarningChime.running = true;
            autoTimeoutTimer.interval = alertData.timeout_ms || 15000;
            autoTimeoutTimer.restart();
        } else {
            isRinging = true;
            remainingSeconds = 300;
            pAlarmLoop.running = true;
            autoTimeoutTimer.interval = 300000;
            autoTimeoutTimer.restart();
        }
    }

    function stopAlertLoop() {
        autoTimeoutTimer.stop();
        isRinging = false;
        if (pAlarmLoop.running) pAlarmLoop.running = false;
        if (pWarningChime.running) pWarningChime.running = false;
    }

    function dismissPill() {
        stopAlertLoop();
        currentAlert = null;
        show = false;
    }

    function handleSnooze(minutes) {
        if (!currentAlert) return;
        var aType = currentAlert.type || "";
        var aId = currentAlert.id;
        stopAlertLoop();

        if (aType === "water") {
            if (shellRoot && typeof shellRoot.snoozeWaterTimer === "function") {
                shellRoot.snoozeWaterTimer();
            }
        } else if (aType === "stretch") {
            if (shellRoot && typeof shellRoot.snoozeStretchTimer === "function") {
                shellRoot.snoozeStretchTimer();
            }
        } else {
            if (shellRoot && typeof shellRoot.snoozeAlert === "function") {
                shellRoot.snoozeAlert(aId, minutes);
            }
        }
        dismissPill();
    }

    function handleActionComplete() {
        if (!currentAlert) return;
        var aType = currentAlert.type || "";
        var alertItem = currentAlert;
        stopAlertLoop();

        if (aType === "water") {
            if (shellRoot && typeof shellRoot.logWater === "function") {
                shellRoot.logWater(250);
            }
            if (shellRoot && typeof shellRoot.resetWaterTimer === "function") {
                shellRoot.resetWaterTimer();
            }
        } else if (aType === "stretch") {
            if (shellRoot && typeof shellRoot.logStretch === "function") {
                shellRoot.logStretch(1);
            }
            if (shellRoot && typeof shellRoot.resetStretchTimer === "function") {
                shellRoot.resetStretchTimer();
            }
        } else if (aType === "task" && alertItem.task_id) {
            if (shellRoot && typeof shellRoot.toggleTask === "function") {
                shellRoot.toggleTask(alertItem.task_id);
            }
        } else if (typeof shellRoot.dismissAlert === "function") {
            shellRoot.dismissAlert(alertItem.id);
        }
        dismissPill();
    }

    function logToNotificationHistory(alertData) {
        if (!shellRoot || typeof shellRoot.addNotificationToList !== "function") return;
        var isAlarm = alertData.is_alarm || alertData.type === "alarm";
        var prefix = alertData.is_warning ? "⏳ Upcoming: " : (isAlarm ? "⏰ Alarm: " : (alertData.type === "water" ? "💧 Water: " : (alertData.type === "stretch" ? "🧘 Stretch: " : (alertData.type === "f1" ? "🏎 F1: " : "📋 Todoist: "))));
        shellRoot.addNotificationToList({
            id: "reminder_" + alertData.id + "_" + Date.now(),
            notifId: "reminder_" + alertData.id,
            summary: prefix + (alertData.title || "Reminder"),
            body: alertData.subtitle || (isAlarm ? "Scheduled Alarm" : "Notification"),
            appName: isAlarm ? "Alarm" : (alertData.type === "water" || alertData.type === "stretch" ? "Health" : (alertData.type === "f1" ? "Formula 1" : "Todoist")),
            appIcon: isAlarm ? "alarm" : "checkbox-checked",
            hasActions: false,
            actions: []
        });
    }

    onShowChanged: {
        if (show) {
            localScreenBackdrop.revealContent = false;
            preCaptureDelayTimer.restart();
            isClosing = false;
            closeWatchdog.stop();
            suppressOpenAnimation = true;
            snapResetTimer.start();
            savedCloseTarget = Qt.binding(function() {
                return shellRoot ? shellRoot.closedNotchWidth : 120;
            });
        } else {
            localScreenBackdrop.revealContent = false;
            preCaptureDelayTimer.stop();
            screencopySnapshotTimer.stop();
            savedCloseTarget = shellRoot ? shellRoot.closedNotchWidth : 120;
            isClosing = true;
            closeWatchdog.restart();

            // Dequeue next alert after close animation
            if (alertQueue.length > 0) {
                var next = alertQueue.shift();
                nextAlertTimer.nextItem = next;
                nextAlertTimer.restart();
            }
        }
    }

    Timer { id: snapResetTimer; interval: 32; onTriggered: rootWindow.suppressOpenAnimation = false }
    Timer { id: closeWatchdog; interval: 1000; onTriggered: { if (rootWindow.isClosing) rootWindow.isClosing = false; } }
    Timer {
        id: nextAlertTimer
        property var nextItem: null
        interval: 420
        onTriggered: {
            if (nextItem) { rootWindow.triggerAlert(nextItem); nextItem = null; }
        }
    }

    // ── Sound Processes ──────────────────────────────────────────────────
    Process {
        id: pAlarmLoop
        command: ["mpv", "--loop=inf", "--no-video", "--load-scripts=no", "--volume=85",
                  "/usr/share/sounds/ocean/stereo/alarm-clock-elapsed.oga"]
    }
    Process {
        id: pWarningChime
        command: ["mpv", "--no-video", "--load-scripts=no", "--volume=80",
                  "/usr/share/sounds/ocean/stereo/message-new-instant.oga"]
    }

    // ── Pill Color & Icon Logic ──────────────────────────────────────────
    readonly property color pillAccentColor: {
        if (!currentAlert) return "#F59E0B";
        var t = currentAlert.type || "";
        if (currentAlert.is_alarm || t === "alarm") return "#F59E0B";
        if (t === "water") return "#38BDF8";
        if (t === "stretch") return "#10B981";
        if (t === "f1") return "#EF4444";
        if (currentAlert.is_warning) return "#38BDF8";
        var p = currentAlert.priority || 1;
        if (p >= 4) return "#EF4444";
        if (p === 3) return "#F97316";
        if (p === 2) return "#38BDF8";
        return "#6B7280";
    }

    readonly property string pillIconGlyph: {
        if (!currentAlert) return "󰂞";
        var t = currentAlert.type || "";
        if (currentAlert.is_alarm || t === "alarm") return "󰂞";
        if (t === "water") return "󰖌";  // md-water (U+F058C)
        if (t === "stretch") return "󱅼"; // md-yoga (U+F117C)
        if (t === "f1") return "󰞬";      // md-car_sports (U+F07AC)
        if (currentAlert.is_warning) return "󰔛";
        return "󰄴";
    }

    function getAlertPrimaryText() {
        if (!currentAlert) return "10:30";
        var t = currentAlert.type || "";
        if (currentAlert.is_alarm || t === "alarm") {
            if (currentAlert.time_str) return currentAlert.time_str;
            if (currentAlert.subtitle) {
                var m = currentAlert.subtitle.match(/\b\d{1,2}:\d{2}\b/);
                if (m) return m[0];
            }
            var d = new Date();
            var h = d.getHours().toString().padStart(2, '0');
            var min = d.getMinutes().toString().padStart(2, '0');
            return h + ":" + min;
        }
        if (t === "water") return "Drink Water";
        if (t === "stretch") return "Stretch Break";
        if (t === "f1") return "Formula 1";
        return currentAlert.title || "Reminder";
    }

    function getAlertSecondaryText() {
        if (!currentAlert) return "Wake up";
        var t = currentAlert.type || "";
        if (currentAlert.is_alarm || t === "alarm") {
            return currentAlert.title && currentAlert.title !== "Alarm" ? currentAlert.title : "Wake up";
        }
        if (t === "water") {
            var tw = shellRoot ? shellRoot.healthWaterToday : 0;
            var gw = shellRoot ? shellRoot.healthWaterGoal : 2500;
            return tw + " / " + gw + " ml";
        }
        if (t === "stretch") return "Time to stand up and stretch";
        if (t === "f1") return currentAlert.subtitle || (shellRoot ? shellRoot.f1NextRaceName : "Session Starting");
        return currentAlert.subtitle || (currentAlert.is_warning ? "Due in 5 mins" : "Due Now");
    }

    Rectangle {
        id: animRect
        anchors.top: parent.top
        anchors.topMargin: shellRoot && shellRoot.topHuggingStyle ? 0 : 4 * rootWindow.scaleFactor
        anchors.horizontalCenter: parent.horizontalCenter

        readonly property bool isWarningMode: rootWindow.currentAlert && rootWindow.currentAlert.is_warning
        readonly property bool isAlarmMode: rootWindow.currentAlert &&
            (rootWindow.currentAlert.is_alarm || rootWindow.currentAlert.type === "alarm")
        readonly property bool isWaterMode: rootWindow.currentAlert && rootWindow.currentAlert.type === "water"
        readonly property bool isStretchMode: rootWindow.currentAlert && rootWindow.currentAlert.type === "stretch"
        readonly property bool isTaskMode: rootWindow.currentAlert && rootWindow.currentAlert.type === "task"

        width: rootWindow.suppressOpenAnimation
            ? Math.round(32 * rootWindow.scaleFactor)
            : rootWindow.show
                ? (isAlarmMode
                    ? Math.round(365 * rootWindow.scaleFactor)
                    : (isWaterMode
                        ? Math.round(410 * rootWindow.scaleFactor)
                        : (isStretchMode
                            ? Math.round(390 * rootWindow.scaleFactor)
                            : (isTaskMode ? Math.round(425 * rootWindow.scaleFactor) : Math.round(350 * rootWindow.scaleFactor)))))
                : (rootWindow.isClosing ? Math.round(32 * rootWindow.scaleFactor) : savedCloseTarget)

        height: rootWindow.suppressOpenAnimation
            ? Math.round(32 * rootWindow.scaleFactor)
            : rootWindow.show
                ? Math.round(66 * rootWindow.scaleFactor)
                : Math.round(32 * rootWindow.scaleFactor)

        radius: rootWindow.suppressOpenAnimation
            ? Math.round(16 * rootWindow.scaleFactor)
            : rootWindow.show ? Math.round(22 * rootWindow.scaleFactor) : Math.round(16 * rootWindow.scaleFactor)

        color: "transparent"

        // Ringing border glow — subtle amber pulse when alarm sounds
        border.color: {
            if (rootWindow.isRinging && rootWindow.show) {
                var t = Date.now() / 400;
                var alpha = 0.40 + 0.20 * ((Math.sin(t) + 1) / 2);
                return Qt.rgba(0.96, 0.62, 0.04, alpha);
            }
            return shellRoot ? shellRoot.colBorder : Qt.rgba(1, 1, 1, 0.08);
        }
        border.width: rootWindow.isRinging ? 1.5 : 1

        Timer {
            interval: 80
            running: rootWindow.isRinging && rootWindow.show
            repeat: true
            onTriggered: animRect.border.color = Qt.binding(function() {
                if (rootWindow.isRinging && rootWindow.show) {
                    var t = Date.now() / 400;
                    var alpha = 0.40 + 0.20 * ((Math.sin(t) + 1) / 2);
                    return Qt.rgba(0.96, 0.62, 0.04, alpha);
                }
                return shellRoot ? shellRoot.colBorder : Qt.rgba(1, 1, 1, 0.08);
            })
        }

        // Glass surface
        SurfaceCard {
            anchors.fill: parent
            backdropItem: localScreenBackdrop
            cornerRadius: animRect.radius
            blurAmount: shellRoot ? shellRoot.glassBlurAmount : 0.20
            refraction: shellRoot ? shellRoot.glassRefraction : 0.40
            bevelMode: shellRoot ? shellRoot.glassBevelMode : 0.0
            zRadius: shellRoot ? shellRoot.glassZRadius : 32.0
            chromaticAberration: shellRoot ? shellRoot.glassChromAberration : 0.030
            edgeHighlight: shellRoot ? shellRoot.glassEdgeHighlight : 0.24
            fresnel: shellRoot ? shellRoot.glassFresnel : 0.85
            brightness: shellRoot ? shellRoot.glassBrightness : -0.22
            saturation: shellRoot ? shellRoot.glassSaturation : 0.0
            glassMode: shellRoot ? shellRoot.glassMode : "dark"
            contentPadding: 0

            Rectangle {
                anchors.fill: parent
                radius: animRect.radius
                color: Qt.rgba(0.03, 0.03, 0.06, 0.32)
            }
        }

        // ── ColorOS 17 Bottom Edge Ambient Glow Tint ───────────────────
        // Uses exact capsule radius and fill — never crosses outside the capsule boundary
        Rectangle {
            anchors.fill: parent
            radius: animRect.radius
            color: "transparent"
            gradient: Gradient {
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 0.62; color: "transparent" }
                GradientStop {
                    position: 1.0
                    color: {
                        var ac = Qt.color(rootWindow.pillAccentColor);
                        return Qt.rgba(ac.r, ac.g, ac.b, 0.16);
                    }
                }
            }

            // Bottom specular rim hairline — safely constrained inside flat bottom span
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width - Math.round(56 * rootWindow.scaleFactor)
                height: 1
                color: {
                    var ac = Qt.color(rootWindow.pillAccentColor);
                    return Qt.rgba(ac.r, ac.g, ac.b, 0.28);
                }
            }
        }

        // Smooth circle-collapse watchdog verification
        function checkCloseFinished() {
            if (!rootWindow.show && rootWindow.isClosing) {
                var sf = rootWindow.scaleFactor;
                var target = Math.round(32 * sf);
                if (Math.abs(width - target) < 1.8 && Math.abs(height - target) < 1.8) {
                    rootWindow.isClosing = false;
                    closeWatchdog.stop();
                }
            }
        }
        onWidthChanged: checkCloseFinished()
        onHeightChanged: checkCloseFinished()

        Behavior on radius {
            enabled: (rootWindow.show || rootWindow.isClosing) && !(shellRoot && shellRoot.batteryMode)
            SpringAnimation { spring: 5.5; damping: 0.82; mass: 0.5 }
        }
        Behavior on width {
            enabled: !rootWindow.suppressOpenAnimation && (rootWindow.show || rootWindow.isClosing) && !(shellRoot && shellRoot.batteryMode)
            SpringAnimation { spring: 5.5; damping: 0.82; mass: 0.5 }
        }
        Behavior on height {
            enabled: !rootWindow.suppressOpenAnimation && (rootWindow.show || rootWindow.isClosing) && !(shellRoot && shellRoot.batteryMode)
            SpringAnimation { spring: 5.5; damping: 0.82; mass: 0.5 }
        }

        // ── Omnidirectional 360° Breathing Ripple Aura ─────────────────
        // Clipping container: strictly bounds ripple waves inside animRect
        Item {
            anchors.fill: parent
            clip: true

            Item {
                id: rippleArea
                // Centered on the icon badge center: leftMargin(14) + iconBadge(40/2) = 34px from left
                x: Math.round(34 * rootWindow.scaleFactor)
                y: parent.height / 2
                width: 0; height: 0
                opacity: (rootWindow.show && localScreenBackdrop.revealContent)
                         ? (shellRoot && shellRoot.batteryMode ? 0.0 : 1.0)
                         : 0.0
                Behavior on opacity { NumberAnimation { duration: 250 } }

                readonly property real acR: Qt.color(rootWindow.pillAccentColor).r
                readonly property real acG: Qt.color(rootWindow.pillAccentColor).g
                readonly property real acB: Qt.color(rootWindow.pillAccentColor).b

                // 1. Ambient soft radial bloom — constrained to 40px diameter
                Rectangle {
                    id: ripBloom
                    width: Math.round(40 * rootWindow.scaleFactor)
                    height: width
                    radius: width / 2
                    x: -width / 2; y: -height / 2
                    color: Qt.rgba(rippleArea.acR, rippleArea.acG, rippleArea.acB, 0.14)

                    SequentialAnimation on scale {
                        running: rippleArea.opacity > 0 && !rootWindow.isClosing
                        loops: Animation.Infinite
                        NumberAnimation { to: 1.12; duration: rootWindow.isRinging ? 2000 : 2800; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 0.95; duration: rootWindow.isRinging ? 2000 : 2800; easing.type: Easing.InOutSine }
                    }
                }

                // 2. Wave 1 — expands from 32px to 54px diameter (max radius 27 < icon-center-x 34, so left edge = 34-27 = 7px inside)
                Rectangle {
                    id: ripWave1
                    property real progress: 0.0
                    width: Math.round((32 + progress * 22) * rootWindow.scaleFactor)
                    height: width
                    radius: width / 2
                    x: -width / 2; y: -height / 2
                    color: "transparent"
                    border.width: Math.max(1, Math.round((4.5 - progress * 2.0) * rootWindow.scaleFactor))
                    border.color: {
                        var alpha = (1.0 - progress) * 0.40;
                        return Qt.rgba(rippleArea.acR, rippleArea.acG, rippleArea.acB, alpha);
                    }

                    SequentialAnimation on progress {
                        running: rippleArea.opacity > 0 && !rootWindow.isClosing
                        loops: Animation.Infinite
                        NumberAnimation {
                            from: 0.0; to: 1.0
                            duration: rootWindow.isRinging ? 3200 : 4200
                            easing.type: Easing.OutSine
                        }
                        PauseAnimation { duration: 1200 }
                    }
                }

                // 3. Wave 2 (concentric echo, delayed offset)
                Rectangle {
                    id: ripWave2
                    property real progress: 0.0
                    width: Math.round((32 + progress * 22) * rootWindow.scaleFactor)
                    height: width
                    radius: width / 2
                    x: -width / 2; y: -height / 2
                    color: "transparent"
                    border.width: Math.max(1, Math.round((3.5 - progress * 1.5) * rootWindow.scaleFactor))
                    border.color: {
                        var alpha = (1.0 - progress) * 0.25;
                        return Qt.rgba(rippleArea.acR, rippleArea.acG, rippleArea.acB, alpha);
                    }

                    SequentialAnimation on progress {
                        running: rippleArea.opacity > 0 && !rootWindow.isClosing
                        loops: Animation.Infinite
                        PauseAnimation { duration: 1600 }
                        NumberAnimation {
                            from: 0.0; to: 1.0
                            duration: rootWindow.isRinging ? 3200 : 4200
                            easing.type: Easing.OutSine
                        }
                    }
                }
            }
        }

        // ── Content Layer ─────────────────────────────────────────────
        Item {
            anchors.fill: parent
            clip: true
            opacity: (rootWindow.show && localScreenBackdrop.revealContent) ? 1.0 : 0.0
            Behavior on opacity {
                NumberAnimation {
                    duration: rootWindow.show ? 160 : 70
                    easing.type: rootWindow.show ? Easing.OutQuad : Easing.InQuad
                }
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Math.round(14 * rootWindow.scaleFactor)
                anchors.rightMargin: Math.round(14 * rootWindow.scaleFactor)
                spacing: Math.round(12 * rootWindow.scaleFactor)

                // ── Icon Badge ────────────────────────────────────────
                Item {
                    id: iconBadgeArea
                    Layout.preferredWidth:  Math.round(40 * rootWindow.scaleFactor)
                    Layout.preferredHeight: Math.round(40 * rootWindow.scaleFactor)
                    Layout.alignment: Qt.AlignVCenter

                    readonly property color accentColor: rootWindow.pillAccentColor
                    readonly property real  colR: Qt.color(accentColor).r
                    readonly property real  colG: Qt.color(accentColor).g
                    readonly property real  colB: Qt.color(accentColor).b

                    Rectangle {
                        id: iconBadge
                        anchors.fill: parent
                        radius: width / 2
                        color: Qt.rgba(iconBadgeArea.colR, iconBadgeArea.colG, iconBadgeArea.colB, 0.20)
                        border.color: Qt.rgba(iconBadgeArea.colR, iconBadgeArea.colG, iconBadgeArea.colB, 0.45)
                        border.width: 1.2

                        // Gentle breathe when ringing
                        SequentialAnimation on scale {
                            running: rootWindow.isRinging && rootWindow.show && !(shellRoot && shellRoot.batteryMode)
                            loops: Animation.Infinite
                            NumberAnimation { to: 1.08; duration: 400; easing.type: Easing.OutSine }
                            NumberAnimation { to: 1.0;  duration: 450; easing.type: Easing.InOutSine }
                            PauseAnimation  { duration: 800 }
                        }
                        NumberAnimation on scale {
                            running: !rootWindow.isRinging
                            to: 1.0; duration: 200; easing.type: Easing.OutQuad
                        }

                        Text {
                            anchors.centerIn: parent
                            text: rootWindow.pillIconGlyph
                            color: iconBadgeArea.accentColor
                            font {
                                family: shellRoot ? shellRoot.nerdFontFamily : "Symbols Nerd Font"
                                pixelSize: Math.round(18 * rootWindow.fontScale)
                            }
                        }
                    }
                }

                // ── Typography: Clean, Uncluttered Two-Line Hierarchy ──
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Math.round(1 * rootWindow.scaleFactor)
                    Layout.alignment: Qt.AlignVCenter

                    Text {
                        Layout.fillWidth: true
                        text: rootWindow.getAlertPrimaryText()
                        color: shellRoot ? shellRoot.colFgPrimary : "#FFFFFF"
                        elide: Text.ElideRight
                        font {
                            family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                            pixelSize: animRect.isAlarmMode
                                ? Math.round(18 * rootWindow.fontScale)
                                : Math.round(13.5 * rootWindow.fontScale)
                            weight: Font.DemiBold
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: rootWindow.getAlertSecondaryText()
                        color: shellRoot ? shellRoot.colFgSecondary : Qt.rgba(1, 1, 1, 0.60)
                        elide: Text.ElideRight
                        font {
                            family: shellRoot ? shellRoot.textFontFamily : "sans-serif"
                            pixelSize: Math.round(11 * rootWindow.fontScale)
                            weight: Font.Normal
                        }
                    }
                }

                // ── Action Buttons: Streamlined & Premium ──────────────
                RowLayout {
                    spacing: Math.round(8 * rootWindow.scaleFactor)
                    Layout.alignment: Qt.AlignVCenter

                    // ── Snooze Button (Left click 10m, Right click 30m) ──
                    MouseArea {
                        id: btnSnooze
                        visible: rootWindow.currentAlert &&
                                 !animRect.isWarningMode &&
                                 !animRect.isWaterMode &&
                                 !animRect.isStretchMode &&
                                 rootWindow.currentAlert.type !== "f1"
                        Layout.preferredWidth: visible ? Math.round(74 * rootWindow.scaleFactor) : 0
                        Layout.preferredHeight: Math.round(32 * rootWindow.scaleFactor)
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: mouse => {
                            if (mouse.button === Qt.RightButton) {
                                rootWindow.handleSnooze(30);
                            } else {
                                rootWindow.handleSnooze(animRect.isAlarmMode ? 10 : 30);
                            }
                        }
                        scale: containsPress ? 0.93 : 1.0
                        Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutQuad } }

                        Rectangle {
                            anchors.fill: parent
                            radius: height / 2
                            color: btnSnooze.containsMouse ? "#1E88E5" : "#0A84FF"
                            Behavior on color { ColorAnimation { duration: 120 } }

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: Math.round(3 * rootWindow.scaleFactor)
                                Text {
                                    text: "󰔛"
                                    color: "#FFFFFF"
                                    font {
                                        family: shellRoot ? shellRoot.iconFontFamily : "sans-serif"
                                        pixelSize: Math.round(11 * rootWindow.fontScale)
                                    }
                                }
                                Text {
                                    text: "Snooze"
                                    color: "#FFFFFF"
                                    font {
                                        family: shellRoot ? shellRoot.textFontFamily : "sans-serif"
                                        pixelSize: Math.round(11.5 * rootWindow.fontScale)
                                        weight: Font.DemiBold
                                    }
                                }
                            }
                        }
                    }

                    // ── Done Button for Todoist Tasks ──
                    MouseArea {
                        id: btnDoneTask
                        visible: animRect.isTaskMode
                        Layout.preferredWidth: visible ? Math.round(64 * rootWindow.scaleFactor) : 0
                        Layout.preferredHeight: Math.round(32 * rootWindow.scaleFactor)
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: rootWindow.handleActionComplete()
                        scale: containsPress ? 0.93 : 1.0
                        Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutQuad } }

                        Rectangle {
                            anchors.fill: parent
                            radius: height / 2
                            color: btnDoneTask.containsMouse ? "#059669" : "#10B981"
                            Behavior on color { ColorAnimation { duration: 120 } }

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: Math.round(3 * rootWindow.scaleFactor)
                                Text {
                                    text: "󰄴"
                                    color: "#FFFFFF"
                                    font {
                                        family: shellRoot ? shellRoot.iconFontFamily : "sans-serif"
                                        pixelSize: Math.round(11 * rootWindow.fontScale)
                                    }
                                }
                                Text {
                                    text: "Done"
                                    color: "#FFFFFF"
                                    font {
                                        family: shellRoot ? shellRoot.textFontFamily : "sans-serif"
                                        pixelSize: Math.round(11.5 * rootWindow.fontScale)
                                        weight: Font.DemiBold
                                    }
                                }
                            }
                        }
                    }

                    // ── Water Action Button: +250ml ──
                    MouseArea {
                        id: btnWaterAction
                        visible: animRect.isWaterMode
                        Layout.preferredWidth: visible ? Math.round(76 * rootWindow.scaleFactor) : 0
                        Layout.preferredHeight: Math.round(32 * rootWindow.scaleFactor)
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: rootWindow.handleActionComplete()
                        scale: containsPress ? 0.93 : 1.0
                        Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutQuad } }

                        Rectangle {
                            anchors.fill: parent
                            radius: height / 2
                            color: btnWaterAction.containsMouse ? "#0284C7" : "#0284C7"
                            Behavior on color { ColorAnimation { duration: 120 } }

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: Math.round(3 * rootWindow.scaleFactor)
                                Text {
                                    text: "󰖌"
                                    color: "#FFFFFF"
                                    font {
                                        family: shellRoot ? shellRoot.nerdFontFamily : "Symbols Nerd Font"
                                        pixelSize: Math.round(11 * rootWindow.fontScale)
                                    }
                                }
                                Text {
                                    text: "+250ml"
                                    color: "#FFFFFF"
                                    font {
                                        family: shellRoot ? shellRoot.textFontFamily : "sans-serif"
                                        pixelSize: Math.round(11.5 * rootWindow.fontScale)
                                        weight: Font.DemiBold
                                    }
                                }
                            }
                        }
                    }

                    // ── Stretch Action Button: Done ──
                    MouseArea {
                        id: btnStretchAction
                        visible: animRect.isStretchMode
                        Layout.preferredWidth: visible ? Math.round(64 * rootWindow.scaleFactor) : 0
                        Layout.preferredHeight: Math.round(32 * rootWindow.scaleFactor)
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: rootWindow.handleActionComplete()
                        scale: containsPress ? 0.93 : 1.0
                        Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutQuad } }

                        Rectangle {
                            anchors.fill: parent
                            radius: height / 2
                            color: btnStretchAction.containsMouse ? "#059669" : "#10B981"
                            Behavior on color { ColorAnimation { duration: 120 } }

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: Math.round(3 * rootWindow.scaleFactor)
                                Text {
                                    text: "󰄴"
                                    color: "#FFFFFF"
                                    font {
                                        family: shellRoot ? shellRoot.iconFontFamily : "sans-serif"
                                        pixelSize: Math.round(11 * rootWindow.fontScale)
                                    }
                                }
                                Text {
                                    text: "Done"
                                    color: "#FFFFFF"
                                    font {
                                        family: shellRoot ? shellRoot.textFontFamily : "sans-serif"
                                        pixelSize: Math.round(11.5 * rootWindow.fontScale)
                                        weight: Font.DemiBold
                                    }
                                }
                            }
                        }
                    }

                    // ── Snooze Button for Health Suite ──
                    MouseArea {
                        id: btnHealthSnooze
                        visible: animRect.isWaterMode || animRect.isStretchMode
                        Layout.preferredWidth: visible ? Math.round(68 * rootWindow.scaleFactor) : 0
                        Layout.preferredHeight: Math.round(32 * rootWindow.scaleFactor)
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: rootWindow.handleSnooze(10)
                        scale: containsPress ? 0.93 : 1.0
                        Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutQuad } }

                        Rectangle {
                            anchors.fill: parent
                            radius: height / 2
                            color: btnHealthSnooze.containsMouse ? Qt.rgba(1, 1, 1, 0.20) : Qt.rgba(1, 1, 1, 0.10)
                            border.color: Qt.rgba(1, 1, 1, 0.12)
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: 120 } }

                            Text {
                                anchors.centerIn: parent
                                text: "Snooze"
                                color: Qt.rgba(1, 1, 1, 0.85)
                                font {
                                    family: shellRoot ? shellRoot.textFontFamily : "sans-serif"
                                    pixelSize: Math.round(11 * rootWindow.fontScale)
                                    weight: Font.Medium
                                }
                            }
                        }
                    }

                    // ── Circular Dismiss / Stop Button ──────────────────
                    MouseArea {
                        id: btnCloseCircle
                        Layout.preferredWidth: Math.round(32 * rootWindow.scaleFactor)
                        Layout.preferredHeight: Math.round(32 * rootWindow.scaleFactor)
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (animRect.isAlarmMode) {
                                rootWindow.dismissPill();
                            } else {
                                rootWindow.handleActionComplete();
                            }
                        }
                        scale: containsPress ? 0.92 : 1.0
                        Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutQuad } }

                        Rectangle {
                            anchors.fill: parent
                            radius: width / 2
                            color: btnCloseCircle.containsMouse ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(1, 1, 1, 0.12)
                            border.color: Qt.rgba(1, 1, 1, 0.08)
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: 120 } }

                            Text {
                                anchors.centerIn: parent
                                text: animRect.isAlarmMode ? "󰅖" : "✕"
                                color: Qt.rgba(1, 1, 1, 0.85)
                                font {
                                    family: animRect.isAlarmMode ? (shellRoot ? shellRoot.iconFontFamily : "sans-serif") : (shellRoot ? shellRoot.textFontFamily : "sans-serif")
                                    pixelSize: Math.round(13 * rootWindow.fontScale)
                                    weight: Font.Bold
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
