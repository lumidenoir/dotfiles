import QtQuick
import QtQuick.Shapes
import "Singletons"

/**
 * Baked vector glyphs for the lock, same recipe as the pill's GlyphIcon: 24x24
 * SVG path data stroked into a Shape, so nothing depends on icon themes.
 */
Item {
    id: root

    property string name: ""
    property color color: Theme.dim
    property real stroke: 1.8

    readonly property real u: Math.min(width, height) / 24

    readonly property var glyphs: ({
        "eye": { d: "M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z M15 12a3 3 0 1 1-6 0 3 3 0 0 1 6 0z", fill: false },
        "eye-off": { d: "M17.94 17.94A10.07 10.07 0 0 1 12 20c-7 0-11-8-11-8a18.45 18.45 0 0 1 5.06-5.94 M9.9 4.24A9.12 9.12 0 0 1 12 4c7 0 11 8 11 8a18.5 18.5 0 0 1-2.16 3.19 M14.12 14.12a3 3 0 1 1-4.24-4.24 M1 1l22 22", fill: false },
        "play": { d: "M5 3 19 12 5 21 5 3", fill: false },
        "pause": { d: "M6 4h4v16H6z M14 4h4v16h-4z", fill: false },
        "skip-back": { d: "M19 20L9 12 19 4z M5 19V5", fill: false },
        "skip-forward": { d: "M5 4l10 8-10 8z M19 5v14", fill: false },
        "lock": { d: "M12 2a5 5 0 0 0-5 5v3H6a2 2 0 0 0-2 2v8a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-8a2 2 0 0 0-2-2h-1V7a5 5 0 0 0-5-5zm-3 5a3 3 0 0 1 6 0v3H9V7zm3 6a2 2 0 0 1 2 2c0 .74-.4 1.39-1 1.73V18a1 1 0 1 1-2 0v-1.27a2 2 0 0 1-1-1.73 2 2 0 0 1 2-2z", fill: false },
        "user": { d: "M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2 M12 3a4 4 0 1 0 0 8 4 4 0 0 0 0-8z", fill: false },
        "power": { d: "M18.36 6.64a9 9 0 1 1-12.73 0 M12 2v10", fill: false },
        "refresh": { d: "M23 4v6h-6 M1 20v-6h6 M3.51 9a9 9 0 0 1 14.85-3.36L23 10 M1 14l4.64 4.36A9 9 0 0 0 20.49 15", fill: false },
        "moon": { d: "M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z", fill: false },
        "monitor": { d: "M20 3H4a2 2 0 0 0-2 2v10a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2V5a2 2 0 0 0-2-2z M8 21h8 M12 17v4", fill: false },
        "volume": { d: "M11 5L6 9H2v6h4l5 4V5z M19.07 4.93a10 10 0 0 1 0 14.14 M15.54 8.46a5 5 0 0 1 0 7.07", fill: false },
        "volume-x": { d: "M11 5L6 9H2v6h4l5 4V5z M23 9l-6 6 M17 9l6 6", fill: false },
        "wifi": { d: "M5 12.55a11 11 0 0 1 14.08 0 M1.42 9a16 16 0 0 1 21.16 0 M8.53 16.11a6 6 0 0 1 6.95 0 M12 20h.01", fill: false },
        "ethernet": { d: "M4 4h16v12H4z M9 16v4 M15 16v4 M8 20h8 M9 8h2v3H9z M13 8h2v3h-2z", fill: false },
        "bluetooth": { d: "M6.5 6.5l11 11L12 23V1l5.5 5.5-11 11", fill: false },
        "alert-triangle": { d: "M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z M12 9v4 M12 17h.01", fill: false }
    })
    readonly property var g: glyphs[name] !== undefined ? glyphs[name] : ({ d: "", fill: false })

    Shape {
        id: glyph

        width: 24
        height: 24
        scale: root.u
        transformOrigin: Item.TopLeft
        x: glyph.boundingRect.width > 0
           ? root.width / 2 - (glyph.boundingRect.x + glyph.boundingRect.width / 2) * root.u
           : (root.width - 24 * root.u) / 2
        y: glyph.boundingRect.height > 0
           ? root.height / 2 - (glyph.boundingRect.y + glyph.boundingRect.height / 2) * root.u
           : (root.height - 24 * root.u) / 2
        antialiasing: true
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: root.g.fill ? "transparent" : root.color
            fillColor: root.g.fill ? root.color : "transparent"
            strokeWidth: root.stroke
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: root.g.d }
        }
    }
}
