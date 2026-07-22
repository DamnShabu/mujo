import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Variants {
  model: Quickshell.screens

  PanelWindow {
    id: root
    required property var modelData
    screen: modelData

    WlrLayershell.namespace: "qs-visualizer"
    WlrLayershell.layer: WlrLayer.Background
    anchors { top: true; left: true; right: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    readonly property string confFile: Quickshell.env("HOME") + "/.config/quickshell/wallpaper.json"

    property int barCount: 40
    readonly property color barColor: Qt.color("@base05@")
    readonly property color barColorDim: Qt.color("@base02@")

    property var barHeights: []
    property string values: ""
    property bool wrapEnabled: false

    Process {
      id: confReader
      command: ["cat", root.confFile]
      running: false
      stdout: StdioCollector {
        onStreamFinished: {
          try {
            var c = JSON.parse(this.text)
            var fx = c.effects || {}
            root.wrapEnabled = !!(fx && fx.visualizerWrap)
          } catch(e) {}
        }
      }
    }

    Timer { interval: 2000; running: true; repeat: true; onTriggered: confReader.running = true }
    Component.onCompleted: confReader.running = true

    Process {
      id: audioProcess
      command: ["cava", "-p", "@cavaConf@"]
      running: true
      stdout: SplitParser {
        onRead: data => { root.values = data }
      }
    }

    onValuesChanged: {
      if (values.length === 0) return
      var raw = values.trim().split(/\s+/)
      var h = []
      for (var i = 0; i < barCount && i < raw.length; i++) {
        var v = parseFloat(raw[i])
        if (!isNaN(v)) h.push(v / 1000)
        else h.push(i < barHeights.length ? barHeights[i] : 0)
      }
      barHeights = h
    }

    Canvas {
      id: canvas
      anchors.fill: parent
      renderStrategy: Canvas.Cooperative

      onWidthChanged: requestPaint()
      onHeightChanged: requestPaint()

      Connections {
        target: root
        function onBarHeightsChanged() { canvas.requestPaint() }
        function onWrapEnabledChanged() { canvas.requestPaint() }
      }

      function bezierPoint(t, p0, p1, p2, p3) {
        var u = 1 - t
        return u*u*u*p0 + 3*u*u*t*p1 + 3*u*t*t*p2 + t*t*t*p3
      }

      onPaint: {
        var ctx = getContext("2d")
        if (!ctx) return
        ctx.reset()
        ctx.antialiasing = true

        var bars = root.barHeights
        var n = bars.length
        if (n === 0) return

        var maxH

        if (root.wrapEnabled) {
          var perimeter = 2 * (width + height)
          maxH = Math.min(width, height) * 0.15
          var step = perimeter / n

          var pts = []
          for (var i = 0; i < n; i++) {
            var dist = i * step
            var h = Math.max(2, bars[i] * maxH)
            var nx, ny, ox, oy

            if (dist < width) {
              ox = dist; oy = height
              nx = 0; ny = -1
            } else if (dist < width + height) {
              ox = width; oy = height - (dist - width)
              nx = -1; ny = 0
            } else if (dist < 2 * width + height) {
              ox = width - (dist - width - height); oy = 0
              nx = 0; ny = 1
            } else {
              ox = 0; oy = dist - 2 * width - height
              nx = 1; ny = 0
            }

            pts.push({ ox: ox, oy: oy, ix: ox + nx * h, iy: oy + ny * h })
          }

          ctx.beginPath()
          ctx.moveTo(pts[0].ox, pts[0].oy)

          for (var i = 0; i < n; i++) {
            var curr = pts[i]
            var next = pts[(i + 1) % n]

            var dx = next.ox - curr.ox
            var dy = next.oy - curr.oy
            var len = Math.sqrt(dx * dx + dy * dy)
            var tdx = dx / len
            var tdy = dy / len

            var c1x = curr.ox + tdx * len * 0.4
            var c1y = curr.oy + tdy * len * 0.4
            var c2x = next.ox - tdx * len * 0.4
            var c2y = next.oy - tdy * len * 0.4
            ctx.bezierCurveTo(c1x, c1y, c2x, c2y, next.ox, next.oy)
          }

          ctx.closePath()

          var fillGrad = ctx.createLinearGradient(0, height, 0, 0)
          fillGrad.addColorStop(0, Qt.rgba(root.barColorDim.r, root.barColorDim.g, root.barColorDim.b, 0.4))
          fillGrad.addColorStop(0.5, Qt.rgba(root.barColor.r, root.barColor.g, root.barColor.b, 0.6))
          fillGrad.addColorStop(1, Qt.rgba(root.barColor.r, root.barColor.g, root.barColor.b, 0.85))
          ctx.fillStyle = fillGrad
          ctx.fill()

          ctx.beginPath()
          ctx.moveTo(pts[0].ix, pts[0].iy)

          for (var i = 0; i < n; i++) {
            var curr = pts[i]
            var next = pts[(i + 1) % n]

            var dx = next.ix - curr.ix
            var dy = next.iy - curr.iy
            var len = Math.sqrt(dx * dx + dy * dy)
            if (len < 1) { ctx.lineTo(next.ix, next.iy); continue }
            var tdx = dx / len
            var tdy = dy / len

            var c1x = curr.ix + tdx * len * 0.4
            var c1y = curr.iy + tdy * len * 0.4
            var c2x = next.ix - tdx * len * 0.4
            var c2y = next.iy - tdy * len * 0.4
            ctx.bezierCurveTo(c1x, c1y, c2x, c2y, next.ix, next.iy)
          }

          ctx.closePath()
          ctx.strokeStyle = Qt.rgba(root.barColor.r, root.barColor.g, root.barColor.b, 0.9)
          ctx.lineWidth = 1.5
          ctx.stroke()
        } else {
          maxH = height * 0.2
          var baseY = height
          var step = n > 1 ? width / (n - 1) : 0

          ctx.beginPath()
          ctx.moveTo(0, baseY)

          for (var i = 0; i < n; i++) {
            var x = i * step
            var y = baseY - Math.max(2, bars[i] * maxH)

            if (i === 0) {
              ctx.lineTo(x, y)
            } else {
              var px = (i - 1) * step
              var py = baseY - Math.max(2, bars[i - 1] * maxH)
              var cx = (px + x) / 2
              ctx.bezierCurveTo(cx, py, cx, y, x, y)
            }
          }

          ctx.lineTo(width, baseY)
          ctx.closePath()

          var fillGrad = ctx.createLinearGradient(0, baseY, 0, baseY - maxH)
          fillGrad.addColorStop(0, Qt.rgba(root.barColorDim.r, root.barColorDim.g, root.barColorDim.b, 0.4))
          fillGrad.addColorStop(0.5, Qt.rgba(root.barColor.r, root.barColor.g, root.barColor.b, 0.6))
          fillGrad.addColorStop(1, Qt.rgba(root.barColor.r, root.barColor.g, root.barColor.b, 0.85))
          ctx.fillStyle = fillGrad
          ctx.fill()

          ctx.strokeStyle = Qt.rgba(root.barColor.r, root.barColor.g, root.barColor.b, 0.9)
          ctx.lineWidth = 1.5
          ctx.stroke()
        }
      }
    }
  }
}
