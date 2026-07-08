import Quickshell
import QtQuick
import QtQuick.Layouts
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io

PanelWindow {
    id: airspaceWin

    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    property var shellRoot: null
    property real scaleFactor: shellRoot ? shellRoot.scaleFactor : 1.0

    property bool show: false

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: show ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.namespace: "quickshell_airspace"

    visible: show || overlay.opacity > 0

    property var workspacesData: []
    property string activeWindowAddress: ""

    Timer {
        id: deferredRefreshTimer
        interval: 300
        repeat: false
        onTriggered: refresh()
    }

    Timer {
        id: focusDelayTimer
        interval: 80
        repeat: false
        property string targetAddress: ""
        onTriggered: {
            Hyprland.dispatch("hl.dsp.focus({ window = \"address:" + targetAddress + "\" })");
        }
    }

    Component.onCompleted: {
        refresh();
    }

    // Screen dimensions from the PanelWindow itself
    readonly property real screenW: airspaceWin.width  > 0 ? airspaceWin.width  : 1920
    readonly property real screenH: airspaceWin.height > 0 ? airspaceWin.height : 1080

    // Monitor coordinates scaling base
    property real monitorW: 1920
    property real monitorH: 1080

    // ─── Tooltip state ───────────────────────────────────────────────────
    property string tooltipText: ""
    property real   tooltipX:    0
    property real   tooltipY:    0
    property bool   tooltipVis:  false

    // ─── Drag and Drop State ─────────────────────────────────────────────
    property bool dragActive: false
    property string draggedAddress: ""
    property string draggedTitle: ""
    property real draggedWidth: 0
    property real draggedHeight: 0
    property real dragMouseX: 0
    property real dragMouseY: 0
    property int dragSourceWsId: -1
    property int hoveredTargetWsId: -1

    function toggle() { show ? close() : open() }

    function open() {
        show = true;
        deferredRefreshTimer.restart();
    }

    function close() {
        show = false;
        tooltipVis = false;
        dragActive = false;
        hoveredTargetWsId = -1;
    }

    function refresh() {
        pGetActiveWindow.running = true;
        pGetAirspace.running = true;
    }

    function switchToWorkspace(wsId) {
        Hyprland.dispatch("hl.dsp.focus({ workspace = \"" + wsId.toString() + "\" })");
        close();
    }

    function focusWindow(wsId, address) {
        Hyprland.dispatch("hl.dsp.focus({ workspace = \"" + wsId.toString() + "\" })");
        focusDelayTimer.targetAddress = address;
        focusDelayTimer.start();
        close();
    }

    function closeWindow(address) {
        Hyprland.dispatch("hl.dsp.window.close({ window = \"address:" + address + "\" })");
        refresh();
    }

    function resolveWorkspaceAt(overlayX, overlayY) {
        for (var i = 0; i < wsRepeater.count; i++) {
            var item = wsRepeater.itemAt(i);
            if (!item) continue;
            var mapped = item.mapFromItem(overlay, overlayX, overlayY);
            if (mapped.x >= 0 && mapped.x <= item.width &&
                mapped.y >= 0 && mapped.y <= item.height) {
                return item.workspaceId;
            }
        }
        return -1;
    }

    // ─── Data fetching ───────────────────────────────────────────────────
    Process {
        id: pGetActiveWindow
        command: ["hyprctl", "activewindow", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var act = JSON.parse(text.trim());
                    airspaceWin.activeWindowAddress = act.address || "";
                } catch (e) { airspaceWin.activeWindowAddress = ""; }
            }
        }
    }

    Process {
        id: pGetAirspace
        command: ["sh", "-c", "hyprctl monitors -j && echo 'QSSPLIT' && hyprctl workspaces -j && echo 'QSSPLIT' && hyprctl clients -j"]
        stdout: StdioCollector {
            onStreamFinished: {
                var parts = text.split("QSSPLIT");
                if (parts.length < 3) return;
                try {
                    var monJson = JSON.parse(parts[0].trim());
                    var wsJson  = JSON.parse(parts[1].trim());
                    var clJson  = JSON.parse(parts[2].trim());

                    // Find focused monitor to set correct layout scaling bounds
                    var mon = monJson[0];
                    for (var m = 0; m < monJson.length; m++) {
                        if (monJson[m].focused) {
                            mon = monJson[m];
                            break;
                        }
                    }
                    if (mon) {
                        airspaceWin.monitorW = mon.width || 1920;
                        airspaceWin.monitorH = mon.height || 1080;
                    }

                    var clMap = {};
                    for (var i = 0; i < clJson.length; i++) {
                        var c = clJson[i];
                        if (c.workspace.id < 0) continue;
                        var wid = c.workspace.id;
                        if (!clMap[wid]) clMap[wid] = [];
                        clMap[wid].push({
                            x:        c.at[0],
                            y:        c.at[1],
                            w:        c.size[0],
                            h:        c.size[1],
                            address:  c.address,
                            title:    c.title   || "",
                            appClass: c.class   || ""
                        });
                    }

                    wsJson.sort(function(a, b) { return a.id - b.id; });

                    var list = [], seen = {};
                    for (var j = 0; j < wsJson.length; j++) {
                        var ws = wsJson[j];
                        if (ws.id > 0 && ws.id <= 10) {
                            seen[ws.id] = true;
                            list.push({ wsId: ws.id, name: ws.name, clients: clMap[ws.id] || [] });
                        }
                    }
                    for (var k = 1; k <= 5; k++) {
                        if (!seen[k]) list.push({ wsId: k, name: k.toString(), clients: [] });
                    }
                    list.sort(function(a, b) { return a.wsId - b.wsId; });
                    airspaceWin.workspacesData = list;
                } catch (e) { console.log("Airspace parse error: " + e); }
            }
        }
    }

    // ─── Hyprland socket IPC — live event listener ───────────────────────
    Process {
        id: pHyprEvents
        command: ["sh", "-c",
            "socat - UNIX-CONNECT:/tmp/hypr/${HYPRLAND_INSTANCE_SIGNATURE}/.socket2.sock 2>/dev/null"]
        running: airspaceWin.show
        stdout: SplitParser {
            onRead: function(data) {
                var parts = data.trim().split(">>");
                if (parts.length < 1) return;
                var ev = parts[0];
                // Window open/close/move → refresh layout
                if (ev === "openwindow" || ev === "closewindow" ||
                    ev === "movewindow" || ev === "closeworkspace" ||
                    ev === "createworkspace") {
                    pGetAirspace.running = true;
                }
                // Active window change → highlight update
                if (ev === "activewindowv2" || ev === "focusedmon") {
                    pGetActiveWindow.running = true;
                }
            }
        }
        // Auto-restart on unexpected disconnect while Airspace is still open
        onExited: {
            if (airspaceWin.show) {
                pHyprEvents.running = false;
                pHyprEventsRestartTimer.restart();
            }
        }
    }

    Timer {
        id: pHyprEventsRestartTimer
        interval: 500
        repeat: false
        onTriggered: {
            if (airspaceWin.show) {
                pHyprEvents.running = true;
            }
        }
    }

    // ─── OVERLAY ────────────────────────────────────────────────────────
    Rectangle {
        id: overlay
        anchors.fill: parent
        color: Qt.rgba(0.02, 0.02, 0.05, 0.72)
        opacity: airspaceWin.show ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

        focus: airspaceWin.show

        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) {
                airspaceWin.close(); event.accepted = true;
            } else if (event.key >= Qt.Key_1 && event.key <= Qt.Key_9) {
                airspaceWin.switchToWorkspace(event.key - Qt.Key_0);
                event.accepted = true;
            }
        }

        // Background dismiss
        MouseArea {
            anchors.fill: parent
            onClicked: airspaceWin.close()
        }

        // ── Content column ─────────────────────────────────────────────
        Column {
            anchors.centerIn: parent
            spacing: Math.round(28 * scaleFactor)

            // Scale-in animation when showing
            scale: airspaceWin.show ? 1.0 : 0.94
            Behavior on scale { NumberAnimation { duration: 280; easing.type: Easing.OutBack; easing.overshoot: 0.6 } }

            // Header row: title + hint
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Math.round(20 * scaleFactor)

                Column {
                    spacing: Math.round(4 * scaleFactor)
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Airspace Overview"
                        color: "#FFFFFF"
                        font {
                            family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                            pixelSize: Math.round(26 * scaleFactor)
                            weight: Font.Light
                            letterSpacing: 1.5
                        }
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Click a workspace to switch  •  Hover a window for details  •  1-9 to jump"
                        color: Qt.rgba(1, 1, 1, 0.32)
                        font {
                            family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                            pixelSize: Math.round(11 * scaleFactor)
                        }
                    }
                }
            }

            // ── Workspace cards Grid (Wrapping after 3 columns) ─────────
            Grid {
                id: wsGrid
                anchors.horizontalCenter: parent.horizontalCenter
                columns: Math.min(3, airspaceWin.workspacesData.length)
                spacing: Math.round(28 * scaleFactor)
                rowSpacing: Math.round(36 * scaleFactor)

                Repeater {
                    id: wsRepeater
                    model: airspaceWin.workspacesData

                    delegate: Item {
                        id: wsDelegate

                        // Fixed card dimensions for stable layout & better readability
                        readonly property real cardW: Math.round(440 * scaleFactor)
                        readonly property real cardH: Math.round(247.5 * scaleFactor) // 16:9 Aspect Ratio

                        // Scale relative to actual monitor dimensions (avoids status bar shrinkage offset)
                        readonly property real sX: (cardW - 16 * scaleFactor) / airspaceWin.monitorW
                        readonly property real sY: (cardH - 16 * scaleFactor) / airspaceWin.monitorH
                        readonly property int workspaceId: modelData.wsId

                        property bool isCurrent: modelData.wsId === (Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : -1)

                        width:  cardW
                        height: cardH + Math.round(56 * scaleFactor)

                        // ── Card ──────────────────────────────────────────
                        Rectangle {
                            id: wsCard
                            width:  wsDelegate.cardW
                            height: wsDelegate.cardH
                            radius: Math.round(16 * scaleFactor)
                            color:  cardMouse.containsMouse ? Qt.rgba(1,1,1,0.09) : Qt.rgba(1,1,1,0.04)
                            border.color: {
                                if (airspaceWin.hoveredTargetWsId === wsDelegate.workspaceId) {
                                    return "#30D158";
                                }
                                return wsDelegate.isCurrent ? "#007AFF"
                                             : (cardMouse.containsMouse ? Qt.rgba(1,1,1,0.30) : Qt.rgba(1,1,1,0.12));
                            }
                            border.width: {
                                if (airspaceWin.hoveredTargetWsId === wsDelegate.workspaceId) {
                                    return 3.0;
                                }
                                return wsDelegate.isCurrent ? 2.5 : 1;
                            }
                            clip: true

                            Behavior on border.color { ColorAnimation { duration: 120 } }
                            Behavior on color         { ColorAnimation { duration: 120 } }

                            // Card Click MouseArea (declared FIRST so it sits behind the window blocks in z-order)
                            MouseArea {
                                id: cardMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: airspaceWin.switchToWorkspace(modelData.wsId)
                            }

                            // Workspace pill badge (top-left)
                            Rectangle {
                                x: Math.round(10 * scaleFactor)
                                y: Math.round(10 * scaleFactor)
                                width:  Math.round(24 * scaleFactor)
                                height: Math.round(24 * scaleFactor)
                                radius: Math.round(12 * scaleFactor)
                                color: wsDelegate.isCurrent ? "#007AFF" : Qt.rgba(0,0,0,0.55)
                                z: 10

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.name
                                    color: "#FFFFFF"
                                    font {
                                        family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                                        pixelSize: Math.round(11 * scaleFactor)
                                        weight: Font.SemiBold
                                    }
                                }
                            }

                             // Empty state
                             Text {
                                 anchors.centerIn: parent
                                 visible: modelData.clients.length === 0
                                 text: "Empty"
                                 color: Qt.rgba(1, 1, 1, 0.18)
                                 font {
                                     family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                                     pixelSize: Math.round(12 * scaleFactor)
                                     weight: Font.Light
                                     italic: true
                                 }
                             }

                             // ── Miniature window blocks (sits on top of cardMouse) ──────────────────
                             Item {
                                 anchors.fill: parent
                                 anchors.margins: Math.round(8 * scaleFactor)
                                 clip: true
                                 z: 5

                                 Repeater {
                                     model: modelData.clients
                                     delegate: Rectangle {
                                         id: winBlock

                                         // Capture outer scale factors via property
                                         readonly property real _sX:  wsDelegate.sX
                                         readonly property real _sY:  wsDelegate.sY
                                         readonly property real _sf:  airspaceWin.scaleFactor

                                         x:      Math.round(model.modelData.x * _sX)
                                         y:      Math.round(model.modelData.y * _sY)
                                         width:  Math.max(Math.round(model.modelData.w * _sX), 20)
                                         height: Math.max(Math.round(model.modelData.h * _sY), 20)
                                         radius: Math.round(5 * _sf)

                                         property bool isActive: model.modelData.address === airspaceWin.activeWindowAddress

                                         // Apple/Gnome style hover brightening: more opaque white when hovered
                                         color:        isActive ? Qt.rgba(0.0, 0.478, 1.0, 0.78)
                                                                : (winMouse.containsMouse ? Qt.rgba(255, 255, 255, 0.28) : Qt.rgba(1, 1, 1, 0.13))
                                         border.color: isActive ? "#FFFFFF"
                                                                : (winMouse.containsMouse ? Qt.rgba(255, 255, 255, 0.45) : Qt.rgba(1, 1, 1, 0.18))
                                         border.width: isActive ? 1.5 : 1

                                         // Smooth transitions for layout changes and hovers
                                         Behavior on x { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                                         Behavior on y { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                                         Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                                         Behavior on height { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                                         Behavior on color { ColorAnimation { duration: 150 } }
                                         Behavior on border.color { ColorAnimation { duration: 150 } }

                                         // Blue glow for active
                                         Rectangle {
                                             visible: winBlock.isActive
                                             anchors.fill: parent
                                             radius: parent.radius
                                             color: "transparent"
                                             border.color: Qt.rgba(0.0, 0.478, 1.0, 0.45)
                                             border.width: 3
                                             anchors.margins: -2
                                         }

                                          // App Icon and Title text inside block
                                          Column {
                                              anchors.centerIn: parent
                                              width: parent.width - Math.round(8 * _sf)
                                              spacing: Math.round(2 * _sf)

                                              Image {
                                                  anchors.horizontalCenter: parent.horizontalCenter
                                                  width: Math.min(Math.round(24 * _sf), parent.width - 4)
                                                  height: Math.min(Math.round(24 * _sf), parent.height - 10)
                                                  source: "image://icon/" + (model.modelData.appClass || "").toLowerCase()
                                                  fillMode: Image.PreserveAspectFit
                                                  smooth: true
                                                  visible: parent.parent.width > 20 && parent.parent.height > 20
                                              }

                                              Text {
                                                  width: parent.width
                                                  text: {
                                                      var titleStr = model.modelData.title || "";
                                                      return titleStr.length > 15 ? titleStr.substring(0, 13) + "…" : titleStr;
                                                  }
                                                  color: winBlock.isActive ? "#FFFFFF" : Qt.rgba(1,1,1,0.85)
                                                  font {
                                                      family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                                                      pixelSize: Math.max(Math.round(9 * _sf), 8)
                                                      weight: Font.Medium
                                                  }
                                                  elide: Text.ElideRight
                                                  horizontalAlignment: Text.AlignHCenter
                                                  visible: parent.parent.width > 50 && parent.parent.height > 40
                                              }
                                          }

                                         // Hover to show tooltip + click/drag to focus/move
                                         MouseArea {
                                             id: winMouse
                                             anchors.fill: parent
                                             hoverEnabled: true
                                             z: 20

                                             property var dragState: ({ startX: 0, startY: 0, isPossibleDrag: false })

                                             onEntered: {
                                                 if (!airspaceWin.dragActive) {
                                                     airspaceWin.tooltipText = model.modelData.title;
                                                     var mapped = winBlock.mapToItem(overlay, winBlock.width / 2, -8);
                                                     airspaceWin.tooltipX = mapped.x;
                                                     airspaceWin.tooltipY = mapped.y;
                                                     airspaceWin.tooltipVis = true;
                                                 }
                                             }
                                             onExited: {
                                                 airspaceWin.tooltipVis = false;
                                             }
                                             onPressed: function(mouse) {
                                                 if (mouse.button === Qt.LeftButton) {
                                                     dragState.startX = mouse.x;
                                                     dragState.startY = mouse.y;
                                                     dragState.isPossibleDrag = true;
                                                 }
                                             }
                                             onPositionChanged: function(mouse) {
                                                 if (dragState.isPossibleDrag) {
                                                     var dx = mouse.x - dragState.startX;
                                                     var dy = mouse.y - dragState.startY;
                                                     if (Math.abs(dx) > 6 || Math.abs(dy) > 6) {
                                                         if (!airspaceWin.dragActive) {
                                                             airspaceWin.dragActive = true;
                                                             airspaceWin.tooltipVis = false;
                                                             airspaceWin.draggedAddress = model.modelData.address;
                                                             airspaceWin.draggedTitle = model.modelData.title || "";
                                                             airspaceWin.draggedWidth = winBlock.width;
                                                             airspaceWin.draggedHeight = winBlock.height;
                                                             airspaceWin.dragSourceWsId = wsDelegate.workspaceId;
                                                         }
                                                     }
                                                 }
                                                 if (airspaceWin.dragActive) {
                                                     var mapped = winMouse.mapToItem(overlay, mouse.x, mouse.y);
                                                     airspaceWin.dragMouseX = mapped.x;
                                                     airspaceWin.dragMouseY = mapped.y;
                                                     airspaceWin.hoveredTargetWsId = airspaceWin.resolveWorkspaceAt(mapped.x, mapped.y);
                                                 }
                                             }
                                             onReleased: function(mouse) {
                                                 if (mouse.button === Qt.LeftButton) {
                                                     dragState.isPossibleDrag = false;
                                                     if (airspaceWin.dragActive) {
                                                         airspaceWin.dragActive = false;
                                                         var targetWsId = airspaceWin.hoveredTargetWsId;
                                                         var sourceWsId = airspaceWin.dragSourceWsId;
                                                         var addr = airspaceWin.draggedAddress;
                                                         if (targetWsId !== -1 && targetWsId !== sourceWsId && addr !== "") {
                                                             Hyprland.dispatch("hl.dsp.window.move({ workspace = \"" + targetWsId.toString() + "\", window = \"address:" + addr + "\" })");
                                                             airspaceWin.refresh();
                                                         }
                                                         airspaceWin.hoveredTargetWsId = -1;
                                                         airspaceWin.draggedAddress = "";
                                                     }
                                                 }
                                             }
                                             onClicked: function(mouse) {
                                                 if (!airspaceWin.dragActive) {
                                                     if (mouse.button === Qt.RightButton) {
                                                         airspaceWin.closeWindow(model.modelData.address);
                                                     } else {
                                                         airspaceWin.focusWindow(wsDelegate.workspaceId, model.modelData.address);
                                                     }
                                                 }
                                             }
                                             acceptedButtons: Qt.LeftButton | Qt.RightButton
                                         }
                                     }
                                 }
                             }
                        } // wsCard

                        // ── App icons indicator row below card ────────────────────
                        Item {
                            anchors.top:              wsCard.bottom
                            anchors.topMargin:        Math.round(10 * scaleFactor)
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: wsDelegate.cardW
                            height: Math.round(36 * scaleFactor)
                            opacity: airspaceWin.show ? 1.0 : 0.0
                            Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: Math.round(8 * scaleFactor)

                                Repeater {
                                    model: {
                                        var map = {};
                                        var list = [];
                                        for (var i = 0; i < modelData.clients.length; i++) {
                                            var cls = modelData.clients[i].appClass || "unknown";
                                            if (!map[cls]) {
                                                map[cls] = { appClass: cls, count: 0 };
                                                list.push(map[cls]);
                                            }
                                            map[cls].count++;
                                        }
                                        return list;
                                    }
                                    delegate: Item {
                                        width: Math.round(30 * scaleFactor)
                                        height: Math.round(30 * scaleFactor)

                                        Rectangle {
                                            anchors.fill: parent
                                            radius: Math.round(8 * scaleFactor)
                                            color: Qt.rgba(1, 1, 1, 0.08)
                                            border.color: Qt.rgba(1, 1, 1, 0.12)
                                            border.width: 1
                                        }

                                        Image {
                                            anchors.centerIn: parent
                                            width: Math.round(22 * scaleFactor)
                                            height: Math.round(22 * scaleFactor)
                                            source: "image://icon/" + modelData.appClass.toLowerCase()
                                            fillMode: Image.PreserveAspectFit
                                            smooth: true
                                        }

                                        // Count badge if > 1
                                        Rectangle {
                                            visible: modelData.count > 1
                                            anchors.top: parent.top
                                            anchors.right: parent.right
                                            anchors.topMargin: Math.round(-6 * scaleFactor)
                                            anchors.rightMargin: Math.round(-6 * scaleFactor)
                                            width: Math.round(15 * scaleFactor)
                                            height: Math.round(15 * scaleFactor)
                                            radius: Math.round(7.5 * scaleFactor)
                                            color: "#007AFF"
                                            z: 5

                                            Text {
                                                anchors.centerIn: parent
                                                text: modelData.count.toString()
                                                color: "#FFFFFF"
                                                font {
                                                    family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                                                    pixelSize: Math.round(8.5 * scaleFactor)
                                                    bold: true
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Current-workspace pill indicator (macOS style)
                        Rectangle {
                            anchors.top:              wsCard.bottom
                            anchors.topMargin:        Math.round(46 * scaleFactor)
                            anchors.horizontalCenter: parent.horizontalCenter
                            width:                    Math.round(24 * scaleFactor)
                            height:                   Math.round(4 * scaleFactor)
                            radius:                   Math.round(2 * scaleFactor)
                            color:                    "#007AFF"
                            visible:                  wsDelegate.isCurrent
                        }

                    } // wsDelegate
                } // Repeater
            } // Grid of cards
        } // Column

        // ── Floating tooltip ─────────────────────────────────────────────
        Rectangle {
            id: tooltip
            enabled: false // Completely ignore mouse events so it never steals hover or click focus
            visible: airspaceWin.tooltipVis && airspaceWin.tooltipText !== ""
            x: Math.max(8, Math.min(airspaceWin.tooltipX - width / 2, overlay.width - width - 8))
            y: Math.max(8, airspaceWin.tooltipY - height - 4)
            z: 100

            width:  tooltipLabel.implicitWidth + Math.round(20 * scaleFactor)
            height: tooltipLabel.implicitHeight + Math.round(10 * scaleFactor)
            radius: Math.round(8 * scaleFactor)
            color:  Qt.rgba(0.05, 0.05, 0.10, 0.92)
            border.color: Qt.rgba(1,1,1,0.18)
            border.width: 1

            Text {
                id: tooltipLabel
                anchors.centerIn: parent
                text: airspaceWin.tooltipText
                color: "#FFFFFF"
                font {
                    family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                    pixelSize: Math.round(12 * scaleFactor)
                    weight: Font.Medium
                }
            }
        }

        // ── Floating drag proxy ──────────────────────────────────────────
        Rectangle {
            id: dragProxy
            visible: airspaceWin.dragActive
            x: airspaceWin.dragMouseX - width / 2
            y: airspaceWin.dragMouseY - height / 2
            width: airspaceWin.draggedWidth
            height: airspaceWin.draggedHeight
            radius: Math.round(5 * airspaceWin.scaleFactor)
            color: Qt.rgba(0.0, 0.478, 1.0, 0.60)
            border.color: "#FFFFFF"
            border.width: 1.5
            z: 200

            Text {
                anchors.centerIn: parent
                width: parent.width - Math.round(8 * airspaceWin.scaleFactor)
                text: airspaceWin.draggedTitle
                color: "#FFFFFF"
                font {
                    family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                    pixelSize: Math.max(Math.round(11 * airspaceWin.scaleFactor), 9)
                    weight: Font.Medium
                }
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignHCenter
            }
        }
    } // overlay
}
