import Quickshell
import QtQuick
import QtQuick.Layouts
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import "Singletons"

PanelWindow {
    id: hudWindow

    property var shellRoot: null
    readonly property real scaleFactor: shellRoot ? shellRoot.scaleFactor : 1.0
    readonly property string monoFont: "Ioskeley Mono"
    readonly property string iconFont: "Symbols Nerd Font"

    // Occlusion Culling: Automatically hide wallpaper HUD when a window is fullscreened
    visible: !(shellRoot && shellRoot.isWindowFullscreen)

    FontLoader { source: "file:///home/krishna/.local/share/fonts/i/IoskeleyMono_Regular.ttf" }
    FontLoader { source: "file:///home/krishna/.local/share/fonts/i/IoskeleyMono_Bold.ttf" }
    FontLoader { source: "file:///home/krishna/.local/share/fonts/i/IoskeleyMono_Medium.ttf" }
    FontLoader { source: "file:///home/krishna/.local/share/fonts/i/IoskeleyMono_SemiBold.ttf" }

    property bool isEditingScratch: false
    property bool showWeeklyScreenTime: false
    property bool showF1Overlay: false
    property bool showEmailOverlay: false
    property bool showWifiOverlay: false
    property bool showBtOverlay: false
    property var networkOverlayData: null
    property var btOverlayData: null
    property bool showNotificationDeck: false

    // Custom Timer Input Deck
    property bool showTimerCustomInput: false
    property string customTimerMinutes: "10"

    // Hardware Mic Control State
    property int hudMicVolumePct: 100
    property bool hudMicMuted: false

    // Synced Lyrics State
    property bool hudLyricsSynced: false
    property int hudActiveLyricIndex: -1
    property string hudCurrentTrackKey: ""

    // ── GAP CONFIGURATION: Distance from bottom of top bar (36px) to HUD separator ──
    // 36px = flush against bar (0px gap)
    // 42px = 6px gap below bar
    // 46px = 10px gap below bar
    property int topRailHeight: Math.round(46 * scaleFactor)

    function getWorldTime(offsetMs) {
        var _tick = hudWindow.clockMinutes;
        var d = new Date(Date.now() + offsetMs);
        var h = d.getUTCHours();
        var m = d.getUTCMinutes();
        return (h < 10 ? "0" : "") + h + ":" + (m < 10 ? "0" : "") + m;
    }

    function formatTimeSec(sec) {
        if (!sec || isNaN(sec) || sec <= 0) return "00:00";
        var m = Math.floor(sec / 60);
        var s = Math.floor(sec % 60);
        return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s;
    }

    Process {
        id: pOpenNvim
        command: ["sh", "-c", "kitty --class kitty-scratchpad -e nvim ~/.cache/quickshell/scratchpad.md 2>/dev/null || nvim ~/.cache/quickshell/scratchpad.md"]
    }

    Process {
        id: pRunPacman
        command: ["sh", "-c", "kitty -e sudo pacman -Syu"]
    }

    // ── Hardware Mic Control Process ──────────────────────────────────────────
    Process {
        id: pHudMic
        command: []
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                var line = data.trim();
                if (!line) return;
                var parts = line.split("|");
                if (parts.length >= 2) {
                    hudWindow.hudMicVolumePct = parseInt(parts[0]) || 100;
                    hudWindow.hudMicMuted = (parts[1] === "true");
                }
            }
        }
    }

    function updateHudMic() {
        pHudMic.command = ["/home/krishna/dotfiles/scripts/hud_mic_control.sh", "get"];
        pHudMic.running = true;
    }

    function setHudMicVolume(volNorm) {
        pHudMic.command = ["/home/krishna/dotfiles/scripts/hud_mic_control.sh", "set", volNorm.toFixed(2)];
        pHudMic.running = true;
    }

    function toggleHudMicMute() {
        pHudMic.command = ["/home/krishna/dotfiles/scripts/hud_mic_control.sh", "toggle"];
        pHudMic.running = true;
    }

    // ── Network & Bluetooth Info for Card [09] Overlays ───────────────────────
    Process {
        id: pFetchNetworkInfo
        command: ["/home/krishna/dotfiles/scripts/hud_network_info.sh", "network"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                try {
                    hudWindow.networkOverlayData = JSON.parse(data.trim());
                } catch(e) {}
            }
        }
    }

    Process {
        id: pFetchBtInfo
        command: ["/home/krishna/dotfiles/scripts/hud_network_info.sh", "bluetooth"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                try {
                    hudWindow.btOverlayData = JSON.parse(data.trim());
                } catch(e) {}
            }
        }
    }

    function toggleWifiOverlay() {
        hudWindow.showBtOverlay = false;
        hudWindow.showWifiOverlay = !hudWindow.showWifiOverlay;
        if (hudWindow.showWifiOverlay) pFetchNetworkInfo.running = true;
    }

    function toggleBtOverlay() {
        hudWindow.showWifiOverlay = false;
        hudWindow.showBtOverlay = !hudWindow.showBtOverlay;
        if (hudWindow.showBtOverlay) pFetchBtInfo.running = true;
    }

    function toggleNotificationDeck() {
        hudWindow.showNotificationDeck = !hudWindow.showNotificationDeck;
        console.log("[Quickshell] toggleNotificationDeck! now=" + hudWindow.showNotificationDeck);
    }

    function toggleScratchTodo(lineIndex) {
        var raw = (hudWindow.hudData && hudWindow.hudData.scratchpad) ? hudWindow.hudData.scratchpad : "";
        var lines = raw.split("\n");
        if (lineIndex >= 0 && lineIndex < lines.length) {
            var l = lines[lineIndex];
            if (l.match(/^(\s*[-*]\s*)\[ \]/)) {
                lines[lineIndex] = l.replace(/^(\s*[-*]\s*)\[ \]/, "$1[x]");
            } else if (l.match(/^(\s*[-*]\s*)\[[xX]\]/)) {
                lines[lineIndex] = l.replace(/^(\s*[-*]\s*)\[[xX]\]/, "$1[ ]");
            }
            var updated = lines.join("\n");
            if (hudWindow.hudData) hudWindow.hudData.scratchpad = updated;
            hudWindow.saveScratchText(updated);
        }
    }

    // Wayland Bottom Layer (Receives hover & clicks below client windows)
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "quickshell_terminal_hud"
    WlrLayershell.keyboardFocus: (isEditingScratch || showTimerCustomInput) ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    WlrLayershell.exclusiveZone: -1

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    // PURE OLED BLACK TERMINAL CHASSIS (#000000)
    color: "#000000"

    // Mask for interactive controls on desktop background
    mask: Region {
        Region { item: card01Container }
        Region { item: screenTimeToggleBtn }
        Region { item: pacmanBtn }
        Region { item: interactiveSlidersArea }
        Region { item: interactiveMicArea }
        Region { item: interactiveTogglesArea }
        Region { item: interactiveF1Area }
        Region { item: interactiveEmailArea }
        Region { item: !hudWindow.showNotificationDeck ? interactiveAudioArea : null }
        Region { item: interactiveTasksArea }
        Region { item: pomoDeckArea }
        Region { item: audioFftArea }
        Region { item: !hudWindow.showNotificationDeck ? editScratchBtn : null }
        Region { item: !hudWindow.showNotificationDeck ? interactiveScratchArea : null }
        Region { item: f1OverlayArea }
        Region { item: emailOverlayArea }
        Region { item: (!hudWindow.showNotificationDeck && typeof wifiOverlayArea !== "undefined") ? wifiOverlayArea : null }
        Region { item: (!hudWindow.showNotificationDeck && typeof btOverlayArea !== "undefined") ? btOverlayArea : null }
        Region { item: (!hudWindow.showNotificationDeck && typeof notifToggleBtn !== "undefined") ? notifToggleBtn : null }
        Region { item: (hudWindow.showNotificationDeck && typeof notificationDeckArea !== "undefined") ? notificationDeckArea : null }
    }

    // Master Telemetry Vector Rendering Timer (25 FPS, ultralight CPU)
    Timer {
        id: hudAnimTimer
        interval: 40
        running: true
        repeat: true
        onTriggered: {
            if (typeof buckyCanvas !== "undefined" && buckyCanvas.visible) {
                buckyCanvas.rotAngle += 0.035;
                buckyCanvas.requestPaint();
            }
            if (typeof uavFbdCanvas !== "undefined" && uavFbdCanvas.visible) {
                uavFbdCanvas.rotorAngle += 0.35;
                uavFbdCanvas.requestPaint();
            }
            if (typeof lidarCanvas !== "undefined" && lidarCanvas.visible) {
                lidarCanvas.sweepAngle = (lidarCanvas.sweepAngle + 0.05) % (2 * Math.PI);
                lidarCanvas.requestPaint();
            }
        }
    }

    // ── Persistent Scratchpad Save Process ────────────────────────────────────
    Process {
        id: pSaveScratch
        command: []
    }

    function saveScratchText(txt) {
        try {
            var b64 = Qt.btoa(txt);
            pSaveScratch.command = ["python3", Quickshell.env("HOME") + "/dotfiles/scripts/scratchpad_manager.py", "--set-b64", b64];
            pSaveScratch.running = true;
        } catch(e) {}
    }

    // ── HUD Native F1 Calendar Overlay Engine ─────────────────────────────────
    ListModel {
        id: f1CalendarModel
    }

    Process {
        id: pFetchF1Calendar
        command: ["python3", Quickshell.env("HOME") + "/dotfiles/scripts/f1_checker.py", "--four-weeks"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                var line = data.trim();
                if (!line) return;
                var parts = line.split("|");
                if (parts.length >= 2) {
                    f1CalendarModel.append({
                        event: parts[0],
                        timeStr: parts[1],
                        location: parts.length > 2 ? parts[2] : ""
                    });
                }
            }
        }
    }

    function toggleF1Overlay() {
        hudWindow.showEmailOverlay = false;
        hudWindow.showF1Overlay = !hudWindow.showF1Overlay;
        if (hudWindow.showF1Overlay) {
            f1CalendarModel.clear();
            pFetchF1Calendar.running = true;
        }
    }

    function toggleEmailOverlay() {
        hudWindow.showF1Overlay = false;
        hudWindow.showEmailOverlay = !hudWindow.showEmailOverlay;
    }

    // ── HUD Native Synced Lyrics Engine ───────────────────────────────────────
    ListModel {
        id: hudLyricsModel
    }

    Process {
        id: pHudLyrics
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                var line = data.trim();
                if (!line) return;
                try {
                    var parsed = JSON.parse(line);
                    hudWindow.hudLyricsSynced = parsed.synced || false;
                    hudLyricsModel.clear();
                    if (parsed.lyrics && parsed.lyrics.length > 0) {
                        for (var i = 0; i < parsed.lyrics.length; i++) {
                            hudLyricsModel.append({
                                time: parsed.lyrics[i].time,
                                text: parsed.lyrics[i].text
                            });
                        }
                    } else {
                        hudLyricsModel.append({ time: -1, text: "Instrumental / No Lyrics Available" });
                    }
                    hudWindow.updateHudLyric();
                } catch(e) {}
            }
        }
    }

    function fetchHudLyrics() {
        var t = Players.has ? Players.title : "";
        var a = Players.has ? Players.artist : "";
        var key = t + "::" + a;
        if (key === hudWindow.hudCurrentTrackKey && hudLyricsModel.count > 0) return;
        hudWindow.hudCurrentTrackKey = key;
        hudLyricsModel.clear();
        hudWindow.hudActiveLyricIndex = -1;
        hudWindow.hudLyricsSynced = false;
        if (!t) return;

        var pName = Players.has ? (Players.active.identity || Players.active.desktopEntry || "") : "";
        var args = [
            "python3",
            Quickshell.env("HOME") + "/dotfiles/scripts/extract_lyrics.py",
            "--artist", a,
            "--title", t,
            "--duration", String(Players.has && Players.active ? Math.round(Players.lengthSec) : 0),
            "--player", pName
        ];
        pHudLyrics.command = args;
        pHudLyrics.running = true;
    }

    function updateHudLyric() {
        if (!hudWindow.hudLyricsSynced || hudLyricsModel.count === 0) {
            hudWindow.hudActiveLyricIndex = -1;
            return;
        }
        var cur = (Players.has && Players.active) ? Players.active.position : 0.0;
        var match = -1;
        for (var i = 0; i < hudLyricsModel.count; i++) {
            var itemTime = hudLyricsModel.get(i).time;
            if (itemTime <= cur + 0.25) {
                match = i;
            } else {
                break;
            }
        }
        if (match !== hudWindow.hudActiveLyricIndex) {
            hudWindow.hudActiveLyricIndex = match;
        }
    }

    Timer {
        id: hudLyricSyncTimer
        interval: 150
        running: Players.playing && hudWindow.hudLyricsSynced
        repeat: true
        onTriggered: hudWindow.updateHudLyric()
    }

    Timer {
        id: hudTrackWatchTimer
        interval: 400
        running: true
        repeat: true
        onTriggered: {
            var key = (Players.has ? Players.title : "") + "::" + (Players.has ? Players.artist : "");
            if (key !== hudWindow.hudCurrentTrackKey && key !== "::") {
                hudWindow.fetchHudLyrics();
            }
        }
    }

    // ── Music Playback Direct & Fallback Processes ────────────────────────────
    Process {
        id: pMpcToggle
        command: ["mpc", "toggle"]
    }
    Process {
        id: pMpcNext
        command: ["mpc", "next"]
    }
    Process {
        id: pMpcPrev
        command: ["mpc", "prev"]
    }
    Process {
        id: pMpcSeek
        property int targetSec: 0
        command: ["mpc", "seek", String(targetSec)]
    }
    Process {
        id: pPlayerctlToggle
        command: ["playerctl", "play-pause"]
    }
    Process {
        id: pPlayerctlNext
        command: ["playerctl", "next"]
    }
    Process {
        id: pPlayerctlPrev
        command: ["playerctl", "previous"]
    }

    function togglePlayback() {
        var isMpd = (Players.has && Players.active && (Players.playerName === "mpd" || Players.active.identity === "mpd")) || (!Players.has);
        if (isMpd) {
            if (pMpcToggle.running) pMpcToggle.running = false;
            pMpcToggle.running = true;
        } else if (Players.has && Players.active) {
            try {
                if (Players.active.canTogglePlaying) {
                    Players.active.togglePlaying();
                } else if (Players.playing) {
                    Players.active.pause();
                } else {
                    Players.active.play();
                }
            } catch(e) {
                if (pPlayerctlToggle.running) pPlayerctlToggle.running = false;
                pPlayerctlToggle.running = true;
            }
        } else {
            if (pPlayerctlToggle.running) pPlayerctlToggle.running = false;
            pPlayerctlToggle.running = true;
        }
    }

    function previousTrack() {
        var isMpd = (Players.has && Players.active && (Players.playerName === "mpd" || Players.active.identity === "mpd")) || (!Players.has);
        if (isMpd) {
            if (pMpcPrev.running) pMpcPrev.running = false;
            pMpcPrev.running = true;
        } else if (Players.has && Players.active && Players.active.canGoPrevious) {
            try {
                Players.active.previous();
            } catch(e) {
                if (pPlayerctlPrev.running) pPlayerctlPrev.running = false;
                pPlayerctlPrev.running = true;
            }
        } else {
            if (pPlayerctlPrev.running) pPlayerctlPrev.running = false;
            pPlayerctlPrev.running = true;
        }
    }

    function nextTrack() {
        var isMpd = (Players.has && Players.active && (Players.playerName === "mpd" || Players.active.identity === "mpd")) || (!Players.has);
        if (isMpd) {
            if (pMpcNext.running) pMpcNext.running = false;
            pMpcNext.running = true;
        } else if (Players.has && Players.active && Players.active.canGoNext) {
            try {
                Players.active.next();
            } catch(e) {
                if (pPlayerctlNext.running) pPlayerctlNext.running = false;
                pPlayerctlNext.running = true;
            }
        } else {
            if (pPlayerctlNext.running) pPlayerctlNext.running = false;
            pPlayerctlNext.running = true;
        }
    }

    function seekTo(sec) {
        if (Players.has && Players.active) {
            try {
                Players.active.position = sec;
            } catch(e) {}
        }
    }

    function seekAudioPosition(sec) {
        seekTo(sec);
        if (Players.has && Players.active && Players.playerName === "mpd") {
            pMpcSeek.targetSec = Math.round(sec);
            pMpcSeek.running = true;
        }
    }

    // ── Telemetry State ──────────────────────────────────────────────────────
    property var hudData: ({
        epoch: 0,
        utc_zulu: "--:--:--Z",
        doy: 0,
        week: 0,
        uptime: "--",
        cpu_pct: 0.0,
        cpu_temp: 0,
        cpu_freq: 0.0,
        cpu_spark: "",
        cpu_cores: [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
        load: "0.00 0.00 0.00",
        mem_str: "-- / --",
        mem_pct: 0.0,
        disk_str: "-- / --",
        disk_pct: 0.0,
        disk_io_str: "R: 0 B/s │ W: 0 B/s",
        pkg_temp: 44.0,
        peak_temp: 87,
        mem_used_gb: 0.0,
        mem_total_gb: 31.2,
        mem_cached_gb: 0.0,
        mem_cached_pct: 0.0,
        disk_used_gb: 0.0,
        disk_total_gb: 217.0,
        disk_read_str: "0 B/s",
        disk_write_str: "0 B/s",
        disk_iops: 0,
        sunrise: "06:15",
        sunset: "17:30",
        daylight_rem: "--",
        daylight_pct: 0.0,
        active_iface: "wlan0",
        net_rx_str: "0 B/s",
        net_tx_str: "0 B/s",
        net_total_rx: "0 MB",
        net_total_tx: "0 MB",
        net_rx_spark: "",
        net_tx_spark: "",
        processes: [],
        proc_summary: {
            active_threads: 1600,
            context_sw_s: "14.2k",
            procs_running: 2,
            procs_sleeping: 450,
            top_bottleneck: "quickshell",
            fault_rate: "0.2/s"
        },
        f1: {
            race_name: "Brazilian GP",
            session: "Race",
            location: "Sao Paulo",
            time_str: "Sun, Nov 08 • 22:30",
            countdown: "14h 08m"
        },
        tasks: [],
        app_time: {
            total_formatted: "0m",
            apps: []
        },
        clip: "─ no clipboard entries ─",
        scratchpad: "",
        git: {
            branch: "pc",
            modified: 0,
            deleted: 0,
            untracked: 0,
            total: 0,
            last_commit: ""
        },
        vpn: {
            active: false,
            name: "TAILSCALE",
            status: "STANDBY"
        }
    })

    // ── Telemetry Polling (Every 1.8 seconds via Native Rust Daemon) ─────────
    Process {
        id: pTelemetry
        command: [Quickshell.env("HOME") + "/dotfiles/quickshell-daemon/target/release/quickshell-daemon", "telemetry"]
        stdout: SplitParser {
            onRead: data => {
                try {
                    hudWindow.hudData = JSON.parse(data);
                } catch(e) {}
            }
        }
    }

    Timer {
        interval: 1800
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            pTelemetry.running = true;
            hudWindow.updateHudMic();
        }
    }

    // ── Headless Mathematical Physics Simulation Daemon (25 Hz Stream) ──────
    property var simData: null

    // ── Real-Time Universal Audio Visualizer Stream (Native Rust Engine) ──────
    property var mpdFftBands: []
    property var mpdFftPeaks: []

    Process {
        id: pMpdFftStream
        command: [Quickshell.env("HOME") + "/dotfiles/quickshell-daemon/target/release/quickshell-daemon", "audio"]
        running: Players.playing
        onRunningChanged: {
            if (!running) {
                hudWindow.mpdFftBands = [];
                hudWindow.mpdFftPeaks = [];
            }
        }
        stdout: SplitParser {
            splitMarker: "
"
            onRead: data => {
                var line = data.trim();
                if (!line) return;
                try {
                    var parsed = JSON.parse(line);
                    if (parsed && parsed.bands) {
                        hudWindow.mpdFftBands = parsed.bands;
                        hudWindow.mpdFftPeaks = parsed.peaks || parsed.bands;
                    } else if (Array.isArray(parsed)) {
                        hudWindow.mpdFftBands = parsed;
                        hudWindow.mpdFftPeaks = parsed;
                    }
                } catch(e) {}
            }
        }
    }

    // Master Chrono Precision Timer (1s cadence)
    property string clockHours: "00"
    property string clockMinutes: "00"
    property string clockSeconds: "00"
    property string clockTenths: "0"
    property string clockDateStr: "SUN, 08 NOV 2026"

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            var d = new Date();
            var h = d.getHours();
            var m = d.getMinutes();
            var s = d.getSeconds();
            hudWindow.clockHours = (h < 10 ? "0" : "") + h;
            hudWindow.clockMinutes = (m < 10 ? "0" : "") + m;
            hudWindow.clockSeconds = (s < 10 ? "0" : "") + s;
            hudWindow.clockTenths = "0";
            var days = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"];
            var months = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"];
            var dayNum = (d.getDate() < 10 ? "0" : "") + d.getDate();
            hudWindow.clockDateStr = days[d.getDay()] + ", " + dayNum + " " + months[d.getMonth()] + " " + d.getFullYear();
        }
    }

    // ── Helper formatters ───────────────────────────────────────────────────
    function makeBar(pct, totalChars) {
        var p = Math.max(0.0, Math.min(1.0, pct / 100.0));
        var filled = Math.round(p * totalChars);
        var empty = Math.max(0, totalChars - filled);
        var res = "";
        for (var i = 0; i < filled; i++) res += "█";
        for (var j = 0; j < empty; j++) res += "░";
        return "[" + res + "]";
    }

    function makeLineBar(pct, totalChars) {
        var p = Math.max(0.0, Math.min(1.0, pct / 100.0));
        var filled = Math.round(p * totalChars);
        var empty = Math.max(0, totalChars - filled);
        var res = "";
        for (var i = 0; i < filled; i++) res += "━";
        res += "●";
        for (var j = 0; j < empty; j++) res += "─";
        return "[" + res + "]";
    }

    function makeBlockGauge(pct, totalBlocks) {
        var p = Math.max(0.0, Math.min(1.0, pct / 100.0));
        var filled = Math.round(p * totalBlocks);
        var empty = Math.max(0, totalBlocks - filled);
        var res = "";
        for (var i = 0; i < filled; i++) res += "■";
        for (var j = 0; j < empty; j++) res += "□";
        return "[" + res + "]";
    }

    function formatBytesRate(b) {
        if (!b || b <= 0) return "0 B/s";
        if (b < 1024) return Math.round(b) + " B/s";
        if (b < 1024 * 1024) return (b / 1024).toFixed(1) + " KB/s";
        return (b / (1024 * 1024)).toFixed(1) + " MB/s";
    }

    function makeBrailleCoreMatrix(coresArr) {
        if (!coresArr || coresArr.length === 0) return "[ ■■□□ ■■□□ ■■□□ ■■□□ ]";
        var res = "";
        for (var i = 0; i < coresArr.length; i++) {
            var val = coresArr[i] || 0;
            if (val > 75) res += "█";
            else if (val > 50) res += "▆";
            else if (val > 25) res += "▄";
            else if (val > 5) res += "▂";
            else res += " ";
            if ((i + 1) % 4 === 0 && i < coresArr.length - 1) res += " ";
        }
        return "[ " + res + " ]";
    }

    function makeSunOrbitalArc(pct) {
        var p = Math.max(0.0, Math.min(1.0, pct));
        var total = 22;
        var pos = Math.round(p * (total - 1));
        var left = "";
        for (var i = 0; i < pos; i++) left += "─";
        var right = "";
        for (var j = pos + 1; j < total; j++) right += "─";
        return left + "( ● )" + right;
    }

    // ═════════════════════════════════════════════════════════════════════════
    // MONOLITHIC FULL-SCREEN BLOOMBERG / BTOP TERMINAL GRID
    // ═════════════════════════════════════════════════════════════════════════
    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ─────────────────────────────────────────────────────────────────────
        // 1. TOP HEADER RAIL (y: 0 to 36px) — Unified 3-Column Top Dock
        // ─────────────────────────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: hudWindow.topRailHeight
            Layout.maximumHeight: hudWindow.topRailHeight
            spacing: 0

            // Column 1 Top Rail (28% width)
            Rectangle {
                Layout.preferredWidth: Math.round(parent.width * 0.28)
                Layout.fillHeight: true
                color: "#000000"
                border.color: "#181d26"
                border.width: 1
            }

            // Column 2 Top Rail (44% width)
            Rectangle {
                Layout.preferredWidth: Math.round(parent.width * 0.44)
                Layout.fillHeight: true
                color: "#000000"
                border.color: "#181d26"
                border.width: 1
            }

            // Column 3 Top Rail (28% width)
            Rectangle {
                Layout.preferredWidth: Math.round(parent.width * 0.28)
                Layout.fillHeight: true
                color: "#000000"
                border.color: "#181d26"
                border.width: 1
            }
        }

        // ─────────────────────────────────────────────────────────────────────
        // 2. MAIN 3-COLUMN TUI MATRIX (Fills 100% of Screen Height)
        // ─────────────────────────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            // ═════════════════════════════════════════════════════════════════
            // COLUMN 1: TELEMETRY, SENSORS & PROCESSES (28% Width)
            // ═════════════════════════════════════════════════════════════════
            ColumnLayout {
                Layout.preferredWidth: Math.round(parent.width * 0.28)
                Layout.fillHeight: true
                spacing: 0

                // ── PANE 1A: EXECUTIVE MONITOR // WORKSPACE & FOCUS (~320px) ─────
                // NOTE [Vertical Space Balance / Planned expansion]:
                // Currently set to 320 * scaleFactor with padding reserved for future telemetry
                // (e.g. project git branch trackers, deep focus scoring, or workspace heatmaps).
                // If not expanded, this can be tightened to ~280px to yield +40px to Card [03].
                Rectangle {
                    id: card01Container
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.round(320 * scaleFactor)
                    color: "#000000"
                    border.color: "#181d26"
                    border.width: 1

                    readonly property var curApps: {
                        var at = (hudWindow.hudData && hudWindow.hudData.app_time) ? hudWindow.hudData.app_time : null;
                        if (!at) return [];
                        if (hudWindow.showWeeklyScreenTime) {
                            return (at.week_apps && at.week_apps.length > 0) ? at.week_apps : (at.apps || []);
                        } else {
                            return (at.today_apps && at.today_apps.length > 0) ? at.today_apps : (at.apps || []);
                        }
                    }
                    readonly property string totalStr: {
                        var at = (hudWindow.hudData && hudWindow.hudData.app_time) ? hudWindow.hudData.app_time : null;
                        if (!at) return "0m";
                        return hudWindow.showWeeklyScreenTime ? (at.week_total || "0m") : (at.today_total || "0m");
                    }
                    readonly property string focusedWsStr: {
                        if (Hyprland.focusedWorkspace) {
                            var id = Hyprland.focusedWorkspace.id;
                            var name = Hyprland.focusedWorkspace.name || "";
                            return "[" + (id < 10 ? "0" + id : id) + ": " + (name !== "" + id ? name.toUpperCase() : "DEV") + "]";
                        }
                        return "[01: MAIN]";
                    }
                    readonly property string activeWinClass: {
                        if (shellRoot && shellRoot.activeWindowClass && shellRoot.activeWindowClass !== "") {
                            return shellRoot.activeWindowClass.toLowerCase();
                        }
                        return "desktop";
                    }
                    readonly property bool isFocusLocked: {
                        return activeWinClass !== "desktop" && activeWinClass !== "";
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Math.round(10 * scaleFactor)
                        spacing: Math.round(5 * scaleFactor)

                        // 1. TOP HEADER: Monospace title + Window Toggle + TE Accent Badge
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Math.round(6 * scaleFactor)

                            Text {
                                text: "┌─ [01] WORKSPACE FOCUS"
                                color: "#0A84FF"
                                font { family: hudWindow.monoFont; pixelSize: Math.round(11 * scaleFactor); bold: true }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                height: 1
                                color: "#212836"
                                Layout.alignment: Qt.AlignVCenter
                            }

                            // Interactive Today / 7-Day Window Toggle
                            Rectangle {
                                id: screenTimeToggleBtn
                                width: Math.round(68 * scaleFactor)
                                height: Math.round(18 * scaleFactor)
                                color: hudWindow.showWeeklyScreenTime ? "#101d2d" : "#0d1b2a"
                                border.color: hudWindow.showWeeklyScreenTime ? "#0A84FF" : "#38bdf8"
                                border.width: 1
                                radius: 2

                                Text {
                                    anchors.centerIn: parent
                                    text: hudWindow.showWeeklyScreenTime ? "[ 7-DAY ]" : "[ TODAY ]"
                                    color: hudWindow.showWeeklyScreenTime ? "#64D2FF" : "#38bdf8"
                                    font { family: hudWindow.monoFont; pixelSize: Math.round(9 * scaleFactor); bold: true }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: hudWindow.showWeeklyScreenTime = !hudWindow.showWeeklyScreenTime
                                }
                            }

                            // TE Accent Status Pill [STATE: FOCUS LOCK]
                            Rectangle {
                                width: Math.round(86 * scaleFactor)
                                height: Math.round(18 * scaleFactor)
                                color: card01Container.isFocusLocked ? "#FF5F15" : "#1f2937"
                                radius: 2

                                Text {
                                    anchors.centerIn: parent
                                    text: card01Container.isFocusLocked ? "FOCUS LOCK" : "DESKTOP IDLE"
                                    font { family: hudWindow.monoFont; pixelSize: Math.round(9 * scaleFactor); bold: true }
                                    color: card01Container.isFocusLocked ? "#000000" : "#9ca3af"
                                }
                            }
                        }

                        // 2. EXECUTIVE 4-COLUMN TELEMETRY STRIP (Total Uptime, Active Win, Workspace, Session Drift)
                        Rectangle {
                            Layout.fillWidth: true
                            height: Math.round(42 * scaleFactor)
                            color: "#070a0f"
                            border.color: "#1a2433"
                            border.width: 1

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: Math.round(8 * scaleFactor)
                                anchors.rightMargin: Math.round(8 * scaleFactor)
                                spacing: Math.round(6 * scaleFactor)

                                // Session Active Time
                                ColumnLayout {
                                    Layout.preferredWidth: Math.round(76 * scaleFactor)
                                    spacing: 1
                                    Text {
                                        text: "ACTIVE TIME"
                                        color: "#6b7d96"
                                        font { family: hudWindow.monoFont; pixelSize: Math.round(9.5 * scaleFactor); bold: true }
                                    }
                                    Text {
                                        text: card01Container.totalStr
                                        color: "#00e5ff"
                                        font { family: hudWindow.monoFont; pixelSize: Math.round(11 * scaleFactor); bold: true; features: { "tnum": 1 } }
                                    }
                                }

                                Rectangle { width: 1; height: Math.round(26 * scaleFactor); color: "#162030"; Layout.alignment: Qt.AlignVCenter }

                                // Active Window / PID
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 1
                                    Text {
                                        text: "ACTIVE CLASS / WIN"
                                        color: "#6b7d96"
                                        font { family: hudWindow.monoFont; pixelSize: Math.round(9 * scaleFactor); bold: true }
                                    }
                                    Text {
                                        text: {
                                            if (!shellRoot || !shellRoot.activeWindowClass || shellRoot.activeWindowClass === "") return "DESKTOP (IDLE)";
                                            var cls = shellRoot.activeWindowClass;
                                            var tit = shellRoot.activeWindowTitle ? " - " + shellRoot.activeWindowTitle : "";
                                            return cls + tit;
                                        }
                                        color: "#ffffff"
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                        font { family: hudWindow.monoFont; pixelSize: Math.round(10 * scaleFactor); bold: true }
                                    }
                                }

                                Rectangle { width: 1; height: Math.round(26 * scaleFactor); color: "#162030"; Layout.alignment: Qt.AlignVCenter }

                                // Focused Workspace
                                ColumnLayout {
                                    Layout.preferredWidth: Math.round(86 * scaleFactor)
                                    spacing: 1
                                    Text {
                                        text: "FOCUSED WS"
                                        color: "#6b7d96"
                                        font { family: hudWindow.monoFont; pixelSize: Math.round(9 * scaleFactor); bold: true }
                                    }
                                    Text {
                                        text: card01Container.focusedWsStr
                                        color: "#30D158"
                                        font { family: hudWindow.monoFont; pixelSize: Math.round(10 * scaleFactor); bold: true; features: { "tnum": 1 } }
                                    }
                                }

                                Rectangle { width: 1; height: Math.round(26 * scaleFactor); color: "#162030"; Layout.alignment: Qt.AlignVCenter }

                                // Live Uptime Indicator
                                ColumnLayout {
                                    Layout.preferredWidth: Math.round(84 * scaleFactor)
                                    spacing: 1
                                    Text {
                                        text: "SYS UPTIME"
                                        color: "#6b7d96"
                                        font { family: hudWindow.monoFont; pixelSize: Math.round(9 * scaleFactor); bold: true }
                                    }
                                    Text {
                                        text: (hudWindow.hudData && hudWindow.hudData.uptime) ? hudWindow.hudData.uptime : "UP"
                                        color: "#30D158"
                                        font { family: hudWindow.monoFont; pixelSize: Math.round(10 * scaleFactor); bold: true; features: { "tnum": 1 } }
                                    }
                                }
                            }
                        }

                        // 3. APP FOCUS MATRIX SUBHEADER
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Math.round(6 * scaleFactor)
                            Text {
                                text: "APP FOCUS MATRIX"
                                color: "#8b949e"
                                font { family: hudWindow.monoFont; pixelSize: Math.round(9.5 * scaleFactor); bold: true }
                            }
                            Rectangle { Layout.fillWidth: true; height: 1; color: "#162030"; Layout.alignment: Qt.AlignVCenter }
                            Text {
                                text: hudWindow.showWeeklyScreenTime ? ("[7-DAY ROLLING BUFFER: " + card01Container.totalStr + "]") : ("[TODAY ROLLING BUFFER: " + card01Container.totalStr + "]")
                                color: "#00e5ff"
                                font { family: hudWindow.monoFont; pixelSize: Math.round(9 * scaleFactor); bold: true }
                            }
                        }

                        // 4. BLOOMBERG TABULAR MATRIX: 5 Distinct Apps with Segmented TE Histograms
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: Math.round(3.5 * scaleFactor)

                            // Table Column Headers
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Math.round(6 * scaleFactor)

                                Text {
                                    text: "APP / SECTOR"
                                    color: "#506075"
                                    font { family: hudWindow.monoFont; pixelSize: Math.round(9 * scaleFactor); bold: true }
                                    Layout.preferredWidth: Math.round(112 * scaleFactor)
                                }
                                Text {
                                    text: "ALLOC"
                                    color: "#506075"
                                    font { family: hudWindow.monoFont; pixelSize: Math.round(9 * scaleFactor); bold: true }
                                    Layout.preferredWidth: Math.round(44 * scaleFactor)
                                    horizontalAlignment: Text.AlignRight
                                }
                                Text {
                                    text: "SHARE"
                                    color: "#506075"
                                    font { family: hudWindow.monoFont; pixelSize: Math.round(9 * scaleFactor); bold: true }
                                    Layout.preferredWidth: Math.round(36 * scaleFactor)
                                    horizontalAlignment: Text.AlignRight
                                }
                                Text {
                                    text: "DISTRIBUTION TRACK (18 BLOCKS)"
                                    color: "#506075"
                                    font { family: hudWindow.monoFont; pixelSize: Math.round(9 * scaleFactor); bold: true }
                                    Layout.fillWidth: true
                                }
                                Text {
                                    text: "DUTY CYCLE"
                                    color: "#506075"
                                    font { family: hudWindow.monoFont; pixelSize: Math.round(9 * scaleFactor); bold: true }
                                    Layout.preferredWidth: Math.round(52 * scaleFactor)
                                    horizontalAlignment: Text.AlignRight
                                }
                            }

                            // App Rows
                            Repeater {
                                model: card01Container.curApps ? card01Container.curApps.slice(0, 5) : []
                                delegate: Rectangle {
                                    Layout.fillWidth: true
                                    height: Math.round(18 * scaleFactor)
                                    color: isLiveActive ? "#0d1d2e" : (index % 2 === 0 ? "#04070c" : "transparent")
                                    border.color: isLiveActive ? "#1e3852" : "transparent"
                                    border.width: 1
                                    radius: 1

                                    readonly property bool isLiveActive: {
                                        if (!shellRoot || !shellRoot.activeWindowClass || shellRoot.activeWindowClass === "") return false;
                                        var cur = shellRoot.activeWindowClass.toLowerCase();
                                        var name = (modelData.name || "").toLowerCase();
                                        var id = (modelData.id || "").toLowerCase();
                                        return cur.indexOf(name) >= 0 || name.indexOf(cur) >= 0 || (id.length > 0 && (cur.indexOf(id) >= 0 || id.indexOf(cur) >= 0));
                                    }
                                    readonly property string dutyState: {
                                        if (isLiveActive) return "ACTIVE";
                                        var p = modelData.pct || 0;
                                        if (p > 0.35) return "DOMINANT";
                                        if (p > 0.15) return "STALE";
                                        if (p > 0.04) return "IDLE";
                                        return "DAEMON";
                                    }
                                    readonly property color dutyColor: {
                                        if (isLiveActive) return "#30D158";
                                        var p = modelData.pct || 0;
                                        if (p > 0.35) return "#00e5ff";
                                        if (p > 0.15) return "#FF9F0A";
                                        if (p > 0.04) return "#8b949e";
                                        return "#485568";
                                    }

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: Math.round(4 * scaleFactor)
                                        anchors.rightMargin: Math.round(4 * scaleFactor)
                                        spacing: Math.round(6 * scaleFactor)

                                        // App Name
                                        RowLayout {
                                            Layout.preferredWidth: Math.round(112 * scaleFactor)
                                            spacing: Math.round(4 * scaleFactor)
                                            Rectangle {
                                                width: Math.round(5 * scaleFactor)
                                                height: Math.round(5 * scaleFactor)
                                                radius: 1
                                                color: parent.parent.parent.isLiveActive ? "#30D158" : (modelData.pct > 0.2 ? "#00e5ff" : "#FF9F0A")
                                            }
                                            Text {
                                                text: modelData.name || "App"
                                                color: parent.parent.parent.isLiveActive ? "#ffffff" : "#e2e8f0"
                                                font { family: hudWindow.monoFont; pixelSize: Math.round(9.5 * scaleFactor); bold: parent.parent.parent.isLiveActive }
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                            }
                                        }

                                        // Allocation Time
                                        Text {
                                            text: modelData.formatted || "0m"
                                            color: "#00e5ff"
                                            font { family: hudWindow.monoFont; pixelSize: Math.round(9.5 * scaleFactor); bold: true; features: { "tnum": 1 } }
                                            Layout.preferredWidth: Math.round(44 * scaleFactor)
                                            horizontalAlignment: Text.AlignRight
                                        }

                                        // Percentage Share
                                        Text {
                                            text: (modelData.pct ? (modelData.pct * 100).toFixed(1) + "%" : "0.0%")
                                            color: "#94a3b8"
                                            font { family: hudWindow.monoFont; pixelSize: Math.round(9 * scaleFactor); features: { "tnum": 1 } }
                                            Layout.preferredWidth: Math.round(36 * scaleFactor)
                                            horizontalAlignment: Text.AlignRight
                                        }

                                        // Teenage Engineering Segmented Histogram (18 tactile blocks)
                                        Row {
                                            id: segTrack
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: Math.round(6 * scaleFactor)
                                            Layout.alignment: Qt.AlignVCenter
                                            spacing: 2

                                            readonly property int totalBlocks: 18
                                            readonly property int litBlocks: Math.round((modelData.pct || 0) * totalBlocks)
                                            readonly property real blockW: Math.max(2, (width - (totalBlocks - 1) * 2) / totalBlocks)

                                            Repeater {
                                                model: segTrack.totalBlocks
                                                Rectangle {
                                                    width: segTrack.blockW
                                                    height: Math.round(6 * scaleFactor)
                                                    radius: 1
                                                    color: index < segTrack.litBlocks
                                                        ? (parent.parent.parent.parent.isLiveActive ? "#30D158" : "#00e5ff")
                                                        : "#121924"
                                                    border.color: index < segTrack.litBlocks ? "transparent" : "#182333"
                                                    border.width: 1
                                                }
                                            }
                                        }

                                        // Duty Cycle State
                                        Text {
                                            text: parent.parent.dutyState
                                            color: parent.parent.dutyColor
                                            font { family: hudWindow.monoFont; pixelSize: Math.round(9.5 * scaleFactor); bold: true }
                                            Layout.preferredWidth: Math.round(52 * scaleFactor)
                                            horizontalAlignment: Text.AlignRight
                                        }
                                    }
                                }
                            }
                        }


                    }
                }

                // ── PANE 1B: HOST SILICON // THERMAL & BUS TELEMETRY (~320px) ───
                // NOTE [Vertical Space Balance / Planned expansion]:
                // Currently set to 320 * scaleFactor with padding reserved for per-core bar expansion
                // or GPU clock/vram monitoring. If not expanded, tightening to ~275px yields +45px to Card [03].
                Rectangle {
                    id: card02Container
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.round(320 * scaleFactor)
                    color: "#000000"
                    border.color: "#181d26"
                    border.width: 1

                    readonly property real curPkgTemp: {
                        if (hudWindow.hudData && hudWindow.hudData.pkg_temp !== undefined) return hudWindow.hudData.pkg_temp;
                        if (hudWindow.hudData && hudWindow.hudData.cpu_temp !== undefined) return hudWindow.hudData.cpu_temp;
                        return 44.2;
                    }
                    readonly property real curPeakTemp: (hudWindow.hudData && hudWindow.hudData.peak_temp) ? hudWindow.hudData.peak_temp : 87
                    readonly property real curClockGhz: (hudWindow.hudData && hudWindow.hudData.cpu_freq) ? hudWindow.hudData.cpu_freq : 4.62
                    readonly property real curCpuTot: (hudWindow.hudData && hudWindow.hudData.cpu_pct !== undefined) ? hudWindow.hudData.cpu_pct : 0.0
                    readonly property real curMemPct: (hudWindow.hudData && hudWindow.hudData.mem_pct !== undefined) ? hudWindow.hudData.mem_pct : 0.0
                    readonly property real curMemUsedGb: (hudWindow.hudData && hudWindow.hudData.mem_used_gb !== undefined) ? hudWindow.hudData.mem_used_gb : 9.54
                    readonly property real curMemTotalGb: (hudWindow.hudData && hudWindow.hudData.mem_total_gb !== undefined) ? hudWindow.hudData.mem_total_gb : 31.14
                    readonly property real curMemCachedGb: (hudWindow.hudData && hudWindow.hudData.mem_cached_gb !== undefined) ? hudWindow.hudData.mem_cached_gb : 13.73
                    readonly property real curMemCachedPct: (hudWindow.hudData && hudWindow.hudData.mem_cached_pct !== undefined) ? hudWindow.hudData.mem_cached_pct : 44.1
                    readonly property real curDiskPct: (hudWindow.hudData && hudWindow.hudData.disk_pct !== undefined) ? hudWindow.hudData.disk_pct : 33.3
                    readonly property string curDiskUsedStr: (hudWindow.hudData && hudWindow.hudData.disk_str) ? hudWindow.hudData.disk_str : "72G / 217G"
                    readonly property string curDiskReadStr: (hudWindow.hudData && hudWindow.hudData.disk_read_str) ? hudWindow.hudData.disk_read_str : "0.0 KB/s"
                    readonly property string curDiskWriteStr: (hudWindow.hudData && hudWindow.hudData.disk_write_str) ? hudWindow.hudData.disk_write_str : "355.2 KB/s"
                    readonly property int curDiskIops: (hudWindow.hudData && hudWindow.hudData.disk_iops !== undefined) ? hudWindow.hudData.disk_iops : 42

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Math.round(10 * scaleFactor)
                        spacing: Math.round(4.5 * scaleFactor)

                        // 1. TOP HEADER: Card Title + Divider + TE Governor Status Badge
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Math.round(6 * scaleFactor)

                            Text {
                                text: "┌─ [02] SYSTEM HARDWARE"
                                color: "#FF9F0A"
                                font { family: hudWindow.monoFont; pixelSize: Math.round(11 * scaleFactor); bold: true }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                height: 1
                                color: "#212836"
                                Layout.alignment: Qt.AlignVCenter
                            }

                            // Interactive Pacman / System Status Pill
                            Rectangle {
                                id: pacmanBtn
                                width: Math.round(82 * scaleFactor)
                                height: Math.round(18 * scaleFactor)
                                readonly property int upCount: {
                                    if (hudWindow.hudData && hudWindow.hudData.pacman_updates) return hudWindow.hudData.pacman_updates;
                                    if (shellRoot && shellRoot.updates) return parseInt(shellRoot.updates) || 0;
                                    return 0;
                                }
                                color: upCount > 0 ? "#241407" : "#0d1b2a"
                                border.color: upCount > 0 ? "#FF9F0A" : "#212836"
                                border.width: 1
                                radius: 2

                                Text {
                                    anchors.centerIn: parent
                                    text: parent.upCount > 0 ? (parent.upCount + " UPDATES") : "PKG SYNC"
                                    color: parent.upCount > 0 ? "#FF9F0A" : "#8b949e"
                                    font { family: hudWindow.monoFont; pixelSize: Math.round(9 * scaleFactor); bold: true; features: { "tnum": 1 } }
                                }
                            }

                            // TE Accent Status Pill [GOV: PERFORMANCE]
                            Rectangle {
                                width: Math.round(106 * scaleFactor)
                                height: Math.round(18 * scaleFactor)
                                color: card02Container.curPkgTemp > 75 ? "#FF3344" : (card02Container.curPkgTemp > 65 ? "#FF9F0A" : "#101d2d")
                                border.color: card02Container.curPkgTemp > 65 ? "transparent" : "#00e5ff"
                                border.width: 1
                                radius: 2

                                Text {
                                    anchors.centerIn: parent
                                    text: "GOV: PERFORMANCE"
                                    font { family: hudWindow.monoFont; pixelSize: Math.round(9.5 * scaleFactor); bold: true }
                                    color: card02Container.curPkgTemp > 65 ? "#000000" : "#00e5ff"
                                }
                            }
                        }

                        // 2. THERMAL ENVELOPE & FREQUENCY METRIC BANNER (5 Structured Columns)
                        Rectangle {
                            Layout.fillWidth: true
                            height: Math.round(42 * scaleFactor)
                            color: "#070a0f"
                            border.color: "#1a2433"
                            border.width: 1

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: Math.round(8 * scaleFactor)
                                anchors.rightMargin: Math.round(8 * scaleFactor)
                                spacing: Math.round(6 * scaleFactor)

                                // Package Temp (Real coretemp-isa package reading)
                                ColumnLayout {
                                    Layout.preferredWidth: Math.round(98 * scaleFactor)
                                    spacing: 1
                                    Text {
                                        text: "PACKAGE TEMP"
                                        color: "#6b7d96"
                                        font { family: hudWindow.monoFont; pixelSize: Math.round(9 * scaleFactor); bold: true }
                                    }
                                    Text {
                                        text: card02Container.curPkgTemp.toFixed(1) + "°C [Tj: 100°]"
                                        color: card02Container.curPkgTemp > 75 ? "#FF3344" : (card02Container.curPkgTemp > 60 ? "#FF9F0A" : "#30D158")
                                        font { family: hudWindow.monoFont; pixelSize: Math.round(10 * scaleFactor); bold: true; features: { "tnum": 1 } }
                                    }
                                }

                                Rectangle { width: 1; height: Math.round(26 * scaleFactor); color: "#162030"; Layout.alignment: Qt.AlignVCenter }

                                // NVMe Hardware Temp (Real PCI NVMe Composite Temp)
                                ColumnLayout {
                                    Layout.preferredWidth: Math.round(90 * scaleFactor)
                                    spacing: 1
                                    Text {
                                        text: "NVMe TEMP"
                                        color: "#6b7d96"
                                        font { family: hudWindow.monoFont; pixelSize: Math.round(9 * scaleFactor); bold: true }
                                    }
                                    Text {
                                        text: ((hudWindow.hudData && hudWindow.hudData.nvme_temp) ? hudWindow.hudData.nvme_temp : "43.9") + "°C [OK]"
                                        color: "#00e5ff"
                                        font { family: hudWindow.monoFont; pixelSize: Math.round(10 * scaleFactor); bold: true; features: { "tnum": 1 } }
                                    }
                                }

                                Rectangle { width: 1; height: Math.round(26 * scaleFactor); color: "#162030"; Layout.alignment: Qt.AlignVCenter }

                                // Core Clock
                                ColumnLayout {
                                    Layout.preferredWidth: Math.round(78 * scaleFactor)
                                    spacing: 1
                                    Text {
                                        text: "CORE CLOCK"
                                        color: "#6b7d96"
                                        font { family: hudWindow.monoFont; pixelSize: Math.round(9 * scaleFactor); bold: true }
                                    }
                                    Text {
                                        text: card02Container.curClockGhz.toFixed(2) + " GHz"
                                        color: "#ffffff"
                                        font { family: hudWindow.monoFont; pixelSize: Math.round(10 * scaleFactor); bold: true; features: { "tnum": 1 } }
                                    }
                                }

                                Rectangle { width: 1; height: Math.round(26 * scaleFactor); color: "#162030"; Layout.alignment: Qt.AlignVCenter }

                                // Pkg Power / Thermal State
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 1
                                    Text {
                                        text: "THERMAL ENVELOPE"
                                        color: "#6b7d96"
                                        font { family: hudWindow.monoFont; pixelSize: Math.round(9 * scaleFactor); bold: true }
                                    }
                                    Text {
                                        readonly property real headroom: Math.max(0, 100.0 - card02Container.curPkgTemp)
                                        text: "+" + headroom.toFixed(0) + "°C HEADROOM"
                                        color: headroom < 25 ? "#FF3344" : (headroom < 40 ? "#FF9F0A" : "#30D158")
                                        font { family: hudWindow.monoFont; pixelSize: Math.round(10 * scaleFactor); bold: true; features: { "tnum": 1 } }
                                    }
                                }
                            }
                        }

                        // 3. SUBSYSTEM LOADS: Expanded 32-Segment Discrete LED Tracks (Relaxed Layout)
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            spacing: Math.round(6 * scaleFactor)

                            // Column Headers
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Math.round(8 * scaleFactor)

                                Text {
                                    text: "SUBSYSTEM"
                                    color: "#506075"
                                    font { family: hudWindow.monoFont; pixelSize: Math.round(9.5 * scaleFactor); bold: true }
                                    Layout.preferredWidth: Math.round(82 * scaleFactor)
                                }
                                Text {
                                    text: "LOAD"
                                    color: "#506075"
                                    font { family: hudWindow.monoFont; pixelSize: Math.round(9.5 * scaleFactor); bold: true }
                                    Layout.preferredWidth: Math.round(44 * scaleFactor)
                                    horizontalAlignment: Text.AlignRight
                                }
                                Text {
                                    text: "BAR METRIC"
                                    color: "#506075"
                                    font { family: hudWindow.monoFont; pixelSize: Math.round(9.5 * scaleFactor); bold: true }
                                    Layout.fillWidth: true
                                }
                                Text {
                                    text: "ALLOCATED / CAPACITY"
                                    color: "#506075"
                                    font { family: hudWindow.monoFont; pixelSize: Math.round(9.5 * scaleFactor); bold: true }
                                    Layout.preferredWidth: Math.round(124 * scaleFactor)
                                    horizontalAlignment: Text.AlignRight
                                }
                                Text {
                                    text: "STATUS"
                                    color: "#506075"
                                    font { family: hudWindow.monoFont; pixelSize: Math.round(9.5 * scaleFactor); bold: true }
                                    Layout.preferredWidth: Math.round(38 * scaleFactor)
                                    horizontalAlignment: Text.AlignRight
                                }
                            }

                            // Subsystem Rows Repeater (4 Stretched, Clean Hardware Tracks)
                            Repeater {
                                model: [
                                    {
                                        name: "CPU TOTAL",
                                        pct: card02Container.curCpuTot,
                                        detail: "8C / 16T @ " + card02Container.curClockGhz.toFixed(2) + " GHz",
                                        status: card02Container.curCpuTot > 85 ? "HOT" : (card02Container.curCpuTot > 50 ? "HIGH" : "NOM"),
                                        color: card02Container.curCpuTot > 85 ? "#FF5F15" : "#30D158"
                                    },
                                    {
                                        name: "MEM PHYS",
                                        pct: card02Container.curMemPct,
                                        detail: card02Container.curMemUsedGb.toFixed(1) + "G / " + card02Container.curMemTotalGb.toFixed(1) + "G",
                                        status: card02Container.curMemPct > 85 ? "WARN" : "NOM",
                                        color: "#00E5FF"
                                    },
                                    {
                                        name: "MEM CACHED",
                                        pct: card02Container.curMemCachedPct,
                                        detail: card02Container.curMemCachedGb.toFixed(1) + "G [SLAB/BUFF]",
                                        status: "NOM",
                                        color: "#BF5AF2"
                                    },
                                    {
                                        name: "NVMe ROOT",
                                        pct: card02Container.curDiskPct,
                                        detail: card02Container.curDiskUsedStr,
                                        status: card02Container.curDiskPct > 85 ? "WARN" : "NOM",
                                        color: "#FF9F0A"
                                    }
                                ]
                                delegate: Rectangle {
                                    Layout.fillWidth: true
                                    height: Math.round(24 * scaleFactor)
                                    color: index % 2 === 0 ? "#06090e" : "transparent"
                                    border.color: "#141b26"
                                    border.width: 1
                                    radius: 2

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: Math.round(6 * scaleFactor)
                                        anchors.rightMargin: Math.round(6 * scaleFactor)
                                        spacing: Math.round(8 * scaleFactor)

                                        // Subsystem Name
                                        Text {
                                            text: modelData.name
                                            color: "#ffffff"
                                            font { family: hudWindow.monoFont; pixelSize: Math.round(10 * scaleFactor); bold: true }
                                            Layout.preferredWidth: Math.round(82 * scaleFactor)
                                        }

                                        // Load Percentage
                                        Text {
                                            text: modelData.pct.toFixed(1) + "%"
                                            color: modelData.color
                                            font { family: hudWindow.monoFont; pixelSize: Math.round(10 * scaleFactor); bold: true; features: { "tnum": 1 } }
                                            Layout.preferredWidth: Math.round(44 * scaleFactor)
                                            horizontalAlignment: Text.AlignRight
                                        }

                                        // 32-Segment Precision Discrete Track
                                        Row {
                                            id: meterSegBar32
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: Math.round(7 * scaleFactor)
                                            Layout.alignment: Qt.AlignVCenter
                                            spacing: 2

                                            readonly property int totalSegments: 32
                                            readonly property int activeSegments: Math.round((modelData.pct / 100.0) * totalSegments)
                                            readonly property real segW: Math.max(2, (width - (totalSegments - 1) * 2) / totalSegments)

                                            Repeater {
                                                model: meterSegBar32.totalSegments
                                                Rectangle {
                                                    width: meterSegBar32.segW
                                                    height: Math.round(7 * scaleFactor)
                                                    radius: 0.5
                                                    color: index < meterSegBar32.activeSegments ? modelData.color : "#101722"
                                                    border.color: index < meterSegBar32.activeSegments ? "transparent" : "#16202e"
                                                    border.width: 1
                                                }
                                            }
                                        }

                                        // Detail Capacity / Usage
                                        Text {
                                            text: modelData.detail
                                            color: "#8b949e"
                                            font { family: hudWindow.monoFont; pixelSize: Math.round(9.5 * scaleFactor); features: { "tnum": 1 } }
                                            Layout.preferredWidth: Math.round(124 * scaleFactor)
                                            horizontalAlignment: Text.AlignRight
                                        }

                                        // Status Pill
                                        Text {
                                            text: modelData.status
                                            color: modelData.status === "HOT" ? "#FF3344" : (modelData.status === "WARN" ? "#FF9F0A" : "#30D158")
                                            font { family: hudWindow.monoFont; pixelSize: Math.round(9.5 * scaleFactor); bold: true }
                                            Layout.preferredWidth: Math.round(38 * scaleFactor)
                                            horizontalAlignment: Text.AlignRight
                                        }
                                    }
                                }
                            }
                        }

                        // 5. STORAGE & BUS I/O THROUGHPUT (NVMe Read/Write & Live IOPS)
                        Rectangle {
                            Layout.fillWidth: true
                            height: Math.round(28 * scaleFactor)
                            color: "#070a0f"
                            border.color: "#162030"
                            border.width: 1

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: Math.round(8 * scaleFactor)
                                anchors.rightMargin: Math.round(8 * scaleFactor)
                                spacing: Math.round(8 * scaleFactor)

                                Text {
                                    text: "NVMe BUS I/O:"
                                    color: "#6b7d96"
                                    font { family: hudWindow.monoFont; pixelSize: Math.round(9 * scaleFactor); bold: true }
                                }

                                Text {
                                    text: "R: " + card02Container.curDiskReadStr
                                    color: "#30D158"
                                    font { family: hudWindow.monoFont; pixelSize: Math.round(9 * scaleFactor); bold: true; features: { "tnum": 1 } }
                                }

                                Rectangle { width: 1; height: Math.round(14 * scaleFactor); color: "#212836"; Layout.alignment: Qt.AlignVCenter }

                                Text {
                                    text: "W: " + card02Container.curDiskWriteStr
                                    color: "#00e5ff"
                                    font { family: hudWindow.monoFont; pixelSize: Math.round(9 * scaleFactor); bold: true; features: { "tnum": 1 } }
                                    Layout.preferredWidth: Math.round(105 * scaleFactor)
                                }

                                Item { Layout.fillWidth: true }

                                Rectangle { width: 1; height: Math.round(14 * scaleFactor); color: "#212836"; Layout.alignment: Qt.AlignVCenter }

                                Text {
                                    text: "IOPS: " + card02Container.curDiskIops + " [ACTIVE]"
                                    color: card02Container.curDiskIops > 200 ? "#FF9F0A" : "#BF5AF2"
                                    font { family: hudWindow.monoFont; pixelSize: Math.round(9 * scaleFactor); bold: true; features: { "tnum": 1 } }
                                }
                            }
                        }
                    }
                }
                // ── PANE 1C: PROCESS DISPATCH // RUNTIME INSPECTOR (Full Height) ──
                Rectangle {
                    id: card03Container
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: "#000000"
                    border.color: "#181d26"
                    border.width: 1

                    readonly property var procSum: (hudWindow.hudData && hudWindow.hudData.proc_summary) ? hudWindow.hudData.proc_summary : ({})
                    readonly property int activeThreads: procSum.active_threads || 1600
                    readonly property string ctxtSwRate: procSum.context_sw_s || "14.2k"
                    readonly property int procsRun: procSum.procs_running || 2
                    readonly property int procsSlp: procSum.procs_sleeping || 450
                    readonly property string topBottleneck: procSum.top_bottleneck || "quickshell"
                    readonly property string faultRate: procSum.fault_rate || "0.2k/s"

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Math.round(10 * scaleFactor)
                        spacing: Math.round(5 * scaleFactor)

                        // 1. TOP HEADER: Monospace Title + Divider + TE Status Badges
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Math.round(6 * scaleFactor)

                            Text {
                                text: "┌─ [03] PROCESS INSPECTOR"
                                color: "#30D158"
                                font { family: hudWindow.monoFont; pixelSize: Math.round(11 * scaleFactor); bold: true }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                height: 1
                                color: "#212836"
                                Layout.alignment: Qt.AlignVCenter
                            }

                            // TE Filter Pill [FILTER: LIVE]
                            Rectangle {
                                width: Math.round(84 * scaleFactor)
                                height: Math.round(18 * scaleFactor)
                                color: "#0b1622"
                                border.color: "#1b324a"
                                border.width: 1
                                radius: 2

                                Text {
                                    anchors.centerIn: parent
                                    text: "FILTER: LIVE"
                                    font { family: hudWindow.monoFont; pixelSize: Math.round(9.5 * scaleFactor); bold: true }
                                    color: "#64D2FF"
                                }
                            }

                            // TE Mode Pill [TOP: CPU]
                            Rectangle {
                                width: Math.round(72 * scaleFactor)
                                height: Math.round(18 * scaleFactor)
                                color: "#161f2c"
                                border.color: "#00e5ff"
                                border.width: 1
                                radius: 2

                                Text {
                                    anchors.centerIn: parent
                                    text: "TOP: CPU"
                                    font { family: hudWindow.monoFont; pixelSize: Math.round(9.5 * scaleFactor); bold: true }
                                    color: "#00e5ff"
                                }
                            }
                        }

                        // 2. DISPATCH METRIC SUMMARY STRIP (5 High-Density Columns)
                        Rectangle {
                            Layout.fillWidth: true
                            height: Math.round(40 * scaleFactor)
                            color: "#070a0f"
                            border.color: "#1a2433"
                            border.width: 1

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: Math.round(8 * scaleFactor)
                                anchors.rightMargin: Math.round(8 * scaleFactor)
                                spacing: Math.round(6 * scaleFactor)

                                // Active Threads
                                ColumnLayout {
                                    Layout.preferredWidth: Math.round(88 * scaleFactor)
                                    spacing: 1
                                    Text {
                                        text: "ACTIVE THREADS"
                                        color: "#6b7d96"
                                        font { family: hudWindow.monoFont; pixelSize: Math.round(9 * scaleFactor); bold: true }
                                    }
                                    Text {
                                        text: card03Container.activeThreads.toLocaleString(Qt.locale(), "f", 0)
                                        color: "#00e5ff"
                                        font { family: hudWindow.monoFont; pixelSize: Math.round(10 * scaleFactor); bold: true; features: { "tnum": 1 } }
                                    }
                                }

                                Rectangle { width: 1; height: Math.round(24 * scaleFactor); color: "#162030"; Layout.alignment: Qt.AlignVCenter }

                                // Context Switches
                                ColumnLayout {
                                    Layout.preferredWidth: Math.round(82 * scaleFactor)
                                    spacing: 1
                                    Text {
                                        text: "CONTEXT SW/s"
                                        color: "#6b7d96"
                                        font { family: hudWindow.monoFont; pixelSize: Math.round(9 * scaleFactor); bold: true }
                                    }
                                    Text {
                                        text: card03Container.ctxtSwRate
                                        color: "#ffffff"
                                        font { family: hudWindow.monoFont; pixelSize: Math.round(10 * scaleFactor); bold: true; features: { "tnum": 1 } }
                                    }
                                }

                                Rectangle { width: 1; height: Math.round(24 * scaleFactor); color: "#162030"; Layout.alignment: Qt.AlignVCenter }

                                // Tasks Running / Sleeping
                                ColumnLayout {
                                    Layout.preferredWidth: Math.round(82 * scaleFactor)
                                    spacing: 1
                                    Text {
                                        text: "TASKS RUN/SLP"
                                        color: "#6b7d96"
                                        font { family: hudWindow.monoFont; pixelSize: Math.round(9 * scaleFactor); bold: true }
                                    }
                                    Text {
                                        text: card03Container.procsRun + " / " + card03Container.procsSlp
                                        color: "#30D158"
                                        font { family: hudWindow.monoFont; pixelSize: Math.round(10 * scaleFactor); bold: true; features: { "tnum": 1 } }
                                    }
                                }

                                Rectangle { width: 1; height: Math.round(24 * scaleFactor); color: "#162030"; Layout.alignment: Qt.AlignVCenter }

                                // Top Bottleneck
                                ColumnLayout {
                                    Layout.preferredWidth: Math.round(88 * scaleFactor)
                                    spacing: 1
                                    Text {
                                        text: "TOP BOTTLENECK"
                                        color: "#6b7d96"
                                        font { family: hudWindow.monoFont; pixelSize: Math.round(9 * scaleFactor); bold: true }
                                    }
                                    Text {
                                        text: card03Container.topBottleneck
                                        color: "#FF9F0A"
                                        font { family: hudWindow.monoFont; pixelSize: Math.round(10 * scaleFactor); bold: true }
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                }

                                Rectangle { width: 1; height: Math.round(24 * scaleFactor); color: "#162030"; Layout.alignment: Qt.AlignVCenter }

                                // Fault Rate
                                ColumnLayout {
                                    Layout.preferredWidth: Math.round(84 * scaleFactor)
                                    spacing: 1
                                    Text {
                                        text: "FAULT RATE"
                                        color: "#6b7d96"
                                        font { family: hudWindow.monoFont; pixelSize: Math.round(9 * scaleFactor); bold: true }
                                    }
                                    Text {
                                        text: card03Container.faultRate + " [NOM]"
                                        color: "#BF5AF2"
                                        font { family: hudWindow.monoFont; pixelSize: Math.round(10 * scaleFactor); bold: true; features: { "tnum": 1 } }
                                    }
                                }
                            }
                        }

                        // 3. TABLE COLUMN HEADERS
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Math.round(6 * scaleFactor)

                            Text {
                                text: "PID"
                                color: "#506075"
                                font { family: hudWindow.monoFont; pixelSize: Math.round(9 * scaleFactor); bold: true }
                                Layout.preferredWidth: Math.round(48 * scaleFactor)
                            }
                            Text {
                                text: "PROCESS / SUBSYSTEM"
                                color: "#506075"
                                font { family: hudWindow.monoFont; pixelSize: Math.round(9 * scaleFactor); bold: true }
                                Layout.preferredWidth: Math.round(132 * scaleFactor)
                            }
                            Text {
                                text: "THR"
                                color: "#506075"
                                font { family: hudWindow.monoFont; pixelSize: Math.round(9 * scaleFactor); bold: true }
                                Layout.preferredWidth: Math.round(26 * scaleFactor)
                                horizontalAlignment: Text.AlignRight
                            }
                            Text {
                                text: "CPU%"
                                color: "#506075"
                                font { family: hudWindow.monoFont; pixelSize: Math.round(9 * scaleFactor); bold: true }
                                Layout.preferredWidth: Math.round(38 * scaleFactor)
                                horizontalAlignment: Text.AlignRight
                            }
                            Text {
                                text: "MICRO-LOAD [10 SEG]"
                                color: "#506075"
                                font { family: hudWindow.monoFont; pixelSize: Math.round(9 * scaleFactor); bold: true }
                                Layout.fillWidth: true
                            }
                            Text {
                                text: "MEM%"
                                color: "#506075"
                                font { family: hudWindow.monoFont; pixelSize: Math.round(9 * scaleFactor); bold: true }
                                Layout.preferredWidth: Math.round(34 * scaleFactor)
                                horizontalAlignment: Text.AlignRight
                            }
                            Text {
                                text: "RAM RSS"
                                color: "#506075"
                                font { family: hudWindow.monoFont; pixelSize: Math.round(9 * scaleFactor); bold: true }
                                Layout.preferredWidth: Math.round(48 * scaleFactor)
                                horizontalAlignment: Text.AlignRight
                            }
                            Text {
                                text: "STAT"
                                color: "#506075"
                                font { family: hudWindow.monoFont; pixelSize: Math.round(9 * scaleFactor); bold: true }
                                Layout.preferredWidth: Math.round(30 * scaleFactor)
                                horizontalAlignment: Text.AlignCenter
                            }
                        }

                        // Divider
                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: "#1a2433"
                        }

                        // 4. PROCESS ROWS (Bloomberg Tabular Precision + TE Micro-Load Bars)
                        Repeater {
                            model: (hudWindow.hudData && hudWindow.hudData.processes) ? hudWindow.hudData.processes : []
                            delegate: Rectangle {
                                Layout.fillWidth: true
                                height: Math.round(17 * scaleFactor)
                                color: index % 2 === 0 ? "#04070c" : "transparent"
                                radius: 1

                                readonly property real cpuVal: parseFloat(modelData.cpu || 0)
                                readonly property string statVal: modelData.state || "SLP"

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: Math.round(2 * scaleFactor)
                                    anchors.rightMargin: Math.round(2 * scaleFactor)
                                    spacing: Math.round(6 * scaleFactor)

                                    // PID
                                    Text {
                                        text: modelData.pid || "--"
                                        color: "#475569"
                                        font { family: hudWindow.monoFont; pixelSize: Math.round(9 * scaleFactor); features: { "tnum": 1 } }
                                        Layout.preferredWidth: Math.round(48 * scaleFactor)
                                    }

                                    // Process / Subsystem Name
                                    Text {
                                        text: modelData.name || "unknown"
                                        color: "#f1f5f9"
                                        font { family: hudWindow.monoFont; pixelSize: Math.round(9.5 * scaleFactor); bold: cpuVal > 15 }
                                        Layout.preferredWidth: Math.round(132 * scaleFactor)
                                        elide: Text.ElideRight
                                    }

                                    // Thread Count (THR)
                                    Text {
                                        text: modelData.threads || 1
                                        color: "#94a3b8"
                                        font { family: hudWindow.monoFont; pixelSize: Math.round(9 * scaleFactor); features: { "tnum": 1 } }
                                        Layout.preferredWidth: Math.round(26 * scaleFactor)
                                        horizontalAlignment: Text.AlignRight
                                    }

                                    // CPU %
                                    Text {
                                        text: cpuVal.toFixed(1) + "%"
                                        color: cpuVal > 25 ? "#FF5F15" : (cpuVal > 12 ? "#FF9F0A" : "#00e5ff")
                                        font { family: hudWindow.monoFont; pixelSize: Math.round(9.5 * scaleFactor); bold: true; features: { "tnum": 1 } }
                                        Layout.preferredWidth: Math.round(38 * scaleFactor)
                                        horizontalAlignment: Text.AlignRight
                                    }

                                    // Teenage Engineering 10-Segment Micro-Load Bar (Single Instanced Item with Overlaid Grid Slots)
                                    Item {
                                        id: procMicroBar
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: Math.round(5 * scaleFactor)
                                        Layout.alignment: Qt.AlignVCenter

                                        readonly property int activeSegs: Math.max(0, Math.min(10, Math.round((cpuVal / 30.0) * 10)))
                                        readonly property color barColor: cpuVal > 25 ? "#FF5F15" : (cpuVal > 12 ? "#FF9F0A" : "#00e5ff")

                                        // Background Track
                                        Rectangle {
                                            anchors.fill: parent
                                            color: "#0a0e14"
                                            border.color: "#182333"
                                            border.width: 0.5
                                        }

                                        // Active Discrete Fill (Quantized in 10% steps)
                                        Rectangle {
                                            anchors.left: parent.left
                                            anchors.top: parent.top
                                            anchors.bottom: parent.bottom
                                            width: parent.width * (procMicroBar.activeSegs / 10.0)
                                            color: procMicroBar.barColor
                                        }

                                        // Slot Overlay (Dividers dividing into 10 discrete TE instrument cells)
                                        Row {
                                            anchors.fill: parent
                                            Repeater {
                                                model: 9
                                                Item {
                                                    width: procMicroBar.width / 10.0
                                                    height: parent.height
                                                    Rectangle {
                                                        anchors.right: parent.right
                                                        width: 1.5
                                                        height: parent.height
                                                        color: "#000000" // OLED pitch black slot dividing each cell
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    // Memory %
                                    Text {
                                        text: (modelData.mem ? parseFloat(modelData.mem).toFixed(1) + "%" : "0.0%")
                                        color: "#94a3b8"
                                        font { family: hudWindow.monoFont; pixelSize: Math.round(9 * scaleFactor); features: { "tnum": 1 } }
                                        Layout.preferredWidth: Math.round(34 * scaleFactor)
                                        horizontalAlignment: Text.AlignRight
                                    }

                                    // RAM RSS
                                    Text {
                                        text: modelData.rss || "--"
                                        color: "#cbd5e1"
                                        font { family: hudWindow.monoFont; pixelSize: Math.round(9 * scaleFactor); features: { "tnum": 1 } }
                                        Layout.preferredWidth: Math.round(48 * scaleFactor)
                                        horizontalAlignment: Text.AlignRight
                                    }

                                    // Status Pill Badge
                                    Rectangle {
                                        Layout.preferredWidth: Math.round(30 * scaleFactor)
                                        Layout.preferredHeight: Math.round(14 * scaleFactor)
                                        color: statVal === "RUN" ? "#082f49" : (statVal === "DSK" ? "#3b1219" : "#101622")
                                        border.color: statVal === "RUN" ? "#00e5ff" : (statVal === "DSK" ? "#EF4444" : "#233044")
                                        border.width: 1
                                        radius: 2

                                        Text {
                                            anchors.centerIn: parent
                                            text: statVal
                                            font { family: hudWindow.monoFont; pixelSize: Math.round(9 * scaleFactor); bold: true }
                                            color: statVal === "RUN" ? "#00e5ff" : (statVal === "DSK" ? "#EF4444" : "#64748b")
                                        }
                                    }
                                }
                            }
                        }

                        Item { Layout.fillHeight: true }

                        // 5. AGGREGATED RUNTIME SUBSYSTEM BREAKDOWN FOOTER
                        Rectangle {
                            Layout.fillWidth: true
                            height: Math.round(26 * scaleFactor)
                            color: "#070a0f"
                            border.color: "#1a2433"
                            border.width: 1

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: Math.round(8 * scaleFactor)
                                anchors.rightMargin: Math.round(8 * scaleFactor)
                                spacing: Math.round(8 * scaleFactor)

                                Text {
                                    text: "SUBSYSTEM POOL:"
                                    color: "#6b7d96"
                                    font { family: hudWindow.monoFont; pixelSize: Math.round(9 * scaleFactor); bold: true }
                                }

                                Text {
                                    text: "COMPUTE/DEV 52%"
                                    color: "#30D158"
                                    font { family: hudWindow.monoFont; pixelSize: Math.round(9.5 * scaleFactor); bold: true }
                                }

                                Rectangle { width: 1; height: Math.round(14 * scaleFactor); color: "#212836"; Layout.alignment: Qt.AlignVCenter }

                                Text {
                                    text: "DESKTOP/GUI 24%"
                                    color: "#00e5ff"
                                    font { family: hudWindow.monoFont; pixelSize: Math.round(9.5 * scaleFactor); bold: true }
                                }

                                Rectangle { width: 1; height: Math.round(14 * scaleFactor); color: "#212836"; Layout.alignment: Qt.AlignVCenter }

                                Text {
                                    text: "SYSTEM MESH 12%"
                                    color: "#BF5AF2"
                                    font { family: hudWindow.monoFont; pixelSize: Math.round(9.5 * scaleFactor); bold: true }
                                }

                                Item { Layout.fillWidth: true }

                                Text {
                                    text: "[LATENCY: 0.1ms]"
                                    color: "#FF9F0A"
                                    font { family: hudWindow.monoFont; pixelSize: Math.round(8 * scaleFactor); bold: true; features: { "tnum": 1 } }
                                }
                            }
                        }
                    }
                }
            }

            // ═════════════════════════════════════════════════════════════════
            // COLUMN 2: GROUNDCONTROL DECK & MASTER CHRONO (44% Width)
            // ═════════════════════════════════════════════════════════════════
            ColumnLayout {
                Layout.preferredWidth: Math.round(parent.width * 0.44)
                Layout.fillHeight: true
                spacing: 0

                // ── PANE 2A: MASTER CHRONO // SOLAR EPHEMERIS & ORBITAL PASS (~165px) ────
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.round(165 * scaleFactor)
                    color: "#000000"
                    border.color: "#181d26"
                    border.width: 1

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Math.round(8 * scaleFactor)
                        spacing: Math.round(4 * scaleFactor)

                        // ── SECTION 0: PANE TITLE & GROUND TRACK ORIGIN HEADER ───────────────
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Math.round(6 * scaleFactor)
                            Text {
                                text: "┌─ [04] MASTER CLOCK & SOLAR"
                                color: "#30D158"
                                font { family: hudWindow.monoFont; pixelSize: Math.round(10.5 * scaleFactor); bold: true }
                            }
                            Rectangle {
                                Layout.fillWidth: true
                                height: 1
                                color: "#212836"
                                Layout.alignment: Qt.AlignVCenter
                            }
                            Text {
                                text: "UPTIME: " + ((hudWindow.hudData && hudWindow.hudData.uptime_full) ? hudWindow.hudData.uptime_full : "1W 23H")
                                color: "#30D158"
                                font { family: hudWindow.monoFont; pixelSize: Math.round(9.5 * scaleFactor); bold: true; features: { "tnum": 1 } }
                            }
                            Rectangle {
                                width: 1
                                height: Math.round(12 * scaleFactor)
                                color: "#212836"
                                Layout.alignment: Qt.AlignVCenter
                            }
                            Text {
                                text: "IIT KANPUR 26.51°N 80.23°E"
                                color: Qt.rgba(1, 1, 1, 0.45)
                                font { family: hudWindow.monoFont; pixelSize: Math.round(9 * scaleFactor); features: { "tnum": 1 } }
                            }
                        }

                        // ── SECTION 1: BALANCED 4-COLUMN CHRONO & EPHEMERIS BANNER ──────
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Math.round(10 * scaleFactor)

                            // COL 1: PRIMARY DIGITAL CHRONO (CENTERED & BALANCED)
                            RowLayout {
                                Layout.preferredWidth: Math.round(parent.width * 0.30)
                                spacing: 0
                                Layout.alignment: Qt.AlignVCenter

                                Item {
                                    width: timeText.implicitWidth
                                    height: Math.round(30 * scaleFactor)

                                    Text {
                                        anchors.fill: parent
                                        text: "88:88:88"
                                        color: "#121720"
                                        font { family: hudWindow.monoFont; pixelSize: Math.round(24 * scaleFactor); bold: true; letterSpacing: 1.5; features: { "tnum": 1 } }
                                        verticalAlignment: Text.AlignVCenter
                                    }

                                    Text {
                                        id: timeText
                                        anchors.fill: parent
                                        text: hudWindow.clockHours + ":" + hudWindow.clockMinutes + ":" + hudWindow.clockSeconds
                                        color: "#ffffff"
                                        font { family: hudWindow.monoFont; pixelSize: Math.round(24 * scaleFactor); bold: true; letterSpacing: 1.5; features: { "tnum": 1 } }
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                }

                                Text {
                                    text: " IST"
                                    color: "#30D158"
                                    font { family: hudWindow.monoFont; pixelSize: Math.round(10 * scaleFactor); bold: true }
                                    Layout.alignment: Qt.AlignBottom
                                    Layout.bottomMargin: Math.round(4 * scaleFactor)
                                    Layout.leftMargin: Math.round(4 * scaleFactor)
                                }
                            }

                            Rectangle { width: 1; height: Math.round(28 * scaleFactor); color: "#181d26"; Layout.alignment: Qt.AlignVCenter }

                            // COL 2: CALENDAR DATE & YEAR PROGRESS
                            ColumnLayout {
                                Layout.preferredWidth: Math.round(parent.width * 0.24)
                                spacing: 1
                                Layout.alignment: Qt.AlignVCenter
                                Text {
                                    text: hudWindow.clockDateStr
                                    color: "#30D158"
                                    font { family: hudWindow.monoFont; pixelSize: Math.round(10.5 * scaleFactor); bold: true }
                                }
                                Text {
                                    text: "DOY: " + (hudWindow.hudData.doy || 314) + " │ WEEK: " + (hudWindow.hudData.week || 46)
                                    color: Qt.rgba(1, 1, 1, 0.5)
                                    font { family: hudWindow.monoFont; pixelSize: Math.round(9 * scaleFactor); features: { "tnum": 1 } }
                                }
                                Text {
                                    text: "YEAR CYC: " + ((Number(hudWindow.hudData.doy || 314) / 365.25) * 100).toFixed(1) + "%"
                                    color: "#FF9F0A"
                                    font { family: hudWindow.monoFont; pixelSize: Math.round(8.5 * scaleFactor); bold: true; features: { "tnum": 1 } }
                                }
                            }

                            Rectangle { width: 1; height: Math.round(28 * scaleFactor); color: "#181d26"; Layout.alignment: Qt.AlignVCenter }

                            // COL 3: LOCAL SIDEREAL TIME (LMST)
                            ColumnLayout {
                                Layout.preferredWidth: Math.round(parent.width * 0.22)
                                spacing: 1
                                Layout.alignment: Qt.AlignVCenter
                                Text {
                                    text: "LOCAL SIDEREAL"
                                    color: Qt.rgba(1, 1, 1, 0.45)
                                    font { family: hudWindow.monoFont; pixelSize: Math.round(9.5 * scaleFactor); bold: true }
                                }
                                Text {
                                    text: hudWindow.hudData.lmst_str || "22:42:16"
                                    color: "#64D2FF"
                                    font { family: hudWindow.monoFont; pixelSize: Math.round(11 * scaleFactor); bold: true; features: { "tnum": 1 } }
                                }
                                Text {
                                    text: "GMST +05:20:56"
                                    color: Qt.rgba(1, 1, 1, 0.35)
                                    font { family: hudWindow.monoFont; pixelSize: Math.round(8.5 * scaleFactor); features: { "tnum": 1 } }
                                }
                            }

                            Rectangle { width: 1; height: Math.round(28 * scaleFactor); color: "#181d26"; Layout.alignment: Qt.AlignVCenter }

                            // COL 4: UTC SYNCHRONIZATION
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1
                                Layout.alignment: Qt.AlignVCenter
                                Text {
                                    text: "UTC ZULU"
                                    color: Qt.rgba(1, 1, 1, 0.45)
                                    font { family: hudWindow.monoFont; pixelSize: Math.round(9.5 * scaleFactor); bold: true }
                                }
                                Text {
                                    text: (hudWindow.hudData.utc_zulu || "00:00:00Z")
                                    color: "#ffffff"
                                    font { family: hudWindow.monoFont; pixelSize: Math.round(11.5 * scaleFactor); bold: true; features: { "tnum": 1 } }
                                }
                                Text {
                                    text: "ZONE: UTC+00:00"
                                    color: "#64748B"
                                    font { family: hudWindow.monoFont; pixelSize: Math.round(8.5 * scaleFactor); features: { "tnum": 1 } }
                                }
                            }
                        }

                        // Hairline Separator
                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: "#181d26"
                        }

                        // ── SECTION 2: TE DIURNAL SOLAR CYCLE TRACK & EPHEMERIS TELEMETRY ─────
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: Math.round(2 * scaleFactor)

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Math.round(6 * scaleFactor)

                                Text {
                                    text: "SOLAR TRACK"
                                    color: Qt.rgba(1, 1, 1, 0.4)
                                    font { family: hudWindow.monoFont; pixelSize: Math.round(9.5 * scaleFactor); bold: true }
                                }
                                Text {
                                    text: "DAWN " + (hudWindow.hudData.sunrise || "06:26")
                                    color: "#FF9F0A"
                                    font { family: hudWindow.monoFont; pixelSize: Math.round(9 * scaleFactor); bold: true; features: { "tnum": 1 } }
                                }

                                Item { Layout.fillWidth: true }

                                Text {
                                    text: "ELEV: " + ((hudWindow.hudData.solar_elev_deg !== undefined) ? ((hudWindow.hudData.solar_elev_deg >= 0 ? "+" : "") + hudWindow.hudData.solar_elev_deg + "°") : "-29.5°") +
                                          " │ AZ: " + ((hudWindow.hudData.solar_az_deg !== undefined) ? (hudWindow.hudData.solar_az_deg + "°") : "263.5°")
                                    color: (hudWindow.hudData.solar_elev_deg !== undefined && hudWindow.hudData.solar_elev_deg > 0) ? "#30D158" : "#64D2FF"
                                    font { family: hudWindow.monoFont; pixelSize: Math.round(8.5 * scaleFactor); bold: true; features: { "tnum": 1 } }
                                }

                                Item { Layout.fillWidth: true }

                                Text {
                                    text: "DUSK " + (hudWindow.hudData.sunset || "17:20")
                                    color: "#FF5F15"
                                    font { family: hudWindow.monoFont; pixelSize: Math.round(9 * scaleFactor); bold: true; features: { "tnum": 1 } }
                                }
                                Text {
                                    text: "[" + (hudWindow.hudData.daylight_rem || "NIGHT") + "]"
                                    color: (hudWindow.hudData.daylight_rem && hudWindow.hudData.daylight_rem.indexOf("NIGHT") === -1) ? "#30D158" : "#8b949e"
                                    font { family: hudWindow.monoFont; pixelSize: Math.round(9.5 * scaleFactor); bold: true }
                                }
                            }

                            // 48-Segment Discrete Mechanical LED Solar Track
                            RowLayout {
                                Layout.fillWidth: true
                                height: Math.round(8 * scaleFactor)
                                spacing: 2

                                Repeater {
                                    model: 48
                                    delegate: Rectangle {
                                        Layout.fillWidth: true
                                        height: Math.round(5 * scaleFactor)
                                        radius: 1

                                        readonly property real curDiurnal: hudWindow.hudData.diurnal_pct || 0.81
                                        readonly property int activeIdx: Math.min(47, Math.floor(curDiurnal * 48))
                                        // Kanpur daylight hours approx 6:26 to 17:20 -> indices ~13 to 34
                                        readonly property bool isDaySlot: index >= 13 && index <= 34

                                        color: {
                                            if (index === activeIdx) return "#FF5F15"; // Mechanical cursor position
                                            if (index < activeIdx) {
                                                return isDaySlot ? "#FF9F0A" : "#38BDF8";
                                            }
                                            return isDaySlot ? "#2a2215" : "#101622";
                                        }
                                        border.color: (index === activeIdx) ? "#ffffff" : "transparent"
                                        border.width: (index === activeIdx) ? 1 : 0
                                    }
                                }
                            }
                        }

                        // Hairline Separator
                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: "#181d26"
                        }

                        // ── SECTION 3: SYSTEM HARDWARE CHRONO & EPHEMERIS SUMMARY ─────
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Math.round(6 * scaleFactor)

                            // 1. Linux Epoch Timestamp
                            Rectangle {
                                Layout.fillWidth: true
                                height: Math.round(20 * scaleFactor)
                                color: "#080c14"
                                border.color: "#182030"
                                border.width: 1
                                radius: 2

                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: Math.round(4 * scaleFactor)
                                    Text { text: "EPOCH:"; color: "#64748B"; font { family: hudWindow.monoFont; pixelSize: Math.round(8.5 * scaleFactor); bold: true } }
                                    Text {
                                        text: (hudWindow.hudData && hudWindow.hudData.epoch) ? hudWindow.hudData.epoch.toString() : Math.floor(Date.now() / 1000).toString()
                                        color: "#00E5FF"
                                        font { family: hudWindow.monoFont; pixelSize: Math.round(9 * scaleFactor); bold: true; features: { "tnum": 1 } }
                                    }
                                }
                            }

                            // 2. Day of Year / ISO Week
                            Rectangle {
                                Layout.fillWidth: true
                                height: Math.round(20 * scaleFactor)
                                color: "#080c14"
                                border.color: "#182030"
                                border.width: 1
                                radius: 2

                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: Math.round(4 * scaleFactor)
                                    Text { text: "DOY / WEEK:"; color: "#64748B"; font { family: hudWindow.monoFont; pixelSize: Math.round(8.5 * scaleFactor); bold: true } }
                                    Text {
                                        text: ((hudWindow.hudData && hudWindow.hudData.doy) ? ("DOY " + hudWindow.hudData.doy) : "DOY 315") + " [W" + ((hudWindow.hudData && hudWindow.hudData.week) ? hudWindow.hudData.week : "46") + "]"
                                        color: "#ffffff"
                                        font { family: hudWindow.monoFont; pixelSize: Math.round(9 * scaleFactor); bold: true; features: { "tnum": 1 } }
                                    }
                                }
                            }

                            // 3. NTP Sync & Jitter
                            Rectangle {
                                Layout.fillWidth: true
                                height: Math.round(20 * scaleFactor)
                                color: "#080c14"
                                border.color: "#182030"
                                border.width: 1
                                radius: 2

                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: Math.round(4 * scaleFactor)
                                    Rectangle { width: 5; height: 5; radius: 1; color: "#30D158" }
                                    Text { text: "NTP SYNC:"; color: "#64748B"; font { family: hudWindow.monoFont; pixelSize: Math.round(8.5 * scaleFactor); bold: true } }
                                    Text { text: "LOCKED [±0.04ms]"; color: "#30D158"; font { family: hudWindow.monoFont; pixelSize: Math.round(9 * scaleFactor); bold: true; features: { "tnum": 1 } } }
                                }
                            }

                            // 4. Local Sidereal Time
                            Rectangle {
                                Layout.fillWidth: true
                                height: Math.round(20 * scaleFactor)
                                color: "#080c14"
                                border.color: "#182030"
                                border.width: 1
                                radius: 2

                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: Math.round(4 * scaleFactor)
                                    Text { text: "LST:"; color: "#64748B"; font { family: hudWindow.monoFont; pixelSize: Math.round(8.5 * scaleFactor); bold: true } }
                                    Text {
                                        text: (hudWindow.hudData && hudWindow.hudData.lst) ? hudWindow.hudData.lst : "01:42 LST"
                                        color: "#FF9F0A"
                                        font { family: hudWindow.monoFont; pixelSize: Math.round(9 * scaleFactor); bold: true; features: { "tnum": 1 } }
                                    }
                                }
                            }
                        }
                    }
                }

                // ── PANE 2B: GROUNDCONTROL HARDWARE CONTROL MATRIX (Compacted) ──
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.round(218 * scaleFactor)
                    color: "#000000"
                    border.color: "#181d26"
                    border.width: 1

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Math.round(8 * scaleFactor)
                        anchors.rightMargin: Math.round(8 * scaleFactor)
                        anchors.topMargin: Math.round(6 * scaleFactor)
                        anchors.bottomMargin: Math.round(6 * scaleFactor)
                        spacing: Math.round(4 * scaleFactor)

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Math.round(6 * scaleFactor)
                            Text {
                                text: "┌─ [05] AUDIO COMMAND"
                                color: "#0A84FF"
                                font { family: hudWindow.monoFont; pixelSize: Math.round(11.5 * scaleFactor); bold: true }
                            }
                            Rectangle {
                                Layout.fillWidth: true
                                height: 1
                                color: "#212836"
                                Layout.alignment: Qt.AlignVCenter
                            }
                        }

                        // Sliders & Telemetry Container (Dual Stereo Channel Strip: Master Output & Mic Gain)
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Math.round(8 * scaleFactor)

                            // Master Audio Channel Deck (Item id kept for desktop input mask)
                            Item {
                                id: interactiveSlidersArea
                                Layout.fillWidth: true
                                height: Math.round(44 * scaleFactor)

                                ColumnLayout {
                                    anchors.fill: parent
                                    spacing: Math.round(2 * scaleFactor)

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: Math.round(4 * scaleFactor)
                                        readonly property bool isMuted: (shellRoot && shellRoot.volumeMuted) || false

                                        Rectangle {
                                            width: Math.round(16 * scaleFactor)
                                            height: Math.round(16 * scaleFactor)
                                            color: parent.isMuted ? "#250d0d" : "#0d1b2a"
                                            border.color: parent.isMuted ? "#FF453A" : "#0A84FF"
                                            border.width: 1
                                            radius: 2

                                            Text {
                                                anchors.centerIn: parent
                                                text: parent.parent.isMuted ? "󰖁" : "󰕾"
                                                color: parent.parent.isMuted ? "#FF453A" : "#0A84FF"
                                                font { family: hudWindow.iconFont; pixelSize: Math.round(9 * scaleFactor) }
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    if (shellRoot && shellRoot.pVolMute) shellRoot.pVolMute.running = true;
                                                }
                                            }
                                        }

                                        Text {
                                            text: parent.isMuted ? "OUT [MUTED]" : "MASTER AUDIO OUT"
                                            color: parent.isMuted ? "#FF453A" : "#0A84FF"
                                            font { family: hudWindow.monoFont; pixelSize: Math.round(9.5 * scaleFactor); bold: true }
                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    if (shellRoot && shellRoot.pVolMute) shellRoot.pVolMute.running = true;
                                                }
                                            }
                                        }

                                        Item { Layout.fillWidth: true }

                                        Text {
                                            readonly property int notchIdx: Math.round((parseFloat((shellRoot ? shellRoot.volumeOut : "75%").replace("%", "")) || 75) / 100.0 * 20)
                                            text: parent.isMuted ? "[MUTED]" : (shellRoot ? shellRoot.volumeOut : "75%") + " [" + notchIdx + "/20]"
                                            color: parent.isMuted ? "#FF453A" : "#ffffff"
                                            font { family: hudWindow.monoFont; pixelSize: Math.round(9 * scaleFactor); bold: true; features: { "tnum": 1 } }
                                        }
                                    }

                                    // 20-Segment Mechanical Encoder Bar
                                    Rectangle {
                                        id: volChassis
                                        Layout.fillWidth: true
                                        height: Math.round(16 * scaleFactor)
                                        color: "#06090e"
                                        border.color: (shellRoot && shellRoot.volumeMuted) ? "#FF453A" : (volMa.containsMouse ? "#64D2FF" : "#212836")
                                        border.width: 1
                                        radius: 2
                                        scale: volMa.pressed ? 0.985 : 1.0
                                        Behavior on scale { NumberAnimation { duration: 50 } }

                                        readonly property bool isMuted: (shellRoot && shellRoot.volumeMuted) || false
                                        readonly property real volNorm: {
                                            var vStr = shellRoot ? shellRoot.volumeOut : "75%";
                                            var v = parseFloat(vStr.replace("%", "")) || 75;
                                            return Math.max(0.0, Math.min(1.0, v / 100.0));
                                        }

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.margins: 2
                                            spacing: 2

                                            Repeater {
                                                model: 20
                                                Rectangle {
                                                    Layout.fillWidth: true
                                                    Layout.fillHeight: true
                                                    radius: 1
                                                    readonly property bool isLit: (index / 20.0) < volChassis.volNorm
                                                    readonly property bool isTip: isLit && ((index + 1) / 20.0) >= volChassis.volNorm
                                                    readonly property bool isHovered: volMa.containsMouse && Math.floor((volMa.mouseX - 2) / ((volChassis.width - 4) / 20)) === index

                                                    color: volChassis.isMuted
                                                        ? (isLit ? "#351518" : "#0e131d")
                                                        : (isTip ? "#ffffff" : (isLit
                                                            ? (index >= 17 ? "#FF453A" : (index >= 14 ? "#FF9F0A" : "#0A84FF"))
                                                            : (isHovered ? "#223145" : "#0e131d")))
                                                    border.color: volChassis.isMuted && isLit ? "#FF453A" : "transparent"
                                                    border.width: volChassis.isMuted && isLit ? 1 : 0
                                                    opacity: volChassis.isMuted ? (isLit ? 0.75 : 0.25) : (isLit ? 1.0 : (isHovered ? 0.8 : 0.35))
                                                }
                                            }
                                        }

                                        MouseArea {
                                            id: volMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                                            onClicked: mouse => {
                                                if (mouse.button === Qt.RightButton) {
                                                    if (shellRoot && shellRoot.pVolMute) shellRoot.pVolMute.running = true;
                                                    return;
                                                }
                                                var targetPct = Math.max(0, Math.min(100, Math.round((mouse.x / width) * 100)));
                                                if (shellRoot && shellRoot.pVolSet) {
                                                    shellRoot.pVolSet.command = ["/home/krishna/dotfiles/scripts/set_volume.sh", (targetPct / 100.0).toFixed(2)];
                                                    shellRoot.pVolSet.running = true;
                                                }
                                            }
                                            onPositionChanged: mouse => {
                                                if (pressed && shellRoot && shellRoot.pVolSet) {
                                                    var targetPct = Math.max(0, Math.min(100, Math.round((mouse.x / width) * 100)));
                                                    shellRoot.pVolSet.command = ["/home/krishna/dotfiles/scripts/set_volume.sh", (targetPct / 100.0).toFixed(2)];
                                                    shellRoot.pVolSet.running = true;
                                                }
                                            }
                                            onWheel: wheel => {
                                                if (shellRoot && shellRoot.pVolSet) {
                                                    var cur = parseFloat((shellRoot.volumeOut || "75%").replace("%", "")) || 75;
                                                    var delta = wheel.angleDelta.y > 0 ? 3 : -3;
                                                    var targetPct = Math.max(0, Math.min(100, cur + delta));
                                                    shellRoot.pVolSet.command = ["/home/krishna/dotfiles/scripts/set_volume.sh", (targetPct / 100.0).toFixed(2)];
                                                    shellRoot.pVolSet.running = true;
                                                }
                                            }
                                        }
                                    }

                                    // Micro Scale Ruler
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 0
                                        Text { text: "0%"; color: "#555566"; font { family: hudWindow.monoFont; pixelSize: Math.round(7.5 * scaleFactor); features: { "tnum": 1 } } }
                                        Item { Layout.fillWidth: true }
                                        Text { text: "50%"; color: "#444b58"; font { family: hudWindow.monoFont; pixelSize: Math.round(7.5 * scaleFactor); features: { "tnum": 1 } } }
                                        Item { Layout.fillWidth: true }
                                        Text { text: "100%"; color: "#555566"; font { family: hudWindow.monoFont; pixelSize: Math.round(7.5 * scaleFactor); features: { "tnum": 1 } } }
                                    }
                                }
                            }

                            // Vertical Hairline Separator
                            Rectangle {
                                width: 1
                                height: Math.round(38 * scaleFactor)
                                color: "#181d26"
                                Layout.alignment: Qt.AlignVCenter
                            }

                            // Microphone Input Channel Deck (Item id kept for desktop input mask)
                            Item {
                                id: interactiveMicArea
                                Layout.fillWidth: true
                                height: Math.round(44 * scaleFactor)

                                ColumnLayout {
                                    anchors.fill: parent
                                    spacing: Math.round(2 * scaleFactor)

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: Math.round(4 * scaleFactor)

                                        Rectangle {
                                            width: Math.round(16 * scaleFactor)
                                            height: Math.round(16 * scaleFactor)
                                            color: hudWindow.hudMicMuted ? "#250d0d" : "#0d1b2a"
                                            border.color: hudWindow.hudMicMuted ? "#FF453A" : "#30D158"
                                            border.width: 1
                                            radius: 2

                                            Text {
                                                anchors.centerIn: parent
                                                text: hudWindow.hudMicMuted ? "󰍭" : "󰍬"
                                                color: hudWindow.hudMicMuted ? "#FF453A" : "#30D158"
                                                font { family: hudWindow.iconFont; pixelSize: Math.round(9 * scaleFactor) }
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: hudWindow.toggleHudMicMute()
                                            }
                                        }

                                        Text {
                                            text: hudWindow.hudMicMuted ? "MIC [MUTED]" : "MICROPHONE GAIN"
                                            color: hudWindow.hudMicMuted ? "#FF453A" : "#30D158"
                                            font { family: hudWindow.monoFont; pixelSize: Math.round(9.5 * scaleFactor); bold: true }
                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: hudWindow.toggleHudMicMute()
                                            }
                                        }

                                        Item { Layout.fillWidth: true }

                                        Text {
                                            readonly property int notchIdx: Math.round(hudWindow.hudMicVolumePct / 100.0 * 20)
                                            text: hudWindow.hudMicMuted ? "[MUTED]" : hudWindow.hudMicVolumePct + "% [" + notchIdx + "/20]"
                                            color: hudWindow.hudMicMuted ? "#FF453A" : "#ffffff"
                                            font { family: hudWindow.monoFont; pixelSize: Math.round(9 * scaleFactor); bold: true; features: { "tnum": 1 } }
                                        }
                                    }

                                    // 20-Segment Mechanical Encoder Bar
                                    Rectangle {
                                        id: micChassis
                                        Layout.fillWidth: true
                                        height: Math.round(16 * scaleFactor)
                                        color: "#06090e"
                                        border.color: hudWindow.hudMicMuted ? "#FF453A" : (micMa.containsMouse ? "#30D158" : "#212836")
                                        border.width: 1
                                        radius: 2
                                        scale: micMa.pressed ? 0.985 : 1.0
                                        Behavior on scale { NumberAnimation { duration: 50 } }

                                        readonly property real micPct: Math.max(0.0, Math.min(1.0, hudWindow.hudMicVolumePct / 100.0))

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.margins: 2
                                            spacing: 2

                                            Repeater {
                                                model: 20
                                                Rectangle {
                                                    Layout.fillWidth: true
                                                    Layout.fillHeight: true
                                                    radius: 1
                                                    readonly property bool isLit: (index / 20.0) < micChassis.micPct
                                                    readonly property bool isTip: isLit && ((index + 1) / 20.0) >= micChassis.micPct
                                                    readonly property bool isHovered: micMa.containsMouse && Math.floor((micMa.mouseX - 2) / ((micChassis.width - 4) / 20)) === index

                                                    color: hudWindow.hudMicMuted
                                                        ? (isLit ? "#351518" : "#0e131d")
                                                        : (isTip ? "#ffffff" : (isLit
                                                            ? (index >= 17 ? "#FF453A" : (index >= 14 ? "#FF9F0A" : "#30D158"))
                                                            : (isHovered ? "#1b2d20" : "#0e131d")))
                                                    border.color: hudWindow.hudMicMuted && isLit ? "#FF453A" : "transparent"
                                                    border.width: hudWindow.hudMicMuted && isLit ? 1 : 0
                                                    opacity: hudWindow.hudMicMuted ? (isLit ? 0.75 : 0.25) : (isLit ? 1.0 : (isHovered ? 0.8 : 0.35))
                                                }
                                            }
                                        }

                                        MouseArea {
                                            id: micMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                                            onClicked: mouse => {
                                                if (mouse.button === Qt.RightButton) {
                                                    hudWindow.toggleHudMicMute();
                                                    return;
                                                }
                                                var raw = Math.max(0.0, Math.min(1.0, (mouse.x - 2) / (width - 4)));
                                                hudWindow.setHudMicVolume(raw);
                                            }
                                            onPositionChanged: mouse => {
                                                if (pressed) {
                                                    var raw = Math.max(0.0, Math.min(1.0, (mouse.x - 2) / (width - 4)));
                                                    hudWindow.setHudMicVolume(raw);
                                                }
                                            }
                                            onWheel: wheel => {
                                                var delta = wheel.angleDelta.y > 0 ? 5 : -5;
                                                var newPct = Math.max(0, Math.min(100, hudWindow.hudMicVolumePct + delta));
                                                hudWindow.setHudMicVolume(newPct / 100.0);
                                            }
                                        }
                                    }

                                    // Micro Scale Ruler
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 0
                                        Text { text: "0%"; color: "#555566"; font { family: hudWindow.monoFont; pixelSize: Math.round(7.5 * scaleFactor); features: { "tnum": 1 } } }
                                        Item { Layout.fillWidth: true }
                                        Text { text: "50%"; color: "#444b58"; font { family: hudWindow.monoFont; pixelSize: Math.round(7.5 * scaleFactor); features: { "tnum": 1 } } }
                                        Item { Layout.fillWidth: true }
                                        Text { text: "100%"; color: "#555566"; font { family: hudWindow.monoFont; pixelSize: Math.round(7.5 * scaleFactor); features: { "tnum": 1 } } }
                                    }
                                }
                            }
                        }

                        // Clipboard Latest Entry (Single most recent text item, zero flicker)
                        Rectangle {
                            Layout.fillWidth: true
                            height: Math.round(22 * scaleFactor)
                            color: "#080c14"
                            border.color: "#212836"
                            border.width: 1

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: Math.round(10 * scaleFactor)
                                anchors.rightMargin: Math.round(10 * scaleFactor)
                                spacing: Math.round(10 * scaleFactor)
                                Text {
                                    text: "󰅌"
                                    color: "#64D2FF"
                                    font { family: hudWindow.iconFont; pixelSize: Math.round(11 * scaleFactor) }
                                }
                                Text {
                                    text: "CLIP:"
                                    color: "#64D2FF"
                                    font { family: hudWindow.monoFont; pixelSize: Math.round(10 * scaleFactor); bold: true }
                                }
                                Text {
                                    text: {
                                        var c = (hudWindow.hudData && hudWindow.hudData.clip) ? hudWindow.hudData.clip : "─ IDLE // BUFFER CLEAR ─";
                                        if (c.indexOf("Failed to load") !== -1 || c.indexOf("@shell.qml") !== -1 || c.indexOf("Traceback") !== -1 || c.indexOf("Error:") !== -1) {
                                            return "─ IDLE // BUFFER CLEAR ─";
                                        }
                                        return c;
                                    }
                                    color: Qt.rgba(1, 1, 1, 0.75)
                                    font { family: hudWindow.monoFont; pixelSize: Math.round(10 * scaleFactor) }
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (shellRoot && shellRoot.togglePopup && shellRoot.clipboardPopup) {
                                        shellRoot.togglePopup(shellRoot.clipboardPopup);
                                    }
                                }
                            }
                        }

                        // 10 Tactical Mechanical 3D Sharp Box Buttons (Latching & White Bezel Extrusion)
                        Item {
                            id: interactiveTogglesArea
                            Layout.fillWidth: true
                            height: Math.round(76 * scaleFactor)

                            GridLayout {
                                anchors.fill: parent
                                columns: 5
                                rows: 2
                                columnSpacing: Math.round(6 * scaleFactor)
                                rowSpacing: Math.round(6 * scaleFactor)

                                // ── 1. DND ────────────────────────────────────
                                Item {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    readonly property bool active: shellRoot && shellRoot.dndActive
                                    readonly property color accentColor: "#FF453A"
                                    readonly property color activeBg: "#220d0d"
                                    readonly property color activeShadow: "#3d1414"

                                    // Lighter / Whitish 3D Box Drop Slab (machined under-socket)
                                    Rectangle {
                                        anchors.fill: parent
                                        anchors.leftMargin: Math.round(2 * scaleFactor)
                                        anchors.topMargin: Math.round(2 * scaleFactor)
                                        color: parent.active ? parent.activeShadow : (dndMa.containsMouse ? "#28374a" : "#182332")
                                        border.color: parent.active ? parent.accentColor : (dndMa.containsMouse ? "#ffffff" : Qt.rgba(1, 1, 1, 0.60))
                                        border.width: 1
                                        radius: 1
                                    }

                                    // Sharp Keycap Face (Translates down-right when pressed or latched)
                                    Rectangle {
                                        id: dndFront
                                        z: 2
                                        anchors.left: parent.left
                                        anchors.top: parent.top
                                        anchors.right: parent.right
                                        anchors.bottom: parent.bottom
                                        anchors.leftMargin: (dndMa.pressed || parent.active) ? Math.round(2 * scaleFactor) : 0
                                        anchors.topMargin: (dndMa.pressed || parent.active) ? Math.round(2 * scaleFactor) : (dndMa.containsMouse ? -Math.round(1 * scaleFactor) : 0)
                                        anchors.rightMargin: (dndMa.pressed || parent.active) ? 0 : Math.round(2 * scaleFactor)
                                        anchors.bottomMargin: (dndMa.pressed || parent.active) ? 0 : (dndMa.containsMouse ? Math.round(3 * scaleFactor) : Math.round(2 * scaleFactor))

                                        color: parent.active ? parent.activeBg : (dndMa.containsMouse ? "#141e2c" : "#0d141e")
                                        border.color: parent.active ? parent.accentColor : (dndMa.containsMouse ? "#64D2FF" : "#2a394e")
                                        border.width: 1
                                        radius: 1

                                        Behavior on anchors.leftMargin { NumberAnimation { duration: 55; easing.type: Easing.OutQuad } }
                                        Behavior on anchors.topMargin { NumberAnimation { duration: 55; easing.type: Easing.OutQuad } }
                                        Behavior on anchors.rightMargin { NumberAnimation { duration: 55; easing.type: Easing.OutQuad } }
                                        Behavior on anchors.bottomMargin { NumberAnimation { duration: 55; easing.type: Easing.OutQuad } }

                                        // Micro Bevel Highlight Line
                                        Rectangle {
                                            anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 1
                                            height: 1; color: parent.parent.active ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(1, 1, 1, 0.12)
                                        }

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.margins: Math.round(4 * scaleFactor)
                                            spacing: Math.round(4 * scaleFactor)
                                            Text {
                                                text: parent.parent.parent.active ? "■" : "•"
                                                color: parent.parent.parent.active ? parent.parent.parent.accentColor : "#64748b"
                                                font { family: hudWindow.monoFont; pixelSize: Math.round(9.5 * scaleFactor); bold: true }
                                            }
                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: 0
                                                Text { text: "DND"; color: parent.parent.parent.parent.active ? "#ffffff" : "#cbd5e1"; font { family: hudWindow.monoFont; pixelSize: Math.round(9.5 * scaleFactor); bold: true } }
                                                Text { text: parent.parent.parent.parent.active ? "ON" : "OFF"; color: parent.parent.parent.parent.active ? parent.parent.parent.parent.accentColor : "#64748b"; font { family: hudWindow.monoFont; pixelSize: Math.round(8.5 * scaleFactor); bold: true } }
                                            }
                                        }
                                    }
                                    MouseArea {
                                        id: dndMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: { if (shellRoot) shellRoot.dndActive = !shellRoot.dndActive; }
                                    }
                                }

                                // ── 2. CAFFEINE ───────────────────────────────
                                Item {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    readonly property bool active: shellRoot && shellRoot.caffeineActive
                                    readonly property color accentColor: "#FF9F0A"
                                    readonly property color activeBg: "#261608"
                                    readonly property color activeShadow: "#45240a"

                                    Rectangle {
                                        anchors.fill: parent
                                        anchors.leftMargin: Math.round(2 * scaleFactor)
                                        anchors.topMargin: Math.round(2 * scaleFactor)
                                        color: parent.active ? parent.activeShadow : (caffMa.containsMouse ? "#28374a" : "#182332")
                                        border.color: parent.active ? parent.accentColor : (caffMa.containsMouse ? "#ffffff" : Qt.rgba(1, 1, 1, 0.60))
                                        border.width: 1
                                        radius: 1
                                    }

                                    Rectangle {
                                        id: caffFront
                                        z: 2
                                        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.bottom: parent.bottom
                                        anchors.leftMargin: (caffMa.pressed || parent.active) ? Math.round(2 * scaleFactor) : 0
                                        anchors.topMargin: (caffMa.pressed || parent.active) ? Math.round(2 * scaleFactor) : (caffMa.containsMouse ? -Math.round(1 * scaleFactor) : 0)
                                        anchors.rightMargin: (caffMa.pressed || parent.active) ? 0 : Math.round(2 * scaleFactor)
                                        anchors.bottomMargin: (caffMa.pressed || parent.active) ? 0 : (caffMa.containsMouse ? Math.round(3 * scaleFactor) : Math.round(2 * scaleFactor))

                                        color: parent.active ? parent.activeBg : (caffMa.containsMouse ? "#141e2c" : "#0d141e")
                                        border.color: parent.active ? parent.accentColor : (caffMa.containsMouse ? "#64D2FF" : "#2a394e")
                                        border.width: 1
                                        radius: 1

                                        Behavior on anchors.leftMargin { NumberAnimation { duration: 55; easing.type: Easing.OutQuad } }
                                        Behavior on anchors.topMargin { NumberAnimation { duration: 55; easing.type: Easing.OutQuad } }
                                        Behavior on anchors.rightMargin { NumberAnimation { duration: 55; easing.type: Easing.OutQuad } }
                                        Behavior on anchors.bottomMargin { NumberAnimation { duration: 55; easing.type: Easing.OutQuad } }

                                        Rectangle {
                                            anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 1
                                            height: 1; color: parent.parent.active ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(1, 1, 1, 0.12)
                                        }

                                        RowLayout {
                                            anchors.fill: parent; anchors.margins: Math.round(4 * scaleFactor); spacing: Math.round(4 * scaleFactor)
                                            Text { text: parent.parent.parent.active ? "■" : "•"; color: parent.parent.parent.active ? parent.parent.parent.accentColor : "#64748b"; font { family: hudWindow.monoFont; pixelSize: Math.round(9.5 * scaleFactor); bold: true } }
                                            ColumnLayout {
                                                Layout.fillWidth: true; spacing: 0
                                                Text { text: "CAFF"; color: parent.parent.parent.parent.active ? "#ffffff" : "#cbd5e1"; font { family: hudWindow.monoFont; pixelSize: Math.round(9.5 * scaleFactor); bold: true } }
                                                Text { text: parent.parent.parent.parent.active ? "AWAKE" : "OFF"; color: parent.parent.parent.parent.active ? parent.parent.parent.parent.accentColor : "#64748b"; font { family: hudWindow.monoFont; pixelSize: Math.round(8.5 * scaleFactor); bold: true } }
                                            }
                                        }
                                    }
                                    MouseArea {
                                        id: caffMa
                                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (shellRoot) {
                                                shellRoot.caffeineActive = !shellRoot.caffeineActive;
                                                if (shellRoot.toggleCaffeine) {
                                                    shellRoot.toggleCaffeine();
                                                } else if (shellRoot.pCaffeineToggle) {
                                                    shellRoot.pCaffeineToggle.running = false;
                                                    shellRoot.pCaffeineToggle.running = true;
                                                }
                                            }
                                        }
                                    }
                                }

                                // ── 3. SCREEN RECORD ──────────────────────────
                                Item {
                                    Layout.fillWidth: true; Layout.fillHeight: true
                                    readonly property bool active: shellRoot && shellRoot.isRecording
                                    readonly property color accentColor: "#FF453A"
                                    readonly property color activeBg: "#220d0d"
                                    readonly property color activeShadow: "#3d1414"

                                    Rectangle {
                                        anchors.fill: parent
                                        anchors.leftMargin: Math.round(2 * scaleFactor)
                                        anchors.topMargin: Math.round(2 * scaleFactor)
                                        color: parent.active ? parent.activeShadow : (recMa.containsMouse ? "#28374a" : "#182332")
                                        border.color: parent.active ? parent.accentColor : (recMa.containsMouse ? "#ffffff" : Qt.rgba(1, 1, 1, 0.60))
                                        border.width: 1
                                        radius: 1
                                    }

                                    Rectangle {
                                        id: recFront
                                        z: 2
                                        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.bottom: parent.bottom
                                        anchors.leftMargin: (recMa.pressed || parent.active) ? Math.round(2 * scaleFactor) : 0
                                        anchors.topMargin: (recMa.pressed || parent.active) ? Math.round(2 * scaleFactor) : (recMa.containsMouse ? -Math.round(1 * scaleFactor) : 0)
                                        anchors.rightMargin: (recMa.pressed || parent.active) ? 0 : Math.round(2 * scaleFactor)
                                        anchors.bottomMargin: (recMa.pressed || parent.active) ? 0 : (recMa.containsMouse ? Math.round(3 * scaleFactor) : Math.round(2 * scaleFactor))

                                        color: parent.active ? parent.activeBg : (recMa.containsMouse ? "#141e2c" : "#0d141e")
                                        border.color: parent.active ? parent.accentColor : (recMa.containsMouse ? "#64D2FF" : "#2a394e")
                                        border.width: 1; radius: 1

                                        Behavior on anchors.leftMargin { NumberAnimation { duration: 55; easing.type: Easing.OutQuad } }
                                        Behavior on anchors.topMargin { NumberAnimation { duration: 55; easing.type: Easing.OutQuad } }
                                        Behavior on anchors.rightMargin { NumberAnimation { duration: 55; easing.type: Easing.OutQuad } }
                                        Behavior on anchors.bottomMargin { NumberAnimation { duration: 55; easing.type: Easing.OutQuad } }

                                        Rectangle {
                                            anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 1
                                            height: 1; color: parent.parent.active ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(1, 1, 1, 0.12)
                                        }

                                        RowLayout {
                                            anchors.fill: parent; anchors.margins: Math.round(4 * scaleFactor); spacing: Math.round(4 * scaleFactor)
                                            Text { text: parent.parent.parent.active ? "■" : "•"; color: parent.parent.parent.active ? parent.parent.parent.accentColor : "#64748b"; font { family: hudWindow.monoFont; pixelSize: Math.round(9.5 * scaleFactor); bold: true } }
                                            ColumnLayout {
                                                Layout.fillWidth: true; spacing: 0
                                                Text { text: "REC"; color: parent.parent.parent.parent.active ? "#ffffff" : "#cbd5e1"; font { family: hudWindow.monoFont; pixelSize: Math.round(9.5 * scaleFactor); bold: true } }
                                                Text { text: parent.parent.parent.parent.active ? (shellRoot.recordingTime || "REC") : "IDLE"; color: parent.parent.parent.parent.active ? parent.parent.parent.parent.accentColor : "#64748b"; font { family: hudWindow.monoFont; pixelSize: Math.round(8.5 * scaleFactor); bold: true } }
                                            }
                                        }
                                    }
                                    MouseArea {
                                        id: recMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onClicked: { if (shellRoot) shellRoot.toggleRecording(); }
                                    }
                                }

                                // ── 4. MIC MUTE ───────────────────────────────
                                Item {
                                    Layout.fillWidth: true; Layout.fillHeight: true
                                    readonly property bool active: !hudWindow.hudMicMuted
                                    readonly property color accentColor: "#30D158"
                                    readonly property color activeBg: "#0c1f12"
                                    readonly property color activeShadow: "#14361e"

                                    Rectangle {
                                        anchors.fill: parent
                                        anchors.leftMargin: Math.round(2 * scaleFactor)
                                        anchors.topMargin: Math.round(2 * scaleFactor)
                                        color: parent.active ? parent.activeShadow : (micBtnMa.containsMouse ? "#28374a" : "#182332")
                                        border.color: parent.active ? parent.accentColor : (micBtnMa.containsMouse ? "#ffffff" : Qt.rgba(1, 1, 1, 0.60))
                                        border.width: 1
                                        radius: 1
                                    }

                                    Rectangle {
                                        id: micBtnFront
                                        z: 2
                                        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.bottom: parent.bottom
                                        anchors.leftMargin: (micBtnMa.pressed || parent.active) ? Math.round(2 * scaleFactor) : 0
                                        anchors.topMargin: (micBtnMa.pressed || parent.active) ? Math.round(2 * scaleFactor) : (micBtnMa.containsMouse ? -Math.round(1 * scaleFactor) : 0)
                                        anchors.rightMargin: (micBtnMa.pressed || parent.active) ? 0 : Math.round(2 * scaleFactor)
                                        anchors.bottomMargin: (micBtnMa.pressed || parent.active) ? 0 : (micBtnMa.containsMouse ? Math.round(3 * scaleFactor) : Math.round(2 * scaleFactor))

                                        color: parent.active ? parent.activeBg : (micBtnMa.containsMouse ? "#141e2c" : "#0d141e")
                                        border.color: parent.active ? parent.accentColor : (micBtnMa.containsMouse ? "#64D2FF" : "#2a394e")
                                        border.width: 1; radius: 1

                                        Behavior on anchors.leftMargin { NumberAnimation { duration: 55; easing.type: Easing.OutQuad } }
                                        Behavior on anchors.topMargin { NumberAnimation { duration: 55; easing.type: Easing.OutQuad } }
                                        Behavior on anchors.rightMargin { NumberAnimation { duration: 55; easing.type: Easing.OutQuad } }
                                        Behavior on anchors.bottomMargin { NumberAnimation { duration: 55; easing.type: Easing.OutQuad } }

                                        Rectangle {
                                            anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 1
                                            height: 1; color: parent.parent.active ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(1, 1, 1, 0.12)
                                        }

                                        RowLayout {
                                            anchors.fill: parent; anchors.margins: Math.round(4 * scaleFactor); spacing: Math.round(4 * scaleFactor)
                                            Text { text: parent.parent.parent.active ? "■" : "•"; color: parent.parent.parent.active ? parent.parent.parent.accentColor : "#64748b"; font { family: hudWindow.monoFont; pixelSize: Math.round(9.5 * scaleFactor); bold: true } }
                                            ColumnLayout {
                                                Layout.fillWidth: true; spacing: 0
                                                Text { text: "MIC"; color: parent.parent.parent.parent.active ? "#ffffff" : "#cbd5e1"; font { family: hudWindow.monoFont; pixelSize: Math.round(9.5 * scaleFactor); bold: true } }
                                                Text { text: parent.parent.parent.parent.active ? "LIVE" : "MUTED"; color: parent.parent.parent.parent.active ? parent.parent.parent.parent.accentColor : "#FF453A"; font { family: hudWindow.monoFont; pixelSize: Math.round(8.5 * scaleFactor); bold: true } }
                                            }
                                        }
                                    }
                                    MouseArea {
                                        id: micBtnMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onClicked: hudWindow.toggleHudMicMute()
                                    }
                                }

                                // ── 5. TIMER ──────────────────────────────────
                                Item {
                                    Layout.fillWidth: true; Layout.fillHeight: true
                                    readonly property bool active: shellRoot && shellRoot.timerRunning
                                    readonly property color accentColor: "#0A84FF"
                                    readonly property color activeBg: "#0a1928"
                                    readonly property color activeShadow: "#132b45"

                                    Rectangle {
                                        anchors.fill: parent
                                        anchors.leftMargin: Math.round(2 * scaleFactor)
                                        anchors.topMargin: Math.round(2 * scaleFactor)
                                        color: parent.active ? parent.activeShadow : (timerBtnMa.containsMouse ? "#28374a" : "#182332")
                                        border.color: parent.active ? parent.accentColor : (timerBtnMa.containsMouse ? "#ffffff" : Qt.rgba(1, 1, 1, 0.60))
                                        border.width: 1
                                        radius: 1
                                    }

                                    Rectangle {
                                        id: timerBtnFront
                                        z: 2
                                        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.bottom: parent.bottom
                                        anchors.leftMargin: (timerBtnMa.pressed || parent.active) ? Math.round(2 * scaleFactor) : 0
                                        anchors.topMargin: (timerBtnMa.pressed || parent.active) ? Math.round(2 * scaleFactor) : (timerBtnMa.containsMouse ? -Math.round(1 * scaleFactor) : 0)
                                        anchors.rightMargin: (timerBtnMa.pressed || parent.active) ? 0 : Math.round(2 * scaleFactor)
                                        anchors.bottomMargin: (timerBtnMa.pressed || parent.active) ? 0 : (timerBtnMa.containsMouse ? Math.round(3 * scaleFactor) : Math.round(2 * scaleFactor))

                                        color: parent.active ? parent.activeBg : (timerBtnMa.containsMouse ? "#141e2c" : "#0d141e")
                                        border.color: parent.active ? parent.accentColor : (timerBtnMa.containsMouse ? "#64D2FF" : "#2a394e")
                                        border.width: 1; radius: 1

                                        Behavior on anchors.leftMargin { NumberAnimation { duration: 55; easing.type: Easing.OutQuad } }
                                        Behavior on anchors.topMargin { NumberAnimation { duration: 55; easing.type: Easing.OutQuad } }
                                        Behavior on anchors.rightMargin { NumberAnimation { duration: 55; easing.type: Easing.OutQuad } }
                                        Behavior on anchors.bottomMargin { NumberAnimation { duration: 55; easing.type: Easing.OutQuad } }

                                        Rectangle {
                                            anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 1
                                            height: 1; color: parent.parent.active ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(1, 1, 1, 0.12)
                                        }

                                        RowLayout {
                                            anchors.fill: parent; anchors.margins: Math.round(4 * scaleFactor); spacing: Math.round(4 * scaleFactor)
                                            Text { text: parent.parent.parent.active ? "■" : "•"; color: parent.parent.parent.active ? parent.parent.parent.accentColor : "#64748b"; font { family: hudWindow.monoFont; pixelSize: Math.round(9.5 * scaleFactor); bold: true } }
                                            ColumnLayout {
                                                Layout.fillWidth: true; spacing: 0
                                                Text { text: "TIMER"; color: parent.parent.parent.parent.active ? "#ffffff" : "#cbd5e1"; font { family: hudWindow.monoFont; pixelSize: Math.round(9.5 * scaleFactor); bold: true } }
                                                Text { text: (shellRoot && shellRoot.timerText) ? shellRoot.timerText : "05:00"; color: parent.parent.parent.parent.active ? parent.parent.parent.parent.accentColor : "#64748b"; font { family: hudWindow.monoFont; pixelSize: Math.round(8.5 * scaleFactor); bold: true } }
                                            }
                                        }
                                    }
                                    MouseArea {
                                        id: timerBtnMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (shellRoot) {
                                                shellRoot.timerRunning = !shellRoot.timerRunning;
                                            }
                                        }
                                    }
                                }

                                // ── 6. STOPWATCH ──────────────────────────────
                                Item {
                                    Layout.fillWidth: true; Layout.fillHeight: true
                                    readonly property bool active: shellRoot && shellRoot.stopwatchRunning
                                    readonly property color accentColor: "#64D2FF"
                                    readonly property color activeBg: "#0a1c26"
                                    readonly property color activeShadow: "#113042"

                                    Rectangle {
                                        anchors.fill: parent
                                        anchors.leftMargin: Math.round(2 * scaleFactor)
                                        anchors.topMargin: Math.round(2 * scaleFactor)
                                        color: parent.active ? parent.activeShadow : (swMa.containsMouse ? "#28374a" : "#182332")
                                        border.color: parent.active ? parent.accentColor : (swMa.containsMouse ? "#ffffff" : Qt.rgba(1, 1, 1, 0.60))
                                        border.width: 1
                                        radius: 1
                                    }

                                    Rectangle {
                                        id: swFront
                                        z: 2
                                        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.bottom: parent.bottom
                                        anchors.leftMargin: (swMa.pressed || parent.active) ? Math.round(2 * scaleFactor) : 0
                                        anchors.topMargin: (swMa.pressed || parent.active) ? Math.round(2 * scaleFactor) : (swMa.containsMouse ? -Math.round(1 * scaleFactor) : 0)
                                        anchors.rightMargin: (swMa.pressed || parent.active) ? 0 : Math.round(2 * scaleFactor)
                                        anchors.bottomMargin: (swMa.pressed || parent.active) ? 0 : (swMa.containsMouse ? Math.round(3 * scaleFactor) : Math.round(2 * scaleFactor))

                                        color: parent.active ? parent.activeBg : (swMa.containsMouse ? "#141e2c" : "#0d141e")
                                        border.color: parent.active ? parent.accentColor : (swMa.containsMouse ? "#64D2FF" : "#2a394e")
                                        border.width: 1; radius: 1

                                        Behavior on anchors.leftMargin { NumberAnimation { duration: 55; easing.type: Easing.OutQuad } }
                                        Behavior on anchors.topMargin { NumberAnimation { duration: 55; easing.type: Easing.OutQuad } }
                                        Behavior on anchors.rightMargin { NumberAnimation { duration: 55; easing.type: Easing.OutQuad } }
                                        Behavior on anchors.bottomMargin { NumberAnimation { duration: 55; easing.type: Easing.OutQuad } }

                                        Rectangle {
                                            anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 1
                                            height: 1; color: parent.parent.active ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(1, 1, 1, 0.12)
                                        }

                                        RowLayout {
                                            anchors.fill: parent; anchors.margins: Math.round(4 * scaleFactor); spacing: Math.round(4 * scaleFactor)
                                            Text { text: parent.parent.parent.active ? "■" : "•"; color: parent.parent.parent.active ? parent.parent.parent.accentColor : "#64748b"; font { family: hudWindow.monoFont; pixelSize: Math.round(9.5 * scaleFactor); bold: true } }
                                            ColumnLayout {
                                                Layout.fillWidth: true; spacing: 0
                                                Text { text: "WATCH"; color: parent.parent.parent.parent.active ? "#ffffff" : "#cbd5e1"; font { family: hudWindow.monoFont; pixelSize: Math.round(9.5 * scaleFactor); bold: true } }
                                                Text { text: (shellRoot && shellRoot.stopwatchTime) ? shellRoot.stopwatchTime : "00:00"; color: parent.parent.parent.parent.active ? parent.parent.parent.parent.accentColor : "#64748b"; font { family: hudWindow.monoFont; pixelSize: Math.round(8.5 * scaleFactor); bold: true } }
                                            }
                                        }
                                    }
                                    MouseArea {
                                        id: swMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onClicked: { if (shellRoot) shellRoot.stopwatchRunning = !shellRoot.stopwatchRunning; }
                                    }
                                }

                                // ── 7. WLAN OVERLAY ───────────────────────────
                                Item {
                                    Layout.fillWidth: true; Layout.fillHeight: true
                                    readonly property bool active: hudWindow.showWifiOverlay || (shellRoot && shellRoot.wifiActive)
                                    readonly property color accentColor: "#30D158"
                                    readonly property color activeBg: "#0c1f12"
                                    readonly property color activeShadow: "#14361e"

                                    Rectangle {
                                        anchors.fill: parent
                                        anchors.leftMargin: Math.round(2 * scaleFactor)
                                        anchors.topMargin: Math.round(2 * scaleFactor)
                                        color: parent.active ? parent.activeShadow : (wlanBtnMa.containsMouse ? "#28374a" : "#182332")
                                        border.color: parent.active ? parent.accentColor : (wlanBtnMa.containsMouse ? "#ffffff" : Qt.rgba(1, 1, 1, 0.60))
                                        border.width: 1
                                        radius: 1
                                    }

                                    Rectangle {
                                        id: wlanBtnFront
                                        z: 2
                                        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.bottom: parent.bottom
                                        anchors.leftMargin: (wlanBtnMa.pressed || parent.active) ? Math.round(2 * scaleFactor) : 0
                                        anchors.topMargin: (wlanBtnMa.pressed || parent.active) ? Math.round(2 * scaleFactor) : (wlanBtnMa.containsMouse ? -Math.round(1 * scaleFactor) : 0)
                                        anchors.rightMargin: (wlanBtnMa.pressed || parent.active) ? 0 : Math.round(2 * scaleFactor)
                                        anchors.bottomMargin: (wlanBtnMa.pressed || parent.active) ? 0 : (wlanBtnMa.containsMouse ? Math.round(3 * scaleFactor) : Math.round(2 * scaleFactor))

                                        color: parent.active ? parent.activeBg : (wlanBtnMa.containsMouse ? "#141e2c" : "#0d141e")
                                        border.color: parent.active ? parent.accentColor : (wlanBtnMa.containsMouse ? "#64D2FF" : "#2a394e")
                                        border.width: 1; radius: 1

                                        Behavior on anchors.leftMargin { NumberAnimation { duration: 55; easing.type: Easing.OutQuad } }
                                        Behavior on anchors.topMargin { NumberAnimation { duration: 55; easing.type: Easing.OutQuad } }
                                        Behavior on anchors.rightMargin { NumberAnimation { duration: 55; easing.type: Easing.OutQuad } }
                                        Behavior on anchors.bottomMargin { NumberAnimation { duration: 55; easing.type: Easing.OutQuad } }

                                        Rectangle {
                                            anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 1
                                            height: 1; color: parent.parent.active ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(1, 1, 1, 0.12)
                                        }

                                        RowLayout {
                                            anchors.fill: parent; anchors.margins: Math.round(4 * scaleFactor); spacing: Math.round(4 * scaleFactor)
                                            Text { text: parent.parent.parent.active ? "■" : "•"; color: parent.parent.parent.active ? parent.parent.parent.accentColor : "#64748b"; font { family: hudWindow.monoFont; pixelSize: Math.round(9.5 * scaleFactor); bold: true } }
                                            ColumnLayout {
                                                Layout.fillWidth: true; spacing: 0
                                                Text { text: "WLAN"; color: parent.parent.parent.parent.active ? "#ffffff" : "#cbd5e1"; font { family: hudWindow.monoFont; pixelSize: Math.round(9.5 * scaleFactor); bold: true } }
                                                Text { text: parent.parent.parent.parent.active ? "ONLINE" : "OFF"; color: parent.parent.parent.parent.active ? parent.parent.parent.parent.accentColor : "#64748b"; font { family: hudWindow.monoFont; pixelSize: Math.round(8.5 * scaleFactor); bold: true } }
                                            }
                                        }
                                    }
                                    MouseArea {
                                        id: wlanBtnMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onClicked: hudWindow.toggleWifiOverlay()
                                    }
                                }

                                // ── 8. BLUETOOTH OVERLAY ──────────────────────
                                Item {
                                    Layout.fillWidth: true; Layout.fillHeight: true
                                    readonly property bool active: hudWindow.showBtOverlay || (shellRoot && shellRoot.bluetoothActive)
                                    readonly property color accentColor: "#BF5AF2"
                                    readonly property color activeBg: "#1e0e2b"
                                    readonly property color activeShadow: "#381650"

                                    Rectangle {
                                        anchors.fill: parent
                                        anchors.leftMargin: Math.round(2 * scaleFactor)
                                        anchors.topMargin: Math.round(2 * scaleFactor)
                                        color: parent.active ? parent.activeShadow : (btBtnMa.containsMouse ? "#28374a" : "#182332")
                                        border.color: parent.active ? parent.accentColor : (btBtnMa.containsMouse ? "#ffffff" : Qt.rgba(1, 1, 1, 0.60))
                                        border.width: 1
                                        radius: 1
                                    }

                                    Rectangle {
                                        id: btBtnFront
                                        z: 2
                                        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.bottom: parent.bottom
                                        anchors.leftMargin: (btBtnMa.pressed || parent.active) ? Math.round(2 * scaleFactor) : 0
                                        anchors.topMargin: (btBtnMa.pressed || parent.active) ? Math.round(2 * scaleFactor) : (btBtnMa.containsMouse ? -Math.round(1 * scaleFactor) : 0)
                                        anchors.rightMargin: (btBtnMa.pressed || parent.active) ? 0 : Math.round(2 * scaleFactor)
                                        anchors.bottomMargin: (btBtnMa.pressed || parent.active) ? 0 : (btBtnMa.containsMouse ? Math.round(3 * scaleFactor) : Math.round(2 * scaleFactor))

                                        color: parent.active ? parent.activeBg : (btBtnMa.containsMouse ? "#141e2c" : "#0d141e")
                                        border.color: parent.active ? parent.accentColor : (btBtnMa.containsMouse ? "#64D2FF" : "#2a394e")
                                        border.width: 1; radius: 1

                                        Behavior on anchors.leftMargin { NumberAnimation { duration: 55; easing.type: Easing.OutQuad } }
                                        Behavior on anchors.topMargin { NumberAnimation { duration: 55; easing.type: Easing.OutQuad } }
                                        Behavior on anchors.rightMargin { NumberAnimation { duration: 55; easing.type: Easing.OutQuad } }
                                        Behavior on anchors.bottomMargin { NumberAnimation { duration: 55; easing.type: Easing.OutQuad } }

                                        Rectangle {
                                            anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 1
                                            height: 1; color: parent.parent.active ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(1, 1, 1, 0.12)
                                        }

                                        RowLayout {
                                            anchors.fill: parent; anchors.margins: Math.round(4 * scaleFactor); spacing: Math.round(4 * scaleFactor)
                                            Text { text: parent.parent.parent.active ? "■" : "•"; color: parent.parent.parent.active ? parent.parent.parent.accentColor : "#64748b"; font { family: hudWindow.monoFont; pixelSize: Math.round(9.5 * scaleFactor); bold: true } }
                                            ColumnLayout {
                                                Layout.fillWidth: true; spacing: 0
                                                Text { text: "BLTH"; color: parent.parent.parent.parent.active ? "#ffffff" : "#cbd5e1"; font { family: hudWindow.monoFont; pixelSize: Math.round(9.5 * scaleFactor); bold: true } }
                                                Text { text: parent.parent.parent.parent.active ? "ON" : "OFF"; color: parent.parent.parent.parent.active ? parent.parent.parent.parent.accentColor : "#64748b"; font { family: hudWindow.monoFont; pixelSize: Math.round(8.5 * scaleFactor); bold: true } }
                                            }
                                        }
                                    }
                                    MouseArea {
                                        id: btBtnMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onClicked: hudWindow.toggleBtOverlay()
                                    }
                                }

                                // ── 9. POWER PROFILE ──────────────────────────
                                Item {
                                    Layout.fillWidth: true; Layout.fillHeight: true
                                    readonly property string prof: shellRoot ? (shellRoot.powerProfile || "balanced") : "balanced"
                                    readonly property string profShort: prof.toLowerCase().indexOf("perf") >= 0 ? "PERF" : (prof.toLowerCase().indexOf("sav") >= 0 ? "SAVE" : "BAL")
                                    readonly property bool active: true
                                    readonly property color accentColor: prof.toLowerCase().indexOf("perf") >= 0 ? "#FF453A" : (prof.toLowerCase().indexOf("sav") >= 0 ? "#30D158" : "#BF5AF2")
                                    readonly property color activeBg: prof.toLowerCase().indexOf("perf") >= 0 ? "#260e0e" : (prof.toLowerCase().indexOf("sav") >= 0 ? "#0c2414" : "#1e0f2b")
                                    readonly property color activeShadow: prof.toLowerCase().indexOf("perf") >= 0 ? "#451616" : (prof.toLowerCase().indexOf("sav") >= 0 ? "#143a20" : "#3b1654")

                                    Rectangle {
                                        anchors.fill: parent
                                        anchors.leftMargin: Math.round(2 * scaleFactor)
                                        anchors.topMargin: Math.round(2 * scaleFactor)
                                        color: parent.activeShadow
                                        border.color: pwrBtnMa.containsMouse ? "#ffffff" : parent.accentColor
                                        border.width: 1
                                        radius: 1
                                    }

                                    Rectangle {
                                        id: pwrBtnFront
                                        z: 2
                                        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.bottom: parent.bottom
                                        anchors.leftMargin: pwrBtnMa.pressed ? Math.round(2 * scaleFactor) : 0
                                        anchors.topMargin: pwrBtnMa.pressed ? Math.round(2 * scaleFactor) : (pwrBtnMa.containsMouse ? -Math.round(1 * scaleFactor) : 0)
                                        anchors.rightMargin: pwrBtnMa.pressed ? 0 : Math.round(2 * scaleFactor)
                                        anchors.bottomMargin: pwrBtnMa.pressed ? 0 : (pwrBtnMa.containsMouse ? Math.round(3 * scaleFactor) : Math.round(2 * scaleFactor))

                                        color: parent.activeBg
                                        border.color: pwrBtnMa.containsMouse ? "#ffffff" : parent.accentColor
                                        border.width: 1; radius: 1

                                        Behavior on anchors.leftMargin { NumberAnimation { duration: 55; easing.type: Easing.OutQuad } }
                                        Behavior on anchors.topMargin { NumberAnimation { duration: 55; easing.type: Easing.OutQuad } }
                                        Behavior on anchors.rightMargin { NumberAnimation { duration: 55; easing.type: Easing.OutQuad } }
                                        Behavior on anchors.bottomMargin { NumberAnimation { duration: 55; easing.type: Easing.OutQuad } }

                                        Rectangle {
                                            anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 1
                                            height: 1; color: Qt.rgba(1, 1, 1, 0.35)
                                        }

                                        RowLayout {
                                            anchors.fill: parent; anchors.margins: Math.round(4 * scaleFactor); spacing: Math.round(4 * scaleFactor)
                                            Text { text: "■"; color: parent.parent.parent.accentColor; font { family: hudWindow.monoFont; pixelSize: Math.round(9.5 * scaleFactor); bold: true } }
                                            ColumnLayout {
                                                Layout.fillWidth: true; spacing: 0
                                                Text { text: "PWR"; color: "#ffffff"; font { family: hudWindow.monoFont; pixelSize: Math.round(9.5 * scaleFactor); bold: true } }
                                                Text { text: parent.parent.parent.parent.profShort; color: "#ffffff"; font { family: hudWindow.monoFont; pixelSize: Math.round(8.5 * scaleFactor); bold: true } }
                                            }
                                        }
                                    }
                                    MouseArea {
                                        id: pwrBtnMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (shellRoot) {
                                                var cur = (shellRoot.powerProfile || "balanced").toLowerCase();
                                                var next = cur === "balanced" ? "performance" : (cur === "performance" ? "power-saver" : "balanced");
                                                shellRoot.powerProfile = next;
                                                if (shellRoot.pCyclePowerProfile) shellRoot.pCyclePowerProfile.running = true;
                                            }
                                        }
                                    }
                                }

                                // ── 10. SETTINGS ──────────────────────────────
                                Item {
                                    Layout.fillWidth: true; Layout.fillHeight: true
                                    readonly property bool active: shellRoot && shellRoot.settingsWindow && shellRoot.settingsWindow.visible
                                    readonly property color accentColor: "#64D2FF"
                                    readonly property color activeBg: "#0c1b26"
                                    readonly property color activeShadow: "#142e42"

                                    Rectangle {
                                        anchors.fill: parent
                                        anchors.leftMargin: Math.round(2 * scaleFactor)
                                        anchors.topMargin: Math.round(2 * scaleFactor)
                                        color: parent.active ? parent.activeShadow : (settingsBtnMa.containsMouse ? "#28374a" : "#182332")
                                        border.color: parent.active ? parent.accentColor : (settingsBtnMa.containsMouse ? "#ffffff" : Qt.rgba(1, 1, 1, 0.60))
                                        border.width: 1
                                        radius: 1
                                    }

                                    Rectangle {
                                        id: settingsBtnFront
                                        z: 2
                                        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.bottom: parent.bottom
                                        anchors.leftMargin: (settingsBtnMa.pressed || parent.active) ? Math.round(2 * scaleFactor) : 0
                                        anchors.topMargin: (settingsBtnMa.pressed || parent.active) ? Math.round(2 * scaleFactor) : (settingsBtnMa.containsMouse ? -Math.round(1 * scaleFactor) : 0)
                                        anchors.rightMargin: (settingsBtnMa.pressed || parent.active) ? 0 : Math.round(2 * scaleFactor)
                                        anchors.bottomMargin: (settingsBtnMa.pressed || parent.active) ? 0 : (settingsBtnMa.containsMouse ? Math.round(3 * scaleFactor) : Math.round(2 * scaleFactor))

                                        color: parent.active ? parent.activeBg : (settingsBtnMa.containsMouse ? "#141e2c" : "#0d141e")
                                        border.color: parent.active ? parent.accentColor : (settingsBtnMa.containsMouse ? "#64D2FF" : "#2a394e")
                                        border.width: 1; radius: 1

                                        Behavior on anchors.leftMargin { NumberAnimation { duration: 55; easing.type: Easing.OutQuad } }
                                        Behavior on anchors.topMargin { NumberAnimation { duration: 55; easing.type: Easing.OutQuad } }
                                        Behavior on anchors.rightMargin { NumberAnimation { duration: 55; easing.type: Easing.OutQuad } }
                                        Behavior on anchors.bottomMargin { NumberAnimation { duration: 55; easing.type: Easing.OutQuad } }

                                        Rectangle {
                                            anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 1
                                            height: 1; color: parent.parent.active ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(1, 1, 1, 0.12)
                                        }

                                        RowLayout {
                                            anchors.fill: parent; anchors.margins: Math.round(4 * scaleFactor); spacing: Math.round(4 * scaleFactor)
                                            Text { text: parent.parent.parent.active ? "■" : "•"; color: parent.parent.parent.active ? parent.parent.parent.accentColor : "#64748b"; font { family: hudWindow.monoFont; pixelSize: Math.round(9.5 * scaleFactor); bold: true } }
                                            ColumnLayout {
                                                Layout.fillWidth: true; spacing: 0
                                                Text { text: "SETTINGS"; color: parent.parent.parent.parent.active ? "#ffffff" : "#cbd5e1"; font { family: hudWindow.monoFont; pixelSize: Math.round(9.5 * scaleFactor); bold: true } }
                                                Text { text: "[C] PREFS"; color: parent.parent.parent.parent.active ? parent.parent.parent.parent.accentColor : "#64748b"; font { family: hudWindow.monoFont; pixelSize: Math.round(8.5 * scaleFactor); bold: true } }
                                            }
                                        }
                                    }
                                    MouseArea {
                                        id: settingsBtnMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (shellRoot && shellRoot.settingsWindow) {
                                                shellRoot.settingsWindow.visible = !shellRoot.settingsWindow.visible;
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                // ── PANE 2C: WEATHER RADAR, FORMULA 1 PADDOCK & EMAIL INBOX (~215px) ──────
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.round(215 * scaleFactor)
                    color: "#000000"
                    border.color: "#181d26"
                    border.width: 1

                    // Main 3-Panel Horizontal Split
                    RowLayout {
                        anchors.fill: parent
                        spacing: 0
                        visible: !hudWindow.showF1Overlay && !hudWindow.showEmailOverlay

                        // 1. Weather Sub-Panel (32% width - IITK Fog Lab & Open-Meteo Ground AWS)
                        Rectangle {
                            Layout.preferredWidth: Math.round(parent.width * 0.32)
                            Layout.fillHeight: true
                            color: "transparent"
                            border.color: "#181d26"
                            border.width: 1

                            readonly property var wData: (hudWindow.hudData && hudWindow.hudData.weather) ? hudWindow.hudData.weather : null

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: Math.round(8 * scaleFactor)
                                spacing: Math.round(3 * scaleFactor)

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: Math.round(6 * scaleFactor)
                                    Text {
                                        text: "┌─ [06] IITK WEATHER"
                                        color: "#64D2FF"
                                        font { family: hudWindow.monoFont; pixelSize: Math.round(10.5 * scaleFactor); bold: true }
                                    }
                                    Rectangle { Layout.fillWidth: true; height: 1; color: "#212836"; Layout.alignment: Qt.AlignVCenter }
                                    Text {
                                        text: (parent.parent.wData && parent.parent.wData.is_ground_live) ? "[FOG LAB: LIVE]" : "[CAMPUS AWS]"
                                        color: (parent.parent.wData && parent.parent.wData.is_ground_live) ? "#30D158" : "#64748b"
                                        font { family: hudWindow.monoFont; pixelSize: Math.round(8 * scaleFactor); bold: true }
                                    }
                                }

                                Text {
                                    text: "IIT KANPUR 26.51°N 80.23°E"
                                    color: Qt.rgba(1, 1, 1, 0.45)
                                    font { family: hudWindow.monoFont; pixelSize: Math.round(8.5 * scaleFactor); features: { "tnum": 1 } }
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                RowLayout {
                                    spacing: Math.round(8 * scaleFactor)
                                    Text {
                                        text: (parent.parent.wData ? parent.parent.wData.icon : "󰖙") + " " + (parent.parent.wData ? (parent.parent.wData.temp + "°C") : (shellRoot && shellRoot.weatherText ? shellRoot.weatherText : "28°C"))
                                        color: "#ffffff"
                                        font { family: hudWindow.monoFont; pixelSize: Math.round(14 * scaleFactor); bold: true; features: { "tnum": 1 } }
                                    }
                                    Text {
                                        text: parent.parent.wData ? parent.parent.wData.condition : "CLEAR SKY"
                                        color: parent.parent.wData ? parent.parent.wData.color : "#64D2FF"
                                        font { family: hudWindow.monoFont; pixelSize: Math.round(10 * scaleFactor); bold: true }
                                    }
                                    Item { Layout.fillWidth: true }
                                    Text {
                                        text: (parent.parent.wData ? parent.parent.wData.pressure : 1014) + " hPa"
                                        color: "#30D158"
                                        font { family: hudWindow.monoFont; pixelSize: Math.round(9.5 * scaleFactor); bold: true; features: { "tnum": 1 } }
                                    }
                                }

                                Text {
                                    text: "FEELS: " + (parent.parent.wData ? (parent.parent.wData.feels_like + "°C") : "29°C") + " │ HUM: " + (parent.parent.wData ? (parent.parent.wData.humidity + "%") : "45%") + " │ WIND: " + (parent.parent.wData ? (parent.parent.wData.wind_speed + " km/h") : "6 km/h")
                                    color: Qt.rgba(1, 1, 1, 0.6)
                                    font { family: hudWindow.monoFont; pixelSize: Math.round(9 * scaleFactor); features: { "tnum": 1 } }
                                }

                                Text {
                                    text: "VIS: " + (parent.parent.wData ? (parent.parent.wData.visibility + "m") : "5000m") + " │ DEW: " + (parent.parent.wData ? (parent.parent.wData.dew_point + "°C") : "14°C") + " │ RANGE: " + (parent.parent.wData ? (parent.parent.wData.t_min + "° / " + parent.parent.wData.t_max + "°C") : "18° / 31°C")
                                    color: Qt.rgba(1, 1, 1, 0.45)
                                    font { family: hudWindow.monoFont; pixelSize: Math.round(8.5 * scaleFactor); features: { "tnum": 1 } }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    Text {
                                        text: "HOURLY:"
                                        color: "#555566"
                                        font { family: hudWindow.monoFont; pixelSize: Math.round(9 * scaleFactor); bold: true }
                                    }
                                    Text {
                                        text: " ▂▃▅▆▇▆▅▃ "
                                        color: "#FF9F0A"
                                        font { family: hudWindow.monoFont; pixelSize: Math.round(9.5 * scaleFactor) }
                                    }
                                    Item { Layout.fillWidth: true }
                                    Text {
                                        text: (parent.parent.wData ? parent.parent.wData.timestamp : "LIVE") + " SYNC"
                                        color: Qt.rgba(1, 1, 1, 0.35)
                                        font { family: hudWindow.monoFont; pixelSize: Math.round(8.5 * scaleFactor); features: { "tnum": 1 } }
                                    }
                                }
                            }
                        }

                        // 2. F1 Paddock Sub-Panel (34% width - Click opens In-Card 4-Week Calendar Overlay)
                        Rectangle {
                            id: interactiveF1Area
                            Layout.preferredWidth: Math.round(parent.width * 0.34)
                            Layout.fillHeight: true
                            color: "transparent"
                            border.color: "#181d26"
                            border.width: 1

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: Math.round(8 * scaleFactor)
                                spacing: Math.round(3 * scaleFactor)

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: Math.round(4 * scaleFactor)
                                    Text {
                                        text: "┌─ [07] F1 PADDOCK"
                                        color: "#FF453A"
                                        font { family: hudWindow.monoFont; pixelSize: Math.round(10.5 * scaleFactor); bold: true }
                                    }
                                    Rectangle {
                                        Layout.fillWidth: true
                                        height: 1
                                        color: "#212836"
                                        Layout.alignment: Qt.AlignVCenter
                                    }
                                    Rectangle {
                                        width: Math.round(52 * scaleFactor)
                                        height: Math.round(16 * scaleFactor)
                                        color: "#250d0d"
                                        border.color: "#FF453A"
                                        border.width: 1
                                        radius: 2
                                        Text {
                                            anchors.centerIn: parent
                                            text: "󰄉 4-WK"
                                            color: "#FF453A"
                                            font { family: hudWindow.monoFont; pixelSize: Math.round(9.5 * scaleFactor); bold: true }
                                        }
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    Text {
                                        text: (hudWindow.hudData && hudWindow.hudData.f1) ? hudWindow.hudData.f1.race_name : "BRAZILIAN GP"
                                        color: "#ffffff"
                                        font { family: hudWindow.monoFont; pixelSize: Math.round(10.5 * scaleFactor); bold: true }
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                }

                                Text {
                                    text: "CIRCUIT: " + ((hudWindow.hudData && hudWindow.hudData.f1) ? hudWindow.hudData.f1.location : "Sao Paulo") + " │ TIRES: S/M/H"
                                    color: Qt.rgba(1, 1, 1, 0.45)
                                    font { family: hudWindow.monoFont; pixelSize: Math.round(9.5 * scaleFactor) }
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                Text {
                                    text: "NEXT ROUND: 🇺🇸 Las Vegas GP (Nov 22)"
                                    color: Qt.rgba(1, 1, 1, 0.35)
                                    font { family: hudWindow.monoFont; pixelSize: Math.round(8.5 * scaleFactor) }
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    height: Math.round(22 * scaleFactor)
                                    color: "#080c14"
                                    border.color: "#FF453A"
                                    border.width: 1

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: Math.round(3 * scaleFactor)
                                        Text {
                                            text: "COUNTDOWN:"
                                            color: Qt.rgba(1, 1, 1, 0.45)
                                            font { family: hudWindow.monoFont; pixelSize: Math.round(9 * scaleFactor) }
                                        }
                                        Item { Layout.fillWidth: true }
                                        Text {
                                            text: "[ " + ((hudWindow.hudData && hudWindow.hudData.f1) ? hudWindow.hudData.f1.countdown : "--") + " ]"
                                            color: "#FF453A"
                                            font { family: hudWindow.monoFont; pixelSize: Math.round(10 * scaleFactor); bold: true; features: { "tnum": 1 } }
                                        }
                                    }
                                }

                                Text {
                                    text: "CLICK TO OPEN 4-WEEK CALENDAR OVERLAY"
                                    color: "#FF453A"
                                    opacity: 0.6
                                    font { family: hudWindow.monoFont; pixelSize: Math.round(9 * scaleFactor); bold: true }
                                    Layout.alignment: Qt.AlignHCenter
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: hudWindow.toggleF1Overlay()
                            }
                        }

                        // 3. Email Suite Sub-Panel (34% width - Click opens In-Card Email Overlay)
                        Rectangle {
                            id: interactiveEmailArea
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            color: "transparent"
                            border.color: "#181d26"
                            border.width: 1

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: Math.round(8 * scaleFactor)
                                spacing: Math.round(3 * scaleFactor)

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: Math.round(4 * scaleFactor)
                                    Text {
                                        text: "┌─ [08] EMAIL INBOX"
                                        color: "#0A84FF"
                                        font { family: hudWindow.monoFont; pixelSize: Math.round(10.5 * scaleFactor); bold: true }
                                    }
                                    Rectangle {
                                        Layout.fillWidth: true
                                        height: 1
                                        color: "#212836"
                                        Layout.alignment: Qt.AlignVCenter
                                    }
                                    Rectangle {
                                        width: Math.round(52 * scaleFactor)
                                        height: Math.round(16 * scaleFactor)
                                        color: "#0c1b2c"
                                        border.color: "#0A84FF"
                                        border.width: 1
                                        radius: 2
                                        Text {
                                            anchors.centerIn: parent
                                            text: "󰇮 RECENT"
                                            color: "#0A84FF"
                                            font { family: hudWindow.monoFont; pixelSize: Math.round(9.5 * scaleFactor); bold: true }
                                        }
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    Text {
                                        text: "TODAY: " + (shellRoot ? shellRoot.todayEmailsCount : 0) + " EMAILS"
                                        color: "#ffffff"
                                        font { family: hudWindow.monoFont; pixelSize: Math.round(10.5 * scaleFactor); bold: true }
                                    }
                                    Item { Layout.fillWidth: true }
                                    Text {
                                        text: "1-HR: " + (shellRoot ? shellRoot.hourEmailsCount : 0)
                                        color: (shellRoot && shellRoot.hourEmailsCount > 0) ? "#30D158" : Qt.rgba(1, 1, 1, 0.45)
                                        font { family: hudWindow.monoFont; pixelSize: Math.round(9.5 * scaleFactor); bold: true }
                                    }
                                }

                                // Message 1
                                Text {
                                    Layout.fillWidth: true
                                    text: {
                                        if (!shellRoot || !shellRoot.latestEmails || shellRoot.latestEmails.length === 0) return "No unread messages // Inbox clear";
                                        var m0 = shellRoot.latestEmails[0];
                                        var s0 = m0.from || m0.sender || "Mail";
                                        return s0 + ": " + (m0.subject || "");
                                    }
                                    color: (shellRoot && shellRoot.latestEmails && shellRoot.latestEmails.length > 0) ? "#64D2FF" : Qt.rgba(1, 1, 1, 0.4)
                                    font { family: hudWindow.monoFont; pixelSize: Math.round(9.5 * scaleFactor) }
                                    elide: Text.ElideRight
                                }

                                // Message 2
                                Text {
                                    Layout.fillWidth: true
                                    visible: shellRoot && shellRoot.latestEmails && shellRoot.latestEmails.length > 1
                                    text: {
                                        if (!shellRoot || !shellRoot.latestEmails || shellRoot.latestEmails.length < 2) return "";
                                        var m1 = shellRoot.latestEmails[1];
                                        var s1 = m1.from || m1.sender || "Mail";
                                        return s1 + ": " + (m1.subject || "");
                                    }
                                    color: Qt.rgba(1, 1, 1, 0.45)
                                    font { family: hudWindow.monoFont; pixelSize: Math.round(9 * scaleFactor) }
                                    elide: Text.ElideRight
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    height: Math.round(22 * scaleFactor)
                                    color: "#080c14"
                                    border.color: "#0A84FF"
                                    border.width: 1

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: Math.round(3 * scaleFactor)
                                        Text {
                                            text: "INBOX TELEMETRY:"
                                            color: Qt.rgba(1, 1, 1, 0.45)
                                            font { family: hudWindow.monoFont; pixelSize: Math.round(9 * scaleFactor) }
                                        }
                                        Item { Layout.fillWidth: true }
                                        Text {
                                            text: "[ VIEW RECENT EMAILS ]"
                                            color: "#0A84FF"
                                            font { family: hudWindow.monoFont; pixelSize: Math.round(9.5 * scaleFactor); bold: true }
                                        }
                                    }
                                }

                                Text {
                                    text: "CLICK TO OPEN INBOX OVERLAY"
                                    color: "#0A84FF"
                                    opacity: 0.6
                                    font { family: hudWindow.monoFont; pixelSize: Math.round(9 * scaleFactor); bold: true }
                                    Layout.alignment: Qt.AlignHCenter
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: hudWindow.toggleEmailOverlay()
                            }
                        }
                    }

                    // ── In-Card / Overlay: Full F1 4-Week Schedule ────────────
                    Rectangle {
                        id: f1OverlayArea
                        anchors.fill: parent
                        z: 50
                        visible: hudWindow.showF1Overlay
                        color: "#04060a"
                        border.color: "#FF453A"
                        border.width: 1

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: Math.round(10 * scaleFactor)
                            spacing: Math.round(6 * scaleFactor)

                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    text: "┌─ [07] F1 SCHEDULE"
                                    color: "#FF453A"
                                    font { family: hudWindow.monoFont; pixelSize: Math.round(11 * scaleFactor); bold: true }
                                }
                                Item { Layout.fillWidth: true }
                                Rectangle {
                                    width: Math.round(64 * scaleFactor)
                                    height: Math.round(20 * scaleFactor)
                                    color: "#250d0d"
                                    border.color: "#FF453A"
                                    border.width: 1
                                    radius: 2
                                    Text {
                                        anchors.centerIn: parent
                                        text: "✕ CLOSE"
                                        color: "#FF453A"
                                        font { family: hudWindow.monoFont; pixelSize: Math.round(9.5 * scaleFactor); bold: true }
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: hudWindow.showF1Overlay = false
                                    }
                                }
                            }

                            ListView {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                clip: true
                                model: f1CalendarModel
                                spacing: Math.round(4 * scaleFactor)

                                delegate: Rectangle {
                                    width: parent ? parent.width : 0
                                    height: Math.round(22 * scaleFactor)
                                    color: index % 2 === 0 ? "#080c14" : "#04060a"
                                    border.color: "#182030"
                                    border.width: 1

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: Math.round(8 * scaleFactor)
                                        anchors.rightMargin: Math.round(8 * scaleFactor)
                                        spacing: Math.round(10 * scaleFactor)

                                        Text {
                                            text: model.event || ""
                                            color: "#ffffff"
                                            font { family: hudWindow.monoFont; pixelSize: Math.round(9.5 * scaleFactor); bold: true }
                                            elide: Text.ElideRight
                                            Layout.preferredWidth: Math.round(260 * scaleFactor)
                                        }
                                        Text {
                                            text: model.location || ""
                                            color: "#FF9F0A"
                                            font { family: hudWindow.monoFont; pixelSize: Math.round(9 * scaleFactor) }
                                            elide: Text.ElideRight
                                            Layout.preferredWidth: Math.round(110 * scaleFactor)
                                        }
                                        Item { Layout.fillWidth: true }
                                        Text {
                                            text: model.timeStr || ""
                                            color: "#64D2FF"
                                            font { family: hudWindow.monoFont; pixelSize: Math.round(9.5 * scaleFactor); bold: true; features: { "tnum": 1 } }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ── In-Card / Overlay: Full Recent Emails List ─────────────
                    Rectangle {
                        id: emailOverlayArea
                        anchors.fill: parent
                        z: 50
                        visible: hudWindow.showEmailOverlay
                        color: "#04060a"
                        border.color: "#0A84FF"
                        border.width: 1

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: Math.round(10 * scaleFactor)
                            spacing: Math.round(6 * scaleFactor)

                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    text: "┌─ [08] EMAIL INBOX"
                                    color: "#0A84FF"
                                    font { family: hudWindow.monoFont; pixelSize: Math.round(11 * scaleFactor); bold: true }
                                }
                                Item { Layout.fillWidth: true }
                                Rectangle {
                                    width: Math.round(64 * scaleFactor)
                                    height: Math.round(20 * scaleFactor)
                                    color: "#0c1b2c"
                                    border.color: "#0A84FF"
                                    border.width: 1
                                    radius: 2
                                    Text {
                                        anchors.centerIn: parent
                                        text: "✕ CLOSE"
                                        color: "#0A84FF"
                                        font { family: hudWindow.monoFont; pixelSize: Math.round(9.5 * scaleFactor); bold: true }
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: hudWindow.showEmailOverlay = false
                                    }
                                }
                            }

                            ListView {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                clip: true
                                model: (shellRoot && shellRoot.latestEmails) ? shellRoot.latestEmails : []
                                spacing: Math.round(4 * scaleFactor)

                                delegate: Rectangle {
                                    width: parent ? parent.width : 0
                                    height: Math.round(24 * scaleFactor)
                                    color: index % 2 === 0 ? "#080c14" : "#04060a"
                                    border.color: "#182030"
                                    border.width: 1

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: Math.round(8 * scaleFactor)
                                        anchors.rightMargin: Math.round(8 * scaleFactor)
                                        spacing: Math.round(10 * scaleFactor)

                                        Text {
                                            text: modelData.from || modelData.sender || "Mail"
                                            color: "#64D2FF"
                                            font { family: hudWindow.monoFont; pixelSize: Math.round(9.5 * scaleFactor); bold: true }
                                            elide: Text.ElideRight
                                            Layout.preferredWidth: Math.round(160 * scaleFactor)
                                        }
                                        Text {
                                            text: modelData.subject || "No Subject"
                                            color: "#ffffff"
                                            font { family: hudWindow.monoFont; pixelSize: Math.round(9.5 * scaleFactor) }
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }
                                        Text {
                                            text: modelData.date || ""
                                            color: Qt.rgba(1, 1, 1, 0.45)
                                            font { family: hudWindow.monoFont; pixelSize: Math.round(9 * scaleFactor); features: { "tnum": 1 } }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ── PANE 2D: DISPATCH MATRIX // TODOIST & POMODORO CADENCE (fill remaining space) ─────
                Rectangle {
                    id: card09Root
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: "#000000"
                    border.color: "#181d26"
                    border.width: 1

                    property string boundTaskId: "TK-01"

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Math.round(8 * scaleFactor)
                        spacing: Math.round(5 * scaleFactor)

                        // ── Header Rail ──────────────────────────────────────
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Math.round(6 * scaleFactor)
                            Text {
                                text: "┌─ [09] TASKS & POMODORO"
                                color: "#FF9F0A"
                                font { family: hudWindow.monoFont; pixelSize: Math.round(10.5 * scaleFactor); bold: true }
                            }
                            Rectangle {
                                Layout.fillWidth: true
                                height: 1
                                color: "#212836"
                                Layout.alignment: Qt.AlignVCenter
                            }

                            Rectangle {
                                width: Math.round(92 * scaleFactor)
                                height: Math.round(16 * scaleFactor)
                                color: (shellRoot && shellRoot.pomodoroActive && shellRoot.pomodoroRunning) ? "#201008" : "#0d131d"
                                border.color: (shellRoot && shellRoot.pomodoroActive && shellRoot.pomodoroRunning) ? "#FF5F15" : "#38BDF8"
                                border.width: 1
                                radius: 2

                                Text {
                                    anchors.centerIn: parent
                                    text: (shellRoot && shellRoot.pomodoroActive && shellRoot.pomodoroRunning)
                                        ? ((shellRoot.pomodoroMode === "focus") ? "SPRINT ACTIVE" : "REST BREAK")
                                        : "ENGINE: IDLE"
                                    font { family: hudWindow.monoFont; pixelSize: Math.round(9 * scaleFactor); bold: true }
                                    color: (shellRoot && shellRoot.pomodoroActive && shellRoot.pomodoroRunning) ? "#FF5F15" : "#38BDF8"
                                }
                            }
                        }

                        // ── Pomodoro Interval Command Deck (Teenage Engineering Hardware Clock) ─
                        Rectangle {
                            id: pomoDeckArea
                            Layout.fillWidth: true
                            height: Math.round(36 * scaleFactor)
                            color: "#0a0d14"
                            border.color: "#1a2433"
                            border.width: 1
                            radius: 2

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: Math.round(5 * scaleFactor)
                                spacing: Math.round(8 * scaleFactor)

                                // Hardware Latch Start/Pause Button
                                Rectangle {
                                    Layout.preferredWidth: Math.round(50 * scaleFactor)
                                    Layout.fillHeight: true
                                    color: pomoLatchMa.pressed
                                        ? "#1e2c3d"
                                        : ((shellRoot && shellRoot.pomodoroActive && shellRoot.pomodoroRunning) ? "#FF5F15" : "#121924")
                                    border.color: (shellRoot && shellRoot.pomodoroActive && shellRoot.pomodoroRunning) ? "#FFA040" : "#243244"
                                    border.width: 1
                                    radius: 2

                                    Text {
                                        anchors.centerIn: parent
                                        text: (shellRoot && shellRoot.pomodoroActive && shellRoot.pomodoroRunning) ? "PAUSE" : "START"
                                        font { family: hudWindow.monoFont; pixelSize: Math.round(9.5 * scaleFactor); bold: true }
                                        color: (shellRoot && shellRoot.pomodoroActive && shellRoot.pomodoroRunning) ? "#000000" : "#ffffff"
                                    }

                                    MouseArea {
                                        id: pomoLatchMa
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (shellRoot && shellRoot.togglePomodoro) shellRoot.togglePomodoro();
                                        }
                                    }
                                }

                                // Skip Rest Button
                                Rectangle {
                                    Layout.preferredWidth: Math.round(38 * scaleFactor)
                                    Layout.fillHeight: true
                                    color: skipMa.pressed ? "#1e2c3d" : "#0d131d"
                                    border.color: skipMa.containsMouse ? "#64D2FF" : "#1a2433"
                                    border.width: 1
                                    radius: 2

                                    Text {
                                        anchors.centerIn: parent
                                        text: "SKIP"
                                        font { family: hudWindow.monoFont; pixelSize: Math.round(9 * scaleFactor); bold: true }
                                        color: skipMa.containsMouse ? "#64D2FF" : Qt.rgba(1, 1, 1, 0.45)
                                    }

                                    MouseArea {
                                        id: skipMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (shellRoot && shellRoot.skipPomodoro) shellRoot.skipPomodoro();
                                        }
                                    }
                                }

                                // Reset Button
                                Rectangle {
                                    Layout.preferredWidth: Math.round(44 * scaleFactor)
                                    Layout.fillHeight: true
                                    color: resetMa.pressed ? "#3b1515" : "#0d131d"
                                    border.color: resetMa.containsMouse ? "#FF453A" : "#1a2433"
                                    border.width: 1
                                    radius: 2

                                    Text {
                                        anchors.centerIn: parent
                                        text: "RESET"
                                        font { family: hudWindow.monoFont; pixelSize: Math.round(9 * scaleFactor); bold: true }
                                        color: resetMa.containsMouse ? "#FF453A" : Qt.rgba(1, 1, 1, 0.45)
                                    }

                                    MouseArea {
                                        id: resetMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (shellRoot && shellRoot.resetPomodoro) shellRoot.resetPomodoro();
                                        }
                                    }
                                }

                                // Digital Timer Counter
                                Text {
                                    text: (shellRoot && shellRoot.pomodoroActive) ? shellRoot.pomodoroTimeStr : "25:00"
                                    font { family: hudWindow.monoFont; pixelSize: Math.round(14 * scaleFactor); bold: true; features: { "tnum": 1 } }
                                    color: (shellRoot && shellRoot.pomodoroActive && shellRoot.pomodoroRunning) ? "#FF5F15" : "#ffffff"
                                }

                                // 25-Segment Progress Track
                                RowLayout {
                                    Layout.fillWidth: true
                                    height: Math.round(6 * scaleFactor)
                                    spacing: 2

                                    readonly property real progressPct: {
                                        if (!shellRoot || !shellRoot.pomodoroActive) return 0.0;
                                        var total = shellRoot.pomodoroTotalSeconds || 1500;
                                        var sec = shellRoot.pomodoroSeconds || 0;
                                        return Math.max(0.0, Math.min(1.0, 1.0 - (sec / total)));
                                    }

                                    Repeater {
                                        model: 24
                                        Rectangle {
                                            Layout.fillWidth: true
                                            height: Math.round(5 * scaleFactor)
                                            radius: 1
                                            readonly property bool isLit: index < Math.round(parent.progressPct * 24)
                                            color: isLit ? "#FF5F15" : "#141c28"
                                        }
                                    }
                                }

                                // 4-Pip Session Counter (Teenage Engineering Jeweled Beads)
                                RowLayout {
                                    spacing: 3
                                    Repeater {
                                        model: 4
                                        Rectangle {
                                            width: Math.round(7 * scaleFactor)
                                            height: Math.round(7 * scaleFactor)
                                            radius: width / 2
                                            readonly property int curCycle: (shellRoot ? shellRoot.pomodoroSession : 1) - 1
                                            color: index < curCycle ? "#00E5FF" : (index === curCycle && shellRoot && shellRoot.pomodoroActive ? "#FF5F15" : "#121822")
                                            border.color: index < curCycle ? "#38BDF8" : "#243244"
                                            border.width: 1
                                        }
                                    }
                                }

                                // Active Task Bind Pill (with live task name)
                                Rectangle {
                                    Layout.preferredWidth: Math.round(140 * scaleFactor)
                                    Layout.fillHeight: true
                                    color: (shellRoot && shellRoot.pomodoroActive && shellRoot.pomodoroRunning) ? "#201008" : "#080c14"
                                    border.color: (shellRoot && shellRoot.pomodoroActive && shellRoot.pomodoroRunning) ? "#FF5F15" : "#212836"
                                    border.width: 1
                                    radius: 2

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: Math.round(5 * scaleFactor)
                                        anchors.rightMargin: Math.round(5 * scaleFactor)
                                        spacing: Math.round(3 * scaleFactor)

                                        Text {
                                            text: (shellRoot && shellRoot.pomodoroActive && shellRoot.pomodoroRunning) ? "󰈈 FOCUS:" : "BIND:"
                                            color: (shellRoot && shellRoot.pomodoroActive && shellRoot.pomodoroRunning) ? "#FF5F15" : "#00E5FF"
                                            font { family: hudWindow.monoFont; pixelSize: Math.round(8 * scaleFactor); bold: true }
                                        }

                                        Text {
                                            text: {
                                                var bId = card09Root.boundTaskId || "TK-01";
                                                var tasks = (hudWindow.hudData && hudWindow.hudData.tasks) ? hudWindow.hudData.tasks : [];
                                                for (var i = 0; i < tasks.length; i++) {
                                                    if (tasks[i].id === bId) {
                                                        return "[" + bId + "] " + tasks[i].content;
                                                    }
                                                }
                                                return bId;
                                            }
                                            color: "#ffffff"
                                            font { family: hudWindow.monoFont; pixelSize: Math.round(8.5 * scaleFactor); bold: true }
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }
                                    }
                                }
                            }
                        }

                        // Task List Container (Scrollable ListView in Mask for Desktop Interaction)
                        Item {
                            id: interactiveTasksArea
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            ColumnLayout {
                                anchors.fill: parent
                                spacing: Math.round(3 * scaleFactor)

                                // Bloomberg Checklist Ledger Header
                                RowLayout {
                                    Layout.fillWidth: true
                                    anchors.leftMargin: Math.round(6 * scaleFactor)
                                    anchors.rightMargin: Math.round(6 * scaleFactor)
                                    spacing: Math.round(8 * scaleFactor)

                                    Text {
                                        text: "ACT"
                                        Layout.preferredWidth: Math.round(24 * scaleFactor)
                                        color: "#556477"
                                        font { family: hudWindow.monoFont; pixelSize: Math.round(9.5 * scaleFactor); bold: true }
                                    }
                                    Text {
                                        text: "PRI"
                                        Layout.preferredWidth: Math.round(20 * scaleFactor)
                                        color: "#556477"
                                        font { family: hudWindow.monoFont; pixelSize: Math.round(9.5 * scaleFactor); bold: true }
                                    }
                                    Text {
                                        text: "ID"
                                        Layout.preferredWidth: Math.round(40 * scaleFactor)
                                        color: "#556477"
                                        font { family: hudWindow.monoFont; pixelSize: Math.round(9.5 * scaleFactor); bold: true }
                                    }
                                    Text {
                                        text: "TASK ITEM / SCOPE"
                                        Layout.fillWidth: true
                                        color: "#556477"
                                        font { family: hudWindow.monoFont; pixelSize: Math.round(9.5 * scaleFactor); bold: true }
                                    }
                                    Text {
                                        text: "DOMAIN"
                                        Layout.preferredWidth: Math.round(60 * scaleFactor)
                                        color: "#556477"
                                        font { family: hudWindow.monoFont; pixelSize: Math.round(9.5 * scaleFactor); bold: true }
                                    }
                                    Text {
                                        text: "DELTA"
                                        Layout.preferredWidth: Math.round(65 * scaleFactor)
                                        horizontalAlignment: Text.AlignRight
                                        color: "#556477"
                                        font { family: hudWindow.monoFont; pixelSize: Math.round(9.5 * scaleFactor); bold: true }
                                    }

                                }

                                Rectangle { Layout.fillWidth: true; height: 1; color: "#161f2c" }

                                // Interactive Task Items Scrollable ListView
                                ListView {
                                    id: taskListView
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    clip: true
                                    spacing: Math.round(2 * scaleFactor)
                                    boundsBehavior: Flickable.StopAtBounds
                                    model: (hudWindow.hudData && hudWindow.hudData.tasks) ? hudWindow.hudData.tasks : []

                                    delegate: Rectangle {
                                        width: taskListView.width
                                        height: Math.round(24 * scaleFactor)
                                        color: (card09Root.boundTaskId === modelData.id)
                                            ? "#0c1522"
                                            : (taskRowMa.containsMouse ? "#0a0e17" : "#05080e")
                                        border.color: (card09Root.boundTaskId === modelData.id)
                                            ? "#00E5FF"
                                            : (taskRowMa.containsMouse ? "#212836" : "#141c26")
                                        border.width: 1
                                        radius: 2

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: Math.round(6 * scaleFactor)
                                            anchors.rightMargin: Math.round(6 * scaleFactor)
                                            spacing: Math.round(8 * scaleFactor)

                                            // Latch Action Toggle Checkbox
                                            Rectangle {
                                                Layout.preferredWidth: Math.round(14 * scaleFactor)
                                                Layout.preferredHeight: Math.round(14 * scaleFactor)
                                                color: modelData.done ? "#059669" : "#101622"
                                                border.color: modelData.done ? "#10b981" : "#334155"
                                                border.width: 1
                                                radius: 2

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: modelData.done ? "✓" : ""
                                                    font { family: hudWindow.monoFont; pixelSize: Math.round(9.5 * scaleFactor); bold: true }
                                                    color: "#000000"
                                                }

                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        if (shellRoot && shellRoot.toggleTask) {
                                                            shellRoot.toggleTask(modelData.raw_id || modelData.id);
                                                        }
                                                    }
                                                }
                                            }

                                            // Priority Badge
                                            Text {
                                                text: modelData.prio_label || "P1"
                                                font { family: hudWindow.monoFont; pixelSize: Math.round(9.5 * scaleFactor); bold: true }
                                                color: (modelData.prio_label === "P1" || modelData.priority === 1)
                                                    ? "#FF5F15"
                                                    : ((modelData.prio_label === "P2" || modelData.priority === 2) ? "#FF9F0A" : "#64748B")
                                                Layout.preferredWidth: Math.round(20 * scaleFactor)
                                            }

                                            // UID
                                            Text {
                                                text: modelData.id || "TK-00"
                                                font { family: hudWindow.monoFont; pixelSize: Math.round(8.5 * scaleFactor); bold: true; features: { "tnum": 1 } }
                                                color: (card09Root.boundTaskId === modelData.id) ? "#00E5FF" : "#556477"
                                                Layout.preferredWidth: Math.round(40 * scaleFactor)
                                            }

                                            // Task Item Text (Click binds task to Pomodoro)
                                            Text {
                                                text: modelData.content || "Task Item"
                                                color: modelData.done ? Qt.rgba(1, 1, 1, 0.3) : ((card09Root.boundTaskId === modelData.id) ? "#ffffff" : "#c5d1de")
                                                font { family: hudWindow.monoFont; pixelSize: Math.round(9.5 * scaleFactor); bold: (card09Root.boundTaskId === modelData.id); strikeout: modelData.done }
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                            }

                                            // Domain Tag
                                            Text {
                                                text: "[" + (modelData.domain || "GENERAL") + "]"
                                                font { family: hudWindow.monoFont; pixelSize: Math.round(9 * scaleFactor); bold: true }
                                                color: "#64748B"
                                                Layout.preferredWidth: Math.round(60 * scaleFactor)
                                            }

                                            // Delta Urgency Tag
                                            Text {
                                                text: modelData.delta || "ROUTINE"
                                                font { family: hudWindow.monoFont; pixelSize: Math.round(8.5 * scaleFactor); bold: true; features: { "tnum": 1 } }
                                                color: modelData.delta_color || "#64748B"
                                                Layout.preferredWidth: Math.round(65 * scaleFactor)
                                                horizontalAlignment: Text.AlignRight
                                            }


                                        }

                                        MouseArea {
                                            id: taskRowMa
                                            anchors.fill: parent
                                            anchors.leftMargin: Math.round(24 * scaleFactor)
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                card09Root.boundTaskId = modelData.id;
                                            }
                                        }
                                    }
                                }

                                // ── Dispatch Controls Footer ──────────────────────────────
                                Rectangle {
                                    Layout.fillWidth: true
                                    height: Math.round(22 * scaleFactor)
                                    color: "#080c14"
                                    border.color: "#181d26"
                                    border.width: 1

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: Math.round(6 * scaleFactor)
                                        anchors.rightMargin: Math.round(6 * scaleFactor)
                                        spacing: Math.round(8 * scaleFactor)

                                        // Refresh Button
                                        Rectangle {
                                            Layout.preferredWidth: Math.round(48 * scaleFactor)
                                            Layout.fillHeight: true
                                            color: resyncMa.pressed ? "#152233" : "#0d131d"
                                            border.color: resyncMa.containsMouse ? "#64D2FF" : "#1c2636"
                                            border.width: 1
                                            radius: 2

                                            Text {
                                                anchors.centerIn: parent
                                                text: "↻ SYNC"
                                                font { family: hudWindow.monoFont; pixelSize: Math.round(7.5 * scaleFactor); bold: true }
                                                color: resyncMa.containsMouse ? "#64D2FF" : Qt.rgba(1, 1, 1, 0.45)
                                            }

                                            MouseArea {
                                                id: resyncMa
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    if (shellRoot && shellRoot.refreshTasks) shellRoot.refreshTasks();
                                                }
                                            }
                                        }

                                        Text {
                                            text: "DISPATCH QUEUE: " + ((hudWindow.hudData && hudWindow.hudData.tasks) ? hudWindow.hudData.tasks.length : 0) + " ITEMS"
                                            color: Qt.rgba(1, 1, 1, 0.35)
                                            font { family: hudWindow.monoFont; pixelSize: Math.round(9 * scaleFactor); bold: true }
                                        }

                                        Item { Layout.fillWidth: true }

                                        Text {
                                            text: "URGENCY LOAD: 80% [P1 FOCUS]"
                                            color: "#FF9F0A"
                                            font { family: hudWindow.monoFont; pixelSize: Math.round(9 * scaleFactor); bold: true }
                                        }
                                    }
                                }

                                // ── MIDDLE COLUMN AUDIO SPECTRUM RTA DOCK (Tall Hardware RTA) ──────
                                Rectangle {
                                    id: audioFftArea
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: Math.round(145 * scaleFactor)
                                    color: "#070a10"
                                    border.color: "#162234"
                                    border.width: 1
                                    radius: 2

                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.margins: Math.round(5 * scaleFactor)
                                        spacing: Math.round(3 * scaleFactor)

                                        // Header Strip with Live RTA Telemetry Readout
                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: Math.round(4 * scaleFactor)

                                            RowLayout {
                                                spacing: Math.round(4 * scaleFactor)
                                                Rectangle {
                                                    width: Math.round(5 * scaleFactor)
                                                    height: Math.round(5 * scaleFactor)
                                                    radius: 1
                                                    color: (hudWindow.mpdFftBands && hudWindow.mpdFftBands.length > 0) ? "#00E5FF" : "#334155"
                                                }
                                                Text {
                                                    text: "󰎆 AUDIO SPECTRUM"
                                                    color: (hudWindow.mpdFftBands && hudWindow.mpdFftBands.length > 0) ? "#00E5FF" : "#64748B"
                                                    font { family: hudWindow.monoFont; pixelSize: Math.round(9 * scaleFactor); bold: true }
                                                }
                                            }

                                            Rectangle {
                                                Layout.fillWidth: true
                                                height: 1
                                                color: "#162234"
                                                Layout.alignment: Qt.AlignVCenter
                                            }

                                            Text {
                                                text: (hudWindow.mpdFftBands && hudWindow.mpdFftBands.length > 0 && Players.playing)
                                                    ? "[25 FPS // PIPEWIRE RTA]"
                                                    : "[RTA STANDBY // PAUSED]"
                                                color: (hudWindow.mpdFftBands && hudWindow.mpdFftBands.length > 0 && Players.playing) ? "#30D158" : "#475569"
                                                font { family: hudWindow.monoFont; pixelSize: Math.round(8 * scaleFactor); bold: true; features: { "tnum": 1 } }
                                            }
                                        }

                                        // 24 Full-Height Discrete Frequency Columns with Ballistics & Amber Peak Hold
                                        // Isolated via layer.enabled to prevent dirtying parent window branch on audio ticks
                                        Item {
                                            Layout.fillWidth: true
                                            Layout.fillHeight: true
                                            layer.enabled: true
                                            layer.smooth: false

                                            RowLayout {
                                                anchors.fill: parent
                                            spacing: Math.round(2 * scaleFactor)

                                            Repeater {
                                                model: 24
                                                Rectangle {
                                                    Layout.fillWidth: true
                                                    Layout.fillHeight: true
                                                    color: "#04060a"
                                                    border.color: "#101622"
                                                    border.width: 0.5
                                                    radius: 1

                                                    readonly property real pLvl: (hudWindow.mpdFftBands && hudWindow.mpdFftBands.length > index)
                                                        ? hudWindow.mpdFftBands[index]
                                                        : 0.0
                                                    readonly property real pPeak: (hudWindow.mpdFftPeaks && hudWindow.mpdFftPeaks.length > index)
                                                        ? hudWindow.mpdFftPeaks[index]
                                                        : pLvl

                                                    // Multi-Segment LED Ladder Fill (Hardware RTA Meter)
                                                    ColumnLayout {
                                                        anchors.fill: parent
                                                        anchors.margins: 1
                                                        spacing: 1

                                                        Repeater {
                                                            model: 16
                                                            Rectangle {
                                                                Layout.fillWidth: true
                                                                Layout.fillHeight: true
                                                                radius: 0.5
                                                                readonly property int segIdx: 15 - index // 0 at bottom, 15 at top
                                                                readonly property real thresh: (segIdx + 0.5) / 16.0
                                                                readonly property bool isLit: parent.parent.pLvl >= thresh
                                                                color: isLit
                                                                    ? (segIdx >= 14 ? "#FF453A" : (segIdx >= 11 ? "#FF9F0A" : (segIdx >= 4 ? "#30D158" : "#00E5FF")))
                                                                    : "#070d16"
                                                                opacity: isLit ? 1.0 : 0.3
                                                            }
                                                        }
                                                    }

                                                    // High-Contrast High-Visibility Peak Hold Indicator (Amber / White)
                                                    Rectangle {
                                                        anchors.left: parent.left
                                                        anchors.right: parent.right
                                                        anchors.leftMargin: 1
                                                        anchors.rightMargin: 1
                                                        y: Math.max(1, Math.min(parent.height - 3, Math.round(parent.height * (1.0 - Math.min(1.0, parent.pPeak))) - 1))
                                                        height: Math.round(1.5 * scaleFactor)
                                                        color: parent.pPeak >= 0.88 ? "#FFFFFF" : "#FFB703"
                                                        visible: parent.pPeak > 0.06
                                                        z: 2
                                                    }
                                                }
                                            }
                                        }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ═════════════════════════════════════════════════════════════════
            // COLUMN 3: NETWORK RADAR & AUDIOPHILE DECK / NOTIFICATION MATRIX (28% Width)
            // ═════════════════════════════════════════════════════════════════
            Item {
                id: col3Container
                Layout.preferredWidth: Math.round(hudWindow.width * 0.28)
                Layout.maximumWidth: Math.round(hudWindow.width * 0.28)
                Layout.fillHeight: true
                clip: true

                // VIEW 1: STANDARD TRI-DECK ([09] Radar, [10] Audiophile, [11] Scratchpad)
                ColumnLayout {
                    anchors.fill: parent
                    spacing: 0
                    visible: !hudWindow.showNotificationDeck

                // ── PANE 3A: PASSIVE SPECTRUM // KERNEL RADAR (~280px) ───────
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.round(320 * scaleFactor)
                    color: "#000000"
                    border.color: "#181d26"
                    border.width: 1

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Math.round(10 * scaleFactor)
                        spacing: Math.round(5 * scaleFactor)

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Math.round(6 * scaleFactor)
                            Text {
                                text: "┌─ [10] NETWORK SPECTRUM"
                                color: "#00E5FF"
                                font { family: hudWindow.monoFont; pixelSize: Math.round(11.5 * scaleFactor); bold: true }
                            }
                            Rectangle {
                                Layout.fillWidth: true
                                height: 1
                                color: "#212836"
                                Layout.alignment: Qt.AlignVCenter
                            }

                            // Notification Deck Toggle Pill
                            Rectangle {
                                id: notifToggleBtn
                                implicitWidth: notifRowLayout.implicitWidth + Math.round(22 * scaleFactor)
                                width: implicitWidth
                                height: Math.round(18 * scaleFactor)
                                color: (shellRoot && shellRoot.totalNotifCount > 0) ? "#2a1808" : (hudWindow.showNotificationDeck ? "#0c1524" : "#0d1b2a")
                                border.color: (shellRoot && shellRoot.totalNotifCount > 0) ? "#FF9F0A" : (hudWindow.showNotificationDeck ? "#64D2FF" : "#212836")
                                border.width: 1
                                radius: 2

                                RowLayout {
                                    id: notifRowLayout
                                    anchors.centerIn: parent
                                    spacing: Math.round(5 * scaleFactor)
                                    Text {
                                        id: notifIconTxt
                                        text: (shellRoot && shellRoot.totalNotifCount > 0) ? "󰂚" : "󰂛"
                                        color: (shellRoot && shellRoot.totalNotifCount > 0) ? "#FF9F0A" : (hudWindow.showNotificationDeck ? "#64D2FF" : Qt.rgba(1, 1, 1, 0.6))
                                        font { family: hudWindow.iconFont; pixelSize: Math.round(9 * scaleFactor) }
                                    }
                                    Text {
                                        id: notifBtnTxt
                                        text: (shellRoot && shellRoot.totalNotifCount > 0) ? (shellRoot.totalNotifCount + " ALERTS") : "ALERTS"
                                        color: (shellRoot && shellRoot.totalNotifCount > 0) ? "#FF9F0A" : (hudWindow.showNotificationDeck ? "#64D2FF" : Qt.rgba(1, 1, 1, 0.6))
                                        font { family: hudWindow.monoFont; pixelSize: Math.round(8.5 * scaleFactor); bold: true; features: { "tnum": 1 } }
                                    }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: hudWindow.toggleNotificationDeck()
                                }
                            }
                        }

                        // ── Physical Link & Packet Telemetry Strip ──
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Math.round(6 * scaleFactor)

                            // Interface & PHY Spec
                            RowLayout {
                                spacing: Math.round(4 * scaleFactor)
                                Rectangle {
                                    width: Math.round(6 * scaleFactor)
                                    height: Math.round(6 * scaleFactor)
                                    radius: 1
                                    color: (hudWindow.hudData && hudWindow.hudData.active_iface !== "none") ? "#00E5FF" : "#64748B"
                                }
                                Text {
                                    text: "DEV: " + ((hudWindow.hudData && hudWindow.hudData.active_iface) ? hudWindow.hudData.active_iface.toUpperCase() : "ENP2S0")
                                    color: "#00E5FF"
                                    font { family: hudWindow.monoFont; pixelSize: Math.round(9.5 * scaleFactor); bold: true }
                                }
                                Text {
                                    text: "[" + ((hudWindow.hudData && hudWindow.hudData.wifi_phy) ? hudWindow.hudData.wifi_phy : "1000 Mbps") + "]"
                                    color: "#64748B"
                                    font { family: hudWindow.monoFont; pixelSize: Math.round(9.5 * scaleFactor); bold: true }
                                }
                            }

                            // Mesh VPN Status
                            Text {
                                text: "│"
                                color: "#212836"
                                font { family: hudWindow.monoFont; pixelSize: Math.round(9 * scaleFactor) }
                            }
                            Text {
                                text: (hudWindow.hudData && hudWindow.hudData.vpn && hudWindow.hudData.vpn.active) ? "MESH: TS0 OK" : "MESH: STANDBY"
                                color: (hudWindow.hudData && hudWindow.hudData.vpn && hudWindow.hudData.vpn.active) ? "#30D158" : "#475569"
                                font { family: hudWindow.monoFont; pixelSize: Math.round(9.5 * scaleFactor); bold: true }
                            }

                            Item { Layout.fillWidth: true }

                            // TCP Sockets Matrix
                            RowLayout {
                                spacing: Math.round(4 * scaleFactor)
                                Text {
                                    text: "TCP:"
                                    color: "#64748B"
                                    font { family: hudWindow.monoFont; pixelSize: Math.round(9.5 * scaleFactor); bold: true }
                                }
                                Text {
                                    text: ((hudWindow.hudData && hudWindow.hudData.net_tcp_estab !== undefined) ? hudWindow.hudData.net_tcp_estab : 24) + " ESTAB"
                                    color: "#30D158"
                                    font { family: hudWindow.monoFont; pixelSize: Math.round(8.5 * scaleFactor); bold: true; features: { "tnum": 1 } }
                                }
                                Text {
                                    text: "/"
                                    color: "#334155"
                                    font { family: hudWindow.monoFont; pixelSize: Math.round(8.5 * scaleFactor) }
                                }
                                Text {
                                    text: ((hudWindow.hudData && hudWindow.hudData.net_tcp_wait !== undefined) ? hudWindow.hudData.net_tcp_wait : 4) + " WAIT"
                                    color: "#FF9F0A"
                                    font { family: hudWindow.monoFont; pixelSize: Math.round(8.5 * scaleFactor); bold: true; features: { "tnum": 1 } }
                                }
                            }

                            // Packet Rate Pill
                            Rectangle {
                                width: Math.round(76 * scaleFactor)
                                height: Math.round(18 * scaleFactor)
                                color: "#071822"
                                border.color: "#00E5FF"
                                border.width: 1
                                radius: 2

                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: Math.round(3 * scaleFactor)
                                    Text {
                                        text: "󰛳"
                                        color: "#00E5FF"
                                        font { family: hudWindow.iconFont; pixelSize: Math.round(8.5 * scaleFactor) }
                                    }
                                    Text {
                                        text: ((hudWindow.hudData && hudWindow.hudData.net_pkt_rate !== undefined) ? hudWindow.hudData.net_pkt_rate : 884) + " PKT/S"
                                        color: "#00E5FF"
                                        font { family: hudWindow.monoFont; pixelSize: Math.round(8 * scaleFactor); bold: true; features: { "tnum": 1 } }
                                    }
                                }
                            }
                        }

                        // ── Sub-Header: Live Dual-Channel Rates & Oscilloscope Readout ──
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Math.round(8 * scaleFactor)

                            readonly property var rxHist: (hudWindow.hudData && hudWindow.hudData.net_rx_hist) ? hudWindow.hudData.net_rx_hist : []
                            readonly property var txHist: (hudWindow.hudData && hudWindow.hudData.net_tx_hist) ? hudWindow.hudData.net_tx_hist : []
                            readonly property real peakRxVal: {
                                var m = 0;
                                for (var i = 0; i < rxHist.length; i++) if (rxHist[i] > m) m = rxHist[i];
                                return m;
                            }
                            readonly property real peakTxVal: {
                                var m = 0;
                                for (var i = 0; i < txHist.length; i++) if (txHist[i] > m) m = txHist[i];
                                return m;
                            }

                            // CH1 RX Live Rate + Peak Hold (Cyan #00E5FF)
                            RowLayout {
                                spacing: Math.round(4 * scaleFactor)
                                Rectangle {
                                    width: Math.round(8 * scaleFactor)
                                    height: Math.round(8 * scaleFactor)
                                    color: "#00E5FF"
                                    radius: 1
                                }
                                Text {
                                    text: "CH1 [RX]:"
                                    color: "#00E5FF"
                                    font { family: hudWindow.monoFont; pixelSize: Math.round(11 * scaleFactor); bold: true }
                                }
                                Text {
                                    text: (hudWindow.hudData ? hudWindow.hudData.net_rx_str : "0 B/s")
                                    color: "#00E5FF"
                                    font { family: hudWindow.monoFont; pixelSize: Math.round(11.5 * scaleFactor); bold: true; features: { "tnum": 1 } }
                                    Layout.preferredWidth: Math.round(76 * scaleFactor)
                                    horizontalAlignment: Text.AlignRight
                                }
                                Text {
                                    text: "▲PK " + hudWindow.formatBytesRate(parent.parent.peakRxVal)
                                    color: "#64748B"
                                    font { family: hudWindow.monoFont; pixelSize: Math.round(8.5 * scaleFactor); features: { "tnum": 1 } }
                                    Layout.preferredWidth: Math.round(80 * scaleFactor)
                                    horizontalAlignment: Text.AlignRight
                                }
                            }

                            Item { Layout.fillWidth: true }

                            // CH2 TX Live Rate + Peak Hold (Safety Orange #FF5F15)
                            RowLayout {
                                spacing: Math.round(4 * scaleFactor)
                                Rectangle {
                                    width: Math.round(8 * scaleFactor)
                                    height: Math.round(8 * scaleFactor)
                                    color: "#FF5F15"
                                    radius: 1
                                }
                                Text {
                                    text: "CH2 [TX]:"
                                    color: "#FF5F15"
                                    font { family: hudWindow.monoFont; pixelSize: Math.round(11 * scaleFactor); bold: true }
                                }
                                Text {
                                    text: (hudWindow.hudData ? hudWindow.hudData.net_tx_str : "0 B/s")
                                    color: "#FF5F15"
                                    font { family: hudWindow.monoFont; pixelSize: Math.round(11.5 * scaleFactor); bold: true; features: { "tnum": 1 } }
                                    Layout.preferredWidth: Math.round(82 * scaleFactor)
                                    horizontalAlignment: Text.AlignRight
                                }
                                Text {
                                    text: "▲PK " + hudWindow.formatBytesRate(parent.parent.peakTxVal)
                                    color: "#64748B"
                                    font { family: hudWindow.monoFont; pixelSize: Math.round(8.5 * scaleFactor); features: { "tnum": 1 } }
                                    Layout.preferredWidth: Math.round(84 * scaleFactor)
                                    horizontalAlignment: Text.AlignRight
                                }
                            }
                        }

                        // ── Calibrated Dual-Trace Oscilloscope / Spectrum Analyzer Canvas ──
                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: Math.round(152 * scaleFactor)
                            clip: true

                            Canvas {
                                id: netSpectrumCanvas
                                anchors.fill: parent
                                property var rxHist: (hudWindow.hudData && hudWindow.hudData.net_rx_hist) ? hudWindow.hudData.net_rx_hist : []
                                property var txHist: (hudWindow.hudData && hudWindow.hudData.net_tx_hist) ? hudWindow.hudData.net_tx_hist : []
                                onRxHistChanged: requestPaint()
                                onTxHistChanged: requestPaint()

                                onPaint: {
                                    var ctx = getContext("2d");
                                    ctx.reset();
                                    var w = width;
                                    var h = height;
                                    var padTop = Math.round(8 * scaleFactor);
                                    var padBottom = Math.round(18 * scaleFactor);
                                    var padLeft = Math.round(8 * scaleFactor);
                                    var padRight = Math.round(8 * scaleFactor);
                                    var plotW = w - padLeft - padRight;
                                    var plotH = h - padTop - padBottom;
                                    var baselineY = padTop + plotH;

                                    // 1. Oscilloscope Screen Bezel / Dark CRT Background
                                    ctx.fillStyle = "#04070c";
                                    ctx.fillRect(padLeft, padTop, plotW, plotH);

                                    // 2. High-Precision Laboratory Graticule Grid (4 Horiz Divisions, 8 Vert Divisions)
                                    ctx.strokeStyle = "#101a28";
                                    ctx.lineWidth = 1;

                                    // Horizontal Subdivisions (25%, 50%, 75%)
                                    for (var gh = 1; gh <= 3; gh++) {
                                        var gy = padTop + plotH * (1.0 - gh / 4.0);
                                        ctx.beginPath();
                                        ctx.moveTo(padLeft, gy);
                                        ctx.lineTo(padLeft + plotW, gy);
                                        ctx.stroke();
                                    }

                                    // Vertical Time Divisions (Every 6s across 48s history: 8 columns)
                                    for (var gv = 0; gv <= 8; gv++) {
                                        var gx = padLeft + (gv / 8.0) * plotW;
                                        ctx.beginPath();
                                        ctx.moveTo(gx, padTop);
                                        ctx.lineTo(gx, baselineY);
                                        ctx.stroke();
                                    }

                                    // Center Crosshair Major Reticle Ticks
                                    var midX = padLeft + plotW * 0.5;
                                    var midY = padTop + plotH * 0.5;
                                    ctx.strokeStyle = "#1c2d44";
                                    ctx.lineWidth = 1;
                                    // Major center vertical reticle line
                                    ctx.beginPath();
                                    ctx.moveTo(midX, padTop);
                                    ctx.lineTo(midX, baselineY);
                                    ctx.stroke();
                                    // Major center horizontal reticle line
                                    ctx.beginPath();
                                    ctx.moveTo(padLeft, midY);
                                    ctx.lineTo(padLeft + plotW, midY);
                                    ctx.stroke();

                                    // Scale Bounds & Dynamic Auto-Ranging
                                    var rxArr = rxHist || [];
                                    var txArr = txHist || [];
                                    var maxVal = 1024 * 32; // 32 KB/s minimum dynamic ceiling
                                    for (var i = 0; i < rxArr.length; i++) if (rxArr[i] > maxVal) maxVal = rxArr[i];
                                    for (var j = 0; j < txArr.length; j++) if (txArr[j] > maxVal) maxVal = txArr[j];

                                    // Subtle Reticle Graduation Labels
                                    ctx.font = "bold " + Math.round(7.5 * scaleFactor) + "px monospace";
                                    ctx.fillStyle = "#334155";
                                    ctx.fillText(hudWindow.formatBytesRate(maxVal), padLeft + 4, padTop + 10);
                                    ctx.fillText(hudWindow.formatBytesRate(maxVal * 0.5), padLeft + 4, midY - 2);

                                    // 3. Draw Trace 2: Instantaneous TX (Safety Orange #FF5F15)
                                    if (txArr.length >= 2) {
                                        var ptsTx = [];
                                        for (var ti = 0; ti < txArr.length; ti++) {
                                            var txX = padLeft + (ti / (txArr.length - 1)) * plotW;
                                            var txV = txArr[ti] || 0;
                                            var txY = baselineY - (Math.min(txV, maxVal) / maxVal) * plotH;
                                            ptsTx.push({ x: txX, y: txY });
                                        }

                                        // Area Fill Gradient for TX
                                        ctx.beginPath();
                                        ctx.moveTo(ptsTx[0].x, baselineY);
                                        ctx.lineTo(ptsTx[0].x, ptsTx[0].y);
                                        for (var tk = 1; tk < ptsTx.length; tk++) {
                                            ctx.lineTo(ptsTx[tk].x, ptsTx[tk].y);
                                        }
                                        ctx.lineTo(ptsTx[ptsTx.length - 1].x, baselineY);
                                        ctx.closePath();
                                        var gradTx = ctx.createLinearGradient(0, padTop, 0, baselineY);
                                        gradTx.addColorStop(0, "rgba(255, 95, 21, 0.28)");
                                        gradTx.addColorStop(0.5, "rgba(255, 95, 21, 0.08)");
                                        gradTx.addColorStop(1, "rgba(255, 95, 21, 0.00)");
                                        ctx.fillStyle = gradTx;
                                        ctx.fill();

                                        // Trace 2 Stroke Line
                                        ctx.beginPath();
                                        ctx.moveTo(ptsTx[0].x, ptsTx[0].y);
                                        for (var tl = 1; tl < ptsTx.length; tl++) {
                                            ctx.lineTo(ptsTx[tl].x, ptsTx[tl].y);
                                        }
                                        ctx.strokeStyle = "#FF5F15";
                                        ctx.lineWidth = 1.4;
                                        ctx.stroke();

                                        // TX Live Endpoint Reticle Pip
                                        var lastTx = ptsTx[ptsTx.length - 1];
                                        ctx.beginPath();
                                        ctx.arc(lastTx.x, lastTx.y, 2.5, 0, 2 * Math.PI);
                                        ctx.fillStyle = "#FF5F15";
                                        ctx.fill();
                                    }

                                    // 4. Draw Trace 1: Instantaneous RX (Pure Cyan #00E5FF)
                                    if (rxArr.length >= 2) {
                                        var ptsRx = [];
                                        for (var ri = 0; ri < rxArr.length; ri++) {
                                            var rxX = padLeft + (ri / (rxArr.length - 1)) * plotW;
                                            var rxV = rxArr[ri] || 0;
                                            var rxY = baselineY - (Math.min(rxV, maxVal) / maxVal) * plotH;
                                            ptsRx.push({ x: rxX, y: rxY });
                                        }

                                        // Area Fill Gradient for RX
                                        ctx.beginPath();
                                        ctx.moveTo(ptsRx[0].x, baselineY);
                                        ctx.lineTo(ptsRx[0].x, ptsRx[0].y);
                                        for (var rk = 1; rk < ptsRx.length; rk++) {
                                            ctx.lineTo(ptsRx[rk].x, ptsRx[rk].y);
                                        }
                                        ctx.lineTo(ptsRx[ptsRx.length - 1].x, baselineY);
                                        ctx.closePath();
                                        var gradRx = ctx.createLinearGradient(0, padTop, 0, baselineY);
                                        gradRx.addColorStop(0, "rgba(0, 229, 255, 0.32)");
                                        gradRx.addColorStop(0.5, "rgba(0, 229, 255, 0.10)");
                                        gradRx.addColorStop(1, "rgba(0, 229, 255, 0.00)");
                                        ctx.fillStyle = gradRx;
                                        ctx.fill();

                                        // Trace 1 Stroke Line
                                        ctx.beginPath();
                                        ctx.moveTo(ptsRx[0].x, ptsRx[0].y);
                                        for (var rl = 1; rl < ptsRx.length; rl++) {
                                            ctx.lineTo(ptsRx[rl].x, ptsRx[rl].y);
                                        }
                                        ctx.strokeStyle = "#00E5FF";
                                        ctx.lineWidth = 1.6;
                                        ctx.stroke();

                                        // RX Live Endpoint Glow Reticle
                                        var lastRx = ptsRx[ptsRx.length - 1];
                                        ctx.beginPath();
                                        ctx.arc(lastRx.x, lastRx.y, 3.2, 0, 2 * Math.PI);
                                        ctx.fillStyle = "#00E5FF";
                                        ctx.fill();
                                        ctx.beginPath();
                                        ctx.arc(lastRx.x, lastRx.y, 1.4, 0, 2 * Math.PI);
                                        ctx.fillStyle = "#ffffff";
                                        ctx.fill();
                                    }

                                    // 5. Baseline Axis Line & Frame Border
                                    ctx.strokeStyle = "#1e293b";
                                    ctx.lineWidth = 1;
                                    ctx.strokeRect(padLeft, padTop, plotW, plotH);

                                    // 6. Time Division Ticks & Legend Labels
                                    ctx.font = "bold " + Math.round(8 * scaleFactor) + "px monospace";
                                    ctx.fillStyle = "#475569";
                                    ctx.fillText("-48s", padLeft, h - 3);
                                    ctx.fillText("-36s", padLeft + plotW * 0.25 - 10, h - 3);
                                    ctx.fillText("-24s", padLeft + plotW * 0.50 - 10, h - 3);
                                    ctx.fillText("-12s", padLeft + plotW * 0.75 - 10, h - 3);
                                    ctx.fillStyle = "#00E5FF";
                                    ctx.fillText("0s [LIVE]", padLeft + plotW - 42, h - 3);

                                    // Oscilloscope Diagnostic Calibration Stamp
                                    ctx.font = "bold " + Math.round(7.5 * scaleFactor) + "px monospace";
                                    ctx.fillStyle = "#334155";
                                    ctx.fillText("TIME: 6s/DIV │ VERT: AUTO-SCALE", padLeft + plotW * 0.50 - 75, padTop + 10);
                                }
                            }
                        }

                        // ── Traffic Volume Accumulator & Hardware Bus Telemetry Footer ──
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Math.round(6 * scaleFactor)

                            // Lifetime Session RX Counter
                            RowLayout {
                                spacing: Math.round(3 * scaleFactor)
                                Text {
                                    text: "RX Σ:"
                                    color: "#00E5FF"
                                    font { family: hudWindow.monoFont; pixelSize: Math.round(9.5 * scaleFactor); bold: true }
                                }
                                Text {
                                    text: (hudWindow.hudData ? hudWindow.hudData.net_total_rx : "0.0 GB")
                                    color: "#ffffff"
                                    font { family: hudWindow.monoFont; pixelSize: Math.round(9.5 * scaleFactor); bold: true; features: { "tnum": 1 } }
                                }
                            }

                            Text {
                                text: "│"
                                color: "#212836"
                                font { family: hudWindow.monoFont; pixelSize: Math.round(9 * scaleFactor) }
                            }

                            // Lifetime Session TX Counter
                            RowLayout {
                                spacing: Math.round(3 * scaleFactor)
                                Text {
                                    text: "TX Σ:"
                                    color: "#FF5F15"
                                    font { family: hudWindow.monoFont; pixelSize: Math.round(9.5 * scaleFactor); bold: true }
                                }
                                Text {
                                    text: (hudWindow.hudData ? hudWindow.hudData.net_total_tx : "0.0 GB")
                                    color: "#ffffff"
                                    font { family: hudWindow.monoFont; pixelSize: Math.round(9.5 * scaleFactor); bold: true; features: { "tnum": 1 } }
                                }
                            }

                            Item { Layout.fillWidth: true }

                            // Physical Link Duplex & MTU
                            Text {
                                text: "FULL DUPLEX // MTU 1500"
                                color: "#64748B"
                                font { family: hudWindow.monoFont; pixelSize: Math.round(9.5 * scaleFactor); bold: true }
                            }
                        }

                        // ── Hardware Bus Error & Drop Statistics Bar ──
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Math.round(6 * scaleFactor)

                            // Drops Counter
                            RowLayout {
                                spacing: Math.round(3 * scaleFactor)
                                Text {
                                    text: "DROPS:"
                                    color: "#64748B"
                                    font { family: hudWindow.monoFont; pixelSize: Math.round(9.5 * scaleFactor); bold: true }
                                }
                                Text {
                                    text: ((hudWindow.hudData && hudWindow.hudData.net_drops !== undefined) ? hudWindow.hudData.net_drops : 0)
                                    color: (hudWindow.hudData && hudWindow.hudData.net_drops > 0) ? "#FF9F0A" : "#30D158"
                                    font { family: hudWindow.monoFont; pixelSize: Math.round(8.5 * scaleFactor); bold: true; features: { "tnum": 1 } }
                                }
                            }

                            Text {
                                text: "│"
                                color: "#212836"
                                font { family: hudWindow.monoFont; pixelSize: Math.round(8.5 * scaleFactor) }
                            }

                            // Frame Errors Counter
                            RowLayout {
                                spacing: Math.round(3 * scaleFactor)
                                Text {
                                    text: "ERRS:"
                                    color: "#64748B"
                                    font { family: hudWindow.monoFont; pixelSize: Math.round(9.5 * scaleFactor); bold: true }
                                }
                                Text {
                                    text: ((hudWindow.hudData && hudWindow.hudData.net_errs !== undefined) ? hudWindow.hudData.net_errs : 0)
                                    color: (hudWindow.hudData && hudWindow.hudData.net_errs > 0) ? "#EF4444" : "#30D158"
                                    font { family: hudWindow.monoFont; pixelSize: Math.round(8.5 * scaleFactor); bold: true; features: { "tnum": 1 } }
                                }
                            }

                            Item { Layout.fillWidth: true }

                            // Link Integrity & BER Quality Rating
                            RowLayout {
                                spacing: Math.round(3 * scaleFactor)
                                Text {
                                    text: "LINK INTEGRITY: 100%"
                                    color: "#30D158"
                                    font { family: hudWindow.monoFont; pixelSize: Math.round(9.5 * scaleFactor); bold: true }
                                }
                                Text {
                                    text: "│ BER < 1e-12"
                                    color: "#475569"
                                    font { family: hudWindow.monoFont; pixelSize: Math.round(8 * scaleFactor) }
                                }
                            }
                        }
                    }

                    // ── In-Card Overlay: Network & Interface Telemetry ────────
                    Rectangle {
                        id: wifiOverlayArea
                        anchors.fill: parent
                        z: 50
                        visible: hudWindow.showWifiOverlay
                        color: "#04060a"
                        border.color: "#0A84FF"
                        border.width: 1

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: Math.round(10 * scaleFactor)
                            spacing: Math.round(6 * scaleFactor)

                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    text: "┌─ [10] NETWORK INTERFACES"
                                    color: "#0A84FF"
                                    font { family: hudWindow.monoFont; pixelSize: Math.round(11 * scaleFactor); bold: true }
                                }
                                Item { Layout.fillWidth: true }
                                Rectangle {
                                    width: Math.round(64 * scaleFactor)
                                    height: Math.round(20 * scaleFactor)
                                    color: "#250d0d"
                                    border.color: "#FF453A"
                                    border.width: 1
                                    radius: 2
                                    Text {
                                        anchors.centerIn: parent
                                        text: "✕ CLOSE"
                                        color: "#FF453A"
                                        font { family: hudWindow.monoFont; pixelSize: Math.round(9.5 * scaleFactor); bold: true }
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: hudWindow.showWifiOverlay = false
                                    }
                                }
                            }

                            // Gateway & Ping
                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    text: "GATEWAY: " + (hudWindow.networkOverlayData ? hudWindow.networkOverlayData.default_gw : "172.29.7.254")
                                    color: "#ffffff"
                                    font { family: hudWindow.monoFont; pixelSize: Math.round(9.5 * scaleFactor); bold: true }
                                }
                                Item { Layout.fillWidth: true }
                                Text {
                                    text: "PING: " + (hudWindow.networkOverlayData && hudWindow.networkOverlayData.ping_ms > 0 ? hudWindow.networkOverlayData.ping_ms + " ms" : "15 ms")
                                    color: "#30D158"
                                    font { family: hudWindow.monoFont; pixelSize: Math.round(9.5 * scaleFactor); bold: true }
                                }
                            }

                            Rectangle { Layout.fillWidth: true; height: 1; color: "#182030" }

                            // Interface List
                            Repeater {
                                model: (hudWindow.networkOverlayData && hudWindow.networkOverlayData.interfaces) ? hudWindow.networkOverlayData.interfaces : [
                                    { name: "enp2s0", state: "UP", ip: "172.29.6.16", type: "WIRED" },
                                    { name: "tailscale0", state: "UP", ip: "100.77.57.23", type: "VPN" }
                                ]
                                delegate: Rectangle {
                                    Layout.fillWidth: true
                                    height: Math.round(26 * scaleFactor)
                                    color: index % 2 === 0 ? "#080c14" : "#05080e"
                                    border.color: "#182030"
                                    border.width: 1

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: Math.round(6 * scaleFactor)
                                        spacing: Math.round(8 * scaleFactor)

                                        Text {
                                            text: modelData.name
                                            color: modelData.type === "VPN" ? "#64D2FF" : "#30D158"
                                            font { family: hudWindow.monoFont; pixelSize: Math.round(9.5 * scaleFactor); bold: true }
                                            Layout.preferredWidth: Math.round(75 * scaleFactor)
                                        }
                                        Text {
                                            text: "[" + modelData.type + "]"
                                            color: "#8b949e"
                                            font { family: hudWindow.monoFont; pixelSize: Math.round(8.5 * scaleFactor) }
                                            Layout.preferredWidth: Math.round(60 * scaleFactor)
                                        }
                                        Text {
                                            text: modelData.ip
                                            color: "#ffffff"
                                            font { family: hudWindow.monoFont; pixelSize: Math.round(9 * scaleFactor); features: { "tnum": 1 } }
                                        }
                                        Item { Layout.fillWidth: true }
                                        Text {
                                            text: "[" + modelData.state + "]"
                                            color: modelData.state === "UP" ? "#30D158" : "#8b949e"
                                            font { family: hudWindow.monoFont; pixelSize: Math.round(9.5 * scaleFactor); bold: true }
                                        }
                                    }
                                }
                            }

                            Item { Layout.fillHeight: true }

                            // Re-poll Button
                            Rectangle {
                                Layout.fillWidth: true
                                height: Math.round(22 * scaleFactor)
                                color: "#0d1b2a"
                                border.color: "#0A84FF"
                                border.width: 1
                                radius: 2

                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: Math.round(4 * scaleFactor)
                                    Text {
                                        text: "󰑐"
                                        color: "#64D2FF"
                                        font { family: hudWindow.iconFont; pixelSize: Math.round(10 * scaleFactor) }
                                    }
                                    Text {
                                        text: "REFRESH NETWORK TELEMETRY"
                                        color: "#64D2FF"
                                        font { family: hudWindow.monoFont; pixelSize: Math.round(9 * scaleFactor); bold: true }
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: pFetchNetworkInfo.running = true
                                }
                            }
                        }
                    }

                    // ── In-Card Overlay: Bluetooth Devices & Controller ───────
                    Rectangle {
                        id: btOverlayArea
                        anchors.fill: parent
                        z: 50
                        visible: hudWindow.showBtOverlay
                        color: "#04060a"
                        border.color: "#BF5AF2"
                        border.width: 1

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: Math.round(10 * scaleFactor)
                            spacing: Math.round(6 * scaleFactor)

                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    text: "┌─ [10] BLUETOOTH DEVICES"
                                    color: "#BF5AF2"
                                    font { family: hudWindow.monoFont; pixelSize: Math.round(11 * scaleFactor); bold: true }
                                }
                                Item { Layout.fillWidth: true }
                                Rectangle {
                                    width: Math.round(64 * scaleFactor)
                                    height: Math.round(20 * scaleFactor)
                                    color: "#250d0d"
                                    border.color: "#FF453A"
                                    border.width: 1
                                    radius: 2
                                    Text {
                                        anchors.centerIn: parent
                                        text: "✕ CLOSE"
                                        color: "#FF453A"
                                        font { family: hudWindow.monoFont; pixelSize: Math.round(9.5 * scaleFactor); bold: true }
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: hudWindow.showBtOverlay = false
                                    }
                                }
                            }

                            // Controller Power Status
                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    text: "CONTROLLER STATUS:"
                                    color: "#ffffff"
                                    font { family: hudWindow.monoFont; pixelSize: Math.round(9.5 * scaleFactor); bold: true }
                                }
                                Item { Layout.fillWidth: true }
                                Text {
                                    text: (hudWindow.btOverlayData && hudWindow.btOverlayData.powered) ? "POWERED [ON]" : "DISABLED [OFF]"
                                    color: (hudWindow.btOverlayData && hudWindow.btOverlayData.powered) ? "#30D158" : "#8b949e"
                                    font { family: hudWindow.monoFont; pixelSize: Math.round(9.5 * scaleFactor); bold: true }
                                }
                            }

                            Rectangle { Layout.fillWidth: true; height: 1; color: "#182030" }

                            // Paired Devices List
                            Item {
                                Layout.fillWidth: true
                                Layout.fillHeight: true

                                ColumnLayout {
                                    anchors.centerIn: parent
                                    visible: !hudWindow.btOverlayData || !hudWindow.btOverlayData.devices || hudWindow.btOverlayData.devices.length === 0
                                    spacing: Math.round(4 * scaleFactor)
                                    Text {
                                        text: "NO PAIRED BLUETOOTH DEVICES FOUND"
                                        color: Qt.rgba(1, 1, 1, 0.4)
                                        font { family: hudWindow.monoFont; pixelSize: Math.round(9.5 * scaleFactor); bold: true }
                                        Layout.alignment: Qt.AlignHCenter
                                    }
                                    Text {
                                        text: "PAIR PERIPHERALS VIA BLUETOOTHCTL OR BLUEBERRY"
                                        color: "#555566"
                                        font { family: hudWindow.monoFont; pixelSize: Math.round(8 * scaleFactor) }
                                        Layout.alignment: Qt.AlignHCenter
                                    }
                                }

                                ListView {
                                    anchors.fill: parent
                                    clip: true
                                    visible: hudWindow.btOverlayData && hudWindow.btOverlayData.devices && hudWindow.btOverlayData.devices.length > 0
                                    model: (hudWindow.btOverlayData && hudWindow.btOverlayData.devices) ? hudWindow.btOverlayData.devices : []
                                    spacing: Math.round(4 * scaleFactor)

                                    delegate: Rectangle {
                                        width: parent ? parent.width : 0
                                        height: Math.round(26 * scaleFactor)
                                        color: "#080c14"
                                        border.color: "#182030"
                                        border.width: 1

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.margins: Math.round(6 * scaleFactor)
                                            spacing: Math.round(8 * scaleFactor)

                                            Text {
                                                text: modelData.name || "Device"
                                                color: "#ffffff"
                                                font { family: hudWindow.monoFont; pixelSize: Math.round(9.5 * scaleFactor); bold: true }
                                                Layout.fillWidth: true
                                                elide: Text.ElideRight
                                            }
                                            Text {
                                                text: modelData.connected ? "[CONNECTED]" : "[DISCONNECTED]"
                                                color: modelData.connected ? "#30D158" : "#8b949e"
                                                font { family: hudWindow.monoFont; pixelSize: Math.round(9.5 * scaleFactor); bold: true }
                                            }
                                        }
                                    }
                                }
                            }

                            // Toggle Power Button
                            Rectangle {
                                Layout.fillWidth: true
                                height: Math.round(22 * scaleFactor)
                                color: "#140c20"
                                border.color: "#BF5AF2"
                                border.width: 1
                                radius: 2

                                Text {
                                    anchors.centerIn: parent
                                    text: "TOGGLE BLUETOOTH RADIO POWER"
                                    color: "#BF5AF2"
                                    font { family: hudWindow.monoFont; pixelSize: Math.round(9.5 * scaleFactor); bold: true }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (shellRoot && shellRoot.pBtToggle) shellRoot.pBtToggle.running = true;
                                        pFetchBtInfo.running = true;
                                    }
                                }
                            }
                        }
                    }
                }

                // ── PANE 3B: AUDIOPHILE SOUND ENGINE (~330px) ─────────
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.round(320 * scaleFactor)
                    color: "#000000"
                    border.color: "#181d26"
                    border.width: 1

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Math.round(10 * scaleFactor)
                        spacing: Math.round(6 * scaleFactor)

                        // 1. Header with Live Status Pill & Multi-Player Source Selector Rail
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Math.round(5 * scaleFactor)
                            Text {
                                text: "┌─ [11] AUDIO ENGINE"
                                color: "#30D158"
                                font { family: hudWindow.monoFont; pixelSize: Math.round(11 * scaleFactor); bold: true }
                            }
                            Rectangle {
                                Layout.fillWidth: true
                                height: 1
                                color: "#212836"
                                Layout.alignment: Qt.AlignVCenter
                            }

                            // Dynamic Multi-Source Player Selector Rail (Click to Switch Active Stream)
                            RowLayout {
                                spacing: Math.round(3 * scaleFactor)
                                Repeater {
                                    model: (Players.pickable && Players.pickable.length > 0) ? Players.pickable : [null]
                                    delegate: Rectangle {
                                        readonly property var pObj: modelData
                                        readonly property bool isSelected: pObj && (pObj === Players.active)
                                        readonly property string pLabel: pObj ? (Players.labelOf(pObj) || "MEDIA") : "STANDBY"
                                        readonly property bool isPl: pObj ? pObj.isPlaying : false

                                        width: Math.round((pLabelTxt.implicitWidth + 12) * scaleFactor)
                                        height: Math.round(18 * scaleFactor)
                                        color: isSelected ? (isPl ? "#0d2516" : "#121d2b") : "#080c14"
                                        border.color: isSelected ? (isPl ? "#30D158" : "#00E5FF") : "#212836"
                                        border.width: 1
                                        radius: 2

                                        RowLayout {
                                            anchors.centerIn: parent
                                            spacing: Math.round(3 * scaleFactor)
                                            Rectangle {
                                                width: Math.round(4 * scaleFactor)
                                                height: Math.round(4 * scaleFactor)
                                                radius: 1
                                                color: isSelected ? (isPl ? "#30D158" : "#00E5FF") : "#475569"
                                            }
                                            Text {
                                                id: pLabelTxt
                                                text: pLabel.toUpperCase()
                                                color: isSelected ? "#ffffff" : "#64748B"
                                                font { family: hudWindow.monoFont; pixelSize: Math.round(8 * scaleFactor); bold: isSelected }
                                            }
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            enabled: pObj !== null
                                            onClicked: {
                                                if (pObj) Players.select(pObj);
                                            }
                                        }
                                    }
                                }
                            }

                            // Active Engine State Pill
                            Rectangle {
                                width: Math.round(62 * scaleFactor)
                                height: Math.round(18 * scaleFactor)
                                color: Players.playing ? "#0e2314" : "#141720"
                                border.color: Players.playing ? "#30D158" : "#30394a"
                                border.width: 1
                                radius: 2
                                Text {
                                    anchors.centerIn: parent
                                    text: Players.playing ? "[PLAYING]" : (Players.title ? "[PAUSED]" : "[IDLE]")
                                    color: Players.playing ? "#30D158" : (Players.title ? "#FF9F0A" : "#6B7280")
                                    font { family: hudWindow.monoFont; pixelSize: Math.round(9.5 * scaleFactor); bold: true }
                                }
                            }
                        }

                        // 2. Track Title & Artist Metadata
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1
                            Text {
                                text: Players.title || "No Media Active"
                                color: "#ffffff"
                                font { family: hudWindow.monoFont; pixelSize: Math.round(13 * scaleFactor); bold: true }
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            Text {
                                text: Players.artist || "System Media Bus // Standby"
                                color: Qt.rgba(1, 1, 1, 0.55)
                                font { family: hudWindow.monoFont; pixelSize: Math.round(10.5 * scaleFactor) }
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }

                        // 3. Audio Format & Quality Specs Strip (Real Codec & Bitrate Inspection)
                        Rectangle {
                            Layout.fillWidth: true
                            height: Math.round(22 * scaleFactor)
                            color: "#080c14"
                            border.color: "#1a2233"
                            border.width: 1

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: Math.round(8 * scaleFactor)
                                anchors.rightMargin: Math.round(8 * scaleFactor)
                                spacing: 0

                                readonly property var mediaInfo: (hudWindow.hudData && hudWindow.hudData.audio && hudWindow.hudData.audio.media) ? hudWindow.hudData.audio.media : null
                                readonly property string fmtText: mediaInfo ? mediaInfo.format : (Players.has ? (Players.source.toUpperCase() || "AUDIO STREAM") : "IDLE BUFFER")
                                readonly property string badgeText: mediaInfo ? mediaInfo.badge : (Players.has ? "STEREO • 48.0 kHz" : "STANDBY")
                                readonly property bool isLossless: mediaInfo ? mediaInfo.lossless : false
                                readonly property string posText: (mediaInfo && mediaInfo.track_pos) ? mediaInfo.track_pos : ""

                                Text {
                                    text: parent.fmtText
                                    color: parent.isLossless ? "#30D158" : "#64D2FF"
                                    font { family: hudWindow.monoFont; pixelSize: Math.round(9.5 * scaleFactor); bold: true }
                                }
                                Text { text: " │ "; color: "#212836"; font { family: hudWindow.monoFont; pixelSize: Math.round(9.5 * scaleFactor) } }
                                Text {
                                    text: parent.badgeText
                                    color: parent.isLossless ? "#00E5FF" : "#FF9F0A"
                                    font { family: hudWindow.monoFont; pixelSize: Math.round(9.5 * scaleFactor); bold: true; features: { "tnum": 1 } }
                                }
                                Item { Layout.fillWidth: true }
                                Text {
                                    visible: parent.posText !== ""
                                    text: parent.posText + " │ "
                                    color: "#64748B"
                                    font { family: hudWindow.monoFont; pixelSize: Math.round(8.5 * scaleFactor); bold: true; features: { "tnum": 1 } }
                                }
                                Rectangle {
                                    width: Math.round(5 * scaleFactor)
                                    height: Math.round(5 * scaleFactor)
                                    radius: 1
                                    color: parent.isLossless ? "#30D158" : "#0A84FF"
                                    Layout.alignment: Qt.AlignVCenter
                                }
                                Item { width: Math.round(4 * scaleFactor) }
                                Text {
                                    text: parent.isLossless ? "LOSSLESS BIT-PERFECT" : "HIGH FIDELITY"
                                    color: parent.isLossless ? "#30D158" : Qt.rgba(1, 1, 1, 0.6)
                                    font { family: hudWindow.monoFont; pixelSize: Math.round(9 * scaleFactor); bold: true }
                                }
                            }
                        }

                        // 4. Hardware Audio Destination Badge (ALC897 Direct vs External DAC)
                        Rectangle {
                            Layout.fillWidth: true
                            height: Math.round(24 * scaleFactor)
                            color: (hudWindow.hudData && hudWindow.hudData.audio && hudWindow.hudData.audio.dac_connected) ? "#0a1e12" : "#0a1320"
                            border.color: (hudWindow.hudData && hudWindow.hudData.audio && hudWindow.hudData.audio.dac_connected) ? "#30D158" : "#0A84FF"
                            border.width: 1

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: Math.round(8 * scaleFactor)
                                anchors.rightMargin: Math.round(8 * scaleFactor)
                                spacing: Math.round(8 * scaleFactor)
                                Text {
                                    text: (hudWindow.hudData && hudWindow.hudData.audio && hudWindow.hudData.audio.dac_connected) ? "󰎆" : "󰓃"
                                    color: (hudWindow.hudData && hudWindow.hudData.audio && hudWindow.hudData.audio.dac_connected) ? "#30D158" : "#0A84FF"
                                    font { family: hudWindow.iconFont; pixelSize: Math.round(11 * scaleFactor) }
                                }
                                Text {
                                    text: (hudWindow.hudData && hudWindow.hudData.audio) ? hudWindow.hudData.audio.dac_label : "DIRECT OUTPUT (PCH ALC897)"
                                    color: (hudWindow.hudData && hudWindow.hudData.audio && hudWindow.hudData.audio.dac_connected) ? "#30D158" : "#ffffff"
                                    font { family: hudWindow.monoFont; pixelSize: Math.round(9.5 * scaleFactor); bold: true }
                                }
                                Item { Layout.fillWidth: true }
                                Text {
                                    text: (hudWindow.hudData && hudWindow.hudData.audio) ? hudWindow.hudData.audio.mode_label : "PIPEWIRE DIRECT"
                                    color: (hudWindow.hudData && hudWindow.hudData.audio && hudWindow.hudData.audio.dac_connected) ? "#30D158" : "#0A84FF"
                                    font { family: hudWindow.monoFont; pixelSize: Math.round(9 * scaleFactor); bold: true }
                                }
                            }
                        }

                        // 5. Interactive Audio Controls Enclosure (Masked in hudWindow.mask for Clickability)
                        ColumnLayout {
                            id: interactiveAudioArea
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            spacing: Math.round(6 * scaleFactor)

                            // A. Live Synced Lyrics View (Real-time LRC Scrolling Terminal)
                            Rectangle {
                                id: hudLyricsBox
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                Layout.minimumHeight: Math.round(95 * scaleFactor)
                                color: "#05080e"
                                border.color: "#182030"
                                border.width: 1
                                radius: 2
                                clip: true

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: Math.round(6 * scaleFactor)
                                    spacing: Math.round(3 * scaleFactor)

                                    // Sub-Header with LRC State Indicator
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: Math.round(4 * scaleFactor)
                                        Text {
                                            text: "󰝚 SYNCED LYRICS"
                                            color: hudWindow.hudLyricsSynced ? "#30D158" : "#64D2FF"
                                            font { family: hudWindow.monoFont; pixelSize: Math.round(9.5 * scaleFactor); bold: true }
                                        }
                                        Rectangle {
                                            Layout.fillWidth: true
                                            height: 1
                                            color: "#182030"
                                            Layout.alignment: Qt.AlignVCenter
                                        }
                                        Text {
                                            text: hudWindow.hudLyricsSynced ? "[LRCLIB: SYNCED]" : (Players.has ? "[READY]" : "[STANDBY]")
                                            color: hudWindow.hudLyricsSynced ? "#30D158" : "#555566"
                                            font { family: hudWindow.monoFont; pixelSize: Math.round(8.5 * scaleFactor); bold: true }
                                        }
                                    }

                                    // Synced Lyrics Scrolling View
                                    Item {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true

                                        // Dedicated Instrumental / No Lyrics Message
                                        Item {
                                            anchors.centerIn: parent
                                            visible: hudLyricsModel.count === 0 || (hudLyricsModel.count === 1 && hudLyricsModel.get(0).time < 0)
                                            width: parent.width * 0.9
                                            height: parent.height

                                            ColumnLayout {
                                                anchors.centerIn: parent
                                                spacing: Math.round(2 * scaleFactor)
                                                Text {
                                                    text: Players.has ? (hudWindow.hudLyricsSynced ? "♪ INSTRUMENTAL BREAK ♪" : "♪ " + (Players.title || "AUDIO STREAM") + " ♪") : "STANDBY // NO MEDIA ACTIVE"
                                                    color: Qt.rgba(1, 1, 1, 0.45)
                                                    font { family: hudWindow.monoFont; pixelSize: Math.round(9.5 * scaleFactor); bold: true }
                                                    Layout.alignment: Qt.AlignHCenter
                                                }
                                                Text {
                                                    text: Players.has ? (hudWindow.hudLyricsSynced ? "VOCAL-FREE TRACK OR SECTION" : "CONNECTING TO LRCLIB TELEMETRY") : "PLAY MUSIC VIA MPD, SPOTIFY, OR CIDER"
                                                    color: "#555566"
                                                    font { family: hudWindow.monoFont; pixelSize: Math.round(8 * scaleFactor) }
                                                    Layout.alignment: Qt.AlignHCenter
                                                }
                                            }
                                        }

                                        ListView {
                                            id: hudLyricsView
                                            anchors.fill: parent
                                            clip: true
                                            model: hudLyricsModel
                                            visible: hudLyricsModel.count > 0 && hudLyricsModel.get(0).time >= 0
                                            spacing: Math.round(4 * scaleFactor)

                                            currentIndex: hudWindow.hudActiveLyricIndex
                                            preferredHighlightBegin: height * 0.35
                                            preferredHighlightEnd: height * 0.45
                                            highlightRangeMode: ListView.StrictlyEnforceRange
                                            highlightMoveDuration: 300

                                            delegate: Item {
                                                width: hudLyricsView.width
                                                height: lyricRowText.implicitHeight + Math.round(2 * scaleFactor)
                                                readonly property bool isActive: index === hudWindow.hudActiveLyricIndex
                                                readonly property bool isPast: hudWindow.hudLyricsSynced && model.time >= 0 && model.time < ((Players.has && Players.active) ? Players.active.position : 0) && !isActive

                                                RowLayout {
                                                    anchors.fill: parent
                                                    spacing: Math.round(4 * scaleFactor)

                                                    Text {
                                                        text: isActive ? "▶" : " "
                                                        color: "#30D158"
                                                        font { family: hudWindow.monoFont; pixelSize: Math.round(9.5 * scaleFactor); bold: true }
                                                        Layout.preferredWidth: Math.round(12 * scaleFactor)
                                                    }

                                                    Text {
                                                        id: lyricRowText
                                                        text: model.text.trim() === "" ? "♪" : model.text
                                                        color: isActive ? "#ffffff" : (isPast ? "#64748b" : "#475569")
                                                        font {
                                                            family: hudWindow.monoFont
                                                            pixelSize: Math.round((isActive ? 10.5 : 9.5) * scaleFactor)
                                                            bold: isActive
                                                        }
                                                        elide: Text.ElideRight
                                                        Layout.fillWidth: true
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // B. Dedicated Tactile Hardware Audio Transport Controls
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: Math.round(4 * scaleFactor)

                                // Tactile Transport Controls & Direct Stream Sink
                                RowLayout {
                                    id: hudAudioTransportRow
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: Math.round(28 * scaleFactor)
                                    spacing: Math.round(6 * scaleFactor)

                                    // PREV
                                    Rectangle {
                                        Layout.preferredWidth: Math.round(72 * scaleFactor)
                                        Layout.preferredHeight: Math.round(26 * scaleFactor)
                                        color: prevMa.pressed ? "#161c28" : "#080c14"
                                        border.color: prevMa.containsMouse ? "#3a475a" : "#212836"
                                        border.width: 1
                                        radius: 2
                                        scale: prevMa.pressed ? 0.95 : 1.0
                                        Behavior on scale { NumberAnimation { duration: 60 } }

                                        Text {
                                            anchors.centerIn: parent
                                            text: "◀◀ PREV"
                                            color: Qt.rgba(1, 1, 1, 0.75)
                                            font { family: hudWindow.monoFont; pixelSize: Math.round(9.5 * scaleFactor); bold: true }
                                        }

                                        MouseArea {
                                            id: prevMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: hudWindow.previousTrack()
                                        }
                                    }

                                    // PLAY / PAUSE (Tactile Focal Button)
                                    Rectangle {
                                        Layout.preferredWidth: Math.round(98 * scaleFactor)
                                        Layout.preferredHeight: Math.round(26 * scaleFactor)
                                        color: Players.playing ? "#0e2013" : "#080c14"
                                        border.color: Players.playing ? "#30D158" : "#0A84FF"
                                        border.width: 1
                                        radius: 2
                                        scale: playMa.pressed ? 0.95 : 1.0
                                        Behavior on scale { NumberAnimation { duration: 60 } }

                                        Text {
                                            anchors.centerIn: parent
                                            text: Players.playing ? "❚❚ PAUSE" : "▶ PLAY"
                                            color: Players.playing ? "#30D158" : "#0A84FF"
                                            font { family: hudWindow.monoFont; pixelSize: Math.round(9.5 * scaleFactor); bold: true }
                                        }

                                        MouseArea {
                                            id: playMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: hudWindow.togglePlayback()
                                        }
                                    }

                                    // NEXT
                                    Rectangle {
                                        Layout.preferredWidth: Math.round(72 * scaleFactor)
                                        Layout.preferredHeight: Math.round(26 * scaleFactor)
                                        color: nextMa.pressed ? "#161c28" : "#080c14"
                                        border.color: nextMa.containsMouse ? "#3a475a" : "#212836"
                                        border.width: 1
                                        radius: 2
                                        scale: nextMa.pressed ? 0.95 : 1.0
                                        Behavior on scale { NumberAnimation { duration: 60 } }

                                        Text {
                                            anchors.centerIn: parent
                                            text: "NEXT ▶▶"
                                            color: Qt.rgba(1, 1, 1, 0.75)
                                            font { family: hudWindow.monoFont; pixelSize: Math.round(9.5 * scaleFactor); bold: true }
                                        }

                                        MouseArea {
                                            id: nextMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: hudWindow.nextTrack()
                                        }
                                    }

                                    Item { Layout.fillWidth: true }

                                    // Real Direct Pipeline Engine Indicator
                                    Rectangle {
                                        height: Math.round(26 * scaleFactor)
                                        Layout.preferredWidth: Math.round(135 * scaleFactor)
                                        color: "#07121c"
                                        border.color: "#00E5FF"
                                        border.width: 1
                                        radius: 2

                                        RowLayout {
                                            anchors.centerIn: parent
                                            spacing: Math.round(4 * scaleFactor)
                                            Rectangle {
                                                width: Math.round(5 * scaleFactor)
                                                height: Math.round(5 * scaleFactor)
                                                radius: 1
                                                color: "#00E5FF"
                                            }
                                            Text {
                                                text: (Players.has && Players.active && Players.playerName === "mpd") ? "ENGINE: MPD DIRECT" : "ENGINE: PIPEWIRE BUS"
                                                color: "#00E5FF"
                                                font { family: hudWindow.monoFont; pixelSize: Math.round(9 * scaleFactor); bold: true }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ── PANE 3C: PERSISTENT SCRATCHPAD // RESEARCH MEMO (~386px) ───
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: "#000000"
                    border.color: "#181d26"
                    border.width: 1

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Math.round(10 * scaleFactor)
                        spacing: Math.round(6 * scaleFactor)

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Math.round(6 * scaleFactor)
                            Text {
                                text: "┌─ [12] SCRATCHPAD"
                                color: "#64D2FF"
                                font { family: hudWindow.monoFont; pixelSize: Math.round(11 * scaleFactor); bold: true }
                            }
                            Rectangle {
                                Layout.fillWidth: true
                                height: 1
                                color: "#212836"
                                Layout.alignment: Qt.AlignVCenter
                            }

                            // Interactive In-Screen Edit / Done Toggle
                            Rectangle {
                                id: editScratchBtn
                                width: Math.round(48 * scaleFactor)
                                height: Math.round(18 * scaleFactor)
                                color: "#0d1b2a"
                                border.color: "#38bdf8"
                                border.width: 1
                                radius: 2

                                Text {
                                    anchors.centerIn: parent
                                    text: "EDIT"
                                    color: "#38bdf8"
                                    font { family: hudWindow.monoFont; pixelSize: Math.round(9.5 * scaleFactor); bold: true }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        pOpenNvim.running = true;
                                    }
                                }
                            }
                        }

                        // Scratchpad Content Area (Viewer or In-Screen Editor)
                        Rectangle {
                            id: interactiveScratchArea
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            color: "#000000"
                            border.color: hudWindow.isEditingScratch ? "#64D2FF" : "#212836"
                            border.width: 1
                            clip: true

                            // 1. In-Screen Editor Mode
                            Flickable {
                                id: editorFlickable
                                visible: hudWindow.isEditingScratch
                                anchors.fill: parent
                                anchors.margins: Math.round(10 * scaleFactor)
                                contentWidth: width
                                contentHeight: scratchEditor.implicitHeight
                                boundsBehavior: Flickable.StopAtBounds

                                TextEdit {
                                    id: scratchEditor
                                    width: parent.width
                                    text: (hudWindow.hudData && hudWindow.hudData.scratchpad) ? hudWindow.hudData.scratchpad : ""
                                    color: "#64D2FF"
                                    font { family: hudWindow.monoFont; pixelSize: Math.round(11 * scaleFactor) }
                                    wrapMode: Text.Wrap
                                    selectByMouse: true
                                    focus: hudWindow.isEditingScratch

                                    Timer {
                                        id: saveTimer
                                        interval: 1000
                                        repeat: false
                                        onTriggered: {
                                            hudWindow.saveScratchText(scratchEditor.text);
                                        }
                                    }

                                    onTextChanged: {
                                        saveTimer.restart();
                                    }
                                }
                            }

                            // 2. Multi-Level Markdown & Todo Viewer Mode
                            Flickable {
                                visible: !hudWindow.isEditingScratch
                                anchors.fill: parent
                                anchors.margins: Math.round(10 * scaleFactor)
                                contentWidth: width
                                contentHeight: linesCol.implicitHeight
                                boundsBehavior: Flickable.StopAtBounds

                                ColumnLayout {
                                    id: linesCol
                                    width: parent.width
                                    spacing: Math.round(4 * scaleFactor)

                                    Repeater {
                                        model: {
                                            var raw = (hudWindow.hudData && hudWindow.hudData.scratchpad) ? hudWindow.hudData.scratchpad : "";
                                            return raw.length > 0 ? raw.split("\n") : ["No active memo recorded.", "Click [EDIT] above or press SUPER+N."];
                                        }
                                        delegate: ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 1

                                            readonly property string rawLine: modelData || ""
                                            readonly property string tLine: rawLine.trim()
                                            readonly property int lineIdx: index

                                            // Detect line types
                                            readonly property bool isH1: rawLine.startsWith("# ")
                                            readonly property bool isH2: rawLine.startsWith("## ")
                                            readonly property bool isH3: rawLine.startsWith("### ")
                                            readonly property bool isHeading: isH1 || isH2 || isH3

                                            readonly property bool isTodoUnchecked: Boolean(tLine.match(/^[-*]\s+\[ \]/))
                                            readonly property bool isTodoChecked: Boolean(tLine.match(/^[-*]\s+\[[xX]\]/))
                                            readonly property bool isTodo: isTodoUnchecked || isTodoChecked

                                            readonly property bool isBullet: !isTodo && (tLine.startsWith("- ") || tLine.startsWith("* "))
                                            readonly property bool isNumbered: !isTodo && Boolean(tLine.match(/^[0-9]+\.\s+/))
                                            readonly property bool isQuote: tLine.startsWith("> ")
                                            readonly property bool isEmpty: tLine === ""

                                            Item {
                                                visible: isEmpty
                                                height: Math.round(5 * scaleFactor)
                                                Layout.fillWidth: true
                                            }

                                            RowLayout {
                                                visible: !isEmpty
                                                Layout.fillWidth: true
                                                spacing: Math.round(8 * scaleFactor)

                                                // Prefix Badge / Checkbox / Bullet
                                                Item {
                                                    Layout.preferredWidth: Math.round(isHeading ? 24 * scaleFactor : 16 * scaleFactor)
                                                    Layout.preferredHeight: Math.round(16 * scaleFactor)
                                                    Layout.alignment: Qt.AlignTop

                                                    // Interactive Checkbox for todos
                                                    Rectangle {
                                                        visible: isTodo
                                                        anchors.centerIn: parent
                                                        width: Math.round(14 * scaleFactor)
                                                        height: Math.round(14 * scaleFactor)
                                                        color: isTodoChecked ? "#0e2013" : "#0d1b2a"
                                                        border.color: isTodoChecked ? "#30D158" : "#FF9F0A"
                                                        border.width: 1
                                                        radius: 2

                                                        Text {
                                                            anchors.centerIn: parent
                                                            text: isTodoChecked ? "✓" : " "
                                                            color: "#30D158"
                                                            font { family: hudWindow.monoFont; pixelSize: Math.round(9 * scaleFactor); bold: true }
                                                        }

                                                        MouseArea {
                                                            anchors.fill: parent
                                                            cursorShape: Qt.PointingHandCursor
                                                            onClicked: hudWindow.toggleScratchTodo(lineIdx)
                                                        }
                                                    }

                                                    // Heading Badges
                                                    Text {
                                                        visible: isHeading
                                                        anchors.centerIn: parent
                                                        text: isH1 ? "[#1]" : (isH2 ? "[#2]" : "[#3]")
                                                        color: isH1 ? "#64D2FF" : (isH2 ? "#FF9F0A" : "#BF5AF2")
                                                        font { family: hudWindow.monoFont; pixelSize: Math.round(9.5 * scaleFactor); bold: true }
                                                    }

                                                    // Standard Bullets & Numbers
                                                    Text {
                                                        visible: !isTodo && !isHeading && (isBullet || isNumbered || isQuote)
                                                        anchors.centerIn: parent
                                                        text: isBullet ? "▸" : (isQuote ? "▌" : "•")
                                                        color: isBullet ? "#30D158" : (isQuote ? "#0A84FF" : "#FF9F0A")
                                                        font { family: hudWindow.monoFont; pixelSize: Math.round(9.5 * scaleFactor); bold: true }
                                                    }
                                                }

                                                // Text Body
                                                Text {
                                                    Layout.fillWidth: true
                                                    text: {
                                                        if (isH1) return rawLine.replace(/^#\s+/, "");
                                                        if (isH2) return rawLine.replace(/^##\s+/, "");
                                                        if (isH3) return rawLine.replace(/^###\s+/, "");
                                                        if (isTodoUnchecked) return tLine.replace(/^[-*]\s+\[ \]\s*/, "");
                                                        if (isTodoChecked) return tLine.replace(/^[-*]\s+\[[xX]\]\s*/, "");
                                                        if (isBullet) return tLine.substring(2);
                                                        if (isQuote) return tLine.substring(2);
                                                        return rawLine;
                                                    }
                                                    color: {
                                                        if (isH1) return "#64D2FF";
                                                        if (isH2) return "#FF9F0A";
                                                        if (isH3) return "#BF5AF2";
                                                        if (isTodoChecked) return "#64748b";
                                                        if (isTodoUnchecked) return "#ffffff";
                                                        if (isQuote) return "#94a3b8";
                                                        return "#e2e8f0";
                                                    }
                                                    font {
                                                        family: hudWindow.monoFont
                                                        pixelSize: Math.round(isH1 ? 12 * scaleFactor : (isH2 ? 11 * scaleFactor : (isH3 ? 10.5 * scaleFactor : 10 * scaleFactor)))
                                                        bold: isHeading || isTodoUnchecked
                                                        strikeout: isTodoChecked
                                                    }
                                                    wrapMode: Text.Wrap
                                                }
                                            }

                                            // Hairline divider under H1
                                            Rectangle {
                                                visible: isH1
                                                Layout.fillWidth: true
                                                height: 1
                                                color: "#18283a"
                                                Layout.topMargin: Math.round(2 * scaleFactor)
                                                Layout.bottomMargin: Math.round(2 * scaleFactor)
                                            }
                                        }
                                    }
                                }
                            }

                            // Double-click to Edit overlay
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onDoubleClicked: {
                                    pOpenNvim.running = true;
                                }
                            }
                        }

                        // Telemetry Footer
                        RowLayout {
                            Layout.fillWidth: true
                            readonly property string sText: hudWindow.isEditingScratch ? scratchEditor.text : ((hudWindow.hudData && hudWindow.hudData.scratchpad) ? hudWindow.hudData.scratchpad : "")
                            readonly property int charCount: sText.length
                            readonly property int lineCount: sText.length > 0 ? sText.split("\n").length : 0

                            Text {
                                text: "CHARS: " + parent.charCount + " │ LINES: " + parent.lineCount + " │ UTF-8 │ SYNCED"
                                color: Qt.rgba(1, 1, 1, 0.45)
                                font { family: hudWindow.monoFont; pixelSize: Math.round(11.5 * scaleFactor); bold: true }
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: "DOUBLE-CLICK OR PRESS [EDIT] FOR NVIM"
                                color: Qt.rgba(1, 1, 1, 0.35)
                                font { family: hudWindow.monoFont; pixelSize: Math.round(11 * scaleFactor) }
                            }
                        }
                    }
                }
            }

            // VIEW 2: VERTICAL NOTIFICATION MATRIX ([09-11] Full-Height Alert Stream)
            Rectangle {
                id: notificationDeckArea
                anchors.fill: parent
                visible: hudWindow.showNotificationDeck
                color: "#000000"
                border.color: "#181d26"
                border.width: 1
                clip: true

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Math.round(10 * scaleFactor)
                    spacing: Math.round(8 * scaleFactor)

                    // Matrix Header
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Math.round(5 * scaleFactor)

                        Text {
                            text: "┌─ [10-12] ALERT FEED"
                            color: "#FF9F0A"
                            font { family: hudWindow.monoFont; pixelSize: Math.round(11 * scaleFactor); bold: true }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 10
                            height: 1
                            color: "#212836"
                            Layout.alignment: Qt.AlignVCenter
                        }

                        // Badge count pill
                        Rectangle {
                            visible: shellRoot && shellRoot.totalNotifCount > 0
                            Layout.preferredHeight: Math.round(18 * scaleFactor)
                            Layout.preferredWidth: Math.round((notifCountBadge.implicitWidth + 12) * scaleFactor)
                            radius: 2
                            color: "#2a1808"
                            border.color: "#FF9F0A"
                            border.width: 1

                            Text {
                                id: notifCountBadge
                                anchors.centerIn: parent
                                text: shellRoot ? (shellRoot.totalNotifCount + " NEW") : "0"
                                color: "#FF9F0A"
                                font { family: hudWindow.monoFont; pixelSize: Math.round(8.5 * scaleFactor); bold: true; features: { "tnum": 1 } }
                            }
                        }

                        // Clear All button
                        Rectangle {
                            visible: shellRoot && shellRoot.totalNotifCount > 0
                            Layout.preferredHeight: Math.round(18 * scaleFactor)
                            Layout.preferredWidth: Math.round(58 * scaleFactor)
                            radius: 2
                            color: clrAllMa.pressed ? "#3b1515" : (clrAllMa.containsMouse ? "#2b1010" : "#1a0c0c")
                            border.color: clrAllMa.containsMouse ? "#FF453A" : "#602020"
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: "CLEAR ALL"
                                color: "#FF453A"
                                font { family: hudWindow.monoFont; pixelSize: Math.round(9 * scaleFactor); bold: true }
                            }

                            MouseArea {
                                id: clrAllMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (shellRoot) shellRoot.clearAllNotifications();
                                }
                            }
                        }

                        // Return [✕ CLOSE] button
                        Rectangle {
                            Layout.preferredHeight: Math.round(18 * scaleFactor)
                            Layout.preferredWidth: Math.round(52 * scaleFactor)
                            radius: 2
                            color: closeDeckMa.pressed ? "#223145" : (closeDeckMa.containsMouse ? "#152030" : "#0c1522")
                            border.color: closeDeckMa.containsMouse ? "#64D2FF" : "#212836"
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: "✕ CLOSE"
                                color: "#64D2FF"
                                font { family: hudWindow.monoFont; pixelSize: Math.round(9 * scaleFactor); bold: true }
                            }

                            MouseArea {
                                id: closeDeckMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: hudWindow.showNotificationDeck = false
                            }
                        }
                    }

                    // Notifications List (Active when notifications exist)
                    ListView {
                        id: hudNotifListView
                        visible: shellRoot && shellRoot.totalNotifCount > 0
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: Math.round(10 * scaleFactor)
                        boundsBehavior: Flickable.StopAtBounds
                        model: shellRoot ? shellRoot.groupedNotifList : null

                        delegate: ColumnLayout {
                            id: groupCol
                            width: hudNotifListView.width
                            spacing: Math.round(4 * scaleFactor)

                            readonly property var groupData: modelData

                            // Group Header Bar
                            Rectangle {
                                Layout.fillWidth: true
                                height: Math.round(22 * scaleFactor)
                                color: "#0c121d"
                                border.color: "#1e293b"
                                border.width: 1
                                radius: 2

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: Math.round(6 * scaleFactor)
                                    anchors.rightMargin: Math.round(6 * scaleFactor)
                                    spacing: Math.round(6 * scaleFactor)

                                    Text {
                                        text: "󰂚"
                                        color: "#64D2FF"
                                        font { family: hudWindow.iconFont; pixelSize: Math.round(10 * scaleFactor) }
                                    }

                                    Text {
                                        text: groupData ? ((groupData.appName || "APP").toUpperCase() + " //") : "APP //"
                                        color: "#ffffff"
                                        font { family: hudWindow.monoFont; pixelSize: Math.round(9.5 * scaleFactor); bold: true }
                                    }

                                    Text {
                                        text: groupData && groupData.notifications ? ("[" + groupData.notifications.length + " ITEMS]") : "[0]"
                                        color: "#64D2FF"
                                        font { family: hudWindow.monoFont; pixelSize: Math.round(8.5 * scaleFactor); features: { "tnum": 1 } }
                                    }

                                    Item { Layout.fillWidth: true }

                                    // Group Clear button
                                    Rectangle {
                                        width: Math.round(16 * scaleFactor)
                                        height: Math.round(16 * scaleFactor)
                                        color: "transparent"
                                        radius: 2
                                        Text {
                                            anchors.centerIn: parent
                                            text: "✕"
                                            color: groupDismissMa.containsMouse ? "#FF453A" : "#555566"
                                            font { family: hudWindow.monoFont; pixelSize: Math.round(9.5 * scaleFactor); bold: true }
                                        }
                                        MouseArea {
                                            id: groupDismissMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (shellRoot && groupData) {
                                                    shellRoot.dismissNotificationGroup(groupData.appName);
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // Individual Notifications within Group
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: Math.round(5 * scaleFactor)

                                Repeater {
                                    model: groupData ? groupData.notifications : []
                                    Rectangle {
                                        id: notifCard
                                        Layout.fillWidth: true
                                        implicitHeight: notifContentCol.implicitHeight + Math.round(12 * scaleFactor)
                                        color: notifHoverMa.containsMouse ? "#0c1524" : "#060a12"
                                        border.color: notifHoverMa.containsMouse ? "#64D2FF" : "#1a2436"
                                        border.width: 1
                                        radius: 2

                                        readonly property var itemData: modelData

                                        ColumnLayout {
                                            id: notifContentCol
                                            anchors.fill: parent
                                            anchors.margins: Math.round(6 * scaleFactor)
                                            spacing: Math.round(4 * scaleFactor)

                                            // Item Header: Summary + Time + Dismiss
                                            RowLayout {
                                                Layout.fillWidth: true
                                                spacing: Math.round(4 * scaleFactor)

                                                Text {
                                                    text: "▸"
                                                    color: "#0A84FF"
                                                    font { family: hudWindow.monoFont; pixelSize: Math.round(9 * scaleFactor); bold: true }
                                                }

                                                Text {
                                                    Layout.fillWidth: true
                                                    text: itemData ? (itemData.summary || "Notification") : ""
                                                    color: "#ffffff"
                                                    font { family: hudWindow.monoFont; pixelSize: Math.round(10 * scaleFactor); bold: true }
                                                    elide: Text.ElideRight
                                                }

                                                Text {
                                                    text: itemData && itemData.time ? itemData.time : ""
                                                    color: "#555566"
                                                    font { family: hudWindow.monoFont; pixelSize: Math.round(8.5 * scaleFactor); features: { "tnum": 1 } }
                                                }

                                                // Dismiss button
                                                Rectangle {
                                                    width: Math.round(14 * scaleFactor)
                                                    height: Math.round(14 * scaleFactor)
                                                    color: itemDismissMa.containsMouse ? "#3b1515" : "transparent"
                                                    radius: 1
                                                    border.color: itemDismissMa.containsMouse ? "#FF453A" : "transparent"
                                                    border.width: 1

                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: "✕"
                                                        color: itemDismissMa.containsMouse ? "#FF453A" : "#444b58"
                                                        font { family: hudWindow.monoFont; pixelSize: Math.round(9 * scaleFactor); bold: true }
                                                    }

                                                    MouseArea {
                                                        id: itemDismissMa
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: {
                                                            if (shellRoot && itemData) {
                                                                var nId = itemData.notifId !== undefined ? itemData.notifId : itemData.id;
                                                                shellRoot.dismissNotificationSafely(nId);
                                                            }
                                                        }
                                                    }
                                                }
                                            }

                                            // Item Body Text
                                            Text {
                                                visible: text.length > 0
                                                Layout.fillWidth: true
                                                text: itemData ? (itemData.body || "") : ""
                                                color: "#8a99ad"
                                                font { family: hudWindow.monoFont; pixelSize: Math.round(9.5 * scaleFactor) }
                                                wrapMode: Text.Wrap
                                                maximumLineCount: 4
                                                elide: Text.ElideRight
                                            }

                                            // Action Buttons (if any)
                                            RowLayout {
                                                visible: itemData && itemData.actions && itemData.actions.length > 0
                                                Layout.fillWidth: true
                                                spacing: Math.round(6 * scaleFactor)

                                                Repeater {
                                                    model: (itemData && itemData.actions) ? itemData.actions : []
                                                    Rectangle {
                                                        Layout.preferredHeight: Math.round(18 * scaleFactor)
                                                        Layout.preferredWidth: actionTxt.implicitWidth + Math.round(12 * scaleFactor)
                                                        color: actionMa.pressed ? "#223145" : (actionMa.containsMouse ? "#16253a" : "#0d1b2d")
                                                        border.color: actionMa.containsMouse ? "#64D2FF" : "#1e3450"
                                                        border.width: 1
                                                        radius: 1

                                                        Text {
                                                            id: actionTxt
                                                            anchors.centerIn: parent
                                                            text: modelData.text || "ACTION"
                                                            color: "#64D2FF"
                                                            font { family: hudWindow.monoFont; pixelSize: Math.round(9.5 * scaleFactor); bold: true }
                                                        }

                                                        MouseArea {
                                                            id: actionMa
                                                            anchors.fill: parent
                                                            hoverEnabled: true
                                                            cursorShape: Qt.PointingHandCursor
                                                            onClicked: {
                                                                if (shellRoot && itemData && modelData) {
                                                                    var nId = itemData.notifId !== undefined ? itemData.notifId : itemData.id;
                                                                    shellRoot.invokeNotificationAction(nId, modelData.identifier);
                                                                }
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }

                                        MouseArea {
                                            id: notifHoverMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            z: -1
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Empty State: All Caught Up / Buffer Clear
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: !(shellRoot && shellRoot.totalNotifCount > 0)
                        visible: !(shellRoot && shellRoot.totalNotifCount > 0)
                        spacing: Math.round(10 * scaleFactor)
                        Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter

                        Item { Layout.fillHeight: true }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: "󰂛"
                            color: "#253347"
                            font { family: hudWindow.iconFont; pixelSize: Math.round(36 * scaleFactor) }
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: "[ BUFFER CLEAR // ZERO ACTIVE ALERTS ]"
                            color: "#64D2FF"
                            font { family: hudWindow.monoFont; pixelSize: Math.round(11 * scaleFactor); bold: true }
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: "ALL SUBSYSTEMS NOMINAL • DBUS LISTENER IDLE"
                            color: "#445066"
                            font { family: hudWindow.monoFont; pixelSize: Math.round(9 * scaleFactor) }
                        }

                        Item { Layout.fillHeight: true }
                    }

                    // Matrix Footer Telemetry
                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "STREAM: ACTIVE │ DBUS: RUNNING"
                            color: Qt.rgba(1, 1, 1, 0.4)
                            font { family: hudWindow.monoFont; pixelSize: Math.round(9.5 * scaleFactor); bold: true }
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: "[SUPER+N: CLOSE]"
                            color: Qt.rgba(1, 1, 1, 0.3)
                            font { family: hudWindow.monoFont; pixelSize: Math.round(9.5 * scaleFactor) }
                        }
                    }
                }
            }
        }
    }

    }
}
