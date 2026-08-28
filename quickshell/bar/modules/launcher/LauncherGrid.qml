import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import "../../theme"
import "../../components"
import "../../services"

// LauncherGrid: Categorized grid view with interactive Group Folders for Mujo (無常).
// Features interactive group folders with 2x2 mini previews, smooth open/close transitions,
// favorites prioritization across all tiers, category chips, and keyboard navigation.
Item {
    id: grid

    property string screenName: ""
    property string query: ""
    property int selectedIndex: 0
    property string category: "all"
    property var openGroup: null     // null = Root View; non-null = Inside Group Folder
    signal requestClose

    readonly property var groups: SettingsBus.get("apps.groups", [])
    readonly property var favorites: SettingsBus.get("apps.favorites", [])
    readonly property var recents: SettingsBus.get("apps.recent", [])
    readonly property bool showSections: grid.query.trim() === "" && grid.openGroup === null

    readonly property var catDefs: [
        { id: "all", label: "All", icon: "apps", match: null },
        { id: "web", label: "Internet", icon: "language", match: ["Network", "WebBrowser", "Email", "InstantMessaging"] },
        { id: "dev", label: "Dev", icon: "code", match: ["Development", "IDE"] },
        { id: "media", label: "Media", icon: "play_circle", match: ["AudioVideo", "Audio", "Video", "Player", "Music"] },
        { id: "graphics", label: "Graphics", icon: "image", match: ["Graphics", "Photography"] },
        { id: "games", label: "Games", icon: "sports_esports", match: ["Game"] },
        { id: "office", label: "Office", icon: "edit_note", match: ["Office", "TextEditor"] },
        { id: "system", label: "System", icon: "settings", match: ["System", "Settings", "Security"] },
        { id: "utility", label: "Utils", icon: "handyman", match: ["Utility", "Accessories"] }
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
        for (var i = 0; i < a.length; i++) if (a[i] && (a[i].id === id || a[i].name === id)) return a[i]
        return null
    }

    function mapIds(ids) {
        var out = []
        for (var i = 0; i < ids.length; i++) {
            var e = grid.entryById(ids[i])
            if (e) out.push(e)
        }
        return out
    }

    // Only offer categories some installed app actually falls into — the full
    // catDefs list showed chips (Games, Office…) that always led to an empty
    // grid on a machine with none of them.
    readonly property var visibleCatDefs: {
        var apps = DesktopEntries && DesktopEntries.applications
            ? DesktopEntries.applications.values : null
        if (!apps) return grid.catDefs
        var seen = {}
        for (var i = 0; i < apps.length; i++) {
            var cats = (apps[i] && apps[i].categories) || []
            for (var j = 0; j < cats.length; j++) seen[String(cats[j])] = true
        }
        var out = []
        for (var d = 0; d < grid.catDefs.length; d++) {
            var def = grid.catDefs[d]
            if (!def.match) { out.push(def); continue }
            for (var m = 0; m < def.match.length; m++) {
                if (seen[def.match[m]]) { out.push(def); break }
            }
        }
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

    function fuzzySubsequenceScore(str, pattern) {
        var sIdx = 0, pIdx = 0
        var score = 0
        var consecutive = 0
        var prevMatchIdx = -1

        while (sIdx < str.length && pIdx < pattern.length) {
            if (str[sIdx] === pattern[pIdx]) {
                score += 20
                if (prevMatchIdx === sIdx - 1) {
                    consecutive++
                    score += consecutive * 15
                } else {
                    consecutive = 0
                }
                if (sIdx === 0 || str[sIdx - 1] === " " || str[sIdx - 1] === "-" || str[sIdx - 1] === "_") {
                    score += 35
                }
                prevMatchIdx = sIdx
                pIdx++
            }
            sIdx++
        }
        return pIdx === pattern.length ? Math.max(1, score) : -1
    }

    function scoreApp(entry, q, isFavorite) {
        if (!entry || !entry.name) return -1
        if (!q) return isFavorite ? 10000 : 1000

        var name = entry.name.toLowerCase()
        var generic = (entry.genericName || "").toLowerCase()
        var comment = (entry.comment || "").toLowerCase()
        var exec = (entry.execString || "").toLowerCase()
        var id = (entry.id || "").toLowerCase()

        var s = -1

        if (name === q) {
            s = 10000
        } else if (name.indexOf(q) === 0) {
            s = 8500 + Math.max(0, 500 - (name.length - q.length) * 10)
        } else if (name.indexOf(" " + q) >= 0 || name.indexOf("-" + q) >= 0 || name.indexOf("_" + q) >= 0) {
            var idx = Math.max(name.indexOf(" " + q), Math.max(name.indexOf("-" + q), name.indexOf("_" + q)))
            s = 7200 - idx * 15
        } else if (generic === q) {
            s = 6800
        } else if (generic.indexOf(q) === 0) {
            s = 6300
        } else if (generic.indexOf(" " + q) >= 0) {
            s = 5800
        } else if (entry.keywords) {
            for (var k = 0; k < entry.keywords.length; k++) {
                var kw = String(entry.keywords[k]).toLowerCase()
                if (kw === q) { s = 5500; break }
                if (kw.indexOf(q) === 0) { s = 5200; break }
                if (kw.indexOf(q) > 0) { s = 4700; break }
            }
        }

        if (s < 0 && name.indexOf(q) >= 0) {
            s = 4200 - name.indexOf(q) * 20
        }

        if (s < 0) {
            var fz = grid.fuzzySubsequenceScore(name, q)
            if (fz > 0) s = 3000 + fz
        }

        if (s < 0 && generic.indexOf(q) >= 0) {
            s = 2200
        }
        if (s < 0 && (comment.indexOf(q) >= 0 || exec.indexOf(q) >= 0 || id.indexOf(q) >= 0)) {
            s = 1200
        }

        if (s < 0) return -1
        if (isFavorite) s += 2500
        return s
    }

    readonly property var filtered: {
        var a = (DesktopEntries.applications ? DesktopEntries.applications.values : []) || []
        var q = grid.query.trim().toLowerCase()
        var out = []

        // If inside an open group folder, scope to that group
        if (grid.openGroup !== null) {
            var groupAppIds = grid.openGroup.apps || []
            for (var gi = 0; gi < groupAppIds.length; gi++) {
                var ge = grid.entryById(groupAppIds[gi])
                if (!ge || !ge.name || ge.noDisplay) continue
                var gFav = grid.isFav(ge.id)
                var gs = grid.scoreApp(ge, q, gFav)
                if (gs < 0) continue
                ge._s = gs
                out.push(ge)
            }
            out.sort(function (x, y) {
                var xFav = grid.isFav(x.id), yFav = grid.isFav(y.id)
                if (xFav !== yFav) return xFav ? -1 : 1
                if (q && (y._s || 0) !== (x._s || 0)) return (y._s || 0) - (x._s || 0)
                return x.name.localeCompare(y.name)
            })
            return out
        }

        // Top-level root grid
        for (var i = 0; i < a.length; i++) {
            var e = a[i]
            if (!e || !e.name || e.noDisplay) continue
            if (!grid.catMatch(e)) continue
            var fav = grid.isFav(e.id)
            var s = grid.scoreApp(e, q, fav)
            if (s < 0) continue
            e._s = s
            out.push(e)
        }

        out.sort(function (x, y) {
            var xFav = grid.isFav(x.id), yFav = grid.isFav(y.id)
            if (xFav !== yFav) return xFav ? -1 : 1
            if (q && (y._s || 0) !== (x._s || 0)) return (y._s || 0) - (x._s || 0)
            return x.name.localeCompare(y.name)
        })
        return out
    }

    readonly property int columns: gv.width > 0 ? Math.max(1, Math.floor(gv.width / 110)) : 1

    function openFolder(grp) {
        if (!grp) return
        grid.openGroup = grp
        grid.selectedIndex = 0
        gv.contentY = 0
    }

    function closeFolder() {
        grid.openGroup = null
        grid.selectedIndex = 0
        gv.contentY = 0
    }

    // Keyboard API
    function activate(i) {
        if (i >= 0 && i < grid.filtered.length) {
            Launch.app(grid.filtered[i], grid.screenName)
            grid.requestClose()
        }
    }
    function activateSelected() { grid.activate(grid.selectedIndex) }
    function move(dx, dy) {
        var n = grid.filtered.length
        if (n === 0) return
        var i = grid.selectedIndex + dx + dy * grid.columns
        grid.selectedIndex = Math.max(0, Math.min(n - 1, i))
        gv.positionViewAtIndex(grid.selectedIndex, GridView.Contain)
    }

    onQueryChanged: selectedIndex = 0
    onCategoryChanged: selectedIndex = 0

    // Mini-tile component for Favourites & Recents
    Component {
        id: miniTile
        Item {
            id: mt
            required property var modelData
            width: 72
            height: 72

            Rectangle {
                anchors.fill: parent
                anchors.margins: 2
                radius: Theme.radiusMd
                color: mHover.hovered ? Theme.surfaceHover : Theme.surface
                border.color: mHover.hovered ? Theme.withAlpha(Theme.accent, 0.4) : Theme.border
                border.width: 1

                scale: Anim.microInteractions && mHover.hovered ? 1.05 : 1.0
                Behavior on scale { NumberAnimation { duration: Anim.d(Anim.fast); easing.type: Anim.easeStandard } }
                Behavior on color { ColorAnimation { duration: Anim.d(Anim.fast) } }
                Behavior on border.color { ColorAnimation { duration: Anim.d(Anim.fast) } }

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 4
                    width: parent.width - 8

                    IconImage {
                        Layout.alignment: Qt.AlignHCenter
                        source: grid.iconSource(mt.modelData.icon)
                        width: 28
                        height: 28
                    }

                    Text {
                        Layout.fillWidth: true
                        text: mt.modelData.name
                        color: mHover.hovered ? Theme.text : Theme.textSecondary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeLabel
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }
                }

                HoverHandler { id: mHover; cursorShape: Qt.PointingHandCursor }
                TapHandler {
                    onTapped: {
                        Launch.app(mt.modelData, grid.screenName)
                        grid.requestClose()
                    }
                }
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 8

        // ── Inside Folder Breadcrumb Navigation Header ───────────────────────
        Rectangle {
            id: folderBreadcrumb
            Layout.fillWidth: true
            Layout.preferredHeight: 36
            radius: Theme.radiusSm
            color: Theme.surface
            border.color: Theme.border
            border.width: 1
            visible: grid.openGroup !== null

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                spacing: 8

                // Back Button
                Rectangle {
                    implicitWidth: backRow.implicitWidth + 12
                    implicitHeight: 26
                    radius: Theme.radiusSm
                    color: backHover.hovered ? Theme.surfaceHover : Theme.surfaceActive
                    border.color: backHover.hovered ? Theme.accent : Theme.borderStrong

                    RowLayout {
                        id: backRow
                        anchors.centerIn: parent
                        spacing: 4
                        MaterialIcon {
                            iconName: "arrow_back"
                            pixelSize: 13
                            color: Theme.accent
                        }
                        Text {
                            text: "All Apps"
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            font.bold: true
                        }
                    }
                    HoverHandler { id: backHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: grid.closeFolder() }
                }

                Text {
                    text: "/"
                    color: Theme.textDim
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeTitle
                }

                // Folder Title with Icon
                MaterialIcon {
                    iconName: grid.openGroup ? (grid.openGroup.icon || "folder") : "folder"
                    pixelSize: 16
                    color: Theme.accent
                }

                Text {
                    text: grid.openGroup ? grid.openGroup.name : ""
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    font.bold: true
                }

                // Count Pill
                Rectangle {
                    implicitWidth: folderCnt.implicitWidth + 10
                    implicitHeight: 18
                    radius: 9
                    color: Theme.withAlpha(Theme.accent, 0.2)
                    border.color: Theme.withAlpha(Theme.accent, 0.4)

                    Text {
                        id: folderCnt
                        anchors.centerIn: parent
                        text: grid.filtered.length + " item" + (grid.filtered.length === 1 ? "" : "s")
                        color: Theme.accent
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeLabel - 1
                        font.bold: true
                    }
                }

                Item { Layout.fillWidth: true }
            }
        }

        // ── Main Grid View ───────────────────────────────────────────────────
        GridView {
            id: gv
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            cellWidth: width > 0 ? Math.floor(width / grid.columns) : 110
            cellHeight: 96
            cacheBuffer: 800
            boundsBehavior: Flickable.StopAtBounds
            model: grid.filtered

            header: ColumnLayout {
                width: gv.width
                spacing: 12
                Layout.bottomMargin: 8
                visible: grid.openGroup === null

                // Category Chips Row (only when at root)
                Flow {
                    Layout.fillWidth: true
                    spacing: 6

                    Repeater {
                        model: grid.visibleCatDefs
                        delegate: Rectangle {
                            id: catChip
                            required property var modelData
                            readonly property bool isSelected: grid.category === modelData.id

                            implicitHeight: 28
                            implicitWidth: catRow.implicitWidth + 16
                            radius: Theme.radiusSm
                            color: isSelected
                                   ? (Anim.ambient ? Theme.withAlpha(Theme.accent, 0.2) : Theme.accentDim)
                                   : (chipHover.hovered ? Theme.surfaceHover : Theme.surface)
                            border.color: isSelected ? Theme.accent : (chipHover.hovered ? Theme.borderStrong : Theme.border)
                            border.width: 1

                            Behavior on color { ColorAnimation { duration: Anim.d(Anim.fast) } }
                            Behavior on border.color { ColorAnimation { duration: Anim.d(Anim.fast) } }

                            RowLayout {
                                id: catRow
                                anchors.centerIn: parent
                                spacing: 5

                                MaterialIcon {
                                    iconName: catChip.modelData.icon
                                    pixelSize: 13
                                    color: catChip.isSelected ? Theme.accent : (chipHover.hovered ? Theme.text : Theme.textSecondary)
                                }

                                Text {
                                    text: catChip.modelData.label
                                    color: catChip.isSelected ? Theme.text : (chipHover.hovered ? Theme.text : Theme.textSecondary)
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.bold: catChip.isSelected
                                }
                            }

                            HoverHandler { id: chipHover; cursorShape: Qt.PointingHandCursor }
                            TapHandler { onTapped: grid.category = catChip.modelData.id }
                        }
                    }
                }

                // Group Folders Shelf
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    visible: grid.showSections && grid.groups.length > 0

                    SectionLabel { text: "Group Folders" }

                    Flow {
                        Layout.fillWidth: true
                        spacing: 8
                        Repeater {
                            model: grid.groups
                            delegate: Item {
                                required property var modelData
                                width: 110
                                height: 96

                                LauncherFolderCard {
                                    anchors.fill: parent
                                    group: modelData
                                    screenName: grid.screenName
                                    onOpened: function(grp) { grid.openFolder(grp) }
                                }
                            }
                        }
                    }
                }

                // Favourites Shelf
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    visible: grid.showSections && grid.favorites.length > 0

                    SectionLabel { text: "Favourites" }

                    Flow {
                        Layout.fillWidth: true
                        spacing: 6
                        Repeater {
                            model: grid.mapIds(grid.favorites)
                            delegate: miniTile
                        }
                    }
                }

                // Recent Section
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    visible: grid.showSections && grid.recents.length > 0

                    SectionLabel { text: "Recent Applications" }

                    Flow {
                        Layout.fillWidth: true
                        spacing: 6
                        Repeater {
                            model: grid.mapIds(grid.recents)
                            delegate: miniTile
                        }
                    }
                }

                SectionLabel {
                    text: grid.showSections
                          ? (grid.category === "all" ? "All Applications" : (grid.category.toUpperCase() + " APPS"))
                          : (grid.filtered.length + " result" + (grid.filtered.length === 1 ? "" : "s"))
                }
            }

            delegate: Item {
                id: cell
                required property var modelData
                required property int index
                width: gv.cellWidth
                height: gv.cellHeight
                readonly property bool sel: index === grid.selectedIndex

                Rectangle {
                    id: cellCard
                    anchors.fill: parent
                    anchors.margins: 4
                    radius: Theme.radiusMd
                    color: cell.sel
                           ? (Anim.ambient ? Theme.withAlpha(Theme.accent, 0.18) : Theme.accentDim)
                           : (cellHover.hovered ? Theme.surfaceHover : Theme.surface)
                    border.color: cell.sel ? Theme.accent : (cellHover.hovered ? Theme.borderStrong : Theme.border)
                    border.width: 1

                    scale: Anim.microInteractions ? (cell.sel ? 1.04 : (cellHover.hovered ? 1.02 : 1.0)) : 1.0
                    Behavior on scale { NumberAnimation { duration: Anim.d(Anim.fast); easing.type: Anim.easeStandard } }
                    Behavior on color { ColorAnimation { duration: Anim.d(Anim.fast) } }
                    Behavior on border.color { ColorAnimation { duration: Anim.d(Anim.fast) } }

                    // App Content Area
                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 6
                        width: parent.width - 12

                        IconImage {
                            Layout.alignment: Qt.AlignHCenter
                            source: grid.iconSource(cell.modelData.icon)
                            width: 36
                            height: 36
                        }

                        Text {
                            Layout.fillWidth: true
                            text: cell.modelData.name
                            color: cell.sel ? Theme.text : Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            font.bold: cell.sel
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }
                    }

                    // Top-right Star Favorite Toggle Button
                    Item {
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.margins: 4
                        width: 22
                        height: 22
                        opacity: grid.isFav(cell.modelData.id) || cellHover.hovered ? 1.0 : 0.0
                        Behavior on opacity { NumberAnimation { duration: Anim.d(Anim.fast) } }

                        MaterialIcon {
                            anchors.centerIn: parent
                            iconName: grid.isFav(cell.modelData.id) ? "star" : "star_outline"
                            pixelSize: 14
                            color: grid.isFav(cell.modelData.id) ? Theme.warning : (starHover.hovered ? Theme.text : Theme.textDim)
                            scale: starHover.hovered ? 1.25 : 1.0
                            Behavior on scale { NumberAnimation { duration: Anim.d(Anim.fast); easing.type: Anim.easeStandard } }
                        }

                        HoverHandler { id: starHover; cursorShape: Qt.PointingHandCursor }
                        TapHandler {
                            onTapped: grid.toggleFav(cell.modelData.id)
                        }
                    }

                    // Cell Body Launch Click & Motion Hover
                    HoverHandler {
                        id: cellHover
                        cursorShape: Qt.PointingHandCursor
                        onHoveredChanged: if (hovered) grid.selectedIndex = cell.index
                    }
                    TapHandler {
                        onTapped: grid.activate(cell.index)
                    }
                }
            }
        }
    }

    LauncherEmptyState {
        anchors.centerIn: parent
        visible: grid.filtered.length === 0
        mode: "no-results"
        query: grid.query
    }
}
