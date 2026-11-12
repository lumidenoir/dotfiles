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
import QtQuick.Effects
import Quickshell.Services.Mpris
import "Singletons"

ShellRoot {
    id: root
    readonly property real fontScale: scaleFactor * root.fontSizeMultiplier
    property bool _initApp: {
        Qt.application.organization = "Quickshell";
        Qt.application.domain = "quickshell.org";
        Qt.application.name = "Quickshell";
        return true;
    }
    property real wallTopBrightness: 0.5
    property real scaleFactorOverride: 0.0
    property int themeOverride: 0 // 0: Auto, 1: Force Light, 2: Force Dark
    property real darkOpacity: 0.60
    property real lightOpacity: 0.12
    property real fontSizeMultiplier: 1.0
    property int visualizerShader: 0 // 0: Glow, 1: Silk Waves, 2: Cyber Bars, 3: Radial Aura

    property bool wallTopIsDark: {
        if (themeOverride === 1) return true;
        if (themeOverride === 2) return false;
        return !isPearlMode;
    }

    property color colBg: {
        if (wallTopIsDark) {
            return Qt.rgba(1, 1, 1, lightOpacity);
        } else {
            return Qt.rgba(0.08, 0.08, 0.09, darkOpacity);
        }
    }
    
    property color colBorder: {
        if (wallTopIsDark) {
            return Qt.rgba(1, 1, 1, 0.22);
        } else {
            return Qt.rgba(1, 1, 1, 0.08);
        }
    }

    function runProcessSafely(proc, cmdArr) {
        if (proc && !proc.running) {
            if (cmdArr !== undefined && cmdArr !== null) {
                proc.command = cmdArr;
            }
            proc.running = true;
        }
    }

    function checkWallpaperBrightness() {
        // Decommissioned: HUD wallpaper runs on OLED dark palette
    }

    property real wallLuminance: 0.50
    property real wallSigma: 0.05
    property real wallSaturation: 0.20
    property string wallDominantHex: "#6D4A54"
    readonly property color wallDominantColor: Qt.color(wallDominantHex)
    property string userGlassPreference: "auto"
    property bool autoGlassMode: userGlassPreference === "auto"

    // Dynamic Apple Vibrancy Palette (Calibrated SF Deep Ink with subtle ambient environmental tinting)
    readonly property color colVibrantInk: {
        var r = Math.min(0.18, 0.114 + (wallDominantColor.r * 0.03));
        var g = Math.min(0.18, 0.114 + (wallDominantColor.g * 0.03));
        var b = Math.min(0.19, 0.122 + (wallDominantColor.b * 0.03));
        return Qt.rgba(r, g, b, 0.98); // Apple SF Ink #1D1D1F
    }
    readonly property color colVibrantSecondary: {
        var r = Math.min(0.50, 0.431 + (wallDominantColor.r * 0.04));
        var g = Math.min(0.50, 0.431 + (wallDominantColor.g * 0.04));
        var b = Math.min(0.52, 0.451 + (wallDominantColor.b * 0.04));
        return Qt.rgba(r, g, b, 0.88); // Apple Secondary #6E6E73
    }
    readonly property color colVibrantMuted: {
        var r = Math.min(0.60, 0.525 + (wallDominantColor.r * 0.04));
        var g = Math.min(0.60, 0.525 + (wallDominantColor.g * 0.04));
        var b = Math.min(0.62, 0.545 + (wallDominantColor.b * 0.04));
        return Qt.rgba(r, g, b, 0.75); // Apple Tertiary #86868B
    }

    property string wallpaperPath: ""

    FileView {
        path: (Quickshell.env("HOME") || "/home/krishna") + "/.cache/wallpaper"
        watchChanges: true
        printErrors: false
        onFileChanged: {
            var p = text().trim();
            if (p.length > 0) {
                root.wallpaperPath = p;
                root.checkWallpaperBrightness();
            }
        }
    }

    Process {
        id: pGetWallpaperPath
        command: ["cat", (Quickshell.env("HOME") || "/home/krishna") + "/.cache/wallpaper"]
        stdout: SplitParser {
            onRead: data => {
                var p = data.trim();
                if (p.length > 0 && p !== root.wallpaperPath) {
                    root.wallpaperPath = p;
                    root.checkWallpaperBrightness();
                }
            }
        }
    }

    Timer {
        id: wallPollTimer
        interval: 2500
        running: true
        repeat: true
        onTriggered: root.runProcessSafely(pGetWallpaperPath)
    }

    readonly property Item wallpaperBackdropRoot: Item {
        id: wallpaperBackdropRoot
        width: Screen.width > 0 ? Screen.width : 1920
        height: Screen.height > 0 ? Screen.height : 1080
        z: -999
        opacity: 0.001

        Image {
            id: wallpaperImg
            anchors.fill: parent
            source: root.wallpaperPath !== "" ? ("file://" + root.wallpaperPath) : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }
    }
    readonly property alias wallpaperBackdropItem: wallpaperBackdropRoot

    // Dynamic color tint for light wallpapers to enhance contrast
    property color colTint: {
        if (wallTopIsDark) {
            return Qt.rgba(0.0, 0.0, 0.0, 0.0);
        } else {
            return Qt.rgba(0.04, 0.04, 0.06, 0.15);
        }
    }

    property color colGlass: {
        if (wallTopIsDark) {
            return Qt.rgba(1, 1, 1, 0.08);
        } else {
            return Qt.rgba(0.06, 0.06, 0.08, 0.50);
        }
    }

    // =========================================================================
    // VISIONOS 2-TIER SPATIAL GLASS ENGINE ("frosted" | "dark")
    // =========================================================================
    property string glassMode: "frosted"
    readonly property bool isPearlMode: false
    readonly property bool isFrostedMode: glassMode === "frosted"
    readonly property bool isDarkMode: glassMode === "dark" || glassMode === "apple_dark"
    readonly property real appleGlassModeValue: isDarkMode ? 1.0 : 0.0

    property real customFrostBlur: 0.88
    readonly property real glassBlurAmount: root.customFrostBlur
    readonly property real glassRefraction: isFrostedMode ? 0.38 : 0.40
    readonly property real glassChromAberration: 0.020
    readonly property real glassEdgeHighlight: isDarkMode ? 0.32 : 0.28
    readonly property real glassFresnel: 0.80
    readonly property real glassBrightness: isDarkMode ? -0.20 : 0.0
    readonly property real glassSaturation: isDarkMode ? 0.15 : 0.10
    readonly property real glassBevelMode: 0.0
    readonly property real glassZRadius: 28.0

    Process {
        id: pReadGlassMode
        command: ["cat", (Quickshell.env("HOME") || "/home/krishna") + "/.cache/quickshell_glass_mode"]
        stdout: SplitParser {
            onRead: data => {
                var m = data.trim();
                if (m === "auto") {
                    root.userGlassPreference = "auto";
                    root.autoGlassMode = true;
                    root.checkWallpaperBrightness();
                } else if (m === "frosted" || m === "dark" || m === "apple_dark") {
                    root.userGlassPreference = m;
                    root.autoGlassMode = false;
                    if (root.glassMode !== m) root.glassMode = m;
                } else {
                    // Default fallback for legacy "pearl" or unrecognized values
                    root.userGlassPreference = "frosted";
                    root.autoGlassMode = false;
                    root.glassMode = "frosted";
                }
            }
        }
    }

    Process {
        id: pWriteGlassMode
    }

    function setGlassMode(mode) {
        if (mode === "auto") {
            root.userGlassPreference = "auto";
            root.autoGlassMode = true;
            pWriteGlassMode.command = ["sh", "-c", "mkdir -p " + (Quickshell.env("HOME") || "/home/krishna") + "/.cache && echo -n auto > " + (Quickshell.env("HOME") || "/home/krishna") + "/.cache/quickshell_glass_mode"];
            if (pWriteGlassMode.running) pWriteGlassMode.running = false;
            pWriteGlassMode.running = true;
            root.checkWallpaperBrightness();
            return;
        }
        var targetMode = (mode === "dark" || mode === "apple_dark") ? "dark" : "frosted";
        root.userGlassPreference = targetMode;
        root.autoGlassMode = false;
        root.glassMode = targetMode;
        pWriteGlassMode.command = ["sh", "-c", "mkdir -p " + (Quickshell.env("HOME") || "/home/krishna") + "/.cache && echo -n " + targetMode + " > " + (Quickshell.env("HOME") || "/home/krishna") + "/.cache/quickshell_glass_mode"];
        if (pWriteGlassMode.running) pWriteGlassMode.running = false;
        pWriteGlassMode.running = true;
    }

    // =========================================================================
    // MINIMO BOT APPEARANCE ("dark" | "light")
    // =========================================================================
    property string minimoBotMode: "dark"
    readonly property bool isMinimoLightMode: minimoBotMode === "light"

    Process {
        id: pReadMinimoBotMode
        command: ["cat", (Quickshell.env("HOME") || "/home/krishna") + "/.cache/quickshell_minimo_mode"]
        stdout: SplitParser {
            onRead: data => {
                var m = data.trim();
                if (m === "light" || m === "dark") {
                    root.minimoBotMode = m;
                }
            }
        }
    }

    Process {
        id: pWriteMinimoBotMode
    }

    function setMinimoBotMode(mode) {
        var targetMode = (mode === "light") ? "light" : "dark";
        root.minimoBotMode = targetMode;
        pWriteMinimoBotMode.command = ["sh", "-c", "mkdir -p " + (Quickshell.env("HOME") || "/home/krishna") + "/.cache && echo -n " + targetMode + " > " + (Quickshell.env("HOME") || "/home/krishna") + "/.cache/quickshell_minimo_mode"];
        if (pWriteMinimoBotMode.running) pWriteMinimoBotMode.running = false;
        pWriteMinimoBotMode.running = true;
    }

    function toggleThemeMode() {
        if (root.glassMode === "dark" || root.glassMode === "apple_dark") {
            root.setGlassMode("frosted");
        } else {
            root.setGlassMode("dark");
        }
    }

    readonly property color colFgPrimary: "#ffffff"
    readonly property color colFgSecondary: Qt.rgba(1.0, 1.0, 1.0, 0.70)
    readonly property color colBgPill: isFrostedMode ? Qt.rgba(0, 0, 0, 0.28) : Qt.rgba(0, 0, 0, 0.35)
    readonly property color colCardBorder: Qt.rgba(1.0, 1.0, 1.0, 0.12)
    readonly property color colCardInner: Qt.rgba(1.0, 1.0, 1.0, 0.04)

    property color colFg: "#ffffff"
    property color colAccent: "#0A84FF" // Apple System Blue
    property color colAccentSecondary: "#30D158" // Apple System Green
    property color colMuted: Qt.rgba(1, 1, 1, 0.50)
    property color colHover: Qt.rgba(1, 1, 1, 0.15)
    property color colCrit: "#FF453A" // Apple System Red
    property color colSuccess: "#30D158" // Apple System Green
    property color colWarn: "#FF9F0A" // Apple System Orange
    property color colSpotify: "#30D158"
    property real scaleFactor: scaleFactorOverride > 0.0 ? scaleFactorOverride : (Screen.width > 2560 ? 1.25 : (Screen.width > 1920 ? 1.125 : 1.0))
    property string fontFamily: "Ioskeley Mono"
    property string textFontFamily: "Ioskeley Mono"
    property string monoFontFamily: "Ioskeley Mono"
    property string roundedFontFamily: "Ioskeley Mono"
    property string serifFontFamily: "Ioskeley Mono"
    property string iconFontFamily: "Symbols Nerd Font"
    property string nerdFontFamily: "Symbols Nerd Font"

    FontLoader { source: "file:///home/krishna/.local/share/fonts/i/IoskeleyMono_Regular.ttf" }
    FontLoader { source: "file:///home/krishna/.local/share/fonts/i/IoskeleyMono_Bold.ttf" }
    FontLoader { source: "file:///home/krishna/.local/share/fonts/i/IoskeleyMono_Medium.ttf" }
    FontLoader { source: "file:///home/krishna/.local/share/fonts/i/IoskeleyMono_SemiBold.ttf" }
    property int fontSize: Math.round(11 * scaleFactor)
    property bool isDestroying: false
    property bool hasBattery: false

    property var activeNotifQueue: []
    // Computed — always in sync with activeNotifQueue, never manually written
    readonly property bool notifActive: activeNotifQueue.length > 0
    readonly property var currentNotifGroup: activeNotifQueue.length > 0 ? activeNotifQueue[0] : null
    readonly property var currentNotifItem: (currentNotifGroup && currentNotifGroup.notifications && currentNotifGroup.notifications.length > 0) ? currentNotifGroup.notifications[0] : null
    readonly property var currentNotifId: currentNotifItem ? (currentNotifItem.notifId !== undefined ? currentNotifItem.notifId : currentNotifItem.id) : null
    readonly property string notifTitle: currentNotifItem ? currentNotifItem.summary : ""
    readonly property string notifBody: currentNotifItem ? currentNotifItem.body : ""
    readonly property string notifIcon: currentNotifGroup ? currentNotifGroup.appIcon : ""
    readonly property var notifActions: currentNotifItem ? (currentNotifItem.actions || []) : []
    readonly property bool notifHasActions: currentNotifItem ? (currentNotifItem.hasActions || (currentNotifItem.actions && currentNotifItem.actions.length > 0)) : false

    property real notifProgress: 1.0
    PropertyAnimation {
        id: notifProgressAnim
        target: root
        property: "notifProgress"
        from: 1.0
        to: 0.0
        duration: notifCloseTimer.interval
        running: notifCloseTimer.running
    }

    property var _lastShownNotifId: -1

    onActiveNotifQueueChanged: {
        if (activeNotifQueue.length > 0) {
            var head = activeNotifQueue[0].notifications[0];
            if (head && head.id !== _lastShownNotifId) {
                _lastShownNotifId = head.id;
                notifCloseTimer.interval = root.notifDismissDelay;
                notifCloseTimer.restart();
            }
        } else {
            _lastShownNotifId = -1;
            notifCloseTimer.stop();
        }
    }

    function removeNotificationById(notifId) {
        if (!notifId && notifId !== 0) return;

        // 1. Remove from activeNotifQueue
        var newQueue = [];
        for (var i = 0; i < activeNotifQueue.length; i++) {
            var group = activeNotifQueue[i];
            var notifs = group.notifications.filter(function(n) { return n && n.id !== notifId; });
            if (notifs.length > 0) {
                newQueue.push({
                    appName: group.appName,
                    appIcon: group.appIcon,
                    notifications: notifs
                });
            }
        }
        activeNotifQueue = newQueue;
        // groupedNotifList auto-derives from activeNotifQueue — no manual update needed
    }

    function dismissFrontNotification() {
        if (activeNotifQueue.length > 0) {
            var newQueue = activeNotifQueue.slice();
            var frontGroup = newQueue[0];
            if (frontGroup.notifications && frontGroup.notifications.length > 1) {
                var groupNotifs = frontGroup.notifications.slice();
                groupNotifs.shift();
                newQueue[0] = {
                    appName: frontGroup.appName,
                    appIcon: frontGroup.appIcon,
                    notifications: groupNotifs
                };
                activeNotifQueue = newQueue;
                // Force triggering re-check of head ID and restart close timer
                var head = groupNotifs[0];
                if (head) {
                    _lastShownNotifId = head.id;
                    notifCloseTimer.interval = root.notifDismissDelay;
                    notifCloseTimer.restart();
                }
            } else {
                newQueue.shift();
                activeNotifQueue = newQueue;
            }
        }
    }

    // Safe C++ Notification Object lookup map
    property var _notifObjMap: ({})
    // Cache of live NotificationAction objects: { "notifId:actionId": actionObject }
    property var _actionObjMap: ({})

    function registerNotifObj(notif) {
        if (!notif || !notif.id) return;
        notif.tracked = true; // Keep the D-Bus notification alive!
        _notifObjMap[notif.id] = notif;

        // Store each individual action object for direct invocation later
        try {
            var acts = notif.actions;
            if (acts && acts.length > 0) {
                for (var i = 0; i < acts.length; i++) {
                    var a = acts[i];
                    if (a && a.identifier) {
                        _actionObjMap[notif.id + ":" + a.identifier] = a;
                        console.log("Registered action: " + notif.id + ":" + a.identifier + " = " + a.text);
                    }
                }
            }
        } catch(e) {
            console.log("Error registering actions: " + e);
        }
    }

    function invokeNotificationAction(notifId, actionId) {
        console.log("invokeNotificationAction: notifId=" + notifId + " actionId=" + actionId);
        try {
            // First try the direct cached action object (most reliable)
            var key = notifId + ":" + (actionId || "default");
            var cachedAction = _actionObjMap[key];
            if (cachedAction && typeof cachedAction.invoke === "function") {
                console.log("Invoking cached action: " + key);
                cachedAction.invoke();
            } else {
                // Fallback: iterate n.actions directly via index
                var n = _notifObjMap[notifId];
                if (n) {
                    var invoked = false;
                    for (var i = 0; i < n.actions.length; i++) {
                        var a = n.actions[i];
                        if (a && a.identifier === (actionId || "default")) {
                            console.log("Invoking indexed action: " + a.identifier);
                            if (typeof a.invoke === "function") { a.invoke(); invoked = true; break; }
                        }
                    }
                    if (!invoked) console.log("No matching action found for actionId=" + actionId);
                } else {
                    console.log("No notification object for id=" + notifId);
                }
            }
        } catch(e) {
            console.log("Error invoking notification action: " + e);
        }
        // Clean up action entries for this notification
        try {
            for (var k in _actionObjMap) {
                if (k.indexOf(notifId + ":") === 0) delete _actionObjMap[k];
            }
        } catch(e2) {}
        
        var nRef = _notifObjMap[notifId];
        delete _notifObjMap[notifId];
        removeNotificationById(notifId);
        removeNotificationFromList(notifId);

        // Delay dismissing the D-Bus notification slightly to ensure ActionInvoked signal is fully sent to the client first
        if (nRef) {
            root.delayedDismissQueue.push(nRef);
            delayedDismissTimer.restart();
        }
    }

    property var delayedDismissQueue: []
    Timer {
        id: delayedDismissTimer
        interval: 200
        repeat: false
        onTriggered: {
            while (root.delayedDismissQueue.length > 0) {
                var n = root.delayedDismissQueue.shift();
                if (n && typeof n.dismiss === "function") {
                    n.dismiss();
                } else if (n && typeof n.close === "function") {
                    n.close();
                } else if (n) {
                    n.tracked = false;
                }
            }
        }
    }

    function dismissNotificationSafely(notifId) {
        try {
            var n = _notifObjMap[notifId];
            if (n && typeof n.dismiss === "function") {
                n.dismiss();
            } else if (n && typeof n.close === "function") {
                n.close();
            }
        } catch(e) {}
        delete _notifObjMap[notifId];
        removeNotificationById(notifId);
        removeNotificationFromList(notifId);
    }

    function dismissNotificationGroup(appName) {
        if (!appName) return;

        // 1. Collect all notification IDs for this app
        var idsToDismiss = [];
        for (var i = 0; i < root.groupedNotifList.length; i++) {
            if (root.groupedNotifList[i].appName === appName) {
                var notifs = root.groupedNotifList[i].notifications;
                for (var k = 0; k < notifs.length; k++) {
                    var nId = notifs[k].notifId !== undefined ? notifs[k].notifId : notifs[k].id;
                    if (nId !== undefined && nId !== null) idsToDismiss.push(nId);
                }
                break;
            }
        }

        // 2. Also check activeNotifQueue for any matching notifications
        for (var a = 0; a < root.activeNotifQueue.length; a++) {
            if (root.activeNotifQueue[a].appName === appName) {
                var qNotifs = root.activeNotifQueue[a].notifications;
                for (var qk = 0; qk < qNotifs.length; qk++) {
                    var qId = qNotifs[qk].notifId !== undefined ? qNotifs[qk].notifId : qNotifs[qk].id;
                    if (qId !== undefined && qId !== null && idsToDismiss.indexOf(qId) === -1) {
                        idsToDismiss.push(qId);
                    }
                }
            }
        }

        // 3. Dismiss D-Bus notification objects
        for (var d = 0; d < idsToDismiss.length; d++) {
            var notifId = idsToDismiss[d];
            try {
                var obj = _notifObjMap[notifId];
                if (obj) {
                    if (typeof obj.dismiss === "function") obj.dismiss();
                    else if (typeof obj.close === "function") obj.close();
                }
            } catch(e) {}
            delete _notifObjMap[notifId];
        }

        // 4. Atomically remove from activeNotifQueue
        var newQueue = [];
        for (var qi = 0; qi < root.activeNotifQueue.length; qi++) {
            if (root.activeNotifQueue[qi].appName !== appName) {
                newQueue.push(root.activeNotifQueue[qi]);
            }
        }
        root.activeNotifQueue = newQueue;

        // 5. Atomically remove from groupedNotifList in one assignment
        var newList = [];
        for (var gi = 0; gi < root.groupedNotifList.length; gi++) {
            if (root.groupedNotifList[gi].appName !== appName) {
                newList.push(root.groupedNotifList[gi]);
            }
        }
        root.groupedNotifList = newList;

        // 6. Clean up expanded map entry
        var map = Object.assign({}, root._groupExpandedMap);
        delete map[appName];
        root._groupExpandedMap = map;
    }

    // ── Persistent Notification Center List (Ground Control) ──
    property var _groupExpandedMap: ({})
    property var groupedNotifList: []

    readonly property int totalNotifCount: {
        var count = 0;
        for (var i = 0; i < groupedNotifList.length; i++) {
            if (groupedNotifList[i].notifications)
                count += groupedNotifList[i].notifications.length;
        }
        return count;
    }

    function addNotificationToList(notifItem) {
        if (!notifItem) return;
        var appName = notifItem.appName ? notifItem.appName : "System";
        var appIcon = notifItem.appIcon ? notifItem.appIcon : "";
        var nId = notifItem.id !== undefined ? notifItem.id : notifItem.notifId;

        var listCopy = root.groupedNotifList.slice();
        var groupFound = false;

        for (var i = 0; i < listCopy.length; i++) {
            if (listCopy[i].appName === appName) {
                var notifs = listCopy[i].notifications.slice();
                var dupIndex = -1;
                for (var k = 0; k < notifs.length; k++) {
                    var currId = notifs[k].id !== undefined ? notifs[k].id : notifs[k].notifId;
                    if (currId === nId) {
                        dupIndex = k;
                        break;
                    }
                }
                if (dupIndex !== -1) {
                    notifs[dupIndex] = notifItem;
                } else {
                    notifs.unshift(notifItem);
                }
                listCopy[i] = {
                    appName: appName,
                    appIcon: appIcon,
                    isExpanded: root._groupExpandedMap[appName] === true,
                    notifications: notifs
                };
                if (i > 0) {
                    var updatedGroup = listCopy.splice(i, 1)[0];
                    listCopy.unshift(updatedGroup);
                }
                groupFound = true;
                break;
            }
        }

        if (!groupFound) {
            listCopy.unshift({
                appName: appName,
                appIcon: appIcon,
                isExpanded: root._groupExpandedMap[appName] === true,
                notifications: [notifItem]
            });
        }

        root.groupedNotifList = listCopy;
    }

    function removeNotificationFromList(notifId) {
        if (!notifId && notifId !== 0) return;

        var listCopy = [];
        for (var i = 0; i < root.groupedNotifList.length; i++) {
            var group = root.groupedNotifList[i];
            var notifs = group.notifications.filter(function(n) {
                var id = n.notifId !== undefined ? n.notifId : n.id;
                return id !== notifId;
            });
            if (notifs.length > 0) {
                listCopy.push({
                    appName: group.appName,
                    appIcon: group.appIcon,
                    isExpanded: root._groupExpandedMap[group.appName] === true,
                    notifications: notifs
                });
            }
        }
        root.groupedNotifList = listCopy;
    }

    function toggleGroupExpanded(index) {
        if (index < 0 || index >= root.groupedNotifList.length) return;
        var appName = root.groupedNotifList[index].appName;
        var map = Object.assign({}, root._groupExpandedMap);
        map[appName] = !(map[appName] === true);
        root._groupExpandedMap = map;

        var listCopy = root.groupedNotifList.slice();
        for (var i = 0; i < listCopy.length; i++) {
            if (listCopy[i].appName === appName) {
                listCopy[i] = {
                    appName: listCopy[i].appName,
                    appIcon: listCopy[i].appIcon,
                    isExpanded: map[appName] === true,
                    notifications: listCopy[i].notifications
                };
                break;
            }
        }
        root.groupedNotifList = listCopy;
    }

    function clearAllNotifications() {
        for (var i = 0; i < root.groupedNotifList.length; i++) {
            var group = root.groupedNotifList[i];
            for (var j = 0; j < group.notifications.length; j++) {
                var nId = group.notifications[j].notifId !== undefined ? group.notifications[j].notifId : group.notifications[j].id;
                if (nId !== undefined && nId !== null) {
                    try {
                        var n = _notifObjMap[nId];
                        if (n) {
                            if (typeof n.dismiss === "function") n.dismiss();
                            else if (typeof n.close === "function") n.close();
                        }
                    } catch(e) {}
                    delete _notifObjMap[nId];
                }
            }
        }
        for (var a = 0; a < root.activeNotifQueue.length; a++) {
            var ag = root.activeNotifQueue[a];
            for (var b = 0; b < ag.notifications.length; b++) {
                var anId = ag.notifications[b].notifId !== undefined ? ag.notifications[b].notifId : ag.notifications[b].id;
                if (anId !== undefined && anId !== null) {
                    try {
                        var an = _notifObjMap[anId];
                        if (an) {
                            if (typeof an.dismiss === "function") an.dismiss();
                            else if (typeof an.close === "function") an.close();
                        }
                    } catch(e) {}
                    delete _notifObjMap[anId];
                }
            }
        }
        root._groupExpandedMap = {};
        root.activeNotifQueue = [];
        root.groupedNotifList = [];
    }

    property real notchWidth: notchRect && notchRect.notchLayout ? notchRect.notchLayout.implicitWidth : 0
    property alias notchRect: notchRect
    readonly property var _notchWidths: ({
        [root.stateMedia]: 380 * scaleFactor,
        [root.stateTimer]: 340 * scaleFactor,
        [root.stateStopwatch]: 340 * scaleFactor,
        [root.stateRecording]: 280 * scaleFactor,
        [root.stateOsd]: 200 * scaleFactor,
        [root.stateBatteryLow]: 200 * scaleFactor,
        [root.stateCharging]: 200 * scaleFactor,
        [root.stateDnd]: 200 * scaleFactor,
        [root.stateWaterAlert]: 360 * scaleFactor,
        [root.stateStretchAlert]: 360 * scaleFactor,
        [root.statePomodoro]: 360 * scaleFactor,
        [root.stateF1Alert]: 260 * scaleFactor,
        [root.stateCpuAlert]: 280 * scaleFactor,
        [root.stateDragLocalSend]: 340 * scaleFactor,
        [root.stateLocalSendSuccess]: 260 * scaleFactor,
        [root.stateComms]: 220 * scaleFactor,
        [root.stateDiskAlert]: 290 * scaleFactor,
        [root.stateNudge]: Math.round(440 * scaleFactor)
    })

    property bool bootSettled: false
    Timer {
        interval: 3000
        running: true
        repeat: false
        onTriggered: root.bootSettled = true
    }


    property bool unlockTriggerPrimed: false
    Timer {
        interval: 800
        running: true
        repeat: false
        onTriggered: root.unlockTriggerPrimed = true
    }
    FileView {
        path: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/ricelin-unlock-trigger"
        watchChanges: true
        printErrors: false
        onLoadFailed: setText("0")
        onFileChanged: {
            if (root.unlockTriggerPrimed) {
                root.isLocked = false;
            }
        }
    }

    FileView {
        path: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/ricelin-lock-trigger"
        watchChanges: true
        printErrors: false
        onLoadFailed: setText("0")
        onFileChanged: {
            if (root.unlockTriggerPrimed) {
                root.isLocked = true;
                root.closeAllPopups();
            }
        }
    }

    property real _cachedNotchWidth: 180 * scaleFactor
    Connections {
        target: notchRect && notchRect.notchLayout ? notchRect.notchLayout : null
        // Only update while in compact with a stability threshold to prevent tiny text changes
        // from causing feedback loops and width jitter.
        function onImplicitWidthChanged() {
            if (root.islandState === root.stateCompact && !root.isAnyPopupOpen && notchRect && notchRect.notchLayout) {
                var target = Math.round(notchRect.notchLayout.implicitWidth + 40 * scaleFactor);
                if (Math.abs(target - root._cachedNotchWidth) >= 3) {
                    root._cachedNotchWidth = target;
                }
            }
        }
    }
    // Also refresh when *returning* to compact, in case modules changed
    // while the island was in another state (e.g. Spotify started while in media state).
    onIslandStateChanged: {
        if (root.islandState === root.stateCompact && notchRect && notchRect.notchLayout) {
            var target = Math.round(notchRect.notchLayout.implicitWidth + 40 * scaleFactor);
            if (Math.abs(target - root._cachedNotchWidth) >= 3) {
                root._cachedNotchWidth = target;
            }
        }
    }
    Component.onCompleted: {
        if (notchRect && notchRect.notchLayout) {
            root._cachedNotchWidth = Math.round(notchRect.notchLayout.implicitWidth + 40 * scaleFactor);
        }
        root.runProcessSafely(pGetWallpaperPath);
        root.runProcessSafely(pReadGlassMode);
        root.runProcessSafely(pReadMinimoBotMode);
        root.checkWallpaperBrightness();
        root.runProcessSafely(pVolumeOut);
        root.runProcessSafely(pVolumeMic);
        root.loadScratchpad();
    }
    // Dynamic boundary capping: ensures center notch never overlaps left/right capsules
    readonly property real closedNotchWidth: {
        var screenW = Screen.width;
        var targetW;
        if (islandState === root.stateDiskAlert) {
            var layoutW = (typeof diskAlertLayout !== "undefined" && diskAlertLayout) ? diskAlertLayout.implicitWidth : (290 * scaleFactor - 28);
            targetW = Math.max(180 * scaleFactor, Math.min(360 * scaleFactor, layoutW + 28));
        } else {
            targetW = _notchWidths[islandState] ?? _cachedNotchWidth;
        }
        var rCapW = (typeof rightCapsule !== "undefined" && rightCapsule) ? rightCapsule.width : Math.round(280 * scaleFactor);
        var lCapW = (typeof leftCapsule !== "undefined" && leftCapsule) ? leftCapsule.width : Math.round(200 * scaleFactor);
        var rightBoundary = screenW - rCapW - Math.round(24 * scaleFactor);
        var leftBoundary = Math.round(12 * scaleFactor) + lCapW + Math.round(12 * scaleFactor);
        var maxCenterW = Math.min((rightBoundary - screenW / 2) * 2, (screenW / 2 - leftBoundary) * 2);
        var safeMaxW = Math.max(140 * scaleFactor, maxCenterW);
        return Math.min(targetW, safeMaxW);
    }
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
    readonly property int statePomodoro: 18
    readonly property int stateNudge: 19
    property string diskAlertTitle: ""
    property string diskAlertSubtitle: ""
    property bool diskAlertMounted: true
    property string diskAlertDev: ""
    property string diskAlertType: "usb" // "usb" | "phone" | "bluetooth"


    property bool topHuggingStyle: false
    property real notchSpringStiffness: 4.2
    property real notchSpringDamping: 0.72
    property real notchSpringMass: 0.65
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
        property alias scaleFactorOverride: root.scaleFactorOverride
        property alias themeOverride: root.themeOverride
        property alias darkOpacity: root.darkOpacity
        property alias lightOpacity: root.lightOpacity
        property alias fontSizeMultiplier: root.fontSizeMultiplier
        property alias visualizerShader: root.visualizerShader
    }

    property int islandState: stateCompact
    property int prevIslandState: stateCompact // for restoring after OSD

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
    property alias audiophilePlayer: audiophilePlayer
    property alias audiophileMiniPlayer: audiophileMiniPlayer
    property alias pOcrShot: pOcrShot
    property alias audioPopup: audioPopup
    property var wifiMenuPopup: null
    property alias bluetoothMenuPopup: bluetoothMenuPopup
    property alias timerPopup: timerPopup
    property alias alarmReminderPill: alarmReminderPill
    property alias calendarPopup: calendarPopup
    property alias f1CalendarPopup: f1CalendarPopup
    property alias emailsPopup: emailsPopup
    property var wallpaperMenuPopup: null
    property alias screenshotMenuPopup: screenshotMenuPopup
    property alias screenSelector: screenSelector
    property alias settingsWindow: settingsWindow
    property var sparklinePopup: null
    property var powerProfilePopup: null
    property alias sinkModel: sinkModel
    property alias pListSinks: pListSinks
    property alias pSetSink: pSetSink
    property alias pCaffeineToggle: pCaffeineToggle
    property alias pAudiophileToggle: pAudiophileToggle
    property alias pKeybindings: pKeybindings
    property alias pTriggerStatsUpdate: pTriggerStatsUpdate
    property alias barWindow: barWindow
    property alias recordingTimer: recordingTimer
    property var groundControl: null
    property var airspace: null

    property var cpuHistory: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    property var ramHistory: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]

    // Reactive list — re-evaluates automatically when any input property changes
    property var activeActivities: {
        var list = [];
        if (root.pomodoroActive && (root.pomodoroRunning || root.pomodoroSeconds > 0))
            list.push("pomodoro");
        if (root.spotifyStatus === "playing")
            list.push("media");
        if (root.timerRunning || (root.timerSeconds > 0 && root.timerSeconds < root.timerTotal))
            list.push("timer");
        if (root.stopwatchRunning || root.stopwatchSeconds > 0)
            list.push("stopwatch");
        if (root.isRecording)
            list.push("recording");
        if (root.isMicActive)
            list.push("comms");
        return list;
    }

    // Continuous activities default to compact pill notch display (isMaximized: false).
    // When an activity starts, notch switches to its minimized pill.
    onActiveActivitiesChanged: {
        var acts = root.activeActivities;
        var currentAct = "";
        if (root.islandState === root.statePomodoro)
            currentAct = "pomodoro";
        else if (root.islandState === root.stateMedia)
            currentAct = "media";
        else if (root.islandState === root.stateTimer)
            currentAct = "timer";
        else if (root.islandState === root.stateStopwatch)
            currentAct = "stopwatch";
        else if (root.islandState === root.stateRecording)
            currentAct = "recording";
        else if (root.islandState === root.stateComms)
            currentAct = "comms";

        if (currentAct !== "" && acts.indexOf(currentAct) === -1) {
            // Current activity ended — switch to next active activity or compact
            if (acts.length > 0) {
                var nextAct = acts[0];
                if (nextAct === "pomodoro") root.islandState = root.statePomodoro;
                else if (nextAct === "media") root.islandState = root.stateMedia;
                else if (nextAct === "timer") root.islandState = root.stateTimer;
                else if (nextAct === "stopwatch") root.islandState = root.stateStopwatch;
                else if (nextAct === "recording") root.islandState = root.stateRecording;
                else if (nextAct === "comms") root.islandState = root.stateComms;
            } else {
                root.islandState = root.stateCompact;
            }
        } else if (root.islandState === root.stateCompact && acts.length > 0) {
            // Activity started — display as minimized pill in notch
            var first = acts[0];
            if (first === "pomodoro") root.islandState = root.statePomodoro;
            else if (first === "media") root.islandState = root.stateMedia;
            else if (first === "timer") root.islandState = root.stateTimer;
            else if (first === "stopwatch") root.islandState = root.stateStopwatch;
            else if (first === "recording") root.islandState = root.stateRecording;
            else if (first === "comms") root.islandState = root.stateComms;
        }
    }

    function swapActivities() {
        var acts = root.activeActivities;
        if (acts.length <= 1)
            return;
        var currentActivity = "";
        if (root.islandState === root.statePomodoro)
            currentActivity = "pomodoro";
        else if (root.islandState === root.stateMedia)
            currentActivity = "media";
        else if (root.islandState === root.stateTimer)
            currentActivity = "timer";
        else if (root.islandState === root.stateStopwatch)
            currentActivity = "stopwatch";
        else if (root.islandState === root.stateRecording)
            currentActivity = "recording";
        else if (root.islandState === root.stateComms)
            currentActivity = "comms";

        var currentIndex = acts.indexOf(currentActivity);
        var nextIndex = (currentIndex + 1) % acts.length;
        var nextActivity = acts[nextIndex];

        if (nextActivity === "pomodoro")
            root.islandState = root.statePomodoro;
        else if (nextActivity === "media")
            root.islandState = root.stateMedia;
        else if (nextActivity === "timer")
            root.islandState = root.stateTimer;
        else if (nextActivity === "stopwatch")
            root.islandState = root.stateStopwatch;
        else if (nextActivity === "recording")
            root.islandState = root.stateRecording;
        else if (nextActivity === "comms")
            root.islandState = root.stateComms;
    }

    property bool isLocked: false
    readonly property bool isAnyPopupOpen: (groundControl && (groundControl.show || groundControl.visible)) ||
                                           (airspace && (airspace.show || airspace.visible)) ||
                                           (calendarPopup && (calendarPopup.show || calendarPopup.visible)) ||
                                           (powerMenuPopup && (powerMenuPopup.show || powerMenuPopup.visible)) ||
                                           (wallpaperMenuPopup && (wallpaperMenuPopup.show || wallpaperMenuPopup.visible)) ||
                                           (screenshotMenuPopup && (screenshotMenuPopup.show || screenshotMenuPopup.visible)) ||
                                           (audioPopup && (audioPopup.show || audioPopup.visible)) ||
                                           (wifiMenuPopup && (wifiMenuPopup.show || wifiMenuPopup.visible)) ||
                                           (bluetoothMenuPopup && (bluetoothMenuPopup.show || bluetoothMenuPopup.visible)) ||
                                           (sparklinePopup && (sparklinePopup.show || sparklinePopup.visible)) ||
                                           (powerProfilePopup && (powerProfilePopup.show || powerProfilePopup.visible)) ||
                                           (f1CalendarPopup && (f1CalendarPopup.show || f1CalendarPopup.visible)) ||
                                           (appLauncherPopup && (appLauncherPopup.show || appLauncherPopup.visible)) ||
                                           (clipboardPopup && (clipboardPopup.show || clipboardPopup.visible)) ||
                                           (spotlightPopup && (spotlightPopup.show || spotlightPopup.visible)) ||
                                           (mindPilotPopup && (mindPilotPopup.show || mindPilotPopup.visible)) ||
                                           (cheatsheetPopup && (cheatsheetPopup.show || cheatsheetPopup.visible)) ||
                                           (emailsPopup && (emailsPopup.show || emailsPopup.visible)) ||
                                           (alarmReminderPill && (alarmReminderPill.show || alarmReminderPill.visible))
    readonly property bool isCenterPopupOpen: (groundControl && (groundControl.show || groundControl.visible || groundControl.isClosing)) ||
                                           (airspace && (airspace.show || airspace.visible)) ||
                                           (calendarPopup && (calendarPopup.show || calendarPopup.visible)) ||
                                           (powerMenuPopup && (powerMenuPopup.show || powerMenuPopup.visible || powerMenuPopup.isClosing)) ||
                                           (wallpaperMenuPopup && (wallpaperMenuPopup.show || wallpaperMenuPopup.visible)) ||
                                           (appLauncherPopup && (appLauncherPopup.show || appLauncherPopup.visible || appLauncherPopup.isClosing)) ||
                                           (clipboardPopup && (clipboardPopup.show || clipboardPopup.visible || clipboardPopup.isClosing)) ||
                                           (spotlightPopup && (spotlightPopup.show || spotlightPopup.visible || spotlightPopup.isClosing)) ||
                                           (screenshotMenuPopup && (screenshotMenuPopup.show || screenshotMenuPopup.visible)) ||
                                           (alarmReminderPill && (alarmReminderPill.show || alarmReminderPill.visible || alarmReminderPill.isClosing))

    Timer {
        id: popupHandoffTimer
        interval: 60 // ~4-5 compositor frames on 60-120Hz to guarantee clean framebuffer unmapping
        repeat: false
        property var pendingPopup: null
        onTriggered: {
            if (pendingPopup) {
                if (typeof pendingPopup.hideImmediately !== "undefined") {
                    pendingPopup.hideImmediately = false;
                }
                if (typeof pendingPopup.show !== "undefined") {
                    pendingPopup.show = true;
                } else if (typeof pendingPopup.visible !== "undefined") {
                    pendingPopup.visible = true;
                }
                pendingPopup = null;
            }
        }
    }

    function togglePopup(targetPopup) {
        if (!targetPopup) return;

        var isOpen = (typeof targetPopup.show !== "undefined" && targetPopup.show) ||
                     (typeof targetPopup.visible !== "undefined" && targetPopup.visible);

        if (isOpen) {
            popupHandoffTimer.stop();
            popupHandoffTimer.pendingPopup = null;
            if (typeof targetPopup.show !== "undefined") targetPopup.show = false;
            else if (typeof targetPopup.visible !== "undefined") targetPopup.visible = false;
            if (typeof targetPopup.close === "function") targetPopup.close();
            return;
        }

        // Check if any sibling popup is currently open
        var hadOpenPopup = root.isAnyPopupOpen;

        // Close all other open popups first with immediate hide flags
        root.closeAllPopupsExcept(targetPopup);

        if (hadOpenPopup) {
            // Sibling handoff: give Wayland compositor 60ms to swap clean buffer
            popupHandoffTimer.pendingPopup = targetPopup;
            popupHandoffTimer.restart();
        } else {
            popupHandoffTimer.stop();
            popupHandoffTimer.pendingPopup = null;
            if (typeof targetPopup.show !== "undefined") targetPopup.show = true;
            else if (typeof targetPopup.visible !== "undefined") targetPopup.visible = true;
        }
    }

    function closeAllPopups() {
        closeAllPopupsExcept(null);
    }

    function closeAllPopupsExcept(exceptPopup) {
        popupHandoffTimer.stop();
        popupHandoffTimer.pendingPopup = null;
        var popups = [groundControl, airspace, calendarPopup, powerMenuPopup, wallpaperMenuPopup, screenshotMenuPopup, audioPopup, wifiMenuPopup, bluetoothMenuPopup, sparklinePopup, powerProfilePopup, f1CalendarPopup, emailsPopup, timerPopup, spotlightPopup, mindPilotPopup];
        for (var i = 0; i < popups.length; i++) {
            var p = popups[i];
            if (p && p !== exceptPopup) {
                if (typeof p.hideImmediately !== "undefined") p.hideImmediately = true;
                if (typeof p.show !== "undefined") p.show = false;
                if (typeof p.close === "function") p.close();
                if (typeof p.closeAllSubPopups === "function") p.closeAllSubPopups();
            }
        }
    }

    // Active Window Title State
    property string activeWindowTitle: ""
    property string activeWindowClass: ""

    // State properties
    property string wifiSsid: ""
    property string bluetoothDevice: ""
    property bool redshiftActive: false
    property bool caffeineActive: false
    property bool audiophileActive: false
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
    property bool showEmailPill: true

    Timer {
        id: emailPillTimer
        interval: 10000 // 10 seconds max
        repeat: false
        onTriggered: root.showEmailPill = false
    }

    onHourEmailsCountChanged: {
        if (hourEmailsCount > prevHourEmailsCount) {
            //queueNotification(["notify-send", "-u", "normal", "-i", "mail-unread", "New Mail Received", "You have " + hourEmailsCount + " new mail(s) in the last hour."]);
            root.showEmailPill = true;
            emailPillTimer.restart();
        } else if (hourEmailsCount === 0) {
            root.showEmailPill = false;
            emailPillTimer.stop();
        }
        prevHourEmailsCount = hourEmailsCount;
    }
    
    property var latestEmails: []
    property string emailLastSynced: ""
    property string volumeOut: "0%"
    property bool volumeMuted: false
    property string activeSinkName: "Default Output"
    property string volumeMic: "0%"
    property bool micMuted: false
    property string bluetoothStatus: "off"
    property bool bluetoothPresent: false
    property int diskUsage: 0
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

    property string spotifyStatus: Players.status
    property string spotifyText: Players.text
    property string spotifyTitle: Players.title
    property string spotifyArtist: Players.artist
    property string spotifyArtUrl: Players.artUrl
    property string spotifyPlayerName: Players.playerName
    property string displayPlayerName: Players.has ? Players.playerNameOf(Players.active) : Players.serviceLabel

    property double spotifyPosition: 0.0
    property double spotifyLength: Players.lengthSec
    property string spotifyPositionStr: formatTime(spotifyPosition)
    property string spotifyLengthStr: formatTime(spotifyLength)

    property double _mediaAnchorPos: 0.0
    property double _mediaAnchorTime: 0.0

    function resyncMediaPosition() {
        if (Players.has && Players.active) {
            var p = Players.active.position;
            _mediaAnchorPos = (p >= 0) ? p : 0.0;
            _mediaAnchorTime = Date.now();
            spotifyPosition = _mediaAnchorPos;
            spotifyPositionStr = formatTime(spotifyPosition);
        }
    }

    Connections {
        target: Players
        function onActiveChanged() { root.resyncMediaPosition(); }
    }

    Connections {
        target: Players.has ? Players.active : null
        ignoreUnknownSignals: true
        function onPositionChanged() { root.resyncMediaPosition(); }
        function onPlayingChanged() { root.resyncMediaPosition(); }
        function onPlaybackStateChanged() { root.resyncMediaPosition(); }
    }

    Timer {
        id: mediaPositionTimer
        interval: 100 // 10 updates/sec for buttery-smooth progress tracking
        running: root.spotifyStatus === "playing"
        repeat: true
        onTriggered: {
            if (Players.has && Players.active) {
                var pos = Players.active.position;
                if (Math.abs(pos - root.spotifyPosition) > 1.5) {
                    root._mediaAnchorPos = pos;
                    root._mediaAnchorTime = Date.now();
                }
                var elapsed = (Date.now() - root._mediaAnchorTime) / 1000.0;
                var cur = Math.max(0.0, root._mediaAnchorPos + elapsed);
                if (root.spotifyLength > 0 && cur > root.spotifyLength) {
                    cur = root.spotifyLength;
                }
                root.spotifyPosition = cur;
                root.spotifyPositionStr = root.formatTime(cur);
            }
        }
    }
    property string wifiIcon: "󰤯"
    property string wifiText: "Disconnected"
    property string wifiIp: ""
    property bool wifiEnabled: false
    property bool ethernetConnected: false
    property string networkDown: ""
    property string networkUp: ""

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
        if (!hasBattery) return;
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
        if (!hasBattery) return;
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
    readonly property var _transientStates: [root.stateOsd, root.stateBatteryLow, root.stateCharging, root.stateDnd, root.stateWaterAlert, root.stateStretchAlert, root.stateF1Alert, root.stateCpuAlert, root.stateDragLocalSend, root.stateLocalSendSuccess, root.stateDiskAlert, root.stateComms, root.stateNudge]

    function safeSavePrev() {
        if (_transientStates.indexOf(root.islandState) === -1) {
            root.prevIslandState = root.islandState;
        }
    }

    function playSoundSafely(proc) {
        if (proc && !proc.running) {
            proc.running = true;
        }
    }

    property bool triggerDndPillOnClose: false
    property bool lastDndActive: false
    onDndActiveChanged: {
        if (dndActive !== lastDndActive) {
            if (groundControl && groundControl.visible) {
                root.triggerDndPillOnClose = true;
            } else {
                root.safeSavePrev();
                root.islandState = root.stateDnd;
                dndPillTimer.restart();
            }
        }
        lastDndActive = dndActive;
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

    // Shell Nudge Suite
    property string nudgeTitle: "Action Detected"
    property string nudgeSubtitle: ""
    property string nudgeIcon: "󰐊"
    property string nudgeActionCmd: ""
    property string nudgeActionLabel: "Open"
    property string nudgeAccentColor: "#89B4FA"
    property string nudgeCategory: "NOW NUDGE"
    property real nudgeProgress: 1.0
    property bool nudgePaused: false
    property int nudgeTotalMs: 8000
    property int nudgeElapsedMs: 0

    Timer {
        id: nudgeProgressTimer
        interval: 50
        repeat: true
        running: (root.islandState === root.stateNudge) && !root.nudgePaused
        onTriggered: {
            root.nudgeElapsedMs += 50;
            root.nudgeProgress = Math.max(0.0, 1.0 - (root.nudgeElapsedMs / Math.max(1, root.nudgeTotalMs)));
            if (root.nudgeElapsedMs >= root.nudgeTotalMs) {
                nudgeProgressTimer.stop();
                if (root.islandState === root.stateNudge) {
                    root.islandState = root.prevIslandState;
                }
            }
        }
    }

    function triggerNudgeAlert(title, subtitle, icon, actionCmd, actionLabel, accentColor, timeoutMs, category) {
        root.nudgeTitle = title || "Action Detected";
        root.nudgeSubtitle = subtitle || "";
        root.nudgeIcon = icon || "󰐊";
        root.nudgeActionCmd = actionCmd || "";
        root.nudgeActionLabel = actionLabel || "Open";
        root.nudgeAccentColor = accentColor || "#89B4FA";
        root.nudgeCategory = category || "NOW NUDGE";
        root.safeSavePrev();
        root.islandState = root.stateNudge;
        root.nudgeTotalMs = timeoutMs || 8000;
        root.nudgeElapsedMs = 0;
        root.nudgeProgress = 1.0;
        root.nudgePaused = false;
        nudgeProgressTimer.restart();
    }

    function pauseNudgeTimer() {
        root.nudgePaused = true;
    }

    function resumeNudgeTimer() {
        root.nudgePaused = false;
    }

    function dismissNudgeAlert() {
        nudgeProgressTimer.stop();
        if (root.islandState === root.stateNudge) {
            root.islandState = root.prevIslandState;
        }
    }

    function executeNudgeAction() {
        var cmd = root.nudgeActionCmd;
        dismissNudgeAlert();
        if (cmd) {
            pNudgeExec.command = ["sh", "-c", cmd];
            pNudgeExec.running = true;
        }
    }

    Process {
        id: pNudgeExec
        command: []
    }

    // Health & Activity Rings Suite
    property bool healthRemindersActive: true
    property int waterInterval: 2700000 // 45 minutes
    property int stretchInterval: 3000000 // 50 minutes

    property int healthWaterToday: 0
    property int healthWaterGoal: 2500
    property real healthWaterPct: healthWaterGoal > 0 ? Math.min(2.0, healthWaterToday / healthWaterGoal) : 0.0

    property int healthStretchToday: 0
    property int healthStretchGoal: 10
    property real healthStretchPct: healthStretchGoal > 0 ? Math.min(2.0, healthStretchToday / healthStretchGoal) : 0.0

    property real healthOverallPct: (healthWaterPct + healthStretchPct) / 2.0
    property int healthStreak: 0
    property var healthHistory: []

    // Health Monitoring Suite disabled (safe no-op stubs to prevent breakage)
    function refreshHealthData() {}
    function logWater(ml) {}
    function logStretch(cnt) {}
    function resetWaterTimer() {}
    function snoozeWaterTimer() {}
    function resetStretchTimer() {}
    function snoozeStretchTimer() {}

    // =========================================================================
    // 🍅 POMODORO DEEP-WORK ENGINE
    // =========================================================================
    property bool pomodoroActive: false
    property bool pomodoroRunning: false
    property int pomodoroSeconds: 1500
    property int pomodoroTotalSeconds: 1500
    property string pomodoroMode: "focus" // "focus" | "short_break" | "long_break"
    property int pomodoroSession: 1
    property int pomodoroTotalCompleted: 0
    readonly property real pomodoroProgress: pomodoroTotalSeconds > 0 ? ((pomodoroTotalSeconds - pomodoroSeconds) / pomodoroTotalSeconds) : 0.0
    readonly property string pomodoroTimeStr: {
        var m = Math.floor(root.pomodoroSeconds / 60);
        var s = root.pomodoroSeconds % 60;
        return (m < 10 ? "0" + m : m) + ":" + (s < 10 ? "0" + s : s);
    }
    readonly property string pomodoroTitle: {
        if (root.pomodoroMode === "focus") return "Focus Session #" + root.pomodoroSession;
        if (root.pomodoroMode === "short_break") return "Short Break";
        if (root.pomodoroMode === "long_break") return "Long Rest";
        return "Pomodoro";
    }

    function startPomodoro(mode) {
        if (mode) root.pomodoroMode = mode;
        if (root.pomodoroSeconds <= 0) {
            if (root.pomodoroMode === "focus") {
                root.pomodoroTotalSeconds = 1500;
                root.pomodoroSeconds = 1500;
            } else if (root.pomodoroMode === "short_break") {
                root.pomodoroTotalSeconds = 300;
                root.pomodoroSeconds = 300;
            } else if (root.pomodoroMode === "long_break") {
                root.pomodoroTotalSeconds = 900;
                root.pomodoroSeconds = 900;
            }
        }
        root.pomodoroActive = true;
        root.pomodoroRunning = true;
    }

    function pausePomodoro() {
        root.pomodoroRunning = false;
    }

    function togglePomodoro() {
        if (!root.pomodoroActive) {
            startPomodoro();
        } else {
            root.pomodoroRunning = !root.pomodoroRunning;
        }
    }

    function resetPomodoro() {
        root.pomodoroRunning = false;
        if (root.pomodoroMode === "focus") {
            root.pomodoroTotalSeconds = 1500;
            root.pomodoroSeconds = 1500;
        } else if (root.pomodoroMode === "short_break") {
            root.pomodoroTotalSeconds = 300;
            root.pomodoroSeconds = 300;
        } else if (root.pomodoroMode === "long_break") {
            root.pomodoroTotalSeconds = 900;
            root.pomodoroSeconds = 900;
        }
    }

    function exitPomodoro() {
        root.pomodoroActive = false;
        root.pomodoroRunning = false;
        resetPomodoro();
        if (root.islandState === root.statePomodoro) {
            root.islandState = root.stateCompact;
        }
    }

    function skipPomodoro() {
        root.pomodoroRunning = false;
        if (root.pomodoroMode === "focus") {
            root.pomodoroTotalCompleted++;
            if (root.pomodoroSession >= 4) {
                root.pomodoroSession = 1;
                root.pomodoroMode = "long_break";
                root.pomodoroTotalSeconds = 900;
                root.pomodoroSeconds = 900;
            } else {
                root.pomodoroSession++;
                root.pomodoroMode = "short_break";
                root.pomodoroTotalSeconds = 300;
                root.pomodoroSeconds = 300;
            }
        } else {
            root.pomodoroMode = "focus";
            root.pomodoroTotalSeconds = 1500;
            root.pomodoroSeconds = 1500;
        }
    }

    Timer {
        id: pomodoroTimer
        interval: 1000
        running: root.pomodoroRunning
        repeat: true
        onTriggered: {
            if (root.pomodoroSeconds > 1) {
                root.pomodoroSeconds--;
            } else {
                root.pomodoroSeconds = 0;
                root.playSoundSafely(pPlaySound);
                root.skipPomodoro();
            }
        }
    }

    // =========================================================================
    // 📋 TODOIST & LOCAL TASKS & ALARMS ENGINE
    // =========================================================================
    property var tasksList: []
    property var alarmsList: []
    property string tasksSource: "todoist"
    property bool tasksLoading: false

    Process {
        id: pGetTasks
        command: ["python3", (Quickshell.env("HOME") || "/home/krishna") + "/dotfiles/scripts/tasks_manager.py", "--get"]
        stdout: SplitParser {
            onRead: data => {
                try {
                    var parsed = JSON.parse(data);
                    if (parsed.tasks && Array.isArray(parsed.tasks)) root.tasksList = parsed.tasks;
                    if (parsed.source) root.tasksSource = parsed.source;
                } catch(e) {}
                root.tasksLoading = false;
            }
        }
    }

    Process {
        id: pCheckDue
        command: ["python3", (Quickshell.env("HOME") || "/home/krishna") + "/dotfiles/scripts/tasks_manager.py", "--check-due"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var parsed = JSON.parse(text.trim());
                    if (parsed.alarms && Array.isArray(parsed.alarms)) root.alarmsList = parsed.alarms;
                    if (parsed.alerts && Array.isArray(parsed.alerts) && parsed.alerts.length > 0) {
                        for (var i = 0; i < parsed.alerts.length; i++) {
                            alarmReminderPill.triggerAlert(parsed.alerts[i]);
                        }
                    }
                } catch(e) {}
            }
        }
    }

    Process {
        id: pActionTasks
        stdout: SplitParser {
            onRead: data => {
                try {
                    var parsed = JSON.parse(data);
                    if (parsed.tasks && Array.isArray(parsed.tasks)) root.tasksList = parsed.tasks;
                    if (parsed.alarms && Array.isArray(parsed.alarms)) root.alarmsList = parsed.alarms;
                    if (parsed.source) root.tasksSource = parsed.source;
                } catch(e) {}
                root.tasksLoading = false;
            }
        }
    }

    function refreshTasks() {
        root.tasksLoading = true;
        if (!pGetTasks.running) pGetTasks.running = true;
        if (!pCheckDue.running) pCheckDue.running = true;
    }

    function addTask(content) {
        if (!content || content.trim() === "") return;
        root.tasksLoading = true;
        pActionTasks.command = ["python3", (Quickshell.env("HOME") || "/home/krishna") + "/dotfiles/scripts/tasks_manager.py", "--add", content.trim()];
        if (pActionTasks.running) pActionTasks.running = false;
        pActionTasks.running = true;
    }

    function toggleTask(taskId) {
        root.tasksLoading = true;
        pActionTasks.command = ["python3", (Quickshell.env("HOME") || "/home/krishna") + "/dotfiles/scripts/tasks_manager.py", "--toggle", taskId.toString()];
        if (pActionTasks.running) pActionTasks.running = false;
        pActionTasks.running = true;
    }

    function deleteTask(taskId) {
        root.tasksLoading = true;
        pActionTasks.command = ["python3", (Quickshell.env("HOME") || "/home/krishna") + "/dotfiles/scripts/tasks_manager.py", "--delete", taskId.toString()];
        if (pActionTasks.running) pActionTasks.running = false;
        pActionTasks.running = true;
    }

    function snoozeAlert(alertId, minutes) {
        pActionTasks.command = ["python3", (Quickshell.env("HOME") || "/home/krishna") + "/dotfiles/scripts/tasks_manager.py", "--snooze", alertId.toString(), (minutes || 10).toString()];
        if (pActionTasks.running) pActionTasks.running = false;
        pActionTasks.running = true;
    }

    function dismissAlert(alertId) {
        pActionTasks.command = ["python3", (Quickshell.env("HOME") || "/home/krishna") + "/dotfiles/scripts/tasks_manager.py", "--dismiss", alertId.toString()];
        if (pActionTasks.running) pActionTasks.running = false;
        pActionTasks.running = true;
    }

    function addAlarm(timeStr, label) {
        pActionTasks.command = ["python3", (Quickshell.env("HOME") || "/home/krishna") + "/dotfiles/scripts/tasks_manager.py", "--add-alarm", timeStr, label || "Alarm"];
        if (pActionTasks.running) pActionTasks.running = false;
        pActionTasks.running = true;
    }

    function toggleAlarm(alarmId) {
        pActionTasks.command = ["python3", (Quickshell.env("HOME") || "/home/krishna") + "/dotfiles/scripts/tasks_manager.py", "--toggle-alarm", alarmId.toString()];
        if (pActionTasks.running) pActionTasks.running = false;
        pActionTasks.running = true;
    }

    function deleteAlarm(alarmId) {
        pActionTasks.command = ["python3", (Quickshell.env("HOME") || "/home/krishna") + "/dotfiles/scripts/tasks_manager.py", "--delete-alarm", alarmId.toString()];
        if (pActionTasks.running) pActionTasks.running = false;
        pActionTasks.running = true;
    }

    Timer {
        id: tasksPollTimer
        interval: 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refreshTasks()
    }

    Timer {
        id: duePollTimer
        interval: 15000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!pCheckDue.running && !root.isLocked) {
                pCheckDue.running = true;
            }
        }
    }

    // =========================================================================
    // 📝 SCRATCHPAD & CLIPBOARD HELPER
    // =========================================================================
    property string scratchpadText: ""

    Process {
        id: pGetScratchpad
        command: ["python3", (Quickshell.env("HOME") || "/home/krishna") + "/dotfiles/scripts/scratchpad_manager.py", "--get"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                root.scratchpadText = text;
            }
        }
    }

    Process {
        id: pSetScratchpad
    }

    // Debounce timer: waits 1.5s after last keystroke before actually writing to disk
    property string _pendingScratchText: ""
    Timer {
        id: scratchSaveDebounce
        interval: 1500
        repeat: false
        onTriggered: {
            if (pSetScratchpad.running) pSetScratchpad.running = false;
            // Base64 encode the utf-8 text safely so no newlines, quotes, or markdown syntax are mangled
            var b64 = Qt.btoa(unescape(encodeURIComponent(root._pendingScratchText)));
            pSetScratchpad.command = [
                "python3",
                (Quickshell.env("HOME") || "/home/krishna") + "/dotfiles/scripts/scratchpad_manager.py",
                "--set-b64",
                b64
            ];
            pSetScratchpad.running = true;
        }
    }

    function loadScratchpad() {
        if (!pGetScratchpad.running) pGetScratchpad.running = true;
    }

    function saveScratchpad(text) {
        root.scratchpadText = text;
        root._pendingScratchText = text;
        scratchSaveDebounce.restart();   // debounce: resets the 1.5s window on every keystroke
    }

    Process {
        id: pWlCopy
    }

    function copyToClipboard(text) {
        if (!text) return;
        pWlCopy.command = ["wl-copy", text];
        if (pWlCopy.running) pWlCopy.running = false;
        pWlCopy.running = true;
    }


    Timer {
        id: waterReminderTimer
        running: false
    }

    Timer {
        id: stretchReminderTimer
        running: false
    }

    Timer {
        id: waterAlertTimer
        running: false
    }

    Timer {
        id: stretchAlertTimer
        running: false
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
        command: ["/home/krishna/dotfiles/scripts/set_volume.sh", "toggle"]
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
    Process {
        id: pSetSink
        property int sinkId: -1
        command: ["wpctl", "set-default", sinkId.toString()]
        onRunningChanged: {
            if (!running) {
                pListSinks.running = true;
                pVolumeOut.running = true;
                pVolumeMic.running = true;
            }
        }
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

    QtObject {
        id: pSpotPrev
        property bool running: false
        onRunningChanged: {
            if (running) {
                if (Players.has && Players.active.canGoPrevious)
                    Players.active.previous();
                running = false;
            }
        }
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
        command: ["paplay", "/usr/share/sounds/freedesktop/stereo/message.oga"]
    }
    Process {
        id: pPlayTimerSound
        command: ["paplay", "/usr/share/sounds/freedesktop/stereo/complete.oga"]
    }
    Process {
        id: pPlayPowerPlug
        command: ["paplay", "/usr/share/sounds/ocean/stereo/power-plug.oga"]
    }
    Process {
        id: pPlayPowerUnplug
        command: ["paplay", "/usr/share/sounds/ocean/stereo/power-unplug.oga"]
    }

    Process {
        id: pBrightSet
        command: [] // command is always set dynamically before running
    }

    QtObject {
        id: pSpotPlay
        property bool running: false
        onRunningChanged: {
            if (running) {
                if (Players.has && Players.active.canTogglePlaying)
                    Players.active.togglePlaying();
                running = false;
            }
        }
    }
    QtObject {
        id: pSpotNext
        property bool running: false
        onRunningChanged: {
            if (running) {
                if (Players.has && Players.active.canGoNext)
                    Players.active.next();
                running = false;
            }
        }
    }

    Process {
        id: pLockScreen
        command: [root.scriptsDir + "/screenlock.sh"]
    }

    Process {
        id: pScreenshotSel
        command: [root.scriptsDir + "/screenshot.sh", "--sel"]
    }
    Process {
        id: pScreenshotNow
        command: [root.scriptsDir + "/screenshot.sh", "--now"]
    }
    Process {
        id: pOcrShot
        command: [root.scriptsDir + "/screenshot.sh", "--ocr"]
    }
    Process {
        id: pColorPicker
        command: ["hyprpicker", "-a"]
    }
    Process {
        id: pRecordSel
        command: [root.scriptsDir + "/screenshot.sh", "--record-sel"]
    }
    Process {
        id: pRecordFull
        command: [root.scriptsDir + "/screenshot.sh", "--record"]
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
                        root.diskAlertDev = parts.length >= 4 ? parts[3] : "";
                        root.diskAlertType = parts.length >= 5 ? parts[4] : "usb";
                        root.safeSavePrev();
                        root.islandState = root.stateDiskAlert;
                        diskAlertTimer.restart();
                        playSoundSafely(pPlaySound);
                    }
                } catch(e) {}
            }
        }
    }

    Process {
        id: pOmniNudge
        command: ["python3", root.scriptsDir + "/omni_nudge.py"]
        running: true
        stdout: SplitParser {
            onRead: function(data) {
                try {
                    var line = data.trim();
                    if (!line) return;
                    var d = JSON.parse(line);
                    root.triggerNudgeAlert(d.title, d.subtitle, d.icon, d.action_cmd, d.action_label, d.color, d.timeout_ms);
                } catch(e) {}
            }
        }
    }

    // 📋 Persistent Clipboard History Watcher
    Process {
        id: pClipboardWatcher
        command: ["python3", root.scriptsDir + "/clipboard_manager.py", "--ensure-daemon"]
        running: true
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

    Process {
        id: pMountAndOpen
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
                        if (alarmReminderPill) {
                            alarmReminderPill.triggerAlert({
                                id: "f1_" + Date.now(),
                                type: "f1",
                                title: "Formula 1",
                                subtitle: root.f1AlertName + " in " + root.f1AlertMins + "m (" + root.f1AlertTime + ")",
                                icon: "󰿠",
                                timeout_ms: 15000
                            });
                        } else {
                            root.safeSavePrev();
                            root.islandState = root.stateF1Alert;
                            f1AlertTimer.restart();
                            queueNotification(["notify-send", "-u", "normal", "-i", "f1", "F1 Session Starting", root.f1AlertName + " starts in " + root.f1AlertMins + "m (at " + root.f1AlertTime + ")"]);
                        }
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
        command: ["bash", "-c", "while true; do mic=$(pactl list source-outputs | grep 'application.name' | grep -vi 'cava' 2>/dev/null); cam=$(fuser /dev/video* 2>/dev/null); echo \"$mic|$cam\"; sleep 2; done"]
        stdout: SplitParser {
            onRead: data => {
                var line = data.trim();
                if (line === "") return;
                var parts = line.split('|');
                if (parts.length >= 2) {
                    var micPart = parts[0] ? parts[0].trim() : "";
                    var camPart = parts[1] ? parts[1].trim() : "";
                    root.isMicActive = (micPart.length > 0);
                    root.isCamActive = (camPart.length > 0);
                }
            }
        }
    }

    // Unified Status and Telemetry Daemon
    Process {
        id: pStats
        running: true
        command: ["bash", Quickshell.shellDir + "/scripts/quickshell_stats.sh"]
        stdout: SplitParser {
            onRead: data => {
                var d = data.trim();
                if (d === "")
                    return;
                try {
                    var stats = JSON.parse(d);

                    // Assign battery properties
                    root.hasBattery = stats.has_battery;
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

                    // Assign bluetooth
                    root.bluetoothPresent = stats.bluetooth_present;
                    if (root.bluetoothStatus !== stats.bluetooth_status) root.bluetoothStatus = stats.bluetooth_status;
                    if (root.bluetoothDevice !== stats.bluetooth_device) root.bluetoothDevice = stats.bluetooth_device;

                    // Assign ethernet
                    root.ethernetConnected = stats.ethernet_connected;

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
                    root.audiophileActive = stats.audiophile_active;

                    // Assign power profile
                    root.powerProfile = stats.power_profile;

                    // Assign emails if present
                    if (stats.emails) {
                        root.todayEmailsCount = stats.emails.today_count;
                        root.hourEmailsCount = stats.emails.hour_count || 0;
                        root.latestEmails = stats.emails.latest ? [].concat(stats.emails.latest) : [];
                        root.emailLastSynced = stats.emails.last_sync || "";
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
        command: ["/home/krishna/dotfiles/scripts/get_volume.sh"]
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


    Process {
        id: pVolumeSubscriber
        running: true
        command: ["pactl", "subscribe"]
        stdout: SplitParser {
            onRead: data => {
                if (data.includes("sink") || data.includes("source")) {
                    pVolumeOut.running = true;
                    pVolumeMic.running = true;
                }
            }
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

    function toggleCaffeine() {
        pCaffeineToggle.running = false;
        pCaffeineToggle.running = true;
    }

    Process {
        id: pAudiophileToggle
        command: ["/home/krishna/dotfiles/scripts/audiophile_toggle.sh", "off"]
        onExited: {
            pTriggerStatsUpdate.running = false;
            pTriggerStatsUpdate.running = true;
        }
    }

    function toggleAudiophile() {
        pAudiophileToggle.command = ["/home/krishna/dotfiles/scripts/audiophile_toggle.sh", root.audiophileActive ? "off" : "on"];
        pAudiophileToggle.running = true;
    }

    // Keybindings menu launcher
    Process {
        id: pKeybindings
        command: ["python3", root.scriptsDir + "/keybindings.py"]
    }



    function seekTrack(seconds) {
        if (Players.has) {
            Players.active.position = seconds;
            root.spotifyPosition = seconds;
            root.spotifyPositionStr = root.formatTime(seconds);
        }
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
        id: weatherPollTimer
        interval: 600000
        running: true
        repeat: true
        onTriggered: pWeather.running = true
    }

    property bool isWindowFullscreen: false

    // Live Hyprland active window tracking
    Process {
        id: pActiveWinSock
        command: ["sh", "-c",
            "socat - UNIX-CONNECT:/tmp/hypr/${HYPRLAND_INSTANCE_SIGNATURE}/.socket2.sock 2>/dev/null"]
        running: true
        stdout: SplitParser {
            onRead: function(data) {
                var parts = data.trim().split(">>");
                var ev = parts[0];
                if (ev === "fullscreen") {
                    root.isWindowFullscreen = (parts.length > 1 && parts[1] === "1");
                }
                if (ev === "activewindow" || ev === "activewindowv2" || ev === "closewindow" || ev === "openwindow" || ev === "windowtitle" || ev === "fullscreen") {
                    root.runProcessSafely(pGetActiveWin);
                }
            }
        }
        onExited: winSockRestartTimer.restart()
    }
    Timer {
        id: winSockRestartTimer
        interval: 1000
        repeat: false
        onTriggered: { pActiveWinSock.running = true; pGetActiveWin.running = true; }
    }
    Process {
        id: pGetActiveWin
        command: ["hyprctl", "activewindow", "-j"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var obj = JSON.parse(text.trim());
                    if (obj && obj.title && obj.mapped) {
                        root.activeWindowTitle = obj.title;
                        root.activeWindowClass = obj.class ? obj.class : "";
                        root.isWindowFullscreen = obj.fullscreen ? true : false;
                    } else {
                        root.activeWindowTitle = "";
                        root.activeWindowClass = "";
                        root.isWindowFullscreen = false;
                    }
                } catch(e) {
                    root.activeWindowTitle = "";
                    root.activeWindowClass = "";
                    root.isWindowFullscreen = false;
                }
            }
        }
    }

    PanelWindow {
        id: barWindow
        anchors.top: true
        anchors.left: true
        anchors.right: true
        // Fixed height: never resize the Wayland surface (eliminates compositor jitter).
        // The notch springs inside this fixed viewport; extra space is transparent.
        implicitWidth: Screen.width
        implicitHeight: Math.round(76 * scaleFactor)
        color: "transparent"

        WlrLayershell.namespace: "quickshell_bar"
        WlrLayershell.exclusiveZone: Math.round(36 * scaleFactor)

        mask: Region {
            Region { item: leftCapsule }
            Region { item: windowTitleCapsule.visible ? windowTitleCapsule : null }
            Region { item: notchRect.visible ? notchRect : null }
            Region { item: bubbleRow.visible ? bubbleRow : null }
            Region { item: rightCapsule }
        }

        // RAM Optimization: No full-screen wallpaper texture buffer on the bar
        readonly property Item wallpaperBackdrop: null

        LeftCapsule {
            id: leftCapsule
            root: root
        }

        // Active Window Title Pill (Positioned beside the left capsule to the right)
        Rectangle {
            id: windowTitleCapsule
            color: "transparent"
            z: 1
            anchors.left: leftCapsule.right
            anchors.leftMargin: Math.round(8 * scaleFactor)
            anchors.top: parent.top
            anchors.topMargin: root.topHuggingStyle ? 0 : Math.round(6 * scaleFactor)
            height: root.topHuggingStyle ? Math.round(36 * scaleFactor) : Math.round(34 * scaleFactor)
            radius: root.topHuggingStyle ? 2 : Math.round(4 * scaleFactor)

            // Dynamic width calculation with max cap of 220px so it truncates long titles cleanly
            readonly property real maxAvailableW: Math.min(Math.round(220 * scaleFactor), Math.max(0, notchRect.x - (leftCapsule.x + leftCapsule.width + Math.round(20 * scaleFactor))))
            width: Math.min(titleRow.implicitWidth + Math.round(20 * scaleFactor), maxAvailableW)
            clip: true

            visible: opacity > 0.001
            opacity: (root.activeWindowTitle !== "" && width > Math.round(50 * scaleFactor)) ? 1.0 : 0.0

            Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
            Behavior on width { NumberAnimation { duration: 240; easing.type: Easing.OutBack; easing.overshoot: 1.12 } }

            SurfaceCard {
                anchors.fill: parent
                useShader: false
                cornerRadius: root.topHuggingStyle ? 2 : Math.round(4 * scaleFactor)
                zRadius: root.topHuggingStyle ? 2 : Math.round(4 * scaleFactor)
                contentPadding: 0
                clip: true
                RowLayout {
                    id: titleRow
                    anchors.fill: parent
                    anchors.leftMargin: Math.round(10 * scaleFactor)
                    anchors.rightMargin: Math.round(10 * scaleFactor)
                    spacing: Math.round(6 * scaleFactor)

                    Text {
                        text: "󰅍"
                        color: root.colAccentSecondary
                        font { family: root.iconFontFamily; pixelSize: Math.round(11 * fontScale) }
                        Layout.alignment: Qt.AlignVCenter
                    }

                    Text {
                        text: root.activeWindowTitle
                        color: root.colFg
                        font {
                            family: root.monoFontFamily
                            pixelSize: Math.round(10 * fontScale)
                            weight: Font.Medium
                        }
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                    }
                }

            // Floating tooltip showing full un-truncated title & class
            QSTooltip {
                show: titleMouse.containsMouse && root.activeWindowTitle !== ""
                placement: "below"
                text: root.activeWindowTitle
                subtitle: root.activeWindowClass
                fontScale: root.fontScale
                fontFamily: root.fontFamily
            }

            MouseArea {
                id: titleMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: qsIpc.toggleOverview()
            }
        }
    }

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
                        pLocalSend.command = [root.scriptsDir + "/kdeconnect_share.sh", "--files"].concat(paths);
                        pLocalSend.running = true;

                        root.islandState = root.stateLocalSendSuccess;
                        localSendTimer.restart();
                    } else {
                        root.islandState = root.prevIslandState;
                    }
                } else if (drop.hasText) {
                    drop.accept(Qt.CopyAction);
                    pLocalSend.command = [root.scriptsDir + "/kdeconnect_share.sh", "--text", drop.text];
                    pLocalSend.running = true;
                    
                    root.islandState = root.stateLocalSendSuccess;
                    localSendTimer.restart();
                } else {
                    root.islandState = root.prevIslandState;
                }
            }
        }

        Process {
            id: pMindSpaceDrop
            command: []
        }

        CenterNotch {
            id: notchRect
            root: root
        }

        Row {
            id: bubbleRow

            visible: opacity > 0
            opacity: (root.islandState === 1 || root.islandState === 4 || root.islandState === 5 || root.islandState === 6 || root.islandState === root.stateComms || root.islandState === root.statePomodoro) && !root.isCenterPopupOpen ? 1.0 : 0.0
            Behavior on opacity {
                NumberAnimation {
                    duration: root.batteryMode ? 80 : 120
                    easing.type: Easing.OutQuad
                }
            }

            // Fixed vertical center matching notchRect vertical center (20px when bar height is 40px)
            anchors.verticalCenter: parent.top
            anchors.verticalCenterOffset: root.topHuggingStyle ? Math.round(16 * scaleFactor) : Math.round(20 * scaleFactor)
            y: 0  // suppressed; verticalCenter handles vertical placement
            x: Math.round(notchRect.x + notchRect.width + 8 * scaleFactor)
            spacing: Math.round(6 * scaleFactor)

            Repeater {
                model: root.activeActivities
                delegate: Item {
                    id: bubble
                    property string act: modelData
                    property bool isCurrent: (act === "media" && root.islandState === 1) || (act === "timer" && root.islandState === 4) || (act === "stopwatch" && root.islandState === 5) || (act === "recording" && root.islandState === 6) || (act === "comms" && root.islandState === root.stateComms) || (act === "pomodoro" && root.islandState === root.statePomodoro)

                    opacity: isCurrent ? 0.0 : 1.0
                    scale: isCurrent ? 0.0 : (bubbleMouse.containsPress ? 0.92 : (bubbleMouse.containsMouse ? 1.04 : 1.0))
                    width: isCurrent ? 0 : Math.round(32 * scaleFactor)
                    visible: opacity > 0

                    height: Math.round(32 * scaleFactor)

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 220
                            easing.type: Easing.OutCubic
                        }
                    }
                    Behavior on scale {
                        NumberAnimation {
                            duration: 240
                            easing.type: Easing.OutBack
                            easing.overshoot: 1.15
                        }
                    }
                    Behavior on width {
                        NumberAnimation {
                            duration: 240
                            easing.type: Easing.OutBack
                            easing.overshoot: 1.10
                        }
                    }

                    // Option B / Teenage Engineering Tactile Channel Switch Key
                    Rectangle {
                        id: bubbleTile
                        anchors.fill: parent
                        radius: 4
                        color: bubbleMouse.containsPress ? Qt.rgba(1, 1, 1, 0.16) : (bubbleMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(0.047, 0.051, 0.063, 0.94))
                        border.color: bubbleMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.25) : Qt.rgba(1, 1, 1, 0.10)
                        border.width: 1
                        clip: true

                        Behavior on color { ColorAnimation { duration: 80 } }
                        Behavior on border.color { ColorAnimation { duration: 80 } }

                        // Teenage Engineering amber status LED indicator for active timer
                        Rectangle {
                            visible: bubble.act === "timer" && (root.timerRunning || root.timerSeconds > 0)
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.margins: 4
                            width: 4
                            height: 4
                            radius: 1
                            color: root.timerRunning ? root.colWarn : Qt.rgba(1, 0.69, 0, 0.4)
                            Behavior on color { ColorAnimation { duration: 80 } }
                        }

                        // Recording live indicator dot (blinking red square)
                        Rectangle {
                            visible: bubble.act === "recording"
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.margins: 4
                            width: 5
                            height: 5
                            radius: 1
                            color: root.colCrit
                            SequentialAnimation on opacity {
                                loops: Animation.Infinite
                                running: bubble.act === "recording"
                                NumberAnimation { from: 1.0; to: 0.2; duration: 500 }
                                NumberAnimation { from: 0.2; to: 1.0; duration: 500 }
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: act === "media" ? "󰝚" : (act === "timer" ? "󰔛" : (act === "stopwatch" ? "󱎫" : (act === "pomodoro" ? "🍅" : (act === "recording" ? "󰑊" : "󰍬"))))
                            color: act === "media" && root.spotifyStatus === "playing" ? root.colSpotify : (act === "recording" ? root.colCrit : (act === "timer" && root.timerRunning ? root.colWarn : (act === "stopwatch" && root.stopwatchRunning ? root.colWarn : (act === "pomodoro" ? "#EF4444" : (act === "comms" ? "#FF2D55" : root.colFg)))))
                            font.family: root.nerdFontFamily || root.iconFontFamily
                            font.pixelSize: Math.round(13 * fontScale)
                        }

                        MouseArea {
                            id: bubbleMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (act === "media")
                                    root.islandState = root.stateMedia;
                                else if (act === "timer")
                                    root.islandState = root.stateTimer;
                                else if (act === "stopwatch")
                                    root.islandState = root.stateStopwatch;
                                else if (act === "recording")
                                    root.islandState = root.stateRecording;
                                else if (act === "comms")
                                    root.islandState = root.stateComms;
                                else if (act === "pomodoro")
                                    root.islandState = root.statePomodoro;
                            }
                        }
                    }
                }
            }
        }

        RightCapsule {
            id: rightCapsule
            root: root
        }
}
        // ── Privacy dots now live inside trayPillBg ──────────────────────────




    Timer {
        id: notifCloseTimer
        interval: root.notifDismissDelay
        repeat: false
        onTriggered: {
            root.dismissFrontNotification();
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
        function onLock() {
            root.isLocked = true;
            root.closeAllPopupsExcept(null);
        }
        function onUnlock() {
            root.isLocked = false;
        }
        function toggleScreenshotMenu() {
            if (groundControl && groundControl.show) {
                groundControl.show = false;
                groundControl.closeAllSubPopups();
            }
            screenshotMenuPopup.show = !screenshotMenuPopup.show;
        }
        function openScreenshotSelector() {
            root.closeAllPopupsExcept(null);
            screenSelector.open("sel");
        }
        function openScreenshotEdit() {
            root.closeAllPopupsExcept(null);
            screenSelector.open("edit");
        }
        function openScreenshotOcr() {
            root.closeAllPopupsExcept(null);
            screenSelector.open("ocr");
        }
        function openScreenshotRecord() {
            root.closeAllPopupsExcept(null);
            screenSelector.open("record");
        }
        function dismissAlarmPill() {
            alarmReminderPill.dismissPill();
        }
        function showNudge(dataJson: string) {
            try {
                var d = JSON.parse(dataJson);
                root.triggerNudgeAlert(d.title, d.subtitle, d.icon, d.action_cmd, d.action_label, d.color, d.timeout_ms, d.category);
            } catch (e) {
                root.triggerNudgeAlert("Action Detected", dataJson, "󰐊", "", "OK", "#89B4FA", 8000, "NOW NUDGE");
            }
        }
        function dismissNudge() {
            root.dismissNudgeAlert();
        }
        function reactGrokbot(animName: string) {
            CharacterBus.react(animName);
        }
        function petGrokbot() {
            CharacterBus.pet();
        }
        function setMinimoBotMode(mode: string) {
            root.setMinimoBotMode(mode);
        }
        function toggleMinimoBotMode() {
            root.setMinimoBotMode(root.minimoBotMode === "light" ? "dark" : "light");
        }
        function testAlarmPill() {
            alarmReminderPill.triggerAlert({
                id: "test_task",
                type: "task",
                task_id: "test_1",
                title: "Forward Flight BEMT Graphs",
                subtitle: "Due in 5 mins • Todoist (P4)",
                is_warning: true,
                priority: 4
            });
        }
        function testAlarmRinging() {
            alarmReminderPill.triggerAlert({
                id: "test_alarm",
                type: "alarm",
                title: "Morning Flight Briefing",
                subtitle: "Alarm Ringing",
                is_warning: false,
                is_alarm: true,
                priority: 4
            });
        }
        function testWaterAlert() {
            alarmReminderPill.triggerAlert({
                id: "test_water",
                type: "water",
                title: "Drink Water",
                subtitle: (root.healthWaterToday || 0) + " / " + (root.healthWaterGoal || 2500) + " ml",
                icon: "󰖞",
                timeout_ms: 25000
            });
        }
        function testStretchAlert() {
            alarmReminderPill.triggerAlert({
                id: "test_stretch",
                type: "stretch",
                title: "Stretch Break",
                subtitle: "Time to stand up and stretch!",
                icon: "󰚥",
                timeout_ms: 25000
            });
        }
        function testStartPomodoro() {
            root.startPomodoro();
        }
        function testStartTimer() {
            root.timerTotal = 300;
            root.timerSeconds = 300;
            root.timerText = "05:00";
            root.timerRunning = true;
        }
        function testStopAllActivities() {
            root.exitPomodoro();
            root.timerRunning = false;
            root.timerSeconds = 0;
            root.stopwatchRunning = false;
            root.stopwatchSeconds = 0;
            root.isRecording = false;
            root.islandState = root.stateCompact;
        }
        function testExpandState(stateName) {
            if (stateName === "pomodoro") root.islandState = root.statePomodoro;
            else if (stateName === "timer") root.islandState = root.stateTimer;
            else if (stateName === "stopwatch") root.islandState = root.stateStopwatch;
            else if (stateName === "media") root.islandState = root.stateMedia;
            else if (stateName === "recording") root.islandState = root.stateRecording;
            else if (stateName === "compact") root.islandState = root.stateCompact;
        }
        function testToggleMaximized() {
            if (notchRect) notchRect.isMaximized = !notchRect.isMaximized;
        }
        function toggleAirspace() {
            // Airspace removed - no-op
        }
        function toggleOverview() { }
        function toggleAudiophilePlayer() {
            if (audiophilePlayer) {
                audiophilePlayer.visible = !audiophilePlayer.visible;
                if (audiophilePlayer.visible && audiophileMiniPlayer) {
                    audiophileMiniPlayer.visible = false;
                }
            }
        }
        function toggleAudiophileMiniPlayer() {
            if (audiophileMiniPlayer) {
                audiophileMiniPlayer.visible = !audiophileMiniPlayer.visible;
                if (audiophileMiniPlayer.visible && audiophilePlayer) {
                    audiophilePlayer.visible = false;
                }
            }
        }
        function triggerF1Alert() {
            root.f1AlertName = "Austrian GP: First Free Practice";
            root.f1AlertMins = "15";
            root.f1AlertTime = "17:00";
            if (alarmReminderPill) {
                alarmReminderPill.triggerAlert({
                    id: "f1_" + Date.now(),
                    type: "f1",
                    title: "Formula 1",
                    subtitle: root.f1AlertName + " in 15m (17:00)",
                    icon: "󰿠",
                    timeout_ms: 15000
                });
            } else {
                root.safeSavePrev();
                root.islandState = root.stateF1Alert;
                f1AlertTimer.restart();
                queueNotification(["notify-send", "-u", "normal", "-i", "f1", "F1 Session Starting", root.f1AlertName + " starts in 15m (at " + root.f1AlertTime + ")"]);
            }
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
            root.diskAlertDev = "/dev/sdb1";
            root.diskAlertType = "usb";
            root.safeSavePrev();
            root.islandState = root.stateDiskAlert;
            diskAlertTimer.restart();
            queueNotification(["notify-send", "-u", "normal", "-i", "drive-removable-media", "USB Connected", root.diskAlertTitle + " (" + root.diskAlertSubtitle + ")"]);
            playSoundSafely(pPlaySound);
        }

        function triggerPhoneAlert() {
            root.diskAlertTitle = "OnePlus 13R";
            root.diskAlertSubtitle = "Connected (KDE Connect)";
            root.diskAlertMounted = true;
            root.diskAlertDev = "";
            root.diskAlertType = "phone";
            root.safeSavePrev();
            root.islandState = root.stateDiskAlert;
            diskAlertTimer.restart();
            queueNotification(["notify-send", "-u", "normal", "-i", "phone", "Mobile Connected", root.diskAlertTitle + " (" + root.diskAlertSubtitle + ")"]);
            playSoundSafely(pPlaySound);
        }

        function triggerWaterAlert() {}
        function triggerStretchAlert() {}
        function startPomodoro() { root.startPomodoro(); }
        function pausePomodoro() { root.pausePomodoro(); }
        function togglePomodoro() { root.togglePomodoro(); }
        function resetPomodoro() { root.resetPomodoro(); }
        function skipPomodoro() { root.skipPomodoro(); }
        function exitPomodoro() { root.exitPomodoro(); }
        function stopPomodoro() { root.exitPomodoro(); }
        function refreshTasks() { root.refreshTasks(); }
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
        function dismissNotification() {
            if (root.currentNotifId !== null) {
                root.dismissNotificationSafely(root.currentNotifId);
                root.notifCloseTimer.stop();
            } else {
                root.dismissFrontNotification();
                root.notifCloseTimer.stop();
            }
        }
        function toggleAppLauncher() {
            root.togglePopup(appLauncherPopup);
        }
        function toggleSpotlight() {
            root.togglePopup(spotlightPopup);
        }
        function toggleMindPilot() {
            root.togglePopup(mindPilotPopup);
        }
        function queryMindPilot(q: string) {
            if (!mindPilotPopup.show) root.togglePopup(mindPilotPopup);
            mindPilotPopup.runAgentQuery(q);
        }
        function toggleThinkingAccordion() {
            mindPilotPopup.isThinkingExpandedManual = !mindPilotPopup.isThinkingExpandedManual;
        }
        function toggleCheatsheet() {
            root.togglePopup(cheatsheetPopup);
        }
        function togglePowerMenu() {
            root.togglePopup(powerMenuPopup);
        }
        function toggleClipboard() {
            root.togglePopup(clipboardPopup);
        }
        function toggleThemeSwitcher() {
            root.togglePopup(wallpaperMenuPopup);
        }
        function toggleThemeMode() {
            root.toggleThemeMode();
        }
        function toggleWifiMenu() {
            root.togglePopup(wifiMenuPopup);
        }
        function toggleBluetoothMenu() {
            root.togglePopup(bluetoothMenuPopup);
        }
        function toggleTimer() {
            if (root.timerRunning) {
                root.timerRunning = false;
            } else if (root.timerSeconds > 0) {
                root.timerRunning = true;
            } else {
                root.timerSeconds = root.timerTotal;
                root.timerText = root.formatTime(root.timerTotal);
                root.timerRunning = true;
            }
            root.islandState = root.stateTimer;
        }
        function toggleStopwatch() {
            root.stopwatchRunning = !root.stopwatchRunning;
            root.islandState = root.stateStopwatch;
        }
        function toggleSettings() {
            if (settingsWindow) {
                settingsWindow.visible = !settingsWindow.visible;
            }
        }
        function toggleGroundControl() { toggleSettings(); }
        function toggleControlCenter() { toggleSettings(); }
        function toggleF1CalendarPopup() {
            root.togglePopup(f1CalendarPopup);
        }
        function toggleEmailsPopup() {
            root.togglePopup(emailsPopup);
        }
        function toggleMediaPopup() {
            toggleAudiophilePlayer();
        }
        function toggleAudioPopup() {
            root.togglePopup(audioPopup);
        }
        function toggleSparklinePopup() {
            root.togglePopup(sparklinePopup);
        }
        function togglePowerProfilePopup() {}
        function toggleCalendarPopup() {
            root.togglePopup(calendarPopup);
        }
        function toggleHudNotifications() {
            console.log("[Quickshell] IPC toggleHudNotifications called! terminalHud=" + terminalHud);
            if (terminalHud) {
                terminalHud.toggleNotificationDeck();
            }
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
            if (!notif) return;
            var nId = notif.id;
            root.registerNotifObj(notif);

            console.log("onNotification received: summary=" + (notif.summary ? notif.summary : "") + ", dndActive=" + root.dndActive);
            var appName = notif.appName ? notif.appName : "System";
            var appIcon = notif.appIcon ? notif.appIcon : "";

            var actList = [];
            try {
                if (notif.actions) {
                    for (var a = 0; a < notif.actions.length; a++) {
                        actList.push({
                            identifier: notif.actions[a].identifier,
                            text: notif.actions[a].text
                        });
                    }
                }
            } catch(e) {}

            var notifItem = {
                id: nId,
                notifId: nId,
                summary: notif.summary ? notif.summary : "",
                body: notif.body ? notif.body : "",
                appName: appName,
                appIcon: appIcon,
                hasActions: actList.length > 0,
                actions: actList
            };

            // Listen for notification closed signal to safely clean up pointer references
            try {
                if (notif.closed && typeof notif.closed.connect === "function") {
                    notif.closed.connect(function() {
                        root.removeNotificationById(nId);
                        root.removeNotificationFromList(nId);
                    });
                }
            } catch(e) {}

            // Always add to persistent Ground Control list (even if DnD is active)
            root.addNotificationToList(notifItem);

            if (!root.dndActive) {
                var newQueue = root.activeNotifQueue.slice();
                var groupFound = false;
                
                for (var i = 0; i < newQueue.length; i++) {
                    if (newQueue[i].appName === appName) {
                        var groupNotifs = newQueue[i].notifications.slice();
                        var dupIndex = -1;
                        for (var k = 0; k < groupNotifs.length; k++) {
                            if (groupNotifs[k].id === nId) {
                                dupIndex = k;
                                break;
                            }
                        }
                        if (dupIndex !== -1) {
                            groupNotifs[dupIndex] = notifItem;
                        } else {
                            groupNotifs.push(notifItem);
                        }
                        newQueue[i] = {
                            appName: appName,
                            appIcon: appIcon,
                            notifications: groupNotifs
                        };
                        groupFound = true;
                        break;
                    }
                }
                
                if (!groupFound) {
                    newQueue.push({
                        appName: appName,
                        appIcon: appIcon,
                        notifications: [notifItem]
                    });
                }
                
                root.activeNotifQueue = newQueue;
                root.notificationReceived();
                playSoundSafely(pPlaySound);

                // Always restart dismiss timer on newly arrived notification
                notifCloseTimer.interval = root.notifDismissDelay;
                notifCloseTimer.restart();
            }
        }
    }

    TimerPopup {
        id: timerPopup
        shellRoot: root
        groundControlWindow: null
    }

    CalendarPopup {
        id: calendarPopup
        shellRoot: root
    }

    AppLauncherPopup {
        id: appLauncherPopup
        shellRoot: root
    }

    ClipboardPopup {
        id: clipboardPopup
        shellRoot: root
    }

    SpotlightPopup {
        id: spotlightPopup
        shellRoot: root
    }

    MindPilotPopup {
        id: mindPilotPopup
        shellRoot: root
    }

    MinimoBlob {
        id: minimoBlob
        shellRoot: root
        mindPilot: mindPilotPopup
    }

    CheatsheetPopup {
        id: cheatsheetPopup
        shellRoot: root
    }

    F1CalendarPopup {
        id: f1CalendarPopup
        shellRoot: root
        groundControlWindow: null
    }

    EmailsPopup {
        id: emailsPopup
        shellRoot: root
        groundControlWindow: null
    }

    PowerMenu {
        id: powerMenuPopup
        shellRoot: root
    }

    AlarmReminderPill {
        id: alarmReminderPill
        shellRoot: root
    }

    AudioPopup {
        id: audioPopup
        shellRoot: root
    }

    BluetoothMenu {
        id: bluetoothMenuPopup
        shellRoot: root
    }

    ScreenshotMenu {
        id: screenshotMenuPopup
        shellRoot: root
    }

    ScreenSelector {
        id: screenSelector
        shellRoot: root
    }

    NotificationPopup {
        id: notifPopup
        shellRoot: root
    }

    SettingsWindow {
        id: settingsWindow
        shellRoot: root
    }

    AudiophilePlayer {
        id: audiophilePlayer
        shellRoot: root
    }

    AudiophileMiniPlayer {
        id: audiophileMiniPlayer
        shellRoot: root
    }

    TerminalHudWallpaper {
        id: terminalHud
        shellRoot: root
    }

    Component.onDestruction: {
        isDestroying = true;
        pStats.running = false;
    }
}