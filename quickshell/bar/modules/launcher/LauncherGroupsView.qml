import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import "../../theme"
import "../../components"
import "../../services"

// LauncherGroupsView: User-defined application groups manager & viewer for Mujo (無常).
// Provides seamless group creation, renaming, deletion, application organization,
// and smooth keyboard & mouse navigation, fully independent from Favorites.
Item {
    id: root

    property string screenName: ""
    property string query: ""
    property int selectedIndex: 0
    signal requestClose

    readonly property var rawGroups: SettingsBus.get("apps.groups", [])
    readonly property var favorites: SettingsBus.get("apps.favorites", [])

    // Ensure we always have at least an array
    readonly property var groups: {
        var g = root.rawGroups
        if (g && g.length !== undefined) return g
        return []
    }

    property int activeGroupIndex: 0
    readonly property var currentGroup: {
        if (root.groups.length > 0 && root.activeGroupIndex >= 0 && root.activeGroupIndex < root.groups.length) {
            return root.groups[root.activeGroupIndex]
        }
        return null
    }

    // Modal dialog state: "" | "create" | "rename" | "delete" | "add-apps"
    property string modalState: ""
    property string modalGroupName: ""
    property string modalGroupIcon: "folder"
    property string modalFilterQuery: ""

    readonly property var iconChoices: [
        "folder", "code", "work", "sports_esports", "terminal",
        "language", "music_note", "play_circle", "image", "palette",
        "edit_note", "settings", "build", "bookmark", "star", "dashboard"
    ]

    function isFav(id) { return root.favorites.indexOf(id) >= 0 }
    function toggleFav(id) {
        if (!id) return
        var f = root.favorites.filter(function (x) { return x !== id })
        if (!root.isFav(id)) f.push(id)
        SettingsBus.set("apps.favorites", f)
    }

    function iconSource(name) {
        if (!name) return ""
        if (name.indexOf("://") >= 0) return name
        if (name.charAt(0) === "/") return "file://" + name
        return Quickshell.iconPath(name, "application-x-executable")
    }

    function entryById(id) {
        var a = (DesktopEntries.applications ? DesktopEntries.applications.values : []) || []
        for (var i = 0; i < a.length; i++) {
            if (a[i] && (a[i].id === id || a[i].name === id)) return a[i]
        }
        return null
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
            var fz = root.fuzzySubsequenceScore(name, q)
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

    // Get applications belonging to the active group (filtered by search query if non-empty, favorites first)
    readonly property var currentGroupApps: {
        if (!root.currentGroup || !root.currentGroup.apps) return []
        var appIds = root.currentGroup.apps
        var q = root.query.trim().toLowerCase()
        var out = []
        for (var i = 0; i < appIds.length; i++) {
            var e = root.entryById(appIds[i])
            if (!e || !e.name) continue
            var fav = root.isFav(e.id)
            var s = root.scoreApp(e, q, fav)
            if (s < 0) continue
            e._score = s
            out.push(e)
        }
        out.sort(function (a, b) {
            var aFav = root.isFav(a.id), bFav = root.isFav(b.id)
            if (aFav !== bFav) return aFav ? -1 : 1
            if (q && (b._score || 0) !== (a._score || 0)) return (b._score || 0) - (a._score || 0)
            return a.name.localeCompare(b.name)
        })
        return out
    }

    // All applications available to add to the active group
    readonly property var availableAppsToAdd: {
        var a = (DesktopEntries.applications ? DesktopEntries.applications.values : []) || []
        var currentIds = (root.currentGroup && root.currentGroup.apps) ? root.currentGroup.apps : []
        var q = root.modalFilterQuery.trim().toLowerCase()
        var out = []
        for (var i = 0; i < a.length; i++) {
            var e = a[i]
            if (!e || !e.name || e.noDisplay) continue
            if (currentIds.indexOf(e.id) >= 0) continue
            if (q !== "") {
                var match = e.name.toLowerCase().indexOf(q) >= 0 ||
                            (e.genericName && e.genericName.toLowerCase().indexOf(q) >= 0) ||
                            (e.execString && e.execString.toLowerCase().indexOf(q) >= 0)
                if (!match) continue
            }
            out.push(e)
        }
        out.sort(function (x, y) { return x.name.localeCompare(y.name) })
        return out
    }

    // ── Group Operations ──────────────────────────────────────────────────────
    function createGroup(name, icon) {
        var cleanName = name.trim()
        if (!cleanName) return
        var newGroup = {
            id: "group-" + Date.now(),
            name: cleanName,
            icon: icon || "folder",
            apps: []
        }
        var updated = root.groups.slice()
        updated.push(newGroup)
        SettingsBus.set("apps.groups", updated)
        root.activeGroupIndex = updated.length - 1
        root.modalState = ""
        Notifications.notify("Group created", cleanName, icon || "folder", "low", { transient: true })
    }

    function renameGroup(newName, newIcon) {
        if (!root.currentGroup) return
        var cleanName = newName.trim()
        if (!cleanName) return
        var updated = root.groups.slice()
        var g = JSON.parse(JSON.stringify(root.currentGroup))
        g.name = cleanName
        g.icon = newIcon || g.icon || "folder"
        updated[root.activeGroupIndex] = g
        SettingsBus.set("apps.groups", updated)
        root.modalState = ""
        Notifications.notify("Group updated", cleanName, g.icon, "low", { transient: true })
    }

    function deleteCurrentGroup() {
        if (!root.currentGroup) return
        var name = root.currentGroup.name
        var updated = root.groups.filter(function (g, idx) { return idx !== root.activeGroupIndex })
        SettingsBus.set("apps.groups", updated)
        root.activeGroupIndex = Math.max(0, root.activeGroupIndex - 1)
        root.modalState = ""
        Notifications.notify("Group deleted", name, "delete", "low", { transient: true })
    }

    function addAppToCurrentGroup(appId) {
        if (!root.currentGroup || !appId) return
        var updated = root.groups.slice()
        var g = JSON.parse(JSON.stringify(root.currentGroup))
        if (!g.apps) g.apps = []
        if (g.apps.indexOf(appId) < 0) {
            g.apps.push(appId)
            updated[root.activeGroupIndex] = g
            SettingsBus.set("apps.groups", updated)
        }
    }

    function removeAppFromCurrentGroup(appId) {
        if (!root.currentGroup || !appId) return
        var updated = root.groups.slice()
        var g = JSON.parse(JSON.stringify(root.currentGroup))
        if (!g.apps) return
        g.apps = g.apps.filter(function (id) { return id !== appId })
        updated[root.activeGroupIndex] = g
        SettingsBus.set("apps.groups", updated)
    }

    // Keyboard navigation
    readonly property int columns: gv.width > 0 ? Math.max(1, Math.floor(gv.width / 110)) : 1

    function activate(i) {
        if (i >= 0 && i < root.currentGroupApps.length) {
            Launch.app(root.currentGroupApps[i], root.screenName)
            root.requestClose()
        }
    }
    function activateSelected() { root.activate(root.selectedIndex) }

    function move(dx, dy) {
        var n = root.currentGroupApps.length
        if (n === 0) return
        var i = root.selectedIndex + dx + dy * root.columns
        root.selectedIndex = Math.max(0, Math.min(n - 1, i))
        gv.positionViewAtIndex(root.selectedIndex, GridView.Contain)
    }

    onQueryChanged: selectedIndex = 0

    // ── Main UI Layout ────────────────────────────────────────────────────────
    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        // 1. Group Selector Tab Bar
        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            // Horizontal scrolling group chips
            Flickable {
                id: groupFlick
                Layout.fillWidth: true
                Layout.preferredHeight: 30
                contentWidth: groupRow.implicitWidth
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                RowLayout {
                    id: groupRow
                    spacing: 6
                    anchors.verticalCenter: parent.verticalCenter

                    Repeater {
                        model: root.groups

                        delegate: Rectangle {
                            id: gChip
                            required property var modelData
                            required property int index
                            readonly property bool isSelected: root.activeGroupIndex === index

                            implicitHeight: 28
                            implicitWidth: gChipRow.implicitWidth + 16
                            radius: Theme.radiusSm
                            color: isSelected
                                   ? (Anim.ambient ? Theme.withAlpha(Theme.accent, 0.2) : Theme.accentDim)
                                   : (gHover.hovered ? Theme.surfaceHover : Theme.surface)
                            border.color: isSelected ? Theme.accent : (gHover.hovered ? Theme.borderStrong : Theme.border)
                            border.width: 1

                            Behavior on color { ColorAnimation { duration: Anim.d(Anim.fast) } }
                            Behavior on border.color { ColorAnimation { duration: Anim.d(Anim.fast) } }

                            RowLayout {
                                id: gChipRow
                                anchors.centerIn: parent
                                spacing: 5

                                MaterialIcon {
                                    iconName: gChip.modelData.icon || "folder"
                                    pixelSize: 13
                                    color: gChip.isSelected ? Theme.accent : (gHover.hovered ? Theme.text : Theme.textSecondary)
                                }

                                Text {
                                    text: gChip.modelData.name
                                    color: gChip.isSelected ? Theme.text : (gHover.hovered ? Theme.text : Theme.textSecondary)
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.bold: gChip.isSelected
                                }

                                Rectangle {
                                    implicitWidth: Math.max(16, gCount.implicitWidth + 6)
                                    implicitHeight: 16
                                    radius: 8
                                    color: gChip.isSelected ? Theme.withAlpha(Theme.accent, 0.3) : Theme.surfaceActive
                                    Text {
                                        id: gCount
                                        anchors.centerIn: parent
                                        text: (gChip.modelData.apps ? gChip.modelData.apps.length : 0)
                                        color: gChip.isSelected ? Theme.accent : Theme.textDim
                                        font.family: Theme.fontMono
                                        font.pixelSize: Theme.fontSizeLabel - 1
                                        font.bold: true
                                    }
                                }
                            }

                            HoverHandler { id: gHover; cursorShape: Qt.PointingHandCursor }
                            TapHandler {
                                onTapped: {
                                    root.activeGroupIndex = gChip.index
                                    root.selectedIndex = 0
                                }
                            }
                        }
                    }
                }
            }

            // "+ New Group" button
            Rectangle {
                Layout.preferredHeight: 28
                Layout.preferredWidth: newGrpRow.implicitWidth + 14
                radius: Theme.radiusSm
                color: newGrpHover.hovered ? Theme.surfaceHover : Theme.surface
                border.color: newGrpHover.hovered ? Theme.accent : Theme.border
                border.width: 1

                RowLayout {
                    id: newGrpRow
                    anchors.centerIn: parent
                    spacing: 4
                    MaterialIcon { iconName: "add"; pixelSize: 14; color: Theme.accent }
                    Text { text: "New Group"; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSmall }
                }

                HoverHandler { id: newGrpHover; cursorShape: Qt.PointingHandCursor }
                TapHandler {
                    onTapped: {
                        root.modalGroupName = ""
                        root.modalGroupIcon = "folder"
                        root.modalState = "create"
                    }
                }
            }
        }

        // 2. Active Group Controls Header (Rename, Delete, Add Apps)
        RowLayout {
            Layout.fillWidth: true
            visible: root.currentGroup !== null
            spacing: 8

            MaterialIcon {
                iconName: root.currentGroup ? (root.currentGroup.icon || "folder") : "folder"
                pixelSize: 16
                color: Theme.accent
            }

            Text {
                text: root.currentGroup ? root.currentGroup.name : ""
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeTitle
                font.bold: true
            }

            Text {
                text: "(" + root.currentGroupApps.length + " app" + (root.currentGroupApps.length === 1 ? "" : "s") + ")"
                color: Theme.textSecondary
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeSmall
            }

            Item { Layout.fillWidth: true }

            // Add Apps to Group button
            Rectangle {
                Layout.preferredHeight: 24
                Layout.preferredWidth: addAppsRow.implicitWidth + 12
                radius: Theme.radiusSm
                color: addAppsHover.hovered ? Theme.surfaceHover : Theme.surface
                border.color: addAppsHover.hovered ? Theme.accent : Theme.border

                RowLayout {
                    id: addAppsRow
                    anchors.centerIn: parent
                    spacing: 4
                    MaterialIcon { iconName: "add_circle_outline"; pixelSize: 13; color: Theme.accent }
                    Text { text: "Add Apps"; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSmall }
                }
                HoverHandler { id: addAppsHover; cursorShape: Qt.PointingHandCursor }
                TapHandler {
                    onTapped: {
                        root.modalFilterQuery = ""
                        root.modalState = "add-apps"
                    }
                }
            }

            // Rename Group button
            Rectangle {
                Layout.preferredHeight: 24
                Layout.preferredWidth: renRow.implicitWidth + 12
                radius: Theme.radiusSm
                color: renHover.hovered ? Theme.surfaceHover : Theme.surface
                border.color: renHover.hovered ? Theme.borderStrong : Theme.border

                RowLayout {
                    id: renRow
                    anchors.centerIn: parent
                    spacing: 4
                    MaterialIcon { iconName: "edit"; pixelSize: 13; color: Theme.textSecondary }
                    Text { text: "Rename"; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSmall }
                }
                HoverHandler { id: renHover; cursorShape: Qt.PointingHandCursor }
                TapHandler {
                    onTapped: {
                        if (root.currentGroup) {
                            root.modalGroupName = root.currentGroup.name
                            root.modalGroupIcon = root.currentGroup.icon || "folder"
                            root.modalState = "rename"
                        }
                    }
                }
            }

            // Delete Group button
            Rectangle {
                Layout.preferredHeight: 24
                Layout.preferredWidth: delRow.implicitWidth + 12
                radius: Theme.radiusSm
                color: delHover.hovered ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.18) : Theme.surface
                border.color: delHover.hovered ? Theme.error : Theme.border

                RowLayout {
                    id: delRow
                    anchors.centerIn: parent
                    spacing: 4
                    MaterialIcon { iconName: "delete_outline"; pixelSize: 13; color: delHover.hovered ? Theme.error : Theme.textDim }
                    Text { text: "Delete"; color: delHover.hovered ? Theme.error : Theme.textDim; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSmall }
                }
                HoverHandler { id: delHover; cursorShape: Qt.PointingHandCursor }
                TapHandler {
                    onTapped: root.modalState = "delete"
                }
            }
        }

        // 3. Grid of Applications in Current Group
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            GridView {
                id: gv
                anchors.fill: parent
                clip: true
                cellWidth: width > 0 ? Math.floor(width / root.columns) : 110
                cellHeight: 96
                cacheBuffer: 600
                boundsBehavior: Flickable.StopAtBounds
                model: root.currentGroupApps
                visible: root.currentGroup !== null && root.currentGroupApps.length > 0

                delegate: Item {
                    id: cell
                    required property var modelData
                    required property int index
                    width: gv.cellWidth
                    height: gv.cellHeight
                    readonly property bool sel: index === root.selectedIndex

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

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 6
                            width: parent.width - 12

                            IconImage {
                                Layout.alignment: Qt.AlignHCenter
                                source: root.iconSource(cell.modelData.icon)
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

                        // Top-left: Remove from Group button (hover only)
                        Rectangle {
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.margins: 4
                            width: 20
                            height: 20
                            radius: 10
                            color: rmHover.hovered ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.3) : Theme.surfaceActive
                            border.color: rmHover.hovered ? Theme.error : Theme.borderStrong
                            opacity: cellHover.hovered || cell.sel ? 1.0 : 0.0
                            Behavior on opacity { NumberAnimation { duration: Anim.d(Anim.fast) } }

                            MaterialIcon {
                                anchors.centerIn: parent
                                iconName: "close"
                                pixelSize: 12
                                color: rmHover.hovered ? Theme.error : Theme.textSecondary
                            }

                            HoverHandler { id: rmHover; cursorShape: Qt.PointingHandCursor }
                            TapHandler {
                                onTapped: root.removeAppFromCurrentGroup(cell.modelData.id)
                            }
                        }

                        // Top-right: Favorite Star Toggle
                        Item {
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.margins: 4
                            width: 22
                            height: 22
                            opacity: root.isFav(cell.modelData.id) || cellHover.hovered ? 1.0 : 0.0
                            Behavior on opacity { NumberAnimation { duration: Anim.d(Anim.fast) } }

                            MaterialIcon {
                                anchors.centerIn: parent
                                iconName: root.isFav(cell.modelData.id) ? "star" : "star_outline"
                                pixelSize: 14
                                color: root.isFav(cell.modelData.id) ? Theme.warning : (starHover.hovered ? Theme.text : Theme.textDim)
                                scale: starHover.hovered ? 1.2 : 1.0
                                Behavior on scale { NumberAnimation { duration: Anim.d(Anim.fast); easing.type: Anim.easeStandard } }
                            }

                            HoverHandler { id: starHover; cursorShape: Qt.PointingHandCursor }
                            TapHandler {
                                onTapped: root.toggleFav(cell.modelData.id)
                            }
                        }

                        // Card Body Click Handler & Motion Hover
                        HoverHandler {
                            id: cellHover
                            cursorShape: Qt.PointingHandCursor
                            onHoveredChanged: if (hovered) root.selectedIndex = cell.index
                        }
                        TapHandler {
                            onTapped: root.activate(cell.index)
                        }
                    }
                }
            }

            // Empty Group State
            ColumnLayout {
                anchors.centerIn: parent
                visible: root.groups.length === 0 || (root.currentGroup !== null && root.currentGroupApps.length === 0)
                spacing: 12
                width: 320

                MaterialIcon {
                    Layout.alignment: Qt.AlignHCenter
                    iconName: root.groups.length === 0 ? "folder_open" : "playlist_add"
                    pixelSize: 38
                    color: Theme.textDim
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.groups.length === 0 ? "No groups created yet" : "This group is empty"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeTitle
                    font.bold: true
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.groups.length === 0
                          ? "Create custom collections to organize your favorite tools, games, or workflows."
                          : "Add applications to this collection using the button below or via Ctrl+K."
                    color: Theme.textSecondary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }

                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredHeight: 32
                    Layout.preferredWidth: emptyActRow.implicitWidth + 18
                    radius: Theme.radiusSm
                    color: emptyActHover.hovered ? Theme.accent : Theme.surface
                    border.color: Theme.accent

                    RowLayout {
                        id: emptyActRow
                        anchors.centerIn: parent
                        spacing: 6
                        MaterialIcon {
                            iconName: root.groups.length === 0 ? "add" : "add_circle_outline"
                            pixelSize: 14
                            color: emptyActHover.hovered ? Theme.bg : Theme.accent
                        }
                        Text {
                            text: root.groups.length === 0 ? "Create First Group" : "Add Applications"
                            color: emptyActHover.hovered ? Theme.bg : Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            font.bold: true
                        }
                    }
                    HoverHandler { id: emptyActHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler {
                        onTapped: {
                            if (root.groups.length === 0) {
                                root.modalGroupName = ""
                                root.modalGroupIcon = "folder"
                                root.modalState = "create"
                            } else {
                                root.modalFilterQuery = ""
                                root.modalState = "add-apps"
                            }
                        }
                    }
                }
            }
        }
    }

    // ── Modals & Popovers Overlay ─────────────────────────────────────────────

    // 1. Scrim for active modal
    Rectangle {
        anchors.fill: parent
        z: 90
        opacity: root.modalState !== "" ? 1 : 0
        visible: opacity > 0
        color: Theme.withAlpha("#000000", 0.65)
        Behavior on opacity { NumberAnimation { duration: Anim.d(Anim.fast) } }

        MouseArea {
            anchors.fill: parent
            onClicked: root.modalState = ""
        }
    }

    // 2. Create / Rename Group Dialog
    Rectangle {
        id: groupEditModal
        anchors.centerIn: parent
        z: 100
        readonly property bool shown: root.modalState === "create" || root.modalState === "rename"
        visible: opacity > 0
        width: 380
        height: editCol.implicitHeight + 28
        radius: Theme.radiusLg
        color: Theme.surface
        border.color: Theme.borderStrong
        border.width: 1

        scale: groupEditModal.shown ? 1.0 : 0.94
        opacity: groupEditModal.shown ? 1.0 : 0.0
        Behavior on scale { NumberAnimation { duration: Anim.d(Anim.fast); easing.type: Anim.easeStandard } }
        Behavior on opacity { NumberAnimation { duration: Anim.d(Anim.fast) } }

        ColumnLayout {
            id: editCol
            anchors.fill: parent
            anchors.margins: 16
            spacing: 14

            RowLayout {
                Layout.fillWidth: true
                MaterialIcon {
                    iconName: root.modalGroupIcon || "folder"
                    pixelSize: 20
                    color: Theme.accent
                }
                Text {
                    text: root.modalState === "create" ? "Create New Group" : "Rename Group"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeTitle + 1
                    font.bold: true
                    Layout.fillWidth: true
                }
                IconButton {
                    iconName: "close"
                    onClicked: root.modalState = ""
                }
            }

            // Group Name Input
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 38
                radius: Theme.radiusSm
                color: Theme.bg
                border.color: nameInput.activeFocus ? Theme.accent : Theme.border
                border.width: 1

                TextInput {
                    id: nameInput
                    anchors.fill: parent
                    anchors.margins: 8
                    verticalAlignment: Text.AlignVCenter
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeTitle
                    text: root.modalGroupName
                    onTextChanged: root.modalGroupName = text
                    focus: root.modalState === "create" || root.modalState === "rename"
                    Keys.onReturnPressed: {
                        if (root.modalState === "create") root.createGroup(nameInput.text, root.modalGroupIcon)
                        else root.renameGroup(nameInput.text, root.modalGroupIcon)
                    }
                    Keys.onEscapePressed: root.modalState = ""

                    Text {
                        anchors.fill: parent
                        verticalAlignment: Text.AlignVCenter
                        text: "Enter group name (e.g. Work, Gaming, Creative)…"
                        color: Theme.textDim
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeTitle
                        visible: nameInput.text === ""
                    }
                }
            }

            // Icon Picker
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6
                Text { text: "Choose Icon"; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeLabel }

                Flow {
                    Layout.fillWidth: true
                    spacing: 6
                    Repeater {
                        model: root.iconChoices
                        delegate: Rectangle {
                            id: iChoice
                            required property var modelData
                            readonly property bool isSelected: root.modalGroupIcon === modelData
                            implicitWidth: 32
                            implicitHeight: 32
                            radius: Theme.radiusSm
                            color: isSelected ? Theme.withAlpha(Theme.accent, 0.25) : (iHover.hovered ? Theme.surfaceHover : Theme.bg)
                            border.color: isSelected ? Theme.accent : Theme.border

                            MaterialIcon {
                                anchors.centerIn: parent
                                iconName: iChoice.modelData
                                pixelSize: 16
                                color: iChoice.isSelected ? Theme.accent : Theme.textSecondary
                            }
                            HoverHandler { id: iHover; cursorShape: Qt.PointingHandCursor }
                            TapHandler { onTapped: root.modalGroupIcon = iChoice.modelData }
                        }
                    }
                }
            }

            // Dialog Actions
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 4
                spacing: 8
                Item { Layout.fillWidth: true }

                Rectangle {
                    Layout.preferredHeight: 30
                    Layout.preferredWidth: 80
                    radius: Theme.radiusSm
                    color: cancelH.hovered ? Theme.surfaceHover : Theme.surface
                    border.color: Theme.border
                    Text { anchors.centerIn: parent; text: "Cancel"; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeBody }
                    HoverHandler { id: cancelH; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: root.modalState = "" }
                }

                Rectangle {
                    Layout.preferredHeight: 30
                    Layout.preferredWidth: 80
                    radius: Theme.radiusSm
                    color: saveH.hovered ? Theme.accent : Theme.withAlpha(Theme.accent, 0.85)
                    opacity: root.modalGroupName.trim() !== "" ? 1.0 : 0.5
                    Text { anchors.centerIn: parent; text: "Save"; color: Theme.bg; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeBody; font.bold: true }
                    HoverHandler { id: saveH; cursorShape: Qt.PointingHandCursor }
                    TapHandler {
                        onTapped: {
                            if (root.modalState === "create") root.createGroup(root.modalGroupName, root.modalGroupIcon)
                            else root.renameGroup(root.modalGroupName, root.modalGroupIcon)
                        }
                    }
                }
            }
        }
    }

    // 3. Delete Group Confirmation Dialog
    Rectangle {
        anchors.centerIn: parent
        z: 100
        visible: root.modalState === "delete"
        width: 360
        height: delCol.implicitHeight + 28
        radius: Theme.radiusLg
        color: Theme.surface
        border.color: Theme.error
        border.width: 1

        ColumnLayout {
            id: delCol
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            RowLayout {
                spacing: 8
                MaterialIcon { iconName: "warning"; pixelSize: 22; color: Theme.error }
                Text {
                    text: "Delete Group?"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeTitle + 1
                    font.bold: true
                }
            }

            Text {
                text: "Are you sure you want to delete the group \"" + (root.currentGroup ? root.currentGroup.name : "") + "\"? Applications inside will remain installed on your system."
                color: Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 6
                spacing: 8
                Item { Layout.fillWidth: true }

                Rectangle {
                    Layout.preferredHeight: 30
                    Layout.preferredWidth: 80
                    radius: Theme.radiusSm
                    color: delCancH.hovered ? Theme.surfaceHover : Theme.surface
                    border.color: Theme.border
                    Text { anchors.centerIn: parent; text: "Cancel"; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeBody }
                    HoverHandler { id: delCancH; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: root.modalState = "" }
                }

                Rectangle {
                    Layout.preferredHeight: 30
                    Layout.preferredWidth: 90
                    radius: Theme.radiusSm
                    color: delConfH.hovered ? Theme.error : Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.85)
                    Text { anchors.centerIn: parent; text: "Delete Group"; color: "#ffffff"; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeBody; font.bold: true }
                    HoverHandler { id: delConfH; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: root.deleteCurrentGroup() }
                }
            }
        }
    }

    // 4. Add Applications to Group Picker Modal
    Rectangle {
        anchors.centerIn: parent
        z: 100
        visible: root.modalState === "add-apps"
        width: 440
        height: 380
        radius: Theme.radiusLg
        color: Theme.surface
        border.color: Theme.borderStrong
        border.width: 1

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                MaterialIcon { iconName: "add_circle"; pixelSize: 18; color: Theme.accent }
                Text {
                    text: "Add to " + (root.currentGroup ? root.currentGroup.name : "Group")
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeTitle
                    font.bold: true
                    Layout.fillWidth: true
                }
                IconButton {
                    iconName: "close"
                    onClicked: root.modalState = ""
                }
            }

            // Search filter for available apps
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                radius: Theme.radiusSm
                color: Theme.bg
                border.color: addAppSearch.activeFocus ? Theme.accent : Theme.border

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 6
                    MaterialIcon { iconName: "search"; pixelSize: 15; color: Theme.textSecondary }
                    TextInput {
                        id: addAppSearch
                        Layout.fillWidth: true
                        verticalAlignment: Text.AlignVCenter
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeTitle
                        onTextChanged: root.modalFilterQuery = text
                        focus: root.modalState === "add-apps"
                        Text {
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            text: "Filter applications…"
                            color: Theme.textDim
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeTitle
                            visible: addAppSearch.text === ""
                        }
                    }
                }
            }

            // Scrollable list of applications
            ListView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 3
                model: root.availableAppsToAdd
                boundsBehavior: Flickable.StopAtBounds

                delegate: Rectangle {
                    id: addRow
                    required property var modelData
                    width: parent ? parent.width : 0
                    implicitHeight: 38
                    radius: Theme.radiusSm
                    color: addRowH.hovered ? Theme.surfaceHover : "transparent"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 10

                        IconImage {
                            source: root.iconSource(addRow.modelData.icon)
                            width: 24
                            height: 24
                        }

                        Text {
                            text: addRow.modelData.name
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Rectangle {
                            Layout.preferredHeight: 22
                            Layout.preferredWidth: 64
                            radius: Theme.radiusSm
                            color: addBtnH.hovered ? Theme.accent : Theme.surfaceActive
                            border.color: Theme.borderStrong

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 2
                                MaterialIcon { iconName: "add"; pixelSize: 12; color: addBtnH.hovered ? Theme.bg : Theme.accent }
                                Text { text: "Add"; color: addBtnH.hovered ? Theme.bg : Theme.text; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeLabel; font.bold: true }
                            }
                            HoverHandler { id: addBtnH; cursorShape: Qt.PointingHandCursor }
                            TapHandler {
                                onTapped: root.addAppToCurrentGroup(addRow.modelData.id)
                            }
                        }
                    }
                    HoverHandler { id: addRowH }
                }
            }
        }
    }
}
