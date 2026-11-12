import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io

PanelWindow {
    id: selectorWindow

    property var shellRoot: null
    readonly property real scaleFactor: shellRoot ? shellRoot.scaleFactor : 1.0
    readonly property real fontScale: scaleFactor * (shellRoot ? shellRoot.fontSizeMultiplier : 1.0)

    property bool show: false
    property string targetMode: "sel" // "sel", "edit", "ocr", "record"

    // Selection Geometry
    property real selX: 0
    property real selY: 0
    property real selW: 0
    property real selH: 0

    property bool isSelecting: false
    property bool isResizing: false
    property bool isMoving: false
    property bool hasSelection: false

    readonly property bool hasActiveBox: (hasSelection || isSelecting) && (selW > 2 && selH > 2)

    property real dragStartX: 0
    property real dragStartY: 0
    property real moveStartMouseX: 0
    property real moveStartMouseY: 0
    property real moveStartSelX: 0
    property real moveStartSelY: 0
    property int resizeHandle: -1 // 0=TL, 1=TR, 2=BR, 3=BL, 4=T, 5=R, 6=B, 7=L

    // Current Mouse Cursor Position for Loupe
    property real cursorX: 0
    property real cursorY: 0

    // Screen Dimensions
    readonly property real screenW: selectorWindow.width > 0 ? selectorWindow.width : (Screen.width > 0 ? Screen.width : 1920)
    readonly property real screenH: selectorWindow.height > 0 ? selectorWindow.height : (Screen.height > 0 ? Screen.height : 1080)

    // Window Snapping Data
    property var windowBoxes: []
    property var hoveredWindowBox: null

    // Layer-Shell Setup
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: show ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.namespace: "quickshell_selector"
    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    visible: show || rootAnim.opacity > 0.01

    // ── Screencopy Snapshot Freeze Engine ─────────────────────────────────────
    Timer {
        id: screencopySnapshotTimer
        interval: 60
        repeat: false
        onTriggered: {
            screenBackdrop.live = false;
        }
    }

    onShowChanged: {
        if (show) {
            screenBackdrop.live = true;
            screencopySnapshotTimer.restart();
        } else {
            screenBackdrop.live = false;
        }
    }

    // ── Fetch Hyprland Windows for Smart Snapping ─────────────────────────────
    Process {
        id: pGetClients
        command: ["hyprctl", "clients", "-j"]
        stdout: SplitParser {
            onRead: data => {
                try {
                    var parsed = JSON.parse(data);
                    var list = [];
                    for (var i = 0; i < parsed.length; i++) {
                        var w = parsed[i];
                        if (w.mapped && !w.hidden && w.size && w.size[0] > 10 && w.size[1] > 10) {
                            list.push({
                                x: w.at[0],
                                y: w.at[1],
                                w: w.size[0],
                                h: w.size[1],
                                title: w.title || w.class || "Window",
                                appClass: w.class || ""
                            });
                        }
                    }
                    selectorWindow.windowBoxes = list;
                } catch(e) {}
            }
        }
    }

    // ── Open / Close Management ───────────────────────────────────────────────
    function open(mode) {
        targetMode = mode || "sel";
        hasSelection = false;
        isSelecting = false;
        isResizing = false;
        isMoving = false;
        hoveredWindowBox = null;
        selX = 0; selY = 0; selW = 0; selH = 0;

        // 1. Capture pristine frame at this exact instant
        screenBackdrop.live = true;
        screencopySnapshotTimer.restart();

        // 2. Query Hyprland windows for snapping
        pGetClients.running = true;

        // 3. Reveal overlay
        show = true;
    }

    function dismiss() {
        show = false;
        screenBackdrop.live = false;
        hasSelection = false;
        isSelecting = false;
        isResizing = false;
        isMoving = false;
    }

    // ── Execution Pipeline (Grim / Satty / OCR / wf-recorder) ─────────────────
    Process { id: pExec }

    function confirmSelection(actionOverride) {
        var act = actionOverride || targetMode;
        var cropX = Math.round(Math.min(selX, selX + selW));
        var cropY = Math.round(Math.min(selY, selY + selH));
        var cropW = Math.round(Math.abs(selW));
        var cropH = Math.round(Math.abs(selH));

        if (cropW < 4 || cropH < 4) {
            dismiss();
            return;
        }

        var geom = cropX + "," + cropY + " " + cropW + "x" + cropH;
        var dirImg = "/home/krishna/Pictures/screenshots";
        var dateStr = Qt.formatDateTime(new Date(), "yyyy_MM_dd_hhmmss");
        var finalImg = dirImg + "/" + dateStr + ".png";
        var rawImg = "/tmp/raw_shot_" + dateStr + ".png";

        dismiss();

        // Run action after layer dismisses
        var timer = Qt.createQmlObject('import QtQuick; Timer { interval: 60; repeat: false; }', selectorWindow);
        timer.triggered.connect(function() {
            if (act === "edit") {
                pExec.command = ["bash", "-c", "mkdir -p " + dirImg + " && grim -g '" + geom + "' " + rawImg + " && (command -v satty &>/dev/null && satty --filename " + rawImg + " --output-filename " + finalImg + " --early-exit && (command -v wl-copy &>/dev/null && wl-copy < " + finalImg + ") && canberra-gtk-play -i camera-shutter || mv " + rawImg + " " + finalImg + ")"];
                pExec.running = true;
            } else if (act === "ocr") {
                pExec.command = ["bash", "-c", "mkdir -p /tmp/ocr && grim -g '" + geom + "' /tmp/ocr/ocr_snap.png && python3 /home/krishna/dotfiles/scripts/shot-helper.py --ocr /tmp/ocr/ocr_snap.png | (command -v wl-copy &>/dev/null && wl-copy) && notify-send 'OCR Extracted' 'Text copied to clipboard'"];
                pExec.running = true;
            } else if (act === "record") {
                pExec.command = ["/home/krishna/dotfiles/scripts/screenshot.sh", "--record-geom", geom];
                pExec.running = true;
            } else {
                // Default Copy & Save
                pExec.command = ["bash", "-c", "mkdir -p " + dirImg + " && grim -g '" + geom + "' " + finalImg + " && (command -v wl-copy &>/dev/null && wl-copy < " + finalImg + ") && canberra-gtk-play -i camera-shutter && notify-send -i " + finalImg + " 'Screenshot Captured' 'Saved to " + finalImg + "'"];
                pExec.running = true;
            }
            timer.destroy();
        });
        timer.start();
    }

    // ── Keyboard Navigation ───────────────────────────────────────────────────
    Item {
        focus: true
        Keys.onEscapePressed: selectorWindow.dismiss()
        Keys.onReturnPressed: selectorWindow.confirmSelection()
        Keys.onSpacePressed: selectorWindow.confirmSelection()
        Keys.onPressed: event => {
            if (!hasSelection) return;
            var step = (event.modifiers & Qt.ShiftModifier) ? 10 : 1;
            if (event.key === Qt.Key_Left) { selX = Math.max(0, selX - step); event.accepted = true; }
            else if (event.key === Qt.Key_Right) { selX = Math.min(screenW - selW, selX + step); event.accepted = true; }
            else if (event.key === Qt.Key_Up) { selY = Math.max(0, selY - step); event.accepted = true; }
            else if (event.key === Qt.Key_Down) { selY = Math.min(screenH - selH, selY + step); event.accepted = true; }
            else if (event.key === Qt.Key_C) { confirmSelection("sel"); event.accepted = true; }
            else if (event.key === Qt.Key_E || event.key === Qt.Key_A) { confirmSelection("edit"); event.accepted = true; }
            else if (event.key === Qt.Key_O) { confirmSelection("ocr"); event.accepted = true; }
            else if (event.key === Qt.Key_R) { confirmSelection("record"); event.accepted = true; }
        }
    }

    // ── Main UI Layout ────────────────────────────────────────────────────────
    Item {
        id: rootAnim
        anchors.fill: parent
        opacity: show ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutQuad } }

        // =====================================================================
        // 0. FROZEN SCREENSHOT BACKDROP (Freezes all video & screen motion)
        // =====================================================================
        ScreencopyView {
            id: screenBackdrop
            captureSource: Quickshell.screens[0]
            live: false
            paintCursor: false
            anchors.fill: parent
            z: 1
            visible: true
        }

        // =====================================================================
        // 1. SPATIAL OBSIDIAN VEIL (4-Rect Inverted Mask - 100% Crisp Cutout Inside)
        // =====================================================================
        Item {
            anchors.fill: parent
            z: 10

            // Top veil
            Rectangle {
                x: 0; y: 0; width: selectorWindow.screenW
                height: selectorWindow.hasActiveBox ? Math.max(0, selectorWindow.selY) : selectorWindow.screenH
                color: "#04060a"
                opacity: 0.50
            }
            // Bottom veil
            Rectangle {
                visible: selectorWindow.hasActiveBox
                x: 0; y: selectorWindow.selY + selectorWindow.selH
                width: selectorWindow.screenW
                height: Math.max(0, selectorWindow.screenH - (selectorWindow.selY + selectorWindow.selH))
                color: "#04060a"
                opacity: 0.50
            }
            // Left veil
            Rectangle {
                visible: selectorWindow.hasActiveBox
                x: 0; y: selectorWindow.selY
                width: Math.max(0, selectorWindow.selX)
                height: selectorWindow.selH
                color: "#04060a"
                opacity: 0.50
            }
            // Right veil
            Rectangle {
                visible: selectorWindow.hasActiveBox
                x: selectorWindow.selX + selectorWindow.selW
                y: selectorWindow.selY
                width: Math.max(0, selectorWindow.screenW - (selectorWindow.selX + selectorWindow.selW))
                height: selectorWindow.selH
                color: "#04060a"
                opacity: 0.50
            }
        }

        // =====================================================================
        // 2. BLUEPRINT WINDOW SNAPPING GHOST (CAD Wireframe Preview)
        // =====================================================================
        Rectangle {
            id: snapGhost
            z: 15
            visible: !selectorWindow.hasSelection && !selectorWindow.isSelecting && selectorWindow.hoveredWindowBox !== null
            x: selectorWindow.hoveredWindowBox ? selectorWindow.hoveredWindowBox.x : 0
            y: selectorWindow.hoveredWindowBox ? selectorWindow.hoveredWindowBox.y : 0
            width: selectorWindow.hoveredWindowBox ? selectorWindow.hoveredWindowBox.w : 0
            height: selectorWindow.hoveredWindowBox ? selectorWindow.hoveredWindowBox.h : 0
            radius: 0
            color: Qt.rgba(0.039, 0.518, 1.0, 0.06)
            border.color: "#0A84FF"
            border.width: 1

            Behavior on x { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }
            Behavior on y { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }
            Behavior on width { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }
            Behavior on height { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }

            // Window Title Badge (Berkeley Monospace)
            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.margins: 6
                height: 20 * selectorWindow.scaleFactor
                width: ghostLabel.implicitWidth + 12
                radius: 2
                color: "#0B0C0E"
                border.color: "#0A84FF"
                border.width: 1

                Text {
                    id: ghostLabel
                    anchors.centerIn: parent
                    text: selectorWindow.hoveredWindowBox ? ("[ WIN: " + (selectorWindow.hoveredWindowBox.appClass || selectorWindow.hoveredWindowBox.title) + " ]") : ""
                    color: "#0A84FF"
                    font.pixelSize: 10 * selectorWindow.fontScale
                    font.family: "Geist Mono, JetBrains Mono, monospace"
                    font.bold: true
                }
            }
        }

        // =====================================================================
        // 3. TECHNICAL CAD CUTOUT SELECTION (Zero Shaders, Pure Precision)
        // =====================================================================
        Item {
            id: selectionSheet
            z: 20
            visible: selectorWindow.hasActiveBox
            x: selectorWindow.selX
            y: selectorWindow.selY
            width: selectorWindow.selW
            height: selectorWindow.selH

            // 1px Hairline Technical Border
            Rectangle {
                anchors.fill: parent
                radius: 0
                color: "transparent"
                border.color: "#0A84FF"
                border.width: 1
            }

            // CAD Technical Corner Ticks: ┌ ┐ └ ┘ (12×12px, 2px stroke)
            // Top-Left ┌
            Rectangle { x: 0; y: 0; width: 12; height: 2; color: "#0A84FF" }
            Rectangle { x: 0; y: 0; width: 2; height: 12; color: "#0A84FF" }

            // Top-Right ┐
            Rectangle { x: parent.width - 12; y: 0; width: 12; height: 2; color: "#0A84FF" }
            Rectangle { x: parent.width - 2; y: 0; width: 2; height: 12; color: "#0A84FF" }

            // Bottom-Left └
            Rectangle { x: 0; y: parent.height - 2; width: 12; height: 2; color: "#0A84FF" }
            Rectangle { x: 0; y: parent.height - 12; width: 2; height: 12; color: "#0A84FF" }

            // Bottom-Right ┘
            Rectangle { x: parent.width - 12; y: parent.height - 2; width: 12; height: 2; color: "#0A84FF" }
            Rectangle { x: parent.width - 2; y: parent.height - 12; width: 2; height: 12; color: "#0A84FF" }

            // Center Reticle Crosshair (+)
            Rectangle {
                anchors.centerIn: parent
                width: 14; height: 1
                color: Qt.rgba(0.039, 0.518, 1.0, 0.6)
                visible: selectionSheet.width > 40 && selectionSheet.height > 40
            }
            Rectangle {
                anchors.centerIn: parent
                width: 1; height: 14
                color: Qt.rgba(1, 0.69, 0, 0.6)
                visible: selectionSheet.width > 40 && selectionSheet.height > 40
            }

            // Monospace Dimension Telemetry Badge: [ 840 × 420 px ]
            Rectangle {
                anchors.left: parent.left
                anchors.bottom: parent.top
                anchors.bottomMargin: 4
                height: 20 * selectorWindow.scaleFactor
                width: dimRow.implicitWidth + 10
                radius: 2
                color: "#0B0C0E"
                border.color: "#0A84FF"
                border.width: 1

                RowLayout {
                    id: dimRow
                    anchors.centerIn: parent
                    spacing: 4
                    Text {
                        text: "[ " + Math.round(selectorWindow.selW) + " × " + Math.round(selectorWindow.selH) + " px ]"
                        color: "#0A84FF"
                        font.pixelSize: 10 * selectorWindow.fontScale
                        font.family: "Geist Mono, JetBrains Mono, monospace"
                        font.bold: true
                    }
                }
            }

            // 8 CAD Micro Square Handles
            Repeater {
                model: 8
                Rectangle {
                    id: handle
                    z: 30
                    width: 7; height: 7
                    radius: 0
                    color: "#0A84FF"
                    border.color: "#0B0C0E"
                    border.width: 1

                    // Positions: 0=TL, 1=TR, 2=BR, 3=BL, 4=T, 5=R, 6=B, 7=L
                    x: (index === 0 || index === 3 || index === 7) ? -3 :
                       (index === 1 || index === 2 || index === 5) ? selectionSheet.width - 4 :
                       selectionSheet.width / 2 - 3
                    y: (index === 0 || index === 1 || index === 4) ? -3 :
                       (index === 2 || index === 3 || index === 6) ? selectionSheet.height - 4 :
                       selectionSheet.height / 2 - 3

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -4
                        cursorShape: (index === 0 || index === 2) ? Qt.SizeFDiagCursor :
                                     (index === 1 || index === 3) ? Qt.SizeBDiagCursor :
                                     (index === 4 || index === 6) ? Qt.SizeVerCursor : Qt.SizeHorCursor
                        onPressed: mouse => {
                            selectorWindow.isResizing = true;
                            selectorWindow.resizeHandle = index;
                            selectorWindow.dragStartX = mouse.x;
                            selectorWindow.dragStartY = mouse.y;
                            var curGlobal = handle.mapToItem(null, mouse.x, mouse.y);
                            selectorWindow.cursorX = curGlobal.x;
                            selectorWindow.cursorY = curGlobal.y;
                        }
                        onReleased: {
                            selectorWindow.isResizing = false;
                            selectorWindow.resizeHandle = -1;
                        }
                        onPositionChanged: mouse => {
                            if (!selectorWindow.isResizing) return;
                            var curGlobal = handle.mapToItem(null, mouse.x, mouse.y);
                            var gx = curGlobal.x;
                            var gy = curGlobal.y;
                            selectorWindow.cursorX = gx;
                            selectorWindow.cursorY = gy;

                            if (index === 0) { // TL
                                var newW = (selectorWindow.selX + selectorWindow.selW) - gx;
                                var newH = (selectorWindow.selY + selectorWindow.selH) - gy;
                                if (newW > 10) { selectorWindow.selX = gx; selectorWindow.selW = newW; }
                                if (newH > 10) { selectorWindow.selY = gy; selectorWindow.selH = newH; }
                            } else if (index === 1) { // TR
                                var newW = gx - selectorWindow.selX;
                                var newH = (selectorWindow.selY + selectorWindow.selH) - gy;
                                if (newW > 10) { selectorWindow.selW = newW; }
                                if (newH > 10) { selectorWindow.selY = gy; selectorWindow.selH = newH; }
                            } else if (index === 2) { // BR
                                var newW = gx - selectorWindow.selX;
                                var newH = gy - selectorWindow.selY;
                                if (newW > 10) { selectorWindow.selW = newW; }
                                if (newH > 10) { selectorWindow.selH = newH; }
                            } else if (index === 3) { // BL
                                var newW = (selectorWindow.selX + selectorWindow.selW) - gx;
                                var newH = gy - selectorWindow.selY;
                                if (newW > 10) { selectorWindow.selX = gx; selectorWindow.selW = newW; }
                                if (newH > 10) { selectorWindow.selH = newH; }
                            } else if (index === 4) { // T
                                var newH = (selectorWindow.selY + selectorWindow.selH) - gy;
                                if (newH > 10) { selectorWindow.selY = gy; selectorWindow.selH = newH; }
                            } else if (index === 5) { // R
                                var newW = gx - selectorWindow.selX;
                                if (newW > 10) { selectorWindow.selW = newW; }
                            } else if (index === 6) { // B
                                var newH = gy - selectorWindow.selY;
                                if (newH > 10) { selectorWindow.selH = newH; }
                            } else if (index === 7) { // L
                                var newW = (selectorWindow.selX + selectorWindow.selW) - gx;
                                if (newW > 10) { selectorWindow.selX = gx; selectorWindow.selW = newW; }
                            }
                        }
                    }
                }
            }

            // Move Area (Middle Drag reposition)
            MouseArea {
                anchors.fill: parent
                anchors.margins: 14
                cursorShape: Qt.SizeAllCursor
                onDoubleClicked: selectorWindow.confirmSelection()
                onPressed: mouse => {
                    selectorWindow.isMoving = true;
                    selectorWindow.moveStartMouseX = mouse.x;
                    selectorWindow.moveStartMouseY = mouse.y;
                    selectorWindow.moveStartSelX = selectorWindow.selX;
                    selectorWindow.moveStartSelY = selectorWindow.selY;
                    var curGlobal = mapToItem(null, mouse.x, mouse.y);
                    selectorWindow.cursorX = curGlobal.x;
                    selectorWindow.cursorY = curGlobal.y;
                }
                onReleased: selectorWindow.isMoving = false
                onPositionChanged: mouse => {
                    if (!selectorWindow.isMoving) return;
                    var curGlobal = mapToItem(null, mouse.x, mouse.y);
                    selectorWindow.cursorX = curGlobal.x;
                    selectorWindow.cursorY = curGlobal.y;
                    var dx = mouse.x - selectorWindow.moveStartMouseX;
                    var dy = mouse.y - selectorWindow.moveStartMouseY;
                    selectorWindow.selX = Math.max(0, Math.min(selectorWindow.screenW - selectorWindow.selW, selectorWindow.selX + dx));
                    selectorWindow.selY = Math.max(0, Math.min(selectorWindow.screenH - selectorWindow.selH, selectorWindow.selY + dy));
                }
            }
        }

        // =====================================================================
        // 4. PRECISION MAGNIFIER LOUPE (Subpixel Zoom & Monospace Coordinates)
        // =====================================================================
        Item {
            id: precisionLoupe
            z: 45
            visible: selectorWindow.isSelecting || selectorWindow.isResizing
            x: Math.max(20, Math.min(selectorWindow.screenW - width - 20, selectorWindow.cursorX + 24))
            y: Math.max(20, Math.min(selectorWindow.screenH - height - 20, selectorWindow.cursorY + 24))
            width: 110 * selectorWindow.scaleFactor
            height: 120 * selectorWindow.scaleFactor

            Rectangle {
                anchors.fill: parent
                radius: 4
                color: "#0B0C0E"
                border.color: Qt.rgba(1, 1, 1, 0.15)
                border.width: 1

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 6
                    spacing: 4

                    // Magnified Texture Window
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 80 * selectorWindow.scaleFactor
                        radius: 2
                        clip: true
                        color: "#000000"
                        border.color: Qt.rgba(1, 1, 1, 0.12)
                        border.width: 1

                        ShaderEffectSource {
                            id: loupeZoom
                            sourceItem: screenBackdrop
                            live: true
                            smooth: false // Crisp nearest-neighbor pixels!
                            readonly property real zoomW: 40
                            readonly property real zoomH: 30
                            sourceRect: Qt.rect(
                                Math.max(0, selectorWindow.cursorX - zoomW / 2),
                                Math.max(0, selectorWindow.cursorY - zoomH / 2),
                                zoomW, zoomH
                            )
                            anchors.fill: parent
                        }

                        // Precision Crosshair
                        Rectangle { anchors.centerIn: parent; width: parent.width; height: 1; color: Qt.rgba(1, 0.69, 0, 0.85) }
                        Rectangle { anchors.centerIn: parent; width: 1; height: parent.height; color: Qt.rgba(1, 0.69, 0, 0.85) }
                        Rectangle { anchors.centerIn: parent; width: 5; height: 5; color: "transparent"; border.color: "#ffffff"; border.width: 1 }
                    }

                    // Monospace Coordinate Pill
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "[ X:" + Math.round(selectorWindow.cursorX) + " Y:" + Math.round(selectorWindow.cursorY) + " ]"
                        color: "#0A84FF"
                        font.pixelSize: 9 * selectorWindow.fontScale
                        font.family: "Geist Mono, JetBrains Mono, monospace"
                        font.bold: true
                    }
                }
            }
        }

        // =====================================================================
        // 5. TEENAGE ENGINEERING TECHNICAL ACTION DOCK
        // =====================================================================
        Item {
            id: actionHud
            z: 50
            visible: selectorWindow.hasSelection && !selectorWindow.isSelecting
            opacity: visible ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }

            // Position HUD below selection; if too close to bottom edge, flip above
            readonly property bool flipAbove: (selectorWindow.selY + selectorWindow.selH + 58) > selectorWindow.screenH
            x: Math.max(16, Math.min(selectorWindow.screenW - width - 16, selectorWindow.selX + (selectorWindow.selW - width) / 2))
            y: flipAbove ? Math.max(16, selectorWindow.selY - height - 14) : (selectorWindow.selY + selectorWindow.selH + 14)
            width: hudContent.implicitWidth + 16
            height: hudContent.implicitHeight + 10

            Rectangle {
                anchors.fill: parent
                radius: 4
                color: "#0B0C0E"
                border.color: Qt.rgba(1, 1, 1, 0.15)
                border.width: 1

                RowLayout {
                    id: hudContent
                    anchors.centerIn: parent
                    spacing: 6

                    // Action Buttons (Copy, Annotate, OCR, Record)
                    Repeater {
                        model: [
                            { icon: "󰄀", label: "COPY",     key: "↵", act: "sel",    color: "#0A84FF", isPrimary: true },
                            { icon: "󰏫", label: "ANNOTATE", key: "E", act: "edit",   color: "#BF5AF2", isPrimary: false },
                            { icon: "󱃩", label: "OCR",      key: "O", act: "ocr",    color: "#FF9F0A", isPrimary: false },
                            { icon: "󰕧", label: "RECORD",   key: "R", act: "record", color: "#FF453A", isPrimary: false }
                        ]

                        Rectangle {
                            id: btn
                            Layout.preferredHeight: 28 * selectorWindow.scaleFactor
                            Layout.preferredWidth: btnRow.implicitWidth + 14
                            radius: 2
                            color: btnHover.containsPress ? Qt.rgba(1, 1, 1, 0.16) : (btnHover.containsMouse ? (modelData.isPrimary ? Qt.rgba(0.039, 0.518, 1.0, 0.30) : Qt.rgba(1, 1, 1, 0.10)) : (modelData.isPrimary ? Qt.rgba(0.039, 0.518, 1.0, 0.18) : Qt.rgba(1, 1, 1, 0.04)))
                            border.color: modelData.isPrimary ? "#0A84FF" : (btnHover.containsMouse ? Qt.rgba(1, 1, 1, 0.25) : Qt.rgba(1, 1, 1, 0.10))
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: 80 } }
                            Behavior on border.color { ColorAnimation { duration: 80 } }

                            RowLayout {
                                id: btnRow
                                anchors.centerIn: parent
                                spacing: 5
                                Text { text: modelData.icon; color: modelData.color; font.pixelSize: 12 * selectorWindow.fontScale }
                                Text {
                                    text: modelData.label
                                    color: "#FFFFFF"
                                    font.pixelSize: 10 * selectorWindow.fontScale
                                    font.family: "Geist Mono, JetBrains Mono, monospace"
                                    font.bold: true
                                }
                                Rectangle {
                                    Layout.preferredHeight: 14
                                    Layout.preferredWidth: keyText.implicitWidth + 6
                                    radius: 1
                                    color: Qt.rgba(0, 0, 0, 0.50)
                                    border.color: Qt.rgba(255, 255, 255, 0.15)
                                    border.width: 1
                                    Text {
                                        id: keyText
                                        anchors.centerIn: parent
                                        text: modelData.key
                                        color: Qt.rgba(1, 1, 1, 0.70)
                                        font.pixelSize: 8 * selectorWindow.fontScale
                                        font.family: "Geist Mono, JetBrains Mono, monospace"
                                        font.bold: true
                                    }
                                }
                            }

                            MouseArea {
                                id: btnHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: selectorWindow.confirmSelection(modelData.act)
                            }
                        }
                    }

                    // Cancel Button
                    Rectangle {
                        Layout.preferredHeight: 28 * selectorWindow.scaleFactor
                        Layout.preferredWidth: 28 * selectorWindow.scaleFactor
                        radius: 2
                        color: cancelHover.containsPress ? Qt.rgba(1, 1, 1, 0.16) : (cancelHover.containsMouse ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.04))
                        border.color: Qt.rgba(1, 1, 1, 0.10)
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "󰅖"
                            color: "#FFFFFF"
                            font.pixelSize: 12 * selectorWindow.fontScale
                        }

                        MouseArea {
                            id: cancelHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: selectorWindow.dismiss()
                        }
                    }
                }
            }
        }

        // =====================================================================
        // 6. MASTER BACKGROUND DRAG MOUSE AREA
        // =====================================================================
        MouseArea {
            id: masterMouse
            anchors.fill: parent
            z: 5
            hoverEnabled: true
            cursorShape: Qt.CrossCursor

            onPositionChanged: mouse => {
                selectorWindow.cursorX = mouse.x;
                selectorWindow.cursorY = mouse.y;

                // Window Hover Snapping (When not yet dragging)
                if (!selectorWindow.isSelecting && !selectorWindow.hasSelection) {
                    var found = null;
                    for (var i = 0; i < selectorWindow.windowBoxes.length; i++) {
                        var box = selectorWindow.windowBoxes[i];
                        if (mouse.x >= box.x && mouse.x <= (box.x + box.w) &&
                            mouse.y >= box.y && mouse.y <= (box.y + box.h)) {
                            found = box;
                            break;
                        }
                    }
                    selectorWindow.hoveredWindowBox = found;
                }

                // Drag Selection
                if (selectorWindow.isSelecting) {
                    var x1 = Math.min(selectorWindow.dragStartX, mouse.x);
                    var y1 = Math.min(selectorWindow.dragStartY, mouse.y);
                    var x2 = Math.max(selectorWindow.dragStartX, mouse.x);
                    var y2 = Math.max(selectorWindow.dragStartY, mouse.y);

                    selectorWindow.selX = x1;
                    selectorWindow.selY = y1;
                    selectorWindow.selW = Math.max(2, x2 - x1);
                    selectorWindow.selH = Math.max(2, y2 - y1);
                }
            }

            onPressed: mouse => {
                selectorWindow.cursorX = mouse.x;
                selectorWindow.cursorY = mouse.y;
                selectorWindow.dragStartX = mouse.x;
                selectorWindow.dragStartY = mouse.y;
                selectorWindow.selX = mouse.x;
                selectorWindow.selY = mouse.y;
                selectorWindow.selW = 2;
                selectorWindow.selH = 2;
                selectorWindow.isSelecting = true;
                selectorWindow.hasSelection = false;
            }

            onReleased: mouse => {
                if (selectorWindow.isSelecting) {
                    selectorWindow.isSelecting = false;
                    // If simple click without dragging on a hovered window: snap to window!
                    if (selectorWindow.selW < 12 && selectorWindow.selH < 12 && selectorWindow.hoveredWindowBox !== null) {
                        var wb = selectorWindow.hoveredWindowBox;
                        selectorWindow.selX = wb.x;
                        selectorWindow.selY = wb.y;
                        selectorWindow.selW = wb.w;
                        selectorWindow.selH = wb.h;
                        selectorWindow.hasSelection = true;
                    } else if (selectorWindow.selW > 10 && selectorWindow.selH > 10) {
                        selectorWindow.hasSelection = true;
                    } else {
                        selectorWindow.hasSelection = false;
                    }
                }
            }
        }
    }
}
