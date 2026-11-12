pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root
    property int users: 0
    property real x: -1
    property real y: -1
    property bool ok: false
    property real lastMove: 0

    function acquire() { 
        if (users === 0) lastMove = Date.now(); 
        users++; 
    }
    function release() { 
        users = Math.max(0, users - 1); 
    }

    property var proc: Process {
        id: proc
        running: root.users > 0
        onExited: if (root.users > 0) relaunch.restart()
        command: ["python3", "/home/krishna/dotfiles/quickshell/scripts/cursorpos.py"]
        stdout: SplitParser {
            onRead: function(line) {
                var m = line.match(/^(-?\d+),\s*(-?\d+)/);
                if (!m) return;
                var nx = parseInt(m[1]), ny = parseInt(m[2]);
                if (nx !== root.x || ny !== root.y) { 
                    root.lastMove = Date.now(); 
                    root.x = nx; 
                    root.y = ny; 
                }
                root.ok = true;
            }
        }
    }
    property var relaunch: Timer { 
        id: relaunch
        interval: 2000
        repeat: false
        onTriggered: {
            if (root.users > 0) { 
                proc.running = false; 
                proc.running = true; 
            } 
        }
    }
}
