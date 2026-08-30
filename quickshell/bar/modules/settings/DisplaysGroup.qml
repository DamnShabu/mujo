import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../theme"
import "../../components"

// Displays. Reads live state from `niri msg -j outputs` and applies changes with
// `niri msg output …` (resolution, refresh, scale, on/off). niri applies these
// immediately for the session; the *persistent* source of truth stays the NixOS
// niri `outputs` block, so this is a live control surface, not a second config
// store (hence the note in the arrangement card).
ColumnLayout {
    id: root
    Layout.fillWidth: true
    spacing: 14

    property var outputs: []

    function refresh() { outProc.running = true }
    // Apply a `niri msg output` command, then re-read so the UI reflects reality.
    function apply(args) {
        Quickshell.execDetached(["niri", "msg", "output"].concat(args))
        reRead.restart()
    }

    Process {
        id: outProc
        command: ["niri", "msg", "-j", "outputs"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var obj = JSON.parse(this.text)
                    var arr = []
                    for (var k in obj) {
                        var o = obj[k]
                        arr.push({
                            name: o.name,
                            make: o.make || "",
                            model: o.model || "",
                            modes: o.modes || [],
                            currentIdx: (o.current_mode !== null && o.current_mode !== undefined) ? o.current_mode : -1,
                            on: !!o.logical,
                            scale: o.logical ? o.logical.scale : 1.0,
                            transform: o.logical ? o.logical.transform : "Normal",
                            x: o.logical ? o.logical.x : 0,
                            y: o.logical ? o.logical.y : 0,
                            lw: o.logical ? o.logical.width : 1920,
                            lh: o.logical ? o.logical.height : 1080
                        })
                    }
                    arr.sort(function(a, b) { return a.name < b.name ? -1 : 1 })
                    root.outputs = arr
                } catch (e) { root.outputs = [] }
            }
        }
    }
    Component.onCompleted: refresh()
    Timer { id: reRead; interval: 450; onTriggered: root.refresh() }

    // ── mode helpers ─────────────────────────────────────────────────────────
    function resList(modes) {
        var seen = {}, out = []
        for (var i = 0; i < modes.length; i++) {
            var r = modes[i].width + "x" + modes[i].height
            if (!seen[r]) { seen[r] = 1; out.push({ res: r, area: modes[i].width * modes[i].height }) }
        }
        out.sort(function(a, b) { return b.area - a.area })
        return out.map(function(x) { return x.res })
    }
    function curRes(o) {
        var m = o.modes[o.currentIdx]
        return m ? (m.width + "x" + m.height) : ""
    }
    function curRefresh(o) {
        var m = o.modes[o.currentIdx]
        return m ? m.refresh_rate : 0
    }
    function refreshList(modes, res) {
        var out = []
        for (var i = 0; i < modes.length; i++)
            if ((modes[i].width + "x" + modes[i].height) === res && out.indexOf(modes[i].refresh_rate) < 0)
                out.push(modes[i].refresh_rate)
        out.sort(function(a, b) { return b - a })
        return out
    }
    function hz(rate) { return (Math.round(rate / 100) / 10) }

    function applyRes(o, res) {
        // Keep the current refresh if this resolution offers it; else its highest.
        var rates = refreshList(o.modes, res)
        var rate = (rates.indexOf(curRefresh(o)) >= 0) ? curRefresh(o) : rates[0]
        root.apply([o.name, "mode", res + "@" + (rate / 1000)])
    }
    function applyRefresh(o, rate) {
        root.apply([o.name, "mode", curRes(o) + "@" + (rate / 1000)])
    }

    readonly property var scaleSteps: [1.0, 1.25, 1.5, 1.75, 2.0]

    MujoCard {
        title: "Arrangement"
        iconName: "monitor"
        isNixos: true
        collapsible: false

        actions: DialogButton {
            text: "Save to NixOS"
            primary: true
            onClicked: Quickshell.execDetached(["mujo", "niri", "save-apply"])
        }

        SectionLabel { text: "Drag to arrange" }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 220
            radius: Theme.radiusMd
            color: Theme.bg
            border.color: Theme.border
            clip: true

            Item {
                id: canvas
                anchors.fill: parent
                anchors.margins: 16

                // world bounds across enabled outputs
                readonly property var activeOutputs: root.outputs.filter(function(o) { return o.on })  // was `enabled`: shadowed Item.enabled
                readonly property real minX: activeOutputs.length ? Math.min.apply(null, activeOutputs.map(function(o) { return o.x })) : 0
                readonly property real minY: activeOutputs.length ? Math.min.apply(null, activeOutputs.map(function(o) { return o.y })) : 0
                readonly property real maxX: activeOutputs.length ? Math.max.apply(null, activeOutputs.map(function(o) { return o.x + o.lw })) : 1920
                readonly property real maxY: activeOutputs.length ? Math.max.apply(null, activeOutputs.map(function(o) { return o.y + o.lh })) : 1080
                readonly property real worldW: Math.max(1, maxX - minX)
                readonly property real worldH: Math.max(1, maxY - minY)
                readonly property real s: Math.min(width / worldW, height / worldH) * 0.86
                readonly property real offX: (width - worldW * s) / 2
                readonly property real offY: (height - worldH * s) / 2

                Repeater {
                    model: canvas.activeOutputs
                    delegate: Rectangle {
                        id: mon
                        required property var modelData
                        width: modelData.lw * canvas.s
                        height: modelData.lh * canvas.s
                        x: canvas.offX + (modelData.x - canvas.minX) * canvas.s
                        y: canvas.offY + (modelData.y - canvas.minY) * canvas.s
                        radius: 6
                        color: dragArea.drag.active ? Theme.accentDim : Theme.surfaceActive
                        border.color: Theme.accent
                        border.width: dragArea.drag.active ? 2 : 1
                        Behavior on color { ColorAnimation { duration: Anim.d(Anim.fast) } }

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 0
                            Text { Layout.alignment: Qt.AlignHCenter; text: mon.modelData.name; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSmall; font.bold: true }
                            Text { Layout.alignment: Qt.AlignHCenter; text: root.curRes(mon.modelData); color: Theme.textSecondary; font.family: Theme.fontMono; font.pixelSize: Theme.fontSizeLabel }
                        }

                        MouseArea {
                            id: dragArea
                            anchors.fill: parent
                            cursorShape: Qt.SizeAllCursor
                            drag.target: mon
                            drag.axis: Drag.XAndYAxis
                            onReleased: {
                                // back-project to logical coords, snap to 10px
                                var lx = Math.round(((mon.x - canvas.offX) / canvas.s + canvas.minX) / 10) * 10
                                var ly = Math.round(((mon.y - canvas.offY) / canvas.s + canvas.minY) / 10) * 10
                                root.apply([mon.modelData.name, "position", "set", String(lx), String(ly)])
                            }
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: canvas.activeOutputs.length === 0
                    text: "No enabled outputs"
                    color: Theme.textDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeBody
                }
            }
        }

        Text {
            Layout.fillWidth: true
            text: "Changes preview instantly. “Save to NixOS” writes the current "
                + "layout into the niri configuration (the single source of truth) "
                + "and rebuilds so it survives reboot."
            color: Theme.textDim
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            wrapMode: Text.WordWrap
        }
    }

    Repeater {
        model: root.outputs

        delegate: MujoCard {
            id: card
            required property var modelData

            title: card.modelData.name
            iconName: "desktop_windows"
            badgeText: card.modelData.on ? "ON" : "OFF"
            badgeColor: card.modelData.on ? Theme.success : Theme.textDim

            actions: ToggleSwitch {
                checked: card.modelData.on
                onToggled: function(c) { root.apply([card.modelData.name, c ? "on" : "off"]) }
            }

            Text {
                text: (card.modelData.make + " " + card.modelData.model).trim() || "Display"
                color: Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            ColumnLayout {
                visible: card.modelData.on
                Layout.fillWidth: true
                spacing: 8
                SectionLabel { text: "Resolution" }
                Flow {
                    Layout.fillWidth: true
                    spacing: 7
                    Repeater {
                        model: root.resList(card.modelData.modes)
                        delegate: DisplayChip {
                            required property var modelData
                            label: modelData
                            selected: modelData === root.curRes(card.modelData)
                            onClicked: root.applyRes(card.modelData, modelData)
                        }
                    }
                }
            }

            ColumnLayout {
                visible: card.modelData.on
                Layout.fillWidth: true
                spacing: 8
                SectionLabel { text: "Refresh rate" }
                Flow {
                    Layout.fillWidth: true
                    spacing: 7
                    Repeater {
                        model: root.refreshList(card.modelData.modes, root.curRes(card.modelData))
                        delegate: DisplayChip {
                            required property var modelData
                            label: root.hz(modelData) + " Hz"
                            selected: modelData === root.curRefresh(card.modelData)
                            onClicked: root.applyRefresh(card.modelData, modelData)
                        }
                    }
                }
            }

            ColumnLayout {
                visible: card.modelData.on
                Layout.fillWidth: true
                spacing: 8
                SectionLabel { text: "Scale" }
                Flow {
                    Layout.fillWidth: true
                    spacing: 7
                    Repeater {
                        model: root.scaleSteps
                        delegate: DisplayChip {
                            required property var modelData
                            label: modelData.toFixed(2) + "×"
                            selected: Math.abs(modelData - card.modelData.scale) < 0.01
                            onClicked: root.apply([card.modelData.name, "scale", String(modelData)])
                        }
                    }
                }
            }

            Text {
                visible: card.modelData.on
                text: "Position " + card.modelData.x + ", " + card.modelData.y
                    + "   ·   Transform " + card.modelData.transform
                color: Theme.textDim
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeSmall
            }
        }
    }
}
