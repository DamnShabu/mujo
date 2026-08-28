import QtQuick
import "../../theme"
import "../../components"
import "../../services"

// Desktop audio visualizer, as an ordinary desktop widget: draggable, resizable
// and rotatable like any other, but chromeless so only the spectrum is visible.
// Replaces the old fullscreen CavaOverlay surface; the cava process + audio
// guards still live in the shared Cava singleton, which this widget reference
// counts (a cava widget existing is what makes cava run).
BaseWidget {
    id: root

    property var wcfg: ({})

    // Per-widget config wins; the cava.* settings are the defaults for new
    // widgets, so the Desktop settings page still steers every visualizer.
    readonly property string style: wcfg.style !== undefined ? wcfg.style : SettingsBus.get("cava.style", "bars")
    readonly property string colorPref: wcfg.color !== undefined ? wcfg.color : SettingsBus.get("cava.color", "")
    readonly property real fillOpacity: wcfg.opacity !== undefined ? wcfg.opacity : SettingsBus.get("cava.opacity", 0.85)
    readonly property bool reflection: wcfg.reflection !== undefined ? !!wcfg.reflection : SettingsBus.get("cava.reflection", true)
    readonly property color barColor: colorPref !== "" ? colorPref : Theme.accent

    chromeless: true
    title: ""
    iconName: ""

    Component.onCompleted: Cava.acquire()
    Component.onDestruction: Cava.release()

    Canvas {
        id: canvas
        anchors.fill: parent
        opacity: root.fillOpacity
        visible: Cava.active && Cava.levels.length > 0

        Connections { target: Cava; function onLevelsChanged() { canvas.requestPaint() } }

        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            var lv = Cava.levels
            var n = lv.length
            if (!n) return
            ctx.fillStyle = root.barColor
            ctx.strokeStyle = root.barColor

            var base = root.reflection ? height * 0.62 : height
            var maxH = base * 0.98

            if (root.style === "circle") {
                var cx = width / 2, cy = height / 2
                var r0 = Math.min(width, height) * 0.14
                for (var c = 0; c < n; c++) {
                    var ang = (c / n) * Math.PI * 2 - Math.PI / 2
                    var len = r0 + (lv[c] / 100) * (Math.min(width, height) * 0.30)
                    ctx.beginPath()
                    ctx.lineWidth = Math.max(1.5, (Math.PI * 2 * r0 / n) * 0.5)
                    ctx.moveTo(cx + Math.cos(ang) * r0, cy + Math.sin(ang) * r0)
                    ctx.lineTo(cx + Math.cos(ang) * len, cy + Math.sin(ang) * len)
                    ctx.stroke()
                }
                return
            }

            var bw = width / n
            if (root.style === "wave") {
                ctx.beginPath()
                ctx.moveTo(0, base)
                for (var w = 0; w < n; w++)
                    ctx.lineTo(w * bw + bw / 2, base - (lv[w] / 100) * maxH)
                ctx.lineTo(width, base)
                ctx.closePath()
                ctx.globalAlpha = 0.85
                ctx.fill()
                ctx.globalAlpha = 1
                if (root.reflection) root._reflect(ctx, lv, n, bw, base)
                return
            }

            var gap = bw * 0.28
            for (var b = 0; b < n; b++) {
                var h = (lv[b] / 100) * maxH
                ctx.fillRect(b * bw + gap / 2, base - h, bw - gap, h)
            }
            if (root.reflection) root._reflect(ctx, lv, n, bw, base)
        }
    }

    // Idle hint, so an unlocked cava widget with no audio is still findable
    // instead of being a completely blank rectangle.
    Text {
        anchors.centerIn: parent
        visible: !canvas.visible && !root.locked
        text: "audio visualizer"
        color: Theme.textSecondary
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
    }

    // Mirrored, fading copy below the baseline. isWave is inferred from style.
    function _reflect(ctx, lv, n, bw, base) {
        var reflMax = (ctx.canvas.height - base) * 0.9
        ctx.save()
        ctx.globalAlpha = 0.3
        if (root.style === "wave") {
            ctx.beginPath()
            ctx.moveTo(0, base)
            for (var w = 0; w < n; w++)
                ctx.lineTo(w * bw + bw / 2, base + (lv[w] / 100) * reflMax)
            ctx.lineTo(ctx.canvas.width, base)
            ctx.closePath()
            ctx.fill()
        } else {
            var gap = bw * 0.28
            for (var b = 0; b < n; b++) {
                var h = (lv[b] / 100) * reflMax
                ctx.fillRect(b * bw + gap / 2, base, bw - gap, h)
            }
        }
        ctx.restore()
    }
}
