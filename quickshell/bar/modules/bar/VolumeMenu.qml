import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import "../../theme"
import "../../components"
import "../../services"

Item {
    id: root
    property var panelWindow
    property string screenName: ""

    readonly property string popupId: root.screenName + ":volume"
    readonly property bool menuOpen: PopupCoordinator.activeId === root.popupId
    implicitWidth: trigger.width
    implicitHeight: trigger.height

    readonly property bool showPercent: SettingsBus.get("bar.volume.showPercent", false)
    readonly property real stepFrac: (SettingsBus.get("bar.volume.step", 5)) / 100

    // Scroll over the pill to adjust volume (WP-17 scroll actions).
    WheelHandler {
        enabled: SettingsBus.get("bar.scrollActions", true)
        onWheel: function (e) {
            if (!root.sink || !root.sink.audio) return
            var step = e.angleDelta.y > 0 ? root.stepFrac : -root.stepFrac
            root.sink.audio.volume = Math.max(0, Math.min(1.5, root.sink.audio.volume + step))
        }
    }

    // Track the default sink/source *and* every per-application playback stream,
    // otherwise their .audio.volume/.muted don't update reactively.
    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource]
            .concat(root.appStreams)
            .filter(function(n) { return n !== null && n !== undefined })
    }

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    readonly property bool sinkMuted: root.sink && root.sink.audio ? root.sink.audio.muted : false
    readonly property real sinkVolume: root.sink && root.sink.audio ? root.sink.audio.volume : 0

    // Per-application output streams (e.g. a browser tab, a music player).
    property var appStreams: []
    function refreshStreams() {
        if (!Pipewire.nodes) { root.appStreams = []; return }
        root.appStreams = Pipewire.nodes.values.filter(function(n) {
            return n && n.isStream && (n.type & PwNodeType.AudioOutStream) === PwNodeType.AudioOutStream
        })
    }
    Connections {
        target: Pipewire.nodes
        function onValuesChanged() { root.refreshStreams() }
    }
    Component.onCompleted: root.refreshStreams()

    function streamName(n) {
        if (!n) return ""
        var p = n.properties || {}
        return p["application.name"] || p["media.name"] || n.description || n.name || "Application"
    }

    function outputSinks() {
        if (!Pipewire.nodes) return []
        return Pipewire.nodes.values.filter(function(n) {
            return n.isSink && !n.isStream && (n.type & PwNodeType.AudioSink) === PwNodeType.AudioSink
        })
    }

    Rectangle {
        id: trigger
        implicitHeight: Theme.barHeight - 6
        implicitWidth: root.showPercent ? (triggerRow.implicitWidth + 14) : 28
        radius: Theme.radiusSm
        color: root.menuOpen ? Theme.accentDim : (trigHh.hovered ? Theme.surfaceHover : "transparent")
        border.color: root.menuOpen ? Theme.accent : (trigHh.hovered ? Theme.borderStrong : "transparent")
        border.width: 1

        Behavior on color { ColorAnimation { duration: Anim.d(Anim.fast) } }
        Behavior on border.color { ColorAnimation { duration: Anim.d(Anim.fast) } }

        RowLayout {
            id: triggerRow
            anchors.centerIn: parent
            spacing: 4

            MaterialIcon {
                iconName: root.sinkMuted || root.sinkVolume <= 0 ? "volume_off" : (root.sinkVolume < 0.5 ? "volume_down" : "volume_up")
                pixelSize: 16
                color: root.menuOpen ? Theme.accent : (trigHh.hovered ? Theme.text : Theme.textSecondary)
                Layout.alignment: Qt.AlignVCenter
                Behavior on color { ColorAnimation { duration: Anim.d(Anim.fast) } }
            }

            Text {
                visible: root.showPercent
                text: root.sinkMuted ? "Mute" : (Math.round(root.sinkVolume * 100) + "%")
                color: root.menuOpen ? Theme.accent : (trigHh.hovered ? Theme.text : Theme.textSecondary)
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeSmall
                font.bold: true
                Layout.alignment: Qt.AlignVCenter
                Behavior on color { ColorAnimation { duration: Anim.d(Anim.fast) } }
            }
        }

        HoverHandler { id: trigHh; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: PopupCoordinator.toggle(root.popupId) }
    }

    PopupWindow {
        id: popup
        visible: root.menuOpen
        color: "transparent"
        anchor.window: root.panelWindow
        anchor.item: trigger
        anchor.edges: Theme.popupEdge | Edges.Right
        anchor.gravity: Theme.popupGravity | Edges.Left
        anchor.adjustment: PopupAdjustment.Slide

        implicitWidth: 340 + 32
        implicitHeight: content.implicitHeight + 28 + 32

        onClosed: PopupCoordinator.close(root.popupId)

        PopupCard {
            anchors.fill: parent
            open: root.menuOpen

            ColumnLayout {
                id: content
                anchors.fill: parent
                anchors.margins: 14
                spacing: 12

                SectionLabel { text: "Volume"; accented: true; visible: root.sink }

                // No sink at all: say so, the way the network and bluetooth menus do,
                // rather than leaving bare section headers with nothing under them.
                Text {
                    Layout.fillWidth: true
                    visible: !root.sink
                    text: "No audio device found."
                    color: Theme.textSecondary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    wrapMode: Text.WordWrap
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    visible: root.sink

                    MaterialIcon {
                        iconName: root.sinkMuted ? "volume_off" : "volume_up"
                        pixelSize: 16
                        color: Theme.textSecondary
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -4
                            cursorShape: Qt.PointingHandCursor
                            onClicked: if (root.sink && root.sink.audio) root.sink.audio.muted = !root.sink.audio.muted
                        }
                    }

                    Slider {
                        Layout.fillWidth: true
                        from: 0
                        to: 1.5
                        value: root.sinkVolume
                        valueText: Math.round(root.sinkVolume * 100) + "%"
                        onMoved: v => { if (root.sink && root.sink.audio) root.sink.audio.volume = v }
                    }

                    Text {
                        text: Math.round(root.sinkVolume * 100) + "%"
                        color: root.sinkVolume > 1.0 ? Theme.warning : Theme.textSecondary
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeSmall
                        Layout.preferredWidth: 34
                    }
                }

                SectionLabel { text: "Microphone"; accented: true; visible: root.source }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    visible: root.source

                    MaterialIcon {
                        iconName: root.source && root.source.audio && root.source.audio.muted ? "mic_off" : "mic"
                        pixelSize: 16
                        color: Theme.textSecondary
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -4
                            cursorShape: Qt.PointingHandCursor
                            onClicked: if (root.source && root.source.audio) root.source.audio.muted = !root.source.audio.muted
                        }
                    }

                    Slider {
                        Layout.fillWidth: true
                        from: 0
                        to: 1.5
                        value: root.source && root.source.audio ? root.source.audio.volume : 0
                        valueText: Math.round((root.source && root.source.audio ? root.source.audio.volume : 0) * 100) + "%"
                        onMoved: v => { if (root.source && root.source.audio) root.source.audio.volume = v }
                    }

                    Text {
                        text: root.source && root.source.audio ? Math.round(root.source.audio.volume * 100) + "%" : ""
                        color: Theme.textSecondary
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeSmall
                        Layout.preferredWidth: 34
                    }
                }

                // ---- per-application streams --------------------------------
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    Layout.topMargin: 2
                    color: Theme.border
                    visible: root.appStreams.length > 0
                }

                SectionLabel { text: "Applications"; visible: root.appStreams.length > 0 }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    visible: root.appStreams.length > 0

                    Repeater {
                        model: root.appStreams

                        delegate: RowLayout {
                            required property var modelData
                            readonly property bool appMuted: modelData.audio ? modelData.audio.muted : false
                            readonly property real appVol: modelData.audio ? modelData.audio.volume : 0
                            Layout.fillWidth: true
                            spacing: 8

                            MaterialIcon {
                                iconName: appMuted ? "volume_off" : "graphic_eq"
                                pixelSize: 15
                                color: appMuted ? Theme.textDim : Theme.accent
                                MouseArea {
                                    anchors.fill: parent
                                    anchors.margins: -4
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: if (modelData.audio) modelData.audio.muted = !modelData.audio.muted
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 4

                                Text {
                                    text: root.streamName(modelData)
                                    color: Theme.text
                                    font.pixelSize: Theme.fontSizeSmall
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                Slider {
                                    Layout.fillWidth: true
                                    from: 0
                                    to: 1.5
                                    value: appVol
                                    valueText: Math.round(appVol * 100) + "%"
                                    onMoved: v => { if (modelData.audio) modelData.audio.volume = v }
                                }
                            }

                            Text {
                                text: Math.round(appVol * 100) + "%"
                                color: appVol > 1.0 ? Theme.warning : Theme.textSecondary
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fontSizeSmall
                                Layout.preferredWidth: 34
                                horizontalAlignment: Text.AlignRight
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    Layout.topMargin: 2
                    color: Theme.border
                    visible: root.outputSinks().length > 0
                }

                SectionLabel { text: "Output device"; visible: root.outputSinks().length > 0 }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Repeater {
                        model: root.outputSinks()

                        delegate: Rectangle {
                            id: sinkRow
                            required property var modelData
                            Layout.fillWidth: true
                            implicitWidth: content.width
                            implicitHeight: 32
                            radius: Theme.radiusMd
                            color: sinkRow.modelData === root.sink ? Theme.surfaceHover : (sinkHover.hovered ? Theme.surface : "transparent")

                            HoverHandler { id: sinkHover }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                spacing: 8

                                MaterialIcon {
                                    iconName: "speaker"
                                    pixelSize: 14
                                    color: sinkRow.modelData === root.sink ? Theme.accent : Theme.textSecondary
                                }

                                Text {
                                    text: sinkRow.modelData.description || sinkRow.modelData.name
                                    color: sinkRow.modelData === root.sink ? Theme.text : Theme.textSecondary
                                    font.pixelSize: Theme.fontSizeSmall
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }

                                MaterialIcon {
                                    visible: sinkRow.modelData === root.sink
                                    iconName: "check"
                                    pixelSize: 15
                                    color: Theme.accent
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Pipewire.preferredDefaultAudioSink = sinkRow.modelData
                            }
                        }
                    }
                }
            }
        }
    }
}
