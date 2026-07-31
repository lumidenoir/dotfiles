import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io

PanelWindow {
    id: groundControl

    property bool show: false
    property var shellRoot: null
    readonly property real scaleFactor: shellRoot ? shellRoot.scaleFactor : 1.0
    property real notchLayoutWidth: 120
    property real animHeight: animRect.height
    property real animWidth: animRect.width
    property bool hideImmediately: false
    readonly property real targetWidth: Math.min(680 * scaleFactor, groundControl.width > 100 ? groundControl.width - 40 : 640)

    // Expose btnTimer so timerPopup can anchor to it
    property alias btnTimer: btnTimer
    property alias cardF1: cardF1
    property alias cardEmails: cardEmails
    property int cachedHeight: Math.round(380 * scaleFactor)

    WlrLayershell.keyboardFocus: show ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    WlrLayershell.namespace: "quickshell"

    ListModel {
        id: audioSinksModel
    }

    Process {
        id: pListSinks
        command: [shellRoot ? (shellRoot.scriptsDir + "/list_sinks.sh") : "list_sinks.sh"]
        stdout: SplitParser {
            onRead: data => {
                audioSinksModel.clear();
                var lines = data.trim().split("\n");
                for (var i = 0; i < lines.length; i++) {
                    var parts = lines[i].split("|");
                    if (parts.length >= 3) {
                        audioSinksModel.append({
                            "sinkId": parseInt(parts[0]),
                            "isActive": parts[1] === "true",
                            "name": parts[2]
                        });
                    }
                }
            }
        }
    }

    Process {
        id: pSetSink
        property int sinkId: -1
        command: ["wpctl", "set-default", sinkId.toString()]
        onRunningChanged: {
            if (!running) {
                pListSinks.running = true;
                if (shellRoot) {
                    shellRoot.pVolumeOut.running = true;
                    shellRoot.pVolumeMic.running = true;
                }
            }
        }
    }

    Timer {
        id: sinksRefreshTimer
        interval: 3000
        repeat: true
        running: typeof slidersCard !== "undefined" && slidersCard && slidersCard.airPlayOpen && groundControl.show
        onTriggered: pListSinks.running = true
    }

    Connections {
        target: typeof slidersCard !== "undefined" ? slidersCard : null
        ignoreUnknownSignals: true
        function onAirPlayOpenChanged() {
            if (slidersCard && slidersCard.airPlayOpen) {
                pListSinks.running = true;
            }
        }
    }

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    exclusionMode: ExclusionMode.Ignore
    visible: show || (isClosing && !hideImmediately)
    color: "transparent"

    property bool isClosing: false
    property real savedCloseTarget: 120
    // Temporarily suppresses the Behavior on width/height so animRect can snap to
    // the circle size (36px) before the spring expands it — avoids the "pop from
    // pill width" artifact on open.
    property bool suppressOpenAnimation: false

    function closeAllSubPopups() {
        if (shellRoot) {
            if (shellRoot.timerPopup)
                shellRoot.timerPopup.show = false;
            if (shellRoot.f1CalendarPopup)
                shellRoot.f1CalendarPopup.show = false;
            if (shellRoot.emailsPopup)
                shellRoot.emailsPopup.show = false;
        }
    }

    onShowChanged: {
        if (show) {
            isClosing = false;
            hideImmediately = false;
            // Snap to circle first so the spring always expands from 36px
            suppressOpenAnimation = true;
            snapResetTimer.start();
            savedCloseTarget = Qt.binding(function () {
                return shellRoot ? shellRoot.closedNotchWidth : 120;
            });
            focusTimerCc.start();
            if (shellRoot)
                shellRoot.pListSinks.running = true;
        } else {
            savedCloseTarget = shellRoot ? shellRoot.closedNotchWidth : 120;
            isClosing = !hideImmediately;
            closeAllSubPopups();
        }
    }

    // One-shot: releases suppressOpenAnimation after ~2 frames so Behavior kicks in
    // Reduced from 120ms → 32ms to minimize the snap artifact before the spring expands
    Timer {
        id: snapResetTimer
        interval: 32
        repeat: false
        onTriggered: groundControl.suppressOpenAnimation = false
    }

    Timer {
        id: focusTimerCc
        interval: 50
        onTriggered: groundControlContent.forceActiveFocus()
    }

    Item {
        id: groundControlContent
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: {
            groundControl.show = false;
            closeAllSubPopups();
        }

        MouseArea {
            anchors.fill: parent
            enabled: groundControl.show
            onClicked: {
                groundControl.show = false;
                groundControl.closeAllSubPopups();
            }
        }

        Rectangle {
            id: animRect
            anchors.top: parent.top
            anchors.topMargin: 4 * groundControl.scaleFactor
            anchors.horizontalCenter: parent.horizontalCenter

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
            }

            width: groundControl.suppressOpenAnimation ? 36 * groundControl.scaleFactor : groundControl.show ? groundControl.targetWidth : (groundControl.isClosing ? 36 * groundControl.scaleFactor : groundControl.savedCloseTarget)

            function checkCloseFinished() {
                if (!groundControl.show && groundControl.isClosing) {
                    var sf = groundControl.scaleFactor;
                    var targetWidth = 36 * sf;
                    var targetHeight = 36 * sf;
                    if (Math.abs(width - targetWidth) < 1.0 && Math.abs(height - targetHeight) < 1.0) {
                        groundControl.isClosing = false;
                    }
                }
            }

            onWidthChanged: checkCloseFinished()

            height: groundControl.suppressOpenAnimation ? 36 * groundControl.scaleFactor : groundControl.show ? (mainLayout.implicitHeight > 100 ? (mainLayout.implicitHeight + 28) : groundControl.cachedHeight) : (groundControl.isClosing ? 36 * groundControl.scaleFactor : 40 * groundControl.scaleFactor)

            onHeightChanged: checkCloseFinished()

            color: Qt.rgba(0.02, 0.02, 0.02, 1.0)

            radius: groundControl.suppressOpenAnimation ? 18 * groundControl.scaleFactor : groundControl.show ? 24 * groundControl.scaleFactor : (groundControl.isClosing ? 18 * groundControl.scaleFactor : 20 * groundControl.scaleFactor)
            border.color: Qt.rgba(1, 1, 1, 0.08)
            border.width: 1

            // Top-highlight shimmer — 1px bright streak at the very top of the pill,
            // identical to the notch and tray pill. Fades in/out with the panel.
            Rectangle {
                id: gcTopHighlight
                anchors {
                    top:         parent.top
                    topMargin:   1
                    left:        parent.left
                    leftMargin:  Math.round(animRect.radius * 0.6)
                    right:       parent.right
                    rightMargin: Math.round(animRect.radius * 0.6)
                }
                height: 1
                radius: 1
                color:  Qt.rgba(1, 1, 1, 0.10)
                opacity: groundControl.show ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutQuad } }
            }

            Behavior on width {
                enabled: !groundControl.suppressOpenAnimation && (groundControl.show || groundControl.isClosing) && (shellRoot ? !shellRoot.batteryMode : true)
                SpringAnimation {
                    spring: 4.8
                    damping: 0.8
                    mass: 0.6
                }
            }
            Behavior on height {
                enabled: !groundControl.suppressOpenAnimation && (groundControl.show || groundControl.isClosing) && (shellRoot ? !shellRoot.batteryMode : true)
                SpringAnimation {
                    spring: 4.8
                    damping: 0.8
                    mass: 0.6
                }
            }
            Behavior on radius {
                enabled: !groundControl.suppressOpenAnimation && (groundControl.show || groundControl.isClosing) && (shellRoot ? !shellRoot.batteryMode : true)
                SpringAnimation {
                    spring: 4.8
                    damping: 0.8
                    mass: 0.6
                }
            }



            Item {
                anchors.fill: parent
                anchors.margins: 14
                clip: true

                opacity: groundControl.show ? 1.0 : 0.0
                Behavior on opacity {
                    SequentialAnimation {
                        PauseAnimation {
                            duration: shellRoot && shellRoot.batteryMode ? 0 : groundControl.show ? 120 : 0
                        }
                        NumberAnimation {
                            duration: shellRoot && shellRoot.batteryMode ? 0 : groundControl.show ? 300 : 80
                            easing.type: groundControl.show ? Easing.OutQuad : Easing.InQuad
                        }
                    }
                }

                scale: groundControl.show ? 1.0 : 0.9
                Behavior on scale {
                    enabled: shellRoot ? !shellRoot.batteryMode : true
                    SpringAnimation {
                        spring: 3.0
                        damping: 0.8
                        mass: 0.8
                    }
                }

                ColumnLayout {
                    id: mainLayout
                    onImplicitHeightChanged: {
                        if (implicitHeight > 100) {
                            groundControl.cachedHeight = implicitHeight + 28;
                        }
                    }
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    spacing: 8

                    RowLayout {
                        spacing: 8
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignTop

                        // ================= COLUMN 1 (LEFT) =================
                        ColumnLayout {
                            Layout.alignment: Qt.AlignTop
                            Layout.fillWidth: true
                            Layout.preferredWidth: 280
                            spacing: 8

                            // 1. Clock, Weather, Stats & Battery Display
                            CCCard {
                                shellRoot: groundControl.shellRoot
                                groundControlShow: groundControl.show
                                cardDelay: 0
                                Layout.preferredHeight: 120
                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    spacing: 8

                                    RowLayout {
                                        Layout.fillWidth: true
                                        ColumnLayout {
                                            spacing: 2
                                            RowLayout {
                                                spacing: 8
                                                Text {
                                                    id: clockText
                                                    color: shellRoot ? shellRoot.colFg : "#ffffff"
                                                    font.family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                                                    font.pixelSize: 22
                                                    font.bold: true
                                                    text: Qt.formatDateTime(new Date(), "HH:mm")
                                                    Timer {
                                                        interval: groundControl.show ? 1000 : 60000
                                                        running: true
                                                        repeat: true
                                                        onTriggered: clockText.text = Qt.formatDateTime(new Date(), "HH:mm")
                                                    }
                                                }
                                                Text {
                                                    text: shellRoot ? shellRoot.weatherText : ""
                                                    color: shellRoot ? shellRoot.colFg : "#ffffff"
                                                    font.family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                                                    font.pixelSize: 14
                                                    Layout.alignment: Qt.AlignBottom
                                                    Layout.bottomMargin: 3
                                                    visible: shellRoot && shellRoot.weatherText !== ""
                                                }
                                            }
                                            Text {
                                                color: shellRoot ? shellRoot.colMuted : "#888888"
                                                font.family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                                                font.pixelSize: 11
                                                text: Qt.formatDateTime(new Date(), "dddd, MMMM d")
                                            }
                                        }

                                        Item {
                                            Layout.fillWidth: true
                                        }

                                        // Battery Display
                                        Rectangle {
                                            property int cap: shellRoot ? parseInt(shellRoot.batteryCap) : 0
                                            property bool isCrit: shellRoot ? (cap <= 15 && !shellRoot.batteryCharging) : false
                                            property bool isWarn: shellRoot ? (cap <= 30 && cap > 15 && !shellRoot.batteryCharging) : false

                                            Layout.preferredHeight: 44
                                            Layout.minimumWidth: 100
                                            Layout.preferredWidth: Math.max(100, batteryCol.implicitWidth + 24)
                                            Layout.alignment: Qt.AlignRight
                                            radius: 12
                                            color: Qt.rgba(1, 1, 1, 0.08)
                                            border.color: Qt.rgba(1, 1, 1, 0.1)
                                            border.width: 1

                                            ColumnLayout {
                                                id: batteryCol
                                                anchors.centerIn: parent
                                                spacing: 2

                                                RowLayout {
                                                    spacing: 6
                                                    Layout.alignment: Qt.AlignHCenter
                                                    Text {
                                                        text: {
                                                            if (!shellRoot)
                                                                return "";
                                                            let cap = parseInt(shellRoot.batteryCap);
                                                            if (shellRoot.batteryCharging)
                                                                return "";
                                                            if (cap > 80)
                                                                return "";
                                                            if (cap > 60)
                                                                return "";
                                                            if (cap > 40)
                                                                return "";
                                                            if (cap > 20)
                                                                return "";
                                                            return "";
                                                        }
                                                        color: {
                                                            if (!shellRoot)
                                                                return "#ffffff";
                                                            let cap = parseInt(shellRoot.batteryCap);
                                                            let isCrit = cap <= 15 && !shellRoot.batteryCharging;
                                                            let isWarn = cap <= 30 && cap > 15 && !shellRoot.batteryCharging;
                                                            return isCrit ? shellRoot.colCrit : (isWarn ? "#FFA500" : (shellRoot.batteryCharging ? "#76B900" : shellRoot.colFg));
                                                        }
                                                        font.family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                                                        font.pixelSize: 13
                                                    }
                                                    Text {
                                                        text: shellRoot ? shellRoot.batteryCap + "%" : ""
                                                        color: shellRoot ? shellRoot.colFg : "#ffffff"
                                                        font.family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                                                        font.pixelSize: shellRoot ? Math.round(11 * shellRoot.scaleFactor) : 11
                                                        font.bold: true
                                                    }
                                                }
                                                Text {
                                                    text: {
                                                        if (!shellRoot) return "";
                                                        if (shellRoot.batteryTimeStr !== "") return shellRoot.batteryTimeStr;
                                                        return shellRoot.batteryCharging ? "charging" : "—";
                                                    }
                                                    color: shellRoot ? Qt.rgba(shellRoot.colFg.r, shellRoot.colFg.g, shellRoot.colFg.b, 0.65) : Qt.rgba(1, 1, 1, 0.65)
                                                    font.family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                                                    font.pixelSize: 10
                                                    Layout.alignment: Qt.AlignHCenter
                                                }
                                            }
                                        }
                                    }

                                    // Divider
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 1
                                        color: Qt.rgba(1, 1, 1, 0.08)
                                    }

                                    // Stats Row (Updates, Temp, Power)
                                    RowLayout {
                                        Layout.fillWidth: true
                                        Layout.alignment: Qt.AlignHCenter
                                        spacing: 16

                                        Text {
                                            text: "󰏗  " + (shellRoot ? shellRoot.updates : 0)
                                            color: shellRoot ? (parseInt(shellRoot.updates) > 0 ? shellRoot.colAccent : shellRoot.colMuted) : "#888888"
                                            font {
                                                family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                                                pixelSize: 11
                                                bold: true
                                            }
                                        }
                                        Text {
                                            text: "󰔏  " + (shellRoot ? shellRoot.temperature : 0) + "°C"
                                            color: shellRoot ? (parseInt(shellRoot.temperature) >= 80 ? shellRoot.colCrit : shellRoot.colMuted) : "#888888"
                                            font {
                                                family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                                                pixelSize: 11
                                                bold: true
                                            }
                                        }
                                        Text {
                                            text: "󱐋  " + (shellRoot ? shellRoot.powerDraw : 0) + "W"
                                            color: shellRoot ? shellRoot.colMuted : "#888888"
                                            font {
                                                family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                                                pixelSize: 11
                                                bold: true
                                            }
                                        }
                                    }
                                }
                            }

                            // 2. System Sliders Card (Vertical side-by-side)
                            CCCard {
                                id: slidersCard
                                property bool airPlayOpen: false
                                shellRoot: groundControl.shellRoot
                                groundControlShow: groundControl.show
                                cardDelay: 40
                                Layout.preferredHeight: 183

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    spacing: 12
                                    visible: !slidersCard.airPlayOpen
                                    opacity: visible ? 1.0 : 0.0
                                    Behavior on opacity { NumberAnimation { duration: 150 } }

                                    ModernVerticalSlider {
                                        shellRoot: groundControl.shellRoot
                                        customAccent: shellRoot ? shellRoot.colAccent : "#007AFF"
                                        isMuted: shellRoot ? shellRoot.volumeMuted : false
                                        showAirPlayButton: true
                                        onAirPlayClicked: {
                                            slidersCard.airPlayOpen = true;
                                        }
                                        iconText: {
                                            if (!shellRoot || shellRoot.volumeMuted)
                                                return "󰖁";
                                            let vol = parseInt(shellRoot.volumeOut);
                                            if (vol === 0)
                                                return "󰕿";
                                            if (vol < 30)
                                                return "󰕿";
                                            if (vol < 70)
                                                return "󰖀";
                                            return "󰕾";
                                        }
                                        labelText: "Volume"
                                        value: shellRoot ? (parseInt(shellRoot.volumeOut) / 100.0) : 0
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        onMoved: {
                                            if (shellRoot) {
                                                shellRoot.volumeOut = Math.round(value * 100) + "%";
                                                volDebounce.volValue = value;
                                                volDebounce.restart();
                                            }
                                        }
                                        onIconClicked: {
                                            if (shellRoot)
                                                shellRoot.pVolMute.running = true;
                                        }
                                        Timer {
                                            id: volDebounce
                                            property real volValue: 0
                                            interval: 80
                                            onTriggered: {
                                                if (shellRoot) {
                                                    shellRoot.pVolSet.command = ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", volValue.toFixed(2)];
                                                    shellRoot.pVolSet.running = true;
                                                }
                                            }
                                        }
                                    }

                                    ModernVerticalSlider {
                                        shellRoot: groundControl.shellRoot
                                        customAccent: shellRoot ? shellRoot.colAccentSecondary : "#FF9500"
                                        isMuted: shellRoot ? shellRoot.micMuted : false
                                        iconText: shellRoot && shellRoot.micMuted ? "󰍭" : "󰍬"
                                        labelText: "Mic"
                                        value: shellRoot ? (parseInt(shellRoot.volumeMic) / 100.0) : 0
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        onMoved: {
                                            if (shellRoot) {
                                                shellRoot.volumeMic = Math.round(value * 100) + "%";
                                                micDebounce.micValue = value;
                                                micDebounce.restart();
                                            }
                                        }
                                        onIconClicked: {
                                            if (shellRoot)
                                                shellRoot.pMicMute.running = true;
                                        }
                                        Timer {
                                            id: micDebounce
                                            property real micValue: 0
                                            interval: 80
                                            onTriggered: {
                                                if (shellRoot) {
                                                    shellRoot.pVolSetMic.command = ["wpctl", "set-volume", "@DEFAULT_AUDIO_SOURCE@", micValue.toFixed(2)];
                                                    shellRoot.pVolSetMic.running = true;
                                                }
                                            }
                                        }
                                    }

                                    ModernVerticalSlider {
                                        shellRoot: groundControl.shellRoot
                                        customAccent: shellRoot ? shellRoot.colAccent : "#FFCC00"
                                        iconText: "󰃠"
                                        labelText: "Brightness"
                                        value: shellRoot ? (parseInt(shellRoot.brightnessLevel) / 100.0) : 0
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        onMoved: {
                                            if (shellRoot) {
                                                shellRoot.brightnessLevel = Math.round(value * 100) + "%";
                                                shellRoot.pBrightSet.command = ["brightnessctl", "s", Math.round(value * 100) + "%"];
                                                shellRoot.pBrightSet.running = true;
                                            }
                                        }
                                    }
                                }

                                // AirPlay Switcher Layout
                                ColumnLayout {
                                    id: airPlayLayout
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    spacing: 8
                                    visible: slidersCard.airPlayOpen
                                    opacity: visible ? 1.0 : 0.0
                                    Behavior on opacity { NumberAnimation { duration: 150 } }

                                    // Header Row
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 8

                                        Item {
                                            width: 24
                                            height: 24
                                            
                                            Rectangle {
                                                anchors.fill: parent
                                                radius: 12
                                                color: backMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : "transparent"
                                                Behavior on color { ColorAnimation { duration: 150 } }
                                            }

                                            Text {
                                                anchors.centerIn: parent
                                                text: "" // Back Arrow Icon
                                                color: groundControl.shellRoot ? groundControl.shellRoot.colFg : "#ffffff"
                                                font {
                                                    family: groundControl.shellRoot ? groundControl.shellRoot.iconFontFamily : "sans-serif"
                                                    pixelSize: 11
                                                }
                                            }

                                            MouseArea {
                                                id: backMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                onClicked: slidersCard.airPlayOpen = false
                                            }
                                        }

                                        Text {
                                            text: "Audio Output Devices"
                                            color: groundControl.shellRoot ? groundControl.shellRoot.colFg : "#ffffff"
                                            font {
                                                family: groundControl.shellRoot ? groundControl.shellRoot.fontFamily : "sans-serif"
                                                pixelSize: 11
                                                bold: true
                                            }
                                            Layout.fillWidth: true
                                        }
                                    }

                                    // Audio Outputs List
                                    ScrollView {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        clip: true
                                        ScrollBar.vertical.policy: ScrollBar.AsNeeded

                                        ColumnLayout {
                                            width: parent.width
                                            spacing: 4

                                            Repeater {
                                                model: audioSinksModel
                                                delegate: Rectangle {
                                                    Layout.fillWidth: true
                                                    Layout.preferredHeight: 30
                                                    radius: 8
                                                    color: model.isActive ? Qt.rgba(0.0, 0.478, 1.0, 0.2) : (rowMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent")
                                                    border.color: model.isActive ? "#007AFF" : "transparent"
                                                    border.width: 1

                                                    RowLayout {
                                                        anchors.fill: parent
                                                        anchors.leftMargin: 8
                                                        anchors.rightMargin: 8
                                                        spacing: 8

                                                        Text {
                                                             text: {
                                                                 var name = model.name.toLowerCase();
                                                                 if (name.indexOf("headphone") !== -1 || name.indexOf("headset") !== -1)
                                                                     return "󰋋";
                                                                 if (name.indexOf("speaker") !== -1)
                                                                     return "󰓃";
                                                                 return "󰕾";
                                                             }
                                                            color: model.isActive ? "#007AFF" : (groundControl.shellRoot ? groundControl.shellRoot.colFg : "#ffffff")
                                                            font {
                                                                family: groundControl.shellRoot ? groundControl.shellRoot.iconFontFamily : "sans-serif"
                                                                pixelSize: 12
                                                            }
                                                        }

                                                        Text {
                                                            text: model.name
                                                            color: groundControl.shellRoot ? groundControl.shellRoot.colFg : "#ffffff"
                                                            font {
                                                                family: groundControl.shellRoot ? groundControl.shellRoot.fontFamily : "sans-serif"
                                                                pixelSize: 10
                                                                bold: model.isActive
                                                            }
                                                            Layout.fillWidth: true
                                                            elide: Text.ElideRight
                                                        }

                                                        Text {
                                                            text: "󰄬"
                                                            color: "#76B900" // Success checkmark color
                                                            font {
                                                                family: groundControl.shellRoot ? groundControl.shellRoot.iconFontFamily : "sans-serif"
                                                                pixelSize: 11
                                                            }
                                                            visible: model.isActive
                                                        }
                                                    }

                                                    MouseArea {
                                                        id: rowMouse
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        onClicked: {
                                                            pSetSink.sinkId = model.sinkId;
                                                            pSetSink.running = true;
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // 3. Connectivity Card (Wi-Fi & Bluetooth)
                            CCCard {
                                shellRoot: groundControl.shellRoot
                                groundControlShow: groundControl.show
                                cardDelay: 80
                                Layout.preferredHeight: 64

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    spacing: 8

                                    ModernSplitButton {
                                        Layout.fillWidth: true
                                        title: shellRoot && shellRoot.wifiEnabled && shellRoot.wifiSsid !== "" ? shellRoot.wifiSsid : "Wi-Fi"
                                        text: {
                                            if (!shellRoot)
                                                return "Off";
                                            if (shellRoot.wifiEnabled && shellRoot.wifiSsid !== "" && shellRoot.wifiIp !== "") {
                                                return shellRoot.wifiText + " (" + shellRoot.wifiIp + ")";
                                            }
                                            return shellRoot.wifiText;
                                        }
                                        iconText: shellRoot ? shellRoot.wifiIcon : "󰤮"
                                        isActive: shellRoot && shellRoot.wifiEnabled && shellRoot.wifiText !== "Disconnected"
                                        accent: "#007AFF"
                                        onMainClicked: {
                                            if (shellRoot) {
                                                shellRoot.wifiMenuPopup.show = true;
                                                groundControl.hideImmediately = true;
                                                groundControl.show = false;
                                            }
                                        }
                                        onRightIconClicked: {
                                            if (shellRoot) {
                                                shellRoot.wifiMenuPopup.show = true;
                                                groundControl.hideImmediately = true;
                                                groundControl.show = false;
                                            }
                                        }
                                        onIconClicked: {
                                            if (shellRoot) {
                                                if (shellRoot.wifiEnabled) {
                                                    shellRoot.wifiText = "Disconnected";
                                                    shellRoot.wifiIcon = "󰤮";
                                                    shellRoot.wifiEnabled = false;
                                                } else {
                                                    shellRoot.wifiText = "Connecting...";
                                                    shellRoot.wifiIcon = "󰤨";
                                                    shellRoot.wifiEnabled = true;
                                                }
                                                shellRoot.pWifiToggle.running = true;
                                            }
                                        }
                                    }

                                    ModernSplitButton {
                                        Layout.fillWidth: true
                                        title: shellRoot && shellRoot.bluetoothDevice !== "" ? shellRoot.bluetoothDevice : "Bluetooth"
                                        text: shellRoot && shellRoot.bluetoothStatus === "on" ? "On" : "Off"
                                        iconText: shellRoot && shellRoot.bluetoothStatus === "on" ? "󰂯" : "󰂲"
                                        isActive: shellRoot && shellRoot.bluetoothStatus === "on"
                                        accent: "#007AFF"
                                        onMainClicked: {
                                            if (shellRoot) {
                                                shellRoot.bluetoothMenuPopup.show = true;
                                                groundControl.hideImmediately = true;
                                                groundControl.show = false;
                                            }
                                        }
                                        onRightIconClicked: {
                                            if (shellRoot) {
                                                shellRoot.bluetoothMenuPopup.show = true;
                                                groundControl.hideImmediately = true;
                                                groundControl.show = false;
                                            }
                                        }
                                        onIconClicked: {
                                            if (shellRoot) {
                                                shellRoot.bluetoothStatus = (shellRoot.bluetoothStatus === "on") ? "off" : "on";
                                                shellRoot.pBtToggle.running = true;
                                            }
                                        }
                                    }
                                }
                            }

                            CCCard {
                                id: cardF1
                                shellRoot: groundControl.shellRoot
                                groundControlShow: groundControl.show
                                cardDelay: 120
                                Layout.preferredHeight: 150
                                clip: true

                                border.color: shellRoot && shellRoot.islandState === shellRoot.stateF1Alert ? "#E10600" : Qt.rgba(1, 1, 1, 0.08)
                                border.width: shellRoot && shellRoot.islandState === shellRoot.stateF1Alert ? 1.5 : 1

                                // ── Live countdown state ──────────────────────────────────────
                                property string countdownText: "—"
                                property bool   isLive:   false
                                property bool   isUrgent: false
                                property bool   hasEvent: shellRoot && shellRoot.f1NextEventIso !== ""

                                function computeCountdown() {
                                    if (!shellRoot || shellRoot.f1NextEventIso === "") {
                                        countdownText = "—"; isLive = false; isUrgent = false; return;
                                    }
                                    var target   = new Date(shellRoot.f1NextEventIso);
                                    var now      = new Date();
                                    var diff     = target - now; // ms
                                    if (diff <= 0) {
                                        if (Math.abs(diff) < 7200000) {
                                            countdownText = "LIVE"; isLive = true; isUrgent = false;
                                        } else {
                                            countdownText = "Ended"; isLive = false; isUrgent = false;
                                        }
                                        return;
                                    }
                                    isLive = false;
                                    var totalSec = Math.floor(diff / 1000);
                                    var days  = Math.floor(totalSec / 86400);
                                    var hours = Math.floor((totalSec % 86400) / 3600);
                                    var mins  = Math.floor((totalSec % 3600) / 60);
                                    var secs  = totalSec % 60;
                                    isUrgent = (totalSec < 3600);
                                    if (days > 0)       countdownText = days + "d " + hours + "h " + mins + "m";
                                    else if (hours > 0) countdownText = hours + "h " + mins + "m";
                                    else if (mins > 0)  countdownText = mins + "m " + secs + "s";
                                    else                countdownText = secs + "s";
                                }

                                Component.onCompleted: computeCountdown()

                                // Tick every second when urgent/live, every 30s otherwise
                                Timer {
                                    id: f1CountdownTimer
                                    interval: (cardF1.isUrgent || cardF1.isLive) ? 1000 : 30000
                                    repeat:   true
                                    running:  groundControl.show && cardF1.hasEvent
                                    triggeredOnStart: true
                                    onTriggered: cardF1.computeCountdown()
                                }

                                Connections {
                                    target: shellRoot || null
                                    ignoreUnknownSignals: true
                                    function onF1NextEventIsoChanged() { cardF1.computeCountdown(); }
                                }
                                // ─────────────────────────────────────────────────────────────

                                MouseArea {
                                    id: f1MouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (shellRoot && shellRoot.f1CalendarPopup)
                                            shellRoot.f1CalendarPopup.show = !shellRoot.f1CalendarPopup.show;
                                    }

                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.margins: 12
                                        spacing: 6

                                        // Header
                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 6
                                            Text {
                                                text: "󰛄"
                                                color: "#E10600"
                                                font { family: shellRoot ? shellRoot.iconFontFamily : "sans-serif"; pixelSize: 14 }
                                            }
                                            Text {
                                                text: "F1 Calendar"
                                                color: shellRoot ? shellRoot.colFg : "#ffffff"
                                                font { family: shellRoot ? shellRoot.fontFamily : "sans-serif"; pixelSize: 12; bold: true }
                                            }
                                            Item { Layout.fillWidth: true }

                                            // ── Countdown chip ────────────────────────────────
                                            Rectangle {
                                                id: countdownChip
                                                visible: cardF1.hasEvent
                                                height: 18
                                                width:  chipLabel.implicitWidth + (cardF1.isLive ? 18 : 10)
                                                radius: height / 2
                                                color: cardF1.isLive   ? Qt.rgba(0.88, 0.0, 0.0, 0.22)
                                                     : cardF1.isUrgent ? Qt.rgba(0.88, 0.0, 0.0, 0.14)
                                                     :                   Qt.rgba(1, 1, 1, 0.06)
                                                border.color: cardF1.isLive   ? "#E10600"
                                                            : cardF1.isUrgent ? Qt.rgba(0.88, 0.0, 0.0, 0.50)
                                                            :                   Qt.rgba(1, 1, 1, 0.10)
                                                border.width: 1
                                                Behavior on color        { ColorAnimation { duration: 400 } }
                                                Behavior on border.color { ColorAnimation { duration: 400 } }
                                                Behavior on width        { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                                                // Pulsing dot for LIVE state
                                                Rectangle {
                                                    id: liveDot
                                                    visible: cardF1.isLive
                                                    anchors.left:           parent.left
                                                    anchors.leftMargin:     5
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    width: 5; height: 5; radius: 2.5
                                                    color: "#E10600"
                                                    antialiasing: true
                                                    SequentialAnimation on opacity {
                                                        loops: Animation.Infinite
                                                        running: cardF1.isLive && groundControl.show
                                                        NumberAnimation { from: 1.0; to: 0.2; duration: 700; easing.type: Easing.InOutSine }
                                                        NumberAnimation { from: 0.2; to: 1.0; duration: 700; easing.type: Easing.InOutSine }
                                                    }
                                                }

                                                Text {
                                                    id: chipLabel
                                                    anchors.centerIn: parent
                                                    anchors.horizontalCenterOffset: cardF1.isLive ? 4 : 0
                                                    text: cardF1.countdownText
                                                    color: cardF1.isLive   ? "#FF3B30"
                                                         : cardF1.isUrgent ? "#FF9500"
                                                         : (shellRoot ? shellRoot.colFg : "#ffffff")
                                                    font {
                                                        family:    shellRoot ? shellRoot.fontFamily : "sans-serif"
                                                        pixelSize: 10
                                                        bold:      true
                                                    }
                                                    Behavior on color { ColorAnimation { duration: 400 } }
                                                }
                                            }

                                            Text {
                                                text: "󰃭"
                                                color: f1MouseArea.containsMouse ? "#E10600" : (shellRoot ? shellRoot.colMuted : "#888888")
                                                font { family: shellRoot ? shellRoot.iconFontFamily : "sans-serif"; pixelSize: 14 }
                                                Behavior on color { ColorAnimation { duration: 150 } }
                                            }
                                        }

                                        Rectangle {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 1
                                            color: Qt.rgba(1, 1, 1, 0.05)
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 2

                                            Text {
                                                text: shellRoot && shellRoot.f1NextEventName !== "" ? shellRoot.f1NextEventName : "No upcoming F1 events"
                                                color: shellRoot ? shellRoot.colFg : "#ffffff"
                                                font { family: shellRoot ? shellRoot.fontFamily : "sans-serif"; pixelSize: 11; bold: true }
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                            }
                                            RowLayout {
                                                Layout.fillWidth: true
                                                spacing: 4
                                                Text {
                                                    text: shellRoot && shellRoot.f1NextEventTime !== "" ? shellRoot.f1NextEventTime : ""
                                                    color: shellRoot ? Qt.rgba(shellRoot.colFg.r, shellRoot.colFg.g, shellRoot.colFg.b, 0.65) : Qt.rgba(1, 1, 1, 0.65)
                                                    font { family: shellRoot ? shellRoot.fontFamily : "sans-serif"; pixelSize: 10 }
                                                }
                                                Item { Layout.fillWidth: true }
                                                Text {
                                                    text: shellRoot && shellRoot.f1NextEventLocation !== "" ? "📍 " + shellRoot.f1NextEventLocation : ""
                                                    color: shellRoot ? Qt.rgba(shellRoot.colFg.r, shellRoot.colFg.g, shellRoot.colFg.b, 0.65) : Qt.rgba(1, 1, 1, 0.65)
                                                    font { family: shellRoot ? shellRoot.fontFamily : "sans-serif"; pixelSize: 10 }
                                                    elide: Text.ElideRight
                                                    Layout.maximumWidth: 140
                                                }
                                            }
                                        }

                                        Rectangle {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 1
                                            color: Qt.rgba(1, 1, 1, 0.04)
                                            visible: shellRoot && shellRoot.f1MainRaceText !== ""
                                        }

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 4
                                            visible: shellRoot && shellRoot.f1MainRaceText !== ""
                                            Text {
                                                text: "Race:"
                                                color: "#E10600"
                                                font { family: shellRoot ? shellRoot.fontFamily : "sans-serif"; pixelSize: 10; bold: true }
                                            }
                                            Text {
                                                text: shellRoot ? shellRoot.f1MainRaceText : ""
                                                color: shellRoot ? Qt.rgba(shellRoot.colFg.r, shellRoot.colFg.g, shellRoot.colFg.b, 0.75) : Qt.rgba(1, 1, 1, 0.75)
                                                font { family: shellRoot ? shellRoot.fontFamily : "sans-serif"; pixelSize: 10 }
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // ================= COLUMN 2 (RIGHT) =================
                        ColumnLayout {
                            Layout.alignment: Qt.AlignTop
                            Layout.fillWidth: true
                            Layout.preferredWidth: 280
                            spacing: 8

                            // 1. Quick Toggles Grid Card
                            CCCard {
                                shellRoot: groundControl.shellRoot
                                groundControlShow: groundControl.show
                                cardDelay: 40
                                Layout.preferredHeight: 215

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    spacing: 6

                                    GridLayout {
                                        columns: 4
                                        columnSpacing: 8
                                        rowSpacing: 6
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true

                                        CircleToggle {
                                            shellRoot: groundControl.shellRoot
                                            id: btnDnd
                                            label: "DND"
                                            iconText: shellRoot && shellRoot.dndActive ? "󰂛" : "󰂚"
                                            active: shellRoot && shellRoot.dndActive
                                            accent: shellRoot ? shellRoot.colAccent : "#3B82F6"
                                            onClicked: {
                                                if (shellRoot)
                                                    shellRoot.dndActive = !shellRoot.dndActive;
                                            }
                                        }

                                        CircleToggle {
                                            shellRoot: groundControl.shellRoot
                                            id: btnNight
                                            label: "Night"
                                            iconText: "󰖔"
                                            active: shellRoot && shellRoot.redshiftActive
                                            accent: shellRoot ? shellRoot.colAccentSecondary : "#10B981"
                                            onClicked: {
                                                if (shellRoot && !shellRoot.pRedshiftToggle.running)
                                                    shellRoot.pRedshiftToggle.running = true;
                                            }
                                        }

                                        CircleToggle {
                                            shellRoot: groundControl.shellRoot
                                            id: btnCaffeine
                                            label: "Caffeine"
                                            iconText: "󰅶"
                                            active: shellRoot && shellRoot.caffeineActive
                                            accent: shellRoot ? shellRoot.colAccent : "#3B82F6"
                                            onClicked: {
                                                if (shellRoot)
                                                    shellRoot.pCaffeineToggle.running = true;
                                            }
                                        }

                                        CircleToggle {
                                            shellRoot: groundControl.shellRoot
                                            id: btnHealth
                                            label: "Health"
                                            iconText: "󰏖"
                                            active: shellRoot && shellRoot.healthRemindersActive
                                            accent: shellRoot ? shellRoot.colAccentSecondary : "#10B981"
                                            onClicked: {
                                                if (shellRoot)
                                                    shellRoot.healthRemindersActive = !shellRoot.healthRemindersActive;
                                            }
                                        }

                                        CircleToggle {
                                            shellRoot: groundControl.shellRoot
                                            id: btnBatteryMode
                                            label: {
                                                if (!shellRoot)
                                                    return "Norm";
                                                return shellRoot.powerProfile === "performance" ? "Perf" : (shellRoot.powerProfile === "power-saver" ? "Eco" : "Norm");
                                            }
                                            iconText: {
                                                if (!shellRoot)
                                                    return "󰾆";
                                                return shellRoot.powerProfile === "performance" ? "" : (shellRoot.powerProfile === "power-saver" ? "" : "󰾆");
                                            }
                                            active: shellRoot && shellRoot.powerProfile !== "balanced"
                                            accent: shellRoot ? shellRoot.colAccent : "#3B82F6"
                                            onClicked: {
                                                if (shellRoot)
                                                    shellRoot.pCyclePowerProfile.running = true;
                                            }
                                        }

                                        CircleToggle {
                                            shellRoot: groundControl.shellRoot
                                            id: btnPomodoro
                                            label: {
                                                if (!shellRoot)
                                                    return "Focus";
                                                if (shellRoot.pomodoroState === 1)
                                                    return "Work";
                                                if (shellRoot.pomodoroState === 2)
                                                    return "Break";
                                                return "Focus";
                                            }
                                            iconText: "󰄉"
                                            active: shellRoot && shellRoot.pomodoroState > 0
                                            accent: shellRoot ? (shellRoot.pomodoroState === 1 ? shellRoot.colAccent : shellRoot.colAccentSecondary) : "#3B82F6"
                                            onClicked: {
                                                if (shellRoot) {
                                                    if (shellRoot.pomodoroState === 0) {
                                                        shellRoot.pomodoroState = 1;
                                                        shellRoot.timerTotal = shellRoot.pomodoroWorkTotal;
                                                        shellRoot.timerSeconds = shellRoot.timerTotal;
                                                        shellRoot.timerText = shellRoot.formatTime(shellRoot.timerTotal);
                                                        shellRoot.timerRunning = true;
                                                    } else {
                                                        shellRoot.pomodoroState = 0;
                                                        shellRoot.timerRunning = false;
                                                        shellRoot.timerSeconds = 0;
                                                        shellRoot.timerTotal = 300;
                                                        shellRoot.timerText = shellRoot.formatTime(shellRoot.timerTotal);
                                                    }
                                                }
                                            }
                                        }

                                        CircleToggle {
                                            shellRoot: groundControl.shellRoot
                                            id: btnStopwatch
                                            label: shellRoot ? shellRoot.stopwatchText : "00:00"
                                            iconText: "󰔚"
                                            active: shellRoot && (shellRoot.stopwatchRunning || shellRoot.stopwatchSeconds > 0)
                                            accent: shellRoot ? shellRoot.colAccentSecondary : "#10B981"
                                            onClicked: {
                                                if (shellRoot)
                                                    shellRoot.stopwatchRunning = !shellRoot.stopwatchRunning;
                                            }
                                            onPressAndHold: {
                                                if (shellRoot) {
                                                    shellRoot.stopwatchRunning = false;
                                                    shellRoot.stopwatchSeconds = 0;
                                                    shellRoot.stopwatchText = "00:00";
                                                }
                                            }
                                        }

                                        CircleToggle {
                                            shellRoot: groundControl.shellRoot
                                            id: btnTimer
                                            label: shellRoot ? shellRoot.timerText : "05:00"
                                            iconText: "󰔛"
                                            active: shellRoot && (shellRoot.timerRunning || (shellRoot.timerSeconds > 0 && shellRoot.timerSeconds < shellRoot.timerTotal))
                                            accent: shellRoot ? shellRoot.colAccent : "#3B82F6"
                                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                                            onClicked: {
                                                if (mouse.button === Qt.RightButton) {
                                                    if (shellRoot) {
                                                        shellRoot.timerPopup.show = !shellRoot.timerPopup.show;
                                                    }
                                                } else {
                                                    if (shellRoot) {
                                                        shellRoot.pomodoroState = 0;
                                                        if (shellRoot.timerRunning) {
                                                            shellRoot.timerRunning = false;
                                                        } else if (shellRoot.timerSeconds > 0) {
                                                            shellRoot.timerRunning = true;
                                                        } else {
                                                            shellRoot.timerSeconds = shellRoot.timerTotal;
                                                            shellRoot.timerText = shellRoot.formatTime(shellRoot.timerTotal);
                                                            shellRoot.timerRunning = true;
                                                        }
                                                    }
                                                }
                                            }
                                            onPressAndHold: {
                                                if (shellRoot) {
                                                    shellRoot.pomodoroState = 0;
                                                    shellRoot.timerRunning = false;
                                                    shellRoot.timerSeconds = 0;
                                                    shellRoot.timerText = shellRoot.formatTime(shellRoot.timerTotal);
                                                }
                                            }
                                            onWheel: {
                                                if (shellRoot) {
                                                    shellRoot.pomodoroState = 0;
                                                    if (wheel.angleDelta.y > 0) {
                                                        shellRoot.timerTotal += 60;
                                                    } else if (wheel.angleDelta.y < 0 && shellRoot.timerTotal >= 120) {
                                                        shellRoot.timerTotal -= 60;
                                                    }
                                                    shellRoot.timerRunning = false;
                                                    shellRoot.timerSeconds = 0;
                                                    shellRoot.timerText = shellRoot.formatTime(shellRoot.timerTotal);
                                                }
                                            }
                                        }
                                    }

                                    // Divider
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 1
                                        color: Qt.rgba(1, 1, 1, 0.08)
                                    }

                                    GridLayout {
                                        columns: 4
                                        columnSpacing: 8
                                        rowSpacing: 6
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true

                                        CircleToggle {
                                            shellRoot: groundControl.shellRoot
                                            id: btnScreen
                                            label: "Screen"
                                            iconText: "󰄀"
                                            accent: shellRoot ? shellRoot.colAccent : "#3B82F6"
                                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                                            onClicked: {
                                                groundControl.hideImmediately = true;
                                                groundControl.show = false;
                                                if (shellRoot) {
                                                    if (mouse.button === Qt.RightButton) {
                                                        shellRoot.pScreenshotNow.running = true;
                                                    } else {
                                                        shellRoot.pScreenshotSel.running = true;
                                                    }
                                                }
                                            }
                                        }

                                        CircleToggle {
                                            shellRoot: groundControl.shellRoot
                                            id: btnRecord
                                            label: shellRoot && shellRoot.isRecording ? "Stop" : "Record"
                                            iconText: shellRoot && shellRoot.isRecording ? "󰓛" : "󰑊"
                                            active: shellRoot && shellRoot.isRecording
                                            accent: shellRoot ? shellRoot.colAccentSecondary : "#EF4444"
                                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                                            onClicked: {
                                                if (shellRoot) {
                                                    if (shellRoot.isRecording) {
                                                        shellRoot.pStopRecord.running = true;
                                                    } else {
                                                        groundControl.hideImmediately = true;
                                                        groundControl.show = false;
                                                        if (mouse.button === Qt.RightButton) {
                                                            shellRoot.pRecordFull.running = true;
                                                        } else {
                                                            shellRoot.pRecordSel.running = true;
                                                        }
                                                    }
                                                }
                                            }
                                        }

                                        CircleToggle {
                                            shellRoot: groundControl.shellRoot
                                            id: btnTheme
                                            label: "Theme"
                                            iconText: "󰸉"
                                            accent: shellRoot ? shellRoot.colAccent : "#3B82F6"
                                            onClicked: {
                                                groundControl.hideImmediately = true;
                                                groundControl.show = false;
                                                if (shellRoot)
                                                    shellRoot.wallpaperMenuPopup.show = true;
                                            }
                                        }

                                        CircleToggle {
                                            shellRoot: groundControl.shellRoot
                                            id: btnColor
                                            label: "Color"
                                            iconText: "󰏘"
                                            accent: shellRoot ? shellRoot.colAccentSecondary : "#10B981"
                                            onClicked: {
                                                groundControl.hideImmediately = true;
                                                groundControl.show = false;
                                                if (shellRoot)
                                                    shellRoot.pColorPicker.running = true;
                                            }
                                        }
                                    }
                                }
                            }

                            // 2. Spotify Media Bento Card
                            CCCard {
                                id: spotifyCard
                                // Intentionally shows when "paused" (not just "playing") as a quick-resume
                                // affordance — the card stays visible so the user can unpause from CC without
                                // reopening Spotify. Only collapses when the player process exits ("offline").
                                property bool hasSpotify: shellRoot && shellRoot.spotifyStatus !== "offline"
                                shellRoot: groundControl.shellRoot
                                groundControlShow: groundControl.show
                                showCard: hasSpotify
                                visible: opacity > 0.01 || Layout.preferredHeight > 10
                                cardDelay: 120
                                Layout.preferredHeight: hasSpotify ? 114 : 0
                                Behavior on Layout.preferredHeight { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                                Layout.topMargin: hasSpotify ? 0 : -8
                                Behavior on Layout.topMargin { NumberAnimation { duration: 250 } }
                                clip: true

                                // Dedicated rounded container for background art to force perfect rounded corner clipping
                                Rectangle {
                                    anchors.fill: parent
                                    color: "transparent"

                                    Rectangle {
                                        id: spotifyArtMask
                                        anchors.fill: parent
                                        radius: 16
                                        visible: false
                                        layer.enabled: true
                                    }

                                    layer.enabled: true
                                    layer.effect: MultiEffect {
                                        maskEnabled: true
                                        maskSource: spotifyArtMask
                                    }

                                    Image {
                                        id: spotifyArtBg
                                        anchors.fill: parent
                                        anchors.margins: -16 // Bleed out to avoid edge artifacts
                                        source: (shellRoot && shellRoot.spotifyArtUrl && shellRoot.spotifyArtUrl.length > 8) ? shellRoot.spotifyArtUrl : ""
                                        fillMode: Image.PreserveAspectCrop
                                        opacity: status === Image.Ready ? 0.20 : 0.0
                                        Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutQuad } }
                                        visible: (shellRoot && shellRoot.spotifyArtUrl && shellRoot.spotifyArtUrl.length > 8)
                                    }

                                    MultiEffect {
                                         id: spotifyArtBlur
                                         source: spotifyArtBg
                                         anchors.fill: parent
                                         blurEnabled: true
                                         blur: 0.25
                                         opacity: 0.30
                                         visible: spotifyArtBg.visible
                                    }

                                    Rectangle {
                                        anchors.fill: parent
                                        color: "#000000"
                                        opacity: 0.60
                                        visible: spotifyArtBg.visible
                                    }
                                }

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    spacing: 6

                                    RowLayout {
                                        Layout.fillWidth: true
                                        Text {
                                            text: ""
                                            color: "#1DB954"
                                            font.family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                                            font.pixelSize: 16
                                        }
                                        Text {
                                            text: shellRoot ? shellRoot.spotifyText : ""
                                            color: shellRoot ? shellRoot.colFg : "#ffffff"
                                            font.family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                                            font.pixelSize: 12
                                            font.bold: true
                                            Layout.fillWidth: true
                                            elide: Text.ElideRight
                                        }
                                    }

                                    // Progress Seek Bar
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 6
                                        Text {
                                            text: shellRoot ? shellRoot.spotifyPositionStr : "0:00"
                                            color: Qt.rgba(1, 1, 1, 0.65)
                                            font.family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                                            font.pixelSize: 9
                                            Layout.alignment: Qt.AlignVCenter
                                        }
                                        ModernSlider {
                                            id: progressSlider
                                            shellRoot: groundControl.shellRoot
                                            sliderAccent: "#1DB954"
                                            from: 0
                                            to: shellRoot ? Math.max(1.0, shellRoot.spotifyLength) : 100
                                            value: shellRoot ? shellRoot.spotifyPosition : 0
                                            Layout.fillWidth: true
                                            Layout.alignment: Qt.AlignVCenter
                                            onMoved: {
                                                if (shellRoot) {
                                                    shellRoot.seekTrack(value);
                                                }
                                            }
                                        }
                                        Text {
                                            text: shellRoot ? shellRoot.spotifyLengthStr : "0:00"
                                            color: Qt.rgba(1, 1, 1, 0.65)
                                            font.family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                                            font.pixelSize: 9
                                            Layout.alignment: Qt.AlignVCenter
                                        }
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 12
                                        Item {
                                            Layout.fillWidth: true
                                        }
                                        ModernButton {
                                            Layout.preferredWidth: 40
                                            Layout.preferredHeight: 32
                                            iconText: "󰒮"
                                            onClicked: {
                                                if (shellRoot)
                                                    shellRoot.pSpotPrev.running = true;
                                            }
                                        }
                                        ModernButton {
                                            Layout.preferredWidth: 54
                                            Layout.preferredHeight: 32
                                            iconText: shellRoot && shellRoot.spotifyStatus === "playing" ? "󰏤" : "󰐊"
                                            isActive: shellRoot && shellRoot.spotifyStatus === "playing"
                                            accent: "#1DB954"
                                            onClicked: {
                                                if (shellRoot)
                                                    shellRoot.pSpotPlay.running = true;
                                            }
                                        }
                                        ModernButton {
                                            Layout.preferredWidth: 40
                                            Layout.preferredHeight: 32
                                            iconText: "󰒭"
                                            onClicked: {
                                                if (shellRoot)
                                                    shellRoot.pSpotNext.running = true;
                                            }
                                        }
                                        Item {
                                            Layout.fillWidth: true
                                        }
                                    }
                                }
                            }

                            // 3. Resource Sparklines (CPU/RAM side-by-side)
                            CCCard {
                                shellRoot: groundControl.shellRoot
                                groundControlShow: groundControl.show
                                cardDelay: 160
                                Layout.preferredHeight: 74
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    spacing: 12

                                    // CPU Block
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 2
                                        RowLayout {
                                            Layout.fillWidth: true
                                            Text {
                                                text: "CPU"
                                                color: shellRoot ? shellRoot.colFg : "#ffffff"
                                                font {
                                                    family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                                                    pixelSize: 10
                                                    bold: true
                                                }
                                            }
                                            Item {
                                                Layout.fillWidth: true
                                            }
                                            Text {
                                                text: (shellRoot ? shellRoot.cpuUsage : 0) + "%"
                                                color: shellRoot ? shellRoot.colFg : "#ffffff"
                                                font {
                                                    family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                                                    pixelSize: 10
                                                    bold: true
                                                }
                                            }
                                        }
                                        SparklineChart {
                                            history: shellRoot ? shellRoot.cpuHistory : []
                                            strokeColor: shellRoot ? shellRoot.colAccent : "#ffffff"
                                        }
                                    }

                                    // Divider
                                    Rectangle {
                                        Layout.preferredWidth: 1
                                        Layout.fillHeight: true
                                        color: Qt.rgba(1, 1, 1, 0.08)
                                    }

                                    // RAM Block
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 2
                                        RowLayout {
                                            Layout.fillWidth: true
                                            Text {
                                                text: "RAM"
                                                color: shellRoot ? shellRoot.colFg : "#ffffff"
                                                font {
                                                    family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                                                    pixelSize: 10
                                                    bold: true
                                                }
                                            }
                                            Item {
                                                Layout.fillWidth: true
                                            }
                                            Text {
                                                text: (shellRoot ? shellRoot.ramUsage : 0) + "%"
                                                color: shellRoot ? shellRoot.colFg : "#ffffff"
                                                font {
                                                    family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                                                    pixelSize: 10
                                                    bold: true
                                                }
                                            }
                                        }
                                        SparklineChart {
                                            history: shellRoot ? shellRoot.ramHistory : []
                                            strokeColor: shellRoot ? shellRoot.colAccent : "#ffffff"
                                        }
                                    }
                                }
                            }

                            // 4. Dedicated Email Inbox Card
                            CCCard {
                                id: cardEmails
                                shellRoot: groundControl.shellRoot
                                groundControlShow: groundControl.show
                                cardDelay: 180
                                Layout.preferredHeight: (shellRoot && shellRoot.latestEmails && shellRoot.latestEmails.length > 0) ? 110 : 64
                                clip: true

                                MouseArea {
                                    id: emailMouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (shellRoot && shellRoot.emailsPopup) {
                                            shellRoot.emailsPopup.show = !shellRoot.emailsPopup.show;
                                        }
                                    }

                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.margins: 12
                                        spacing: 6

                                        // Header
                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 6
                                            Text {
                                                text: "󰇮"
                                                color: "#007AFF"
                                                font {
                                                    family: shellRoot ? shellRoot.iconFontFamily : "sans-serif"
                                                    pixelSize: 14
                                                }
                                            }
                                            Text {
                                                text: "Inbox"
                                                color: shellRoot ? shellRoot.colFg : "#ffffff"
                                                font {
                                                    family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                                                    pixelSize: 11
                                                    bold: true
                                                }
                                            }
                                            Rectangle {
                                                color: Qt.rgba(0, 122, 255, 0.15)
                                                radius: 4
                                                implicitWidth: mailCountText.implicitWidth + 8
                                                implicitHeight: 14
                                                Text {
                                                    id: mailCountText
                                                    anchors.centerIn: parent
                                                    text: shellRoot ? shellRoot.todayEmailsCount : "0"
                                                    color: "#007AFF"
                                                    font {
                                                        family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                                                        pixelSize: 11
                                                        bold: true
                                                    }
                                                }
                                            }
                                            Item {
                                                Layout.fillWidth: true
                                            }
                                            Text {
                                                text: "󰇰"
                                                color: emailMouseArea.containsMouse ? "#007AFF" : (shellRoot ? shellRoot.colMuted : "#888888")
                                                font {
                                                    family: shellRoot ? shellRoot.iconFontFamily : "sans-serif"
                                                    pixelSize: 14
                                                }
                                                Behavior on color {
                                                    ColorAnimation {
                                                        duration: 150
                                                    }
                                                }
                                            }
                                        }

                                        Rectangle {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 1
                                            color: Qt.rgba(1, 1, 1, 0.05)
                                        }

                                        // Email list (3 most recent)
                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            Layout.fillHeight: true
                                            spacing: 4

                                            Repeater {
                                                model: (shellRoot && shellRoot.latestEmails) ? shellRoot.latestEmails.slice(0, 3) : []
                                                delegate: ColumnLayout {
                                                    Layout.fillWidth: true
                                                    spacing: 1
                                                    RowLayout {
                                                        Layout.fillWidth: true
                                                        spacing: 6
                                                        Text {
                                                            text: modelData.from
                                                            color: shellRoot ? shellRoot.colFg : "#ffffff"
                                                            font {
                                                                family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                                                                pixelSize: 10
                                                                bold: true
                                                            }
                                                            elide: Text.ElideRight
                                                            Layout.preferredWidth: 80
                                                        }
                                                        Text {
                                                            text: modelData.subject
                                                            color: shellRoot ? Qt.rgba(shellRoot.colFg.r, shellRoot.colFg.g, shellRoot.colFg.b, 0.65) : Qt.rgba(1, 1, 1, 0.65)
                                                            font {
                                                                family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                                                                pixelSize: 10
                                                            }
                                                            elide: Text.ElideRight
                                                            Layout.fillWidth: true
                                                        }
                                                    }
                                                    Rectangle {
                                                        Layout.fillWidth: true
                                                        Layout.preferredHeight: 1
                                                        color: Qt.rgba(1, 1, 1, 0.03)
                                                        visible: index < (Math.min(shellRoot.latestEmails.length, 3) - 1)
                                                    }
                                                }
                                            }

                                            Text {
                                                visible: !shellRoot || !shellRoot.latestEmails || shellRoot.latestEmails.length === 0
                                                text: "No recent emails"
                                                color: shellRoot ? Qt.rgba(shellRoot.colFg.r, shellRoot.colFg.g, shellRoot.colFg.b, 0.65) : Qt.rgba(1, 1, 1, 0.65)
                                                font {
                                                    family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                                                    pixelSize: 10
                                                }
                                                horizontalAlignment: Text.AlignHCenter
                                                Layout.fillWidth: true
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ================= BOTTOM SECTION: NOTIFICATIONS =================
                    NotificationList {
                        shellRoot: groundControl.shellRoot
                        groundControlShow: groundControl.show
                    }
                }
            }
        }
    }


}
