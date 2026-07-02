import QtQuick

Canvas {
    id: commsCanvas
    width: 200
    height: 32
    property real phase: 0.0
    property real amplitude: 1.0
    property bool active: false

    Timer {
        interval: 16
        running: commsCanvas.active
        repeat: true
        onTriggered: {
            commsCanvas.phase += 0.15;
            commsCanvas.requestPaint();
        }
    }

    onActiveChanged: {
        if (active) {
            commsCanvas.requestPaint();
        }
    }

    onPaint: {
        var ctx = getContext("2d");
        ctx.reset();
        if (!active) return;

        var w = width;
        var h = height;
        var midY = h / 2;

        // UAV/Drone Comms-inspired colors (Cyan, Emerald, Amber)
        var colors = [
            Qt.rgba(0.0, 0.90, 0.90, 0.55),  // Teal/Cyan link status
            Qt.rgba(0.0, 0.85, 0.45, 0.60),  // Signal Emerald green
            Qt.rgba(1.0, 0.65, 0.0, 0.50)    // Warning/Telemetry Amber
        ];

        var waveParams = [
            { freq: 0.025, amp: 8, speed: 1.0 },
            { freq: 0.035, amp: 10, speed: -0.7 },
            { freq: 0.020, amp: 6, speed: 1.3 }
        ];

        // Screen composite blending mode for the neon glowing effect
        ctx.globalCompositeOperation = "screen";

        for (var i = 0; i < 3; i++) {
            var p = waveParams[i];
            ctx.beginPath();
            ctx.strokeStyle = colors[i];
            ctx.lineWidth = 2.5;

            var currentPhase = phase * p.speed;

            for (var x = 0; x <= w; x += 4) {
                // Bell curve envelope to zero out the amplitude at screen boundaries
                var envelope = Math.sin((x / w) * Math.PI);
                var y = midY + Math.sin(x * p.freq + currentPhase) * p.amp * envelope * amplitude;
                if (x === 0) {
                    ctx.moveTo(x, y);
                } else {
                    ctx.lineTo(x, y);
                }
            }
            ctx.stroke();
        }
    }
}
