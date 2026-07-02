import QtQuick
import QtQuick.Layouts

Canvas {
    id: sparkline
    Layout.fillWidth: true
    Layout.preferredHeight: 24
    property var history: []
    property color strokeColor: "#ffffff"
    onHistoryChanged: requestPaint()
    onPaint: {
        var ctx = getContext("2d");
        ctx.clearRect(0, 0, width, height);
        if (history.length < 2) return;

        var dx = width / (history.length - 1);

        // 1. Draw the under-fill gradient path
        ctx.beginPath();
        ctx.moveTo(0, height);
        for (var i = 0; i < history.length; i++) {
            var val = history[i];
            var x = i * dx;
            var y = height - (val / 100.0) * height;
            ctx.lineTo(x, y);
        }
        ctx.lineTo(width, height);
        ctx.closePath();

        var grad = ctx.createLinearGradient(0, 0, 0, height);
        var c = strokeColor;
        grad.addColorStop(0, Qt.rgba(c.r, c.g, c.b, 0.28)); // Enhanced opacity for distinct under-fill pop
        grad.addColorStop(1, Qt.rgba(c.r, c.g, c.b, 0.0));
        ctx.fillStyle = grad;
        ctx.fill();

        // 2. Draw the line stroke path on top
        ctx.beginPath();
        for (var i = 0; i < history.length; i++) {
            var val = history[i];
            var x = i * dx;
            var y = height - (val / 100.0) * height;
            if (i === 0) ctx.moveTo(x, y);
            else ctx.lineTo(x, y);
        }
        ctx.strokeStyle = strokeColor;
        ctx.lineWidth = 1.5;
        ctx.stroke();
    }
}
