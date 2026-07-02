import Quickshell
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Wayland
import Quickshell.Io

PanelWindow {
    id: widgetsWin
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "quickshell_widgets"

    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true

    color: "transparent"

    property var shellRoot: null
    property real scaleFactor: shellRoot ? shellRoot.scaleFactor : 1.0

    Column {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: Math.round(44 * scaleFactor)
        anchors.topMargin: Math.round(90 * scaleFactor)
        spacing: Math.round(10 * scaleFactor)

        // ══════════════════════════════════════════════════════════════════
        // 1. CLOCK — "Timepiece" flavor: accent bar, bold time, AM/PM tag
        // ══════════════════════════════════════════════════════════════════
        Rectangle {
            id: clockWidget
            width:  Math.round(300 * scaleFactor)
            height: Math.round(130 * scaleFactor)
            radius: Math.round(20 * scaleFactor)
            color:  Qt.rgba(0.07, 0.07, 0.11, 0.50)
            border.color: Qt.rgba(1, 1, 1, 0.08)
            border.width: 1

            property string timeStr: "12:00"
            property string ampmStr: "AM"
            property string dateStr: "Monday, January 1"

            Timer {
                interval: 1000; running: true; repeat: true; triggeredOnStart: true
                onTriggered: {
                    var d = new Date();
                    var h  = d.getHours();
                    var m  = d.getMinutes();
                    var ms = m < 10 ? "0" + m : "" + m;
                    var ap = h >= 12 ? "PM" : "AM";
                    var dh = h % 12; if (dh === 0) dh = 12;
                    clockWidget.timeStr = dh + ":" + ms;
                    clockWidget.ampmStr = ap;
                    
                    var day = d.getDate();
                    var month = d.getMonth() + 1;
                    var year = d.getFullYear() % 100;
                    var dd = day < 10 ? "0" + day : day;
                    var mm = month < 10 ? "0" + month : month;
                    var yy = year < 10 ? "0" + year : year;
                    clockWidget.dateStr = dd + "/" + mm + "/" + yy;
                }
            }

            // Left accent bar
            Rectangle {
                x: 0; y: Math.round(18 * scaleFactor)
                width: Math.round(3 * scaleFactor)
                height: parent.height - Math.round(36 * scaleFactor)
                radius: Math.round(2 * scaleFactor)
                color: Qt.rgba(0.5, 0.72, 1.0, 0.55)
            }

            Item {
                anchors.fill: parent
                anchors.leftMargin: Math.round(20 * scaleFactor)
                anchors.rightMargin: Math.round(18 * scaleFactor)
                anchors.topMargin: Math.round(16 * scaleFactor)
                anchors.bottomMargin: Math.round(16 * scaleFactor)

                // AM/PM pill — top right
                Rectangle {
                    anchors.top: parent.top
                    anchors.right: parent.right
                    width: Math.round(34 * scaleFactor)
                    height: Math.round(18 * scaleFactor)
                    radius: Math.round(6 * scaleFactor)
                    color: Qt.rgba(1, 1, 1, 0.08)
                    Text {
                        anchors.centerIn: parent
                        text: clockWidget.ampmStr
                        color: Qt.rgba(1, 1, 1, 0.55)
                        font {
                            family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                            pixelSize: Math.round(10 * scaleFactor)
                            weight: Font.Medium
                        }
                    }
                }

                // Large time — left
                Text {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.topMargin: Math.round(-4 * scaleFactor)
                    text: clockWidget.timeStr
                    color: "#FFFFFF"
                    font {
                        family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                        pixelSize: Math.round(58 * scaleFactor)
                        weight: Font.Thin
                    }
                }

                // Date — bottom left
                Text {
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    text: clockWidget.dateStr
                    color: Qt.rgba(1, 1, 1, 0.42)
                    font {
                        family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                        pixelSize: Math.round(11 * scaleFactor)
                        weight: Font.Medium
                        letterSpacing: 0.3
                    }
                }
            }
        }

        // ══════════════════════════════════════════════════════════════════
        // 2. WEATHER — "Atmospheric" flavor: oversized icon watermark, temp hero
        // ══════════════════════════════════════════════════════════════════
        Rectangle {
            id: weatherWidget
            width:  Math.round(300 * scaleFactor)
            height: Math.round(148 * scaleFactor)
            radius: Math.round(20 * scaleFactor)
            color:  Qt.rgba(0.04, 0.08, 0.20, 0.52)
            border.color: Qt.rgba(1, 1, 1, 0.07)
            border.width: 1
            clip: true

            property string currentTemp: "--°"
            property string feelsLike:   "Feels like --°"
            property string weatherIcon: "󰖙"
            property string condition:   "Loading…"
            property string iconColor:   "#ffd86b"

            Process {
                id: pWidgetWeather
                command: [shellRoot ? (shellRoot.scriptsDir + "/weather.sh") : "/usr/bin/true", "full"]
                running: shellRoot !== null
                stdout: StdioCollector {
                    onStreamFinished: {
                        try {
                            var w    = JSON.parse(text.trim());
                            var temp = Math.round(w.current.temperature_2m);
                            var feel = Math.round(w.current.apparent_temperature);
                            var code = parseInt(w.current.weather_code);
                            weatherWidget.currentTemp = temp + "°";
                            weatherWidget.feelsLike   = "Feels like " + feel + "°";
                            var icon = "󰖙", col = "#ffd86b", cond = "Clear";
                            if      (code === 0)                               { icon = "󰖙"; col = "#ffd86b"; cond = "Clear"; }
                            else if (code >= 1  && code <= 3)                  { icon = "󰖕"; col = "#adadff"; cond = "Partly Cloudy"; }
                            else if (code === 45 || code === 48)               { icon = ""; col = "#84afdb"; cond = "Foggy"; }
                            else if (code >= 51 && code <= 55)                 { icon = "󰖗"; col = "#6b95ff"; cond = "Drizzle"; }
                            else if (code >= 61 && code <= 65)                 { icon = "󰖖"; col = "#6b95ff"; cond = "Rainy"; }
                            else if (code >= 71 && code <= 77)                 { icon = ""; col = "#e3e6fc"; cond = "Snowy"; }
                            else if (code >= 80 && code <= 82)                 { icon = "󰖗"; col = "#6b95ff"; cond = "Showers"; }
                            else if (code === 85 || code === 86)               { icon = ""; col = "#e3e6fc"; cond = "Snow Showers"; }
                            else if (code >= 95 && code <= 99)                 { icon = "󰖓"; col = "#ffeb57"; cond = "Thunderstorm"; }
                            else                                               { icon = "󰖐"; col = "#adadff"; cond = "Cloudy"; }
                            weatherWidget.weatherIcon = icon;
                            weatherWidget.iconColor   = col;
                            weatherWidget.condition   = cond;
                        } catch (e) { console.log("weather parse error: " + e); }
                    }
                }
            }
            Timer { interval: 300000; running: true; repeat: true; onTriggered: pWidgetWeather.running = true }



            // Content layer
            Item {
                anchors.fill: parent
                anchors.margins: Math.round(18 * scaleFactor)

                // Hero temperature — top left
                Text {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    text: weatherWidget.currentTemp
                    color: "#FFFFFF"
                    font {
                        family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                        pixelSize: Math.round(52 * scaleFactor)
                        weight: Font.Thin
                    }
                }

                // Small icon — top right
                Text {
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.topMargin: Math.round(4 * scaleFactor)
                    text:  weatherWidget.weatherIcon
                    color: weatherWidget.iconColor
                    font {
                        family: shellRoot ? shellRoot.iconFontFamily : "sans-serif"
                        pixelSize: Math.round(36 * scaleFactor)
                    }
                }

                // Condition + feels like + city — bottom
                Column {
                    anchors.left:   parent.left
                    anchors.bottom: parent.bottom
                    spacing: Math.round(2 * scaleFactor)

                    Text {
                        text: weatherWidget.condition
                        color: Qt.rgba(1, 1, 1, 0.75)
                        font {
                            family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                            pixelSize: Math.round(13 * scaleFactor)
                            weight: Font.Medium
                        }
                    }
                    Row {
                        spacing: Math.round(6 * scaleFactor)
                        Text {
                            text: weatherWidget.feelsLike
                            color: Qt.rgba(1, 1, 1, 0.40)
                            font { family: shellRoot ? shellRoot.fontFamily : "sans-serif"; pixelSize: Math.round(11 * scaleFactor) }
                        }
                        Text {
                            text: "· IIT Kanpur"
                            color: Qt.rgba(1, 1, 1, 0.22)
                            font { family: shellRoot ? shellRoot.fontFamily : "sans-serif"; pixelSize: Math.round(11 * scaleFactor) }
                        }
                    }
                }
            }
        }

        // ══════════════════════════════════════════════════════════════════
        // 3. STATS — "System Monitor" flavor: dark terminal, divider, spaced rings
        // ══════════════════════════════════════════════════════════════════
        Rectangle {
            id: statsWidget
            width:  Math.round(300 * scaleFactor)
            height: Math.round(120 * scaleFactor)
            radius: Math.round(20 * scaleFactor)
            color:  Qt.rgba(0.04, 0.04, 0.07, 0.62)
            border.color: Qt.rgba(1, 1, 1, 0.07)
            border.width: 1

            // SYSTEM label header
            Text {
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.topMargin: Math.round(10 * scaleFactor)
                text: "SYSTEM"
                color: Qt.rgba(1, 1, 1, 0.22)
                font {
                    family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                    pixelSize: Math.round(9 * scaleFactor)
                    weight: Font.Bold
                    letterSpacing: 2.5
                }
            }

            Row {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: Math.round(6 * scaleFactor)
                spacing: 0

                // CPU
                Column {
                    width: Math.round(130 * scaleFactor)
                    spacing: Math.round(6 * scaleFactor)
                    Item {
                        width:  Math.round(68 * scaleFactor)
                        height: Math.round(68 * scaleFactor)
                        anchors.horizontalCenter: parent.horizontalCenter
                        Canvas {
                            id: cpuCanvas
                            anchors.fill: parent
                            antialiasing: true
                            property real val: shellRoot ? Math.min(1.0, Math.max(0.0, parseInt(shellRoot.cpuUsage) / 100.0)) : 0.0
                            onValChanged: requestPaint()
                            onPaint: {
                                var ctx = getContext("2d");
                                ctx.reset();
                                var cx = width/2, cy = height/2, r = width/2 - 5, lw = 5.0 * scaleFactor;
                                ctx.beginPath(); ctx.arc(cx, cy, r, 0, 2*Math.PI);
                                ctx.strokeStyle = "rgba(255,159,10,0.14)"; ctx.lineWidth = lw; ctx.stroke();
                                if (val > 0) {
                                    ctx.beginPath(); ctx.arc(cx, cy, r, -Math.PI/2, -Math.PI/2 + val*2*Math.PI);
                                    ctx.strokeStyle = "#FF9F0A"; ctx.lineWidth = lw; ctx.lineCap = "round"; ctx.stroke();
                                }
                            }
                        }
                        Column {
                            anchors.centerIn: parent
                            spacing: 0
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: shellRoot ? shellRoot.cpuUsage : "0"; color: "#FFFFFF"; font { family: shellRoot ? shellRoot.fontFamily : "sans-serif"; pixelSize: Math.round(14 * scaleFactor); weight: Font.SemiBold } }
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: "%"; color: Qt.rgba(1,1,1,0.35); font { family: shellRoot ? shellRoot.fontFamily : "sans-serif"; pixelSize: Math.round(8 * scaleFactor) } }
                        }
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "CPU"
                        color: Qt.rgba(1, 1, 1, 0.35)
                        font { family: shellRoot ? shellRoot.fontFamily : "sans-serif"; pixelSize: Math.round(10 * scaleFactor); weight: Font.Medium; letterSpacing: 1.2 }
                    }
                }

                // Divider
                Rectangle {
                    width: 1
                    height: Math.round(60 * scaleFactor)
                    anchors.verticalCenter: parent.verticalCenter
                    color: Qt.rgba(1, 1, 1, 0.10)
                }

                // RAM
                Column {
                    width: Math.round(130 * scaleFactor)
                    spacing: Math.round(6 * scaleFactor)
                    Item {
                        width:  Math.round(68 * scaleFactor)
                        height: Math.round(68 * scaleFactor)
                        anchors.horizontalCenter: parent.horizontalCenter
                        Canvas {
                            id: ramCanvas
                            anchors.fill: parent
                            antialiasing: true
                            property real val: shellRoot ? Math.min(1.0, Math.max(0.0, parseInt(shellRoot.ramUsage) / 100.0)) : 0.0
                            onValChanged: requestPaint()
                            onPaint: {
                                var ctx = getContext("2d");
                                ctx.reset();
                                var cx = width/2, cy = height/2, r = width/2 - 5, lw = 5.0 * scaleFactor;
                                ctx.beginPath(); ctx.arc(cx, cy, r, 0, 2*Math.PI);
                                ctx.strokeStyle = "rgba(10,132,255,0.14)"; ctx.lineWidth = lw; ctx.stroke();
                                if (val > 0) {
                                    ctx.beginPath(); ctx.arc(cx, cy, r, -Math.PI/2, -Math.PI/2 + val*2*Math.PI);
                                    ctx.strokeStyle = "#0A84FF"; ctx.lineWidth = lw; ctx.lineCap = "round"; ctx.stroke();
                                }
                            }
                        }
                        Column {
                            anchors.centerIn: parent
                            spacing: 0
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: shellRoot ? shellRoot.ramUsage : "0"; color: "#FFFFFF"; font { family: shellRoot ? shellRoot.fontFamily : "sans-serif"; pixelSize: Math.round(14 * scaleFactor); weight: Font.SemiBold } }
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: "%"; color: Qt.rgba(1,1,1,0.35); font { family: shellRoot ? shellRoot.fontFamily : "sans-serif"; pixelSize: Math.round(8 * scaleFactor) } }
                        }
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "RAM"
                        color: Qt.rgba(1, 1, 1, 0.35)
                        font { family: shellRoot ? shellRoot.fontFamily : "sans-serif"; pixelSize: Math.round(10 * scaleFactor); weight: Font.Medium; letterSpacing: 1.2 }
                    }
                }
            }
        }

        // ══════════════════════════════════════════════════════════════════
        // 4. BATTERY — "Health" flavor: dynamic tint + health bar
        // ══════════════════════════════════════════════════════════════════
        Rectangle {
            id: batteryWidget
            width:  Math.round(300 * scaleFactor)
            height: Math.round(120 * scaleFactor)
            radius: Math.round(20 * scaleFactor)
            color: {
                if (charging) return Qt.rgba(0.02, 0.12, 0.04, 0.52);
                if (batVal < 0.15) return Qt.rgba(0.14, 0.02, 0.02, 0.52);
                if (batVal < 0.40) return Qt.rgba(0.14, 0.08, 0.01, 0.52);
                return Qt.rgba(0.02, 0.12, 0.04, 0.52);
            }
            border.color: Qt.rgba(1, 1, 1, 0.08)
            border.width: 1
            Behavior on color { ColorAnimation { duration: 600 } }

            property real batVal: shellRoot ? Math.min(1.0, Math.max(0.0, parseInt(shellRoot.batteryCap) / 100.0)) : 0.0
            property bool charging: shellRoot ? shellRoot.batteryCharging : false
            property string arcColor: {
                if (charging) return "#30D158";
                if (batVal < 0.15) return "#FF453A";
                if (batVal < 0.40) return "#FF9F0A";
                return "#30D158";
            }

            Row {
                anchors.centerIn: parent
                spacing: Math.round(20 * scaleFactor)

                // Ring
                Item {
                    width:  Math.round(80 * scaleFactor)
                    height: Math.round(80 * scaleFactor)
                    anchors.verticalCenter: parent.verticalCenter
                    Canvas {
                        id: batteryCanvas
                        anchors.fill: parent
                        antialiasing: true
                        property real val: batteryWidget.batVal
                        property string col: batteryWidget.arcColor
                        onValChanged: requestPaint()
                        onColChanged: requestPaint()
                        onPaint: {
                            var ctx = getContext("2d");
                            ctx.reset();
                            var cx = width/2, cy = height/2, r = width/2 - 5, lw = 6.0 * scaleFactor;
                            ctx.beginPath(); ctx.arc(cx, cy, r, 0, 2*Math.PI);
                            ctx.strokeStyle = "rgba(255,255,255,0.08)"; ctx.lineWidth = lw; ctx.stroke();
                            if (val > 0) {
                                ctx.beginPath(); ctx.arc(cx, cy, r, -Math.PI/2, -Math.PI/2 + val*2*Math.PI);
                                ctx.strokeStyle = batteryWidget.arcColor; ctx.lineWidth = lw; ctx.lineCap = "round"; ctx.stroke();
                            }
                        }
                    }
                    Column {
                        anchors.centerIn: parent
                        spacing: 0
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: shellRoot ? shellRoot.batteryCap : "0"; color: "#FFFFFF"; font { family: shellRoot ? shellRoot.fontFamily : "sans-serif"; pixelSize: Math.round(20 * scaleFactor); weight: Font.Bold } }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "%"; color: Qt.rgba(1,1,1,0.38); font { family: shellRoot ? shellRoot.fontFamily : "sans-serif"; pixelSize: Math.round(9 * scaleFactor) } }
                    }
                }

                // Status + health bar
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Math.round(5 * scaleFactor)
                    Row {
                        spacing: Math.round(6 * scaleFactor)
                        Text { anchors.verticalCenter: parent.verticalCenter; text: batteryWidget.charging ? "󱐋" : "󰁹"; color: batteryWidget.arcColor; font { family: shellRoot ? shellRoot.iconFontFamily : "sans-serif"; pixelSize: Math.round(16 * scaleFactor) } }
                        Text { anchors.verticalCenter: parent.verticalCenter; text: batteryWidget.charging ? "Charging" : "Battery"; color: "#FFFFFF"; font { family: shellRoot ? shellRoot.fontFamily : "sans-serif"; pixelSize: Math.round(14 * scaleFactor); weight: Font.SemiBold } }
                    }
                    Text {
                        text: {
                            if (!shellRoot) return "—";
                            var ts = shellRoot.batteryTimeStr;
                            if (!ts || ts === "") return batteryWidget.charging ? "Estimating…" : "Discharging";
                            return ts;
                        }
                        color: Qt.rgba(1, 1, 1, 0.40)
                        font { family: shellRoot ? shellRoot.fontFamily : "sans-serif"; pixelSize: Math.round(11 * scaleFactor) }
                    }
                    // Animated health bar
                    Rectangle {
                        width: Math.round(120 * scaleFactor)
                        height: Math.round(4 * scaleFactor)
                        radius: Math.round(2 * scaleFactor)
                        color: Qt.rgba(1, 1, 1, 0.10)
                        Rectangle {
                            width: Math.round(parent.width * batteryWidget.batVal)
                            height: parent.height
                            radius: parent.radius
                            color: batteryWidget.arcColor
                            Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
                        }
                    }
                }
            }
        }
    }
}
