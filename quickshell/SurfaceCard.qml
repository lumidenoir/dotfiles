import QtQuick
import QtQuick.Layouts

Item {
    id: root

    // =========================================================================
    // OPTION B TACTICAL STEALTH TELEMETRY CARD
    // =========================================================================
    // Geometry & Layout
    property real cornerRadius: 4
    property alias radius: root.cornerRadius
    property real contentPadding: 8
    implicitWidth: 340
    implicitHeight: 200

    // Theme & Materials (Option B Matte Obsidian / Slate - Near-opaque 98.5% eliminates background bleed)
    property color backgroundColor: Qt.rgba(0.043, 0.047, 0.055, 0.985) // #0B0C0E @ 98.5%
    property color borderColor: isHovered && button ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.08)
    property real borderWidth: 1
    property color accentColor: "#0A84FF" // Apple System Blue
    property bool showAccentTopLine: false

    // Interaction flags
    property bool floating: false
    property bool button: false
    property bool interactive: floating || button
    readonly property bool isHovered: hoverArea.containsMouse
    readonly property bool isPressed: hoverArea.pressed
    signal clicked()

    // Backward compatibility with LiquidGlassCard API
    property bool useShader: false
    property Item backdropItem: null
    property real blurAmount: 0.0
    property real refraction: 0.0
    property real chromaticAberration: 0.0
    property real edgeHighlight: 0.0
    property real fresnel: 0.0
    property real distortion: 0.0
    property real zRadius: cornerRadius
    property real saturation: 0.0
    property real brightness: 0.0
    property real tint: 0.0
    property real shadowOpacity: 0.0
    property real shadowSpread: 0.0
    property real shadowOffsetY: 0.0
    property real bevelMode: 0.0
    property string glassMode: "dark"
    property real appleMode: 0.0
    property real causticStrength: 0.0
    property real causticAngle: 0.0
    property real pearlOpacity: 0.0
    property real fluidTension: 0.0
    readonly property bool isAppleMode: false

    default property alias content: contentContainer.data

    // ── Zero-Overhead Base Surface ───────────────────────────────────────────
    Rectangle {
        id: surfaceBase
        anchors.fill: parent
        radius: root.cornerRadius
        color: root.backgroundColor
        border.color: root.borderColor
        border.width: root.borderWidth
        clip: true

        // Clean uniform subtle top hairline for architectural depth
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: root.borderWidth
            height: 1
            color: root.showAccentTopLine ? root.accentColor : Qt.rgba(1, 1, 1, 0.04)
            visible: root.showAccentTopLine
        }

        Rectangle {
            id: hoverGlow
            anchors.fill: parent
            radius: root.cornerRadius
            color: Qt.rgba(1, 1, 1, 0.02)
            visible: root.button && root.isHovered
        }
    }

    // ── Inner Content Container ──────────────────────────────────────────────
    Item {
        id: contentContainer
        property alias cornerRadius: root.cornerRadius
        anchors.fill: parent
        anchors.margins: root.contentPadding
        z: 20
    }

    // ── Interaction Handler ──────────────────────────────────────────────────
    MouseArea {
        id: hoverArea
        anchors.fill: parent
        enabled: root.interactive
        hoverEnabled: root.interactive
        cursorShape: root.floating ? Qt.SizeAllCursor : (root.button ? Qt.PointingHandCursor : Qt.ArrowCursor)
        drag.target: root.floating ? root : null
        drag.axis: Drag.XAndYAxis
        onClicked: root.clicked()
    }
}

