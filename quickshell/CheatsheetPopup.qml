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
    visible: show || animRect.opacity > 0.01
    color: "transparent"

    property var allCategories: []
    property var displayCategories: []

    Process {
        id: parseProcess
        command: ["python3", "/home/krishna/dotfiles/quickshell/scripts/parse_keybindings.py"]
        running: false
        property var tempCategories: []
        stdout: SplitParser {
            onRead: data => {
                var line = data.trim();
                if (!line) return;
                try {
                    var obj = JSON.parse(line);
                    parseProcess.tempCategories.push(obj);
                } catch(e) {
                    console.log("[Cheatsheet] JSON Parse error on line:", e);
                }
            }
        }
        onRunningChanged: {
            if (running) {
                tempCategories = [];
            } else {
                rootWindow.allCategories = tempCategories;
                rootWindow.refreshModel();
            }
        }
    }

    function refreshModel() {
        var q = searchField.text.toLowerCase().trim();
        var result = [];

        for (var i = 0; i < allCategories.length; i++) {
            var cat = allCategories[i];
            var filteredItems = [];
            for (var j = 0; j < cat.items.length; j++) {
                var item = cat.items[j];
                var keysStr = item.keys.join(" ").toLowerCase();
                if (!q || item.desc.toLowerCase().indexOf(q) !== -1 || keysStr.indexOf(q) !== -1) {
                    filteredItems.push(item);
                }
            }
            if (filteredItems.length > 0) {
                result.push({
                    name: cat.name,
                    icon: cat.icon || "󰌌",
                    items: filteredItems
                });
            }
        }
        displayCategories = result;
    }

    onShowChanged: {
        if (show) {
            parseProcess.running = true;
            searchField.text = "";
            searchField.forceActiveFocus();
        } else {
        }
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

        // Floating Modal Card Centered on Screen
        Rectangle {
            id: animRect
            anchors.centerIn: parent
            width: Math.min(parent.width - 40 * scaleFactor, Math.round(920 * scaleFactor))
            height: Math.min(parent.height - 60 * scaleFactor, Math.round(620 * scaleFactor))
            radius: Math.round(4 * scaleFactor)
            color: "transparent"
            border.color: Qt.rgba(1, 1, 1, 0.12)
            border.width: 1

            opacity: rootWindow.show ? 1.0 : 0.0
            scale: rootWindow.show ? 1.0 : 0.94

            Behavior on opacity {
                NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
            }
            Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
            }

            // SurfaceCard Base (Option B, Zero Shader Overhead)
            SurfaceCard {
                anchors.fill: parent
                radius: animRect.radius
                contentPadding: 0
            }

            // Specular top highlight line
            Rectangle {
                anchors.top: parent.top
                anchors.topMargin: 1
                anchors.left: parent.left
                anchors.leftMargin: parent.radius
                anchors.right: parent.right
                anchors.rightMargin: parent.radius
                height: 1
                color: Qt.rgba(1, 1, 1, 0.15)
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 20 * scaleFactor
                spacing: 14 * scaleFactor

                // Header & Search Row
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 14 * scaleFactor

                    ColumnLayout {
                        spacing: 2 * scaleFactor

                        RowLayout {
                            spacing: 8 * scaleFactor
                            Text {
                                text: "⌨"
                                font.pixelSize: 18 * fontScale
                                color: shellRoot ? shellRoot.colAccent : "#0A84FF"
                            }
                            Text {
                                text: "Keyboard Shortcuts"
                                font.pixelSize: 17 * fontScale
                                font.weight: Font.DemiBold
                                color: "#ffffff"
                                font.family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                            }
                        }

                        Text {
                            text: "Hyprland Dynamic Cheatsheet"
                            font.pixelSize: 11 * fontScale
                            color: Qt.rgba(1, 1, 1, 0.45)
                            font.family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // Search Field
                    Rectangle {
                        Layout.preferredWidth: 260 * scaleFactor
                        height: 36 * scaleFactor
                        radius: Math.round(4 * scaleFactor)
                        color: Qt.rgba(1, 1, 1, 0.07)
                        border.color: Qt.rgba(1, 1, 1, 0.12)
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10 * scaleFactor
                            anchors.rightMargin: 10 * scaleFactor
                            spacing: 6 * scaleFactor

                            Text {
                                text: "\uE8B6"
                                color: Qt.rgba(1, 1, 1, 0.5)
                                font.pixelSize: 14 * fontScale
                                font.family: shellRoot ? shellRoot.iconFontFamily : "sans-serif"
                            }

                            TextField {
                                id: searchField
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                color: "white"
                                font.pixelSize: 12 * fontScale
                                font.family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                                background: Item {}
                                placeholderText: "Filter shortcuts..."
                                placeholderTextColor: Qt.rgba(1, 1, 1, 0.35)
                                onTextChanged: rootWindow.refreshModel()
                                Keys.onEscapePressed: rootWindow.show = false
                            }
                        }
                    }

                    // Close Button
                    MouseArea {
                        width: 28 * scaleFactor
                        height: 28 * scaleFactor
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: rootWindow.show = false

                        Rectangle {
                            anchors.fill: parent
                            radius: Math.round(4 * scaleFactor)
                            color: parent.containsMouse ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(1, 1, 1, 0.08)
                            border.color: parent.containsMouse ? Qt.rgba(1, 1, 1, 0.25) : Qt.rgba(1, 1, 1, 0.1)
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: "✕"
                                color: parent.parent.containsMouse ? "#ffffff" : Qt.rgba(1, 1, 1, 0.6)
                                font.pixelSize: 10 * fontScale
                                font.weight: Font.Bold
                            }
                        }
                    }
                }

                // Separator line
                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: Qt.rgba(1, 1, 1, 0.08)
                }

                // Clean 2-Column Grid of Category Cards
                GridView {
                    id: cardsGrid
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: rootWindow.displayCategories
                    cellWidth: Math.floor(width / 2)
                    cellHeight: 250 * scaleFactor
                    boundsBehavior: Flickable.StopAtBounds

                    ScrollBar.vertical: ScrollBar {
                        policy: ScrollBar.AsNeeded
                    }

                    delegate: Item {
                        width: cardsGrid.cellWidth
                        height: cardsGrid.cellHeight

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 6 * scaleFactor
                            radius: Math.round(4 * scaleFactor)
                            color: Qt.rgba(1, 1, 1, 0.04)
                            border.color: Qt.rgba(1, 1, 1, 0.08)
                            border.width: 1

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 12 * scaleFactor
                                spacing: 8 * scaleFactor

                                // Category Header
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8 * scaleFactor
                                    Text {
                                        text: modelData.icon || "󰌌"
                                        font.pixelSize: 14 * fontScale
                                        color: shellRoot ? shellRoot.colAccent : "#0A84FF"
                                        font.family: shellRoot ? shellRoot.iconFontFamily : "sans-serif"
                                    }
                                    Text {
                                        text: modelData.name
                                        font.pixelSize: 13 * fontScale
                                        font.weight: Font.DemiBold
                                        color: "#ffffff"
                                        font.family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                                        Layout.fillWidth: true
                                    }
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    height: 1
                                    color: Qt.rgba(1, 1, 1, 0.06)
                                }

                                // List of shortcut rows
                                ListView {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    clip: true
                                    model: modelData.items
                                    spacing: 6 * scaleFactor
                                    boundsBehavior: Flickable.StopAtBounds

                                    delegate: RowLayout {
                                        width: ListView.view ? ListView.view.width : 300
                                        height: 22 * scaleFactor
                                        spacing: 8 * scaleFactor

                                        Text {
                                            text: modelData.desc || ""
                                            color: Qt.rgba(1, 1, 1, 0.85)
                                            font.pixelSize: 11 * fontScale
                                            font.family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                                            Layout.fillWidth: true
                                            elide: Text.ElideRight
                                        }

                                        Row {
                                            spacing: 4 * scaleFactor
                                            Repeater {
                                                model: modelData.keys

                                                delegate: Rectangle {
                                                    width: keyLabel.implicitWidth + 8 * scaleFactor
                                                    height: 18 * scaleFactor
                                                    radius: 4 * scaleFactor
                                                    color: Qt.rgba(1, 1, 1, 0.12)
                                                    border.color: Qt.rgba(1, 1, 1, 0.2)
                                                    border.width: 1

                                                    Text {
                                                        id: keyLabel
                                                        anchors.centerIn: parent
                                                        text: modelData
                                                        color: "#ffffff"
                                                        font.pixelSize: 9 * fontScale
                                                        font.weight: Font.Medium
                                                        font.family: shellRoot ? shellRoot.fontFamily : "sans-serif"
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
            }
        }
    }
}
