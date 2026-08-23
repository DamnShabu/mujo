import QtQuick
import Quickshell
import Quickshell.Widgets

// "All apps" grid mode for the launcher (WP-06). A virtualized GridView of
// DesktopEntries with category chips, a favourites row, and a recents row in the
// header. Star toggles write apps.favorites[]; recents come from apps.recent[]
// (maintained by the Launch singleton). Fuzzy filter on the shared query.
// Keyboard nav is driven by the launcher's search field via move()/activate().
Item {
    id: grid

    property string screenName: ""
    property string query: ""
    property int selectedIndex: 0
    property string category: "all"
    signal requestClose

    readonly property var favorites: SettingsBus.get("apps.favorites", [])
    readonly property var recents: SettingsBus.get("apps.recent", [])
    readonly property bool showSections: grid.query.trim() === ""

    readonly property var catDefs: [
        { id: "all", label: "All", match: null },
        { id: "web", label: "Internet", match: ["Network", "WebBrowser", "Email", "InstantMessaging"] },
        { id: "dev", label: "Dev", match: ["Development", "IDE"] },
        { id: "media", label: "Media", match: ["AudioVideo", "Audio", "Video", "Player", "Music"] },
        { id: "graphics", label: "Graphics", match: ["Graphics", "Photography"] },
        { id: "games", label: "Games", match: ["Game"] },
        { id: "office", label: "Office", match: ["Office", "TextEditor"] },
        { id: "system", label: "System", match: ["System", "Settings", "Security"] },
        { id: "utility", label: "Utils", match: ["Utility", "Accessories"] }
    ]

    function iconSource(name) {
        if (!name) return ""
        if (name.indexOf("://") >= 0) return name
        if (name.charAt(0) === "/") return "file://" + name
        return Quickshell.iconPath(name, "application-x-executable")
    }
    function isFav(id) { return grid.favorites.indexOf(id) >= 0 }
    function toggleFav(id) {
        if (!id) return
        var f = grid.favorites.filter(function (x) { return x !== id })
        if (!grid.isFav(id)) f.push(id)
        SettingsBus.set("apps.favorites", f)
    }
    function entryById(id) {
        var a = (DesktopEntries.applications ? DesktopEntries.applications.values : []) || []
        for (var i = 0; i < a.length; i++) if (a[i] && a[i].id === id) return a[i]
        return null
    }
    function mapIds(ids) {
        var out = []
        for (var i = 0; i < ids.length; i++) { var e = grid.entryById(ids[i]); if (e) out.push(e) }
        return out
    }
    function catMatch(entry) {
        if (grid.category === "all") return true
        var def = null
        for (var i = 0; i < grid.catDefs.length; i++) if (grid.catDefs[i].id === grid.category) def = grid.catDefs[i]
        if (!def || !def.match) return true
        var cats = entry.categories || []
        for (var j = 0; j < cats.length; j++) if (def.match.indexOf(String(cats[j])) >= 0) return true
        return false
    }
    function score(entry, q) {
        var n = (entry.name || "").toLowerCase()
        if (n.indexOf(q) === 0) return 100
        if (n.indexOf(q) >= 0) return 80
        var j = 0
        for (var i = 0; i < n.length && j < q.length; i++) if (n[i] === q[j]) j++
        if (j === q.length) return 40
        if ((entry.genericName || "").toLowerCase().indexOf(q) >= 0) return 30
        if ((entry.execString || "").toLowerCase().indexOf(q) >= 0) return 20
        return -1
    }
    readonly property var filtered: {
        var a = (DesktopEntries.applications ? DesktopEntries.applications.values : []) || []
        var q = grid.query.trim().toLowerCase()
        var out = []
        for (var i = 0; i < a.length; i++) {
            var e = a[i]
            if (!e || !e.name || e.noDisplay) continue
            if (!grid.catMatch(e)) continue
            if (q) { var s = grid.score(e, q); if (s < 0) continue; e._s = s }
            out.push(e)
        }
        out.sort(function (x, y) {
            if (q && (y._s || 0) !== (x._s || 0)) return (y._s || 0) - (x._s || 0)
            return x.name.localeCompare(y.name)
        })
        return out
    }

    readonly property int columns: gv.width > 0 ? Math.max(1, Math.round(gv.width / 112)) : 1

    // ── keyboard API (driven by the launcher search field) ──
    function activate(i) {
        if (i >= 0 && i < grid.filtered.length) { Launch.app(grid.filtered[i], grid.screenName); grid.requestClose() }
    }
    function activateSelected() { grid.activate(grid.selectedIndex) }
    function toggleFavSelected() { var e = grid.filtered[grid.selectedIndex]; if (e) grid.toggleFav(e.id) }
    function move(dx, dy) {
        var n = grid.filtered.length
        if (n === 0) return
        var i = grid.selectedIndex + dx + dy * grid.columns
        grid.selectedIndex = Math.max(0, Math.min(n - 1, i))
        gv.positionViewAtIndex(grid.selectedIndex, GridView.Contain)
    }
    onQueryChanged: selectedIndex = 0
    onCategoryChanged: selectedIndex = 0

    // mini tile for the favourites / recents header rows
    Component {
        id: miniTile
        Item {
            id: mt
            required property var modelData
            width: 66; height: 66
            Rectangle {
                anchors.fill: parent; anchors.margins: 2; radius: Theme.radiusMd
                color: mHover.hovered ? Theme.surfaceHover : Theme.surface
                border.color: Theme.border
                Column {
                    anchors.centerIn: parent; spacing: 3
                    IconImage { anchors.horizontalCenter: parent.horizontalCenter; source: grid.iconSource(mt.modelData.icon); width: 28; height: 28 }
                    Text { anchors.horizontalCenter: parent.horizontalCenter; width: 58; text: mt.modelData.name; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeLabel; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight; maximumLineCount: 1 }
                }
                HoverHandler { id: mHover; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: { Launch.app(mt.modelData, grid.screenName); grid.requestClose() } }
            }
        }
    }

    GridView {
        id: gv
        anchors.fill: parent
        clip: true
        cellWidth: width > 0 ? Math.floor(width / grid.columns) : 112
        cellHeight: 94
        cacheBuffer: 600
        boundsBehavior: Flickable.StopAtBounds
        model: grid.filtered

        header: Column {
            width: gv.width
            spacing: 10
            bottomPadding: 8

            Flow {
                width: parent.width
                spacing: 6
                Repeater {
                    model: grid.catDefs
                    delegate: DisplayChip {
                        required property var modelData
                        label: modelData.label
                        selected: grid.category === modelData.id
                        onClicked: grid.category = modelData.id
                    }
                }
            }

            Column {
                width: parent.width; spacing: 4
                visible: grid.showSections && grid.favorites.length > 0
                SectionLabel { text: "Favourites" }
                Row { spacing: 6; Repeater { model: grid.mapIds(grid.favorites); delegate: miniTile } }
            }
            Column {
                width: parent.width; spacing: 4
                visible: grid.showSections && grid.recents.length > 0
                SectionLabel { text: "Recent" }
                Row { spacing: 6; Repeater { model: grid.mapIds(grid.recents); delegate: miniTile } }
            }
            SectionLabel { text: grid.showSections ? "All apps" : (grid.filtered.length + " result" + (grid.filtered.length === 1 ? "" : "s")) }
        }

        delegate: Item {
            id: cell
            required property var modelData
            required property int index
            width: gv.cellWidth
            height: gv.cellHeight
            readonly property bool sel: index === grid.selectedIndex

            Rectangle {
                anchors.fill: parent; anchors.margins: 4
                radius: Theme.radiusMd
                color: cell.sel ? Theme.accentDim : (cellHover.hovered ? Theme.surfaceHover : "transparent")
                border.color: cell.sel ? Theme.accent : "transparent"
                Behavior on color { ColorAnimation { duration: Anim.d(Anim.fast) } }

                Column {
                    anchors.centerIn: parent; spacing: 6
                    IconImage { anchors.horizontalCenter: parent.horizontalCenter; source: grid.iconSource(cell.modelData.icon); width: 40; height: 40 }
                    Text { anchors.horizontalCenter: parent.horizontalCenter; width: gv.cellWidth - 14; text: cell.modelData.name; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSmall; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight; maximumLineCount: 1 }
                }
                MaterialIcon {
                    anchors.top: parent.top; anchors.right: parent.right; anchors.margins: 5
                    iconName: grid.isFav(cell.modelData.id) ? "star" : "star_outline"
                    pixelSize: 15
                    color: grid.isFav(cell.modelData.id) ? Theme.warning : (starHover.hovered ? Theme.text : Theme.textDim)
                    opacity: grid.isFav(cell.modelData.id) || cellHover.hovered ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: Anim.d(Anim.fast) } }
                    HoverHandler { id: starHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: grid.toggleFav(cell.modelData.id) }
                }
                HoverHandler { id: cellHover; onHoveredChanged: if (hovered) grid.selectedIndex = cell.index }
                TapHandler { onTapped: grid.activate(cell.index) }
            }
        }
    }

    Column {
        anchors.centerIn: parent
        visible: grid.filtered.length === 0
        spacing: 6
        MaterialIcon { anchors.horizontalCenter: parent.horizontalCenter; iconName: "apps"; pixelSize: 34; color: Theme.textDim }
        Text { anchors.horizontalCenter: parent.horizontalCenter; text: grid.query.trim() !== "" ? "No apps match" : "No applications"; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeBody }
    }
}
