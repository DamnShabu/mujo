import QtQuick
import QtQuick.Effects
import Quickshell


Item {
    id: root

    property var weather
    property string wallpaperPath: ""
    property string cityName: ""

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    function greeting() {
        var h = parseInt(Qt.formatDateTime(clock.date, "H"), 10)
        if (h < 5) return "Good night"
        if (h < 12) return "Good morning"
        if (h < 17) return "Good afternoon"
        return "Good evening"
    }

    Rectangle {
        anchors.fill: parent
        radius: 5
        color: Theme.bg
        border.color: Theme.border
        border.width: 1
        clip: true

        Image {
            id: clockBg
            anchors.fill: parent
            source: root.wallpaperPath !== "" ? "file://" + root.wallpaperPath : ""
            sourceSize: Qt.size(800, 450)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: false
        }

        MultiEffect {
            anchors.fill: clockBg
            source: clockBg
            maskEnabled: true
            maskSource: clockMask
        }

        Item {
            id: clockMask
            width: clockBg.width
            height: clockBg.height
            layer.enabled: true
            visible: false

            Rectangle {
                width: clockBg.width
                height: clockBg.height
                radius: 5
                color: "black"
            }
        }

        Rectangle {
            anchors.fill: parent
            color: "#000000"
            opacity: 0.4
        }

        Item {
            anchors.fill: parent
            anchors.margins: 16

            Column {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                Text {
                    text: root.greeting().toUpperCase()
                    color: Theme.accent
                    font.pixelSize: 10
                    font.bold: true
                    font.letterSpacing: 1.5
                }

                Text {
                    text: Qt.formatDateTime(clock.date, "HH:mm")
                    color: Theme.text
                    font.pixelSize: 44
                    font.bold: true
                }
            }

            Column {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Row {
                    anchors.right: parent.right
                    spacing: 6

                    MaterialIcon {
                        iconName: weather ? weather.iconName : "device_thermostat"
                        pixelSize: 16
                        color: Theme.accent
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: weather && !isNaN(weather.temperature)
                              ? (Math.round(weather.temperature) + (weather.useCelsius ? "\u00B0C" : "\u00B0F"))
                              : "--"
                        color: Theme.text
                        font.pixelSize: 20
                        font.bold: true
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Text {
                    anchors.right: parent.right
                    text: weather && weather.condition
                          ? (weather.condition + (root.cityName !== "" ? " \u00B7 " + root.cityName : ""))
                          : (root.cityName !== "" ? root.cityName : "")
                    color: Theme.text
                    font.pixelSize: 10
                }

                Text {
                    anchors.right: parent.right
                    text: Qt.formatDateTime(clock.date, "ddd, MMM d")
                    color: Theme.textSecondary
                    font.pixelSize: 9
                }
            }
        }

        Canvas {
            id: waveCanvas
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 16

            Component.onCompleted: requestPaint()

            onWidthChanged: requestPaint()

            Connections {
                target: Theme
                function onAccentChanged() { waveCanvas.requestPaint() }
                function onTextSecondaryChanged() { waveCanvas.requestPaint() }
            }

            onPaint: {
                var ctx = getContext("2d")
                ctx.reset()
                var w = width
                var h = height
                var mid = h * 0.5
                var dotX = w * 0.72

                ctx.lineWidth = 1.5

                ctx.strokeStyle = Theme.textSecondary
                ctx.globalAlpha = 0.4
                ctx.beginPath()
                for (var x = 0; x <= w; x++) {
                    var y = mid + Math.sin(x / w * Math.PI * 3.5) * (h * 0.35)
                    if (x === 0) ctx.moveTo(x, y)
                    else ctx.lineTo(x, y)
                }
                ctx.stroke()

                ctx.strokeStyle = Theme.accent
                ctx.globalAlpha = 0.6
                ctx.beginPath()
                for (var x2 = 0; x2 <= dotX; x2++) {
                    var y2 = mid + Math.sin(x2 / w * Math.PI * 3.5) * (h * 0.35)
                    if (x2 === 0) ctx.moveTo(x2, y2)
                    else ctx.lineTo(x2, y2)
                }
                ctx.stroke()

                var dotY = mid + Math.sin(dotX / w * Math.PI * 3.5) * (h * 0.35)
                ctx.globalAlpha = 0.9
                ctx.fillStyle = Theme.accent
                ctx.beginPath()
                ctx.arc(dotX, dotY, 3, 0, Math.PI * 2)
                ctx.fill()
                ctx.globalAlpha = 1.0
            }
        }
    }
}
