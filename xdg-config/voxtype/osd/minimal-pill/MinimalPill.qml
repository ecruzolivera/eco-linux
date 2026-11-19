// Minimal voxtype OSD: black rounded box, five centre bars driven by voice level.
import QtQuick

Item {
    id: root
    property string daemonState: "idle"
    property var audio: null
    property var theme: null
    property var recipe: null
    property string assetRoot: ""
    property var session: null
    property var outcome: null

    readonly property bool live: daemonState === "recording" || daemonState === "streaming"
    readonly property bool busy: daemonState === "transcribing"

    property real level: 0
    property real phase: 0
    property real _last: Date.now()

    // peak -> 0..1 on a -52..-6 dBFS scale
    function rawLevel() {
        const p = audio ? (audio.peak || 0) : 0;
        if (p <= 0) return 0;
        return Math.max(0, Math.min(1, (20 * Math.log10(p) + 52) / 46));
    }

    Timer {
        interval: 16; repeat: true
        running: root.daemonState !== "idle" && root.daemonState !== ""
        onRunningChanged: { root._last = Date.now(); if (running) root.level = 0; }
        onTriggered: {
            const now = Date.now();
            const dt = Math.min(0.06, (now - root._last) / 1000); root._last = now;
            root.phase += dt;
            const target = root.live ? root.rawLevel() : 0;
            const k = target > root.level ? 18 : 7;   // fast attack, slower release
            root.level += (target - root.level) * Math.min(1, k * dt);
            canvas.requestPaint();
        }
    }

    Rectangle {
        id: box
        width: 76; height: 32
        radius: 10
        color: "#000000"
        opacity: 0.92
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.06)
        x: (root.width - width) / 2
        y: root.height - height - 48 - 4 * height
    }

    Canvas {
        id: canvas
        anchors.fill: box
        onPaint: {
            const ctx = getContext("2d");
            const W = width, H = height, cy = H / 2, t = root.phase;
            ctx.reset();
            ctx.fillStyle = root.busy ? "rgba(255,255,255,0.55)" : "rgba(255,255,255,0.95)";
            const n = 5, bw = 4, gap = 5, shape = [0.45, 0.75, 1.0, 0.75, 0.45];
            const x0 = (W - (n * bw + (n - 1) * gap)) / 2;
            for (let i = 0; i < n; i++) {
                const v = root.busy
                    ? 0.25 + 0.35 * Math.max(0, Math.sin(t * 6 - i * 0.9))
                    : 0.12 + 0.88 * root.level * shape[i] * (0.8 + 0.2 * Math.sin(t * 11 + i * 1.7));
                const h = Math.max(bw, v * (H - 12)), x = x0 + i * (bw + gap), y = cy - h / 2, r = bw / 2;
                ctx.beginPath();
                ctx.moveTo(x, y + r);
                ctx.arc(x + r, y + r, r, Math.PI, 0);
                ctx.lineTo(x + bw, y + h - r);
                ctx.arc(x + r, y + h - r, r, 0, Math.PI);
                ctx.closePath();
                ctx.fill();
            }
        }
    }
}
