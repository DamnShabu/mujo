import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import "../../theme"
import "../../components"
import "../../services"
import "Search.js" as Search

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
            var s = Search.scoreApp(e, q, fav)
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
        var q = modals.filterQuery.trim().toLowerCase()
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
                        modals.open("create")
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
                        modals.open("add-apps")
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
                        if (root.currentGroup)
                            modals.open("rename", root.currentGroup.name, root.currentGroup.icon || "folder")
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
                    onTapped: modals.open("delete")
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
                                onTapped: modals.removeAppFromCurrentGroup(cell.modelData.id)
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
                            modals.open(root.groups.length === 0 ? "create" : "add-apps")
                        }
                    }
                }
            }
        }
    }

    LauncherGroupModals {
        id: modals
        groups: root.groups
        currentGroup: root.currentGroup
        activeGroupIndex: root.activeGroupIndex
        availableApps: root.availableAppsToAdd
        onGroupsWritten: function(selectIndex) {
            if (selectIndex >= 0) root.activeGroupIndex = selectIndex
        }
    }
}
