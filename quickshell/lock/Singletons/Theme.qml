pragma Singleton
import QtQuick
import Quickshell

/**
 * Lock palette unified with the QuickShell top bar & dynamic island design system.
 */
Singleton {
    readonly property bool dyn: Flags.paletteMode !== "static"

    readonly property color accent: dyn ? Dyn.primary : "#0A84FF"
    readonly property color accentSecondary: "#30D158"
    readonly property color crit: "#FF453A"
    readonly property color warn: "#FF9F0A"
    readonly property color spotify: "#1DB954"
    readonly property color success: accentSecondary

    readonly property color cream: dyn ? Dyn.cream : "#E5E5EA"
    readonly property color bright: dyn ? Dyn.bright : "#FFFFFF"
    readonly property color dim: dyn ? Dyn.dim : Qt.rgba(1, 1, 1, 0.55)
    readonly property color subtle: Qt.rgba(1, 1, 1, 0.35)

    readonly property string font: "Geist"
    readonly property string iconFont: "GeistMono Nerd Font"

    // Glassmorphic surface materials matching the main QuickShell bar capsules
    readonly property color colBg: Qt.rgba(0.08, 0.08, 0.09, 0.60)
    readonly property color colBorder: Qt.rgba(1, 1, 1, 0.10)
    readonly property color colHover: Qt.rgba(1, 1, 1, 0.15)
    readonly property color colActive: Qt.rgba(1, 1, 1, 0.22)

    readonly property color fieldBg: Qt.rgba(1, 1, 1, 0.08)
    readonly property color fieldBorder: Qt.rgba(1, 1, 1, 0.14)
    readonly property color trackBg: Qt.rgba(1, 1, 1, 0.12)
    readonly property color error: "#FF453A"

    // Backward compatibility aliases
    readonly property color verm: accent
}
