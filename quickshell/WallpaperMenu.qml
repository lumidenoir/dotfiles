import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

PanelWindow {
    id: rootWindow

    property bool show: false
    property var shellRoot
    property var wallpaperItems: []
    property bool isClosing: false

    WlrLayershell.keyboardFocus: show ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.namespace: "quickshell"

    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    visible: show || isClosing

    onShowChanged: {
        if (show) {
            isClosing = false;
            wallpaperModel.clear();
            wallpaperItems = [];
            pGetWallpapers.running = true;
        } else {
            isClosing = true;
        }
    }

    ListModel {
        id: wallpaperModel
    }

    Process {
        id: pGetWallpapers
        command: ["sh", "-c", "find ~/Pictures/wallpaper/hyprland -type f \\( -iname \"*.jpg\" -o -iname \"*.jpeg\" -o -iname \"*.png\" -o -iname \"*.webp\" \\)"]
        stdout: SplitParser {
            onRead: data => {
                var path = data.trim();
                if (path !== "") {
                    var parts = path.split("/");
                    var name = parts[parts.length - 1];
                    wallpaperItems.push({"path": path, "name": name});
                }
            }
        }
        onRunningChanged: {
            if (!running && rootWindow.show) {
                wallpaperItems.sort((a, b) => a.name.localeCompare(b.name));
                for (var i = 0; i < wallpaperItems.length; i++) {
                    wallpaperModel.append(wallpaperItems[i]);
                }
                if (listView) {
                    listView.forceActiveFocus();
                    listView.currentIndex = 0;
                }
            }
        }
    }

    Process {
        id: pSetWallpaper
        property string path: ""
        command: ["sh", "-c", path !== "" ? ("awww img --transition-bezier .43,1.19,1,.4 --transition-fps 30 --transition-type grow --transition-pos 0.925,0.977 --transition-duration 2 \"" + path + "\" && wal -n -i -s -t \"" + path + "\"") : "echo"]
        onExited: (exitCode) => {
            if (exitCode === 0 && path !== "") {
                pSaveWallpaperCache.path = path;
                pSaveWallpaperCache.running = true;
                if (shellRoot) {
                    shellRoot.reloadWalColors();
                }
            }
        }
    }

    Process {
        id: pSaveWallpaperCache
        property string path: ""
        command: ["sh", "-c", "echo \"" + path + "\" > ~/.cache/wallpaper"]
        running: false
    }

    Item {
        anchors.fill: parent
        
        Keys.onEscapePressed: {
            show = false;
        }

        MouseArea {
            anchors.fill: parent
            enabled: show
            onClicked: show = false
        }

        Rectangle {
            id: animRect
            anchors.horizontalCenter: parent.horizontalCenter
            
            // Positioning at top bar height or flying up and out of the screen
            y: show ? 12 * (shellRoot ? shellRoot.scaleFactor : 1.0) : -height - 30
            
            width: 860 * (shellRoot ? shellRoot.scaleFactor : 1.0)
            height: 340 * (shellRoot ? shellRoot.scaleFactor : 1.0)
            radius: 24 * (shellRoot ? shellRoot.scaleFactor : 1.0)

            color: Qt.rgba(0.08, 0.08, 0.08, 0.94)
            border.color: Qt.rgba(1, 1, 1, 0.08)
            border.width: 1

            // Fly-up spring physics
            Behavior on y {
                enabled: shellRoot ? !shellRoot.batteryMode : true
                SpringAnimation {
                    spring: 3.5
                    damping: 0.8
                    mass: 0.9
                }
            }

            onYChanged: {
                if (!show && isClosing && y <= -height) {
                    isClosing = false;
                }
            }

            Item {
                anchors.fill: parent
                anchors.margins: 20 * (shellRoot ? shellRoot.scaleFactor : 1.0)
                opacity: show ? 1.0 : 0.0
                clip: true
                Behavior on opacity { NumberAnimation { duration: 200 } }

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 12

                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            spacing: 2
                            Text {
                                text: "Select Wallpaper"
                                color: shellRoot ? shellRoot.colFg : "white"
                                font.pixelSize: 20 * (shellRoot ? shellRoot.scaleFactor : 1.0)
                                font.bold: true
                                font.family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                            }
                            Text {
                                text: "Choose an image to update your system style"
                                color: shellRoot ? shellRoot.colMuted : "#88ffffff"
                                font.pixelSize: 11 * (shellRoot ? shellRoot.scaleFactor : 1.0)
                                font.family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                            }
                        }
                        
                        Item { Layout.fillWidth: true }

                        // Hotkey indicator (macOS style pill)
                        Rectangle {
                            color: Qt.rgba(1, 1, 1, 0.06)
                            radius: 8 * (shellRoot ? shellRoot.scaleFactor : 1.0)
                            border.color: Qt.rgba(1, 1, 1, 0.1)
                            border.width: 1
                            implicitWidth: hotkeyText.implicitWidth + 16
                            implicitHeight: hotkeyText.implicitHeight + 8
                            Text {
                                id: hotkeyText
                                anchors.centerIn: parent
                                text: "Esc to close • Enter to apply"
                                color: shellRoot ? shellRoot.colMuted : "#88ffffff"
                                font.pixelSize: 10 * (shellRoot ? shellRoot.scaleFactor : 1.0)
                                font.family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                            }
                        }
                    }

                    ListView {
                        id: listView
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        orientation: ListView.Horizontal
                        spacing: 16
                        model: wallpaperModel
                        clip: true
                        focus: show
                        keyNavigationEnabled: true
                        highlightMoveDuration: 200

                        Keys.onReturnPressed: selectCurrentItem()
                        Keys.onEnterPressed: selectCurrentItem()
                        Keys.onEscapePressed: rootWindow.show = false

                        function selectCurrentItem() {
                            if (currentIndex >= 0 && currentIndex < wallpaperModel.count) {
                                pSetWallpaper.path = wallpaperModel.get(currentIndex).path;
                                pSetWallpaper.running = true;
                                rootWindow.show = false;
                            }
                        }

                        delegate: Item {
                            width: 240 * (shellRoot ? shellRoot.scaleFactor : 1.0)
                            height: 170 * (shellRoot ? shellRoot.scaleFactor : 1.0)

                            Item {
                                id: cardWrapper
                                anchors.fill: parent
                                anchors.margins: 6

                                // Subtle zoom-in and dimming of inactive selections
                                scale: listView.currentIndex === index ? 1.04 : (mouseArea.containsMouse ? 1.02 : 0.96)
                                opacity: listView.currentIndex === index ? 1.0 : (mouseArea.containsMouse ? 0.9 : 0.6)

                                Behavior on scale {
                                    enabled: shellRoot ? !shellRoot.batteryMode : true
                                    SpringAnimation { spring: 4.0; damping: 0.75; mass: 0.8 }
                                }
                                Behavior on opacity {
                                    NumberAnimation { duration: 150 }
                                }

                                Rectangle {
                                    id: cardFrame
                                    anchors.fill: parent
                                    radius: 14 * (shellRoot ? shellRoot.scaleFactor : 1.0)
                                    color: Qt.rgba(0.1, 0.1, 0.1, 0.5)
                                    border.color: mouseArea.containsMouse ? Qt.rgba(1, 1, 1, 0.2) : Qt.rgba(1, 1, 1, 0.08)
                                    border.width: 1.5
                                    antialiasing: true
                                    
                                    Behavior on border.color { ColorAnimation { duration: 150 } }

                                    // Perfect vector-sharp rounded image clipping using layer clipping (no blurry MultiEffect masks)
                                    Rectangle {
                                        id: cardImageContainer
                                        anchors.fill: parent
                                        anchors.margins: 1.5 // inset to prevent bleeding through the frame border
                                        radius: 12.5 * (shellRoot ? shellRoot.scaleFactor : 1.0)
                                        color: "transparent"
                                        clip: true
                                        layer.enabled: true
                                        antialiasing: true

                                        Image {
                                            anchors.fill: parent
                                            source: "file://" + model.path
                                            sourceSize.width: 300
                                            sourceSize.height: 200
                                            fillMode: Image.PreserveAspectCrop
                                            asynchronous: true
                                            cache: true
                                        }

                                        // Dark overlay gradient at the bottom of card
                                        Rectangle {
                                            anchors.bottom: parent.bottom
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            height: 45 * (shellRoot ? shellRoot.scaleFactor : 1.0)
                                            gradient: Gradient {
                                                GradientStop { position: 0.0; color: "transparent" }
                                                GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.85) }
                                            }
                                        }
                                    }

                                    // Elegant floating text tag
                                    Text {
                                        anchors.bottom: parent.bottom
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        anchors.bottomMargin: 8 * (shellRoot ? shellRoot.scaleFactor : 1.0)
                                        text: model.name
                                        color: "#ffffff"
                                        font.family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                                        font.pixelSize: 11 * (shellRoot ? shellRoot.scaleFactor : 1.0)
                                        font.bold: true
                                        elide: Text.ElideRight
                                        width: parent.width - 24
                                        horizontalAlignment: Text.AlignHCenter
                                    }

                                    // Apple-style checkmark badge on active selection
                                    Rectangle {
                                        anchors.top: parent.top
                                        anchors.right: parent.right
                                        anchors.margins: 10 * (shellRoot ? shellRoot.scaleFactor : 1.0)
                                        width: 20 * (shellRoot ? shellRoot.scaleFactor : 1.0)
                                        height: 20 * (shellRoot ? shellRoot.scaleFactor : 1.0)
                                        radius: 10 * (shellRoot ? shellRoot.scaleFactor : 1.0)
                                        color: shellRoot ? shellRoot.colAccent : "#EC4899"
                                        visible: listView.currentIndex === index
                                        antialiasing: true

                                        Text {
                                            anchors.centerIn: parent
                                            text: "󰄬"
                                            // Handle color contrast if colAccent is white (#ffffff)
                                            color: (shellRoot && shellRoot.colAccent == "#ffffff") ? "#000000" : "#ffffff"
                                            font.family: shellRoot ? shellRoot.iconFontFamily : "sans-serif"
                                            font.pixelSize: 10 * (shellRoot ? shellRoot.scaleFactor : 1.0)
                                            font.bold: true
                                        }
                                    }
                                }

                                MouseArea {
                                    id: mouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: {
                                        listView.currentIndex = index;
                                        listView.selectCurrentItem();
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
