import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

PanelWindow {
    id: rootWindow

    property bool show: false
    property var shellRoot
    readonly property real scaleFactor: shellRoot ? shellRoot.scaleFactor : 1.0
    property var btItems: []
    property real animHeight: animRect.height
    property alias animWidth: animRect.width

    property bool isConnecting: false
    property string connectingName: ""
    property string connectionError: ""

    // Two-phase close state machine (unified dynamic island pattern)
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

    Process {
        id: pListBt
        command: ["bash", "-c", "connected=$(bluetoothctl devices Connected | awk '{print $2}'); bluetoothctl devices | while read -r _ mac name; do if [[ \"$connected\" == *\"$mac\"* ]]; then echo \"$mac|$name|yes\"; else echo \"$mac|$name|no\"; fi; done"]

        // C-3 FIX: use a local temp array; never mutate btItems directly mid-parse
        property var connectedTemp: []
        property var otherTemp: []

        stdout: SplitParser {
            onRead: data => {
                var line = data.trim();
                if (line === "") return;
                var parts = line.split('|');
                if (parts.length >= 3) {
                    var mac = parts[0];
                    var name = parts[1];
                    var connected = (parts[2] === "yes");
                    if (name !== "") {
                        if (connected) {
                            pListBt.connectedTemp.push({mac: mac, name: name, connected: connected});
                        } else {
                            pListBt.otherTemp.push({mac: mac, name: name, connected: connected});
                        }
                    }
                }
            }
        }
        onRunningChanged: {
            if (running) {
                // Reset temp buffers at the start of a new scan
                pListBt.connectedTemp = [];
                pListBt.otherTemp = [];
            } else {
                // Assign once — connected devices first, then others
                btItems = pListBt.connectedTemp.concat(pListBt.otherTemp);
                btModel.clear();
                for (var i = 0; i < btItems.length; i++) {
                    btModel.append(btItems[i]);
                }
                if (btModel.count > 0) {
                    listView.currentIndex = 0;
                }
                if (rootWindow.show) {
                    focusTimer.start();
                }
            }
        }
    }

    Process {
        id: pConnect
        property string targetMac: ""
        // Q-4 FIX: guard with running: instead of ["echo"] fallback
        command: ["bluetoothctl", "connect", targetMac]
        running: false
        onExited: (exitCode) => {
            isConnecting = false;
            if (exitCode !== 0) {
                connectionError = "Connection failed";
                errorTimer.start();
            } else {
                show = false;
            }
        }
    }

    Process {
        id: pDisconnect
        property string targetMac: ""
        // Q-4 FIX: guard with running: instead of ["echo"] fallback
        command: ["bluetoothctl", "disconnect", targetMac]
        running: false
        onExited: (exitCode) => {
            isConnecting = false;
            if (exitCode !== 0) {
                connectionError = "Disconnection failed";
                errorTimer.start();
            } else {
                show = false;
            }
        }
    }

    function filterBt(query) {
        btModel.clear();
        var q = query.toLowerCase();
        for (var i = 0; i < btItems.length; i++) {
            if (btItems[i].name.toLowerCase().includes(q)) {
                btModel.append(btItems[i]);
            }
        }
    }

    onShowChanged: {
        if (show) {
            isClosing = false;
            btItems = [];
            btModel.clear();
            pListBt.connectedTemp = [];
            pListBt.otherTemp = [];
            pListBt.running = true;
            searchInput.text = "";
            isConnecting = false;
            connectingName = "";
            connectionError = "";
            errorTimer.stop();
        } else {
            isClosing = true;
        }
    }

    Timer {
        id: errorTimer
        interval: 2500
        onTriggered: {
            connectionError = "";
            show = false;
        }
    }

    Timer {
        id: focusTimer
        interval: 50
        onTriggered: searchInput.forceActiveFocus()
    }

    Item {
        id: btMenuContent
        anchors.fill: parent
        focus: show

        Keys.onEscapePressed: {
            show = false;
        }

        Keys.onReturnPressed: connectCurrent()
        Keys.onEnterPressed: connectCurrent()

        function connectCurrent() {
            if (listView.currentIndex >= 0 && listView.currentIndex < btModel.count) {
                var item = btModel.get(listView.currentIndex);
                connectingName = item.name;
                isConnecting = true;
                if (item.connected) {
                    pDisconnect.targetMac = item.mac;
                    pDisconnect.running = true;
                } else {
                    pConnect.targetMac = item.mac;
                    pConnect.running = true;
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            enabled: show
            onClicked: show = false
        }

        Rectangle {
            id: animRect
            anchors.top: parent.top
            anchors.topMargin: show ? 16 * rootWindow.scaleFactor : 4 * rootWindow.scaleFactor
            anchors.horizontalCenter: parent.horizontalCenter

            // Collapse to circle (width 36, height 36) or closedNotchWidth
            width: rootWindow.show ? 360 * rootWindow.scaleFactor : (rootWindow.isClosing ? 36 * rootWindow.scaleFactor : 120 * rootWindow.scaleFactor)
            
            height: rootWindow.show ? 320 * rootWindow.scaleFactor : (rootWindow.isClosing ? 36 * rootWindow.scaleFactor : 36 * rootWindow.scaleFactor)

            radius: rootWindow.show ? 24 * rootWindow.scaleFactor : (rootWindow.isClosing ? 18 * rootWindow.scaleFactor : 20 * rootWindow.scaleFactor)

            color: Qt.rgba(0.02, 0.02, 0.02, 1.0)
            border.color: Qt.rgba(1, 1, 1, 0.08)
            border.width: 1

            // Unified physics spring animations
            Behavior on width {
                enabled: shellRoot ? !shellRoot.batteryMode : true
                SpringAnimation { spring: 4.8; damping: 0.8; mass: 0.6 }
            }
            Behavior on height {
                enabled: shellRoot ? !shellRoot.batteryMode : true
                SpringAnimation { spring: 4.8; damping: 0.8; mass: 0.6 }
            }
            Behavior on radius {
                enabled: shellRoot ? !shellRoot.batteryMode : true
                SpringAnimation { spring: 4.8; damping: 0.8; mass: 0.6 }
            }
            Behavior on anchors.topMargin {
                enabled: shellRoot ? !shellRoot.batteryMode : true
                SpringAnimation { spring: 4.8; damping: 0.8; mass: 0.6 }
            }

            function checkCloseFinished() {
                if (!rootWindow.show && rootWindow.isClosing) {
                    var sf = rootWindow.scaleFactor;
                    var targetWidth = 36 * sf;
                    var targetHeight = 36 * sf;
                    if (Math.abs(width - targetWidth) < 1.0 && Math.abs(height - targetHeight) < 1.0) {
                        rootWindow.isClosing = false;
                    }
                }
            }

            onWidthChanged: checkCloseFinished()
            onHeightChanged: checkCloseFinished()

            Item {
                anchors.fill: parent
                opacity: show ? 1.0 : 0.0
                clip: true
                Behavior on opacity {
                    SequentialAnimation {
                        PauseAnimation { duration: (shellRoot && shellRoot.batteryMode) ? 0 : show ? 150 : 0 }
                        NumberAnimation {
                            duration: (shellRoot && shellRoot.batteryMode) ? 0 : show ? 200 : 150
                            easing.type: Easing.InOutQuad
                        }
                    }
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 12

                    Text {
                        text: "Bluetooth Devices"
                        color: shellRoot ? shellRoot.colFg : "white"
                        font.family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                        font.pixelSize: 14
                        font.bold: true
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Text {
                        visible: shellRoot && shellRoot.bluetoothStatus !== "on"
                        text: "Bluetooth is turned off"
                        color: shellRoot ? shellRoot.colMuted : "#888888"
                        font.family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                        font.pixelSize: 12
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: 20
                    }

                    TextField {
                        id: searchInput
                        Layout.fillWidth: true
                        placeholderText: "Search devices..."
                        color: shellRoot ? shellRoot.colFg : "white"
                        font.family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                        font.pixelSize: 12
                        background: Rectangle {
                            color: Qt.rgba(1, 1, 1, 0.05)
                            radius: 8
                            border.color: searchInput.activeFocus ? Qt.rgba(1, 1, 1, 0.2) : "transparent"
                        }
                        onTextEdited: filterBt(text)
                        Keys.onDownPressed: listView.incrementCurrentIndex()
                        Keys.onUpPressed: listView.decrementCurrentIndex()
                        Keys.onReturnPressed: connectCurrent()
                    }

                    ListView {
                        id: listView
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        model: ListModel { id: btModel }
                        spacing: 4

                        delegate: Rectangle {
                            width: ListView.view.width
                            height: 40
                            radius: 10
                            color: listView.currentIndex === index || ma.containsMouse ? Qt.rgba(1,1,1,0.1) : "transparent"

                            Rectangle {
                                id: accentStrip
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                width: 3
                                height: 18
                                radius: 1.5
                                color: shellRoot ? shellRoot.colAccent : "#ffffff"
                                visible: listView.currentIndex === index
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 10
                                Text {
                                    text: "󰂯"
                                    color: model.connected ? (shellRoot ? shellRoot.colSpotify : "#1DB954") : (shellRoot ? shellRoot.colFg : "white")
                                    font.family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                                    font.pixelSize: 11
                                }
                                Text {
                                    text: model.name + (model.connected ? " (Connected)" : "")
                                    color: model.connected ? (shellRoot ? shellRoot.colSpotify : "#1DB954") : (shellRoot ? shellRoot.colFg : "white")
                                    font.family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                                    font.pixelSize: 11
                                    font.bold: model.connected
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }
                            }

                            MouseArea {
                                id: ma
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    listView.currentIndex = index;
                                    var mac = model.mac;
                                    connectingName = model.name;
                                    isConnecting = true;
                                    if (model.connected) {
                                        pDisconnect.targetMac = mac;
                                        pDisconnect.running = true;
                                    } else {
                                        pConnect.targetMac = mac;
                                        pConnect.running = true;
                                    }
                                }
                            }
                        }
                    }
                }

                // Connecting overlay
                Item {
                    id: connectingOverlay
                    anchors.fill: parent
                    visible: isConnecting || connectionError !== ""
                    opacity: visible ? 1.0 : 0.0
                    Behavior on opacity { NumberAnimation { duration: 200 } }

                    Rectangle {
                        anchors.fill: parent
                        color: Qt.rgba(0.08, 0.08, 0.08, 0.95)
                        radius: animRect.radius
                    }

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 12

                        Text {
                            text: connectionError !== "" ? "󰅙" : "󰂱"
                            color: connectionError !== "" ? (shellRoot ? shellRoot.colCrit : "red") : (shellRoot ? shellRoot.colAccent : "#007aff")
                            font.family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                            font.pixelSize: 32
                            Layout.alignment: Qt.AlignHCenter

                            NumberAnimation on rotation {
                                running: isConnecting
                                loops: Animation.Infinite
                                from: 0
                                to: 360
                                duration: 1000
                            }
                        }

                        Text {
                            text: connectionError !== "" ? connectionError : (pDisconnect.running ? "Disconnecting..." : "Connecting to " + connectingName + "...")
                            color: shellRoot ? shellRoot.colFg : "white"
                            font.family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                            font.pixelSize: 13
                            font.bold: true
                            Layout.alignment: Qt.AlignHCenter
                        }
                    }
                }
            }
        }
    }
}
