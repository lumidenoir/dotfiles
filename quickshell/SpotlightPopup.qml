import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import "Singletons"

PanelWindow {
    id: rootWindow

    property bool show: false
    property var shellRoot
    readonly property real scaleFactor: shellRoot ? shellRoot.scaleFactor : 1.0
    readonly property real fontScale: scaleFactor * (shellRoot ? shellRoot.fontSizeMultiplier : 1.0)

    WlrLayershell.keyboardFocus: show ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    WlrLayershell.namespace: "quickshell_spotlight"

    property bool suppressDebounce: false

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    exclusionMode: ExclusionMode.Ignore
    visible: show || isClosing
    color: "transparent"

    Process {
        id: queryProcess
        command: []
        running: false
        property var tempResults: []
        stdout: SplitParser {
            onRead: data => {
                var line = data.trim();
                if (!line) return;
                try {
                    var obj = JSON.parse(line);
                    queryProcess.tempResults.push(obj);
                } catch(e) {}
            }
        }
        onRunningChanged: {
            if (running) {
                tempResults = [];
            } else {
                resultsModel.clear();
                for (var i = 0; i < tempResults.length; i++) {
                    resultsModel.append(tempResults[i]);
                }
                resultsListView.currentIndex = 0;
            }
        }
    }

    Process {
        id: execProcess
        command: []
    }

    Timer {
        id: debounceTimer
        interval: 60
        repeat: false
        onTriggered: {
            var q = searchField.text.trim();
            if (queryProcess.running) queryProcess.running = false;
            // Always query backend — empty query returns initial quick actions
            queryProcess.command = ["python3", "/home/krishna/dotfiles/quickshell/scripts/spotlight_backend.py", "--query", q];
            queryProcess.running = true;
        }
    }

    function executeCurrent() {
        if (resultsListView.currentIndex >= 0 && resultsListView.currentIndex < resultsModel.count) {
            var item = resultsModel.get(resultsListView.currentIndex);
            if (item.action_type === "suggest") {
                suppressDebounce = true;
                searchField.text = item.action_payload;
                searchField.cursorPosition = searchField.text.length;
                suppressDebounce = false;
                debounceTimer.restart();
                return;
            }
            if (execProcess.running) execProcess.running = false;
            execProcess.command = ["python3", "/home/krishna/dotfiles/quickshell/scripts/spotlight_backend.py", "--exec", item.action_type, item.action_payload];
            execProcess.running = true;
            rootWindow.show = false;
            return;
        }
        if (resultsModel.count === 0 && searchField.text.trim() !== "") {
            var url = "https://duckduckgo.com/?q=" + encodeURIComponent(searchField.text.trim());
            var cmd = "systemd-run --user --scope xdg-open \"" + url + "\"";
            if (typeof Hyprland !== "undefined" && Hyprland.dispatch) {
                Hyprland.dispatch("hl.dsp.exec_cmd(\"" + cmd + "\")");
            } else {
                if (execProcess.running) execProcess.running = false;
                execProcess.command = ["hyprctl", "dispatch", "hl.dsp.exec_cmd(\"" + cmd + "\")"];
                execProcess.running = true;
            }
            rootWindow.show = false;
        }
    }

    ListModel {
        id: resultsModel
    }

    property bool isClosing: false
    property real savedCloseTarget: 120
    property bool suppressOpenAnimation: false

    onShowChanged: {
        if (show) {
            CharacterBus.react("lookAround");
            isClosing = false;
            suppressOpenAnimation = true;
            snapResetTimer.start();
            savedCloseTarget = Qt.binding(function () {
                return shellRoot ? shellRoot.closedNotchWidth : 120;
            });
            suppressDebounce = true;
            searchField.text = "";
            suppressDebounce = false;
            resultsModel.clear();
            debounceTimer.stop();
            searchField.forceActiveFocus();
            // Load initial quick-action menu entries immediately
            initialMenuTimer.restart();
        } else {
            debounceTimer.stop();
            savedCloseTarget = shellRoot ? shellRoot.closedNotchWidth : 120;
            isClosing = true;
        }
    }

    Timer {
        id: initialMenuTimer
        interval: 80
        repeat: false
        onTriggered: {
            // Only load initial menu if search is still empty
            if (searchField.text.trim() === "") {
                queryProcess.command = ["python3", "/home/krishna/dotfiles/quickshell/scripts/spotlight_backend.py", "--query", ""];
                queryProcess.running = true;
            }
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

        Keys.onEscapePressed: rootWindow.show = false

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

            width: rootWindow.suppressOpenAnimation ? Math.round(32 * scaleFactor) : (rootWindow.show ? Math.round(640 * scaleFactor) : (rootWindow.isClosing ? Math.round(32 * scaleFactor) : rootWindow.savedCloseTarget))
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
                spacing: 10 * scaleFactor

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

                // Spotlight Search Input Bar (GPU Optical Ingress Chamber)
                IngressedChamber {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.round(44 * scaleFactor)
                    radius: Math.round(14 * scaleFactor)

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Math.round(14 * scaleFactor)
                        anchors.rightMargin: Math.round(14 * scaleFactor)
                        spacing: Math.round(10 * scaleFactor)

                        Text {
                            text: "\uE8B6"
                            color: shellRoot ? shellRoot.colFgSecondary : Qt.rgba(1, 1, 1, 0.5)
                            font.pixelSize: 17 * fontScale
                            font.family: shellRoot ? shellRoot.iconFontFamily : "sans-serif"
                        }

                        TextField {
                            id: searchField
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            color: shellRoot ? shellRoot.colFgPrimary : "white"
                            font.pixelSize: 14 * fontScale
                            font.family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                            background: Item {}
                            placeholderText: "Spotlight Search (apps, files, web, math, emojis)..."
                            placeholderTextColor: shellRoot ? shellRoot.colMuted : Qt.rgba(1, 1, 1, 0.38)
                            onTextChanged: {
                                CharacterBus.typed();
                                if (rootWindow.suppressDebounce) return;
                                // Always debounce — backend handles empty query as quick-action menu
                                debounceTimer.restart();
                            }
                            
                            Keys.onDownPressed: {
                                if (resultsListView.currentIndex < resultsModel.count - 1) {
                                    resultsListView.currentIndex++;
                                    resultsListView.positionViewAtIndex(resultsListView.currentIndex, ListView.Contain);
                                }
                            }
                            Keys.onUpPressed: {
                                if (resultsListView.currentIndex > 0) {
                                    resultsListView.currentIndex--;
                                    resultsListView.positionViewAtIndex(resultsListView.currentIndex, ListView.Contain);
                                }
                            }
                            Keys.onEscapePressed: rootWindow.show = false
                            Keys.onEnterPressed: rootWindow.executeCurrent()
                            Keys.onReturnPressed: rootWindow.executeCurrent()
                        }

                        Text {
                            text: resultsModel.count > 0 ? (resultsModel.count + " results") : ""
                            color: Qt.rgba(1, 1, 1, 0.3)
                            font.pixelSize: 11 * fontScale
                            font.family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                        }
                    }
                }

                // Results Container & Overlay
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    // Results List View
                    ListView {
                        id: resultsListView
                        anchors.fill: parent
                        clip: true
                        model: resultsModel
                        spacing: 3 * scaleFactor
                        boundsBehavior: Flickable.StopAtBounds

                        Keys.onDownPressed: {
                            if (currentIndex < count - 1) {
                                currentIndex++;
                                positionViewAtIndex(currentIndex, ListView.Contain);
                            }
                        }
                        Keys.onUpPressed: {
                            if (currentIndex > 0) {
                                currentIndex--;
                                positionViewAtIndex(currentIndex, ListView.Contain);
                            } else {
                                searchField.forceActiveFocus();
                            }
                        }
                        Keys.onEnterPressed: rootWindow.executeCurrent()
                        Keys.onReturnPressed: rootWindow.executeCurrent()
                        Keys.onEscapePressed: rootWindow.show = false

                        delegate: Item {
                            width: resultsListView.width
                            height: 44 * scaleFactor

                            readonly property bool isSelected: resultsListView.currentIndex === index

                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: 1 * scaleFactor
                                color: isSelected
                                    ? (shellRoot ? shellRoot.colAccent : Qt.rgba(0.0, 0.48, 1.0, 0.75))
                                    : (itemMouseArea.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent")
                                radius: 9 * scaleFactor
                                border.color: isSelected ? Qt.rgba(1, 1, 1, 0.25) : "transparent"
                                border.width: 1

                                Behavior on color { ColorAnimation { duration: 80 } }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10 * scaleFactor
                                    anchors.rightMargin: 12 * scaleFactor
                                    spacing: 10 * scaleFactor

                                    // Icon
                                    Item {
                                        Layout.preferredWidth: 28 * scaleFactor
                                        Layout.preferredHeight: 28 * scaleFactor

                                        Image {
                                            anchors.fill: parent
                                            source: (model.icon && model.icon.indexOf("file://") === 0) ? model.icon : ""
                                            visible: source != ""
                                            smooth: true
                                            mipmap: true
                                            fillMode: Image.PreserveAspectFit
                                        }

                                        Text {
                                            anchors.centerIn: parent
                                            text: (model.icon && model.icon.indexOf("file://") !== 0) ? model.icon : "󰌌"
                                            color: isSelected ? "#ffffff" : (shellRoot ? shellRoot.colAccent : "#0A84FF")
                                            font.pixelSize: (model.category === "Emojis") ? 18 * fontScale : 15 * fontScale
                                            font.family: (model.category === "Emojis") ? (shellRoot ? shellRoot.fontFamily : "sans-serif") : (shellRoot ? shellRoot.iconFontFamily : "sans-serif")
                                            visible: !((model.icon && model.icon.indexOf("file://") === 0))
                                        }
                                    }

                                    // Title & Subtitle
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1 * scaleFactor

                                        Text {
                                            text: model.title || ""
                                            color: isSelected ? "#ffffff" : (shellRoot ? shellRoot.colFgPrimary : "white")
                                            Layout.fillWidth: true
                                            font.pixelSize: 13 * fontScale
                                            font.weight: isSelected ? Font.DemiBold : Font.Normal
                                            font.family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            text: model.subtitle || ""
                                            color: isSelected ? Qt.rgba(1, 1, 1, 0.78) : (shellRoot ? shellRoot.colFgSecondary : Qt.rgba(1, 1, 1, 0.42))
                                            Layout.fillWidth: true
                                            font.pixelSize: 10 * fontScale
                                            font.family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                                            elide: Text.ElideRight
                                        }
                                    }

                                    // Category Tag
                                    Rectangle {
                                        Layout.preferredHeight: 18 * scaleFactor
                                        implicitWidth: catLabel.implicitWidth + 10 * scaleFactor
                                        radius: 5 * scaleFactor
                                        color: isSelected ? Qt.rgba(1, 1, 1, 0.2) : Qt.rgba(1, 1, 1, 0.08)

                                        Text {
                                            id: catLabel
                                            anchors.centerIn: parent
                                            text: model.category || ""
                                            color: isSelected ? "#ffffff" : Qt.rgba(1, 1, 1, 0.6)
                                            font.pixelSize: 9 * fontScale
                                            font.weight: Font.Medium
                                            font.family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                                        }
                                    }

                                    Text {
                                        visible: isSelected
                                        text: "\u21B5"
                                        color: Qt.rgba(1, 1, 1, 0.8)
                                        font.pixelSize: 13 * fontScale
                                        font.family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                                    }
                                }

                                MouseArea {
                                    id: itemMouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: {
                                        resultsListView.currentIndex = index;
                                        rootWindow.executeCurrent();
                                    }
                                }
                            }
                        }
                    }

                    // Loading State Hint (shown only when query is empty AND no results yet loaded)
                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 8 * scaleFactor
                        visible: searchField.text.trim() === "" && resultsModel.count === 0 && !queryProcess.running
                        opacity: 0.55

                        Text {
                            text: "\uE8B6"
                            font.family: shellRoot ? shellRoot.iconFontFamily : "sans-serif"
                            font.pixelSize: 32 * fontScale
                            color: shellRoot ? shellRoot.colFgSecondary : Qt.rgba(1, 1, 1, 0.4)
                            Layout.alignment: Qt.AlignHCenter
                        }
                        Text {
                            text: "Type to search apps, files, math, emojis..."
                            font.family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                            font.pixelSize: 13 * fontScale
                            color: shellRoot ? shellRoot.colFgSecondary : Qt.rgba(1, 1, 1, 0.4)
                            Layout.alignment: Qt.AlignHCenter
                        }
                    }

                    // No Results State (when query entered but nothing matches and query process finished)
                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 6 * scaleFactor
                        visible: searchField.text.trim() !== "" && resultsModel.count === 0 && !queryProcess.running
                        opacity: 0.75

                        Text {
                            text: "󰍉"
                            font.family: shellRoot ? shellRoot.iconFontFamily : "sans-serif"
                            font.pixelSize: 32 * fontScale
                            color: shellRoot ? shellRoot.colFgSecondary : Qt.rgba(1, 1, 1, 0.4)
                            Layout.alignment: Qt.AlignHCenter
                        }
                        Text {
                            text: "No results for \"" + searchField.text.trim() + "\""
                            font.family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                            font.pixelSize: 13 * fontScale
                            font.weight: Font.Medium
                            color: shellRoot ? shellRoot.colFgPrimary : "white"
                            Layout.alignment: Qt.AlignHCenter
                        }
                        Text {
                            text: "Press Enter to search the web"
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
