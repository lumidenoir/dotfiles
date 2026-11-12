pragma Singleton
import QtQuick

QtObject {
    readonly property bool reduceMotion: false
    readonly property real mult: reduceMotion ? 0.0 : 1.0

    readonly property int fast:     Math.round(150 * mult)
    readonly property int standard: Math.round(280 * mult)
    readonly property int morph:    Math.round(400 * mult)
    readonly property int glide:    Math.round(220 * mult)

    readonly property int easeMorph: Easing.BezierSpline
    readonly property var morphCurve: [0.16, 1, 0.3, 1, 1, 1]
}
