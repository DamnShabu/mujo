import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../theme"

Item {
    id: root

    property bool active: false
    property string activeTool: "pen" // "pen", "arrow", "rect", "highlight", "blur"
    property color currentColor: Theme.accent
    property int strokeWidth: 3
    property var strokes: []

    visible: active
    anchors.fill: parent
    clip: true

    readonly property var colorPalette: [
        Theme.accent,
        Theme.error,
        Theme.warning,
        Theme.success,
        "#ffffff",
        "#000000"
    ]

    function undo() {
        if (strokes.length > 0) {
            strokes.pop()
            canvas.requestPaint()
        }
    }

    function clear() {
        strokes = []
        canvas.requestPaint()
    }

    // Drawing Canvas
    Canvas {
        id: canvas
        anchors.fill: parent
        renderTarget: Canvas.Image

        property var currentStroke: null

        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)

            for (var i = 0; i < root.strokes.length; i++) {
                drawStroke(ctx, root.strokes[i])
            }

            if (currentStroke) {
                drawStroke(ctx, currentStroke)
            }
        }

        function drawStroke(ctx, s) {
            if (!s) return
            ctx.save()

            if (s.tool === "pen") {
                ctx.strokeStyle = s.color
                ctx.lineWidth = s.width
                ctx.lineCap = "round"
                ctx.lineJoin = "round"
                ctx.beginPath()
                if (s.points.length > 0) {
                    ctx.moveTo(s.points[0].x, s.points[0].y)
                    for (var p = 1; p < s.points.length; p++) {
                        ctx.lineTo(s.points[p].x, s.points[p].y)
                    }
                }
                ctx.stroke()
            } else if (s.tool === "highlight") {
                ctx.strokeStyle = Theme.withAlpha(s.color, 0.35)
                ctx.lineWidth = s.width * 4
                ctx.lineCap = "square"
                ctx.beginPath()
                if (s.points.length > 0) {
                    ctx.moveTo(s.points[0].x, s.points[0].y)
                    for (var p2 = 1; p2 < s.points.length; p2++) {
                        ctx.lineTo(s.points[p2].x, s.points[p2].y)
                    }
                }
                ctx.stroke()
            } else if (s.tool === "rect") {
                ctx.strokeStyle = s.color
                ctx.lineWidth = s.width
                var rx = Math.min(s.startX, s.endX)
                var ry = Math.min(s.startY, s.endY)
                var rw = Math.abs(s.endX - s.startX)
                var rh = Math.abs(s.endY - s.startY)
                ctx.strokeRect(rx, ry, rw, rh)
            } else if (s.tool === "blur") {
                // Blackout / Redaction rectangle
                ctx.fillStyle = "#000000"
                var bx = Math.min(s.startX, s.endX)
                var by = Math.min(s.startY, s.endY)
                var bw = Math.abs(s.endX - s.startX)
                var bh = Math.abs(s.endY - s.startY)
                ctx.fillRect(bx, by, bw, bh)
            } else if (s.tool === "arrow") {
                ctx.strokeStyle = s.color
                ctx.fillStyle = s.color
                ctx.lineWidth = s.width
                ctx.lineCap = "round"

                var fromX = s.startX
                var fromY = s.startY
                var toX = s.endX
                var toY = s.endY

                var headLen = 14 + s.width
                var angle = Math.atan2(toY - fromY, toX - fromX)

                ctx.beginPath()
                ctx.moveTo(fromX, fromY)
                ctx.lineTo(toX, toY)
                ctx.stroke()

                // Arrow head
                ctx.beginPath()
                ctx.moveTo(toX, toY)
                ctx.lineTo(toX - headLen * Math.cos(angle - Math.PI / 6), toY - headLen * Math.sin(angle - Math.PI / 6))
                ctx.lineTo(toX - headLen * Math.cos(angle + Math.PI / 6), toY - headLen * Math.sin(angle + Math.PI / 6))
                ctx.closePath()
                ctx.fill()
            }

            ctx.restore()
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.CrossCursor
            enabled: root.active

            onPressed: function(mouse) {
                if (root.activeTool === "pen" || root.activeTool === "highlight") {
                    canvas.currentStroke = {
                        tool: root.activeTool,
                        color: root.currentColor,
                        width: root.strokeWidth,
                        points: [{ x: mouse.x, y: mouse.y }]
                    }
                } else {
                    canvas.currentStroke = {
                        tool: root.activeTool,
                        color: root.currentColor,
                        width: root.strokeWidth,
                        startX: mouse.x,
                        startY: mouse.y,
                        endX: mouse.x,
                        endY: mouse.y
                    }
                }
                canvas.requestPaint()
            }

            onPositionChanged: function(mouse) {
                if (!pressed || !canvas.currentStroke) return
                if (root.activeTool === "pen" || root.activeTool === "highlight") {
                    canvas.currentStroke.points.push({ x: mouse.x, y: mouse.y })
                } else {
                    canvas.currentStroke.endX = mouse.x
                    canvas.currentStroke.endY = mouse.y
                }
                canvas.requestPaint()
            }

            onReleased: function(mouse) {
                if (canvas.currentStroke) {
                    root.strokes.push(canvas.currentStroke)
                    canvas.currentStroke = null
                    canvas.requestPaint()
                }
            }
        }
    }

    // Tool button component
    component PalButton: Rectangle {
        id: pbtn
        property string toolId: ""
        property string iconName: ""
        property string toolTip: ""
        width: 28
        height: 28
        radius: 14
        color: root.activeTool === toolId ? Theme.accent : (pbtnHover.hovered ? Theme.surfaceHover : "transparent")

        Text {
            anchors.centerIn: parent
            text: pbtn.iconName
            font.family: "Material Symbols Rounded"
            font.pixelSize: 16
            color: root.activeTool === pbtn.toolId ? Theme.accentText : Theme.text
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
        HoverHandler { id: pbtnHover }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.activeTool = pbtn.toolId
        }
    }

    // Annotation Tools Palette Bar (top of selection)
    Rectangle {
        id: toolPalette
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 10
        height: 38
        width: palRow.implicitWidth + 16
        radius: 19
        color: Theme.surface
        border.color: Theme.borderStrong
        border.width: 1
        z: 9999

        RowLayout {
            id: palRow
            anchors.centerIn: parent
            spacing: 4

            PalButton { toolId: "pen"; iconName: "edit"; toolTip: "Pen" }
            PalButton { toolId: "arrow"; iconName: "arrow_outward"; toolTip: "Arrow" }
            PalButton { toolId: "rect"; iconName: "crop_square"; toolTip: "Rectangle" }
            PalButton { toolId: "highlight"; iconName: "highlight"; toolTip: "Highlighter" }
            PalButton { toolId: "blur"; iconName: "blur_on"; toolTip: "Redact / Blackout" }

            Rectangle { width: 1; height: 16; color: Theme.border }

            // Color picker chips
            Repeater {
                model: root.colorPalette
                delegate: Rectangle {
                    required property var modelData
                    width: 18
                    height: 18
                    radius: 9
                    color: modelData
                    border.color: root.currentColor === modelData ? Theme.text : Theme.border
                    border.width: root.currentColor === modelData ? 2 : 1

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.currentColor = modelData
                    }
                }
            }

            Rectangle { width: 1; height: 16; color: Theme.border }

            // Undo
            Rectangle {
                width: 28
                height: 28
                radius: 14
                color: undoHover.hovered ? Theme.surfaceHover : "transparent"
                Text {
                    anchors.centerIn: parent
                    text: "undo"
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: 16
                    color: root.strokes.length > 0 ? Theme.text : Theme.textDim
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                HoverHandler { id: undoHover }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.undo()
                }
            }
        }
    }
}
