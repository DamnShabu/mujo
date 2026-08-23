import QtQuick
import Quickshell
import Quickshell.Io

// Clipboard history mode (WP-10). Lists `cliphist list` (populated by the
// wl-cliphist user service); selecting an entry re-copies it via
// `cliphist decode | wl-copy` and toasts — never force-pastes. Keyboard-first;
// the launcher search field filters the previews.
Item {
    id: clip

    property string query: ""
    property int selectedIndex: 0
    signal requestClose

    property var _all: []               // [{ line, preview }]
    onQueryChanged: clip.selectedIndex = 0

    // Refresh whenever we become visible (parked otherwise).
    onVisibleChanged: if (visible) listProc.running = true

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
                    out.push({ line: ln, preview: tab >= 0 ? ln.slice(tab + 1) : ln })
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
        spacing: 3
        model: clip.filtered
        boundsBehavior: Flickable.StopAtBounds

        delegate: Rectangle {
            id: row
            required property var modelData
            required property int index
            readonly property bool sel: index === clip.selectedIndex
            width: list.width
            height: 40
            radius: Theme.radiusMd
            color: sel ? Theme.accentDim : (rowHover.hovered ? Theme.surfaceHover : "transparent")
            border.color: sel ? Theme.accent : "transparent"
            Behavior on color { ColorAnimation { duration: Anim.d(Anim.fast) } }

            Row {
                anchors.left: parent.left; anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 12; anchors.rightMargin: 12
                spacing: 12
                MaterialIcon { anchors.verticalCenter: parent.verticalCenter; iconName: "content_copy"; pixelSize: 16; color: row.sel ? Theme.accent : Theme.textDim }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: row.width - 60
                    text: row.modelData.preview
                    color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSmall
                    elide: Text.ElideRight; maximumLineCount: 1
                }
            }
            HoverHandler { id: rowHover; onHoveredChanged: if (hovered) clip.selectedIndex = row.index }
            TapHandler { onTapped: clip.activate(row.index) }
        }
    }

    Column {
        anchors.centerIn: parent
        visible: clip.filtered.length === 0
        spacing: 6
        MaterialIcon { anchors.horizontalCenter: parent.horizontalCenter; iconName: "content_paste_off"; pixelSize: 34; color: Theme.textDim }
        Text { anchors.horizontalCenter: parent.horizontalCenter; text: clip.query.trim() !== "" ? "No clips match" : "Clipboard history is empty"; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeBody }
    }
}
