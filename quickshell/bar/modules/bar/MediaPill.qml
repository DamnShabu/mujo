import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import "../../theme"
import "../../components"
import "../../services"

Item {
    id: root
    property var panelWindow
    property string screenName: ""

    // Active MPRIS player: first that's playing, else the first present.
    readonly property var player: {
        var ps = Mpris.players ? Mpris.players.values : []
        if (!ps.length) return null
        for (var i = 0; i < ps.length; i++) {
            if (ps[i] && (ps[i].isPlaying || ps[i].playbackState === MprisPlaybackState.Playing)) return ps[i]
        }
        return ps[0]
    }
    readonly property bool isPlaying: player ? (player.isPlaying || player.playbackState === MprisPlaybackState.Playing) : false
    readonly property string trackTitle: player ? (player.trackTitle || player.title || "") : ""
    readonly property string trackArtist: player ? (player.trackArtist || player.artist || "") : ""

    readonly property bool hasMedia: player !== null && (trackTitle.length > 0 || isPlaying)
    readonly property bool barVisible: root.hasMedia
    visible: root.barVisible
    implicitWidth: visible ? contentRow.implicitWidth + Theme.barItemPadding * 2 : 0
    implicitHeight: Theme.barHeight
    Layout.alignment: Qt.AlignVCenter

    Rectangle {
        anchors.centerIn: parent
        width: parent.width
        height: Theme.barItemHeight
        radius: Theme.radiusSm
        color: mediaHover.hovered ? Theme.surfaceHover : "transparent"

        HoverHandler { id: mediaHover; cursorShape: Qt.PointingHandCursor }
        TapHandler {
            onTapped: {
                if (root.panelWindow) {
                    PopupCoordinator.toggle(root.screenName + ":media")
                }
            }
        }

        RowLayout {
            id: contentRow
            anchors.centerIn: parent
            spacing: 6

            MaterialIcon {
                iconName: root.isPlaying ? "graphic_eq" : "music_note"
                pixelSize: 14
                color: root.isPlaying ? Theme.accent : Theme.textSecondary
            }

            Text {
                text: {
                    var t = root.trackTitle || "No Media"
                    var a = root.trackArtist ? " • " + root.trackArtist : ""
                    var s = t + a
                    return s.length > 24 ? s.substring(0, 22) + "…" : s
                }
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                elide: Text.ElideRight
            }
        }
    }
}
