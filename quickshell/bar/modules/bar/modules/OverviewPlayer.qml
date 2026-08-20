import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell.Services.Mpris


Item {
    id: root

    property var player: null
    property real trackLength: 0
    property real trackPosition: 0
    property real progress: trackLength > 0 ? Math.min(1, trackPosition / trackLength) : 0
    property string currentArtUrl: ""
    property string pendingArtUrl: ""

    function pickPlayer() {
        var all = Mpris.players.values
        for (var i = 0; i < all.length; i++)
            if (all[i].playbackState === MprisPlaybackState.Playing) return all[i]
        return all.length > 0 ? all[0] : null
    }

    function refresh() {
        var next = pickPlayer()
        player = next
        trackPosition = player && player.position ? player.position : 0

        if (player) {
            var len = player.length
            if ((!len || len <= 0) && player.metadata) {
                var ml = player.metadata["mpris:length"]
                if (ml > 0) len = ml / 1000000
            }
            if (len > 0) trackLength = len
        } else {
            trackLength = 0
        }

        var url = artUrl()
        if (url !== "") pendingArtUrl = url
        if (pendingArtUrl !== "") currentArtUrl = pendingArtUrl
    }

    function meta(key) {
        if (!player || !player.metadata) return ""
        var v = player.metadata[key]
        if (Array.isArray(v)) return v.join(", ")
        return v || ""
    }

    function title() { return meta("xesam:title") || "Unknown Title" }
    function artist() { return meta("xesam:artist") || "no active session" }

    function artUrl() {
        var url = meta("mpris:artUrl")
        if (url === "") return ""
        if (url.startsWith("/")) url = "file://" + url
        else if (!url.includes("://")) url = "file://" + url
        return url
    }

    function formatTime(s) {
        if (!s || s <= 0) return "0:00"
        var m = Math.floor(s / 60)
        var sec = Math.floor(s % 60)
        return m + ":" + (sec < 10 ? "0" : "") + sec
    }

    function seek(fraction) {
        if (root.player && root.trackLength > 0)
            root.player.setPosition(fraction * root.trackLength * 1000000)
    }

    Component.onCompleted: refresh()

    Connections {
        target: Mpris.players
        function onValuesChanged() { root.refresh() }
    }

    Instantiator {
        model: Mpris.players.values
        delegate: Connections {
            target: modelData
            function onPlaybackStateChanged() { root.refresh() }
            function onMetadataChanged() { root.refresh() }
        }
    }

Timer {
        interval: 500
        repeat: true
        running: root.visible && root.player !== null
        onTriggered: {
            trackPosition = root.player && root.player.position ? root.player.position : 0
        }
      } // update track position at 500ms

    Rectangle {
        id: playerBg
        anchors.fill: parent
        radius: 5
        color: Theme.surface
        border.color: Theme.border
        border.width: 1
        clip: true

        Image {
            id: bgArt
            anchors.fill: parent
            source: root.currentArtUrl
            sourceSize: Qt.size(256, 256)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            visible: false
        }

        MultiEffect {
            anchors.fill: bgArt
            source: bgArt
            blurEnabled: true
            blur: 1.0
            blurMax: 48
            saturation: -0.2
        }

        Rectangle {
            anchors.fill: parent
            color: "#000000"
            opacity: 0.55
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 4

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 8

                Item {
                    Layout.preferredWidth: 65
                    Layout.preferredHeight: 65

                    Image {
                        id: art
                        anchors.fill: parent
                        anchors.margins: 1
                        source: root.currentArtUrl
                        sourceSize: Qt.size(256, 256)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: true
                        visible: false
                    }

                    MultiEffect {
                        anchors.fill: art
                        source: art
                        maskEnabled: true
                        maskSource: artMask
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: 5
                        color: "transparent"
                        border.color: Theme.border
                        border.width: 1
                    }

                    Item {
                        id: artMask
                        width: art.width
                        height: art.height
                        layer.enabled: true
                        visible: false

                        Rectangle {
                            width: art.width
                            height: art.height
                            radius: 5
                            color: "black"
                        }
                    }

                    Rectangle {
                        anchors.centerIn: parent
                        visible: art.status !== Image.Ready
                        width: 24
                        height: 24
                        radius: 12
                        color: Theme.surface

                        MaterialIcon {
                            anchors.centerIn: parent
                            iconName: "music_note"
                            pixelSize: 14
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 4

                    Row {
                        Layout.fillWidth: true
                        spacing: 4

                        MaterialIcon {
                            iconName: "bolt"
                            pixelSize: 9
                            color: Theme.accent
                            anchors.baseline: nowPlayingLabel.baseline
                        }

                        Text {
                            id: nowPlayingLabel
                            text: "NOW PLAYING"
                            color: Theme.accent
                            font.pixelSize: 9
                            font.bold: true
                            font.letterSpacing: 1.5
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            text: root.title()
                            color: Theme.text
                            font.pixelSize: 13
                            font.bold: true
                        }

                        Row {
                            spacing: 4
                            Layout.alignment: Qt.AlignRight

                            component CtrlBtn: Rectangle {
                                id: ctrl
                                property string icon: ""
                                property bool emphasized: false
                                signal clicked

                                width: 26
                                height: 26
                                radius: 5
                                color: hover.hovered ? Theme.border : "transparent"
                                border.color: emphasized ? Theme.borderInteractive : "transparent"
                                border.width: 1

                                MaterialIcon {
                                    anchors.centerIn: parent
                                    iconName: ctrl.icon
                                    pixelSize: 16
                                    color: ctrl.emphasized ? Theme.text : Theme.textSecondary
                                }

                                HoverHandler { id: hover }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: ctrl.clicked()
                                }
                            }

                            CtrlBtn {
                                icon: "skip_previous"
                                onClicked: if (root.player) root.player.previous()
                            }
                            CtrlBtn {
                                emphasized: true
                                icon: root.player && root.player.playbackState === MprisPlaybackState.Playing
                                       ? "pause" : "play_arrow"
                                onClicked: if (root.player) root.player.togglePlaying()
                            }
                            CtrlBtn {
                                icon: "skip_next"
                                onClicked: if (root.player) root.player.next()
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Text {
                            text: root.formatTime(root.trackPosition)
                            color: Theme.textSecondary
                            font.pixelSize: 9
                        }

                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 12

                            Canvas {
                                id: progressCanvas
                                anchors.fill: parent

                                property real prog: root.progress
                                property real wavePhase: 0

Timer {
                                    interval: 16
                                    repeat: true
                                    running: root.visible && root.player
                                        && root.player.playbackState === MprisPlaybackState.Playing
                                    onTriggered: {
                                        progressCanvas.wavePhase += 0.04
                                        progressCanvas.requestPaint()
                                    }
                                  } // 60fps wave animation

                                Connections {
                                    target: Theme
                                    function onAccentChanged() { progressCanvas.requestPaint() }
                                    function onTextSecondaryChanged() { progressCanvas.requestPaint() }
                                }

                                onWidthChanged: requestPaint()
                                onProgChanged: requestPaint()
                                Component.onCompleted: requestPaint()

                                onPaint: {
                                    var ctx = getContext("2d")
                                    ctx.reset()
                                    var w = width
                                    var h = height
                                    var mid = h * 0.5
                                    var dotX = w * root.progress

                                    ctx.lineWidth = 1
                                    ctx.strokeStyle = Theme.textSecondary
                                    ctx.globalAlpha = 0.3
                                    ctx.beginPath()
                                    ctx.moveTo(0, mid)
                                    ctx.lineTo(w, mid)
                                    ctx.stroke()

                                    ctx.strokeStyle = Theme.accent
                                    ctx.globalAlpha = 0.7
                                    ctx.lineWidth = 1.5
                                    ctx.beginPath()
                                    for (var x = 0; x <= dotX; x++) {
                                        var y = mid + Math.sin(x * 0.5 + wavePhase) * 3
                                        if (x === 0) ctx.moveTo(x, y)
                                        else ctx.lineTo(x, y)
                                    }
                                    ctx.stroke()
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.seek(mouse.x / width)
                                onPositionChanged: {
                                    if (pressed) root.seek(mouse.x / width)
                                }
                            }
                        }

                        Text {
                            text: root.formatTime(root.trackLength)
                            color: Theme.textSecondary
                            font.pixelSize: 9
                        }
                    }
                }
            }
        }
    }
}
