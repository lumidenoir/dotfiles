//@ pragma UseQApplication
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

ShellRoot {
    id: root
    property bool _initApp: {
        Qt.application.organization = "Quickshell";
        Qt.application.domain = "quickshell.org";
        Qt.application.name = "Quickshell";
        return true;
    }
    property color colBg: "#000000"
    property color colFg: "#ffffff"
    property color colAccent: "#ffffff"
    property color colMuted: Qt.rgba(1, 1, 1, 0.4)
    property color colHover: Qt.rgba(1, 1, 1, 0.1)
    property color colCrit: "#ff0000"
    property color colSuccess: "#76B900"
    property color colWarn: "#FFA500"
    property color colSpotify: "#1DB954"
    readonly property real scaleFactor: Screen.width > 2560 ? 1.25 : (Screen.width > 1920 ? 1.125 : 1.0)
    property string fontFamily: "Geist"
    property string iconFontFamily: "GeistMono Nerd Font"
    property int fontSize: Math.round(11 * scaleFactor)
    property bool isDestroying: false

    property var currentNotif: null
    property real notchWidth: notchLayout.implicitWidth
    property alias notchRect: notchRect
    readonly property var _notchWidths: ({
        1: 280 * scaleFactor, 4: 240 * scaleFactor, 5: 240 * scaleFactor, 6: 200 * scaleFactor, 3: 200 * scaleFactor,
        7: 200 * scaleFactor, 8: 200 * scaleFactor, 9: 200 * scaleFactor, 10: 240 * scaleFactor, 11: 240 * scaleFactor,
        12: 260 * scaleFactor, 13: 280 * scaleFactor, 14: 340 * scaleFactor, 15: 260 * scaleFactor, 16: 220 * scaleFactor,
        17: 290 * scaleFactor
    })

    property real _cachedNotchWidth: 180 * scaleFactor
    Connections {
        target: notchLayout
        // Only update while in compact — prevents tiny text changes (e.g. "99%"→"100%")
        // from bouncing _cachedNotchWidth and causing opacity flicker.
        function onImplicitWidthChanged() {
            if (root.islandState === root.stateCompact && !root.isAnyPopupOpen) {
                _cachedNotchWidth = notchLayout.implicitWidth + 40 * scaleFactor;
            }
        }
    }
    // Also refresh when *returning* to compact, in case modules changed
    // while the island was in another state (e.g. Spotify started while in media state).
    onIslandStateChanged: {
        if (root.islandState === root.stateCompact) {
            _cachedNotchWidth = notchLayout.implicitWidth + 40 * scaleFactor;
        }
    }
    Component.onCompleted: {
        _cachedNotchWidth = notchLayout.implicitWidth + 40 * scaleFactor;
        root.reloadWalColors();
    }
    // Cap at 45% of bar width so the pill never overlaps the side widgets
    readonly property real closedNotchWidth: Math.min(
        _notchWidths[islandState] ?? _cachedNotchWidth,
        barWindow.width * 0.45
    )
    signal notificationReceived

    // Dynamic paths
    readonly property string dotfilesDir: {
        var path = Quickshell.shellDir;
        if (path.indexOf("/.config/quickshell") !== -1) {
            return path.replace("/.config/quickshell", "/dotfiles");
        }
        if (path.endsWith("/quickshell")) {
            path = path.substring(0, path.length - 11);
        }
        return path;
    }
    readonly property string scriptsDir: dotfilesDir + "/scripts"

    // Named constants for islandState
    readonly property int stateCompact: 0
    readonly property int stateMedia: 1
    readonly property int stateOsd: 3
    readonly property int stateTimer: 4
    readonly property int stateStopwatch: 5
    readonly property int stateRecording: 6
    readonly property int stateBatteryLow: 7
    readonly property int stateCharging: 8
    readonly property int stateDnd: 9
    readonly property int stateWaterAlert: 10
    readonly property int stateStretchAlert: 11
    readonly property int stateF1Alert: 12
    readonly property int stateCpuAlert: 13
    readonly property int stateDragLocalSend: 14
    readonly property int stateLocalSendSuccess: 15
    readonly property int stateComms: 16
    readonly property int stateDiskAlert: 17
    property string diskAlertTitle: ""
    property string diskAlertSubtitle: ""
    property bool diskAlertMounted: true
    property bool flightDeckActive: false


    property bool topHuggingStyle: false
    property real notchSpringStiffness: 3.5
    property real notchSpringDamping: 0.62
    property real notchSpringMass: 0.75
    property int localSendDismissDelay: 2000
    property int localSendRevealDelay: 140
    property int notifDismissDelay: 4500

    Settings {
        id: configSettings
        category: "Quickshell"
        property alias topHuggingStyle: root.topHuggingStyle
        property alias notchSpringStiffness: root.notchSpringStiffness
        property alias notchSpringDamping: root.notchSpringDamping
        property alias notchSpringMass: root.notchSpringMass
        property alias localSendDismissDelay: root.localSendDismissDelay
        property alias localSendRevealDelay: root.localSendRevealDelay
        property alias notifDismissDelay: root.notifDismissDelay
    }

    property int islandState: stateCompact
    property int prevIslandState: stateCompact // for restoring after OSD
    property string notifTitle: ""
    property string notifBody: ""
    property string notifIcon: ""
    property bool notifActive: false
    property alias mediaExpanded: mediaPopup.show

    // F1, Emails, and CPU Hot alerts state variables
    property string f1NextEventName: ""
    property string f1NextEventTime: ""
    property string f1NextEventLocation: ""
    property string f1NextEventIso: ""
    property string f1ListText: ""
    property string f1MainRaceText: ""
    property string f1AlertName: ""
    property string f1AlertMins: ""
    property string f1AlertTime: ""
    property real lastCpuAlertTime: 0
    property string topCpuProcess: ""

    // Component property aliases for modular sub-menus
    property alias notifCloseTimer: notifCloseTimer
    property alias pSpotPrev: pSpotPrev
    property alias pSpotPlay: pSpotPlay
    property alias pSpotNext: pSpotNext
    property alias pVolMute: pVolMute
    property alias pVolSet: pVolSet
    property alias pVolSetMic: pVolSetMic
    property alias pMicMute: pMicMute
    property alias pVolumeOut: pVolumeOut
    property alias pVolumeMic: pVolumeMic
    property alias pBrightSet: pBrightSet
    property alias pBtToggle: pBtToggle
    property alias pWifiToggle: pWifiToggle
    property alias pCyclePowerProfile: pCyclePowerProfile
    property alias pScreenshotSel: pScreenshotSel
    property alias pScreenshotNow: pScreenshotNow
    property alias pColorPicker: pColorPicker
    property alias pLockScreen: pLockScreen
    property alias pStopRecord: pStopRecord
    property alias pRecordSel: pRecordSel
    property alias pRecordFull: pRecordFull
    property alias pWallTheme: pWallTheme
    property alias pOcrShot: pOcrShot
    property alias wifiMenuPopup: wifiMenuPopup
    property alias bluetoothMenuPopup: bluetoothMenuPopup
    property alias timerPopup: timerPopup
    property alias f1CalendarPopup: f1CalendarPopup
    property alias emailsPopup: emailsPopup
    property alias wallpaperMenuPopup: wallpaperMenuPopup
    property alias settingsWindow: settingsWindow
    property alias sinkModel: sinkModel
    property alias pListSinks: pListSinks
    property alias pSetSink: pSetSink
    property alias notifList: notifList
    property alias pRedshiftToggle: pRedshiftToggle
    property alias pCaffeineToggle: pCaffeineToggle
    property alias pKeybindings: pKeybindings

    property var cpuHistory: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    property var ramHistory: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]

    // Reactive list — re-evaluates automatically when any input property changes
    property var activeActivities: {
        var list = [];
        if (root.spotifyStatus === "playing")
            list.push("media");
        if (root.timerRunning || (root.timerSeconds > 0 && root.timerSeconds < root.timerTotal))
            list.push("timer");
        if (root.stopwatchRunning || root.stopwatchSeconds > 0)
            list.push("stopwatch");
        if (root.isRecording)
            list.push("recording");
        return list;
    }

    // Auto-promote/demote activities as they start or end
    onActiveActivitiesChanged: {
        var acts = root.activeActivities;
        var currentAct = "";
        if (root.islandState === root.stateMedia)
            currentAct = "media";
        else if (root.islandState === root.stateTimer)
            currentAct = "timer";
        else if (root.islandState === root.stateStopwatch)
            currentAct = "stopwatch";
        else if (root.islandState === root.stateRecording)
            currentAct = "recording";

        if (currentAct !== "" && acts.indexOf(currentAct) === -1) {
            // Current activity ended — promote next or go compact
            if (acts.length > 0) {
                var n = acts[0];
                if (n === "media")
                    root.islandState = root.stateMedia;
                else if (n === "timer")
                    root.islandState = root.stateTimer;
                else if (n === "stopwatch")
                    root.islandState = root.stateStopwatch;
                else if (n === "recording")
                    root.islandState = root.stateRecording;
            } else {
                root.islandState = root.stateCompact;
            }
        } else if (root.islandState === root.stateCompact && acts.length > 0) {
            // Island is idle — auto-promote the first new activity
            var first = acts[0];
            if (first === "media")
                root.islandState = root.stateMedia;
            else if (first === "timer")
                root.islandState = root.stateTimer;
            else if (first === "stopwatch")
                root.islandState = root.stateStopwatch;
            else if (first === "recording")
                root.islandState = root.stateRecording;
        }
    }

    function swapActivities() {
        var acts = root.activeActivities;
        if (acts.length <= 1)
            return;
        var currentActivity = "";
        if (root.islandState === root.stateMedia)
            currentActivity = "media";
        else if (root.islandState === root.stateTimer)
            currentActivity = "timer";
        else if (root.islandState === root.stateStopwatch)
            currentActivity = "stopwatch";
        else if (root.islandState === root.stateRecording)
            currentActivity = "recording";

        var currentIndex = acts.indexOf(currentActivity);
        var nextIndex = (currentIndex + 1) % acts.length;
        var nextActivity = acts[nextIndex];

        if (nextActivity === "media")
            root.islandState = root.stateMedia;
        else if (nextActivity === "timer")
            root.islandState = root.stateTimer;
        else if (nextActivity === "stopwatch")
            root.islandState = root.stateStopwatch;
        else if (nextActivity === "recording")
            root.islandState = root.stateRecording;
    }

    readonly property bool isAnyPopupOpen: (groundControl && groundControl.visible) || (wifiMenuPopup && wifiMenuPopup.visible) || (powerMenuPopup && powerMenuPopup.visible) || (bluetoothMenuPopup && bluetoothMenuPopup.visible) || (mediaPopup && mediaPopup.visible) || (timerPopup && timerPopup.visible) || (f1CalendarPopup && f1CalendarPopup.visible) || (emailsPopup && emailsPopup.visible) || (wallpaperMenuPopup && wallpaperMenuPopup.visible) || (airspace && airspace.visible)

    // State properties
    property string wifiSsid: ""
    property string bluetoothDevice: ""
    property bool redshiftActive: false
    property bool caffeineActive: false
    property string powerDraw: "0.0"
    property string temperature: "0"
    property string updates: "0"
    property string batteryCap: "100"
    property string batteryTimeStr: ""
    property bool dndActive: false
    property string cpuUsage: "0"
    property string ramUsage: "0"
    property string brightnessLevel: "0%"
    property bool batteryCharging: false
    property int todayEmailsCount: 0
    property int hourEmailsCount: 0
    property int prevHourEmailsCount: 0
    property bool showEmailPill: false

    Timer {
        id: emailPillTimer
        interval: 10000 // 10 seconds max
        repeat: false
        onTriggered: root.showEmailPill = false
    }
    
    onHourEmailsCountChanged: {
        if (hourEmailsCount > prevHourEmailsCount) {
            queueNotification(["notify-send", "-u", "normal", "-i", "mail-unread", "New Mail Received", "You have " + hourEmailsCount + " new mail(s) in the last hour."]);
            root.showEmailPill = true;
            emailPillTimer.restart();
        } else if (hourEmailsCount === 0) {
            root.showEmailPill = false;
            emailPillTimer.stop();
        }
        prevHourEmailsCount = hourEmailsCount;
    }
    
    property var latestEmails: []
    property string volumeOut: "0%"
    property bool volumeMuted: false
    property string activeSinkName: "Default Output"
    property string volumeMic: "0%"
    property bool micMuted: false
    property string bluetoothStatus: "off"
    property bool batteryMode: false
    property bool showBatteryModeIndicator: false

    onBatteryModeChanged: {
        showBatteryModeIndicator = true;
        batteryModeTimer.restart();
    }

    Timer {
        id: batteryModeTimer
        interval: 1000
        repeat: false
        onTriggered: root.showBatteryModeIndicator = false
    }

    property bool showMicIndicator: false

    onMicMutedChanged: {
        showMicIndicator = true;
        micIndicatorTimer.restart();
    }

    Timer {
        id: micIndicatorTimer
        interval: 1000
        repeat: false
        onTriggered: root.showMicIndicator = false
    }

    property string spotifyStatus: "offline"
    property string spotifyText: ""
    property string spotifyArtUrl: ""
    property double spotifyPosition: 0
    property double spotifyLength: 0
    property string spotifyPositionStr: "0:00"
    property string spotifyLengthStr: "0:00"
    property color colAccentSecondary: "#10b981"
    property string wifiIcon: "󰤯"
    property string wifiText: "Disconnected"
    property string wifiIp: ""
    property bool wifiEnabled: false

    property bool showOsd: false
    property string osdText: "0%"
    property string osdIcon: "󰕾"
    property real osdValue: 0
    property bool showPowerMenu: false

    // Screen recording state
    property bool isRecording: false
    property int recordingSeconds: 0
    property string recordingTime: "0:00"

    // Weather
    property string weatherText: ""

    // Power profile: "balanced" | "performance" | "power-saver"
    property string powerProfile: "balanced"

    // Stopwatch & Timer state
    property bool stopwatchRunning: false
    property int stopwatchSeconds: 0
    property string stopwatchText: "00:00"

    property bool timerRunning: false
    property int timerSeconds: 0
    property int timerTotal: 300 // 5 minutes default
    property string timerText: "05:00"

    property int pomodoroState: 0 // 0 = off, 1 = work, 2 = break
    property int pomodoroWorkTotal: 1500 // 25 minutes
    property int pomodoroBreakTotal: 300 // 5 minutes
    property bool isMicActive: false
    property bool isCamActive: false

    onIsMicActiveChanged: {
        if (isMicActive) {
            root.safeSavePrev();
            root.islandState = root.stateComms;
        } else {
            if (root.islandState === root.stateComms) {
                root.islandState = root.stateCompact;
            }
        }
    }

    function formatTime(s) {
        var m = Math.floor(s / 60);
        var sec = Math.floor(s % 60);
        return (m < 10 ? "0" + m : m) + ":" + (sec < 10 ? "0" + sec : sec);
    }

    // Dynamic Island Alert Triggers (Charging / Low Battery / DND)
    property bool lastBatteryCharging: false
    onBatteryChargingChanged: {
        if (batteryCharging && !lastBatteryCharging) {
            root.safeSavePrev();
            root.islandState = root.stateCharging;
            batteryPillTimer.restart();
            lowBatteryNotified = false; // Reset notified state when charger is connected
            playSoundSafely(pPlayPowerPlug);
        } else if (!batteryCharging && lastBatteryCharging) {
            playSoundSafely(pPlayPowerUnplug);
        }
        lastBatteryCharging = batteryCharging;
    }

    property bool lowBatteryNotified: false
    onBatteryCapChanged: {
        var cap = parseInt(batteryCap);
        if (!isNaN(cap)) {
            if (cap > 0 && cap <= 15 && !batteryCharging) {
                if (!lowBatteryNotified) {
                    root.safeSavePrev();
                    root.islandState = root.stateBatteryLow;
                    batteryPillTimer.restart();
                    lowBatteryNotified = true;
                }
            } else {
                if (cap > 15 || batteryCharging) {
                    lowBatteryNotified = false;
                }
            }
        }
    }

    Timer {
        id: batteryPillTimer
        interval: 5000 // 5 s — gives enough time to read after the spring animation expands
        repeat: false
        onTriggered: {
            if (root.islandState === root.stateBatteryLow || root.islandState === root.stateCharging) {
                root.islandState = root.prevIslandState;
            }
        }
    }

    // Guard: never let prevIslandState be a transient state (prevents chaining)
    readonly property var _transientStates: [root.stateOsd, root.stateBatteryLow, root.stateCharging, root.stateDnd, root.stateWaterAlert, root.stateStretchAlert, root.stateF1Alert, root.stateCpuAlert, root.stateDragLocalSend, root.stateLocalSendSuccess, root.stateDiskAlert]

    function safeSavePrev() {
        if (_transientStates.indexOf(root.islandState) === -1) {
            root.prevIslandState = root.islandState;
        }
    }

    function playSoundSafely(proc) {
        proc.running = false;
        proc.running = true;
    }

    property bool triggerDndPillOnClose: false
    property bool lastDndActive: false
    onDndActiveChanged: {
        if (dndActive !== lastDndActive) {
            if (groundControl.visible) {
                root.triggerDndPillOnClose = true;
            } else {
                root.safeSavePrev();
                root.islandState = root.stateDnd;
                dndPillTimer.restart();
            }
        }
        lastDndActive = dndActive;
    }

    Connections {
        target: groundControl
        function onShowChanged() {
            if (!groundControl.show && root.triggerDndPillOnClose) {
                root.triggerDndPillOnClose = false;
                root.safeSavePrev();
                root.islandState = root.stateDnd;
                dndPillTimer.restart();
            }
        }
    }

    Timer {
        id: dndPillTimer
        interval: 3000
        repeat: false
        onTriggered: {
            if (root.islandState === root.stateDnd) {
                root.islandState = root.prevIslandState;
            }
        }
    }

    // Health reminder configurations
    property bool healthRemindersActive: true
    property int waterInterval: 2700000 // 45 minutes
    property int stretchInterval: 3000000 // 50 minutes

    function resetWaterTimer() {
        waterReminderTimer.restart();
    }

    function resetStretchTimer() {
        stretchReminderTimer.restart();
    }

    Timer {
        id: waterReminderTimer
        interval: root.waterInterval
        running: root.healthRemindersActive
        repeat: true
        onTriggered: {
            root.safeSavePrev();
            root.islandState = root.stateWaterAlert;
            healthAlertTimer.restart();
            queueNotification(["notify-send", "-u", "normal", "-i", "water", "Hydration Reminder", "Time to drink some water!"]);
            playSoundSafely(pPlaySound);
        }
    }

    Timer {
        id: stretchReminderTimer
        interval: root.stretchInterval
        running: root.healthRemindersActive
        repeat: true
        onTriggered: {
            root.safeSavePrev();
            root.islandState = root.stateStretchAlert;
            healthAlertTimer.restart();
            queueNotification(["notify-send", "-u", "normal", "-i", "stretch", "Sedentary Reminder", "Time to stand up and stretch!"]);
            playSoundSafely(pPlaySound);
        }
    }

    Timer {
        id: healthAlertTimer
        interval: 12000 // Display alert for 12 seconds
        repeat: false
        onTriggered: {
            if (root.islandState === root.stateWaterAlert || root.islandState === root.stateStretchAlert) {
                root.islandState = root.prevIslandState;
            }
        }
    }

    // Non-visual background helpers and single-shot process managers
    Process {
        id: pPavu
        command: ["pavucontrol"]
    }
    Process {
        id: pMicMute
        command: ["wpctl", "set-mute", "@DEFAULT_AUDIO_SOURCE@", "toggle"]
        onExited: pVolumeMic.running = true
    }
    Process {
        id: pVolMute
        command: ["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]
        onExited: pVolumeOut.running = true
    }
    Process {
        id: pVolSet
        onExited: pVolumeOut.running = true
    } // Dynamic volume setter (speaker)
    Process {
        id: pVolSetMic
        onExited: pVolumeMic.running = true
    } // Dynamic volume setter (microphone)
    Process {
        id: pBlueberry
        command: ["blueberry"]
    }

    property var tempSinks: []
    ListModel {
        id: sinkModel
    }
    ListModel {
        id: notifList
    }
    Process {
        id: pSetSink
    }
    Process {
        id: pListSinks
        command: [root.scriptsDir + "/list_sinks.sh"]
        stdout: SplitParser {
            onRead: data => {
                var line = data.trim();
                if (line === "")
                    return;
                var parts = line.split("|");
                if (parts.length >= 3) {
                    root.tempSinks.push({
                        "sinkId": parseInt(parts[0]),
                        "isActive": parts[1] === "true",
                        "name": parts[2]
                    });
                }
            }
        }
        onRunningChanged: {
            if (running) {
                root.tempSinks = [];
            } else {
                sinkModel.clear();
                var activeName = "Default Output";
                for (var i = 0; i < root.tempSinks.length; i++) {
                    sinkModel.append(root.tempSinks[i]);
                    if (root.tempSinks[i].isActive) {
                        activeName = root.tempSinks[i].name;
                    }
                }
                root.activeSinkName = activeName;
            }
        }
    }

    // M-3/M-4 FIX: re-poll wifi/bt state on toggle failure so UI reverts
    Process {
        id: pWifiToggle
        command: ["sh", "-c", "if [ \"$(nmcli radio wifi)\" = \"enabled\" ]; then nmcli radio wifi off; else nmcli radio wifi on; fi"]
        onExited: code => {
            if (code !== 0)
                pWifi.running = true;
            pTriggerStatsUpdate.running = true;
        }
    }
    Process {
        id: pBtToggle
        command: ["sh", "-c", "if bluetoothctl show | grep -q 'Powered: yes'; then rfkill block bluetooth; else rfkill unblock bluetooth; fi"]
        onExited: code => {
            if (code !== 0)
                pBluetooth.running = true;
            pTriggerStatsUpdate.running = true;
        }
    }
    Process {
        id: pWifiOn
        command: ["nmcli", "radio", "wifi", "on"]
        onExited: code => pTriggerStatsUpdate.running = true
    }
    Process {
        id: pWifiOff
        command: ["nmcli", "radio", "wifi", "off"]
        onExited: code => pTriggerStatsUpdate.running = true
    }
    Process {
        id: pBtOn
        command: ["rfkill", "unblock", "bluetooth"]
        onExited: code => pTriggerStatsUpdate.running = true
    }
    Process {
        id: pBtOff
        command: ["rfkill", "block", "bluetooth"]
        onExited: code => pTriggerStatsUpdate.running = true
    }

    // Optimized Single-shot battery checker via helper script
    property bool firstBatteryPoll: true  // suppress spurious charging alert on startup

    Process {
        id: pSpotPrev
        command: ["playerctl", "-p", "spotify,Brave,brave,Chromium,chromium,Firefox,firefox,mpd", "previous"]
    }

    // pBright and timer removed; stats daemon handles periodic brightness polling.

    Timer {
        id: stopwatchTimer
        interval: 1000
        running: root.stopwatchRunning
        repeat: true
        onTriggered: {
            root.stopwatchSeconds++;
            root.stopwatchText = root.formatTime(root.stopwatchSeconds);
        }
    }

    Timer {
        id: timerTimer
        interval: 1000
        running: root.timerRunning
        repeat: true
        onTriggered: {
            if (root.timerSeconds > 0) {
                root.timerSeconds--;
                root.timerText = root.formatTime(root.timerSeconds);
            } else {
                if (root.pomodoroState === 1) {
                    root.pomodoroState = 2;
                    root.timerTotal = root.pomodoroBreakTotal;
                    root.timerSeconds = root.timerTotal;
                    root.timerText = root.formatTime(root.timerTotal);
                    queueNotification(["notify-send", "-u", "critical", "-i", "timer", "Pomodoro", "Work session finished! Time for a break."]);
                    playSoundSafely(pPlayTimerSound);
                } else if (root.pomodoroState === 2) {
                    root.pomodoroState = 1;
                    root.timerTotal = root.pomodoroWorkTotal;
                    root.timerSeconds = root.timerTotal;
                    root.timerText = root.formatTime(root.timerTotal);
                    queueNotification(["notify-send", "-u", "normal", "-i", "timer", "Pomodoro", "Break finished! Back to work."]);
                    playSoundSafely(pPlayTimerSound);
                } else {
                    root.timerRunning = false;
                    queueNotification(["notify-send", "-u", "critical", "-i", "timer", "Timer", "Timer finished!"]);
                    playSoundSafely(pPlayTimerSound);
                }
            }
        }
    }

    property var _notifyQueue: []
    function queueNotification(cmdArgs) {
        _notifyQueue.push(cmdArgs);
        if (!pNotify.running) {
            _runNextNotification();
        }
    }
    function _runNextNotification() {
        if (_notifyQueue.length > 0) {
            pNotify.command = _notifyQueue.shift();
            pNotify.running = true;
        }
    }

    Process {
        id: pNotify
        onExited: root._runNextNotification()
    }
    Process {
        id: pPlaySound
        command: ["mpv", "--no-video", "--load-scripts=no", "--af=lavfi=[adelay=800|800]", "/usr/share/sounds/freedesktop/stereo/message.oga"]
    }
    Process {
        id: pPlayTimerSound
        command: ["mpv", "--no-video", "--load-scripts=no", "--af=lavfi=[adelay=800|800]", "/usr/share/sounds/freedesktop/stereo/complete.oga"]
    }
    Process {
        id: pPlayPowerPlug
        command: ["mpv", "--no-video", "--load-scripts=no", "--af=lavfi=[adelay=800|800]", "/usr/share/sounds/ocean/stereo/power-plug.oga"]
    }
    Process {
        id: pPlayPowerUnplug
        command: ["mpv", "--no-video", "--load-scripts=no", "--af=lavfi=[adelay=800|800]", "/usr/share/sounds/ocean/stereo/power-unplug.oga"]
    }

    Process {
        id: pBrightSet
        command: [] // command is always set dynamically before running
    }

    Process {
        id: pSpotPlay
        command: ["playerctl", "-p", "spotify,Brave,brave,Chromium,chromium,Firefox,firefox,mpd", "play-pause"]
    }
    Process {
        id: pSpotNext
        command: ["playerctl", "-p", "spotify,Brave,brave,Chromium,chromium,Firefox,firefox,mpd", "next"]
    }

    Process {
        id: pLockScreen
        command: [root.scriptsDir + "/screenlock.sh"]
    }

    Process {
        id: pScreenshotSel
        command: ["hyprctl", "dispatch", "hl.dsp.exec_cmd(\"" + root.scriptsDir + "/screenshot.sh --sel\")"]
    }
    Process {
        id: pScreenshotNow
        command: ["hyprctl", "dispatch", "hl.dsp.exec_cmd(\"" + root.scriptsDir + "/screenshot.sh --now\")"]
    }
    Process {
        id: pOcrShot
        command: ["hyprctl", "dispatch", "hl.dsp.exec_cmd(\"" + root.scriptsDir + "/screenshot.sh --ocr\")"]
    }
    Process {
        id: pColorPicker
        command: ["hyprctl", "dispatch", "hl.dsp.exec_cmd(\"hyprpicker -a\")"]
    }
    Process {
        id: pRecordSel
        command: ["hyprctl", "dispatch", "hl.dsp.exec_cmd(\"" + root.scriptsDir + "/screenshot.sh --record-sel\")"]
    }
    Process {
        id: pRecordFull
        command: ["hyprctl", "dispatch", "hl.dsp.exec_cmd(\"" + root.scriptsDir + "/screenshot.sh --record\")"]
    }
    Process {
        id: pStopRecord
        command: [root.scriptsDir + "/screenshot.sh", "--stop"]
    }

    Timer {
        id: recordingTimer
        interval: 1000
        repeat: true
        running: false
        onTriggered: {
            root.recordingSeconds++;
            var m = Math.floor(root.recordingSeconds / 60);
            var s = root.recordingSeconds % 60;
            root.recordingTime = m + ":" + (s < 10 ? "0" + s : s);
        }
    }

    Process {
        id: pWallTheme
        command: ["hyprctl", "dispatch", "hl.dsp.exec_cmd(\"" + root.scriptsDir + "/WallSelect.sh\")"]
    }

    Process {
        id: pCyclePowerProfile
        command: ["sh", "-c", "current=$(powerprofilesctl get); if [ \"$current\" = \"balanced\" ]; then powerprofilesctl set performance; elif [ \"$current\" = \"performance\" ]; then powerprofilesctl set power-saver; else powerprofilesctl set balanced; fi"]
        onRunningChanged: {
            if (!running) {
                pTriggerStatsUpdate.running = false;
                pTriggerStatsUpdate.running = true;
            }
        }
    }

    // Local DND property managed internally since Quickshell handles notifications, not Dunst
    // root.dndActive is defined at the top

    // Top CPU Process warning alert system
    Process {
        id: pTopCpu
        command: ["bash", "-c", "ps -Ao pcpu,comm --sort=-pcpu | tail -n +2 | head -n 1 | awk '{print $2 \" (\" $1 \"%)\"}'"]
        stdout: SplitParser {
            onRead: data => {
                var processName = data.trim();
                if (processName) {
                    root.topCpuProcess = processName;
                    root.safeSavePrev();
                    root.islandState = root.stateCpuAlert;
                    cpuAlertTimer.restart();
                    queueNotification(["notify-send", "-u", "critical", "-i", "thermal-hot", "CPU Temperature High", "CPU is at " + root.temperature + "°C. Top process: " + root.topCpuProcess]);
                    playSoundSafely(pPlaySound);
                }
            }
        }
    }

    Timer {
        id: cpuAlertTimer
        interval: 12000 // 12 seconds
        repeat: false
        onTriggered: {
            if (root.islandState === root.stateCpuAlert) {
                root.islandState = root.prevIslandState;
            }
        }
    }

    Timer {
        id: diskAlertTimer
        interval: 3500 // 3.5 seconds
        repeat: false
        onTriggered: {
            if (root.islandState === root.stateDiskAlert) {
                root.islandState = root.prevIslandState;
            }
        }
    }

    Process {
        id: pDiskMonitor
        command: ["python3", root.scriptsDir + "/disk_monitor.py"]
        running: true
        stdout: SplitParser {
            onRead: function(data) {
                try {
                    var parts = data.trim().split("|");
                    if (parts.length >= 3) {
                        var isAdd = parts[0] === "add";
                        root.diskAlertTitle = parts[1];
                        root.diskAlertSubtitle = parts[2];
                        root.diskAlertMounted = isAdd;
                        root.safeSavePrev();
                        root.islandState = root.stateDiskAlert;
                        diskAlertTimer.restart();
                        playSoundSafely(pPlaySound);
                    }
                } catch(e) {}
            }
        }
    }



    Timer {
        id: localSendTimer
        interval: root.localSendDismissDelay
        repeat: false
        onTriggered: {
            root.islandState = root.stateCompact;
        }
    }

    Process {
        id: pLocalSend
    }

    // F1 Calendar telemetry checkers
    Process {
        id: pF1Next
        command: [root.scriptsDir + "/f1_checker.py", "--next"]
        stdout: SplitParser {
            onRead: data => {
                var val = data.trim();
                if (val && val !== "No upcoming events") {
                    var parts = val.split("|");
                    if (parts.length >= 3) {
                        root.f1NextEventName = parts[0];
                        root.f1NextEventTime = parts[1];
                        root.f1NextEventLocation = parts[2];
                        root.f1NextEventIso = parts.length >= 4 ? parts[3] : "";
                    }
                } else {
                    root.f1NextEventName = "";
                    root.f1NextEventTime = "";
                    root.f1NextEventLocation = "";
                    root.f1NextEventIso = "";
                }
            }
        }
    }

    Process {
        id: pF1List
        command: [root.scriptsDir + "/f1_checker.py", "--list"]
        stdout: SplitParser {
            onRead: data => {
                var lines = data.trim().split("\n");
                var formatted = [];
                for (var i = 0; i < lines.length; i++) {
                    var l = lines[i].trim();
                    if (l) {
                        l = l.replace("|", " • ");
                        formatted.push(l);
                    }
                }
                root.f1ListText = formatted.join("\n");
            }
        }
    }

    Process {
        id: pF1MainRace
        command: [root.scriptsDir + "/f1_checker.py", "--this-week-race"]
        stdout: SplitParser {
            onRead: data => {
                var val = data.trim();
                if (val && val !== "No upcoming race") {
                    var parts = val.split("|");
                    if (parts.length >= 2) {
                        var name = parts[0].replace(": 🏁 Race", "").trim();
                        root.f1MainRaceText = name + " • " + parts[1];
                    }
                } else {
                    root.f1MainRaceText = "";
                }
            }
        }
    }

    Process {
        id: pF1Alert
        command: [root.scriptsDir + "/f1_checker.py", "--alert"]
        stdout: SplitParser {
            onRead: data => {
                var val = data.trim();
                if (val && val !== "NO_ALERT" && val.startsWith("ALERT|")) {
                    var parts = val.split("|");
                    if (parts.length >= 4) {
                        root.f1AlertName = parts[1];
                        root.f1AlertMins = parts[2];
                        root.f1AlertTime = parts[3];
                        root.safeSavePrev();
                        root.islandState = root.stateF1Alert;
                        f1AlertTimer.restart();

                        queueNotification(["notify-send", "-u", "normal", "-i", "f1", "F1 Session Starting", root.f1AlertName + " starts in " + root.f1AlertMins + "m (at " + root.f1AlertTime + ")"]);
                        playSoundSafely(pPlaySound);
                    }
                }
            }
        }
    }

    Timer {
        id: f1AlertTimer
        interval: 15000 // 15 seconds
        repeat: false
        onTriggered: {
            if (root.islandState === root.stateF1Alert) {
                root.islandState = root.prevIslandState;
            }
        }
    }

    property bool f1Enabled: true

    Timer {
        id: f1CheckerTimer
        interval: 1800000 // every 30 minutes
        running: root.f1Enabled
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            pF1Next.running = false;
            pF1Next.running = true;
            pF1List.running = false;
            pF1List.running = true;
            pF1MainRace.running = false;
            pF1MainRace.running = true;
        }
    }

    Timer {
        id: f1AlertCheckerTimer
        interval: 60000 // every 1 minute
        running: root.f1Enabled
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (root.f1NextEventName !== "") {
                pF1Alert.running = false;
                pF1Alert.running = true;
            }
        }
    }

    Process {
        id: pPrivacyMonitor
        running: true
        command: ["bash", "-c", "while true; do mic=$(pactl list source-outputs short 2>/dev/null); cam=$(fuser /dev/video* 2>/dev/null); echo \"$mic|$cam\"; sleep 2; done"]
        stdout: SplitParser {
            onRead: data => {
                var line = data.trim();
                if (line === "") return;
                var parts = line.split('|');
                root.isMicActive = (parts[0].trim().length > 0);
                root.isCamActive = (parts[1].trim().length > 0);
            }
        }
    }

    // Unified Status and Telemetry Daemon
    Process {
        id: pStats
        running: true
        command: [Quickshell.shellDir + "/scripts/quickshell_stats.sh"]
        stdout: SplitParser {
            onRead: data => {
                var d = data.trim();
                if (d === "")
                    return;
                try {
                    var stats = JSON.parse(d);

                    // Assign CPU / RAM properties and update charts
                    var cpu = stats.cpu;
                    var ram = stats.ram;
                    if (root.cpuUsage !== cpu.toString()) root.cpuUsage = cpu.toString();
                    if (root.ramUsage !== ram.toString()) root.ramUsage = ram.toString();

                    var cHistory = root.cpuHistory.slice();
                    cHistory.shift();
                    cHistory.push(cpu);
                    root.cpuHistory = cHistory;

                    var rHistory = root.ramHistory.slice();
                    rHistory.shift();
                    rHistory.push(ram);
                    root.ramHistory = rHistory;

                    // Assign battery properties
                    var newCharging = stats.battery_charging;
                    if (root.firstBatteryPoll) {
                        root.lastBatteryCharging = newCharging;
                        root.firstBatteryPoll = false;
                    }
                    if (root.batteryCharging !== newCharging) root.batteryCharging = newCharging;
                    if (root.batteryCap !== stats.battery_cap.toString()) root.batteryCap = stats.battery_cap.toString();
                    if (root.batteryTimeStr !== stats.battery_time) root.batteryTimeStr = stats.battery_time;

                    // Assign brightness
                    if (root.brightnessLevel !== stats.brightness) root.brightnessLevel = stats.brightness;

                    // Assign power draw & temperature
                    if (root.powerDraw !== stats.power_draw) root.powerDraw = stats.power_draw;
                    if (root.temperature !== stats.temperature.toString()) root.temperature = stats.temperature.toString();

                    // Assign bluetooth
                    if (root.bluetoothStatus !== stats.bluetooth_status) root.bluetoothStatus = stats.bluetooth_status;
                    if (root.bluetoothDevice !== stats.bluetooth_device) root.bluetoothDevice = stats.bluetooth_device;

                    // Assign wifi
                    root.wifiEnabled = stats.wifi_enabled;
                    if (!root.wifiEnabled) {
                        root.wifiIcon = "󰤮";
                        root.wifiText = "Off";
                        root.wifiSsid = "";
                        root.wifiIp = "";
                    } else if (stats.wifi_ssid === "") {
                        root.wifiIcon = "󰤮";
                        root.wifiText = "Disconnected";
                        root.wifiSsid = "";
                        root.wifiIp = "";
                    } else {
                        root.wifiSsid = stats.wifi_ssid;
                        var s = parseInt(stats.wifi_strength);
                        root.wifiText = s + "%";
                        root.wifiIp = stats.wifi_ip ? stats.wifi_ip : "";
                        if (s > 80)
                            root.wifiIcon = "󰤨";
                        else if (s > 60)
                            root.wifiIcon = "󰤥";
                        else if (s > 40)
                            root.wifiIcon = "󰤢";
                        else if (s > 20)
                            root.wifiIcon = "󰤟";
                        else
                            root.wifiIcon = "󰤯";
                    }

                    // Assign redshift & caffeine
                    root.redshiftActive = stats.redshift_active;
                    root.caffeineActive = stats.caffeine_active;

                    // Assign power profile
                    root.powerProfile = stats.power_profile;
                    root.batteryMode = (stats.power_profile === "power-saver");

                    // Assign emails if present
                    if (stats.emails) {
                        root.todayEmailsCount = stats.emails.today_count;
                        root.hourEmailsCount = stats.emails.hour_count || 0;
                        root.latestEmails = stats.emails.latest;
                    }
                } catch (e) {
                    console.log("Error parsing quickshell_stats JSON: " + e + " | Data: " + d);
                }
            }
        }
        Component.onDestruction: pStats.running = false
    }

    Process {
        id: pTriggerStatsUpdate
        command: ["pkill", "-USR1", "-f", "quickshell_stats.sh"]
    }

    // Optimized checkupdates
    Process {
        id: pUpdates
        command: ["sh", "-c", "checkupdates 2>/dev/null | wc -l"]
        stdout: SplitParser {
            onRead: data => root.updates = data.trim()
        }
    }
    Timer {
        interval: 3600000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: pUpdates.running = true
    }

    // Optimized volume query (runs single-shot on timer and is manual triggered)
    Process {
        id: pVolumeOut
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
        stdout: SplitParser {
            onRead: data => {
                var d = data.trim();
                root.volumeMuted = d.includes("[MUTED]");
                var m = d.match(/[0-9.]+/);
                if (m)
                    root.volumeOut = Math.round(parseFloat(m[0]) * 100) + "%";
            }
        }
    }
    Process {
        id: pVolumeMic
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SOURCE@"]
        stdout: SplitParser {
            onRead: data => {
                var d = data.trim();
                root.micMuted = d.includes("[MUTED]");
                var m = d.match(/[0-9.]+/);
                if (m)
                    root.volumeMic = Math.round(parseFloat(m[0]) * 100) + "%";
            }
        }
    }
    // Volume polling Timer removed; stats daemon handles periodic volume polling.

    Process {
        id: pRedshiftToggle
        command: ["sh", "-c", "~/dotfiles/scripts/Redshift.sh --toggle >/dev/null 2>&1"]
        onExited: {
            pTriggerStatsUpdate.running = false;
            pTriggerStatsUpdate.running = true;
        }
    }

    Process {
        id: pCaffeineToggle
        command: ["sh", "-c", "if systemctl --user is-active hypridle >/dev/null 2>&1 || pgrep -x hypridle >/dev/null 2>&1; then systemctl --user stop hypridle 2>/dev/null; pkill -x hypridle 2>/dev/null; true; else systemctl --user start hypridle 2>/dev/null || (hypridle & disown); fi"]
        onExited: {
            pTriggerStatsUpdate.running = false;
            pTriggerStatsUpdate.running = true;
        }
    }

    // Keybindings menu launcher
    Process {
        id: pKeybindings
        command: ["python3", root.scriptsDir + "/keybindings.py"]
    }

    property bool hasPlayerctl: false
    Process {
        id: pCleanupPlayerctl
        command: ["pkill", "-f", "playerctl -F -p spotify,Brave,brave,Chromium,chromium,Firefox,firefox,mpd"]
        onExited: {
            pCheckPlayerctl.running = true;
        }
        Component.onCompleted: running = true
    }

    Process {
        id: pCheckPlayerctl
        running: false
        command: ["which", "playerctl"]
        onExited: code => {
            if (code === 0) {
                root.hasPlayerctl = true;
                pSpotify.running = true;
            }
        }
    }

    Timer {
        id: pSpotifyRestartTimer
        interval: 10000 // Retry every 10 seconds if players are closed/inactive
        repeat: false
        onTriggered: {
            if (root.hasPlayerctl && !pSpotify.running) {
                pSpotify.running = true;
            }
        }
    }

    // Persistent media status tracker using playerctl follow mode
    Process {
        id: pSpotify
        running: false
        command: ["playerctl", "-F", "-p", "spotify,Brave,brave,Chromium,chromium,Firefox,firefox,mpd", "metadata", "--format", "{{status}}|@|{{title}} - {{artist}}|@|{{mpris:artUrl}}|@|{{mpris:length}}"]
        stdout: SplitParser {
            onRead: data => {
                var d = data.trim();
                if (d === "")
                    return;
                var parts = d.split("|@|");
                if (parts.length >= 2) {
                    root.spotifyStatus = parts[0].trim().toLowerCase();
                    root.spotifyText = parts[1].trim();
                    if (parts.length >= 3) {
                        root.spotifyArtUrl = parts[2].trim();
                    } else {
                        root.spotifyArtUrl = "";
                    }
                    if (parts.length >= 4) {
                        var lenUsec = parseInt(parts[3].trim());
                        if (!isNaN(lenUsec)) {
                            root.spotifyLength = lenUsec / 1000000.0;
                            root.spotifyLengthStr = root.formatTime(root.spotifyLength);
                        } else {
                            root.spotifyLength = 0;
                            root.spotifyLengthStr = "0:00";
                        }
                    } else {
                        root.spotifyLength = 0;
                        root.spotifyLengthStr = "0:00";
                    }
                }
            }
        }
        onRunningChanged: {
            if (!running) {
                root.spotifyStatus = "offline";
                root.spotifyText = "";
                root.spotifyArtUrl = "";
                root.spotifyLength = 0;
                root.spotifyLengthStr = "0:00";
                root.spotifyPosition = 0;
                root.spotifyPositionStr = "0:00";
                if (root.hasPlayerctl && !root.isDestroying) {
                    pSpotifyRestartTimer.restart();
                }
            }
        }
        Component.onDestruction: pSpotify.running = false
    }



    Timer {
        id: spotifyPositionTimer
        interval: 1000
        running: root.spotifyStatus === "playing"
        repeat: true
        onTriggered: pGetPosition.running = true
    }

    Process {
        id: pGetPosition
        command: ["playerctl", "-p", "spotify,Brave,brave,Chromium,chromium,Firefox,firefox,mpd", "position"]
        stdout: StdioCollector {
            onStreamFinished: {
                var p = parseFloat(text.trim());
                if (!isNaN(p)) {
                    root.spotifyPosition = p;
                    root.spotifyPositionStr = root.formatTime(p);
                }
            }
        }
    }

    Process {
        id: pSpotSeek
        property double pos: 0
        command: ["playerctl", "-p", "spotify,Brave,brave,Chromium,chromium,Firefox,firefox,mpd", "position", pos.toFixed(0)]
    }

    function seekTrack(seconds) {
        pSpotSeek.pos = seconds;
        pSpotSeek.running = true;
        root.spotifyPosition = seconds;
        root.spotifyPositionStr = root.formatTime(seconds);
    }

    function getLuminance(c) {
        var colorObj = Qt.color(c);
        var r = colorObj.r;
        var g = colorObj.g;
        var b = colorObj.b;
        
        var rL = (r <= 0.04045) ? (r / 12.92) : Math.pow((r + 0.055) / 1.055, 2.4);
        var gL = (g <= 0.04045) ? (g / 12.92) : Math.pow((g + 0.055) / 1.055, 2.4);
        var bL = (b <= 0.04045) ? (b / 12.92) : Math.pow((b + 0.055) / 1.055, 2.4);
        
        return 0.2126 * rL + 0.7152 * gL + 0.0722 * bL;
    }

    function ensureContrast(accentColor, minRatio) {
        var c = Qt.color(accentColor);
        var bgL = 0.008; // Luminance of dark card background
        
        var ratio = 0;
        var maxIter = 10;
        var iter = 0;
        
        var h = c.hslHue;
        var s = c.hslSaturation;
        var l = c.hslLightness;
        
        if (h === -1) h = 0;
        
        var currentL = l;
        var resultColor = c;
        
        while (iter < maxIter) {
            var accentL = getLuminance(resultColor);
            ratio = (accentL + 0.05) / (bgL + 0.05);
            if (ratio >= minRatio) {
                break;
            }
            currentL = currentL + (1.0 - currentL) * 0.25;
            resultColor = Qt.hsla(h, s, currentL, c.a);
            iter++;
        }
        
        return resultColor;
    }

    Process {
        id: pGetWalColors
        command: ["cat", "/home/lumi/.cache/wal/colors.json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(text.trim());
                    if (data && data.colors) {
                        var rawAccent1 = data.colors.color1;
                        var rawAccent2 = data.colors.color2;
                        root.colAccent = root.ensureContrast(rawAccent1, 3.2);
                        root.colAccentSecondary = root.ensureContrast(rawAccent2, 3.2);
                    }
                } catch (e) {
                    console.warn("Failed to parse pywal colors:", e);
                }
            }
        }
    }

    function reloadWalColors() {
        pGetWalColors.running = true;
    }

    Process {
        id: pWeather
        command: [root.scriptsDir + "/weather.sh", "current_temp"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                root.weatherText = data.trim();
            }
        }
    }
    Timer {
        interval: 600000
        running: true
        repeat: true
        onTriggered: pWeather.running = true
    }

    PanelWindow {
        id: barWindow
        anchors.top: true
        anchors.left: true
        anchors.right: true
        // Fixed height: never resize the Wayland surface (eliminates compositor jitter).
        // The notch springs inside this fixed viewport; extra space is transparent.
        implicitHeight: Math.round(76 * scaleFactor)
        color: "transparent"

        WlrLayershell.namespace: "quickshell_bar"
        WlrLayershell.exclusiveZone: Math.round(44 * scaleFactor)

        DropArea {
            id: localSendDropArea
            anchors.fill: parent
            
            onEntered: (drag) => {
                if (drag.hasUrls || drag.hasText) {
                    drag.accept(Qt.CopyAction);
                    root.safeSavePrev();
                    root.islandState = root.stateDragLocalSend;
                }
            }
            
            onExited: {
                if (root.islandState === root.stateDragLocalSend) {
                    root.islandState = root.prevIslandState;
                }
            }
            
            onDropped: (drop) => {
                if (drop.hasUrls) {
                    drop.accept(Qt.CopyAction);
                    
                    var paths = [];
                    for (var i = 0; i < drop.urls.length; i++) {
                        var urlStr = drop.urls[i].toString();
                        var cleanPath = decodeURIComponent(urlStr);
                        if (cleanPath.indexOf("file://") === 0) {
                            cleanPath = cleanPath.substring(7);
                        }
                        paths.push(cleanPath);
                    }
                    
                    if (paths.length > 0) {
                        pLocalSend.command = ["localsend"].concat(paths);
                        pLocalSend.running = true;
                        
                        root.islandState = root.stateLocalSendSuccess;
                        localSendTimer.restart();
                    } else {
                        root.islandState = root.prevIslandState;
                    }
                } else if (drop.hasText) {
                    drop.accept(Qt.CopyAction);
                    pLocalSend.command = ["sh", "-c", "echo -n \"$1\" > /tmp/shared_text.txt && localsend /tmp/shared_text.txt", "--", drop.text];
                    pLocalSend.running = true;
                    
                    root.islandState = root.stateLocalSendSuccess;
                    localSendTimer.restart();
                } else {
                    root.islandState = root.prevIslandState;
                }
            }
        }

        Rectangle {
            id: notchRect
            opacity: root.isAnyPopupOpen ? 0.0 : 1.0
            visible: opacity > 0.0

            anchors.top: parent.top
            anchors.topMargin: root.topHuggingStyle ? 0 : 4 * scaleFactor
            anchors.horizontalCenter: parent.horizontalCenter

            // Dark glassmorphic background with gradient
            color: Qt.rgba(0.05, 0.05, 0.05, 0.95)

            // Dynamic heights and widths matching Apple Dynamic Island transitions
            clip: true
            // LocalSend expands taller for a dramatic dock-style pop
            height: (root.islandState === root.stateDragLocalSend || root.islandState === root.stateLocalSendSuccess)
                    ? 70 * scaleFactor
                    : 40 * scaleFactor
            width: root.isAnyPopupOpen ? (36 * scaleFactor) : root.closedNotchWidth
            radius: (root.islandState === root.stateDragLocalSend || root.islandState === root.stateLocalSendSuccess)
                    ? 24 * scaleFactor
                    : 20 * scaleFactor

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

            // GPU texture cache: prevents clip:true from re-rendering all children every frame.
            layer.enabled: !root.batteryMode

            Connections {
                target: root
                function onIslandStateChanged() {
                    if (root.batteryMode) return;
                    // Skip scale-pop for LocalSend — the springy height expansion handles it
                    var s = root.islandState;
                    if (s === root.stateDragLocalSend || s === root.stateLocalSendSuccess) return;
                    popSequence.restart();
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

            border.color: Qt.rgba(1, 1, 1, 0.08) // Sleek premium glass border
            border.width: 1

            MouseArea {
                anchors.fill: parent
                enabled: root.islandState !== root.stateCompact
                onClicked: {
                    root.islandState = root.stateCompact; // normal body clicks revert to main pill
                }
            }

            RowLayout {
                id: notchLayout
                // Width check removed: clip:true on notchRect already prevents overflow;
                // the old threshold caused flicker whenever closedNotchWidth changed slightly.
                opacity: (root.islandState === root.stateCompact && !root.isAnyPopupOpen) ? 1.0 : 0.0
                visible: opacity > 0.0
                enabled: root.islandState === root.stateCompact && !root.isAnyPopupOpen
                scale: opacity > 0 ? 1.0 : 0.9
                Behavior on opacity {
                    NumberAnimation {
                        duration: root.batteryMode ? 150 : 250
                        easing.type: Easing.OutQuad
                    }
                }
                Behavior on scale {
                    enabled: true
                    SpringAnimation {
                        spring: 4.8
                        damping: 0.8
                        mass: 0.6
                    }
                }
                layer.enabled: (opacity > 0.0 && opacity < 1.0) && !root.batteryMode
                anchors.centerIn: parent
                height: 32
                spacing: Math.round(12 * scaleFactor)

                Repeater {
                    model: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
                    NotchMod {
                    shellRoot: root
                        hoverColor: "transparent"
                        activeColor: "transparent"
                        property var ws: Hyprland.workspaces.values.find(w => w.id === modelData)
                        property bool isActive: Hyprland.focusedWorkspace != null && Hyprland.focusedWorkspace.id === modelData
                        show: (ws !== undefined || isActive)
                        customWidth: isActive ? 16 : (containsMouse ? 12 : 8)
                        onClicked: Hyprland.dispatch("hl.dsp.focus({ workspace = \"" + modelData + "\" })")

                        Rectangle {
                            id: wsDot
                            anchors.centerIn: parent
                            width: isActive ? 14 : (containsMouse ? 10 : 6)
                            height: 6
                            radius: 3
                            color: isActive ? "#ffffff" : root.colMuted
                            // Target opacity — the Behavior below smoothly drives toward this.
                            // On hover: dot fades out after a short delay so the number leads.
                            // On exit:  dot fades back in immediately so there's no gap.
                            opacity: containsMouse ? 0.0 : (isActive ? 1.0 : 0.4)
                            Behavior on width {
                                enabled: true
                                SpringAnimation {
                                    spring: 3.0
                                    damping: 0.6
                                    mass: 0.8
                                }
                            }
                                           Behavior on color {
                                ColorAnimation {
                                     duration: root.batteryMode ? 150 : 200
                                }
                            }
                            // Crossfade: when hiding (going to 0) delay 60 ms so the number
                            // has already started appearing before the dot begins to leave.
                            // When showing (going to non-zero) animate instantly so there is
                            // never a moment where both are invisible on mouse-exit.
                            Behavior on opacity {
                                SequentialAnimation {
                                    PauseAnimation {
                                        // Only pause when fading OUT (dot hides on hover).
                                        // wsDot.opacity hasn't updated yet here, so we check
                                        // the mouse state directly.
                                        duration: (!root.batteryMode && containsMouse) ? 60 : 0
                                    }
                                    NumberAnimation {
                                        duration: root.batteryMode ? 100 : 130
                                        easing.type: Easing.OutQuad
                                    }
                                }
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: modelData.toString()
                            color: isActive ? "#ffffff" : root.colFg
                            font {
                                family: root.fontFamily
                                pixelSize: 9
                                bold: true
                            }
                            // Number leads: fades in fast, fades out slightly slower so
                            // the dot is already reappearing before the number is gone.
                            opacity: containsMouse ? 1.0 : 0.0
                            scale: containsMouse ? 1.0 : 0.5
                            Behavior on opacity {
                                NumberAnimation {
                                    duration: root.batteryMode ? 100 : (containsMouse ? 100 : 160)
                                    easing.type: Easing.OutQuad
                                }
                            }
                            Behavior on scale {
                                enabled: true
                                SpringAnimation {
                                    spring: 3.0
                                    damping: 0.6
                                    mass: 0.8
                                }
                            }
                        }
                    }
                }

                NotchMod {
                    shellRoot: root
                    hoverColor: "transparent"
                    activeColor: "transparent"
                    show: root.dndActive
                    onClicked: {
                        root.islandState = root.stateDnd;
                        dndPillTimer.restart();
                    }
                    Text {
                        text: "󰂛"
                        color: "#FF3B30"
                        font {
                            family: root.iconFontFamily
                            pixelSize: 12
                            bold: true
                        }
                    }
                }

                NotchMod {
                    shellRoot: root
                    id: batteryMod
                    hoverColor: "transparent"
                    activeColor: "transparent"
                    property int cap: parseInt(root.batteryCap)
                    property bool isCrit: cap <= 15 && !root.batteryCharging
                    property bool isWarn: cap <= 30 && cap > 15 && !root.batteryCharging
                    show: true
                    onClicked: groundControl.show = true

                    RowLayout {
                        spacing: 6
                        Text {
                            text: root.batteryCap + "%"
                            color: batteryMod.isCrit ? root.colCrit : (batteryMod.isWarn ? root.colWarn : (root.batteryCharging ? root.colSuccess : root.colFg))
                            font {
                                family: root.fontFamily
                                pixelSize: Math.round(11 * root.scaleFactor)
                                bold: true
                            }
                            Behavior on color {
                                ColorAnimation {
                                    duration: root.batteryMode ? 150 : 200
                                }
                            }
                        }
                        ModernBatteryIcon {
                            level: batteryMod.cap / 100.0
                            charging: root.batteryCharging
                            colFg: batteryMod.isCrit ? root.colCrit : (batteryMod.isWarn ? root.colWarn : (root.batteryCharging ? root.colSuccess : root.colFg))
                            Layout.alignment: Qt.AlignVCenter
                        }
                    }
                }

                NotchMod {
                    shellRoot: root
                    id: spotifyMod
                    hoverColor: "transparent"
                    activeColor: "transparent"
                    show: root.spotifyStatus === "playing"
                    onClicked: root.islandState = root.stateMedia

                    RowLayout {
                        spacing: 6
                        Text {
                            text: "󰝚"
                            color: root.colSpotify
                            font {
                                family: root.iconFontFamily
                                pixelSize: 11
                                bold: true
                            }
                            transformOrigin: Item.Center

                            SequentialAnimation on scale {
                                loops: Animation.Infinite
                                running: root.spotifyStatus === "playing"
                                NumberAnimation {
                                    to: 1.2
                                    duration: 600
                                    easing.type: Easing.InOutQuad
                                }
                                NumberAnimation {
                                    to: 0.9
                                    duration: 600
                                    easing.type: Easing.InOutQuad
                                }
                            }
                        }
                        Text {
                            text: "Music"
                            color: root.colFg
                            font {
                                family: root.fontFamily
                                pixelSize: 10
                                bold: true
                            }
                        }
                        Row {
                            spacing: 1.5 * root.scaleFactor
                            Layout.alignment: Qt.AlignVCenter
                            height: Math.round(10 * root.scaleFactor)
                            visible: root.spotifyStatus === "playing"
                            Repeater {
                                model: [400, 650, 500, 750]
                                delegate: Rectangle {
                                    width: 1.5 * root.scaleFactor
                                    height: Math.round(3 * root.scaleFactor)
                                    radius: (1.5 * root.scaleFactor) / 2
                                    color: root.colSpotify
                                    anchors.bottom: parent.bottom

                                    SequentialAnimation on height {
                                        loops: Animation.Infinite
                                        running: root.spotifyStatus === "playing" && !root.batteryMode
                                        NumberAnimation {
                                            to: Math.round(9 * root.scaleFactor)
                                            duration: modelData
                                            easing.type: Easing.InOutQuad
                                        }
                                        NumberAnimation {
                                            to: Math.round(3 * root.scaleFactor)
                                            duration: modelData
                                            easing.type: Easing.InOutQuad
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                NotchMod {
                    shellRoot: root
                    id: stopwatchMod
                    hoverColor: "transparent"
                    activeColor: "transparent"
                    property bool isActive: root.stopwatchRunning || root.stopwatchSeconds > 0
                    show: isActive
                    onClicked: root.islandState = root.stateStopwatch

                    RowLayout {
                        spacing: 6
                        Text {
                            text: "󱎫"
                            color: root.stopwatchRunning ? root.colWarn : root.colFg
                            font {
                                family: root.iconFontFamily
                                pixelSize: 11
                            }
                            transformOrigin: Item.Center

                            NumberAnimation on rotation {
                                loops: Animation.Infinite
                                running: root.stopwatchRunning
                                from: 0
                                to: 360
                                duration: 4000
                            }
                        }
                        Text {
                            text: root.stopwatchText
                            color: root.colFg
                            font {
                                family: root.fontFamily
                                pixelSize: 10
                                bold: true
                            }
                        }
                    }
                }

                NotchMod {
                    shellRoot: root
                    id: timerMod
                    hoverColor: "transparent"
                    activeColor: "transparent"
                    property bool isActive: root.timerRunning || (root.timerSeconds > 0 && root.timerSeconds < root.timerTotal)
                    show: isActive
                    onClicked: root.islandState = root.stateTimer

                    RowLayout {
                        spacing: 6
                        Text {
                            text: "󰔛"
                            color: root.timerRunning ? root.colWarn : root.colFg
                            font {
                                family: root.iconFontFamily
                                pixelSize: 11
                            }
                            transformOrigin: Item.Center

                            SequentialAnimation on rotation {
                                loops: Animation.Infinite
                                running: root.timerRunning && !root.batteryMode
                                NumberAnimation {
                                    from: 0
                                    to: -15
                                    duration: 150
                                    easing.type: Easing.InOutQuad
                                }
                                NumberAnimation {
                                    from: -15
                                    to: 15
                                    duration: 300
                                    easing.type: Easing.InOutQuad
                                }
                                NumberAnimation {
                                    from: 15
                                    to: 0
                                    duration: 150
                                    easing.type: Easing.InOutQuad
                                }
                                PauseAnimation {
                                    duration: 400
                                }
                            }
                        }
                        Text {
                            text: root.timerText
                            color: root.colFg
                            font {
                                family: root.fontFamily
                                pixelSize: 10
                                bold: true
                            }
                        }
                    }
                }

                NotchMod {
                    shellRoot: root
                    id: modeMod
                    hoverColor: "transparent"
                    activeColor: "transparent"
                    show: root.showBatteryModeIndicator

                    RowLayout {
                        spacing: 6
                        Text {
                            // N-17 FIX: glyphs were empty strings — restored correct Nerd Font codepoints
                            text: root.batteryMode ? "󰌪" : "󱐋"
                            color: root.batteryMode ? "#FFCC00" : "#76B900"
                            font {
                                family: root.iconFontFamily
                                pixelSize: 11
                            }
                        }
                        Text {
                            text: root.batteryMode ? "Saver" : "Performance"
                            color: root.colFg
                            font {
                                family: root.fontFamily
                                pixelSize: 10
                                bold: true
                            }
                        }
                    }
                }

                NotchMod {
                    shellRoot: root
                    id: micMod
                    hoverColor: "transparent"
                    activeColor: "transparent"
                    show: root.showMicIndicator

                    RowLayout {
                        spacing: 6
                        Text {
                            text: root.micMuted ? "󰍭" : "󰍬"
                            color: root.micMuted ? root.colMuted : root.colWarn
                            font {
                                family: root.iconFontFamily
                                pixelSize: 11
                            }
                        }
                        Text {
                            text: root.micMuted ? "Muted" : "Active"
                            color: root.colFg
                            font {
                                family: root.fontFamily
                                pixelSize: 10
                                bold: true
                            }
                        }
                    }
                }

                NotchMod {
                    shellRoot: root
                    id: emailMod
                    hoverColor: "transparent"
                    activeColor: "transparent"
                    show: root.showEmailPill && root.hourEmailsCount > 0
                    onClicked: {
                        emailsPopup.show = !emailsPopup.show;
                    }

                    RowLayout {
                        spacing: 6
                        Text {
                            text: "󰇮"
                            color: "#007AFF"
                            font {
                                family: root.iconFontFamily
                                pixelSize: 11
                            }
                        }
                        Text {
                            text: root.hourEmailsCount + " New"
                            color: root.colFg
                            font {
                                family: root.fontFamily
                                pixelSize: 10
                                bold: true
                            }
                        }
                    }
                }
            }

            MouseArea {
                anchors.fill: mediaLayout
                visible: mediaLayout.visible
                z: -1
                onClicked: root.islandState = root.stateCompact
            }

            // Compact Media Layout
            RowLayout {
                id: mediaLayout
                opacity: (root.islandState === 1 && !root.isAnyPopupOpen && notchRect.width >= 272) ? 1.0 : 0.0
                visible: opacity > 0
                scale: opacity > 0 ? 1.0 : 0.9
                Behavior on opacity {
                    NumberAnimation {
                        duration: root.batteryMode ? 150 : 250
                        easing.type: Easing.OutQuad
                    }
                }
                Behavior on scale {
                    enabled: true
                    SpringAnimation {
                        spring: 4.8
                        damping: 0.8
                        mass: 0.6
                    }
                }
                layer.enabled: (opacity > 0.0 && opacity < 1.0) && !root.batteryMode
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                spacing: 10

                MouseArea {
                    width: 20
                    height: 20
                    Layout.alignment: Qt.AlignVCenter
                    onClicked: {
                        mediaPopup.show = true;
                    }
                    Text {
                        anchors.centerIn: parent
                        text: "󰝚"
                        color: root.spotifyStatus === "playing" ? root.colSpotify : root.colFg
                        font {
                            family: root.iconFontFamily
                            pixelSize: 14
                        }
                    }
                }

                // ── MARQUEE TICKER ─────────────────────────────────────────
                Item {
                    id: tickerClip
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    height: 18
                    clip: true

                    property real textW: tickerText.implicitWidth
                    property real clipW: tickerClip.width
                    property bool needsScroll: textW > clipW
                    property int loopsRemaining: 0
                    property bool hoverActive: false
                    property bool isScrolling: false

                    function triggerChangeScroll() {
                        tickerAnim.stop();
                        tickerContainer.x = 0;
                        tickerClip.isScrolling = false;
                        if (needsScroll && root.spotifyStatus === "playing" && !root.batteryMode) {
                            loopsRemaining = 3;
                            tickerAnim.start();
                        } else {
                            loopsRemaining = 0;
                        }
                    }

                    Connections {
                        target: root
                        function onSpotifyStatusChanged() {
                            if (root.spotifyStatus !== "playing") {
                                tickerAnim.stop();
                                tickerContainer.x = 0;
                                tickerClip.loopsRemaining = 0;
                                tickerClip.isScrolling = false;
                            } else {
                                tickerClip.triggerChangeScroll();
                            }
                        }
                        function onBatteryModeChanged() {
                            if (root.batteryMode) {
                                tickerAnim.stop();
                                tickerContainer.x = 0;
                                tickerClip.loopsRemaining = 0;
                                tickerClip.isScrolling = false;
                            } else {
                                tickerClip.triggerChangeScroll();
                            }
                        }
                    }

                    // Scrolling Container
                    Item {
                        id: tickerContainer
                        width: tickerText.implicitWidth * 2 + 40
                        height: parent.height
                        x: 0

                        Row {
                            spacing: 40
                            anchors.verticalCenter: parent.verticalCenter

                            Text {
                                id: tickerText
                                text: root.spotifyText ? root.spotifyText : "No Title"
                                color: root.colFg
                                font {
                                    family: root.fontFamily
                                    pixelSize: 11
                                    bold: true
                                }
                                onTextChanged: {
                                    tickerClip.triggerChangeScroll();
                                }
                            }

                            Text {
                                text: tickerText.text
                                color: tickerText.color
                                font: tickerText.font
                                visible: tickerClip.needsScroll
                            }
                        }
                    }

                    SequentialAnimation {
                        id: tickerAnim
                        loops: 1

                        ScriptAction {
                            script: tickerClip.isScrolling = false
                        }

                        PauseAnimation {
                            duration: 2200
                        }

                        ScriptAction {
                            script: tickerClip.isScrolling = true
                        }

                        NumberAnimation {
                            target: tickerContainer
                            property: "x"
                            from: 0
                            to: -(tickerText.implicitWidth + 40)
                            duration: Math.max(3000, tickerText.implicitWidth * 24)
                            easing.type: Easing.Linear
                        }

                        ScriptAction {
                            script: tickerClip.isScrolling = false
                        }

                        onFinished: {
                            tickerContainer.x = 0;
                            tickerClip.isScrolling = false;
                            if (tickerClip.loopsRemaining > 0) {
                                tickerClip.loopsRemaining--;
                            }
                            if (tickerClip.loopsRemaining > 0 || tickerClip.hoverActive) {
                                tickerAnim.start();
                            }
                        }
                    }

                    onWidthChanged: {
                        triggerChangeScroll();
                    }

                    // Faded Edge Overlays (Left & Right) for premium visual cutoff
                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: 12
                        opacity: (tickerClip.needsScroll && tickerClip.isScrolling) ? 1.0 : 0.0
                        visible: opacity > 0.01
                        z: 10
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop {
                                position: 0.0
                                color: Qt.rgba(0.05, 0.05, 0.05, 1.0)
                            }
                            GradientStop {
                                position: 1.0
                                color: Qt.rgba(0.05, 0.05, 0.05, 0.0)
                            }
                        }
                        Behavior on opacity {
                            NumberAnimation {
                                duration: 300
                                easing.type: Easing.InOutQuad
                            }
                        }
                    }

                    Rectangle {
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: 12
                        opacity: (tickerClip.needsScroll && tickerClip.isScrolling) ? 1.0 : 0.0
                        visible: opacity > 0.01
                        z: 10
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop {
                                position: 0.0
                                color: Qt.rgba(0.05, 0.05, 0.05, 0.0)
                            }
                            GradientStop {
                                position: 1.0
                                color: Qt.rgba(0.05, 0.05, 0.05, 1.0)
                            }
                        }
                        Behavior on opacity {
                            NumberAnimation {
                                duration: 300
                                easing.type: Easing.InOutQuad
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: {
                            if (tickerClip.needsScroll && root.spotifyStatus === "playing" && !root.batteryMode) {
                                tickerClip.hoverActive = true;
                                if (!tickerAnim.running) {
                                    tickerAnim.start();
                                }
                            }
                        }
                        onExited: {
                            tickerClip.hoverActive = false;
                        }
                        onClicked: {
                            root.islandState = root.stateCompact;
                        }
                    }
                }
                // ───────────────────────────────────────────────────────────

                RowLayout {
                    spacing: 6
                    Layout.alignment: Qt.AlignVCenter

                    MouseArea {
                        id: compactPrevBtn
                        width: 22
                        height: 22
                        hoverEnabled: true
                        onClicked: pSpotPrev.running = true

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
                            color: parent.containsMouse ? root.colFg : root.colMuted
                            font {
                                family: root.iconFontFamily
                                pixelSize: 13
                            }
                        }
                    }

                    MouseArea {
                        id: compactPlayBtn
                        width: 24
                        height: 24
                        hoverEnabled: true
                        onClicked: pSpotPlay.running = true

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
                            radius: 12
                            color: parent.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
                        }
                        Text {
                            anchors.centerIn: parent
                            text: root.spotifyStatus === "playing" ? "󰏤" : "󰐊"
                            color: root.colFg
                            font {
                                family: root.iconFontFamily
                                pixelSize: 14
                            }
                        }
                    }

                    MouseArea {
                        id: compactNextBtn
                        width: 22
                        height: 22
                        hoverEnabled: true
                        onClicked: pSpotNext.running = true

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
                            color: parent.containsMouse ? root.colFg : root.colMuted
                            font {
                                family: root.iconFontFamily
                                pixelSize: 13
                            }
                        }
                    }
                }
            }

            MouseArea {
                anchors.fill: timerLayout
                visible: timerLayout.visible
                z: -1
                onClicked: root.islandState = root.stateCompact
            }

            // Timer Layout
            RowLayout {
                id: timerLayout
                opacity: (root.islandState === 4 && !root.isAnyPopupOpen && notchRect.width >= 232) ? 1.0 : 0.0
                visible: opacity > 0
                scale: opacity > 0 ? 1.0 : 0.9
                Behavior on opacity {
                    NumberAnimation {
                        duration: root.batteryMode ? 150 : 250
                        easing.type: Easing.OutQuad
                    }
                }
                Behavior on scale {
                    enabled: true
                    SpringAnimation {
                        spring: 4.8
                        damping: 0.8
                        mass: 0.6
                    }
                }
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                spacing: 12

                Text {
                    text: "󰔛"
                    color: root.timerRunning ? root.colWarn : root.colFg
                    font {
                        family: root.iconFontFamily
                        pixelSize: 18
                    }
                    Layout.alignment: Qt.AlignVCenter
                    transformOrigin: Item.Center

                    SequentialAnimation on rotation {
                        loops: Animation.Infinite
                        running: root.timerRunning && !root.batteryMode
                        NumberAnimation {
                            from: 0
                            to: -15
                            duration: 150
                            easing.type: Easing.InOutQuad
                        }
                        NumberAnimation {
                            from: -15
                            to: 15
                            duration: 300
                            easing.type: Easing.InOutQuad
                        }
                        NumberAnimation {
                            from: 15
                            to: 0
                            duration: 150
                            easing.type: Easing.InOutQuad
                        }
                        PauseAnimation {
                            duration: 400
                        }
                    }
                }

                Text {
                    text: root.timerText
                    color: root.colFg
                    font {
                        family: root.fontFamily
                        pixelSize: 14
                        bold: true
                    }
                    horizontalAlignment: Text.AlignHCenter
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                }

                RowLayout {
                    spacing: 8
                    Layout.alignment: Qt.AlignVCenter

                    MouseArea {
                        width: 24
                        height: 24
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        scale: containsPress ? 0.85 : (containsMouse ? 1.15 : 1.0)
                        Behavior on scale { SpringAnimation { spring: 4.5; damping: 0.65; mass: 0.6 } }
                        onClicked: root.timerRunning = !root.timerRunning
                        Text {
                            anchors.centerIn: parent
                            text: root.timerRunning ? "󰏤" : "󰐊"
                            color: root.colFg
                            font {
                                family: root.iconFontFamily
                                pixelSize: 16
                            }
                        }
                    }

                    MouseArea {
                        width: 24
                        height: 24
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        scale: containsPress ? 0.85 : (containsMouse ? 1.15 : 1.0)
                        Behavior on scale { SpringAnimation { spring: 4.5; damping: 0.65; mass: 0.6 } }
                        onClicked: {
                            root.timerRunning = false;
                            root.timerSeconds = root.timerTotal;
                            root.timerText = root.formatTime(root.timerTotal);
                            root.islandState = root.stateCompact;
                        }
                        Text {
                            anchors.centerIn: parent
                            text: "󰜎"
                            color: root.colMuted
                            font {
                                family: root.iconFontFamily
                                pixelSize: 16
                            }
                        }
                    }
                }
            }

            MouseArea {
                anchors.fill: stopwatchLayout
                visible: stopwatchLayout.visible
                z: -1
                onClicked: root.islandState = root.stateCompact
            }

            // Stopwatch Layout
            RowLayout {
                id: stopwatchLayout
                opacity: (root.islandState === 5 && !root.isAnyPopupOpen && notchRect.width >= 232) ? 1.0 : 0.0
                visible: opacity > 0
                scale: opacity > 0 ? 1.0 : 0.9
                Behavior on opacity {
                    NumberAnimation {
                        duration: root.batteryMode ? 150 : 250
                        easing.type: Easing.OutQuad
                    }
                }
                Behavior on scale {
                    enabled: true
                    SpringAnimation {
                        spring: 4.8
                        damping: 0.8
                        mass: 0.6
                    }
                }
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                spacing: 12

                Text {
                    text: "󱎫"
                    color: root.stopwatchRunning ? root.colWarn : root.colFg
                    font {
                        family: root.iconFontFamily
                        pixelSize: 18
                    }
                    Layout.alignment: Qt.AlignVCenter
                }

                Text {
                    text: root.stopwatchText
                    color: root.colFg
                    font {
                        family: root.fontFamily
                        pixelSize: 14
                        bold: true
                    }
                    horizontalAlignment: Text.AlignHCenter
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                }

                RowLayout {
                    spacing: 8
                    Layout.alignment: Qt.AlignVCenter

                    MouseArea {
                        width: 24
                        height: 24
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        scale: containsPress ? 0.85 : (containsMouse ? 1.15 : 1.0)
                        Behavior on scale { SpringAnimation { spring: 4.5; damping: 0.65; mass: 0.6 } }
                        onClicked: root.stopwatchRunning = !root.stopwatchRunning
                        Text {
                            anchors.centerIn: parent
                            text: root.stopwatchRunning ? "󰏤" : "󰐊"
                            color: root.colFg
                            font {
                                family: root.iconFontFamily
                                pixelSize: 16
                            }
                        }
                    }

                    MouseArea {
                        width: 24
                        height: 24
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        scale: containsPress ? 0.85 : (containsMouse ? 1.15 : 1.0)
                        Behavior on scale { SpringAnimation { spring: 4.5; damping: 0.65; mass: 0.6 } }
                        onClicked: {
                            root.stopwatchRunning = false;
                            root.stopwatchSeconds = 0;
                            root.stopwatchText = "00:00";
                        }
                        Text {
                            anchors.centerIn: parent
                            text: "󰜎"
                            color: root.colMuted
                            font {
                                family: root.iconFontFamily
                                pixelSize: 16
                            }
                        }
                    }
                }
            }

            // Recording Layout
            RowLayout {
                id: recordingLayout
                opacity: (root.islandState === 6 && !root.isAnyPopupOpen && notchRect.width >= 192) ? 1.0 : 0.0
                visible: opacity > 0
                scale: opacity > 0 ? 1.0 : 0.9
                Behavior on opacity {
                    NumberAnimation {
                        duration: root.batteryMode ? 150 : 250
                        easing.type: Easing.OutQuad
                    }
                }
                Behavior on scale {
                    enabled: true
                    SpringAnimation {
                        spring: 4.8
                        damping: 0.8
                        mass: 0.6
                    }
                }
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                spacing: 12

                RowLayout {
                    spacing: 6
                    Layout.alignment: Qt.AlignVCenter
                    Item {
                        width: 10
                        height: 10
                        Layout.alignment: Qt.AlignVCenter

                        // Pulsing outer ring (sonar radar)
                        Rectangle {
                            anchors.centerIn: parent
                            width: 10
                            height: 10
                            radius: 5
                            color: "transparent"
                            border.color: "#EF4444"
                            border.width: 1
                            transformOrigin: Item.Center

                            ParallelAnimation on scale {
                                loops: Animation.Infinite
                                running: root.islandState === 6 && !root.batteryMode
                                NumberAnimation {
                                    from: 1.0
                                    to: 2.4
                                    duration: 1600
                                    easing.type: Easing.OutQuad
                                }
                            }
                            ParallelAnimation on opacity {
                                loops: Animation.Infinite
                                running: root.islandState === 6 && !root.batteryMode
                                NumberAnimation {
                                    from: 0.8
                                    to: 0.0
                                    duration: 1600
                                    easing.type: Easing.OutQuad
                                }
                            }
                        }

                        // Core red dot
                        Rectangle {
                            anchors.fill: parent
                            radius: 5
                            color: "#EF4444"
                            SequentialAnimation on opacity {
                                loops: Animation.Infinite
                                running: root.islandState === 6
                                NumberAnimation {
                                    from: 1.0
                                    to: 0.4
                                    duration: 800
                                    easing.type: Easing.InOutQuad
                                }
                                NumberAnimation {
                                    from: 0.4
                                    to: 1.0
                                    duration: 800
                                    easing.type: Easing.InOutQuad
                                }
                            }
                        }
                    }
                    Text {
                        text: "REC"
                        color: "#EF4444"
                        font {
                            family: root.fontFamily
                            pixelSize: 12
                            bold: true
                        }
                        Layout.alignment: Qt.AlignVCenter
                    }
                }

                Text {
                    text: root.recordingTime
                    color: root.colFg
                    font {
                        family: root.fontFamily
                        pixelSize: 14
                        bold: true
                    }
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                }

                MouseArea {
                    width: 24
                    height: 24
                    Layout.alignment: Qt.AlignVCenter
                    onClicked: {
                        // N-5 FIX: also stop the timer and reset state when clicking stop from the notch
                        pStopRecord.running = true;
                        root.isRecording = false;
                        recordingTimer.stop();
                        root.recordingSeconds = 0;
                        root.recordingTime = "0:00";
                        root.islandState = root.stateCompact;
                    }
                    Text {
                        anchors.centerIn: parent
                        text: "󰓛"
                        color: "#EF4444"
                        font {
                            family: root.iconFontFamily
                            pixelSize: 16
                        }
                    }
                }
            }

            // ── LIQUID-FILL OSD BACKGROUND ──────────────────────────────
            Canvas {
                id: osdLiquidCanvas
                anchors.fill: parent
                clip: true
                visible: root.islandState === root.stateOsd && !root.isAnyPopupOpen

                property real fillRatio: root.osdValue / 100
                property real wavePhase: 0.0
                property real waveAmp: 3.0   // wave amplitude in px

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

            // OSD Layout
            RowLayout {
                id: osdLayout
                opacity: (root.islandState === 3 && !root.isAnyPopupOpen && notchRect.width >= 192) ? 1.0 : 0.0
                visible: opacity > 0
                scale: opacity > 0 ? 1.0 : 0.9
                Behavior on opacity {
                    NumberAnimation {
                        duration: root.batteryMode ? 150 : 250
                        easing.type: Easing.OutQuad
                    }
                }
                Behavior on scale {
                    enabled: true
                    SpringAnimation {
                        spring: 4.8
                        damping: 0.8
                        mass: 0.6
                    }
                }
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

            // Battery Low alert pill
            RowLayout {
                id: lowBatLayout
                opacity: (root.islandState === 7 && !root.isAnyPopupOpen && notchRect.width >= 192) ? 1.0 : 0.0
                visible: opacity > 0
                scale: opacity > 0 ? 1.0 : 0.9
                Behavior on opacity {
                    NumberAnimation {
                        duration: root.batteryMode ? 150 : 250
                        easing.type: Easing.OutQuad
                    }
                }
                Behavior on scale {
                    enabled: true
                    SpringAnimation {
                        spring: 4.8
                        damping: 0.8
                        mass: 0.6
                    }
                }
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
                opacity: (root.islandState === 8 && !root.isAnyPopupOpen && notchRect.width >= 192) ? 1.0 : 0.0
                visible: opacity > 0
                scale: opacity > 0 ? 1.0 : 0.9
                Behavior on opacity {
                    NumberAnimation {
                        duration: root.batteryMode ? 150 : 250
                        easing.type: Easing.OutQuad
                    }
                }
                Behavior on scale {
                    enabled: true
                    SpringAnimation {
                        spring: 4.8
                        damping: 0.8
                        mass: 0.6
                    }
                }
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
                opacity: (root.islandState === 9 && !root.isAnyPopupOpen && notchRect.width >= 192) ? 1.0 : 0.0
                visible: opacity > 0
                scale: opacity > 0 ? 1.0 : 0.9
                Behavior on opacity {
                    NumberAnimation {
                        duration: root.batteryMode ? 150 : 250
                        easing.type: Easing.OutQuad
                    }
                }
                Behavior on scale {
                    enabled: true
                    SpringAnimation {
                        spring: 4.8
                        damping: 0.8
                        mass: 0.6
                    }
                }
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
                                loops: Animation.Infinite
                                running: root.dndActive && !root.batteryMode && root.islandState === root.stateDnd

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

            // Water Alert Pill
            RowLayout {
                id: waterLayout
                opacity: (root.islandState === 10 && !root.isAnyPopupOpen && notchRect.width >= 192) ? 1.0 : 0.0
                visible: opacity > 0
                scale: opacity > 0 ? 1.0 : 0.9
                Behavior on opacity {
                    NumberAnimation {
                        duration: root.batteryMode ? 150 : 250
                        easing.type: Easing.OutQuad
                    }
                }
                Behavior on scale {
                    enabled: true
                    SpringAnimation {
                        spring: 4.8
                        damping: 0.8
                        mass: 0.6
                    }
                }
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                spacing: 8

                Item {
                    id: waterIconContainer
                    Layout.preferredWidth: 16
                    Layout.preferredHeight: 16
                    Layout.alignment: Qt.AlignVCenter

                    Text {
                        id: waterIcon
                        anchors.centerIn: parent
                        text: "󰖞"
                        color: "#3B82F6"
                        font {
                            family: root.iconFontFamily
                            pixelSize: 15
                        }
                        transformOrigin: Item.Center

                        transform: Scale {
                            id: waterScale
                            origin.x: 8
                            origin.y: 8
                        }

                        SequentialAnimation {
                            running: (root.islandState === 10 && !root.batteryMode)
                            loops: Animation.Infinite

                            // Wobble & Float Up
                            ParallelAnimation {
                                NumberAnimation {
                                    target: waterIcon
                                    property: "y"
                                    from: 0
                                    to: -4
                                    duration: 600
                                    easing.type: Easing.InOutQuad
                                }
                                NumberAnimation {
                                    target: waterScale
                                    property: "xScale"
                                    from: 1.0
                                    to: 0.85
                                    duration: 600
                                    easing.type: Easing.InOutQuad
                                }
                                NumberAnimation {
                                    target: waterScale
                                    property: "yScale"
                                    from: 1.0
                                    to: 1.2
                                    duration: 600
                                    easing.type: Easing.InOutQuad
                                }
                            }

                            // Wobble & Fall Down
                            ParallelAnimation {
                                NumberAnimation {
                                    target: waterIcon
                                    property: "y"
                                    to: 0
                                    duration: 500
                                    easing.type: Easing.InOutQuad
                                }
                                NumberAnimation {
                                    target: waterScale
                                    property: "xScale"
                                    to: 1.2
                                    duration: 500
                                    easing.type: Easing.InOutQuad
                                }
                                NumberAnimation {
                                    target: waterScale
                                    property: "yScale"
                                    to: 0.8
                                    duration: 500
                                    easing.type: Easing.InOutQuad
                                }
                            }

                            // Return to normal
                            ParallelAnimation {
                                NumberAnimation {
                                    target: waterScale
                                    property: "xScale"
                                    to: 1.0
                                    duration: 250
                                    easing.type: Easing.InOutQuad
                                }
                                NumberAnimation {
                                    target: waterScale
                                    property: "yScale"
                                    to: 1.0
                                    duration: 250
                                    easing.type: Easing.InOutQuad
                                }
                            }

                            PauseAnimation {
                                duration: 150
                            }
                        }
                    }
                }

                Text {
                    text: "Time to Drink Water!"
                    color: "#3B82F6"
                    font {
                        family: root.fontFamily
                        pixelSize: 11
                        bold: true
                    }
                    Layout.alignment: Qt.AlignVCenter
                    Layout.fillWidth: true
                }
                MouseArea {
                    width: 50
                    height: 24
                    Layout.alignment: Qt.AlignVCenter
                    hoverEnabled: true
                    Rectangle {
                        anchors.fill: parent
                        color: parent.containsMouse ? Qt.rgba(0.23, 0.51, 0.96, 0.2) : Qt.rgba(0.23, 0.51, 0.96, 0.1)
                        radius: 12
                        border.color: Qt.rgba(0.23, 0.51, 0.96, 0.3)
                        border.width: 1
                    }
                    Text {
                        anchors.centerIn: parent
                        text: "Done"
                        color: "#3B82F6"
                        font {
                            family: root.fontFamily
                            pixelSize: 10
                            bold: true
                        }
                    }
                    onClicked: {
                        root.resetWaterTimer();
                        root.islandState = root.prevIslandState;
                    }
                }
            }

            // Sedentary Alert Pill
            RowLayout {
                id: stretchLayout
                opacity: (root.islandState === 11 && !root.isAnyPopupOpen && notchRect.width >= 192) ? 1.0 : 0.0
                visible: opacity > 0
                scale: opacity > 0 ? 1.0 : 0.9
                Behavior on opacity {
                    NumberAnimation {
                        duration: root.batteryMode ? 150 : 250
                        easing.type: Easing.OutQuad
                    }
                }
                Behavior on scale {
                    enabled: true
                    SpringAnimation {
                        spring: 4.8
                        damping: 0.8
                        mass: 0.6
                    }
                }
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                spacing: 8

                Text {
                    text: "󱗝"
                    color: "#8B5CF6"
                    font {
                        family: root.iconFontFamily
                        pixelSize: 15
                    }
                    Layout.alignment: Qt.AlignVCenter
                }
                Text {
                    text: "Time to Stretch!"
                    color: "#8B5CF6"
                    font {
                        family: root.fontFamily
                        pixelSize: 11
                        bold: true
                    }
                    Layout.alignment: Qt.AlignVCenter
                    Layout.fillWidth: true
                }
                MouseArea {
                    width: 50
                    height: 24
                    Layout.alignment: Qt.AlignVCenter
                    hoverEnabled: true
                    Rectangle {
                        anchors.fill: parent
                        color: parent.containsMouse ? Qt.rgba(0.55, 0.36, 0.96, 0.2) : Qt.rgba(0.55, 0.36, 0.96, 0.1)
                        radius: 12
                        border.color: Qt.rgba(0.55, 0.36, 0.96, 0.3)
                        border.width: 1
                    }
                    Text {
                        anchors.centerIn: parent
                        text: "Done"
                        color: "#8B5CF6"
                        font {
                            family: root.fontFamily
                            pixelSize: 10
                            bold: true
                        }
                    }
                    onClicked: {
                        root.resetStretchTimer();
                        root.islandState = root.prevIslandState;
                    }
                }
            }

            // F1 Alert Pill
            RowLayout {
                id: f1Layout
                opacity: (root.islandState === 12 && !root.isAnyPopupOpen && notchRect.width >= 192) ? 1.0 : 0.0
                visible: opacity > 0
                scale: opacity > 0 ? 1.0 : 0.9
                Behavior on opacity {
                    NumberAnimation {
                        duration: root.batteryMode ? 150 : 250
                        easing.type: Easing.OutQuad
                    }
                }
                Behavior on scale {
                    enabled: true
                    SpringAnimation {
                        spring: 4.8
                        damping: 0.8
                        mass: 0.6
                    }
                }
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
                        text: "󰛄"
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
                opacity: (root.islandState === 13 && !root.isAnyPopupOpen && notchRect.width >= 192) ? 1.0 : 0.0
                visible: opacity > 0
                scale: opacity > 0 ? 1.0 : 0.9
                Behavior on opacity {
                    NumberAnimation {
                        duration: root.batteryMode ? 150 : 250
                        easing.type: Easing.OutQuad
                    }
                }
                Behavior on scale {
                    enabled: true
                    SpringAnimation {
                        spring: 4.8
                        damping: 0.8
                        mass: 0.6
                    }
                }
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
                opacity: (root.islandState === root.stateDiskAlert && !root.isAnyPopupOpen && notchRect.width >= 192) ? 1.0 : 0.0
                visible: opacity > 0
                scale: opacity > 0 ? 1.0 : 0.9
                Behavior on opacity {
                    NumberAnimation {
                        duration: root.batteryMode ? 150 : 250
                        easing.type: Easing.OutQuad
                    }
                }
                Behavior on scale {
                    enabled: true
                    SpringAnimation {
                        spring: 4.8
                        damping: 0.8
                        mass: 0.6
                    }
                }
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                spacing: 7

                // Drive icon
                Text {
                    text: root.diskAlertMounted ? "󰋊" : "󱊞"
                    color: root.diskAlertMounted ? "#76B900" : "#FFA500"
                    font {
                        family: root.iconFontFamily
                        pixelSize: 13
                    }
                    Layout.alignment: Qt.AlignVCenter
                }

                // Drive name — fills remaining space, truncates with ellipsis
                Text {
                    text: root.diskAlertTitle !== "" ? root.diskAlertTitle : "USB Drive"
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
                    text: root.diskAlertMounted ? "Connected" : "Disconnected"
                    color: root.diskAlertMounted ? "#76B900" : "#FFA500"
                    font {
                        family: root.fontFamily
                        pixelSize: 10
                        bold: true
                    }
                    Layout.alignment: Qt.AlignVCenter
                }
            }
        }


        // LocalSend Drag & Drop Layout
        Item {
            id: localSendDragLayout
            // Stays visible whenever in a LocalSend state — avoids layout destroy/create during transition
            visible: root.islandState === root.stateDragLocalSend || root.islandState === root.stateLocalSendSuccess
            anchors.centerIn: parent
            implicitWidth: lsDragRow.implicitWidth
            implicitHeight: lsDragRow.implicitHeight
            layer.enabled: true

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
                    text: "󱇧"
                    color: root.colAccent
                    font { family: root.iconFontFamily; pixelSize: 20 * scaleFactor; bold: true }
                    Layout.alignment: Qt.AlignVCenter
                }
                ColumnLayout {
                    spacing: 2 * scaleFactor
                    Layout.alignment: Qt.AlignVCenter
                    Text {
                        text: "Send to LocalSend"
                        color: root.colFg
                        font { family: root.fontFamily; pixelSize: 12 * scaleFactor; bold: true }
                    }
                    Text {
                        text: "Drop files here to share"
                        color: root.colMuted
                        font { family: root.fontFamily; pixelSize: 10 * scaleFactor }
                    }
                }
            }
        }

        // LocalSend Success Layout
        Item {
            id: localSendSuccessLayout
            visible: root.islandState === root.stateLocalSendSuccess
            anchors.centerIn: parent
            implicitWidth: lsSuccessRow.implicitWidth
            implicitHeight: lsSuccessRow.implicitHeight
            layer.enabled: true

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
                    font { family: root.iconFontFamily; pixelSize: 20 * scaleFactor; bold: true }
                    Layout.alignment: Qt.AlignVCenter
                }
                ColumnLayout {
                    spacing: 2 * scaleFactor
                    Layout.alignment: Qt.AlignVCenter
                    Text {
                        text: "Files Sent!"
                        color: root.colSuccess
                        font { family: root.fontFamily; pixelSize: 12 * scaleFactor; bold: true }
                    }
                    Text {
                        text: "Opening LocalSend..."
                        color: root.colMuted
                        font { family: root.fontFamily; pixelSize: 10 * scaleFactor }
                    }
                }
            }
        }

        // Siri Visualizer Layout inside Notch
        RowLayout {
            id: commsLayout
            opacity: (root.islandState === root.stateComms && !root.isAnyPopupOpen) ? 1.0 : 0.0
            visible: opacity > 0
            scale: opacity > 0 ? 1.0 : 0.9
            Behavior on opacity {
                NumberAnimation {
                    duration: root.batteryMode ? 150 : 250
                    easing.type: Easing.OutQuad
                }
            }
            Behavior on scale {
                enabled: true
                SpringAnimation {
                    spring: 4.8
                    damping: 0.8
                    mass: 0.6
                }
            }
            anchors.centerIn: parent
            spacing: 8 * scaleFactor

            Text {
                text: "󰍬"
                color: "#FF2D55"
                font {
                    family: root.iconFontFamily
                    pixelSize: 13 * scaleFactor
                }
                Layout.alignment: Qt.AlignVCenter
            }

            CommsVisualizer {
                id: commsWaves
                width: 140 * scaleFactor
                height: 28 * scaleFactor
                active: root.islandState === root.stateComms && !root.isAnyPopupOpen
                Layout.alignment: Qt.AlignVCenter
            }
        }


        Row {
            id: bubbleRow

            visible: opacity > 0
            opacity: (root.islandState === 1 || root.islandState === 4 || root.islandState === 5 || root.islandState === 6) && !root.isAnyPopupOpen ? 1.0 : 0.0
            Behavior on opacity {
                NumberAnimation {
                    duration: root.batteryMode ? 150 : 200
                    easing.type: Easing.OutQuad
                }
            }

            // Fixed vertical center relative to the bar, not notchRect, to avoid
            // jitter during spring overshoot when the pill height changes.
            anchors.verticalCenter: parent.top
            anchors.verticalCenterOffset: root.topHuggingStyle ? Math.round(20 * scaleFactor) : Math.round(24 * scaleFactor)
            y: 0  // suppressed; verticalCenter handles vertical placement
            x: notchRect.x + notchRect.width + 8
            spacing: 6

            Repeater {
                model: root.activeActivities
                delegate: Rectangle {
                    id: bubble
                    property string act: modelData
                    property bool isCurrent: (act === "media" && root.islandState === 1) || (act === "timer" && root.islandState === 4) || (act === "stopwatch" && root.islandState === 5) || (act === "recording" && root.islandState === 6)

                    opacity: isCurrent ? 0.0 : 1.0
                    scale: isCurrent ? 0.0 : (bubbleMouse.containsPress ? 0.9 : (bubbleMouse.containsMouse ? 1.1 : 1.0))
                    width: isCurrent ? 0 : 32
                    visible: opacity > 0

                    height: 32
                    radius: 16
                    color: Qt.rgba(0.02, 0.02, 0.02, 0.95)
                    border.color: Qt.rgba(1, 1, 1, 0.1)
                    border.width: act === "timer" ? 0 : 1

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 200
                            easing.type: Easing.OutQuad
                        }
                    }
                    Behavior on scale {
                        enabled: true
                        SpringAnimation {
                            spring: 3.5
                            damping: 0.60
                            mass: 0.8
                        }
                    }
                    Behavior on width {
                        enabled: true
                        SpringAnimation {
                            spring: 3.5
                            damping: 0.70
                            mass: 0.8
                        }
                    }

                    Canvas {
                        id: bubbleTimerProgress
                        visible: bubble.act === "timer"
                        anchors.fill: parent
                        property real progress: root.timerTotal > 0 ? (root.timerSeconds / root.timerTotal) : 0
                        onProgressChanged: requestPaint()
                        onPaint: {
                            var ctx = getContext("2d");
                            ctx.reset();

                            var r = width / 2 - 1.5;
                            if (r <= 0) return;

                            // Draw background circle (muted border)
                            ctx.beginPath();
                            ctx.arc(width / 2, height / 2, r, 0, 2 * Math.PI);
                            ctx.lineWidth = 1.5;
                            ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.15);
                            ctx.stroke();

                            // Draw active progress arc (drains clockwise)
                            ctx.beginPath();
                            ctx.arc(width / 2, height / 2, r, -Math.PI / 2, -Math.PI / 2 + (2 * Math.PI * progress));
                            ctx.lineWidth = 1.5;
                            ctx.strokeStyle = root.timerRunning ? root.colWarn : root.colFg;
                            ctx.stroke();
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: act === "media" ? "󰝚" : (act === "timer" ? "󰔛" : (act === "stopwatch" ? "󱎫" : "󰑊"))
                        color: act === "media" && root.spotifyStatus === "playing" ? root.colSpotify : (act === "recording" ? root.colCrit : root.colFg)
                        font.family: root.iconFontFamily
                        font.pixelSize: 13
                    }

                    MouseArea {
                        id: bubbleMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            if (act === "media")
                                root.islandState = root.stateMedia;
                            else if (act === "timer")
                                root.islandState = root.stateTimer;
                            else if (act === "stopwatch")
                                root.islandState = root.stateStopwatch;
                            else if (act === "recording")
                                root.islandState = root.stateRecording;
                        }
                    }
                }
            }
        }

        // ── System Tray Pill ─────────────────────────────────────────────────
        // macOS-style frosted glass pill containing privacy dots and tray icons.
        Rectangle {
            id: trayPillBg
            anchors.right:              parent.right
            anchors.rightMargin:        Math.round(12 * scaleFactor)
            anchors.verticalCenter:     parent.top
            anchors.verticalCenterOffset: root.topHuggingStyle
                                          ? Math.round(20 * scaleFactor)
                                          : Math.round(24 * scaleFactor)

            height: Math.round(32 * scaleFactor)

            // Width tracks content + padding
            width: contentRow.implicitWidth + Math.round(16 * scaleFactor)
            Behavior on width {
                SpringAnimation { spring: 4.0; damping: 0.75; mass: 0.5 }
            }

            radius: height / 2

            // Visible whenever there are tray items or privacy dots are active
            visible: opacity > 0
            opacity: (sysTray.count > 0 || root.isMicActive || root.isCamActive) ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutQuad } }

            // macOS frosted dark glass
            color: Qt.rgba(0.05, 0.05, 0.07, 0.92)
            border.color: Qt.rgba(1, 1, 1, 0.11)
            border.width: 1

            // 1px top-highlight shimmer
            Rectangle {
                anchors {
                    top:         parent.top
                    topMargin:   1
                    left:        parent.left
                    leftMargin:  Math.round(parent.radius * 0.55)
                    right:       parent.right
                    rightMargin: Math.round(parent.radius * 0.55)
                }
                height: 1
                radius: 1
                color:  Qt.rgba(1, 1, 1, 0.09)
            }

            Row {
                id: contentRow
                anchors.centerIn: parent
                spacing: Math.round(8 * scaleFactor)

                // ── Privacy indicator chip (mic / cam dots) ─────────────────
                Item {
                    id: privacyChip
                    anchors.verticalCenter: parent.verticalCenter

                    readonly property real chipWidth: (root.isMicActive || root.isCamActive)
                        ? ((root.isMicActive && root.isCamActive)
                           ? Math.round(20 * scaleFactor)
                           : Math.round(12 * scaleFactor))
                        : 0
                    width:  chipWidth
                    height: Math.round(16 * scaleFactor)
                    visible: chipWidth > 0
                    clip: true
                    Behavior on width { SpringAnimation { spring: 4.0; damping: 0.72; mass: 0.5 } }

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Math.round(4 * scaleFactor)

                        Rectangle {
                            id: micDot
                            width: Math.round(6 * scaleFactor); height: width; radius: width / 2
                            color: "#FF9500"
                            visible: root.isMicActive
                            opacity: root.isMicActive ? 1.0 : 0.0
                            scale:   root.isMicActive ? 1.0 : 0.0
                            antialiasing: true
                            Behavior on scale   { SpringAnimation { spring: 3.5; damping: 0.7; mass: 0.8 } }
                            Behavior on opacity { NumberAnimation { duration: 150 } }
                        }

                        Rectangle {
                            id: camDot
                            width: Math.round(6 * scaleFactor); height: width; radius: width / 2
                            color: "#34C759"
                            visible: root.isCamActive
                            opacity: root.isCamActive ? 1.0 : 0.0
                            scale:   root.isCamActive ? 1.0 : 0.0
                            antialiasing: true
                            Behavior on scale   { SpringAnimation { spring: 3.5; damping: 0.7; mass: 0.8 } }
                            Behavior on opacity { NumberAnimation { duration: 150 } }
                        }
                    }
                }

                // ── Tray icons ───────────────────────────────────────────────
                Repeater {
                    id: sysTray
                    model: SystemTray.items
                    delegate: Item {
                        id: trayItemRoot
                        width:  Math.round(18 * scaleFactor)
                        height: Math.round(18 * scaleFactor)

                        scale: sysTrayMouse.containsMouse ? 1.18 : 1.0
                        Behavior on scale {
                            SpringAnimation { spring: 4.5; damping: 0.65; mass: 0.6 }
                        }

                        QsMenuAnchor {
                            id: menuAnchor
                            menu: modelData.menu
                            anchor {
                                window: barWindow
                                rect: Qt.rect(0, 0, trayItemRoot.width, trayItemRoot.height)
                            }
                        }

                        IconImage {
                            anchors.fill: parent
                            source: modelData.icon
                        }

                        // Floating tooltip above icon
                        Rectangle {
                            id: trayTooltip
                            visible: sysTrayMouse.containsMouse &&
                                     (modelData.tooltip.title !== "" || modelData.title !== "")
                            anchors.bottom:           parent.top
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottomMargin:     Math.round(8 * scaleFactor)
                            width:  ttLabel.implicitWidth + Math.round(14 * scaleFactor)
                            height: ttLabel.implicitHeight + Math.round(8 * scaleFactor)
                            radius: Math.round(7 * scaleFactor)
                            color:  Qt.rgba(0.05, 0.05, 0.10, 0.96)
                            border.color: Qt.rgba(1, 1, 1, 0.14)
                            border.width: 1
                            z: 200

                            opacity: sysTrayMouse.containsMouse ? 1.0 : 0.0
                            Behavior on opacity {
                                NumberAnimation { duration: 130; easing.type: Easing.OutQuad }
                            }

                            Rectangle {
                                anchors { top: parent.top; topMargin: 1; left: parent.left; leftMargin: 4; right: parent.right; rightMargin: 4 }
                                height: 1; radius: 1
                                color: Qt.rgba(1, 1, 1, 0.08)
                            }

                            Text {
                                id: ttLabel
                                anchors.centerIn: parent
                                text: modelData.tooltip.title !== "" ? modelData.tooltip.title : modelData.title
                                color: "#ffffff"
                                font {
                                    family:    root.fontFamily
                                    pixelSize: Math.round(11 * root.scaleFactor)
                                    weight:    Font.Medium
                                }
                            }
                        }

                        MouseArea {
                            id: sysTrayMouse
                            anchors.fill:    parent
                            hoverEnabled:    true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: mouse => {
                                if (mouse.button === Qt.RightButton && modelData.hasMenu) {
                                    var pos = trayItemRoot.mapToItem(barWindow.contentItem, 0, 0);
                                    menuAnchor.anchor.rect = Qt.rect(pos.x, pos.y, trayItemRoot.width, trayItemRoot.height);
                                    menuAnchor.open();
                                } else {
                                    modelData.activate();
                                }
                            }
                        }
                    }
                }
            }
        }

        // ── Privacy dots now live inside trayPillBg ──────────────────────────
    }



    Timer {
        id: notifCloseTimer
        interval: root.notifDismissDelay
        repeat: false
        onTriggered: {
            root.notifActive = false;
        }
    }

    Timer {
        id: osdCloseTimer
        interval: 2500 // 2.5 s — polished middle-ground; timer restarts on each key press
        repeat: false
        onTriggered: {
            if (root.islandState === root.stateOsd)
                root.islandState = root.prevIslandState;
        }
    }

    IpcHandler {
        id: qsIpc
        target: "qsIpc"
        function toggleAirspace() {
            if (groundControl.show) {
                groundControl.show = false;
                groundControl.closeAllSubPopups();
            }
            airspace.toggle();
        }
        function toggleOverview() { toggleAirspace(); }
        function triggerF1Alert() {
            // DEBUG: hardcoded test values — replace with real F1 calendar data from the script
            root.f1AlertName = "Austrian GP: First Free Practice";
            root.f1AlertMins = "15";
            root.f1AlertTime = "17:00";
            root.safeSavePrev();
            root.islandState = root.stateF1Alert;
            f1AlertTimer.restart();
            queueNotification(["notify-send", "-u", "normal", "-i", "f1", "F1 Session Starting", root.f1AlertName + " starts in 15m (at " + root.f1AlertTime + ")"]);
            playSoundSafely(pPlaySound);
        }
        function triggerCpuAlert() {
            // DEBUG: hardcoded test values — real values are populated by the cpu monitoring script
            root.topCpuProcess = "chrome (42.5%)";
            root.temperature = "84";
            root.safeSavePrev();
            root.islandState = root.stateCpuAlert;
            cpuAlertTimer.restart();
            queueNotification(["notify-send", "-u", "critical", "-i", "thermal-hot", "CPU Temperature High", "CPU is at 84°C. Top process: " + root.topCpuProcess]);
            playSoundSafely(pPlaySound);
        }
        function triggerDiskAlert() {
            root.diskAlertTitle = "SanDisk Ultra USB";
            root.diskAlertSubtitle = "Connected (64 GB)";
            root.diskAlertMounted = true;
            root.safeSavePrev();
            root.islandState = root.stateDiskAlert;
            diskAlertTimer.restart();
            queueNotification(["notify-send", "-u", "normal", "-i", "drive-removable-media", "USB Connected", root.diskAlertTitle + " (" + root.diskAlertSubtitle + ")"]);
            playSoundSafely(pPlaySound);
        }

        function triggerWaterAlert() {
            root.safeSavePrev();
            root.islandState = root.stateWaterAlert;
            healthAlertTimer.restart();
            queueNotification(["notify-send", "-u", "normal", "-i", "water", "Hydration Reminder", "Time to drink some water!"]);
            playSoundSafely(pPlaySound);
        }
        function triggerStretchAlert() {
            root.safeSavePrev();
            root.islandState = root.stateStretchAlert;
            healthAlertTimer.restart();
            queueNotification(["notify-send", "-u", "normal", "-i", "stretch", "Sedentary Reminder", "Time to stand up and stretch!"]);
            playSoundSafely(pPlaySound);
        }
        function showOsd(type: string, val: string) {
            var valNum = parseFloat(val);
            if (type === "V") {
                root.osdIcon = valNum === 0 ? "󰝟" : (valNum > 50 ? "󰕾" : "󰖀");
                root.osdText = Math.round(valNum) + "%";
                root.volumeOut = Math.round(valNum) + "%";
                root.volumeMuted = (valNum === 0);
            } else if (type === "B") {
                root.osdIcon = "󰃠";
                root.osdText = Math.round(valNum) + "%";
                root.brightnessLevel = Math.round(valNum) + "%";
            }
            root.osdValue = valNum;
            root.safeSavePrev();
            root.islandState = root.stateOsd;
            osdCloseTimer.restart();
        }
        function showNotification(summary: string, body: string, icon: string) {
            console.warn("showNotification: Not implemented");
        }
        function toggleAppLauncher() {
            console.warn("toggleAppLauncher: Not implemented");
        }
        function togglePowerMenu() {
            powerMenuPopup.show = !powerMenuPopup.show;
        }
        function toggleClipboard() {
            console.warn("toggleClipboard: Not implemented");
        }
        function toggleThemeSwitcher() {
            wallpaperMenuPopup.show = !wallpaperMenuPopup.show;
        }
        function toggleWifiMenu() {
            wifiMenuPopup.show = !wifiMenuPopup.show;
        }
        function toggleBluetoothMenu() {
            bluetoothMenuPopup.show = !bluetoothMenuPopup.show;
        }
        function toggleGroundControl() {
            if (airspace.show) {
                airspace.close();
            }
            groundControl.show = !groundControl.show;
        }
        function toggleControlCenter() { toggleGroundControl(); }
        function toggleF1CalendarPopup() {
            f1CalendarPopup.show = !f1CalendarPopup.show;
        }
        function toggleEmailsPopup() {
            emailsPopup.show = !emailsPopup.show;
        }
        function toggleMediaPopup() {
            mediaPopup.show = !mediaPopup.show;
        }
        function refreshBatteryMode() {
            pTriggerStatsUpdate.running = true;
        }
        function debugScreenshotSel() {
            pScreenshotSel.running = true;
        }
        function debugRecordFull() {
            pRecordFull.running = true;
        }
        function startRecording() {
            if (!root.isRecording) {
                root.isRecording = true;
                root.recordingSeconds = 0;
                root.recordingTime = "0:00";
                recordingTimer.start();
                if (root.islandState === root.stateCompact)
                    root.islandState = root.stateRecording;
            }
        }
        function stopRecording() {
            if (root.isRecording) {
                root.isRecording = false;
                recordingTimer.stop();
                root.recordingSeconds = 0;
                root.recordingTime = "0:00";
                if (root.islandState === root.stateRecording)
                    root.islandState = root.stateCompact;
            }
        }
    }

    NotificationServer {
        id: notifServer
        keepOnReload: false
        actionsSupported: true
        bodyMarkupSupported: true
        imageSupported: true
        onNotification: notif => {
            console.log("onNotification received: summary=" + notif.summary + ", dndActive=" + root.dndActive);
            if (!root.dndActive) {
                root.currentNotif = notif;
                root.notifTitle = notif.summary ? notif.summary : "";
                root.notifBody = notif.body ? notif.body : "";
                root.notifIcon = notif.appIcon ? notif.appIcon : "";
                root.notifActive = true;
                root.notifCloseTimer.restart();
                root.notificationReceived();
                playSoundSafely(pPlaySound);
            }

            var found = false;
            for (var i = 0; i < notifList.count; i++) {
                if (notifList.get(i).notifId === notif.id) {
                    notifList.set(i, {
                        "notifId": notif.id,
                        "summary": notif.summary ? notif.summary : "",
                        "body": notif.body ? notif.body : "",
                        "appName": notif.appName ? notif.appName : "",
                        "appIcon": notif.appIcon ? notif.appIcon : "",
                        "notifObj": notif
                    });
                    found = true;
                    break;
                }
            }
            if (!found) {
                notifList.insert(0, {
                    "notifId": notif.id,
                    "summary": notif.summary ? notif.summary : "",
                    "body": notif.body ? notif.body : "",
                    "appName": notif.appName ? notif.appName : "",
                    "appIcon": notif.appIcon ? notif.appIcon : "",
                    "notifObj": notif
                });
            }
        }
    }

    GroundControl {
        id: groundControl
        shellRoot: root
        notchLayoutWidth: root.notchWidth
    }

    TimerPopup {
        id: timerPopup
        shellRoot: root
        groundControlWindow: groundControl
    }

    F1CalendarPopup {
        id: f1CalendarPopup
        shellRoot: root
        groundControlWindow: groundControl
    }

    EmailsPopup {
        id: emailsPopup
        shellRoot: root
        groundControlWindow: groundControl
    }

    PowerMenu {
        id: powerMenuPopup
        shellRoot: root
    }

    WifiMenu {
        id: wifiMenuPopup
        shellRoot: root
    }

    BluetoothMenu {
        id: bluetoothMenuPopup
        shellRoot: root
    }

    WallpaperMenu {
        id: wallpaperMenuPopup
        shellRoot: root
    }

    NotificationPopup {
        id: notifPopup
        shellRoot: root
    }

    MediaPopup {
        id: mediaPopup
        shellRoot: root
    }

    SonomaWidgets {
        id: sonomaWidgets
        shellRoot: root
    }

    Airspace {
        id: airspace
        shellRoot: root
    }

    FlightDeck {
        id: flightDeck
        shellRoot: root
    }

    SettingsWindow {
        id: settingsWindow
        shellRoot: root
    }

    Component.onDestruction: {
        isDestroying = true;
        pSpotify.running = false;
        pStats.running = false;
    }
}
