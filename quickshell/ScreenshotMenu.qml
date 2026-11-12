import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: rootWindow

    property bool show: false
    property var shellRoot
    readonly property real fontScale: s * (shellRoot ? shellRoot.fontSizeMultiplier : 1.0)
    property bool isClosing: false
    property real savedCloseTarget: 120
    property bool suppressOpenAnimation: false
    property int selectedIndex: 0
    property int pendingAction: -1

    readonly property real s: shellRoot ? shellRoot.scaleFactor : 1.0
    readonly property bool isRecording: shellRoot ? shellRoot.isRecording : false

    // Actions: 6 actions total — 4 Capture, 2 Record (or Stop Recording)
    readonly property var actions: [
        {
            icon:    "󰹑",
            label:   "Region",
            sub:     "select area",
            color:   Qt.rgba(0.36, 0.73, 1.0, 0.85),
            action:  function() {
                if (shellRoot && shellRoot.screenSelector) shellRoot.screenSelector.open("sel");
                else if (shellRoot && shellRoot.pScreenshotSel) shellRoot.pScreenshotSel.running = true;
            }
        },
        {
            icon:    "󰹕",
            label:   "Screen",
            sub:     "full display",
            color:   Qt.rgba(0.47, 0.87, 0.63, 0.85),
            action:  function() { if (shellRoot && shellRoot.pScreenshotNow) shellRoot.pScreenshotNow.running = true; }
        },
        {
            icon:    "󱃩",
            label:   "Extract",
            sub:     "OCR text",
            color:   Qt.rgba(1.0, 0.74, 0.25, 0.85),
            action:  function() {
                if (shellRoot && shellRoot.screenSelector) shellRoot.screenSelector.open("ocr");
                else if (shellRoot && shellRoot.pOcrShot) shellRoot.pOcrShot.running = true;
            }
        },
        {
            icon:    "󰄀",
            label:   "Picker",
            sub:     "color tool",
            color:   Qt.rgba(0.78, 0.45, 1.0, 0.85),
            action:  function() { if (shellRoot && shellRoot.pColorPicker) shellRoot.pColorPicker.running = true; }
        },
        {
            icon:    isRecording ? "󰓛" : "󰕧",
            label:   isRecording ? "Stop Recording" : "Rec Region",
            sub:     isRecording ? (shellRoot ? shellRoot.recordingTime : "0:00") : "select area",
            color:   Qt.rgba(1.0, 0.35, 0.35, 0.85),
            action:  function() {
                if (isRecording) {
                    if (shellRoot && shellRoot.pStopRecord) shellRoot.pStopRecord.running = true;
                } else {
                    if (shellRoot && shellRoot.screenSelector) shellRoot.screenSelector.open("record");
                    else if (shellRoot && shellRoot.pRecordSel) shellRoot.pRecordSel.running = true;
                }
            }
        },
        {
            icon:    isRecording ? "󰓛" : "󰒚",
            label:   isRecording ? "Stop Recording" : "Rec Full",
            sub:     isRecording ? (shellRoot ? shellRoot.recordingTime : "0:00") : "full screen",
            color:   Qt.rgba(1.0, 0.35, 0.35, 0.85),
            action:  function() {
                if (isRecording) {
                    if (shellRoot && shellRoot.pStopRecord) shellRoot.pStopRecord.running = true;
                } else {
                    if (shellRoot && shellRoot.pRecordFull) shellRoot.pRecordFull.running = true;
                }
            }
        }
    ]

    function triggerAction(idx) {
        if (idx < 0 || idx >= actions.length) return;
        pendingAction = idx;
        show = false;
        actionTimer.restart();
    }

    // ── Layer-shell setup ─────────────────────────────────────────────────────
    WlrLayershell.keyboardFocus: show ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    WlrLayershell.namespace: "quickshell"
    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    // Input mask: full when visible, empty when hidden so slurp can grab the pointer
    mask: show ? fullRegion : emptyRegion
    Region { id: emptyRegion }
    Region {
        id: fullRegion
        width: rootWindow.width
        height: rootWindow.height
    }

    visible: show || isClosing

    // ── Lifecycle ─────────────────────────────────────────────────────────────
    onShowChanged: {
        if (show) {
            isClosing = false;
            closeWatchdog.stop();
            suppressOpenAnimation = true;
            snapResetTimer.start();
            savedCloseTarget = Qt.binding(function() { return shellRoot ? shellRoot.closedNotchWidth : 120; });
            selectedIndex = 0;
            focusTimer.start();
        } else {
            savedCloseTarget = shellRoot ? shellRoot.closedNotchWidth : 120;
            isClosing = true;
            closeWatchdog.restart();
        }
    }

    Timer { id: snapResetTimer; interval: 32; repeat: false; onTriggered: rootWindow.suppressOpenAnimation = false }
    Timer { id: focusTimer; interval: 50; onTriggered: menuContent.forceActiveFocus() }

    // Safety watchdog so isClosing never jams
    Timer {
        id: closeWatchdog
        interval: 400
        repeat: false
        onTriggered: { if (rootWindow.isClosing) rootWindow.isClosing = false; }
    }

    // Delay action so the window fully disappears before screenshot is taken
    Timer {
        id: actionTimer
        interval: 220
        repeat: false
        onTriggered: {
            rootWindow.isClosing = false;
            var idx = rootWindow.pendingAction;
            rootWindow.pendingAction = -1;
            if (idx >= 0 && idx < rootWindow.actions.length)
                rootWindow.actions[idx].action();
        }
    }

    // ── Content ───────────────────────────────────────────────────────────────
    Item {
        id: menuContent
        anchors.fill: parent
        focus: show

        Keys.onEscapePressed: { rootWindow.pendingAction = -1; show = false; }
        Keys.onLeftPressed: {
            if (isRecording && selectedIndex === 4) {
                selectedIndex = 0;
            } else if (!isRecording && selectedIndex >= 4) {
                selectedIndex = (selectedIndex === 5) ? 4 : 3;
            } else {
                selectedIndex = (selectedIndex - 1 + 4) % 4;
            }
        }
        Keys.onRightPressed: {
            if (isRecording && selectedIndex === 4) {
                selectedIndex = 0;
            } else if (!isRecording && selectedIndex >= 4) {
                selectedIndex = (selectedIndex === 4) ? 5 : 0;
            } else {
                selectedIndex = (selectedIndex + 1) % 4;
            }
        }
        Keys.onDownPressed: {
            selectedIndex = 4;
        }
        Keys.onUpPressed: {
            if (selectedIndex >= 4) selectedIndex = 0;
        }
        Keys.onReturnPressed: triggerAction(selectedIndex)
        Keys.onEnterPressed:  triggerAction(selectedIndex)
        Keys.onPressed: event => {
            if (event.key >= Qt.Key_1 && event.key <= Qt.Key_6) {
                triggerAction(event.key - Qt.Key_1);
                event.accepted = true;
            }
        }

        // Backdrop click to dismiss
        MouseArea {
            anchors.fill: parent
            enabled: show
            onClicked: { rootWindow.pendingAction = -1; show = false; }
        }

        // ── Animated pill ─────────────────────────────────────────────────────
        Rectangle {
            id: animRect
            anchors.top: parent.top
            anchors.topMargin: 4 * s
            anchors.horizontalCenter: parent.horizontalCenter

            width:  rootWindow.suppressOpenAnimation ? 32 * s : rootWindow.show ? contentCol.implicitWidth  + 40 * s : (rootWindow.isClosing ? 32 * s : savedCloseTarget)
            height: rootWindow.suppressOpenAnimation ? 32 * s : rootWindow.show ? contentCol.implicitHeight + 36 * s : (rootWindow.isClosing ? 32 * s : 32 * s)
            radius: Math.round(4 * s)
            color: "transparent"

            SurfaceCard {
                id: smGlassCard
                anchors.fill: parent
                radius: animRect.radius
                contentPadding: 0
            }

            function checkCloseFinished() {
                if (!rootWindow.show && rootWindow.isClosing) {
                    var tw = 32 * s;
                    var th = 32 * s;
                    if (Math.abs(width - tw) < 2.5 && Math.abs(height - th) < 2.5) {
                        rootWindow.isClosing = false;
                        closeWatchdog.stop();
                    }
                }
            }
            onWidthChanged: checkCloseFinished()
            onHeightChanged: checkCloseFinished()

            Behavior on radius { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
            Behavior on width { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
            Behavior on height { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

            // Content fades + scales in
            Item {
                anchors.fill: parent
                clip: true

                opacity: rootWindow.show ? 1.0 : 0.0
                Behavior on opacity {
                    SequentialAnimation {
                        PauseAnimation { duration: (shellRoot && shellRoot.batteryMode) ? 0 : (rootWindow.show ? 110 : 0) }
                        NumberAnimation {
                            duration: (shellRoot && shellRoot.batteryMode) ? 120 : (rootWindow.show ? 280 : 70)
                            easing.type: rootWindow.show ? Easing.OutQuad : Easing.InQuad
                        }
                    }
                }

                scale: rootWindow.show ? 1.0 : 0.94
                Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }

                ColumnLayout {
                    id: contentCol
                    anchors.centerIn: parent
                    spacing: 16 * s

                    // ── Header ────────────────────────────────────────────────
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        // Camera icon badge
                        Rectangle {
                            width: 22 * s; height: 22 * s; radius: 4 * s
                            color: isRecording ? Qt.rgba(1.0, 0.28, 0.28, 0.15) : Qt.rgba(0.36, 0.73, 1.0, 0.15)
                            border.color: isRecording ? Qt.rgba(1.0, 0.28, 0.28, 0.35) : Qt.rgba(0.36, 0.73, 1.0, 0.3)
                            border.width: 1

                            Behavior on color { ColorAnimation { duration: 150 } }
                            Behavior on border.color { ColorAnimation { duration: 150 } }

                            Text {
                                anchors.centerIn: parent
                                text: isRecording ? "󰓛" : "󰄀"
                                color: isRecording ? "#FF453A" : Qt.rgba(0.36, 0.73, 1.0, 1.0)
                                font.family: shellRoot ? shellRoot.iconFontFamily : "sans-serif"
                                font.pixelSize: 11 * fontScale

                                Behavior on color { ColorAnimation { duration: 150 } }
                            }
                        }

                        Item { width: 8 * s }

                        Text {
                            text: isRecording ? "Screen Recording" : "Capture"
                            color: shellRoot ? shellRoot.colFg : "white"
                            font.family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                            font.pixelSize: 12 * fontScale
                            font.bold: true
                            Layout.fillWidth: true
                        }

                        Text {
                            text: "esc"
                            color: shellRoot ? shellRoot.colMuted : "#555"
                            font.family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                            font.pixelSize: 8 * fontScale

                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: -3 * s
                                radius: 3 * s
                                color: "transparent"
                                border.color: shellRoot ? shellRoot.colBorder : Qt.rgba(1,1,1,0.1)
                                border.width: 1
                            }
                        }
                    }

                    // ── Capture row (4 buttons) ────────────────────────────────
                    RowLayout {
                        spacing: 10 * s
                        Layout.alignment: Qt.AlignHCenter

                        Repeater {
                            model: 4
                            delegate: CaptureButton {
                                required property int index
                                btnIndex: index
                                btnData:  rootWindow.actions[index]
                                isSelected: rootWindow.selectedIndex === index
                                fontScale: rootWindow.fontScale
                                shellRoot: rootWindow.shellRoot
                                s: rootWindow.s
                                onClicked: rootWindow.triggerAction(index)
                                onHovered: rootWindow.selectedIndex = index
                            }
                        }
                    }

                    // ── Divider ───────────────────────────────────────────────
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8 * s
                        Rectangle { Layout.fillWidth: true; height: 1; color: shellRoot ? shellRoot.colBorder : Qt.rgba(1,1,1,0.07) }
                        Text {
                            text: isRecording ? "recording active" : "record"
                            color: isRecording ? "#FF453A" : (shellRoot ? shellRoot.colMuted : "#555")
                            font.family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                            font.pixelSize: 7.5 * fontScale
                            font.capitalization: Font.AllUppercase
                            font.letterSpacing: 1.2
                            font.bold: isRecording

                            Behavior on color { ColorAnimation { duration: 150 } }
                        }
                        Rectangle { Layout.fillWidth: true; height: 1; color: shellRoot ? shellRoot.colBorder : Qt.rgba(1,1,1,0.07) }
                    }

                    // ── Record row: Stop Recording button when active, else 2 buttons ────
                    Item {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: 254 * s
                        Layout.preferredHeight: isRecording ? 42 * s : 38 * s

                        Behavior on Layout.preferredHeight {
                            NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
                        }

                        // Stop Recording Button (Active mode)
                        StopRecordingButton {
                            anchors.fill: parent
                            visible: rootWindow.isRecording
                            isSelected: rootWindow.selectedIndex >= 4
                            fontScale: rootWindow.fontScale
                            shellRoot: rootWindow.shellRoot
                            s: rootWindow.s
                            onClicked: rootWindow.triggerAction(4)
                            onHovered: rootWindow.selectedIndex = 4
                        }

                        // Normal Record Buttons (Idle mode)
                        RowLayout {
                            anchors.fill: parent
                            spacing: 10 * s
                            visible: !rootWindow.isRecording

                            Repeater {
                                model: 2
                                delegate: RecordButton {
                                    required property int index
                                    btnIndex: index + 4
                                    btnData:  rootWindow.actions[index + 4]
                                    isSelected: rootWindow.selectedIndex === (index + 4)
                                    fontScale: rootWindow.fontScale
                                    shellRoot: rootWindow.shellRoot
                                    s: rootWindow.s
                                    onClicked: rootWindow.triggerAction(index + 4)
                                    onHovered: rootWindow.selectedIndex = index + 4
                                }
                            }
                        }
                    }

                    // ── Keyboard hints ────────────────────────────────────────
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 4 * s
                        Layout.alignment: Qt.AlignHCenter

                        Repeater {
                            model: isRecording ? ["1","2","3","4","5/6: Stop"] : ["1","2","3","4","5","6"]
                            delegate: Row {
                                spacing: 3 * s
                                Rectangle {
                                    width: (modelData.length > 1 ? 46 : 14) * s
                                    height: 14 * s
                                    radius: 3 * s
                                    color: (isRecording && modelData.indexOf("Stop") !== -1)
                                        ? Qt.rgba(1.0, 0.28, 0.28, 0.15)
                                        : Qt.rgba(1, 1, 1, 0.05)
                                    border.color: (isRecording && modelData.indexOf("Stop") !== -1)
                                        ? Qt.rgba(1.0, 0.28, 0.28, 0.4)
                                        : Qt.rgba(1, 1, 1, 0.1)
                                    border.width: 1

                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData
                                        color: (isRecording && modelData.indexOf("Stop") !== -1)
                                            ? "#FF453A"
                                            : (shellRoot ? shellRoot.colMuted : "#555")
                                        font.family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                                        font.pixelSize: 7 * fontScale
                                        font.bold: true
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ── Inline button components ──────────────────────────────────────────────
    component CaptureButton: Item {
        id: cbRoot
        property int btnIndex: 0
        property var btnData: ({})
        property bool isSelected: false
        property real fontScale: 1.0
        property var shellRoot: null
        property real s: 1.0
        signal clicked()
        signal hovered()

        width:  56 * s
        height: 68 * s

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 7 * s

            Rectangle {
                id: btnBg
                width: 52 * s; height: 52 * s; radius: 4 * s
                anchors.horizontalCenter: parent.horizontalCenter

                color: (btnMouse.containsMouse || cbRoot.isSelected)
                    ? Qt.rgba(cbRoot.btnData.color.r, cbRoot.btnData.color.g, cbRoot.btnData.color.b, 0.22)
                    : Qt.rgba(1, 1, 1, 0.06)

                border.color: (btnMouse.containsMouse || cbRoot.isSelected)
                    ? Qt.rgba(cbRoot.btnData.color.r, cbRoot.btnData.color.g, cbRoot.btnData.color.b, 0.7)
                    : (shellRoot ? shellRoot.colBorder : Qt.rgba(1,1,1,0.09))
                border.width: (btnMouse.containsMouse || cbRoot.isSelected) ? 1.5 : 1

                Behavior on color  { ColorAnimation { duration: 120 } }
                Behavior on border.color { ColorAnimation { duration: 120 } }

                scale: (btnMouse.containsMouse || cbRoot.isSelected) ? 1.10 : 1.0
                Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }

                Text {
                    anchors.centerIn: parent
                    text: cbRoot.btnData.icon || ""
                    color: (btnMouse.containsMouse || cbRoot.isSelected)
                        ? Qt.rgba(cbRoot.btnData.color.r, cbRoot.btnData.color.g, cbRoot.btnData.color.b, 1.0)
                        : (shellRoot ? shellRoot.colFg : "white")
                    font.family: shellRoot ? shellRoot.iconFontFamily : "sans-serif"
                    font.pixelSize: 20 * fontScale
                    Behavior on color { ColorAnimation { duration: 120 } }
                }

                MouseArea {
                    id: btnMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: cbRoot.hovered()
                    onClicked: cbRoot.clicked()
                }
            }

            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 1
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: cbRoot.btnData.label || ""
                    color: shellRoot ? shellRoot.colFg : "white"
                    font.family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                    font.pixelSize: 8.5 * fontScale
                    font.bold: true
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: cbRoot.btnData.sub || ""
                    color: shellRoot ? shellRoot.colMuted : "#666"
                    font.family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                    font.pixelSize: 7 * fontScale
                }
            }
        }
    }

    component RecordButton: Item {
        id: rbRoot
        property int btnIndex: 0
        property var btnData: ({})
        property bool isSelected: false
        property real fontScale: 1.0
        property var shellRoot: null
        property real s: 1.0
        signal clicked()
        signal hovered()

        width:  122 * s
        height: 38 * s

        Rectangle {
            id: rbBg
            anchors.fill: parent
            radius: 4 * s

            color: (recMouse.containsMouse || rbRoot.isSelected)
                ? Qt.rgba(rbRoot.btnData.color.r, rbRoot.btnData.color.g, rbRoot.btnData.color.b, 0.18)
                : Qt.rgba(1, 1, 1, 0.05)

            border.color: (recMouse.containsMouse || rbRoot.isSelected)
                ? Qt.rgba(rbRoot.btnData.color.r, rbRoot.btnData.color.g, rbRoot.btnData.color.b, 0.65)
                : (shellRoot ? shellRoot.colBorder : Qt.rgba(1,1,1,0.08))
            border.width: (recMouse.containsMouse || rbRoot.isSelected) ? 1.5 : 1

            Behavior on color       { ColorAnimation { duration: 120 } }
            Behavior on border.color { ColorAnimation { duration: 120 } }

            scale: (recMouse.containsMouse || rbRoot.isSelected) ? 1.03 : 1.0
            Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }

            RowLayout {
                anchors.centerIn: parent
                spacing: 7 * rbRoot.s

                // Red record dot
                Rectangle {
                    width: 7 * rbRoot.s; height: 7 * rbRoot.s; radius: 3.5 * rbRoot.s
                    color: Qt.rgba(1.0, 0.28, 0.28, (recMouse.containsMouse || rbRoot.isSelected) ? 1.0 : 0.5)
                    Behavior on color { ColorAnimation { duration: 120 } }
                }

                Text {
                    text: rbRoot.btnData.icon || ""
                    color: (recMouse.containsMouse || rbRoot.isSelected)
                        ? Qt.rgba(1.0, 0.45, 0.45, 1.0)
                        : (shellRoot ? shellRoot.colFg : "white")
                    font.family: shellRoot ? shellRoot.iconFontFamily : "sans-serif"
                    font.pixelSize: 14 * fontScale
                    Behavior on color { ColorAnimation { duration: 120 } }
                }

                Column {
                    spacing: 1
                    Text {
                        text: rbRoot.btnData.label || ""
                        color: shellRoot ? shellRoot.colFg : "white"
                        font.family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                        font.pixelSize: 8.5 * fontScale
                        font.bold: true
                    }
                    Text {
                        text: rbRoot.btnData.sub || ""
                        color: shellRoot ? shellRoot.colMuted : "#666"
                        font.family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                        font.pixelSize: 7 * fontScale
                    }
                }
            }

            MouseArea {
                id: recMouse
                anchors.fill: parent
                hoverEnabled: true
                onEntered: rbRoot.hovered()
                onClicked: rbRoot.clicked()
            }
        }
    }

    component StopRecordingButton: Item {
        id: srbRoot
        property bool isSelected: false
        property real fontScale: 1.0
        property var shellRoot: null
        property real s: 1.0
        signal clicked()
        signal hovered()

        width: 254 * s
        height: 42 * s

        Rectangle {
            id: srbBg
            anchors.fill: parent
            radius: 4 * s

            color: (stopMouse.containsMouse || srbRoot.isSelected)
                ? Qt.rgba(1.0, 0.22, 0.22, 0.26)
                : Qt.rgba(1.0, 0.22, 0.22, 0.14)

            border.color: (stopMouse.containsMouse || srbRoot.isSelected)
                ? Qt.rgba(1.0, 0.35, 0.35, 0.9)
                : Qt.rgba(1.0, 0.35, 0.35, 0.5)
            border.width: (stopMouse.containsMouse || srbRoot.isSelected) ? 1.5 : 1

            Behavior on color { ColorAnimation { duration: 120 } }
            Behavior on border.color { ColorAnimation { duration: 120 } }

            scale: (stopMouse.containsMouse || srbRoot.isSelected) ? 1.02 : 1.0
            Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12 * s
                anchors.rightMargin: 10 * s
                spacing: 10 * s

                // Pulsing red recording dot
                Rectangle {
                    id: pulseDot
                    width: 9 * s; height: 9 * s; radius: 4.5 * s
                    color: "#FF3B30"
                    SequentialAnimation on opacity {
                        running: rootWindow.show && rootWindow.isRecording
                        loops: Animation.Infinite
                        NumberAnimation { from: 1.0; to: 0.3; duration: 600; easing.type: Easing.InOutQuad }
                        NumberAnimation { from: 0.3; to: 1.0; duration: 600; easing.type: Easing.InOutQuad }
                    }
                }

                Text {
                    text: "󰓛"
                    color: "#FF453A"
                    font.family: shellRoot ? shellRoot.iconFontFamily : "sans-serif"
                    font.pixelSize: 15 * fontScale
                }

                Column {
                    Layout.fillWidth: true
                    spacing: 1
                    Text {
                        text: "Stop Recording"
                        color: "#FF453A"
                        font.family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                        font.pixelSize: 9.5 * fontScale
                        font.bold: true
                    }
                    Text {
                        text: "Recording active • " + (shellRoot ? shellRoot.recordingTime : "0:00")
                        color: Qt.rgba(1, 1, 1, 0.75)
                        font.family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                        font.pixelSize: 7.5 * fontScale
                    }
                }

                Rectangle {
                    width: 44 * s; height: 20 * s; radius: 4 * s
                    color: (stopMouse.containsMouse || srbRoot.isSelected) ? "#FF453A" : Qt.rgba(1, 0.27, 0.23, 0.3)
                    border.color: Qt.rgba(1, 0.3, 0.3, 0.6); border.width: 1

                    Behavior on color { ColorAnimation { duration: 100 } }

                    Text {
                        anchors.centerIn: parent
                        text: "STOP"
                        color: (stopMouse.containsMouse || srbRoot.isSelected) ? "white" : "#FF453A"
                        font.family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                        font.pixelSize: 7.5 * fontScale
                        font.bold: true
                    }
                }
            }

            MouseArea {
                id: stopMouse
                anchors.fill: parent
                hoverEnabled: true
                onEntered: srbRoot.hovered()
                onClicked: srbRoot.clicked()
            }
        }
    }
}
