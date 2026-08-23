import QtQuick
import Quickshell
import Quickshell.Wayland

// Desktop audio visualizer surface (WP-15). Renders the shared Cava singleton's
// levels on a per-screen click-through Bottom-layer surface. All look settings
// are render-side and live. The cava process + audio guards live in Cava.qml.
Scope {
    id: root

    readonly property bool enabled: SettingsBus.get("cava.enabled", false)
    readonly property string style: SettingsBus.get("cava.style", "bars")
    readonly property string colorPref: SettingsBus.get("cava.color", "")
    readonly property real fillOpacity: SettingsBus.get("cava.opacity", 0.85)
    readonly property real bandFraction: SettingsBus.get("cava.height", 0.18)
    readonly property string position: SettingsBus.get("cava.position", "bottom")
    readonly property bool reflection: SettingsBus.get("cava.reflection", true)
    readonly property color barColor: colorPref !== "" ? colorPref : Theme.accent

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property var modelData
            screen: modelData
            visible: root.enabled && Cava.active && Cava.levels.length > 0
            color: "transparent"

            WlrLayershell.namespace: "qs-cava"
            WlrLayershell.layer: WlrLayer.Bottom
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore
            anchors { top: true; bottom: true; left: true; right: true }
            mask: Region {}   // input passes straight through

            Canvas {
                id: canvas
                width: parent.width
                height: parent.height * root.bandFraction
                opacity: root.fillOpacity
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: root.position === "top" ? parent.top : undefined
                anchors.bottom: root.position === "bottom" ? parent.bottom : undefined
                anchors.verticalCenter: root.position === "center" ? parent.verticalCenter : undefined

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
        }
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
