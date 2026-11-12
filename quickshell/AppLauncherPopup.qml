import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io

PanelWindow {
    id: rootWindow

    property bool show: false
    property var shellRoot
    readonly property real scaleFactor: shellRoot ? shellRoot.scaleFactor : 1.0
    readonly property real fontScale: scaleFactor * (shellRoot ? shellRoot.fontSizeMultiplier : 1.0)

    WlrLayershell.keyboardFocus: show ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    WlrLayershell.namespace: "quickshell_applauncher"

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    exclusionMode: ExclusionMode.Ignore
    visible: show || isClosing
    color: "transparent"

    property var allApps: []

    Process {
        id: appsProcess
        command: ["python3", "/home/krishna/dotfiles/quickshell/scripts/get_apps.py"]
        running: false
        property var tempApps: []
        stdout: SplitParser {
            onRead: data => {
                var line = data.trim();
                if (line === "") return;
                try {
                    var obj = JSON.parse(line);
                    appsProcess.tempApps.push(obj);
                } catch(e) {}
            }
        }
        onRunningChanged: {
            if (running) {
                tempApps = [];
            } else {
                rootWindow.allApps = tempApps;
                rootWindow.filterApps();
            }
        }
    }

    // Pre-load on startup so icons are cached before first open
    Component.onCompleted: {
        appsProcess.running = true;
    }

    Process {
        id: launchProcess
        command: []
    }

    Process {
        id: pRecordLaunch
        command: []
    }

    function filterApps() {
        appsModel.clear();
        var q = searchField.text.toLowerCase().trim();
        for (var i = 0; i < allApps.length; i++) {
            var app = allApps[i];
            if (!q || app.name.toLowerCase().indexOf(q) !== -1 || (app.description && app.description.toLowerCase().indexOf(q) !== -1) || app.id.toLowerCase().indexOf(q) !== -1) {
                appsModel.append(app);
            }
        }
        appsGridView.currentIndex = 0;
    }

    function launchApp(appId) {
        if (!appId) return;
        pRecordLaunch.command = ["python3", "/home/krishna/dotfiles/quickshell/scripts/get_apps.py", "--record", appId];
        pRecordLaunch.running = true;

        var cmd = "systemd-run --user --scope gtk-launch " + appId;
        if (typeof Hyprland !== "undefined" && Hyprland.dispatch) {
            Hyprland.dispatch("hl.dsp.exec_cmd(\"" + cmd + "\")");
        } else {
            launchProcess.command = ["hyprctl", "dispatch", "hl.dsp.exec_cmd(\"" + cmd + "\")"];
            launchProcess.running = true;
        }
        rootWindow.show = false;
    }

    function launchCurrent() {
        if (appsGridView.currentIndex >= 0 && appsGridView.currentIndex < appsModel.count) {
            launchApp(appsModel.get(appsGridView.currentIndex).id);
        }
    }

    ListModel {
        id: appsModel
    }

    property bool isClosing: false
    property real savedCloseTarget: 120
    property bool suppressOpenAnimation: false

    onShowChanged: {
        if (show) {
            isClosing = false;
            suppressOpenAnimation = true;
            snapResetTimer.start();
            savedCloseTarget = Qt.binding(function () {
                return shellRoot ? shellRoot.closedNotchWidth : 120;
            });
            searchField.text = "";
            searchField.forceActiveFocus();
            // If apps already cached, show them immediately
            if (allApps.length > 0) {
                filterApps();
            }
            // Always refresh app list in background
            if (!appsProcess.running) {
                appsProcess.running = true;
            }
        } else {
            savedCloseTarget = shellRoot ? shellRoot.closedNotchWidth : 120;
            isClosing = true;
        }
    }

    Timer {
        id: snapResetTimer
        interval: 32
        repeat: false
        onTriggered: rootWindow.suppressOpenAnimation = false
    }

    Item {
        id: popupContent
        anchors.fill: parent
        focus: true

        Keys.onEscapePressed: {
            rootWindow.show = false;
        }

        MouseArea {
            anchors.fill: parent
            enabled: rootWindow.show
            onClicked: rootWindow.show = false
        }

        Rectangle {
            id: animRect
            anchors.top: parent.top
            anchors.topMargin: ((shellRoot && shellRoot.topHuggingStyle) ? 0 : 4) * scaleFactor
            anchors.horizontalCenter: parent.horizontalCenter

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
            }

            width: rootWindow.suppressOpenAnimation ? Math.round(32 * scaleFactor) : (rootWindow.show ? Math.round(520 * scaleFactor) : (rootWindow.isClosing ? Math.round(32 * scaleFactor) : rootWindow.savedCloseTarget))
            height: rootWindow.suppressOpenAnimation ? Math.round(32 * scaleFactor) : (rootWindow.show ? Math.round(440 * scaleFactor) : (rootWindow.isClosing ? Math.round(32 * scaleFactor) : Math.round(32 * scaleFactor)))
            radius: Math.round(4 * scaleFactor)

            function checkCloseFinished() {
                if (!rootWindow.show && rootWindow.isClosing) {
                    var sf = rootWindow.scaleFactor;
                    var targetWidth = Math.round(32 * sf);
                    var targetHeight = Math.round(32 * sf);
                    if (Math.abs(width - targetWidth) < 1.5 && Math.abs(height - targetHeight) < 1.5) {
                        rootWindow.isClosing = false;
                    }
                }
            }
            onWidthChanged: checkCloseFinished()
            onHeightChanged: checkCloseFinished()

            Behavior on width { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
            Behavior on height { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
            Behavior on radius { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

            color: "transparent"
            border.color: Qt.rgba(1, 1, 1, 0.08)
            border.width: 1

            // SurfaceCard Base (Option B, Zero Shader Overhead)
            SurfaceCard {
                id: calGlassCard
                anchors.fill: parent
                radius: animRect.radius
                contentPadding: 0
            }

            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                border.width: parent.border.width
                border.color: parent.border.color
                color: "transparent"
            }

            Rectangle {
                anchors.top: parent.top
                anchors.topMargin: 1
                anchors.left: parent.left
                anchors.leftMargin: parent.radius
                anchors.right: parent.right
                anchors.rightMargin: parent.radius
                height: 1
                color: Qt.rgba(1, 1, 1, 0.12)
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14 * scaleFactor
                spacing: 12 * scaleFactor

                opacity: rootWindow.show ? 1.0 : 0.0
                scale: rootWindow.show ? 1.0 : 0.9

                Behavior on opacity {
                    SequentialAnimation {
                        PauseAnimation { duration: (shellRoot && shellRoot.batteryMode) ? 0 : (rootWindow.show ? 120 : 0) }
                        NumberAnimation { duration: (shellRoot && shellRoot.batteryMode) ? 150 : (rootWindow.show ? 220 : 80); easing.type: rootWindow.show ? Easing.OutQuad : Easing.InQuad }
                    }
                }
                Behavior on scale {
                    SequentialAnimation {
                        PauseAnimation { duration: (shellRoot && shellRoot.batteryMode) ? 0 : (rootWindow.show ? 120 : 0) }
                        NumberAnimation { duration: (shellRoot && shellRoot.batteryMode) ? 150 : (rootWindow.show ? 220 : 80); easing.type: rootWindow.show ? Easing.OutBack : Easing.InQuad }
                    }
                }

                // Search Bar (GPU Optical Ingress Chamber)
                IngressedChamber {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.round(40 * scaleFactor)
                    radius: Math.round(14 * scaleFactor)

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Math.round(14 * scaleFactor)
                        anchors.rightMargin: Math.round(14 * scaleFactor)
                        spacing: Math.round(10 * scaleFactor)

                        Text {
                            text: "\uE8B6"
                            color: shellRoot ? shellRoot.colFgSecondary : Qt.rgba(1, 1, 1, 0.5)
                            font.pixelSize: 16 * fontScale
                            font.family: shellRoot ? shellRoot.iconFontFamily : "sans-serif"
                        }

                        TextField {
                            id: searchField
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            color: shellRoot ? shellRoot.colFgPrimary : "white"
                            font.pixelSize: 13 * fontScale
                            font.family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                            background: Item {}
                            placeholderText: "Search apps..."
                            placeholderTextColor: shellRoot ? shellRoot.colMuted : Qt.rgba(1, 1, 1, 0.38)
                            onTextChanged: rootWindow.filterApps()
                            
                            Keys.onDownPressed: {
                                var cols = Math.max(1, Math.floor(appsGridView.width / appsGridView.cellWidth));
                                if (appsGridView.currentIndex + cols < appsModel.count) {
                                    appsGridView.currentIndex += cols;
                                }
                            }
                            Keys.onUpPressed: {
                                var cols = Math.max(1, Math.floor(appsGridView.width / appsGridView.cellWidth));
                                if (appsGridView.currentIndex - cols >= 0) {
                                    appsGridView.currentIndex -= cols;
                                }
                            }
                            Keys.onRightPressed: {
                                if (appsGridView.currentIndex < appsModel.count - 1) {
                                    appsGridView.currentIndex++;
                                }
                            }
                            Keys.onLeftPressed: {
                                if (appsGridView.currentIndex > 0) {
                                    appsGridView.currentIndex--;
                                }
                            }
                            Keys.onEscapePressed: rootWindow.show = false
                            Keys.onEnterPressed: rootWindow.launchCurrent()
                            Keys.onReturnPressed: rootWindow.launchCurrent()
                        }

                        Text {
                            text: appsModel.count + " apps"
                            color: shellRoot ? shellRoot.colFgSecondary : Qt.rgba(1, 1, 1, 0.3)
                            font.pixelSize: 11 * fontScale
                            font.family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                        }
                    }
                }

                // Grid View Container
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    GridView {
                        id: appsGridView
                        anchors.fill: parent
                        cellWidth: Math.floor(width / Math.max(1, Math.floor(width / (88 * scaleFactor))))
                        cellHeight: 92 * scaleFactor
                        clip: true
                        model: appsModel
                        focus: true

                        delegate: Item {
                            id: delegateItem
                            width: appsGridView.cellWidth
                            height: appsGridView.cellHeight

                            readonly property bool isSelected: appsGridView.currentIndex === index

                            opacity: 0.0
                            scale: 0.82

                            ParallelAnimation {
                                id: appearAnim
                                NumberAnimation {
                                    target: delegateItem
                                    property: "opacity"
                                    from: 0.0
                                    to: 1.0
                                    duration: (shellRoot && shellRoot.batteryMode) ? 40 : 160
                                    easing.type: Easing.OutCubic
                                }
                                NumberAnimation {
                                    target: delegateItem
                                    property: "scale"
                                    from: 0.82
                                    to: 1.0
                                    duration: (shellRoot && shellRoot.batteryMode) ? 40 : 200
                                    easing.type: Easing.OutBack
                                }
                            }

                            Timer {
                                id: staggerTimer
                                interval: (shellRoot && shellRoot.batteryMode) ? 0 : Math.min(index * 14, 280)
                                repeat: false
                                running: rootWindow.show
                                onTriggered: appearAnim.start()
                            }

                            Connections {
                                target: rootWindow
                                function onShowChanged() {
                                    if (rootWindow.show) {
                                        delegateItem.opacity = 0.0;
                                        delegateItem.scale = 0.82;
                                        staggerTimer.restart();
                                    } else {
                                        appearAnim.stop();
                                        staggerTimer.stop();
                                        delegateItem.opacity = 0.0;
                                        delegateItem.scale = 0.82;
                                    }
                                }
                            }

                            Component.onCompleted: {
                                if (rootWindow.show) {
                                    staggerTimer.restart();
                                }
                            }

                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: 4 * scaleFactor
                                radius: 10 * scaleFactor
                                color: isSelected
                                    ? (shellRoot ? shellRoot.colAccent : Qt.rgba(0.0, 0.48, 1.0, 0.75))
                                    : (mouseArea.containsMouse ? ((shellRoot && shellRoot.isPearlMode) ? Qt.rgba(0, 0, 0, 0.06) : Qt.rgba(1, 1, 1, 0.08)) : "transparent")
                                border.color: isSelected ? Qt.rgba(1, 1, 1, 0.3) : "transparent"
                                border.width: 1
                                scale: isSelected ? 1.03 : (mouseArea.containsMouse ? 1.02 : 1.0)

                                Behavior on color { ColorAnimation { duration: 90 } }
                                Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }

                                ColumnLayout {
                                    anchors.centerIn: parent
                                    spacing: 6 * scaleFactor
                                    width: parent.width - 8 * scaleFactor

                                    Image {
                                        source: model.icon || ""
                                        Layout.alignment: Qt.AlignHCenter
                                        Layout.preferredWidth: 42 * scaleFactor
                                        Layout.preferredHeight: 42 * scaleFactor
                                        sourceSize: Qt.size(56 * scaleFactor, 56 * scaleFactor)
                                        smooth: true
                                        mipmap: true
                                        fillMode: Image.PreserveAspectFit
                                        // Synchronous load: icons are pre-cached at startup,
                                        // so delegates appear fully-formed before stagger reveals them
                                        asynchronous: false
                                        cache: true
                                    }

                                    Text {
                                        text: model.name
                                        color: isSelected ? "#ffffff" : (shellRoot ? shellRoot.colFgPrimary : Qt.rgba(1, 1, 1, 0.9))
                                        Layout.fillWidth: true
                                        horizontalAlignment: Text.AlignHCenter
                                        font.pixelSize: 11 * fontScale
                                        font.weight: isSelected ? Font.DemiBold : Font.Normal
                                        font.family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                                        elide: Text.ElideRight
                                    }
                                }
                            }

                            MouseArea {
                                id: mouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    appsGridView.currentIndex = index;
                                    rootWindow.launchCurrent();
                                }
                            }
                        }
                    }

                    // Empty search state
                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 8 * scaleFactor
                        visible: appsModel.count === 0 && searchField.text.trim() !== ""
                        opacity: 0.75

                        Text {
                            text: "󰍉"
                            font.family: shellRoot ? shellRoot.iconFontFamily : "sans-serif"
                            font.pixelSize: 36 * fontScale
                            color: shellRoot ? shellRoot.colFgSecondary : Qt.rgba(1, 1, 1, 0.4)
                            Layout.alignment: Qt.AlignHCenter
                        }
                        Text {
                            text: "No applications found"
                            font.family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                            font.pixelSize: 14 * fontScale
                            font.weight: Font.Medium
                            color: shellRoot ? shellRoot.colFgPrimary : "white"
                            Layout.alignment: Qt.AlignHCenter
                        }
                        Text {
                            text: "No apps match \"" + searchField.text.trim() + "\""
                            font.family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                            font.pixelSize: 11 * fontScale
                            color: shellRoot ? shellRoot.colFgSecondary : Qt.rgba(1, 1, 1, 0.4)
                            Layout.alignment: Qt.AlignHCenter
                        }
                    }
                }
            }
        }
    }
}
