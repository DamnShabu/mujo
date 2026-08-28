import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../theme"
import "../../components"
import "../../services"

// ClipboardList: Rich clipboard history viewer for Mujo (無常).
// Connects to `cliphist`, parses rich content types (hex colors, URLs, file paths, code),
// and provides keyboard-first instant re-copying with toast confirmations.
Item {
    id: clip

    property string query: ""
    property int selectedIndex: 0
    signal requestClose

    property var _all: []               // [{ line, preview, type, hexColor }]
    onQueryChanged: clip.selectedIndex = 0

    onVisibleChanged: if (visible) listProc.running = true

    function detectType(text) {
        var t = text.trim()
        if (/^#([0-9a-fA-F]{3,4}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$/.test(t)) {
            return { type: "color", hex: t }
        }
        if (/^https?:\/\//i.test(t)) {
            return { type: "url", hex: "" }
        }
        if (/^\/([a-zA-Z0-9_\-\.]+\/)*[a-zA-Z0-9_\-\.]*$/.test(t)) {
            return { type: "path", hex: "" }
        }
        if (/^(git|nix|systemctl|pkexec|sudo|npm|cargo|bash|curl|cat)\s/.test(t)) {
            return { type: "cmd", hex: "" }
        }
        return { type: "text", hex: "" }
    }

    Process {
        id: listProc
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                var out = [], lines = (this.text || "").split("\n")
                for (var i = 0; i < lines.length; i++) {
                    var ln = lines[i]
                    if (ln.trim() === "") continue
                    var tab = ln.indexOf("\t")
                    var prev = tab >= 0 ? ln.slice(tab + 1) : ln
                    var info = clip.detectType(prev)
                    out.push({
                        line: ln,
                        preview: prev,
                        type: info.type,
                        hexColor: info.hex
                    })
                }
                clip._all = out
                clip.selectedIndex = 0
            }
        }
    }

    readonly property var filtered: {
        var q = clip.query.trim().toLowerCase()
        if (q === "") return clip._all
        return clip._all.filter(function (e) { return e.preview.toLowerCase().indexOf(q) >= 0 })
    }

    function move(dx, dy) {
        var n = clip.filtered.length
        if (n === 0) return
        clip.selectedIndex = Math.max(0, Math.min(n - 1, clip.selectedIndex + dy))
        list.positionViewAtIndex(clip.selectedIndex, ListView.Contain)
    }
    function activateSelected() { clip.activate(clip.selectedIndex) }
    function activate(i) {
        var e = clip.filtered[i]
        if (!e) return
        Quickshell.execDetached(["bash", "-c", "printf '%s' \"$1\" | cliphist decode | wl-copy", "_", e.line])
        Notifications.notify("Copied to clipboard", e.preview.slice(0, 80), "content_paste", "low", { transient: true })
        clip.requestClose()
    }

    ListView {
        id: list
        anchors.fill: parent
        clip: true
        spacing: 4
        model: clip.filtered
        boundsBehavior: Flickable.StopAtBounds

        delegate: Rectangle {
            id: row
            required property var modelData
            required property int index
            readonly property bool sel: index === clip.selectedIndex

            width: list.width
            implicitHeight: 44
            radius: Theme.radiusMd
            color: sel
                   ? (Anim.ambient ? Theme.withAlpha(Theme.accent, 0.16) : Theme.accentDim)
                   : (rowHover.hovered ? Theme.surfaceHover : "transparent")
            border.color: sel ? Theme.accent : (rowHover.hovered ? Theme.border : "transparent")
            border.width: 1

            Behavior on color { ColorAnimation { duration: Anim.d(Anim.fast) } }
            Behavior on border.color { ColorAnimation { duration: Anim.d(Anim.fast) } }

            scale: Anim.microInteractions ? (sel ? 1.008 : (rowHover.hovered ? 1.004 : 1.0)) : 1.0
            Behavior on scale { NumberAnimation { duration: Anim.d(Anim.fast); easing.type: Anim.easeStandard } }

            // Active left bar
            Rectangle {
                anchors.left: parent.left
                anchors.leftMargin: 4
                anchors.verticalCenter: parent.verticalCenter
                width: 3.5
                height: row.sel ? 24 : 0
                radius: 2
                color: Theme.accent
                Behavior on height { NumberAnimation { duration: Anim.d(Anim.standard); easing.type: Anim.easeStandard } }
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 10

                // Type Icon or Color Swatch Preview
                Rectangle {
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    Layout.alignment: Qt.AlignVCenter
                    radius: row.modelData.type === "color" ? 14 : Theme.radiusSm
                    color: row.modelData.type === "color" && row.modelData.hexColor !== ""
                           ? row.modelData.hexColor
                           : (row.sel ? Theme.withAlpha(Theme.accent, 0.22) : Theme.surface)
                    border.color: row.modelData.type === "color" ? Theme.borderStrong : (row.sel ? Theme.withAlpha(Theme.accent, 0.4) : Theme.border)
                    border.width: 1

                    MaterialIcon {
                        anchors.centerIn: parent
                        visible: row.modelData.type !== "color"
                        iconName: row.modelData.type === "url" ? "link"
                                : (row.modelData.type === "path" ? "folder_open"
                                : (row.modelData.type === "cmd" ? "terminal" : "content_paste"))
                        pixelSize: 15
                        color: row.sel ? Theme.accent : Theme.textSecondary
                    }
                }

                // Preview Text
                Text {
                    text: row.modelData.preview
                    color: Theme.text
                    font.family: row.modelData.type === "cmd" || row.modelData.type === "color" ? Theme.fontMono : Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    Layout.fillWidth: true
                }

                // Type Badge
                Rectangle {
                    visible: row.modelData.type !== "text"
                    implicitWidth: tTag.implicitWidth + 8
                    implicitHeight: 18
                    radius: Theme.radiusSm
                    color: row.sel ? Theme.withAlpha(Theme.accent, 0.22) : Theme.surfaceActive
                    border.color: row.sel ? Theme.withAlpha(Theme.accent, 0.4) : Theme.borderStrong

                    Text {
                        id: tTag
                        anchors.centerIn: parent
                        text: row.modelData.type.toUpperCase()
                        color: row.sel ? Theme.accent : Theme.textSecondary
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeLabel - 1
                        font.bold: true
                    }
                }

                // Enter Keycap (when selected)
                Rectangle {
                    visible: row.sel
                    Layout.preferredWidth: 22
                    Layout.preferredHeight: 20
                    radius: Theme.radiusSm
                    color: Theme.withAlpha(Theme.accent, 0.22)
                    border.color: Theme.withAlpha(Theme.accent, 0.5)

                    MaterialIcon {
                        anchors.centerIn: parent
                        iconName: "keyboard_return"
                        pixelSize: 12
                        color: Theme.accent
                    }
                }
            }

            HoverHandler { id: rowHover; onHoveredChanged: if (hovered) clip.selectedIndex = row.index }
            TapHandler { onTapped: clip.activate(row.index) }
        }
    }

    LauncherEmptyState {
        anchors.centerIn: parent
        visible: clip.filtered.length === 0
        mode: "no-results"
        query: clip.query
        subject: "clipboard entries"
        subjectHint: "Copy something and it will show up here"
    }
}
