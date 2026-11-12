import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "Singletons"
import "Character"

PanelWindow {
    id: rootWindow

    // ══════════════════════════════════════════════════════════════════
    // 1. PUBLIC INTEGRATION PROPERTIES (shell.qml & MinimoBlob API)
    // ══════════════════════════════════════════════════════════════════
    property var shellRoot: null
    readonly property real scaleFactor: shellRoot ? shellRoot.scaleFactor : 1.0
    readonly property real fontScale: shellRoot ? shellRoot.fontScale : 1.0

    // Minimo Character Theme Properties
    readonly property color minimoSphereColor: (shellRoot && shellRoot.minimoBotMode === "light")
        ? "#FFFFFF"
        : ((shellRoot && shellRoot.isPearlMode) ? "#F0F0F5" : "#24262f")
    readonly property color minimoEyeColor: (shellRoot && shellRoot.minimoBotMode === "light")
        ? "#121215"
        : ((shellRoot && shellRoot.isPearlMode) ? "#121215" : "#FFFFFF")

    property bool show: false
    property bool isClosing: false
    readonly property bool isAgentRunning: agentProcess.running

    // Core 3-State Machine: "input" -> "thinking" -> "result"
    property string engineState: "input"

    // Telemetry & Intent Deductions
    property int currentStage: 0
    property string stageText: ""
    property string deducedIntent: ""
    property real deducedConfidence: 0.0
    property string deducedTitle: ""
    property string deducedPriority: "P2"
    property string deducedDue: ""
    property string deducedDesc: ""
    property string deducedModel: "Qwen 2.5 1.5B"
    property var stageLogs: []
    property real telemetryElapsedMs: 0
    property real thinkingStartTime: 0

    // Synthesis & Results
    property string lastExecutedQuery: ""
    property string streamedResponse: ""
    property string sheetAccent: "#00F5FF"
    property string sheetIcon: "󰘳"
    property string sheetTitle: "Minimo Knowledge"
    property int selectedCardIndex: 0
    property bool copySuccess: false
    property bool taskSuccess: false

    // Action Palette & Peeking
    property bool isActionMenuOpen: false
    property bool isAltPeek: false
    property bool isThinkingExpandedManual: false
    readonly property bool isThinkingExpanded: (isAgentRunning && engineState === "thinking") || isThinkingExpandedManual || isAltPeek

    // Card categorization helpers
    readonly property bool isTodoCreation: deducedIntent === "add_task" || (actionCardsModel.count === 1 && actionCardsModel.get(0).card_type === "todoist")
    readonly property bool isTasksList: deducedIntent === "list_tasks" || (actionCardsModel.count > 0 && actionCardsModel.get(0).card_type === "task") || (actionCardsModel.count > 1 && actionCardsModel.get(0).card_type === "todoist")
    readonly property bool isCommandCard: deducedIntent === "run_cmd" || (actionCardsModel.count > 0 && actionCardsModel.get(0).card_type === "command")
    readonly property bool hasSourcesAtBottom: actionCardsModel.count > 0 && !isTodoCreation && !isTasksList && !isClarifyActive && !isCommandCard

    // Clarification State
    property var clarificationOptions: []
    property string clarificationPrompt: ""
    property int selectedClarifyIndex: 0
    readonly property bool isClarifyActive: clarificationOptions && clarificationOptions.length > 0

    // Undo State
    property real undoTimeRemaining: 0.0
    property bool isUndone: false

    // Fullscreen Overlay
    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true
    color: "transparent"
    visible: show || isClosing

    // Layer-shell geometry
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: (show && !isClosing) ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // Only route clicks inside the animated card
    mask: Region {
        item: animRect
    }

    ScreencopyView {
        id: localScreenBackdrop
        property bool revealContent: false
        captureSource: Quickshell.screens[0]
        live: false
        paintCursor: false
        width: Screen.width > 0 ? Screen.width : 1920
        height: Screen.height > 0 ? Screen.height : 1080
        z: -999
        visible: false
    }

    Timer {
        id: screencopySnapshotTimer
        interval: 40
        repeat: false
        onTriggered: localScreenBackdrop.revealContent = true
    }

    Timer {
        id: preCaptureDelayTimer
        interval: 40
        repeat: false
        onTriggered: {
            localScreenBackdrop.captureFrame();
            screencopySnapshotTimer.restart();
        }
    }

    onShowChanged: {
        if (show) {
            isClosing = false;
            localScreenBackdrop.revealContent = false;
            preCaptureDelayTimer.restart();
            resetToInput();
            openAnim.restart();
            telemetryTimer.start();
        } else {
            localScreenBackdrop.revealContent = false;
            preCaptureDelayTimer.stop();
            screencopySnapshotTimer.stop();
            isClosing = true;
            closeTimer.restart();
        }
    }

    Timer {
        id: closeTimer
        interval: 160
        onTriggered: {
            rootWindow.isClosing = false;
            if (agentProcess.running) agentProcess.running = false;
        }
    }

    Timer {
        id: telemetryTimer
        interval: 50
        running: rootWindow.show && rootWindow.isAgentRunning
        repeat: true
        onTriggered: {
            if (rootWindow.thinkingStartTime > 0) {
                rootWindow.telemetryElapsedMs = Date.now() - rootWindow.thinkingStartTime;
            }
        }
    }

    Timer {
        id: undoDecayTimer
        interval: 100
        running: rootWindow.show && rootWindow.undoTimeRemaining > 0 && !rootWindow.isUndone
        repeat: true
        onTriggered: {
            rootWindow.undoTimeRemaining = Math.max(0, rootWindow.undoTimeRemaining - 0.1);
        }
    }

    Timer {
        id: copyResetTimer
        interval: 2000
        onTriggered: rootWindow.copySuccess = false
    }

    Timer {
        id: typingSquintTimer
        interval: 1200
        onTriggered: {
            if (agentAvatar) {
                agentAvatar.squint = 0;
                agentAvatar.idleY = 0;
            }
        }
    }

    // ══════════════════════════════════════════════════════════════════
    // 2. ACTIONS & AGENT BRIDGE
    // ══════════════════════════════════════════════════════════════════
    ListModel {
        id: actionCardsModel
    }

    ListModel {
        id: thinkingStepsModel
    }

    function addOrUpdateStep(stage, name, text, intent, details) {
        var icon = "󰘦";
        var accent = "#89B4FA";
        var badge = "STAGE " + (stage !== undefined ? stage : 0);
        var title = name || text || "Reasoning step";
        var desc = text || "";

        if (stage === 0) {
            icon = "󰘦";
            accent = "#89B4FA";
            badge = "STAGE 0 · CONTEXT";
        } else if (stage === 1) {
            icon = "󰘥";
            accent = "#A855F7";
            badge = "STAGE 1 · ROUTING";
        } else if (stage === 2) {
            badge = "STAGE 2 · DEDUCED";
            if (intent === "list_tasks" || intent === "add_task" || intent === "complete_task") {
                icon = "󰄬";
                accent = "#10B981";
            } else if (intent === "email_summary") {
                icon = "󰇮";
                accent = "#60A5FA";
            } else if (intent === "chat") {
                icon = "󰭹";
                accent = "#F59E0B";
            } else if (intent === "run_cmd") {
                icon = "󰆍";
                accent = "#EC4899";
            } else {
                icon = "⚡";
                accent = "#00F5FF";
            }
        } else {
            icon = "⚡";
            accent = "#10B981";
            badge = "ACTION";
        }

        if (details) {
            var detailParts = [];
            if (details.model) detailParts.push("Model: " + details.model);
            if (details.confidence !== undefined) detailParts.push("Conf: " + (details.confidence * 100).toFixed(0) + "%");
            if (details.title) detailParts.push("Task: " + details.title);
            if (details.due) detailParts.push("Due: " + details.due);
            if (details.priority) detailParts.push("Priority: P" + details.priority);
            if (detailParts.length > 0) {
                desc = (desc ? desc + " · " : "") + detailParts.join(" · ");
            }
        }

        var foundIdx = -1;
        for (var i = 0; i < thinkingStepsModel.count; ++i) {
            if (thinkingStepsModel.get(i).title === title) {
                foundIdx = i;
                break;
            }
        }
        if (foundIdx >= 0) {
            thinkingStepsModel.setProperty(foundIdx, "desc", desc);
            thinkingStepsModel.setProperty(foundIdx, "icon", icon);
            thinkingStepsModel.setProperty(foundIdx, "accent", accent);
            thinkingStepsModel.setProperty(foundIdx, "badge", badge);
        } else {
            thinkingStepsModel.append({
                title: title,
                desc: desc,
                icon: icon,
                accent: accent,
                badge: badge
            });
        }
    }

    function resetToInput() {
        if (agentProcess.running) agentProcess.running = false;
        engineState = "input";
        currentStage = 0;
        stageText = "";
        deducedIntent = "";
        deducedConfidence = 0.0;
        deducedTitle = "";
        deducedPriority = "P2";
        deducedDue = "";
        deducedDesc = "";
        stageLogs = [];
        telemetryElapsedMs = 0;
        streamedResponse = "";
        sheetAccent = "#00F5FF";
        sheetIcon = "󰘳";
        sheetTitle = "Minimo Knowledge";
        selectedCardIndex = 0;
        isActionMenuOpen = false;
        isAltPeek = false;
        isThinkingExpandedManual = false;
        undoTimeRemaining = 0.0;
        isUndone = false;
        taskSuccess = false;
        clarificationOptions = [];
        clarificationPrompt = "";
        selectedClarifyIndex = 0;
        actionCardsModel.clear();
        thinkingStepsModel.clear();
        if (inputPrompt) {
            inputPrompt.text = "";
            inputPrompt.forceActiveFocus();
        }
        CharacterBus.react("greet");
    }

    function runAgentQuery(q) {
        if (!q || !q.trim()) return;
        var query = q.trim();
        lastExecutedQuery = query;
        if (inputPrompt) inputPrompt.text = query;

        // Reset stage
        actionCardsModel.clear();
        thinkingStepsModel.clear();
        clarificationOptions = [];
        clarificationPrompt = "";
        selectedClarifyIndex = 0;
        streamedResponse = "";
        currentStage = 0;
        stageText = "Analyzing context...";
        deducedIntent = "";
        deducedConfidence = 0.0;
        deducedTitle = "";
        deducedPriority = "P2";
        deducedDue = "";
        deducedDesc = "";
        stageLogs = [];
        telemetryElapsedMs = 0;
        thinkingStartTime = Date.now();
        undoTimeRemaining = 0.0;
        isUndone = false;
        taskSuccess = false;
        isActionMenuOpen = false;
        selectedCardIndex = 0;
        engineState = "thinking";
        CharacterBus.react("curious");

        agentProcess.command = [
            "python3",
            "/home/krishna/dotfiles/quickshell/scripts/mind_pilot_agent.py",
            "--query",
            query,
            "--delay",
            "1.2"
        ];
        agentProcess.running = true;
    }

    function triggerUndo() {
        if (undoTimeRemaining <= 0 || isUndone) return;
        isUndone = true;
        undoTimeRemaining = 0.0;
        if (actionCardsModel.count > 0) {
            actionCardsModel.setProperty(0, "badge", "UNDONE");
            actionCardsModel.setProperty(0, "subtitle", "Creation cancelled");
        }
        streamedResponse = "Action reverted: Task was cancelled and removed.\n\n— *Reverted by Kafka*";
        executeAction("delete_task", deducedTitle || "task");
    }

    function executeAction(actionType, actionPayload) {
        if (!actionType) return;
        actionExecProcess.command = [
            "python3",
            "/home/krishna/dotfiles/quickshell/scripts/mind_pilot_agent.py",
            "--exec",
            actionType,
            String(actionPayload)
        ];
        actionExecProcess.running = true;
        CharacterBus.react("hop");
    }

    function executeSelectedCard(idx) {
        if (actionCardsModel.count === 0) {
            // Copy streamed response fallback
            if (streamedResponse) {
                executeAction("copy", streamedResponse);
                copySuccess = true;
                copyResetTimer.restart();
            }
            return;
        }
        var i = Math.max(0, Math.min(actionCardsModel.count - 1, idx));
        var card = actionCardsModel.get(i);
        if (!card) return;

        if (card.card_type === "command") {
            if (card.status === "pending_approval") {
                rootWindow.runAgentQuery("confirm " + rootWindow.lastExecutedQuery);
            } else {
                var payloadToCopy = (card.stdout || card.stderr || card.command || card.title);
                executeAction("copy", payloadToCopy);
                copySuccess = true;
                copyResetTimer.restart();
            }
            return;
        }

        var actType = card.action_type || "complete_task";
        var actPayload = card.action_payload || card.title;

        if (actType === "complete_task") {
            taskSuccess = true;
            actionCardsModel.setProperty(i, "badge", "✓ DONE");
            executeAction("complete_task", actPayload);
        } else if (actType === "copy") {
            executeAction("copy", actPayload);
            copySuccess = true;
            copyResetTimer.restart();
        } else {
            executeAction(actType, actPayload);
        }
    }

    Process {
        id: agentProcess
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (data) => {
                var line = data.trim();
                if (!line) return;
                try {
                    var obj = JSON.parse(line);
                    if (obj.type === "stage") {
                        if (obj.stage !== undefined) rootWindow.currentStage = obj.stage;
                        if (obj.text) rootWindow.stageText = obj.text;
                        if (obj.intent) rootWindow.deducedIntent = obj.intent;
                        if (obj.confidence !== undefined) rootWindow.deducedConfidence = obj.confidence;
                        if (obj.details) {
                            if (obj.details.title) rootWindow.deducedTitle = obj.details.title;
                            if (obj.details.priority) rootWindow.deducedPriority = "P" + obj.details.priority;
                            if (obj.details.due) rootWindow.deducedDue = obj.details.due;
                            if (obj.details.description) rootWindow.deducedDesc = obj.details.description;
                            if (obj.details.model) rootWindow.deducedModel = obj.details.model;
                        }
                        var logs = rootWindow.stageLogs.slice();
                        var sText = obj.text || (obj.name ? obj.name : "");
                        if (sText && (logs.length === 0 || logs[logs.length - 1] !== sText)) {
                            logs.push(sText);
                            rootWindow.stageLogs = logs;
                        }
                        rootWindow.addOrUpdateStep(obj.stage, obj.name, obj.text, obj.intent || rootWindow.deducedIntent, obj.details);
                    } else if (obj.type === "phase") {
                        if (obj.accent) rootWindow.sheetAccent = obj.accent;
                    } else if (obj.type === "status") {
                        if (obj.text) {
                            rootWindow.stageText = obj.text;
                            var sLogs = rootWindow.stageLogs.slice();
                            if (sLogs.length === 0 || sLogs[sLogs.length - 1] !== obj.text) {
                                sLogs.push(obj.text);
                                rootWindow.stageLogs = sLogs;
                            }
                            rootWindow.addOrUpdateStep(3, "Action & Telemetry", obj.text, rootWindow.deducedIntent, null);
                        }
                        if (obj.reaction) {
                            if (typeof agentAvatar !== "undefined" && agentAvatar) agentAvatar.react(obj.reaction);
                            if (typeof thinkingAvatar !== "undefined" && thinkingAvatar) thinkingAvatar.react(obj.reaction);
                            CharacterBus.react(obj.reaction);
                        }
                    } else if (obj.type === "layout") {
                        if (obj.accent) rootWindow.sheetAccent = obj.accent;
                        if (obj.icon) rootWindow.sheetIcon = obj.icon;
                        if (obj.title) rootWindow.sheetTitle = obj.title;
                        if (obj.format === "clarify") {
                            rootWindow.clarificationPrompt = obj.prompt || "";
                            rootWindow.clarificationOptions = obj.options || [];
                            rootWindow.selectedClarifyIndex = 0;
                            if (rootWindow.engineState === "thinking") {
                                rootWindow.engineState = "result";
                            }
                        }
                    } else if (obj.type === "action_dispatched") {
                        if (obj.intent === "add_task") {
                            rootWindow.undoTimeRemaining = 4.0;
                            rootWindow.isUndone = false;
                        }
                    } else if (obj.type === "action_card") {
                        actionCardsModel.append(obj);
                    } else if (obj.type === "token") {
                        rootWindow.streamedResponse += obj.text;
                        if (rootWindow.engineState === "thinking") {
                            rootWindow.engineState = "result";
                        }
                    } else if (obj.type === "done") {
                        rootWindow.engineState = "result";
                        if (typeof agentAvatar !== "undefined" && agentAvatar) agentAvatar.react("happyBounce");
                        if (typeof thinkingAvatar !== "undefined" && thinkingAvatar) thinkingAvatar.react("happyBounce");
                        CharacterBus.react("happyBounce");
                    }
                } catch(e) {}
            }
        }
    }

    Process {
        id: actionExecProcess
    }

    // Backdrop dismissal
    MouseArea {
        anchors.fill: parent
        onClicked: {
            rootWindow.show = false;
        }
    }

    // ══════════════════════════════════════════════════════════════════
    // 3. RAYCAST CONTAINER (animRect with dynamic height physics)
    // ══════════════════════════════════════════════════════════════════
    Rectangle {
        id: animRect
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(180 * scaleFactor)
        width: Math.round(740 * scaleFactor)
        height: rootWindow.engineState === "input"
            ? Math.round(74 * scaleFactor)
            : Math.min(Math.round(640 * scaleFactor), Math.max(Math.round(260 * scaleFactor), Math.round(contentCol.implicitHeight + (144 * scaleFactor))))

        radius: Math.round(16 * scaleFactor)
        color: "transparent"
        border.color: rootWindow.engineState !== "input" ? Qt.rgba(rootWindow.sheetAccent.r, rootWindow.sheetAccent.g, rootWindow.sheetAccent.b, 0.35) : Qt.rgba(1, 1, 1, 0.08)
        border.width: 1
        clip: true

        Behavior on height {
            NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
        }
        Behavior on border.color { ColorAnimation { duration: 180 } }

        // System Bar Liquid Glass Shader Effect Layer (apple_liquid_glass.frag.qsb)
        SurfaceCard {
            id: pilotGlassCard
            anchors.fill: parent
            backdropItem: localScreenBackdrop
            cornerRadius: animRect.radius
            blurAmount: shellRoot ? shellRoot.glassBlurAmount : 0.20
            refraction: shellRoot ? shellRoot.glassRefraction : 0.38
            bevelMode: shellRoot ? shellRoot.glassBevelMode : 0.0
            zRadius: shellRoot ? shellRoot.glassZRadius : 32.0
            chromaticAberration: shellRoot ? shellRoot.glassChromAberration : 0.025
            edgeHighlight: shellRoot ? shellRoot.glassEdgeHighlight : 0.22
            fresnel: shellRoot ? shellRoot.glassFresnel : 0.85
            brightness: shellRoot ? shellRoot.glassBrightness : -0.22
            saturation: shellRoot ? shellRoot.glassSaturation : 0.0
            glassMode: shellRoot ? shellRoot.glassMode : "dark"
            contentPadding: 0

            // Atmospheric glass tint matching system bar capsules
            Rectangle {
                anchors.fill: parent
                radius: animRect.radius
                color: (shellRoot && shellRoot.glassMode === "regular")
                    ? Qt.rgba(0.04, 0.04, 0.06, 0.10)
                    : ((shellRoot && shellRoot.glassMode === "frosted")
                        ? Qt.rgba(1.0, 1.0, 1.0, 0.08)
                        : ((shellRoot && (shellRoot.isPearlMode || shellRoot.glassMode === "apple_light" || shellRoot.glassMode === "apple_dark")) ? "transparent" : Qt.rgba(0.03, 0.03, 0.06, 0.18)))
                Behavior on color { ColorAnimation { duration: 180 } }
            }
        }

        ParallelAnimation {
            id: openAnim
            NumberAnimation { target: animRect; property: "scale"; from: 0.96; to: 1.0; duration: 160; easing.type: Easing.OutCubic }
            NumberAnimation { target: animRect; property: "opacity"; from: 0.0; to: 1.0; duration: 140; easing.type: Easing.OutCubic }
        }

        // Inner Layout Column
        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // ══════════════════════════════════════════════════════════
            // A. TOP SEARCH INPUT BAR (Height: 52px)
            // ══════════════════════════════════════════════════════════
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.round(52 * scaleFactor)
                color: "transparent"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Math.round(16 * scaleFactor)
                    anchors.rightMargin: Math.round(16 * scaleFactor)
                    spacing: Math.round(12 * scaleFactor)

                    // Minimo Companion Mascot (Teleported into drawer)
                    Character {
                        id: agentAvatar
                        Layout.preferredWidth: Math.round(28 * scaleFactor)
                        Layout.preferredHeight: Math.round(28 * scaleFactor)
                        Layout.alignment: Qt.AlignVCenter
                        size: Math.round(32 * scaleFactor)
                        active: rootWindow.show
                        sphereColor: rootWindow.minimoSphereColor
                        eyeColor: rootWindow.isAgentRunning ? rootWindow.sheetAccent : rootWindow.minimoEyeColor
                        squint: rootWindow.isAgentRunning ? 0.85 : 0.0

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: (mouse) => {
                                var side = (mouse.x > width / 2) ? 1 : -1;
                                agentAvatar.clicked(side);
                            }
                        }
                    }

                    // Main Text Input Field
                    TextField {
                        id: inputPrompt
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        verticalAlignment: TextInput.AlignVCenter
                        font.family: "Inter"
                        font.pixelSize: Math.round(15 * fontScale)
                        color: "#F8FAFC"
                        placeholderText: "Ask Kafka, manage tasks, search notes or library..."
                        placeholderTextColor: Qt.rgba(1, 1, 1, 0.35)
                        background: null
                        selectByMouse: true
                        focus: true

                        onTextEdited: {
                            CharacterBus.typed();
                            if (agentAvatar) {
                                agentAvatar.squint = 0.85;
                                agentAvatar.idleY = 0.40;
                                typingSquintTimer.restart();
                            }
                        }

                        Keys.onPressed: (event) => {
                            // Ctrl+K -> Action Menu
                            if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_K) {
                                if (rootWindow.engineState !== "input") {
                                    rootWindow.isActionMenuOpen = !rootWindow.isActionMenuOpen;
                                } else {
                                    rootWindow.resetToInput();
                                }
                                event.accepted = true;
                                return;
                            }

                            // Ctrl+Z -> Undo
                            if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_Z) {
                                if (rootWindow.undoTimeRemaining > 0 && !rootWindow.isUndone) {
                                    rootWindow.triggerUndo();
                                    event.accepted = true;
                                    return;
                                }
                            }

                            // Down Arrow -> Shift focus to Cards List or Clarify Options
                            if (event.key === Qt.Key_Down) {
                                if (rootWindow.isClarifyActive) {
                                    rootWindow.selectedClarifyIndex = Math.min(rootWindow.clarificationOptions.length - 1, rootWindow.selectedClarifyIndex + 1);
                                    event.accepted = true;
                                    return;
                                } else if (rootWindow.engineState === "result" && actionCardsModel.count > 0) {
                                    cardsListView.forceActiveFocus();
                                    event.accepted = true;
                                    return;
                                }
                            }

                            // Up Arrow -> Clarify Options Navigation
                            if (event.key === Qt.Key_Up && rootWindow.isClarifyActive) {
                                rootWindow.selectedClarifyIndex = Math.max(0, rootWindow.selectedClarifyIndex - 1);
                                event.accepted = true;
                                return;
                            }

                            // Escape Handling
                            if (event.key === Qt.Key_Escape) {
                                if (rootWindow.isActionMenuOpen) {
                                    rootWindow.isActionMenuOpen = false;
                                } else if (rootWindow.engineState !== "input") {
                                    rootWindow.resetToInput();
                                } else if (inputPrompt.text.trim() !== "") {
                                    inputPrompt.text = "";
                                } else {
                                    rootWindow.show = false;
                                }
                                event.accepted = true;
                                return;
                            }

                            // Enter -> Submit Query, Execute Clarification, or Confirm Command
                            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                if (rootWindow.isClarifyActive && rootWindow.clarificationOptions.length > 0) {
                                    var opt = rootWindow.clarificationOptions[rootWindow.selectedClarifyIndex];
                                    if (opt && opt.query) {
                                        rootWindow.runAgentQuery(opt.query);
                                        event.accepted = true;
                                        return;
                                    }
                                }
                                if (rootWindow.isCommandCard && rootWindow.engineState === "result") {
                                    var cmdCard = actionCardsModel.count > 0 ? actionCardsModel.get(0) : null;
                                    if (cmdCard && cmdCard.status === "pending_approval") {
                                        rootWindow.runAgentQuery("confirm " + rootWindow.lastExecutedQuery);
                                        event.accepted = true;
                                        return;
                                    }
                                }
                                if (inputPrompt.text.trim() !== "") {
                                    rootWindow.runAgentQuery(inputPrompt.text.trim());
                                    event.accepted = true;
                                    return;
                                }
                            }

                            // C / Ctrl+C -> Copy command or output
                            if (event.key === Qt.Key_C && rootWindow.engineState === "result" && rootWindow.isCommandCard && (inputPrompt.text.trim() === "" || (event.modifiers & Qt.ControlModifier))) {
                                var cObj = actionCardsModel.count > 0 ? actionCardsModel.get(0) : null;
                                if (cObj) {
                                    var toCopy = (cObj.status === "executed" && (cObj.stdout || cObj.stderr)) ? (cObj.stdout || cObj.stderr) : (cObj.command || cObj.title);
                                    rootWindow.executeAction("copy", toCopy);
                                    rootWindow.copySuccess = true;
                                    copyResetTimer.restart();
                                    event.accepted = true;
                                    return;
                                }
                            }

                            // T / Ctrl+T -> Open in Kitty terminal
                            if (event.key === Qt.Key_T && rootWindow.engineState === "result" && rootWindow.isCommandCard && (inputPrompt.text.trim() === "" || (event.modifiers & Qt.ControlModifier))) {
                                var tObj = actionCardsModel.count > 0 ? actionCardsModel.get(0) : null;
                                if (tObj) {
                                    rootWindow.executeAction("open_terminal", tObj.command || tObj.title);
                                    event.accepted = true;
                                    return;
                                }
                            }
                        }
                    }

                    // Keycap Hints in Header
                    RowLayout {
                        spacing: Math.round(6 * scaleFactor)

                        Rectangle {
                            Layout.preferredHeight: Math.round(20 * scaleFactor)
                            Layout.preferredWidth: Math.round(36 * scaleFactor)
                            radius: Math.round(4 * scaleFactor)
                            color: Qt.rgba(1, 1, 1, 0.05)
                            border.color: Qt.rgba(1, 1, 1, 0.10)
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: "Esc"
                                font.family: "JetBrains Mono"
                                font.pixelSize: Math.round(9.5 * fontScale)
                                color: Qt.rgba(1, 1, 1, 0.45)
                            }
                        }
                    }
                }
            }

            // 1px Subtle Seam Divider (Visible only when body content exists)
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Qt.rgba(1, 1, 1, 0.08)
                visible: rootWindow.engineState !== "input"
            }

            // ══════════════════════════════════════════════════════════
            // B. SCROLLABLE MAIN CONTENT BODY
            // ══════════════════════════════════════════════════════════
            Item {
                visible: rootWindow.engineState !== "input"
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                Flickable {
                    id: mainFlick
                    anchors.fill: parent
                    anchors.margins: Math.round(14 * scaleFactor)
                    clip: true
                    contentWidth: width
                    contentHeight: contentCol.implicitHeight
                    boundsBehavior: Flickable.StopAtBounds

                    ColumnLayout {
                        id: contentCol
                        width: mainFlick.width
                        spacing: Math.round(14 * scaleFactor)

                        // ──────────────────────────────────────────────
                        // 1. CLAUDE-STYLE REASONING ACCORDION (Raw Text Steps)
                        // ──────────────────────────────────────────────
                        Rectangle {
                            id: thinkingBox
                            Layout.fillWidth: true
                            implicitHeight: Math.max(Math.round(32 * scaleFactor), thinkCol.implicitHeight + (rootWindow.isThinkingExpanded ? Math.round(16 * scaleFactor) : 0))
                            radius: Math.round(8 * scaleFactor)
                            color: rootWindow.isThinkingExpanded ? Qt.rgba(255, 255, 255, 0.03) : "transparent"
                            border.color: rootWindow.isThinkingExpanded ? Qt.rgba(255, 255, 255, 0.10) : "transparent"
                            border.width: rootWindow.isThinkingExpanded ? 1 : 0
                            clip: true

                            ColumnLayout {
                                id: thinkCol
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: rootWindow.isThinkingExpanded ? Math.round(8 * scaleFactor) : 0
                                spacing: Math.round(8 * scaleFactor)

                                // Header Row (Clickable Accordion Trigger)
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: Math.round(32 * scaleFactor)
                                    implicitHeight: Math.round(32 * scaleFactor)
                                    radius: Math.round(6 * scaleFactor)
                                    color: tHvr.containsMouse ? Qt.rgba(255, 255, 255, 0.05) : "transparent"

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: rootWindow.isThinkingExpanded ? 4 : Math.round(4 * scaleFactor)
                                        anchors.rightMargin: Math.round(6 * scaleFactor)
                                        spacing: Math.round(8 * scaleFactor)

                                        // Spinner or subtle bullet
                                        Item {
                                            Layout.preferredWidth: Math.round(16 * scaleFactor)
                                            Layout.preferredHeight: Math.round(16 * scaleFactor)
                                            Layout.alignment: Qt.AlignVCenter

                                            Text {
                                                anchors.centerIn: parent
                                                text: rootWindow.isAgentRunning ? "⟳" : "•"
                                                color: rootWindow.isAgentRunning ? "#00F5FF" : Qt.rgba(1, 1, 1, 0.40)
                                                font.pixelSize: Math.round(13 * fontScale)
                                                font.bold: true

                                                RotationAnimation on rotation {
                                                    running: rootWindow.isAgentRunning
                                                    loops: Animation.Infinite
                                                    from: 0; to: 360
                                                    duration: 900
                                                }
                                            }
                                        }

                                        // Header Text: Running step OR "Thought for X.Xs"
                                        Text {
                                            Layout.fillWidth: true
                                            text: rootWindow.isAgentRunning
                                                ? (rootWindow.stageText || "Reasoning...")
                                                : ("Thought for " + (rootWindow.telemetryElapsedMs / 1000).toFixed(1) + "s")
                                            font.family: "Inter"
                                            font.pixelSize: Math.round(12.5 * fontScale)
                                            font.weight: rootWindow.isAgentRunning ? Font.Normal : Font.Medium
                                            color: rootWindow.isAgentRunning ? Qt.rgba(248/255, 250/255, 252/255, 0.85) : Qt.rgba(1, 1, 1, 0.55)
                                            elide: Text.ElideRight
                                        }

                                        // Elapsed timer while running
                                        Text {
                                            visible: rootWindow.isAgentRunning
                                            text: (rootWindow.telemetryElapsedMs / 1000).toFixed(1) + "s"
                                            font.family: "JetBrains Mono"
                                            font.pixelSize: Math.round(10.5 * fontScale)
                                            color: Qt.rgba(1, 1, 1, 0.40)
                                        }

                                        // Minimal chevron
                                        Text {
                                            text: rootWindow.isThinkingExpanded ? "▴" : "▾"
                                            color: Qt.rgba(1, 1, 1, 0.45)
                                            font.pixelSize: Math.round(12 * fontScale)
                                        }
                                    }

                                    MouseArea {
                                        id: tHvr
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            rootWindow.isThinkingExpandedManual = !rootWindow.isThinkingExpandedManual;
                                        }
                                    }
                                }

                                // Expanded Rope and Knots Stepper Timeline (Kafka Persona Motif)
                                ColumnLayout {
                                    visible: rootWindow.isThinkingExpanded
                                    Layout.fillWidth: true
                                    Layout.leftMargin: Math.round(4 * scaleFactor)
                                    Layout.rightMargin: Math.round(4 * scaleFactor)
                                    Layout.topMargin: Math.round(4 * scaleFactor)
                                    Layout.bottomMargin: Math.round(4 * scaleFactor)
                                    spacing: Math.round(2 * scaleFactor)

                                    Repeater {
                                        model: thinkingStepsModel
                                        delegate: Item {
                                            Layout.fillWidth: true
                                            implicitHeight: knotRow.implicitHeight + Math.round(8 * scaleFactor)

                                            // The Rope / Thread Connecting Line
                                            Rectangle {
                                                visible: index < (thinkingStepsModel.count - 1)
                                                x: Math.round(8.5 * scaleFactor)
                                                y: Math.round(18 * scaleFactor)
                                                width: 1.5
                                                height: parent.height - Math.round(6 * scaleFactor)
                                                color: Qt.rgba(168/255, 85/255, 247/255, 0.35)
                                            }

                                            RowLayout {
                                                id: knotRow
                                                anchors.left: parent.left
                                                anchors.right: parent.right
                                                anchors.top: parent.top
                                                spacing: Math.round(10 * scaleFactor)

                                                // Knot Bead Node
                                                Item {
                                                    Layout.preferredWidth: Math.round(18 * scaleFactor)
                                                    Layout.preferredHeight: Math.round(18 * scaleFactor)
                                                    Layout.alignment: Qt.AlignTop

                                                    Rectangle {
                                                        anchors.centerIn: parent
                                                        width: Math.round(18 * scaleFactor)
                                                        height: Math.round(18 * scaleFactor)
                                                        radius: width / 2
                                                        color: Qt.rgba(15/255, 17/255, 26/255, 0.95)
                                                        border.color: model.accent
                                                        border.width: 1.5

                                                        Text {
                                                            anchors.centerIn: parent
                                                            text: model.icon
                                                            font.family: "Symbols Nerd Font"
                                                            font.pixelSize: Math.round(9.5 * fontScale)
                                                            color: model.accent
                                                        }
                                                    }
                                                }

                                                // Knot Content & Parameters
                                                ColumnLayout {
                                                    Layout.fillWidth: true
                                                    spacing: Math.round(2 * scaleFactor)

                                                    RowLayout {
                                                        Layout.fillWidth: true
                                                        spacing: Math.round(6 * scaleFactor)

                                                        Text {
                                                            text: model.title
                                                            font.family: "Inter"
                                                            font.pixelSize: Math.round(12 * fontScale)
                                                            font.weight: Font.SemiBold
                                                            color: "#F8FAFC"
                                                            elide: Text.ElideRight
                                                        }

                                                        Rectangle {
                                                            radius: 3
                                                            implicitWidth: bTxt.implicitWidth + 8
                                                            implicitHeight: bTxt.implicitHeight + 2
                                                            color: Qt.rgba(1, 1, 1, 0.08)
                                                            border.color: Qt.rgba(1, 1, 1, 0.12)
                                                            border.width: 1

                                                            Text {
                                                                id: bTxt
                                                                anchors.centerIn: parent
                                                                text: model.badge
                                                                font.family: "JetBrains Mono"
                                                                font.pixelSize: Math.round(8 * fontScale)
                                                                font.weight: Font.Bold
                                                                color: model.accent
                                                            }
                                                        }

                                                        Item { Layout.fillWidth: true }
                                                    }

                                                    Text {
                                                        visible: model.desc && model.desc !== model.title
                                                        Layout.fillWidth: true
                                                        text: model.desc
                                                        font.family: "Inter"
                                                        font.pixelSize: Math.round(11 * fontScale)
                                                        color: Qt.rgba(248/255, 250/255, 252/255, 0.65)
                                                        wrapMode: Text.Wrap
                                                        lineHeight: 1.25
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    // Fallback when no step items registered yet
                                    Item {
                                        visible: thinkingStepsModel.count === 0
                                        Layout.fillWidth: true
                                        implicitHeight: fbRow.implicitHeight + Math.round(4 * scaleFactor)

                                        RowLayout {
                                            id: fbRow
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            spacing: Math.round(10 * scaleFactor)

                                            Rectangle {
                                                width: Math.round(18 * scaleFactor)
                                                height: Math.round(18 * scaleFactor)
                                                radius: width / 2
                                                color: Qt.rgba(15/255, 17/255, 26/255, 0.95)
                                                border.color: "#89B4FA"
                                                border.width: 1.5

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "󰘦"
                                                    font.family: "Symbols Nerd Font"
                                                    font.pixelSize: Math.round(9.5 * fontScale)
                                                    color: "#89B4FA"
                                                }
                                            }

                                            Text {
                                                Layout.fillWidth: true
                                                text: rootWindow.stageText || "Tracing threads in context..."
                                                font.family: "Inter"
                                                font.pixelSize: Math.round(12 * fontScale)
                                                color: Qt.rgba(248/255, 250/255, 252/255, 0.70)
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // ──────────────────────────────────────────────
                        // 1.5 CLARIFICATION INTERACTIVE OPTIONS
                        // ──────────────────────────────────────────────
                        ColumnLayout {
                            id: clarifyContainer
                            visible: rootWindow.isClarifyActive
                            Layout.fillWidth: true
                            spacing: Math.round(10 * scaleFactor)

                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: clarCol.implicitHeight + Math.round(20 * scaleFactor)
                                radius: Math.round(10 * scaleFactor)
                                color: Qt.rgba(245/255, 158/255, 11/255, 0.10)
                                border.color: Qt.rgba(245/255, 158/255, 11/255, 0.35)
                                border.width: 1

                                ColumnLayout {
                                    id: clarCol
                                    anchors.fill: parent
                                    anchors.margins: Math.round(12 * scaleFactor)
                                    spacing: Math.round(8 * scaleFactor)

                                    RowLayout {
                                        spacing: Math.round(8 * scaleFactor)
                                        Text {
                                            text: "󰘦"
                                            font.family: "Symbols Nerd Font"
                                            font.pixelSize: Math.round(14 * fontScale)
                                            color: "#F59E0B"
                                        }
                                        Text {
                                            text: rootWindow.clarificationPrompt || "Clarification needed"
                                            font.family: "Inter"
                                            font.pixelSize: Math.round(13 * fontScale)
                                            font.weight: Font.SemiBold
                                            color: "#F8FAFC"
                                            wrapMode: Text.Wrap
                                            Layout.fillWidth: true
                                        }
                                    }

                                    Repeater {
                                        model: rootWindow.clarificationOptions
                                        Rectangle {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: Math.round(36 * scaleFactor)
                                            radius: Math.round(6 * scaleFactor)
                                            color: (index === rootWindow.selectedClarifyIndex)
                                                ? Qt.rgba(245/255, 158/255, 11/255, 0.22)
                                                : (cOptHvr.containsMouse ? Qt.rgba(255, 255, 255, 0.08) : Qt.rgba(255, 255, 255, 0.03))
                                            border.color: (index === rootWindow.selectedClarifyIndex) ? "#F59E0B" : Qt.rgba(255, 255, 255, 0.08)
                                            border.width: 1

                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.leftMargin: Math.round(10 * scaleFactor)
                                                anchors.rightMargin: Math.round(10 * scaleFactor)
                                                spacing: Math.round(8 * scaleFactor)

                                                Rectangle {
                                                    width: Math.round(18 * scaleFactor)
                                                    height: Math.round(18 * scaleFactor)
                                                    radius: 3
                                                    color: Qt.rgba(1, 1, 1, 0.08)
                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: String(index + 1)
                                                        font.family: "JetBrains Mono"
                                                        font.pixelSize: Math.round(9.5 * fontScale)
                                                        font.bold: true
                                                        color: index === rootWindow.selectedClarifyIndex ? "#F59E0B" : Qt.rgba(1, 1, 1, 0.5)
                                                    }
                                                }

                                                Text {
                                                    text: modelData.label || modelData.query || ""
                                                    font.family: "Inter"
                                                    font.pixelSize: Math.round(12 * fontScale)
                                                    color: "#F8FAFC"
                                                    Layout.fillWidth: true
                                                    elide: Text.ElideRight
                                                }
                                            }

                                            MouseArea {
                                                id: cOptHvr
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    rootWindow.selectedClarifyIndex = index;
                                                    if (modelData.query) {
                                                        rootWindow.runAgentQuery(modelData.query);
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }


                        // ──────────────────────────────────────────────
                        // 3. REFINED TODO CREATION CARD (Linear / Things 3 Grade)
                        // ──────────────────────────────────────────────
                        Rectangle {
                            id: todoCreatedCard
                            visible: rootWindow.isTodoCreation
                            Layout.fillWidth: true
                            implicitHeight: todoCol.implicitHeight + Math.round(36 * scaleFactor)
                            radius: Math.round(14 * scaleFactor)
                            color: rootWindow.isUndone ? Qt.rgba(239/255, 68/255, 68/255, 0.08) : Qt.rgba(16/255, 185/255, 129/255, 0.08)
                            border.color: rootWindow.isUndone ? "#EF4444" : Qt.rgba(16/255, 185/255, 129/255, 0.35)
                            border.width: 1
                            clip: true

                            // 4-second transient undo progress bar
                            Rectangle {
                                anchors.bottom: parent.bottom
                                anchors.left: parent.left
                                height: 2.5
                                width: parent.width * (rootWindow.undoTimeRemaining / 4.0)
                                color: rootWindow.isUndone ? "#EF4444" : "#10B981"
                                visible: rootWindow.undoTimeRemaining > 0 && !rootWindow.isUndone
                            }

                            ColumnLayout {
                                id: todoCol
                                anchors.fill: parent
                                anchors.margins: Math.round(16 * scaleFactor)
                                spacing: Math.round(12 * scaleFactor)

                                // Header Row: Status badge & Undo keycap
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: Math.round(8 * scaleFactor)

                                    Rectangle {
                                        Layout.preferredHeight: Math.round(22 * scaleFactor)
                                        Layout.preferredWidth: stBadgeRow.implicitWidth + Math.round(16 * scaleFactor)
                                        radius: Math.round(6 * scaleFactor)
                                        color: rootWindow.isUndone ? Qt.rgba(239/255, 68/255, 68/255, 0.15) : Qt.rgba(16/255, 185/255, 129/255, 0.15)
                                        border.color: rootWindow.isUndone ? "#EF4444" : Qt.rgba(16/255, 185/255, 129/255, 0.40)
                                        border.width: 1

                                        RowLayout {
                                            id: stBadgeRow
                                            anchors.centerIn: parent
                                            spacing: Math.round(5 * scaleFactor)

                                            Text {
                                                text: rootWindow.isUndone ? "✕" : "󰄬"
                                                font.family: "Symbols Nerd Font"
                                                font.pixelSize: Math.round(11 * fontScale)
                                                color: rootWindow.isUndone ? "#EF4444" : "#10B981"
                                            }

                                            Text {
                                                text: rootWindow.isUndone ? "TASK CANCELLED & REMOVED" : "TASK ADDED TO TODOIST"
                                                font.family: "Inter"
                                                font.pixelSize: Math.round(10 * fontScale)
                                                font.weight: Font.Bold
                                                color: rootWindow.isUndone ? "#EF4444" : "#10B981"
                                            }
                                        }
                                    }

                                    Item { Layout.fillWidth: true }

                                    // Clean Undo Button (Only while countdown active)
                                    Rectangle {
                                        visible: rootWindow.undoTimeRemaining > 0 && !rootWindow.isUndone
                                        Layout.preferredHeight: Math.round(22 * scaleFactor)
                                        Layout.preferredWidth: undoBtnTxt.implicitWidth + Math.round(14 * scaleFactor)
                                        radius: Math.round(5 * scaleFactor)
                                        color: uHvr.containsMouse ? Qt.rgba(239/255, 68/255, 68/255, 0.25) : Qt.rgba(239/255, 68/255, 68/255, 0.12)
                                        border.color: "#EF4444"
                                        border.width: 1

                                        Text {
                                            id: undoBtnTxt
                                            anchors.centerIn: parent
                                            text: "[Ctrl+Z] Undo " + Math.ceil(rootWindow.undoTimeRemaining) + "s"
                                            color: "#EF4444"
                                            font.family: "JetBrains Mono"
                                            font.pixelSize: Math.round(10 * fontScale)
                                            font.weight: Font.Bold
                                        }

                                        MouseArea {
                                            id: uHvr; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                            onClicked: rootWindow.triggerUndo()
                                        }
                                    }
                                }

                                // Interactive Task Title with Tactile Checkbox
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: Math.round(12 * scaleFactor)

                                    Rectangle {
                                        Layout.preferredWidth: Math.round(22 * scaleFactor)
                                        Layout.preferredHeight: Math.round(22 * scaleFactor)
                                        radius: Math.round(6 * scaleFactor)
                                        color: rootWindow.taskSuccess ? Qt.rgba(16/255, 185/255, 129/255, 0.25) : (checkHvr.containsMouse ? Qt.rgba(16/255, 185/255, 129/255, 0.15) : Qt.rgba(255, 255, 255, 0.05))
                                        border.color: rootWindow.taskSuccess ? "#10B981" : (checkHvr.containsMouse ? "#10B981" : Qt.rgba(255, 255, 255, 0.25))
                                        border.width: 1.5

                                        Text {
                                            anchors.centerIn: parent
                                            text: rootWindow.taskSuccess ? "✓" : ""
                                            font.family: "Symbols Nerd Font"
                                            font.pixelSize: Math.round(12 * fontScale)
                                            color: "#10B981"
                                        }

                                        MouseArea {
                                            id: checkHvr
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: rootWindow.executeSelectedCard(0)
                                        }
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: rootWindow.deducedTitle || (actionCardsModel.count > 0 ? actionCardsModel.get(0).title : rootWindow.lastExecutedQuery)
                                        font.family: "Inter"
                                        font.pixelSize: Math.round(16 * fontScale)
                                        font.weight: Font.Bold
                                        color: rootWindow.taskSuccess ? Qt.rgba(1, 1, 1, 0.40) : "#F8FAFC"
                                        font.strikeout: rootWindow.taskSuccess
                                        elide: Text.ElideRight
                                    }
                                }

                                // Specific Fields: Priority, Due Date, Project, Assignee Chips
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: Math.round(6 * scaleFactor)

                                    // Priority Chip (Flag + Label)
                                    Rectangle {
                                        property string pText: {
                                            if (actionCardsModel.count > 0 && actionCardsModel.get(0).priority) {
                                                return "P" + actionCardsModel.get(0).priority;
                                            }
                                            return rootWindow.deducedPriority || "P3";
                                        }
                                        property color pColor: pText.indexOf("1") >= 0 ? "#EF4444" : (pText.indexOf("2") >= 0 ? "#F59E0B" : (pText.indexOf("3") >= 0 ? "#3B82F6" : "#94A3B8"))
                                        radius: Math.round(5 * scaleFactor)
                                        implicitWidth: pCol.implicitWidth + Math.round(14 * scaleFactor)
                                        implicitHeight: Math.round(24 * scaleFactor)
                                        color: Qt.rgba(pColor.r, pColor.g, pColor.b, 0.14)
                                        border.color: Qt.rgba(pColor.r, pColor.g, pColor.b, 0.35)
                                        border.width: 1

                                        RowLayout {
                                            id: pCol
                                            anchors.centerIn: parent
                                            spacing: Math.round(5 * scaleFactor)
                                            Text {
                                                text: "󰀨"
                                                font.family: "Symbols Nerd Font"
                                                font.pixelSize: Math.round(10.5 * fontScale)
                                                color: parent.parent.pColor
                                            }
                                            Text {
                                                text: parent.parent.pText.indexOf("1") >= 0 ? "P1 Urgent" : (parent.parent.pText.indexOf("2") >= 0 ? "P2 High" : (parent.parent.pText.indexOf("3") >= 0 ? "P3 Medium" : "P4 Normal"))
                                                font.family: "JetBrains Mono"
                                                font.pixelSize: Math.round(9.5 * fontScale)
                                                font.weight: Font.SemiBold
                                                color: parent.parent.pColor
                                            }
                                        }
                                    }

                                    // Due Date Chip (Calendar + Relative Date)
                                    Rectangle {
                                        property string dText: {
                                            if (actionCardsModel.count > 0 && actionCardsModel.get(0).due) {
                                                return actionCardsModel.get(0).due;
                                            }
                                            return rootWindow.deducedDue || "Today";
                                        }
                                        radius: Math.round(5 * scaleFactor)
                                        implicitWidth: dCol.implicitWidth + Math.round(14 * scaleFactor)
                                        implicitHeight: Math.round(24 * scaleFactor)
                                        color: Qt.rgba(0, 245/255, 255/255, 0.12)
                                        border.color: Qt.rgba(0, 245/255, 255/255, 0.32)
                                        border.width: 1

                                        RowLayout {
                                            id: dCol
                                            anchors.centerIn: parent
                                            spacing: Math.round(5 * scaleFactor)
                                            Text {
                                                text: "󰸗"
                                                font.family: "Symbols Nerd Font"
                                                font.pixelSize: Math.round(11 * fontScale)
                                                color: "#00F5FF"
                                            }
                                            Text {
                                                text: (parent.parent.dText.toLowerCase().indexOf("due") >= 0) ? parent.parent.dText : ("Due " + parent.parent.dText)
                                                font.family: "JetBrains Mono"
                                                font.pixelSize: Math.round(9.5 * fontScale)
                                                font.weight: Font.Medium
                                                color: "#00F5FF"
                                            }
                                        }
                                    }

                                    // Project Chip (Folder + Project Name)
                                    Rectangle {
                                        property string prjText: {
                                            if (actionCardsModel.count > 0 && actionCardsModel.get(0).project) {
                                                return actionCardsModel.get(0).project;
                                            }
                                            return "Inbox";
                                        }
                                        radius: Math.round(5 * scaleFactor)
                                        implicitWidth: prjCol.implicitWidth + Math.round(14 * scaleFactor)
                                        implicitHeight: Math.round(24 * scaleFactor)
                                        color: Qt.rgba(168/255, 85/255, 247/255, 0.12)
                                        border.color: Qt.rgba(168/255, 85/255, 247/255, 0.32)
                                        border.width: 1

                                        RowLayout {
                                            id: prjCol
                                            anchors.centerIn: parent
                                            spacing: Math.round(5 * scaleFactor)
                                            Text {
                                                text: "󰉋"
                                                font.family: "Symbols Nerd Font"
                                                font.pixelSize: Math.round(11 * fontScale)
                                                color: "#A855F7"
                                            }
                                            Text {
                                                text: "#" + parent.parent.prjText.replace(/^#/, '')
                                                font.family: "JetBrains Mono"
                                                font.pixelSize: Math.round(9.5 * fontScale)
                                                font.weight: Font.Medium
                                                color: "#A855F7"
                                            }
                                        }
                                    }

                                    // Agent Origin Chip
                                    Rectangle {
                                        radius: Math.round(5 * scaleFactor)
                                        implicitWidth: orgCol.implicitWidth + Math.round(12 * scaleFactor)
                                        implicitHeight: Math.round(24 * scaleFactor)
                                        color: Qt.rgba(255, 255, 255, 0.05)
                                        border.color: Qt.rgba(255, 255, 255, 0.12)
                                        border.width: 1

                                        RowLayout {
                                            id: orgCol
                                            anchors.centerIn: parent
                                            spacing: Math.round(4 * scaleFactor)
                                            Text {
                                                text: "󰄛"
                                                font.family: "Symbols Nerd Font"
                                                font.pixelSize: Math.round(11 * fontScale)
                                                color: Qt.rgba(1, 1, 1, 0.55)
                                            }
                                            Text {
                                                text: "Minimo"
                                                font.family: "JetBrains Mono"
                                                font.pixelSize: Math.round(9 * fontScale)
                                                color: Qt.rgba(1, 1, 1, 0.55)
                                            }
                                        }
                                    }

                                    Item { Layout.fillWidth: true }
                                }

                                // Inset Description / Context Notes Panel (Linear Inset Style)
                                Rectangle {
                                    id: descBox
                                    property string cleanDesc: {
                                        var raw = rootWindow.deducedDesc || (actionCardsModel.count > 0 ? (actionCardsModel.get(0).description || actionCardsModel.get(0).snippet) : "");
                                        var cleaned = (raw || "").replace(/\\n\\n—.*$/, '').replace(/—.*$/, '').trim();
                                        if (cleaned === "Noted by Kafka" || cleaned === "— Noted by Kafka" || cleaned === (rootWindow.deducedTitle || "")) {
                                            return "";
                                        }
                                        return cleaned;
                                    }
                                    visible: cleanDesc.length > 0
                                    Layout.fillWidth: true
                                    implicitHeight: descCol.implicitHeight + Math.round(18 * scaleFactor)
                                    radius: Math.round(8 * scaleFactor)
                                    color: Qt.rgba(0, 0, 0, 0.35)
                                    border.color: Qt.rgba(255, 255, 255, 0.08)
                                    border.width: 1

                                    ColumnLayout {
                                        id: descCol
                                        anchors.fill: parent
                                        anchors.margins: Math.round(12 * scaleFactor)
                                        spacing: Math.round(6 * scaleFactor)

                                        RowLayout {
                                            spacing: Math.round(6 * scaleFactor)
                                            Text {
                                                text: "󰎞"
                                                font.family: "Symbols Nerd Font"
                                                font.pixelSize: Math.round(11 * fontScale)
                                                color: Qt.rgba(1, 1, 1, 0.45)
                                            }
                                            Text {
                                                text: "Context Notes"
                                                font.family: "Inter"
                                                font.pixelSize: Math.round(10.5 * fontScale)
                                                font.weight: Font.SemiBold
                                                color: Qt.rgba(1, 1, 1, 0.50)
                                            }
                                            Item { Layout.fillWidth: true }
                                            Text {
                                                text: "⚡ Arranged by Kafka"
                                                font.family: "JetBrains Mono"
                                                font.pixelSize: Math.round(9 * fontScale)
                                                color: Qt.rgba(168/255, 85/255, 247/255, 0.70)
                                            }
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: descBox.cleanDesc
                                            font.family: "Inter"
                                            font.pixelSize: Math.round(12 * fontScale)
                                            color: Qt.rgba(248/255, 250/255, 252/255, 0.80)
                                            wrapMode: Text.Wrap
                                            lineHeight: 1.35
                                        }
                                    }
                                }
                            }
                        }

                        // ──────────────────────────────────────────────
                        // 3.5. STRUCTURED COMMAND EXECUTION CARD (run_cmd)
                        // ──────────────────────────────────────────────
                        Rectangle {
                            id: commandCard
                            visible: rootWindow.isCommandCard
                            Layout.fillWidth: true
                            implicitHeight: cmdCol.implicitHeight + Math.round(28 * scaleFactor)
                            radius: Math.round(14 * scaleFactor)
                            property var cmdObj: (actionCardsModel.count > 0 && actionCardsModel.get(0).card_type === "command") ? actionCardsModel.get(0) : null
                            property string cmdStr: cmdObj ? (cmdObj.command || cmdObj.title) : (rootWindow.lastExecutedQuery.replace(/^(run\s+|exec\s+|confirm\s+)/i, ''))
                            property string cmdDesc: cmdObj ? (cmdObj.description || cmdObj.subtitle) : "Proposed shell command"
                            property string cmdRisk: cmdObj ? (cmdObj.risk || "safe") : "safe"
                            property string cmdStatus: cmdObj ? (cmdObj.status || "pending_approval") : "pending_approval"
                            property bool isPending: cmdStatus === "pending_approval"
                            property string cmdStdout: cmdObj ? (cmdObj.stdout || "") : ""
                            property string cmdStderr: cmdObj ? (cmdObj.stderr || "") : ""
                            property int exitCode: cmdObj ? (cmdObj.exit_code !== undefined ? cmdObj.exit_code : 0) : 0
                            property bool copiedCmd: false

                            color: isPending ? Qt.rgba(0, 245/255, 255/255, 0.06) : (exitCode === 0 ? Qt.rgba(16/255, 185/255, 129/255, 0.08) : Qt.rgba(239/255, 68/255, 68/255, 0.08))
                            border.color: isPending ? Qt.rgba(0, 245/255, 255/255, 0.35) : (exitCode === 0 ? Qt.rgba(16/255, 185/255, 129/255, 0.40) : Qt.rgba(239/255, 68/255, 68/255, 0.40))
                            border.width: 1
                            clip: true

                            Timer {
                                id: copyFeedbackTimer
                                interval: 2000
                                onTriggered: commandCard.copiedCmd = false
                            }

                            ColumnLayout {
                                id: cmdCol
                                anchors.fill: parent
                                anchors.margins: Math.round(16 * scaleFactor)
                                spacing: Math.round(12 * scaleFactor)

                                // Header Row: Status & Risk Badges
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: Math.round(8 * scaleFactor)

                                    // Status Pill
                                    Rectangle {
                                        Layout.preferredHeight: Math.round(22 * scaleFactor)
                                        Layout.preferredWidth: stPillRow.implicitWidth + Math.round(16 * scaleFactor)
                                        radius: Math.round(6 * scaleFactor)
                                        color: commandCard.isPending ? Qt.rgba(0, 245/255, 255/255, 0.15) : (commandCard.exitCode === 0 ? Qt.rgba(16/255, 185/255, 129/255, 0.15) : Qt.rgba(239/255, 68/255, 68/255, 0.15))
                                        border.color: commandCard.isPending ? "#00F5FF" : (commandCard.exitCode === 0 ? "#10B981" : "#EF4444")
                                        border.width: 1

                                        RowLayout {
                                            id: stPillRow
                                            anchors.centerIn: parent
                                            spacing: Math.round(5 * scaleFactor)

                                            Text {
                                                text: commandCard.isPending ? "󰆍" : (commandCard.exitCode === 0 ? "󰄬" : "󰅚")
                                                font.family: "Symbols Nerd Font"
                                                font.pixelSize: Math.round(11 * fontScale)
                                                color: commandCard.isPending ? "#00F5FF" : (commandCard.exitCode === 0 ? "#10B981" : "#EF4444")
                                            }

                                            Text {
                                                text: commandCard.isPending ? "APPROVAL REQUIRED BEFORE EXECUTION" : (commandCard.exitCode === 0 ? "COMMAND EXECUTED (EXIT 0)" : "EXECUTION FAILED (EXIT " + commandCard.exitCode + ")")
                                                font.family: "Inter"
                                                font.pixelSize: Math.round(10 * fontScale)
                                                font.weight: Font.Bold
                                                color: commandCard.isPending ? "#00F5FF" : (commandCard.exitCode === 0 ? "#10B981" : "#EF4444")
                                            }
                                        }
                                    }

                                    // Risk Level Pill
                                    Rectangle {
                                        property color rCol: commandCard.cmdRisk === "safe" ? "#10B981" : (commandCard.cmdRisk === "mutating" ? "#F59E0B" : "#EF4444")
                                        property string rText: commandCard.cmdRisk === "safe" ? "Read-Only (Safe)" : (commandCard.cmdRisk === "mutating" ? "State Mutating" : "Elevated / Dangerous")
                                        Layout.preferredHeight: Math.round(22 * scaleFactor)
                                        Layout.preferredWidth: rRow.implicitWidth + Math.round(14 * scaleFactor)
                                        radius: Math.round(5 * scaleFactor)
                                        color: Qt.rgba(rCol.r, rCol.g, rCol.b, 0.12)
                                        border.color: Qt.rgba(rCol.r, rCol.g, rCol.b, 0.35)
                                        border.width: 1

                                        RowLayout {
                                            id: rRow
                                            anchors.centerIn: parent
                                            spacing: Math.round(4 * scaleFactor)
                                            Text {
                                                text: parent.parent.cmdRisk === "safe" ? "󰌪" : (parent.parent.cmdRisk === "mutating" ? "󰀦" : "󰅚")
                                                font.family: "Symbols Nerd Font"
                                                font.pixelSize: Math.round(10 * fontScale)
                                                color: parent.parent.rCol
                                            }
                                            Text {
                                                text: parent.parent.rText
                                                font.family: "JetBrains Mono"
                                                font.pixelSize: Math.round(9.5 * fontScale)
                                                font.weight: Font.SemiBold
                                                color: parent.parent.rCol
                                            }
                                        }
                                    }

                                    Item { Layout.fillWidth: true }

                                    // Host/Environment Chip
                                    Rectangle {
                                        Layout.preferredHeight: Math.round(22 * scaleFactor)
                                        Layout.preferredWidth: envRow.implicitWidth + Math.round(12 * scaleFactor)
                                        radius: Math.round(5 * scaleFactor)
                                        color: Qt.rgba(255, 255, 255, 0.05)
                                        border.color: Qt.rgba(255, 255, 255, 0.12)
                                        border.width: 1

                                        RowLayout {
                                            id: envRow
                                            anchors.centerIn: parent
                                            spacing: Math.round(4 * scaleFactor)
                                            Text {
                                                text: "󰞷"
                                                font.family: "Symbols Nerd Font"
                                                font.pixelSize: Math.round(10.5 * fontScale)
                                                color: Qt.rgba(1, 1, 1, 0.60)
                                            }
                                            Text {
                                                text: "bash"
                                                font.family: "JetBrains Mono"
                                                font.pixelSize: Math.round(9 * fontScale)
                                                color: Qt.rgba(1, 1, 1, 0.60)
                                            }
                                        }
                                    }
                                }

                                // Interactive Command Syntax Box (with one-click Copy)
                                Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: cmdBoxRow.implicitHeight + Math.round(20 * scaleFactor)
                                    radius: Math.round(8 * scaleFactor)
                                    color: Qt.rgba(0, 0, 0, 0.45)
                                    border.color: Qt.rgba(0, 245/255, 255/255, 0.25)
                                    border.width: 1

                                    RowLayout {
                                        id: cmdBoxRow
                                        anchors.fill: parent
                                        anchors.leftMargin: Math.round(14 * scaleFactor)
                                        anchors.rightMargin: Math.round(10 * scaleFactor)
                                        spacing: Math.round(10 * scaleFactor)

                                        Text {
                                            text: "$"
                                            font.family: "JetBrains Mono"
                                            font.pixelSize: Math.round(14 * fontScale)
                                            font.weight: Font.Bold
                                            color: "#00F5FF"
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: commandCard.cmdStr
                                            font.family: "JetBrains Mono"
                                            font.pixelSize: Math.round(13 * fontScale)
                                            font.weight: Font.SemiBold
                                            color: "#F8FAFC"
                                            elide: Text.ElideRight
                                        }

                                        // Inset Copy Button
                                        Rectangle {
                                            Layout.preferredHeight: Math.round(26 * scaleFactor)
                                            Layout.preferredWidth: cBtnRow.implicitWidth + Math.round(16 * scaleFactor)
                                            radius: Math.round(5 * scaleFactor)
                                            color: cmdCopyHvr.containsMouse ? Qt.rgba(0, 245/255, 255/255, 0.25) : Qt.rgba(0, 245/255, 255/255, 0.12)
                                            border.color: "#00F5FF"
                                            border.width: 1

                                            RowLayout {
                                                id: cBtnRow
                                                anchors.centerIn: parent
                                                spacing: Math.round(4 * scaleFactor)
                                                Text {
                                                    text: commandCard.copiedCmd ? "✓" : "󰆏"
                                                    font.family: "Symbols Nerd Font"
                                                    font.pixelSize: Math.round(11 * fontScale)
                                                    color: "#00F5FF"
                                                }
                                                Text {
                                                    text: commandCard.copiedCmd ? "Copied" : "Copy"
                                                    font.family: "JetBrains Mono"
                                                    font.pixelSize: Math.round(10 * fontScale)
                                                    font.weight: Font.Bold
                                                    color: "#00F5FF"
                                                }
                                            }

                                            MouseArea {
                                                id: cmdCopyHvr
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    rootWindow.executeAction("copy", commandCard.cmdStr);
                                                    commandCard.copiedCmd = true;
                                                    copyFeedbackTimer.restart();
                                                }
                                            }
                                        }
                                    }
                                }

                                // Purpose / Description Note
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: Math.round(6 * scaleFactor)

                                    Text {
                                        text: "󰋽"
                                        font.family: "Symbols Nerd Font"
                                        font.pixelSize: Math.round(11 * fontScale)
                                        color: Qt.rgba(1, 1, 1, 0.50)
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        text: commandCard.cmdDesc
                                        font.family: "Inter"
                                        font.pixelSize: Math.round(11.5 * fontScale)
                                        color: Qt.rgba(1, 1, 1, 0.65)
                                        wrapMode: Text.Wrap
                                    }
                                }

                                // Execution Output Box (only visible when executed)
                                Rectangle {
                                    visible: !commandCard.isPending && (commandCard.cmdStdout.length > 0 || commandCard.cmdStderr.length > 0)
                                    Layout.fillWidth: true
                                    implicitHeight: Math.min(Math.round(180 * scaleFactor), outCol.implicitHeight + Math.round(18 * scaleFactor))
                                    radius: Math.round(8 * scaleFactor)
                                    color: Qt.rgba(0, 0, 0, 0.50)
                                    border.color: Qt.rgba(255, 255, 255, 0.08)
                                    border.width: 1
                                    clip: true

                                    ColumnLayout {
                                        id: outCol
                                        anchors.fill: parent
                                        anchors.margins: Math.round(10 * scaleFactor)
                                        spacing: Math.round(6 * scaleFactor)

                                        RowLayout {
                                            Layout.fillWidth: true
                                            Text {
                                                text: "󰆍 Terminal Output"
                                                font.family: "Inter"
                                                font.pixelSize: Math.round(10 * fontScale)
                                                font.weight: Font.SemiBold
                                                color: Qt.rgba(1, 1, 1, 0.45)
                                            }
                                            Item { Layout.fillWidth: true }
                                            Text {
                                                text: commandCard.exitCode === 0 ? "✓ Exit 0" : "✕ Exit " + commandCard.exitCode
                                                font.family: "JetBrains Mono"
                                                font.pixelSize: Math.round(9.5 * fontScale)
                                                font.weight: Font.Bold
                                                color: commandCard.exitCode === 0 ? "#10B981" : "#EF4444"
                                            }
                                        }

                                        Flickable {
                                            Layout.fillWidth: true
                                            Layout.fillHeight: true
                                            contentWidth: width
                                            contentHeight: outText.implicitHeight
                                            clip: true
                                            boundsBehavior: Flickable.StopAtBounds

                                            Text {
                                                id: outText
                                                width: parent.width
                                                text: commandCard.cmdStdout || commandCard.cmdStderr || "(No output produced)"
                                                font.family: "JetBrains Mono"
                                                font.pixelSize: Math.round(11 * fontScale)
                                                color: commandCard.exitCode === 0 ? "#CBD5E1" : "#FCA5A5"
                                                wrapMode: Text.Wrap
                                                lineHeight: 1.3
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // ──────────────────────────────────────────────
                        // 4. MULTI-ITEM TASKS LIST VIEW (list_tasks)
                        // ──────────────────────────────────────────────
                        ListView {
                            id: tasksListView
                            visible: rootWindow.isTasksList
                            Layout.fillWidth: true
                            Layout.preferredHeight: Math.min(Math.round(260 * scaleFactor), contentHeight)
                            implicitHeight: Math.min(Math.round(260 * scaleFactor), contentHeight)
                            model: actionCardsModel
                            spacing: Math.round(6 * scaleFactor)
                            clip: true
                            currentIndex: rootWindow.selectedCardIndex

                            delegate: Rectangle {
                                width: tasksListView.width
                                height: Math.round(46 * scaleFactor)
                                radius: Math.round(8 * scaleFactor)
                                color: (index === rootWindow.selectedCardIndex)
                                    ? Qt.rgba(0, 245/255, 255/255, 0.16)
                                    : (tItemHvr.containsMouse ? Qt.rgba(255, 255, 255, 0.05) : Qt.rgba(255, 255, 255, 0.02))
                                border.color: (index === rootWindow.selectedCardIndex) ? "#00F5FF" : Qt.rgba(1, 1, 1, 0.06)
                                border.width: 1

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: Math.round(12 * scaleFactor)
                                    anchors.rightMargin: Math.round(12 * scaleFactor)
                                    spacing: Math.round(12 * scaleFactor)

                                    Rectangle {
                                        Layout.preferredWidth: Math.round(24 * scaleFactor)
                                        Layout.preferredHeight: Math.round(24 * scaleFactor)
                                        radius: Math.round(6 * scaleFactor)
                                        color: (model.badge === "✓ DONE") ? Qt.rgba(16/255, 185/255, 129/255, 0.25) : Qt.rgba(1, 1, 1, 0.06)
                                        border.color: (model.badge === "✓ DONE") ? "#10B981" : Qt.rgba(1, 1, 1, 0.15)
                                        border.width: 1

                                        Text {
                                            anchors.centerIn: parent
                                            text: (model.badge === "✓ DONE") ? "✓" : (model.icon || "󰄬")
                                            color: (model.badge === "✓ DONE") ? "#10B981" : (index === rootWindow.selectedCardIndex ? "#00F5FF" : "#F8FAFC")
                                            font.family: "Symbols Nerd Font"
                                            font.pixelSize: Math.round(12 * fontScale)
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1

                                        Text {
                                            Layout.fillWidth: true
                                            text: model.title
                                            color: (model.badge === "✓ DONE") ? Qt.rgba(1, 1, 1, 0.45) : "#F8FAFC"
                                            font.family: "Inter"
                                            font.pixelSize: Math.round(12.5 * fontScale)
                                            font.weight: Font.DemiBold
                                            font.strikeout: model.badge === "✓ DONE"
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: model.subtitle || ""
                                            color: Qt.rgba(1, 1, 1, 0.50)
                                            font.family: "JetBrains Mono"
                                            font.pixelSize: Math.round(10 * fontScale)
                                            elide: Text.ElideRight
                                        }
                                    }

                                    Text {
                                        text: model.badge || ""
                                        font.family: "JetBrains Mono"
                                        font.pixelSize: Math.round(10 * fontScale)
                                        font.weight: Font.DemiBold
                                        color: (model.badge === "✓ DONE") ? "#10B981" : "#F59E0B"
                                    }
                                }

                                MouseArea {
                                    id: tItemHvr
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        rootWindow.selectedCardIndex = index;
                                        rootWindow.executeSelectedCard(index);
                                    }
                                }
                            }
                        }

                        // ──────────────────────────────────────────────
                        // 5. CHAT STREAM MARKDOWN PROSE SYNTHESIS
                        // ──────────────────────────────────────────────
                        ColumnLayout {
                            visible: rootWindow.streamedResponse.length > 0 && !rootWindow.isTodoCreation && !rootWindow.isTasksList && !rootWindow.isCommandCard
                            Layout.fillWidth: true
                            spacing: Math.round(8 * scaleFactor)

                            Text {
                                Layout.fillWidth: true
                                textFormat: Text.MarkdownText
                                text: rootWindow.streamedResponse
                                font.family: "Inter"
                                font.pixelSize: Math.round(13.5 * fontScale)
                                font.letterSpacing: 0.2
                                lineHeight: 1.48
                                color: "#F8FAFC"
                                wrapMode: Text.Wrap
                            }
                        }

                        // ──────────────────────────────────────────────
                        // 6. SOURCES & REFERENCED EMAILS (AT THE BOTTOM)
                        // ──────────────────────────────────────────────
                        ColumnLayout {
                            visible: rootWindow.hasSourcesAtBottom
                            Layout.fillWidth: true
                            spacing: Math.round(8 * scaleFactor)

                            // Clean Separator
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 1
                                color: Qt.rgba(255, 255, 255, 0.08)
                            }

                            Text {
                                text: (rootWindow.deducedIntent === "email_summary" ? "󰇮 Referenced Emails" : "󰘳 Sources & References") + " (" + actionCardsModel.count + ")"
                                font.family: "Inter"
                                font.pixelSize: Math.round(11.5 * fontScale)
                                font.weight: Font.DemiBold
                                color: Qt.rgba(1, 1, 1, 0.55)
                            }

                            Repeater {
                                model: actionCardsModel
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: Math.round(44 * scaleFactor)
                                    implicitHeight: Math.round(44 * scaleFactor)
                                    radius: Math.round(6 * scaleFactor)
                                    color: srcHvr.containsMouse ? Qt.rgba(255, 255, 255, 0.08) : Qt.rgba(255, 255, 255, 0.03)
                                    border.color: (index === rootWindow.selectedCardIndex) ? Qt.rgba(0, 245/255, 255/255, 0.5) : Qt.rgba(255, 255, 255, 0.08)
                                    border.width: 1

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: Math.round(10 * scaleFactor)
                                        anchors.rightMargin: Math.round(10 * scaleFactor)
                                        spacing: Math.round(10 * scaleFactor)

                                        Text {
                                            text: model.icon || (model.card_type === "book" ? "󰂿" : (model.card_type === "email" ? "󰇮" : "󰠮"))
                                            font.family: "Symbols Nerd Font"
                                            font.pixelSize: Math.round(14 * fontScale)
                                            color: (model.card_type === "book" ? "#F59E0B" : (model.card_type === "email" ? "#60A5FA" : "#00F5FF"))
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 1

                                            Text {
                                                Layout.fillWidth: true
                                                text: model.title
                                                font.family: "Inter"
                                                font.pixelSize: Math.round(11.5 * fontScale)
                                                font.weight: Font.Medium
                                                color: "#F8FAFC"
                                                elide: Text.ElideRight
                                            }

                                            Text {
                                                Layout.fillWidth: true
                                                text: model.subtitle || ""
                                                font.family: "JetBrains Mono"
                                                font.pixelSize: Math.round(9.5 * fontScale)
                                                color: Qt.rgba(1, 1, 1, 0.50)
                                                elide: Text.ElideRight
                                            }
                                        }

                                        Text {
                                            text: model.badge || ""
                                            font.family: "JetBrains Mono"
                                            font.pixelSize: Math.round(9.5 * fontScale)
                                            color: Qt.rgba(1, 1, 1, 0.45)
                                        }
                                    }

                                    MouseArea {
                                        id: srcHvr
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            rootWindow.selectedCardIndex = index;
                                            rootWindow.executeSelectedCard(index);
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ══════════════════════════════════════════════════════════
            // D. RAYCAST BOTTOM ACTION BAR (Height: 38px)
            // ══════════════════════════════════════════════════════════
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.round(38 * scaleFactor)
                color: Qt.rgba(0, 0, 0, 0.35)
                border.color: Qt.rgba(1, 1, 1, 0.08)
                border.width: 1
                visible: rootWindow.engineState !== "input"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Math.round(14 * scaleFactor)
                    anchors.rightMargin: Math.round(14 * scaleFactor)
                    spacing: Math.round(10 * scaleFactor)

                    // Primary Action Button
                    Rectangle {
                        Layout.preferredHeight: Math.round(26 * scaleFactor)
                        Layout.preferredWidth: primaryBtnTxt.implicitWidth + Math.round(16 * scaleFactor)
                        radius: Math.round(5 * scaleFactor)
                        color: actionCardsModel.count > 0 ? Qt.rgba(16/255, 185/255, 129/255, 0.25) : Qt.rgba(0, 245/255, 255/255, 0.20)
                        border.color: actionCardsModel.count > 0 ? "#10B981" : "#00F5FF"
                        border.width: 1

                        Text {
                            id: primaryBtnTxt
                            anchors.centerIn: parent
                            text: {
                                if (rootWindow.isCommandCard) {
                                    var cCard = actionCardsModel.count > 0 ? actionCardsModel.get(0) : null;
                                    if (cCard && cCard.status === "executed") {
                                        return rootWindow.copySuccess ? "✓ Output Copied" : "[↵] Copy Output";
                                    }
                                    return "[↵] Execute Command";
                                }
                                if (actionCardsModel.count > 0) {
                                    var card = actionCardsModel.get(rootWindow.selectedCardIndex);
                                    if (card && card.card_type === "todoist") {
                                        return "[↵] Complete Task";
                                    }
                                    return "[↵] Execute Item";
                                }
                                return rootWindow.copySuccess ? "✓ Copied" : "[↵] Copy Answer";
                            }
                            color: actionCardsModel.count > 0 ? "#10B981" : "#00F5FF"
                            font.family: "JetBrains Mono"
                            font.pixelSize: Math.round(10.5 * fontScale)
                            font.weight: Font.DemiBold
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: rootWindow.executeSelectedCard(rootWindow.selectedCardIndex)
                        }
                    }

                    // Copy Command Button (Active for command execution)
                    Rectangle {
                        visible: rootWindow.isCommandCard
                        Layout.preferredHeight: Math.round(26 * scaleFactor)
                        Layout.preferredWidth: copyCmdBtnTxt.implicitWidth + Math.round(16 * scaleFactor)
                        radius: Math.round(5 * scaleFactor)
                        color: Qt.rgba(0, 245/255, 255/255, 0.15)
                        border.color: "#00F5FF"
                        border.width: 1

                        Text {
                            id: copyCmdBtnTxt
                            anchors.centerIn: parent
                            text: rootWindow.copySuccess ? "✓ Copied" : "[C] Copy Command"
                            color: "#00F5FF"
                            font.family: "JetBrains Mono"
                            font.pixelSize: Math.round(10.5 * fontScale)
                            font.weight: Font.DemiBold
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                var cCard = actionCardsModel.count > 0 ? actionCardsModel.get(0) : null;
                                if (cCard) {
                                    rootWindow.executeAction("copy", cCard.command || cCard.title);
                                    rootWindow.copySuccess = true;
                                    copyResetTimer.restart();
                                }
                            }
                        }
                    }

                    // Secondary: [Ctrl+K] Actions Menu Trigger
                    Rectangle {
                        Layout.preferredHeight: Math.round(26 * scaleFactor)
                        Layout.preferredWidth: actionsBtnTxt.implicitWidth + Math.round(16 * scaleFactor)
                        radius: Math.round(5 * scaleFactor)
                        color: rootWindow.isActionMenuOpen ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(1, 1, 1, 0.06)
                        border.color: Qt.rgba(1, 1, 1, 0.15)
                        border.width: 1

                        Text {
                            id: actionsBtnTxt
                            anchors.centerIn: parent
                            text: "⌘ [Ctrl+K] Actions"
                            color: "#F8FAFC"
                            font.family: "JetBrains Mono"
                            font.pixelSize: Math.round(10.5 * fontScale)
                            font.weight: Font.Medium
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: rootWindow.isActionMenuOpen = !rootWindow.isActionMenuOpen
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // Model / Engine Tag
                    Text {
                        text: "Minimo MindPilot • " + (rootWindow.deducedModel || "Qwen 2.5 1.5B")
                        font.family: "JetBrains Mono"
                        font.pixelSize: Math.round(10 * fontScale)
                        color: Qt.rgba(1, 1, 1, 0.40)
                    }
                }
            }
        }

        // ══════════════════════════════════════════════════════════════
        // E. RAYCAST ACTION POPOVER SUBMENU (Ctrl+K)
        // ══════════════════════════════════════════════════════════
        Rectangle {
            id: actionPopoverMenu
            visible: rootWindow.isActionMenuOpen && rootWindow.engineState !== "input"
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Math.round(46 * scaleFactor)
            anchors.right: parent.right
            anchors.rightMargin: Math.round(14 * scaleFactor)
            width: Math.round(220 * scaleFactor)
            height: popCol.implicitHeight + Math.round(16 * scaleFactor)
            radius: Math.round(10 * scaleFactor)
            color: Qt.rgba(15/255, 23/255, 42/255, 0.98)
            border.color: Qt.rgba(0, 245/255, 255/255, 0.35)
            border.width: 1
            z: 200

            ColumnLayout {
                id: popCol
                anchors.fill: parent
                anchors.margins: Math.round(8 * scaleFactor)
                spacing: Math.round(4 * scaleFactor)

                // 1. Complete Task
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.round(30 * scaleFactor)
                    radius: Math.round(6 * scaleFactor)
                    color: p1Hvr.containsMouse ? Qt.rgba(255, 255, 255, 0.08) : "transparent"
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8; anchors.rightMargin: 8
                        spacing: 8
                        Text { text: "󰄬"; color: "#10B981"; font.family: "Symbols Nerd Font"; font.pixelSize: 13 }
                        Text { text: "Complete Task"; color: "#F8FAFC"; font.family: "Inter"; font.pixelSize: Math.round(11.5 * fontScale); font.weight: Font.Medium }
                    }
                    MouseArea {
                        id: p1Hvr; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            rootWindow.isActionMenuOpen = false;
                            rootWindow.executeSelectedCard(rootWindow.selectedCardIndex);
                        }
                    }
                }

                // 2. Copy Action JSON
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.round(30 * scaleFactor)
                    radius: Math.round(6 * scaleFactor)
                    color: p2Hvr.containsMouse ? Qt.rgba(255, 255, 255, 0.08) : "transparent"
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8; anchors.rightMargin: 8
                        spacing: 8
                        Text { text: "󰆏"; color: "#00F5FF"; font.family: "Symbols Nerd Font"; font.pixelSize: 13 }
                        Text { text: "Copy Action JSON"; color: "#F8FAFC"; font.family: "Inter"; font.pixelSize: Math.round(11.5 * fontScale); font.weight: Font.Medium }
                    }
                    MouseArea {
                        id: p2Hvr; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            rootWindow.isActionMenuOpen = false;
                            var jsonPayload = JSON.stringify({
                                intent: rootWindow.deducedIntent,
                                title: rootWindow.deducedTitle,
                                priority: rootWindow.deducedPriority,
                                due: rootWindow.deducedDue,
                                desc: rootWindow.deducedDesc
                            }, null, 2);
                            rootWindow.executeAction("copy", jsonPayload);
                            rootWindow.copySuccess = true;
                            copyResetTimer.restart();
                        }
                    }
                }

                // 3. New Query [Esc]
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.round(30 * scaleFactor)
                    radius: Math.round(6 * scaleFactor)
                    color: p3Hvr.containsMouse ? Qt.rgba(255, 255, 255, 0.08) : "transparent"
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8; anchors.rightMargin: 8
                        spacing: 8
                        Text { text: "⌕"; color: Qt.rgba(1, 1, 1, 0.70); font.pixelSize: 13 }
                        Text { text: "New Query [Esc]"; color: "#F8FAFC"; font.family: "Inter"; font.pixelSize: Math.round(11.5 * fontScale); font.weight: Font.Medium }
                    }
                    MouseArea {
                        id: p3Hvr; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            rootWindow.isActionMenuOpen = false;
                            rootWindow.resetToInput();
                        }
                    }
                }
            }
        }
    }
}
