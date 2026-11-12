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

    WlrLayershell.keyboardFocus: show ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    WlrLayershell.namespace: "quickshell_widgets"

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    exclusionMode: ExclusionMode.Ignore
    visible: show || isClosing
    color: "transparent"

    property var allClips: []

    Process {
        id: clipProcess
        command: ["python3", "/home/krishna/dotfiles/quickshell/scripts/clipboard_manager.py"]
        running: false
        property var tempClips: []
        stdout: SplitParser {
            onRead: data => {
                var line = data.trim();
                if (!line) return;
                try {
                    var obj = JSON.parse(line);
                    clipProcess.tempClips.push(obj);
                } catch(e) {}
            }
        }
        onRunningChanged: {
            if (running) {
                tempClips = [];
            } else {
                rootWindow.allClips = tempClips;
                rootWindow.filterClips();
            }
        }
    }

    Process {
        id: actionProcess
        command: []
    }

    function filterClips() {
        clipsModel.clear();
        var q = searchField.text.toLowerCase().trim();
        for (var i = 0; i < allClips.length; i++) {
            var item = allClips[i];
            if (!q || item.preview.toLowerCase().indexOf(q) !== -1 || item.type.toLowerCase().indexOf(q) !== -1) {
                clipsModel.append(item);
            }
        }
        clipsListView.currentIndex = 0;
    }

    function copyClip(clipId) {
        if (!clipId) return;
        actionProcess.command = ["python3", "/home/krishna/dotfiles/quickshell/scripts/clipboard_manager.py", "--copy", clipId];
        actionProcess.running = true;
        rootWindow.show = false;
    }

    function deleteClip(clipId, index) {
        if (!clipId) return;
        actionProcess.command = ["python3", "/home/krishna/dotfiles/quickshell/scripts/clipboard_manager.py", "--delete", clipId];
        actionProcess.running = true;
        if (index >= 0 && index < clipsModel.count) {
            clipsModel.remove(index);
        }
    }

    function clearAll() {
        actionProcess.command = ["python3", "/home/krishna/dotfiles/quickshell/scripts/clipboard_manager.py", "--clear"];
        actionProcess.running = true;
        clipsModel.clear();
        allClips = [];
    }

    function launchCurrent() {
        if (clipsListView.currentIndex >= 0 && clipsListView.currentIndex < clipsModel.count) {
            copyClip(clipsModel.get(clipsListView.currentIndex).id);
        }
    }

    ListModel {
        id: clipsModel
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
            rootWindow.filterClips();
            if (clipProcess.running) clipProcess.running = false;
            clipProcess.running = true;
            searchField.forceActiveFocus();
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

            width: rootWindow.suppressOpenAnimation ? Math.round(32 * scaleFactor) : (rootWindow.show ? Math.round(620 * scaleFactor) : (rootWindow.isClosing ? Math.round(32 * scaleFactor) : rootWindow.savedCloseTarget))
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

                // Header Search Ingressed Chamber
                IngressedChamber {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.round(42 * scaleFactor)
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
                            placeholderText: "Search clipboard history..."
                            placeholderTextColor: shellRoot ? shellRoot.colMuted : Qt.rgba(1, 1, 1, 0.38)
                            onTextChanged: rootWindow.filterClips()
                            
                            Keys.onDownPressed: {
                                if (clipsListView.currentIndex < clipsModel.count - 1) {
                                    clipsListView.currentIndex++;
                                    clipsListView.positionViewAtIndex(clipsListView.currentIndex, ListView.Contain);
                                }
                            }
                            Keys.onUpPressed: {
                                if (clipsListView.currentIndex > 0) {
                                    clipsListView.currentIndex--;
                                    clipsListView.positionViewAtIndex(clipsListView.currentIndex, ListView.Contain);
                                }
                            }
                            Keys.onDeletePressed: {
                                if (clipsListView.currentIndex >= 0 && clipsListView.currentIndex < clipsModel.count) {
                                    rootWindow.deleteClip(clipsModel.get(clipsListView.currentIndex).id, clipsListView.currentIndex);
                                }
                            }
                            Keys.onEscapePressed: rootWindow.show = false
                            Keys.onEnterPressed: rootWindow.launchCurrent()
                            Keys.onReturnPressed: rootWindow.launchCurrent()
                        }

                        Text {
                            text: clipsModel.count + " clips"
                            color: shellRoot ? shellRoot.colFgSecondary : Qt.rgba(1, 1, 1, 0.3)
                            font.pixelSize: 11 * fontScale
                            font.family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                        }

                        // Clear All Button
                        MouseArea {
                            Layout.preferredWidth: 24 * scaleFactor
                            Layout.preferredHeight: 24 * scaleFactor
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            visible: clipsModel.count > 0
                            onClicked: rootWindow.clearAll()

                            Rectangle {
                                anchors.fill: parent
                                radius: 6 * scaleFactor
                                color: parent.containsMouse ? Qt.rgba(1, 0.3, 0.3, 0.2) : Qt.rgba(1, 1, 1, 0.08)
                                border.color: parent.containsMouse ? Qt.rgba(1, 0.3, 0.3, 0.4) : Qt.rgba(1, 1, 1, 0.1)
                                border.width: 1

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰃢"
                                    color: parent.parent.containsMouse ? "#ff453a" : Qt.rgba(1, 1, 1, 0.6)
                                    font.pixelSize: 12 * fontScale
                                    font.family: shellRoot ? shellRoot.iconFontFamily : "sans-serif"
                                }
                            }
                        }
                    }
                }

                // Vertical List of Clipboard Items
                ListView {
                    id: clipsListView
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: clipsModel
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
                    Keys.onDeletePressed: {
                        if (currentIndex >= 0 && currentIndex < count) {
                            rootWindow.deleteClip(clipsModel.get(currentIndex).id, currentIndex);
                        }
                    }
                    Keys.onEnterPressed: rootWindow.launchCurrent()
                    Keys.onReturnPressed: rootWindow.launchCurrent()
                    Keys.onEscapePressed: rootWindow.show = false

                    // Empty State
                    Text {
                        anchors.centerIn: parent
                        text: "Clipboard is empty"
                        color: Qt.rgba(1, 1, 1, 0.35)
                        font.pixelSize: 13 * fontScale
                        font.family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                        visible: clipsModel.count === 0
                    }

                    delegate: Item {
                        width: clipsListView.width
                        height: 44 * scaleFactor

                        readonly property bool isSelected: clipsListView.currentIndex === index

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
                                anchors.rightMargin: 10 * scaleFactor
                                spacing: 10 * scaleFactor

                                // Type Badge
                                Rectangle {
                                    Layout.preferredWidth: 26 * scaleFactor
                                    Layout.preferredHeight: 26 * scaleFactor
                                    radius: 6 * scaleFactor
                                    color: isSelected ? Qt.rgba(1, 1, 1, 0.2) : Qt.rgba(1, 1, 1, 0.08)

                                    Text {
                                        anchors.centerIn: parent
                                        text: model.type === "image" ? "󰋩" : (model.type === "url" ? "󰖟" : (model.type === "code" ? "󰅪" : "󰅍"))
                                        color: isSelected ? "#ffffff" : (model.type === "url" ? "#64D2FF" : (model.type === "code" ? "#FFD60A" : Qt.rgba(1, 1, 1, 0.7)))
                                        font.pixelSize: 13 * fontScale
                                        font.family: shellRoot ? shellRoot.iconFontFamily : "sans-serif"
                                    }
                                }

                                // Preview Content
                                Text {
                                    text: model.preview
                                    color: isSelected ? "#ffffff" : (shellRoot ? shellRoot.colFgPrimary : "white")
                                    Layout.fillWidth: true
                                    font.pixelSize: 12 * fontScale
                                    font.family: model.type === "code" ? "monospace" : (shellRoot ? shellRoot.fontFamily : "sans-serif")
                                    font.weight: isSelected ? Font.DemiBold : Font.Normal
                                    elide: Text.ElideRight
                                    maximumLineCount: 1
                                }

                                // Delete item button
                                MouseArea {
                                    Layout.preferredWidth: 22 * scaleFactor
                                    Layout.preferredHeight: 22 * scaleFactor
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: rootWindow.deleteClip(model.id, index)

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: 5 * scaleFactor
                                        color: parent.containsMouse ? Qt.rgba(1, 0.3, 0.3, 0.3) : "transparent"

                                        Text {
                                            anchors.centerIn: parent
                                            text: "✕"
                                            color: parent.parent.containsMouse ? "#ff453a" : (isSelected ? Qt.rgba(1, 1, 1, 0.7) : Qt.rgba(1, 1, 1, 0.3))
                                            font.pixelSize: 10 * fontScale
                                            font.weight: Font.Bold
                                        }
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
                                acceptedButtons: Qt.LeftButton
                                onClicked: {
                                    clipsListView.currentIndex = index;
                                    rootWindow.launchCurrent();
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
