import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire

Item {
    id: root
    property var panelWindow
    property string screenName: ""

    readonly property string popupId: root.screenName + ":volume"
    readonly property bool menuOpen: PopupCoordinator.activeId === root.popupId
    implicitWidth: trigger.width
    implicitHeight: trigger.height

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

    IconButton {
        id: trigger
        iconName: root.sinkMuted || root.sinkVolume <= 0 ? "volume_off" : (root.sinkVolume < 0.5 ? "volume_down" : "volume_up")
        active: root.menuOpen
        onClicked: PopupCoordinator.toggle(root.popupId)
    }

    PopupWindow {
        id: popup
        visible: root.menuOpen
        color: "transparent"
        anchor.window: root.panelWindow
        anchor.item: trigger
        anchor.edges: Edges.Bottom | Edges.Right
        anchor.gravity: Edges.Bottom | Edges.Left
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

                SectionLabel { text: "Volume"; accented: true }

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
                        onMoved: v => { if (root.sink && root.sink.audio) root.sink.audio.volume = v }
                    }

                    Text {
                        text: Math.round(root.sinkVolume * 100) + "%"
                        color: root.sinkVolume > 1.0 ? Theme.warning : Theme.textSecondary
                        font.family: Theme.fontMono
                        font.pixelSize: 11
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
                        onMoved: v => { if (root.source && root.source.audio) root.source.audio.volume = v }
                    }

                    Text {
                        text: root.source && root.source.audio ? Math.round(root.source.audio.volume * 100) + "%" : ""
                        color: Theme.textSecondary
                        font.family: Theme.fontMono
                        font.pixelSize: 11
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
                                    font.pixelSize: 11
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                Slider {
                                    Layout.fillWidth: true
                                    from: 0
                                    to: 1.5
                                    value: appVol
                                    onMoved: v => { if (modelData.audio) modelData.audio.volume = v }
                                }
                            }

                            Text {
                                text: Math.round(appVol * 100) + "%"
                                color: appVol > 1.0 ? Theme.warning : Theme.textSecondary
                                font.family: Theme.fontMono
                                font.pixelSize: 11
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
                }

                SectionLabel { text: "Output device" }

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
                                    font.pixelSize: 11
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
