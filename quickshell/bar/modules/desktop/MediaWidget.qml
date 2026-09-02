import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris
import "../../theme"
import "../../components"
import "../../services"

// Now-playing widget. Picks the active player the same way the island does:
// prefer whatever is actually playing, else the first player that exists.
BaseWidget {
    id: root

    property var wcfg: ({})
    readonly property string mediaStyle: wcfg.style !== undefined ? wcfg.style : SettingsBus.get("desktop.media.style", "standard")
    readonly property bool showControls: wcfg.showControls !== undefined ? !!wcfg.showControls : SettingsBus.get("desktop.media.showControls", true)
    readonly property bool showArtist: wcfg.showArtist !== undefined ? !!wcfg.showArtist : SettingsBus.get("desktop.media.showArtist", true)
    readonly property string cardStyle: wcfg.cardStyle !== undefined ? wcfg.cardStyle : "glass"

    chromeless: cardStyle === "chromeless"

    readonly property var player: {
        var ps = Mpris.players ? Mpris.players.values : []
        for (var i = 0; i < ps.length; i++)
            if (ps[i].playbackState === MprisPlaybackState.Playing) return ps[i]
        return ps.length > 0 ? ps[0] : null
    }
    readonly property bool playing: player && player.playbackState === MprisPlaybackState.Playing
    readonly property bool compact: mediaStyle === "compact" || width < 260

    title: ""
    iconName: ""

    // No player at all is a normal idle state, not an error - the error overlay
    // would put a red icon on the desktop for "nothing is playing".
    Text {
        anchors.centerIn: parent
        visible: root.player === null
        text: "Nothing playing"
        color: Theme.textSecondary
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: root.chromeless ? 0 : 8
        spacing: 12
        visible: root.player !== null

        // Album Art / Vinyl Disc
        Rectangle {
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: Math.max(40, Math.min(96, root.height - 20))
            Layout.preferredHeight: Layout.preferredWidth
            radius: root.mediaStyle === "vinyl" ? Layout.preferredWidth / 2 : Theme.radiusMd
            color: Theme.surfaceActive
            clip: true

            MaterialIcon {
                anchors.centerIn: parent
                visible: art.status !== Image.Ready
                iconName: "music_note"
                pixelSize: parent.width * 0.45
                color: Theme.accent
            }

            Image {
                id: art
                anchors.fill: parent
                source: root.player && root.player.trackArtUrl ? root.player.trackArtUrl : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                // The disc never exceeds the 96 px its container caps at, so a
                // 1400x1400 cover would spend ~7 MB to paint 96x96. Same cap
                // the Overview card's copy of this art already uses.
                sourceSize.width: 96
                sourceSize.height: 96
            }

            // Vinyl center hole
            Rectangle {
                visible: root.mediaStyle === "vinyl"
                anchors.centerIn: parent
                width: 14; height: 14; radius: 7
                color: Theme.bg
                border.color: Theme.border
            }

            // Spin animation for vinyl mode
            RotationAnimation on rotation {
                running: root.mediaStyle === "vinyl" && root.playing
                loops: Animation.Infinite
                from: 0
                to: 360
                duration: 6000
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 2

            Text {
                Layout.fillWidth: true
                text: root.player ? (root.player.trackTitle || "Unknown track") : ""
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Math.max(12, Math.min(18, Math.floor(root.height * 0.16)))
                font.bold: true
                elide: Text.ElideRight
            }

            Text {
                Layout.fillWidth: true
                visible: !root.compact && root.showArtist
                text: root.player ? (root.player.trackArtist || "") : ""
                color: Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                elide: Text.ElideRight
            }

            RowLayout {
                visible: root.showControls
                spacing: 6
                Layout.topMargin: 4

                Repeater {
                    model: [
                        { icon: "skip_previous", act: "prev" },
                        { icon: root.playing ? "pause" : "play_arrow", act: "toggle" },
                        { icon: "skip_next", act: "next" }
                    ]
                    delegate: Rectangle {
                        required property var modelData
                        implicitWidth: 28
                        implicitHeight: 28
                        radius: Theme.radiusSm
                        color: btnHh.hovered ? Theme.surfaceHover : "transparent"

                        MaterialIcon {
                            anchors.centerIn: parent
                            iconName: parent.modelData.icon
                            pixelSize: 18
                            color: Theme.text
                        }
                        HoverHandler { id: btnHh; cursorShape: Qt.PointingHandCursor }
                        TapHandler {
                            onTapped: {
                                var p = root.player
                                if (!p) return
                                if (parent.modelData.act === "prev" && p.canGoPrevious) p.previous()
                                else if (parent.modelData.act === "next" && p.canGoNext) p.next()
                                else if (parent.modelData.act === "toggle" && p.canTogglePlaying) p.togglePlaying()
                            }
                        }
                    }
                }
            }
        }
    }
}
