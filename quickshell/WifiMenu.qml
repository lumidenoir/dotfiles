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
    property var wifiItems: []
    property real animHeight: animRect.height
    property alias animWidth: animRect.width

    property string selectedSsid: ""
    property var seenSsids: ({})

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

    function filterNetworks(query) {
        wifiModel.clear();
        var q = query.toLowerCase();
        for (var i = 0; i < wifiItems.length; i++) {
            if (wifiItems[i].ssid.toLowerCase().includes(q)) {
                wifiModel.append(wifiItems[i]);
            }
        }
    }

    Timer {
        id: focusTimer
        interval: 50
        onTriggered: {
            if (selectedSsid !== "") {
                passInput.forceActiveFocus();
            } else {
                searchInput.forceActiveFocus();
            }
        }
    }

    onShowChanged: {
        if (show) {
            isClosing = false;
            selectedSsid = "";
            wifiModel.clear();
            wifiItems = [];
            seenSsids = {};
            pGetWifi.running = true;
            searchInput.text = "";
            focusTimer.start();
        } else {
            isClosing = true;
        }
    }

    Process {
        id: pGetWifi
        // C-4 FIX: use a tab separator instead of colon to avoid SSID-with-colon breakage
        command: ["sh", "-c", "nmcli --terse --fields IN-USE,SSID,SECURITY dev wifi list | sort -r"]
        stdout: SplitParser {
            onRead: data => {
                var d = data.trim();
                if (d.length > 0) {
                    // Format is: IN-USE:SSID:SECURITY  where SSID may contain colons
                    // Split on first and last colon to safely extract all three fields
                    var idx1 = d.indexOf(":");
                    var idx2 = d.lastIndexOf(":");
                    if (idx1 > -1 && idx2 > idx1) {
                        var inUse = d.substring(0, idx1).trim();
                        // Middle field is SSID (may contain colons)
                        var ssid = d.substring(idx1 + 1, idx2).trim();
                        var sec = d.substring(idx2 + 1).trim();
                        // SECURITY field is exactly one field and never contains a colon
                        // so lastIndexOf correctly finds the separator before SECURITY
                        var secure = (sec !== "" && sec !== "--");
                        var connected = (inUse === "*");
                        if (ssid !== "" && !seenSsids[ssid]) {
                            seenSsids[ssid] = true;
                            wifiItems.push({"ssid": ssid, "secure": secure, "connected": connected});
                        }
                    }
                }
            }
        }
        onRunningChanged: {
            if (!running && rootWindow.show) {
                for (var i = 0; i < wifiItems.length; i++) {
                    wifiModel.append(wifiItems[i]);
                }
            }
        }
    }

    property bool isConnecting: false
    property string connectionError: ""

    Timer {
        id: errorTimer
        interval: 3000
        repeat: false
        onTriggered: {
            connectionError = "";
        }
    }

    Process {
        id: pConnect
        property string ssid: ""
        property string pass: ""
        command: ssid !== "" ? (pass === "" ? ["nmcli", "dev", "wifi", "connect", ssid]
                                            : ["nmcli", "dev", "wifi", "connect", ssid, "password", pass])
                             : ["echo"]
        onExited: (code, status) => {
            isConnecting = false;
            if (code === 0) {
                rootWindow.show = false;
            } else {
                connectionError = "Failed to connect";
                errorTimer.restart();
            }
        }
    }

    Item {
        anchors.fill: parent
        focus: show
        Keys.onEscapePressed: {
            if (selectedSsid !== "") {
                selectedSsid = "";
                focusTimer.start();
            } else {
                show = false;
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
            
            height: rootWindow.show ? ((selectedSsid !== "" || isConnecting || connectionError !== "") ? 170 * rootWindow.scaleFactor : 320 * rootWindow.scaleFactor) : (rootWindow.isClosing ? 36 * rootWindow.scaleFactor : 36 * rootWindow.scaleFactor)

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
                anchors.margins: 16
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
                    spacing: 12

                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 8

                        MouseArea {
                            id: wifiBackBtn
                            visible: selectedSsid !== ""
                            Layout.preferredWidth: 20
                            Layout.preferredHeight: 20
                            hoverEnabled: true

                            Text {
                                anchors.centerIn: parent
                                text: "󰌍"
                                color: parent.containsMouse ? (shellRoot ? shellRoot.colAccent : "#007AFF") : (shellRoot ? shellRoot.colMuted : "#888888")
                                font { family: shellRoot ? shellRoot.fontFamily : "sans-serif"; pixelSize: 14 }
                            }

                            onClicked: {
                                selectedSsid = "";
                                passInput.text = "";
                                focusTimer.start();
                            }
                        }

                        Text {
                            text: selectedSsid === "" ? "Wi-Fi Networks" : "Connect to " + selectedSsid
                            color: shellRoot ? shellRoot.colFg : "white"
                            font.family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                            font.pixelSize: 14
                            font.bold: true
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true

                        // Networks list view container (slides out to left)
                        Item {
                            id: networkListContainer
                            anchors.fill: parent
                            opacity: (selectedSsid === "" && !isConnecting && connectionError === "") ? 1.0 : 0.0
                            x: selectedSsid === "" ? 0 : -parent.width
                            visible: opacity > 0
                            Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutQuad } }
                            Behavior on x { NumberAnimation { duration: 250; easing.type: Easing.OutQuad } }

                            ColumnLayout {
                                anchors.fill: parent
                                spacing: 8

                                TextField {
                                    id: searchInput
                                    Layout.fillWidth: true
                                    placeholderText: "Search networks..."
                                    color: shellRoot ? shellRoot.colFg : "white"
                                    font.family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                                    font.pixelSize: 12
                                    background: Rectangle {
                                        color: Qt.rgba(1, 1, 1, 0.05)
                                        radius: 8
                                        border.color: searchInput.activeFocus ? Qt.rgba(1, 1, 1, 0.2) : "transparent"
                                    }
                                    onTextEdited: filterNetworks(text)
                                    Keys.onDownPressed: listView.incrementCurrentIndex()
                                    Keys.onUpPressed: listView.decrementCurrentIndex()
                                    Keys.onReturnPressed: {
                                        if (listView.currentIndex >= 0 && listView.currentIndex < wifiModel.count) {
                                            var model = wifiModel.get(listView.currentIndex);
                                            if (model.secure) {
                                                selectedSsid = model.ssid;
                                                passInput.text = "";
                                                focusTimer.start();
                                            } else {
                                                pConnect.ssid = model.ssid;
                                                pConnect.pass = "";
                                                isConnecting = true;
                                                pConnect.running = true;
                                            }
                                        }
                                    }
                                }

                                ListView {
                                    id: listView
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    clip: true
                                    model: ListModel { id: wifiModel }
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
                                                text: model.secure ? "󰌾" : "󰌿"
                                                color: shellRoot ? shellRoot.colFg : "white"
                                                font.family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                                                font.pixelSize: 11
                                            }
                                            Text {
                                                text: model.ssid + (model.connected ? " (Connected)" : "")
                                                color: model.connected ? "#1DB954" : (shellRoot ? shellRoot.colFg : "white")
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
                                                if (model.secure) {
                                                    selectedSsid = model.ssid;
                                                    passInput.text = "";
                                                    focusTimer.start();
                                                } else {
                                                    pConnect.ssid = model.ssid;
                                                    pConnect.pass = "";
                                                    isConnecting = true;
                                                    pConnect.running = true;
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Password entry container (slides in from right)
                        Item {
                            id: passwordContainer
                            anchors.fill: parent
                            opacity: (selectedSsid !== "" && !isConnecting && connectionError === "") ? 1.0 : 0.0
                            x: selectedSsid !== "" ? 0 : parent.width
                            visible: opacity > 0
                            Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutQuad } }
                            Behavior on x { NumberAnimation { duration: 250; easing.type: Easing.OutQuad } }

                            ColumnLayout {
                                anchors.fill: parent
                                spacing: 12

                                TextField {
                                    id: passInput
                                    Layout.fillWidth: true
                                    placeholderText: "Password..."
                                    echoMode: TextInput.Password
                                    color: shellRoot ? shellRoot.colFg : "white"
                                    font.family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                                    font.pixelSize: 13
                                    background: Rectangle {
                                        color: Qt.rgba(1,1,1,0.05)
                                        radius: 10
                                        border.color: passInput.activeFocus ? Qt.rgba(1,1,1,0.2) : "transparent"
                                    }
                                    Keys.onReturnPressed: {
                                        pConnect.ssid = selectedSsid;
                                        pConnect.pass = text;
                                        isConnecting = true;
                                        pConnect.running = true;
                                    }
                                    Keys.onEscapePressed: {
                                        selectedSsid = "";
                                        passInput.text = "";
                                        focusTimer.start();
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    Rectangle {
                                        Layout.fillWidth: true
                                        height: 36
                                        radius: 10
                                        color: Qt.rgba(1,1,1,0.1)
                                        Text { anchors.centerIn: parent; text: "Cancel"; color: "white"; font.pixelSize: 11; font.bold: true; font.family: shellRoot ? shellRoot.fontFamily : "sans-serif" }
                                        MouseArea {
                                            anchors.fill: parent
                                            onClicked: {
                                                selectedSsid = "";
                                                passInput.text = "";
                                                focusTimer.start();
                                            }
                                        }
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        height: 36
                                        radius: 10
                                        color: Qt.rgba(0.2,0.6,1.0,0.8)
                                        Text { anchors.centerIn: parent; text: "Connect"; color: "white"; font.bold: true; font.pixelSize: 11; font.family: shellRoot ? shellRoot.fontFamily : "sans-serif" }
                                        MouseArea {
                                            anchors.fill: parent
                                            onClicked: {
                                                pConnect.ssid = selectedSsid;
                                                pConnect.pass = passInput.text;
                                                isConnecting = true;
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

                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 10

                                Text {
                                    text: isConnecting ? "󰤨" : "󰅙"
                                    color: isConnecting ? (shellRoot ? shellRoot.colAccent : "#007aff") : (shellRoot ? shellRoot.colCrit : "#EF4444")
                                    font.family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                                    font.pixelSize: 32
                                    Layout.alignment: Qt.AlignHCenter

                                    SequentialAnimation on opacity {
                                        running: isConnecting
                                        loops: Animation.Infinite
                                        NumberAnimation { to: 0.3; duration: 600 }
                                        NumberAnimation { to: 1.0; duration: 600 }
                                    }
                                }

                                Text {
                                    text: isConnecting ? "Establishing connection..." : connectionError
                                    color: isConnecting ? (shellRoot ? shellRoot.colFg : "white") : "#EF4444"
                                    font.family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                                    font.pixelSize: 12
                                    Layout.alignment: Qt.AlignHCenter
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
