import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import "Character"

Window {
    id: settingsWin
    title: "Ground Control Settings"
    width: Math.round(420 * scaleFactor)
    height: Math.round(440 * scaleFactor)
    color: "transparent"
    flags: Qt.FramelessWindowHint | Qt.Window
    visible: false

    property var shellRoot: null
    readonly property real scaleFactor: shellRoot ? shellRoot.scaleFactor : 1.0
    readonly property real fontScale: scaleFactor * (shellRoot ? shellRoot.fontSizeMultiplier : 1.0)
    readonly property string monoFont: "Ioskeley Mono"
    readonly property string iconFontFamily: "Symbols Nerd Font"

    // ── TE / INDUSTRIAL TERMINAL CASING ──
    // Pure razor-sharp 0px radius, pitch black OLED (#000000), double hairline borders
    Rectangle {
        id: casing
        anchors.fill: parent
        color: "#000000"
        border.color: "#212836"
        border.width: 1
        radius: 0

        // Inner secondary wireframe border (Teenage Engineering instrument chassis)
        Rectangle {
            anchors.fill: parent
            anchors.margins: 2
            color: "transparent"
            border.color: "#101622"
            border.width: 1
            radius: 0
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 4
            spacing: 0

            // ── TOP TELEMETRY RAIL & TITLE BAR (DRAGGABLE) ──────────────────
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.round(36 * scaleFactor)

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.SizeAllCursor
                    onPressed: settingsWin.startSystemMove()
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Math.round(8 * scaleFactor)
                    anchors.rightMargin: Math.round(8 * scaleFactor)
                    spacing: Math.round(8 * scaleFactor)

                    Text {
                        text: "┌─ [PREFS] SYSTEM CONFIG // TE-01"
                        color: "#0A84FF"
                        font { family: settingsWin.monoFont; pixelSize: Math.round(10.5 * scaleFactor); bold: true }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: "#212836"
                        Layout.alignment: Qt.AlignVCenter
                    }

                    // Status Pill
                    Rectangle {
                        width: Math.round(48 * scaleFactor)
                        height: Math.round(18 * scaleFactor)
                        color: "#0c1f12"
                        border.color: "#30D158"
                        border.width: 1
                        radius: 0

                        Text {
                            anchors.centerIn: parent
                            text: "ONLINE"
                            color: "#30D158"
                            font { family: settingsWin.monoFont; pixelSize: Math.round(8 * scaleFactor); bold: true }
                        }
                    }

                    // Terminal Close [X] Button
                    Rectangle {
                        width: Math.round(20 * scaleFactor)
                        height: Math.round(18 * scaleFactor)
                        color: closeMa.containsMouse ? "#3d1414" : "#0d1117"
                        border.color: closeMa.containsMouse ? "#FF453A" : "#30363d"
                        border.width: 1
                        radius: 0

                        Text {
                            anchors.centerIn: parent
                            text: "×"
                            color: closeMa.containsMouse ? "#FF453A" : "#8b949e"
                            font { family: settingsWin.monoFont; pixelSize: Math.round(11 * scaleFactor); bold: true }
                        }

                        MouseArea {
                            id: closeMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: settingsWin.visible = false
                        }
                    }
                }
            }

            // Divider line
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: "#161b22"
            }

            // ── BODY (TE INSTRUMENT SLOTS) ───────────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.margins: Math.round(12 * scaleFactor)
                spacing: Math.round(12 * scaleFactor)

                // ── [01] MINIMO EMBODIED AI APPEARANCE ───────────────────────
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.round(84 * scaleFactor)
                    color: "#050608"
                    border.color: "#1c212c"
                    border.width: 1
                    radius: 0

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Math.round(8 * scaleFactor)
                        spacing: Math.round(6 * scaleFactor)

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Math.round(6 * scaleFactor)

                            Text {
                                text: ":: [01] MINIMO AI EMBODIMENT"
                                color: "#00E5FF"
                                font { family: settingsWin.monoFont; pixelSize: Math.round(9.5 * scaleFactor); bold: true }
                            }
                            Rectangle { Layout.fillWidth: true; height: 1; color: "#161b22" }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Math.round(10 * scaleFactor)

                            Character {
                                size: Math.round(32 * scaleFactor)
                                active: settingsWin.visible
                                sphereColor: (settingsWin.shellRoot && settingsWin.shellRoot.minimoBotMode === "light") ? "#FFFFFF" : "#14171F"
                                eyeColor: (settingsWin.shellRoot && settingsWin.shellRoot.minimoBotMode === "light") ? "#07080B" : "#00E5FF"
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1
                                Text {
                                    text: (settingsWin.shellRoot && settingsWin.shellRoot.minimoBotMode === "light")
                                        ? "PALE PORCELAIN CHITIN"
                                        : "OBSIDIAN VOID CHITIN"
                                    color: "#F0F6FC"
                                    font { family: settingsWin.monoFont; pixelSize: Math.round(10 * scaleFactor); bold: true }
                                }
                                Text {
                                    text: (settingsWin.shellRoot && settingsWin.shellRoot.minimoBotMode === "light")
                                        ? "OPTICS: DARK CORE // SHELL: LIGHT"
                                        : "OPTICS: ELECTRIC CYAN // SHELL: DARK"
                                    color: "#6e7681"
                                    font { family: settingsWin.monoFont; pixelSize: Math.round(8 * scaleFactor) }
                                }
                            }

                            RowLayout {
                                spacing: Math.round(4 * scaleFactor)

                                Repeater {
                                    model: [
                                        { label: "DARK", mode: "dark" },
                                        { label: "LIGHT", mode: "light" }
                                    ]
                                    Rectangle {
                                        readonly property bool isSel: (settingsWin.shellRoot ? settingsWin.shellRoot.minimoBotMode : "dark") === modelData.mode
                                        width: Math.round(58 * scaleFactor)
                                        height: Math.round(24 * scaleFactor)
                                        color: isSel ? "#0e1e2e" : (bMa.containsMouse ? "#12151c" : "#07090e")
                                        border.color: isSel ? "#00E5FF" : "#212836"
                                        border.width: 1
                                        radius: 0

                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData.label
                                            color: parent.isSel ? "#00E5FF" : "#8b949e"
                                            font { family: settingsWin.monoFont; pixelSize: Math.round(9 * scaleFactor); bold: parent.isSel }
                                        }

                                        MouseArea {
                                            id: bMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: if (settingsWin.shellRoot) settingsWin.shellRoot.setMinimoBotMode(modelData.mode)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ── [02] VISUALIZER SHADER SELECTION ─────────────────────────
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.round(80 * scaleFactor)
                    color: "#050608"
                    border.color: "#1c212c"
                    border.width: 1
                    radius: 0

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Math.round(8 * scaleFactor)
                        spacing: Math.round(6 * scaleFactor)

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Math.round(6 * scaleFactor)

                            Text {
                                text: ":: [02] SPECTRAL AUDIO VISUALIZER ENGINE"
                                color: "#30D158"
                                font { family: settingsWin.monoFont; pixelSize: Math.round(9.5 * scaleFactor); bold: true }
                            }
                            Rectangle { Layout.fillWidth: true; height: 1; color: "#161b22" }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Math.round(6 * scaleFactor)

                            Repeater {
                                model: [
                                    { name: "GLOW [0]", val: 0, desc: "AMBIENT DIFFUSION" },
                                    { name: "FLUID [1]", val: 1, desc: "HARMONIC MESH" },
                                    { name: "TIDE [2]", val: 2, desc: "PROCEDURAL SWELL" }
                                ]
                                Rectangle {
                                    readonly property bool isSel: (settingsWin.shellRoot ? settingsWin.shellRoot.visualizerShader : 0) === modelData.val
                                    Layout.fillWidth: true
                                    height: Math.round(38 * scaleFactor)
                                    color: isSel ? "#0c1f12" : (vMa.containsMouse ? "#12151c" : "#07090e")
                                    border.color: isSel ? "#30D158" : "#212836"
                                    border.width: 1
                                    radius: 0

                                    ColumnLayout {
                                        anchors.centerIn: parent
                                        spacing: 1

                                        Text {
                                            text: modelData.name
                                            color: parent.parent.isSel ? "#30D158" : "#8b949e"
                                            font { family: settingsWin.monoFont; pixelSize: Math.round(9 * scaleFactor); bold: parent.parent.isSel }
                                            Layout.alignment: Qt.AlignHCenter
                                        }
                                        Text {
                                            text: modelData.desc
                                            color: parent.parent.isSel ? "#30D158" : "#484f58"
                                            opacity: 0.8
                                            font { family: settingsWin.monoFont; pixelSize: Math.round(7 * scaleFactor) }
                                            Layout.alignment: Qt.AlignHCenter
                                        }
                                    }

                                    MouseArea {
                                        id: vMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: if (settingsWin.shellRoot) settingsWin.shellRoot.visualizerShader = modelData.val
                                    }
                                }
                            }
                        }
                    }
                }

                // ── [03] TYPOGRAPHY SCALE / STEP ATTENUATOR ──────────────────
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.round(76 * scaleFactor)
                    color: "#050608"
                    border.color: "#1c212c"
                    border.width: 1
                    radius: 0

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Math.round(8 * scaleFactor)
                        spacing: Math.round(8 * scaleFactor)

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Math.round(6 * scaleFactor)

                            Text {
                                text: ":: [03] UI TYPOGRAPHY SCALING"
                                color: "#FF9F0A"
                                font { family: settingsWin.monoFont; pixelSize: Math.round(9.5 * scaleFactor); bold: true }
                            }

                            Rectangle { Layout.fillWidth: true; height: 1; color: "#161b22" }

                            Text {
                                text: settingsWin.shellRoot ? (settingsWin.shellRoot.fontSizeMultiplier * 100).toFixed(0) + "%" : "100%"
                                color: "#FF9F0A"
                                font { family: settingsWin.monoFont; pixelSize: Math.round(10 * scaleFactor); bold: true }
                            }
                        }

                        // Terminal Step Attenuator (Discrete block ticks)
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Math.round(4 * scaleFactor)

                            Repeater {
                                model: [
                                    { label: "80%", val: 0.80 },
                                    { label: "90%", val: 0.90 },
                                    { label: "100%", val: 1.00 },
                                    { label: "110%", val: 1.10 },
                                    { label: "120%", val: 1.20 },
                                    { label: "130%", val: 1.30 }
                                ]
                                Rectangle {
                                    readonly property bool isCur: settingsWin.shellRoot && Math.abs(settingsWin.shellRoot.fontSizeMultiplier - modelData.val) < 0.05
                                    Layout.fillWidth: true
                                    height: Math.round(24 * scaleFactor)
                                    color: isCur ? "#261608" : (fMa.containsMouse ? "#141720" : "#07090e")
                                    border.color: isCur ? "#FF9F0A" : "#212836"
                                    border.width: 1
                                    radius: 0

                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.label
                                        color: parent.isCur ? "#FF9F0A" : "#6e7681"
                                        font { family: settingsWin.monoFont; pixelSize: Math.round(8.5 * scaleFactor); bold: parent.isCur }
                                    }

                                    MouseArea {
                                        id: fMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: if (settingsWin.shellRoot) settingsWin.shellRoot.fontSizeMultiplier = modelData.val
                                    }
                                }
                            }
                        }
                    }
                }

                Item { Layout.fillHeight: true }

                // ── [04] FOOTER TELEMETRY & HARDWARE RESET ───────────────────
                Rectangle {
                    Layout.fillWidth: true
                    height: Math.round(28 * scaleFactor)
                    color: rMa.containsMouse ? "#220d0d" : "#080a0e"
                    border.color: rMa.containsMouse ? "#FF453A" : "#212836"
                    border.width: 1
                    radius: 0

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Math.round(10 * scaleFactor)
                        anchors.rightMargin: Math.round(10 * scaleFactor)

                        Text {
                            text: "[RESET] RESTORE FACTORY MATRIX DEFAULTS"
                            color: rMa.containsMouse ? "#FF453A" : "#8b949e"
                            font { family: settingsWin.monoFont; pixelSize: Math.round(9 * scaleFactor); bold: true }
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            text: "SYS_RST // CONFIRM"
                            color: rMa.containsMouse ? "#FF453A" : "#484f58"
                            font { family: settingsWin.monoFont; pixelSize: Math.round(8 * scaleFactor) }
                        }
                    }

                    MouseArea {
                        id: rMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (settingsWin.shellRoot) {
                                settingsWin.shellRoot.setMinimoBotMode("dark");
                                settingsWin.shellRoot.visualizerShader = 0;
                                settingsWin.shellRoot.fontSizeMultiplier = 1.00;
                            }
                        }
                    }
                }
            }
        }
    }
}
