import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import "../../theme"
import "../../components"
import "../../services"

// Island: Mujo Living Central Vitality Capsule (無常)
// Floating top-center adaptive capsule that unifies diurnal circadian flow,
// real-time audio harmonic visualization, weather vitality, and alert resonance.
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
    readonly property bool isPlaying: hasMedia && player.isPlaying

    property bool hovered: false
    property bool autoExpanded: false
    readonly property bool expanded: hovered || autoExpanded

    function pulse() {
        autoExpanded = true
        collapse.restart()
    }
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
    NumberAnimation { id: enterAnim; target: island; property: "_enter"; from: 0; to: 1; duration: Anim.d(Anim.deliberate); easing.type: Easing.OutBack }

    Rectangle {
        id: pill
        anchors.verticalCenter: parent.verticalCenter
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(content.implicitWidth + (island.expanded ? 32 : 24), island.maxW)
        height: Theme.barHeight
        radius: island.pillRadius
        color: island.bgPref !== "" ? island.bgPref : Theme.surface
        opacity: island.bgOpacity * (0.15 + 0.85 * island._enter)
        scale: 0.85 + 0.15 * island._enter
        border.color: island.hovered ? Theme.borderStrong : Theme.border
        border.width: 1
        clip: true

        Behavior on width {
            NumberAnimation {
                duration: Anim.d(Anim.slow)
                easing.type: Anim.easeStandard
            }
        }
        Behavior on border.color { ColorAnimation { duration: Anim.d(Anim.fast) } }

        // Living Capsule Sub-surface Luminescence
        BarAura {
            auraColor: Theme.accent
            hovered: island.hovered
            active: island.expanded || island.isPlaying
            radius: island.pillRadius
        }

        HoverHandler {
            onHoveredChanged: {
                island.hovered = hovered
            }
        }

        RowLayout {
            id: content
            anchors.centerIn: parent
            spacing: island.expanded ? 14 : 10

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
            anchors { top: parent.top; right: parent.right; topMargin: 2; rightMargin: 4 }
            width: 16; height: 16; radius: 8
            color: Theme.accent

            Text {
                anchors.centerIn: parent
                text: Notifications.unread > 9 ? "9+" : String(Notifications.unread)
                color: Theme.accentText
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeLabel - 1; font.bold: true
            }
        }
    }

    // ── Modules ────────────────────────────────────────────────────────────
    Component {
        id: clockComp
        RowLayout {
            spacing: 6
            Layout.alignment: Qt.AlignVCenter

            // Status indicator pip
            Rectangle {
                width: 5
                height: 5
                radius: 2.5
                color: Theme.accent
                Layout.alignment: Qt.AlignVCenter
            }

            Text {
                text: Qt.formatDateTime(clockTick.now, Theme.clock24h ? "HH:mm" : "hh:mm AP")
                color: island.calOpen ? Theme.accent : Theme.text
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeBody + 1
                font.bold: true
                Layout.alignment: Qt.AlignVCenter

                QtObject { id: clockTick; property date now: new Date() }
                Timer { interval: 1000; running: true; repeat: true; triggeredOnStart: true; onTriggered: clockTick.now = new Date() }

                TapHandler {
                    onTapped: {
                        PopupCoordinator.toggle(island.calPopupId)
                    }
                }
            }
        }
    }

    Component {
        id: mediaComp
        RowLayout {
            spacing: 8
            visible: island.player !== null
            Layout.alignment: Qt.AlignVCenter

            Rectangle {
                Layout.preferredWidth: 22; Layout.preferredHeight: 22
                radius: 6; color: Theme.surfaceHover; clip: true
                Layout.alignment: Qt.AlignVCenter

                Image {
                    anchors.fill: parent
                    source: island.player && island.player.trackArtUrl ? island.player.trackArtUrl : ""
                    fillMode: Image.PreserveAspectCrop
                    sourceSize.width: 44
                    sourceSize.height: 44
                    smooth: true
                    visible: status === Image.Ready
                }
                MaterialIcon {
                    anchors.centerIn: parent
                    visible: !island.player || !island.player.trackArtUrl
                    iconName: "music_note"; pixelSize: 14
                    color: island.isPlaying ? Theme.accent : Theme.textDim
                }
            }

            ColumnLayout {
                spacing: 0
                Layout.maximumWidth: island.expanded ? 240 : 160
                Layout.alignment: Qt.AlignVCenter

                Text {
                    Layout.fillWidth: true
                    text: island.player ? island.player.trackTitle : ""
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    font.bold: island.isPlaying
                    elide: Text.ElideRight
                }
                Text {
                    Layout.fillWidth: true
                    visible: island.expanded && island.player && island.player.trackArtist
                    text: island.player ? island.player.trackArtist : ""
                    color: Theme.textSecondary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeLabel
                    elide: Text.ElideRight
                }
            }

            // Controls — revealed on expand
            RowLayout {
                spacing: 4
                visible: island.expanded
                Layout.alignment: Qt.AlignVCenter

                MaterialIcon {
                    iconName: "skip_previous"; pixelSize: 18; color: Theme.textSecondary
                    visible: island.player && island.player.canGoPrevious
                    TapHandler { onTapped: { if (island.player) island.player.previous() } }
                }
                MaterialIcon {
                    iconName: island.player && island.player.isPlaying ? "pause_circle" : "play_circle"
                    pixelSize: 22; color: Theme.accent
                    TapHandler { onTapped: { if (island.player) island.player.togglePlaying() } }
                }
                MaterialIcon {
                    iconName: "skip_next"; pixelSize: 18; color: Theme.textSecondary
                    visible: island.player && island.player.canGoNext
                    TapHandler { onTapped: { if (island.player) island.player.next() } }
                }
            }
        }
    }

    Component {
        id: weatherComp
        RowLayout {
            spacing: 6
            visible: Weather.data !== null
            Layout.alignment: Qt.AlignVCenter

            MaterialIcon {
                iconName: Weather.data ? Weather.iconFor(Weather.data.code) : "cloud"
                pixelSize: 16
                color: island.hovered ? Theme.accent : Theme.textSecondary
                opacity: island.visible && Anim.ambient ? Anim.shimmer(0.7, 1.0) : 0.85
                Behavior on color { ColorAnimation { duration: Anim.d(Anim.fast) } }
            }
            Text {
                text: Weather.data ? Math.round(Weather.data.temp) + Weather.unitSymbol() : ""
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
            }
        }
    }

    Component {
        id: cavaComp
        Canvas {
            id: mini
            implicitWidth: 56; implicitHeight: Theme.barHeight - 16
            Layout.alignment: Qt.AlignVCenter
            Connections { target: Cava; function onLevelsChanged() { mini.requestPaint() } }
            onPaint: {
                var ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                var lv = Cava.levels
                if (!lv.length) return
                ctx.fillStyle = Theme.accent
                var step = Math.max(1, Math.floor(lv.length / 14))
                var bars = []
                for (var i = 0; i < lv.length; i += step) bars.push(lv[i])
                var bw = width / bars.length
                for (var b = 0; b < bars.length; b++) {
                    var h = Math.max(1.5, (bars[b] / 100) * height)
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
