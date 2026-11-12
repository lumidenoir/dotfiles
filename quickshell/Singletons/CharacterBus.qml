pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root
    signal react(string name)
    signal islandCommand(string cmd)
    signal gaze(real x, real y, int ms)
    signal pet()
    signal typed()
    signal typingStopped()
    signal squintFor(int ms)
    property int hearts: 0
    readonly property var names: ["hop", "doubleHop", "giggle", "lookAround", "surprise",
                                  "wink", "dizzy", "yawn", "curious", "greet", "happyBounce", "startled",
                                  "chew", "sway", "wiggle", "peekaboo"]

    // Idle Asleep state & music dancing
    property bool sleeping: false
    property bool dancing: false
    property real musicLevel: 0.5
    property int idleTimeoutMs: 75000 // 75 seconds of no activity

    onTyped: {
        if (sleeping) sleeping = false;
        Cursor.lastMove = Date.now();
    }

    property var idleTimer: Timer {
        id: idleTimer
        interval: 3000
        repeat: true
        running: true
        onTriggered: {
            if (Cursor.ok && Cursor.lastMove > 0) {
                var elapsed = Date.now() - Cursor.lastMove;
                if (elapsed > root.idleTimeoutMs && !root.sleeping) {
                    root.sleeping = true;
                }
            }
        }
    }

    property var cursorConn: Connections {
        target: Cursor
        function onXChanged() {
            if (root.sleeping) root.sleeping = false;
        }
        function onYChanged() {
            if (root.sleeping) root.sleeping = false;
        }
    }
}
