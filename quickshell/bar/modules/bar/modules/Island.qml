import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris

// Floating top-center island (WP-16). A data-driven pill of modules
// (clock / media / weather / cava-mini) rendered by Bar.qml when island.enabled.
// Hover-expands to reveal media controls; auto-expands briefly on track change
// and on notification arrival (DND off), then collapses. Clock opens the
// calendar; a bell badge shows the suppressed count under DND.
//
// ponytail: media title/artist elide instead of a marquee scroll — same info,
// far less code. Add a real marquee if the truncation bites.
Item {
    id: island

    property var panelWindow
    property string screenName: ""

    readonly property var modules: SettingsBus.get("island.modules", ["clock", "media", "weather"])
    readonly property real maxW: SettingsBus.get("island.maxWidth", 520)
    readonly property real pillRadius: SettingsBus.get("island.radius", 18)
    readonly property real bgOpacity: SettingsBus.get("island.opacity", 1)
    readonly property string bgPref: SettingsBus.get("island.background", "")
    readonly property real yOffset: SettingsBus.get("island.yOffset", 0)
    readonly property int autoExpandMs: SettingsBus.get("island.autoExpandMs", 4000)
    readonly property bool expandOnNotify: SettingsBus.get("island.expandOnNotify", true)

    // Active MPRIS player: first that's playing, else the first present.
    readonly property var player: {
        var ps = Mpris.players ? Mpris.players.values : []
        if (!ps.length) return null
        for (var i = 0; i < ps.length; i++) if (ps[i] && ps[i].isPlaying) return ps[i]
        return ps[0]
    }
    readonly property bool hasMedia: modules.indexOf("media") >= 0 && player !== null

    property bool hovered: false
    property bool autoExpanded: false
    readonly property bool expanded: hovered || autoExpanded

    function pulse() { autoExpanded = true; collapse.restart() }
    Timer { id: collapse; interval: island.autoExpandMs; onTriggered: island.autoExpanded = false }

    // Auto-expand on track change.
    property string _lastTrack: ""
    Connections {
        target: island.player
        ignoreUnknownSignals: true
        function onTrackTitleChanged() {
            if (island.player && island.player.trackTitle !== island._lastTrack) {
                island._lastTrack = island.player.trackTitle
                island.pulse()
            }
        }
    }
    // Auto-expand on new notification (DND off only).
    Connections {
        target: Notifications
        function onLastPushedIdChanged() { if (island.expandOnNotify && !Notifications.dnd) island.pulse() }
    }

    implicitWidth: pill.width
    implicitHeight: Theme.barHeight
    y: yOffset

    // Entrance animation on session start.
    property real _enter: 0
    Component.onCompleted: enterAnim.start()
    NumberAnimation { id: enterAnim; target: island; property: "_enter"; from: 0; to: 1; duration: Anim.d(420); easing.type: Easing.OutBack }

    Rectangle {
        id: pill
        anchors.verticalCenter: parent.verticalCenter
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(content.implicitWidth + 24, island.maxW)
        height: Theme.barHeight
        radius: island.pillRadius
        color: island.bgPref !== "" ? island.bgPref : Theme.surface
        opacity: island.bgOpacity * (0.15 + 0.85 * island._enter)
        scale: 0.85 + 0.15 * island._enter
        border.color: Theme.border
        clip: true

        Behavior on width { NumberAnimation { duration: Anim.d(220); easing.type: Easing.OutCubic } }

        HoverHandler { onHoveredChanged: island.hovered = hovered }

        RowLayout {
            id: content
            anchors.centerIn: parent
            spacing: 12

            Repeater {
                model: island.modules
                delegate: Loader {
                    required property var modelData
                    Layout.alignment: Qt.AlignVCenter
                    sourceComponent: modelData === "clock" ? clockComp
                                   : modelData === "media" ? mediaComp
                                   : modelData === "weather" ? weatherComp
                                   : modelData === "cava-mini" ? cavaComp
                                   : null
                }
            }
        }

        // Bell badge — suppressed notification count under DND.
        Rectangle {
            visible: Notifications.dnd && Notifications.unread > 0
            anchors { top: parent.top; right: parent.right; topMargin: 2; rightMargin: 2 }
            width: 16; height: 16; radius: 8
            color: Theme.accent
            Text {
                anchors.centerIn: parent
                text: Notifications.unread > 9 ? "9+" : String(Notifications.unread)
                color: Theme.accentText
                font.family: Theme.fontFamily
                font.pixelSize: 9; font.bold: true
            }
        }
    }

    // ── Modules ────────────────────────────────────────────────────────────
    Component {
        id: clockComp
        Text {
            text: Qt.formatDateTime(clockTick.now, Theme.clock24h ? "HH:mm" : "hh:mm AP")
            color: island.calOpen ? Theme.accent : Theme.text
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontSizeBody + 1
            QtObject { id: clockTick; property date now: new Date() }
            Timer { interval: 1000; running: true; repeat: true; triggeredOnStart: true; onTriggered: clockTick.now = new Date() }
            TapHandler { onTapped: PopupCoordinator.toggle(island.calPopupId) }
        }
    }

    Component {
        id: mediaComp
        RowLayout {
            spacing: 8
            visible: island.player !== null

            Rectangle {
                Layout.preferredWidth: 22; Layout.preferredHeight: 22
                radius: 5; color: Theme.surfaceHover; clip: true
                Image {
                    anchors.fill: parent
                    source: island.player && island.player.trackArtUrl ? island.player.trackArtUrl : ""
                    fillMode: Image.PreserveAspectCrop
                    visible: status === Image.Ready
                }
                MaterialIcon {
                    anchors.centerIn: parent
                    visible: !island.player || !island.player.trackArtUrl
                    iconName: "music_note"; pixelSize: 14; color: Theme.textDim
                }
            }

            ColumnLayout {
                spacing: 0
                Layout.maximumWidth: 180
                Text {
                    Layout.fillWidth: true
                    text: island.player ? island.player.trackTitle : ""
                    color: Theme.text
                    font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSmall
                    elide: Text.ElideRight
                }
                Text {
                    Layout.fillWidth: true
                    visible: island.expanded && island.player && island.player.trackArtist
                    text: island.player ? island.player.trackArtist : ""
                    color: Theme.textSecondary
                    font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeLabel
                    elide: Text.ElideRight
                }
            }

            // Controls — revealed on expand.
            RowLayout {
                spacing: 2
                visible: island.expanded
                MaterialIcon {
                    iconName: "skip_previous"; pixelSize: 18; color: Theme.textSecondary
                    visible: island.player && island.player.canGoPrevious
                    TapHandler { onTapped: if (island.player) island.player.previous() }
                }
                MaterialIcon {
                    iconName: island.player && island.player.isPlaying ? "pause" : "play_arrow"
                    pixelSize: 20; color: Theme.text
                    TapHandler { onTapped: if (island.player) island.player.togglePlaying() }
                }
                MaterialIcon {
                    iconName: "skip_next"; pixelSize: 18; color: Theme.textSecondary
                    visible: island.player && island.player.canGoNext
                    TapHandler { onTapped: if (island.player) island.player.next() }
                }
            }
        }
    }

    Component {
        id: weatherComp
        RowLayout {
            spacing: 6
            visible: Weather.data !== null
            MaterialIcon {
                iconName: Weather.data ? Weather.iconFor(Weather.data.code) : "cloud"
                pixelSize: 16; color: Theme.textSecondary
            }
            Text {
                text: Weather.data ? Math.round(Weather.data.temp) + Weather.unitSymbol() : ""
                color: Theme.text
                font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSmall
            }
        }
    }

    Component {
        id: cavaComp
        Canvas {
            id: mini
            implicitWidth: 56; implicitHeight: Theme.barHeight - 16
            Connections { target: Cava; function onLevelsChanged() { mini.requestPaint() } }
            onPaint: {
                var ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                var lv = Cava.levels
                if (!lv.length) return
                ctx.fillStyle = Theme.accent
                var step = Math.max(1, Math.floor(lv.length / 14))   // downsample to ~14 bars
                var bars = []
                for (var i = 0; i < lv.length; i += step) bars.push(lv[i])
                var bw = width / bars.length
                for (var b = 0; b < bars.length; b++) {
                    var h = Math.max(1, (bars[b] / 100) * height)
                    ctx.fillRect(b * bw + bw * 0.2, height - h, bw * 0.6, h)
                }
            }
        }
    }

    // ── Calendar popup (clock module) ────────────────────────────────────────
    readonly property string calPopupId: island.screenName + ":island-cal"
    readonly property bool calOpen: PopupCoordinator.activeId === island.calPopupId

    PopupWindow {
        visible: island.calOpen && island.panelWindow
        color: "transparent"
        anchor.window: island.panelWindow
        anchor.item: pill
        anchor.edges: Theme.popupEdge
        anchor.gravity: Theme.popupGravity
        anchor.adjustment: PopupAdjustment.Slide
        implicitWidth: 260 + 32
        implicitHeight: cal.implicitHeight + 28 + 32
        onClosed: PopupCoordinator.close(island.calPopupId)
        PopupCard {
            anchors.fill: parent
            open: island.calOpen
            CalendarMenu { id: cal; anchors.fill: parent; anchors.margins: 14 }
        }
    }
}
