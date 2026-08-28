import Quickshell
import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "calc.js" as Calc
import "../../theme"
import "../../components"
import "../../services"

// LauncherBody: Core interactive engine and visual frame for Mujo (無常).
// Integrates generative atmospheric flow backdrop, high-speed multi-tier search,
// flexible user-defined Groups, independent Favorites, live math evaluation, and keyboard ergonomics.
Item {
    id: root

    property bool open: false
    // One mode at a time. These used to be three independent booleans plus a
    // derived cmdMode, which meant every call site re-typed the same four-term
    // "which mode am I in" predicate — and groups + commands could both be
    // visible at once, stacked on top of each other.
    //
    // Command mode is special: typing "/" enters it, so it overrides the
    // selected base mode rather than replacing it.
    property string baseMode: "apps"    // apps | grid | groups | clip
    readonly property bool cmdMode: searchField.text.charAt(0) === "/"
    readonly property string mode: baseMode === "clip" ? "clip"
                                 : (cmdMode ? "commands" : baseMode)

    function setMode(m) {
        if (m === "commands") {
            if (root.baseMode === "clip") root.baseMode = "apps"
            if (!root.cmdMode) searchField.text = "/"
            return
        }
        root.baseMode = m
        if (m === "clip" || root.cmdMode) searchField.text = ""
    }
    property string screenName: ""
    property int baseWidth: Theme.launcherWidth
    property int baseHeight: Theme.launcherHeight
    signal requestClose

    property var listModel: []
    property var selectableResults: []
    property var modelIndices: []
    property var results: []
    property int selectedIndex: 0
    property string answer: ""

    // Fast 30ms debounce for instantaneous feel while preventing excessive layout recalculations
    Timer {
        id: searchDebounce
        interval: 30
        repeat: false
        onTriggered: root.doUpdateResults()
    }

    function focusSearch() { searchField.forceActiveFocus() }

    function updateResults() {
        searchDebounce.restart()
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

    function scoreApp(app, q, isFav) {
        if (!app || !app.name) return -1
        if (!q) return isFav ? 10000 : 1000

        var name = app.name.toLowerCase()
        var generic = (app.genericName || "").toLowerCase()
        var comment = (app.comment || "").toLowerCase()
        var exec = (app.execString || "").toLowerCase()
        var id = (app.id || "").toLowerCase()

        var s = -1

        // 1. Exact Match on name
        if (name === q) {
            s = 10000
        }
        // 2. Prefix Match on name
        else if (name.indexOf(q) === 0) {
            s = 8500 + Math.max(0, 500 - (name.length - q.length) * 10)
        }
        // 3. Word boundary match on name (e.g. "code" in "Visual Studio Code")
        else if (name.indexOf(" " + q) >= 0 || name.indexOf("-" + q) >= 0 || name.indexOf("_" + q) >= 0) {
            var idx = Math.max(name.indexOf(" " + q), Math.max(name.indexOf("-" + q), name.indexOf("_" + q)))
            s = 7200 - idx * 15
        }
        // 4. Generic name exact/prefix
        else if (generic === q) {
            s = 6800
        } else if (generic.indexOf(q) === 0) {
            s = 6300
        } else if (generic.indexOf(" " + q) >= 0) {
            s = 5800
        }
        // 5. Keyword match
        else if (app.keywords) {
            for (var k = 0; k < app.keywords.length; k++) {
                var kw = String(app.keywords[k]).toLowerCase()
                if (kw === q) { s = 5500; break }
                if (kw.indexOf(q) === 0) { s = 5200; break }
                if (kw.indexOf(q) > 0) { s = 4700; break }
            }
        }

        // 6. Substring in Name
        if (s < 0 && name.indexOf(q) >= 0) {
            s = 4200 - name.indexOf(q) * 20
        }

        // 7. Subsequence Fuzzy Match in Name
        if (s < 0) {
            var fz = root.fuzzySubsequenceScore(name, q)
            if (fz > 0) s = 3000 + fz
        }

        // 8. Generic / Comment / Exec / ID match
        if (s < 0 && generic.indexOf(q) >= 0) {
            s = 2200
        }
        if (s < 0 && (comment.indexOf(q) >= 0 || exec.indexOf(q) >= 0 || id.indexOf(q) >= 0)) {
            s = 1200
        }

        if (s < 0) return -1
        if (isFav) s += 2500
        return s
    }

    function doUpdateResults() {
        var q = searchField.text.trim().toLowerCase()
        root.answer = q === "" ? "" : (Calc.tryEvaluate(q) || "")

        var appsModel = DesktopEntries && DesktopEntries.applications
        var apps = appsModel ? appsModel.values : null
        if (!apps) {
            root.listModel = []
            root.selectableResults = []
            root.results = []
            root.modelIndices = []
            root.selectedIndex = 0
            return
        }

        var favs = SettingsBus.get("apps.favorites", [])
        function isFav(id) { return favs.indexOf(id) >= 0 }

        var groups = SettingsBus.get("apps.groups", [])
        var groupedAppIds = {}
        for (var gIdx = 0; gIdx < groups.length; gIdx++) {
            var grp = groups[gIdx]
            if (grp && grp.apps) {
                for (var aIdx = 0; aIdx < grp.apps.length; aIdx++) {
                    groupedAppIds[grp.apps[aIdx]] = true
                }
            }
        }

        function findAppById(id) {
            for (var i = 0; i < apps.length; i++) {
                if (apps[i] && (apps[i].id === id || apps[i].name === id)) return apps[i]
            }
            return null
        }

        var flattenedList = []
        var selectables = []
        var modelIdxMap = []
        var selCounter = 0

        // 1. Process Defined Groups
        for (var gi = 0; gi < groups.length; gi++) {
            var g = groups[gi]
            if (!g || !g.apps || g.apps.length === 0) continue
            var gApps = []
            for (var ai = 0; ai < g.apps.length; ai++) {
                var appEntry = findAppById(g.apps[ai])
                if (!appEntry || !appEntry.name || appEntry.noDisplay) continue
                var s = root.scoreApp(appEntry, q, isFav(appEntry.id))
                if (s < 0) continue
                appEntry._score = s
                gApps.push(appEntry)
            }

            // Sort group apps: Favorites first, then score DESC, then name ASC
            gApps.sort(function (a, b) {
                var aFav = isFav(a.id), bFav = isFav(b.id)
                if (aFav !== bFav) return aFav ? -1 : 1
                if (q && (b._score || 0) !== (a._score || 0)) return (b._score || 0) - (a._score || 0)
                return a.name.localeCompare(b.name)
            })

            if (gApps.length > 0) {
                // Add Group Header
                flattenedList.push({
                    isHeader: true,
                    groupName: g.name,
                    groupIcon: g.icon || "folder",
                    count: gApps.length
                })
                for (var giItem = 0; giItem < gApps.length; giItem++) {
                    var appObj = gApps[giItem]
                    modelIdxMap[selCounter] = flattenedList.length
                    flattenedList.push({
                        isHeader: false,
                        entry: appObj,
                        isFavorite: isFav(appObj.id),
                        groupName: g.name,
                        selectableIndex: selCounter
                    })
                    selectables.push(appObj)
                    selCounter++
                }
            }
        }

        // 2. Process Ungrouped / Other Applications
        var ungroupedApps = []
        for (var i = 0; i < apps.length; i++) {
            var unApp = apps[i]
            if (!unApp || !unApp.name || unApp.noDisplay) continue
            if (groupedAppIds[unApp.id]) continue
            var unScore = root.scoreApp(unApp, q, isFav(unApp.id))
            if (unScore < 0) continue
            unApp._score = unScore
            ungroupedApps.push(unApp)
        }

        ungroupedApps.sort(function (a, b) {
            var aFav = isFav(a.id), bFav = isFav(b.id)
            if (aFav !== bFav) return aFav ? -1 : 1
            if (q && (b._score || 0) !== (a._score || 0)) return (b._score || 0) - (a._score || 0)
            return a.name.localeCompare(b.name)
        })

        if (ungroupedApps.length > 0) {
            var hasOtherGroups = flattenedList.length > 0
            if (hasOtherGroups) {
                flattenedList.push({
                    isHeader: true,
                    groupName: "Other Applications",
                    groupIcon: "apps",
                    count: ungroupedApps.length
                })
                for (var ui = 0; ui < ungroupedApps.length; ui++) {
                    var uObj = ungroupedApps[ui]
                    modelIdxMap[selCounter] = flattenedList.length
                    flattenedList.push({
                        isHeader: false,
                        entry: uObj,
                        isFavorite: isFav(uObj.id),
                        groupName: "Other Applications",
                        selectableIndex: selCounter
                    })
                    selectables.push(uObj)
                    selCounter++
                }
            } else {
                // No custom groups: Split Favorites and All Applications sections cleanly
                var favUngrouped = ungroupedApps.filter(function(x) { return isFav(x.id) })
                var nonFavUngrouped = ungroupedApps.filter(function(x) { return !isFav(x.id) })

                if (favUngrouped.length > 0) {
                    flattenedList.push({
                        isHeader: true,
                        groupName: "Favorites",
                        groupIcon: "star",
                        count: favUngrouped.length
                    })
                    for (var fi = 0; fi < favUngrouped.length; fi++) {
                        modelIdxMap[selCounter] = flattenedList.length
                        flattenedList.push({
                            isHeader: false,
                            entry: favUngrouped[fi],
                            isFavorite: true,
                            groupName: "Favorites",
                            selectableIndex: selCounter
                        })
                        selectables.push(favUngrouped[fi])
                        selCounter++
                    }
                }

                if (nonFavUngrouped.length > 0) {
                    flattenedList.push({
                        isHeader: true,
                        groupName: favUngrouped.length > 0 ? "All Applications" : (q ? "Search Results" : "All Applications"),
                        groupIcon: q ? "search" : "apps",
                        count: nonFavUngrouped.length
                    })
                    for (var nfi = 0; nfi < nonFavUngrouped.length; nfi++) {
                        modelIdxMap[selCounter] = flattenedList.length
                        flattenedList.push({
                            isHeader: false,
                            entry: nonFavUngrouped[nfi],
                            isFavorite: false,
                            groupName: "All Applications",
                            selectableIndex: selCounter
                        })
                        selectables.push(nonFavUngrouped[nfi])
                        selCounter++
                    }
                }
            }
        }

        root.listModel = flattenedList
        root.selectableResults = selectables
        root.results = selectables
        root.modelIndices = modelIdxMap
        root.selectedIndex = 0
    }

    Connections {
        target: DesktopEntries && DesktopEntries.applications
        function onValuesChanged() { if (root.open) updateResults() }
    }

    Connections {
        target: SettingsBus
        function onSettingsChanged(key) {
            if (key === "apps.favorites" || key === "apps.groups") {
                if (root.open) updateResults()
            }
        }
    }

    function confirmSelection() {
        if (root.answer !== "") {
            copyProcess.command = ["wl-copy", root.answer]
            copyProcess.running = true
            Notifications.notify("Calculation copied", "= " + root.answer, "calculate", "low", { transient: true })
            root.requestClose()
        } else if (root.selectedIndex >= 0 && root.selectedIndex < root.results.length) {
            Launch.app(root.results[root.selectedIndex], root.screenName)
            root.requestClose()
        }
    }

    // Cycles through available modes via Tab
    readonly property var modeOrder: ["apps", "grid", "groups", "commands", "clip"]
    function cycleMode() {
        var i = root.modeOrder.indexOf(root.mode)
        root.setMode(root.modeOrder[(i + 1) % root.modeOrder.length])
    }

    function toggleFavorite(appId) {
        if (!appId) return
        var favs = SettingsBus.get("apps.favorites", [])
        var idx = favs.indexOf(appId)
        var updated = favs.filter(function (x) { return x !== appId })
        var isAdded = false
        if (idx < 0) {
            updated.push(appId)
            isAdded = true
        }
        SettingsBus.set("apps.favorites", updated)
        var app = root.results[root.selectedIndex]
        var name = (app && app.id === appId) ? app.name : appId
        Notifications.notify(isAdded ? "Added to Favorites" : "Removed from Favorites", name, "star", "low", { transient: true })
    }

    Process { id: copyProcess; command: ["wl-copy"] }

    onOpenChanged: {
        if (root.open) {
            searchField.text = ""
            root.baseMode = "apps"
            doUpdateResults()
            root.selectedIndex = 0
        }
    }

    Rectangle {
        id: bg
        anchors.fill: parent
        radius: Theme.radiusLg
        clip: true
        color: Theme.bg
        border.color: Theme.border
        border.width: 1

        // Specular top highlight line
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 1
            color: Theme.withAlpha("#ffffff", 0.1)
        }

        // Subtle ambient flow backdrop
        MujoLivingCanvas {
            id: livingBg
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.left: parent.left
            height: 180
            opacity: Anim.illustrations ? 0.08 : 0.0
            animated: root.open
            showEnso: true
            showWaves: true
            showParticles: false
            accentColor: Theme.accent
            flowSpeed: 0.4
            intensity: 0.5
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            // ── Clean Rebalanced Header Bar with Mode Navigation ─────────────
            RowLayout {
                Layout.fillWidth: true
                Layout.bottomMargin: 2
                spacing: 8

                // Mode tabs. One row, one model — the five modes used to be five
                // copy-pasted Rectangles, each repeating the same four-term
                // "am I the active mode" predicate four times over.
                RowLayout {
                    spacing: 4
                    Layout.alignment: Qt.AlignVCenter

                    Repeater {
                        model: [
                            { id: "apps",     label: "Apps",      icon: "search" },
                            { id: "grid",     label: "Grid",      icon: "grid_view" },
                            { id: "groups",   label: "Groups",    icon: "folder_special" },
                            { id: "commands", label: "Commands",  icon: "terminal" },
                            { id: "clip",     label: "Clipboard", icon: "content_paste" }
                        ]
                        delegate: Rectangle {
                            id: modeTab
                            required property var modelData
                            readonly property bool current: root.mode === modelData.id

                            implicitHeight: 28
                            implicitWidth: tabRow.implicitWidth + 18
                            radius: Theme.radiusSm
                            color: modeTab.current ? Theme.accentDim
                                 : (tabHh.hovered ? Theme.surfaceHover : "transparent")
                            border.color: modeTab.current ? Theme.withAlpha(Theme.accent, 0.4) : "transparent"

                            Behavior on color { ColorAnimation { duration: Anim.d(Anim.fast) } }

                            RowLayout {
                                id: tabRow
                                anchors.centerIn: parent
                                spacing: 5
                                MaterialIcon {
                                    iconName: modeTab.modelData.icon
                                    pixelSize: 13
                                    color: modeTab.current ? Theme.accent : Theme.textDim
                                }
                                Text {
                                    text: modeTab.modelData.label
                                    color: modeTab.current ? Theme.text : Theme.textSecondary
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.bold: modeTab.current
                                }
                            }

                            HoverHandler { id: tabHh; cursorShape: Qt.PointingHandCursor }
                            TapHandler {
                                gesturePolicy: TapHandler.ReleaseWithinBounds
                                onTapped: root.setMode(modeTab.modelData.id)
                            }
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                // Live Results Match Counter Pill
                Rectangle {
                    visible: searchField.text !== "" && root.mode === "apps"
                    implicitWidth: cntTxt.implicitWidth + 12
                    implicitHeight: 22
                    radius: Theme.radiusSm
                    color: Theme.surfaceActive
                    border.color: Theme.borderStrong

                    Text {
                        id: cntTxt
                        anchors.centerIn: parent
                        text: root.results.length + " match" + (root.results.length === 1 ? "" : "es")
                        color: Theme.textSecondary
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeLabel
                    }
                }
            }

            // ── Search Input Field ────────────────────────────────────────────
            Rectangle {
                id: searchWrap
                Layout.fillWidth: true
                Layout.preferredHeight: 48
                radius: Theme.radiusMd
                color: Theme.surface
                border.color: searchField.activeFocus
                              ? Theme.accent
                              : Theme.border
                border.width: 1

                Behavior on border.color { ColorAnimation { duration: Anim.d(Anim.fast) } }

                // Dynamic Mode / Search Icon
                Item {
                    anchors.left: parent.left
                    anchors.leftMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    width: 20
                    height: 20

                    MaterialIcon {
                        anchors.centerIn: parent
                        iconName: root.mode === "clip" ? "content_paste"
                                : (root.mode === "commands" ? "terminal"
                                : (root.mode === "groups" ? "folder_special"
                                : (root.mode === "grid" ? "grid_view" : "search")))
                        pixelSize: 18
                        color: searchField.activeFocus ? Theme.accent : Theme.textSecondary
                        Behavior on color { ColorAnimation { duration: Anim.d(Anim.fast) } }
                    }
                }

                TextInput {
                    id: searchField
                    anchors.fill: parent
                    leftPadding: 44
                    rightPadding: clearBtn.visible ? 36 : 14
                    focus: true
                    verticalAlignment: Text.AlignVCenter
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 14
                    selectByMouse: true
                    activeFocusOnPress: true

                    onTextChanged: {
                        if (root.mode === "apps") updateResults()
                        else root.answer = ""
                        root.selectedIndex = 0
                    }

                    Keys.onTabPressed: function(event) {
                        root.cycleMode()
                        event.accepted = true
                    }

                    Keys.onEscapePressed: {
                        if (actionBar.dropdownOpen) {
                            actionBar.dropdownOpen = false
                        } else if (root.mode === "clip" || root.mode === "groups") {
                            root.setMode("apps")
                        } else if (root.mode === "commands") {
                            searchField.text = ""
                        } else if (searchField.text !== "") {
                            searchField.text = ""
                        } else {
                            root.requestClose()
                        }
                    }

                    Keys.onLeftPressed: function (event) {
                        if (root.mode === "groups" && searchField.text === "") {
                            groupsViewLoader.item.move(-1, 0)
                            event.accepted = true
                        } else if (root.mode === "grid" && searchField.text === "") {
                            appGridLoader.item.move(-1, 0)
                            event.accepted = true
                        } else event.accepted = false
                    }

                    Keys.onRightPressed: function (event) {
                        if (root.mode === "groups" && searchField.text === "") {
                            groupsViewLoader.item.move(1, 0)
                            event.accepted = true
                        } else if (root.mode === "grid" && searchField.text === "") {
                            appGridLoader.item.move(1, 0)
                            event.accepted = true
                        } else event.accepted = false
                    }

                    Keys.onReturnPressed: {
                        if (root.mode === "clip") { clipListLoader.item.activateSelected(); return }
                        if (root.mode === "commands") { cmdPaletteLoader.item.activateSelected(); return }
                        if (root.mode === "groups") { groupsViewLoader.item.activateSelected(); return }
                        if (root.mode === "grid") { appGridLoader.item.activateSelected(); return }
                        if (actionBar.dropdownOpen) {
                            if (dropdown.hoverIndex >= 0) {
                                dropdown.activate(dropdown.hoverIndex)
                            }
                            return
                        }
                        root.confirmSelection()
                    }

                    Keys.onUpPressed: {
                        if (root.mode === "clip") { clipListLoader.item.move(0, -1); return }
                        if (root.mode === "commands") { cmdPaletteLoader.item.move(0, -1); return }
                        if (root.mode === "groups") { groupsViewLoader.item.move(0, -1); return }
                        if (root.mode === "grid") { appGridLoader.item.move(0, -1); return }
                        if (actionBar.dropdownOpen) {
                            dropdown.hoverIndex = Math.max(0, dropdown.hoverIndex - 1)
                            return
                        }
                        if (root.selectableResults.length === 0) return
                        root.selectedIndex = (root.selectedIndex - 1 + root.selectableResults.length) % root.selectableResults.length
                        var modelIdx = (root.modelIndices && root.modelIndices[root.selectedIndex] !== undefined) ? root.modelIndices[root.selectedIndex] : root.selectedIndex
                        resultList.positionViewAtIndex(modelIdx, ListView.Contain)
                    }

                    Keys.onDownPressed: {
                        if (root.mode === "clip") { clipListLoader.item.move(0, 1); return }
                        if (root.mode === "commands") { cmdPaletteLoader.item.move(0, 1); return }
                        if (root.mode === "groups") { groupsViewLoader.item.move(0, 1); return }
                        if (root.mode === "grid") { appGridLoader.item.move(0, 1); return }
                        if (actionBar.dropdownOpen) {
                            dropdown.hoverIndex = Math.min(dropdown.model.length - 1, dropdown.hoverIndex + 1)
                            return
                        }
                        if (root.selectableResults.length === 0) return
                        root.selectedIndex = (root.selectedIndex + 1) % root.selectableResults.length
                        var modelIdx = (root.modelIndices && root.modelIndices[root.selectedIndex] !== undefined) ? root.modelIndices[root.selectedIndex] : root.selectedIndex
                        resultList.positionViewAtIndex(modelIdx, ListView.Contain)
                    }

                    Keys.onPressed: function(event) {
                        if (event.key === Qt.Key_K && (event.modifiers & Qt.ControlModifier)) {
                            actionBar.toggleDropdown()
                            event.accepted = true
                        } else if (event.key === Qt.Key_F && (event.modifiers & Qt.ControlModifier)) {
                            if (root.mode === "apps") {
                                var cur = root.results[root.selectedIndex]
                                if (cur && cur.id) root.toggleFavorite(cur.id)
                                event.accepted = true
                            }
                        }
                    }

                    Text {
                        anchors.fill: parent
                        leftPadding: 44
                        rightPadding: 14
                        verticalAlignment: Text.AlignVCenter
                        text: root.mode === "clip" ? "Search clipboard history…"
                            : (root.mode === "commands" ? "Type a command or settings query…"
                            : (root.mode === "groups" ? "Filter applications in this group…"
                            : (root.mode === "grid" ? "Filter installed applications…"
                            : "Search apps, calculate math, or type / for commands…")))
                        color: Theme.textDim
                        font.family: Theme.fontFamily
                        font.pixelSize: 14
                        visible: searchField.text === ""
                    }
                }

                // Clear Query Button
                Item {
                    id: clearBtn
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    width: 24
                    height: 24
                    visible: searchField.text !== ""

                    Rectangle {
                        anchors.fill: parent
                        radius: 12
                        color: clearHh.hovered ? Theme.surfaceActive : "transparent"
                        MaterialIcon {
                            anchors.centerIn: parent
                            iconName: "close"
                            pixelSize: 14
                            color: clearHh.hovered ? Theme.text : Theme.textDim
                        }
                    }
                    HoverHandler { id: clearHh; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: { searchField.text = ""; searchField.forceActiveFocus() } }
                }
            }

            // ── Live Math Calculation Result Card ─────────────────────────────
            Rectangle {
                id: answerWrap
                Layout.fillWidth: true
                Layout.preferredHeight: root.answer === "" ? 0 : 44
                clip: true
                visible: Layout.preferredHeight > 0
                radius: Theme.radiusMd
                color: Anim.ambient ? Theme.withAlpha(Theme.accent, 0.18) : Theme.accentDim
                border.color: Theme.accent
                border.width: 1

                Behavior on Layout.preferredHeight { NumberAnimation { duration: Anim.d(100); easing.type: Easing.OutQuad } }

                MouseArea { anchors.fill: parent; onClicked: root.confirmSelection() }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    spacing: 10

                    Rectangle {
                        Layout.preferredWidth: 26
                        Layout.preferredHeight: 26
                        radius: Theme.radiusSm
                        color: Theme.withAlpha(Theme.accent, 0.25)
                        MaterialIcon {
                            anchors.centerIn: parent
                            iconName: "calculate"
                            pixelSize: 16
                            color: Theme.accent
                        }
                    }

                    Text {
                        text: "= " + root.answer
                        color: Theme.text
                        font.family: Theme.fontMono
                        font.pixelSize: 15
                        font.bold: true
                        Layout.fillWidth: true
                    }

                    Rectangle {
                        implicitWidth: copyT.implicitWidth + 14
                        implicitHeight: 22
                        radius: Theme.radiusSm
                        color: Theme.withAlpha(Theme.accent, 0.25)
                        border.color: Theme.accent

                        RowLayout {
                            id: copyT
                            anchors.centerIn: parent
                            spacing: 4
                            MaterialIcon {
                                iconName: "keyboard_return"
                                pixelSize: 11
                                color: Theme.accent
                            }
                            Text {
                                text: "Copy Result"
                                color: Theme.accent
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSmall
                                font.bold: true
                            }
                        }
                    }
                }
            }

            // ── Main Viewport Area (List / Grid / Groups / Commands / Clipboard) ─
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                // 1. Search Results List Mode
                ListView {
                    id: resultList
                    anchors.fill: parent
                    visible: root.mode === "apps" && root.listModel.length > 0
                    clip: true
                    spacing: 3
                    model: root.listModel
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: Loader {
                        id: rowLoader
                        required property var modelData
                        required property int index
                        width: resultList.width
                        sourceComponent: modelData.isHeader ? headerComponent : resultComponent
                    }

                    Component {
                        id: headerComponent
                        LauncherGroupHeader {
                            groupName: modelData.groupName
                            groupIcon: modelData.groupIcon
                            count: modelData.count
                            isFirst: index === 0
                        }
                    }

                    Component {
                        id: resultComponent
                        LauncherResult {
                            highlighted: modelData.selectableIndex === root.selectedIndex
                            entry: modelData.entry
                            query: searchField.text
                            onFavoriteToggled: function(id) { root.toggleFavorite(id) }
                            onSelectRequested: {
                                root.selectedIndex = modelData.selectableIndex
                            }
                            onLaunchRequested: function(entry) {
                                Launch.app(entry, root.screenName)
                                root.requestClose()
                            }
                        }
                    }
                }

                // 2. Empty State for List Mode
                LauncherEmptyState {
                    anchors.centerIn: parent
                    visible: root.mode === "apps" && root.listModel.length === 0
                    mode: searchField.text === "" ? "initial" : "no-results"
                    query: searchField.text
                }

                // Modes 3-6 used to be four fully-built component trees --
                // LauncherGrid (652 lines), LauncherGroupsView (1089, including
                // three modal dialogs), CommandPalette and ClipboardList --
                // instantiated at shell startup, per screen, and merely
                // `visible:`-toggled. That is ~3400 lines of live QML resident
                // from boot, times the number of monitors, for a UI that only
                // exists after a keybind. They are all anchors.fill, so a Loader
                // changes nothing about their size or layout; every call site
                // below is already guarded by the same `root.mode` check that
                // gates the Loader.

                // 3. Grid Mode
                Loader {
                    id: appGridLoader
                    anchors.fill: parent
                    readonly property bool wanted: root.mode === "grid"
                    // Latch: build on first use, then keep. These used to be
                    // always-built, so scroll position and selection survived
                    // mode switches and launcher close/open; latching preserves
                    // that exactly while still costing nothing until the mode is
                    // opened for the first time.
                    property bool everUsed: false
                    onWantedChanged: if (wanted) everUsed = true
                    Component.onCompleted: if (wanted) everUsed = true
                    active: everUsed
                    visible: wanted
                    sourceComponent: LauncherGrid {
                        screenName: root.screenName
                        query: searchField.text
                        onRequestClose: root.requestClose()
                    }
                }

                // 4. Groups Mode
                Loader {
                    id: groupsViewLoader
                    anchors.fill: parent
                    readonly property bool wanted: root.mode === "groups"
                    // Latch: build on first use, then keep. These used to be
                    // always-built, so scroll position and selection survived
                    // mode switches and launcher close/open; latching preserves
                    // that exactly while still costing nothing until the mode is
                    // opened for the first time.
                    property bool everUsed: false
                    onWantedChanged: if (wanted) everUsed = true
                    Component.onCompleted: if (wanted) everUsed = true
                    active: everUsed
                    visible: wanted
                    sourceComponent: LauncherGroupsView {
                        screenName: root.screenName
                        query: searchField.text
                        onRequestClose: root.requestClose()
                    }
                }

                // 5. Command Palette Mode
                Loader {
                    id: cmdPaletteLoader
                    anchors.fill: parent
                    readonly property bool wanted: root.mode === "commands"
                    // Latch: build on first use, then keep. These used to be
                    // always-built, so scroll position and selection survived
                    // mode switches and launcher close/open; latching preserves
                    // that exactly while still costing nothing until the mode is
                    // opened for the first time.
                    property bool everUsed: false
                    onWantedChanged: if (wanted) everUsed = true
                    Component.onCompleted: if (wanted) everUsed = true
                    active: everUsed
                    visible: wanted
                    sourceComponent: CommandPalette {
                        screenName: root.screenName
                        query: searchField.text.slice(1)
                        onRequestClose: root.requestClose()
                        onRequestClip: root.setMode("clip")
                    }
                }

                // 6. Clipboard History Mode
                Loader {
                    id: clipListLoader
                    anchors.fill: parent
                    readonly property bool wanted: root.mode === "clip"
                    // Latch: build on first use, then keep. These used to be
                    // always-built, so scroll position and selection survived
                    // mode switches and launcher close/open; latching preserves
                    // that exactly while still costing nothing until the mode is
                    // opened for the first time.
                    property bool everUsed: false
                    onWantedChanged: if (wanted) everUsed = true
                    Component.onCompleted: if (wanted) everUsed = true
                    active: everUsed
                    visible: wanted
                    sourceComponent: ClipboardList {
                        query: searchField.text
                        onRequestClose: root.requestClose()
                    }
                }
            }

            // ── Action Bar ───────────────────────────────────────────────────
            LauncherActionBar {
                id: actionBar
                selectedEntry: root.mode === "apps" && root.results.length > 0
                               ? root.results[root.selectedIndex]
                               : null
                screenName: root.screenName
                dropdownParent: root
                onRequestClose: root.requestClose()
                onTriggered: root.requestClose()
            }
        }
    }

    // ── Dropdown Actions Menu (Ctrl+K) ────────────────────────────────────────
    Rectangle {
        id: dropdown
        visible: opacity > 0
        z: 100
        x: actionBar.dropdownPos.x
        y: actionBar.dropdownPos.y
        width: 240
        height: dropdownCol.implicitHeight + 14
        radius: Theme.radiusMd
        color: Theme.surface
        border.color: Theme.borderStrong
        border.width: 1

        opacity: actionBar.dropdownOpen ? 1.0 : 0.0
        scale: actionBar.dropdownOpen ? 1.0 : 0.95
        Behavior on opacity { NumberAnimation { duration: Anim.d(Anim.fast) } }
        Behavior on scale { NumberAnimation { duration: Anim.d(Anim.fast); easing.type: Anim.easeStandard } }

        property int hoverIndex: -1

        // Single dispatch for the menu, so the keyboard and the mouse cannot
        // drift apart. Favourite/group need launcher state; the rest are the
        // action bar's.
        function activate(index) {
            actionBar.dropdownOpen = false
            if (index === 1) {
                var cur = root.results[root.selectedIndex]
                if (cur && cur.id) root.toggleFavorite(cur.id)
            } else if (index === 2) {
                root.setMode("groups")
            } else {
                actionBar.triggerAction(index)
            }
        }

        property var model: [
            { label: "Open Application", icon: "open_in_new", shortcut: "Enter" },
            { label: "Toggle Favorite", icon: "star", shortcut: "Ctrl F" },
            { label: "Manage Groups", icon: "folder_special", shortcut: "" },
            { label: "Copy App Name", icon: "content_copy", shortcut: "" },
            { label: "Copy App ID", icon: "description", shortcut: "" },
            { label: "Copy Exec Path", icon: "folder_copy", shortcut: "" }
        ]

        ColumnLayout {
            id: dropdownCol
            anchors.fill: parent
            anchors.margins: 7
            spacing: 2

            Repeater {
                model: dropdown.model

                delegate: Rectangle {
                    required property int index
                    required property var modelData

                    Layout.fillWidth: true
                    Layout.preferredHeight: 30
                    radius: Theme.radiusSm
                    color: dropdown.hoverIndex === index ? Theme.surfaceHover : "transparent"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 8

                        MaterialIcon {
                            iconName: modelData.icon
                            pixelSize: 14
                            color: dropdown.hoverIndex === index ? Theme.accent : Theme.textSecondary
                        }
                        Text {
                            text: modelData.label
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            font.bold: dropdown.hoverIndex === index
                            Layout.fillWidth: true
                        }
                        Text {
                            text: modelData.shortcut
                            color: Theme.textSecondary
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSizeLabel - 1
                            visible: modelData.shortcut !== ""
                        }
                    }

                    HoverHandler { onHoveredChanged: dropdown.hoverIndex = hovered ? index : -1 }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: dropdown.activate(index)
                    }
                }
            }
        }
    }

    // Dismiss scrim for dropdown
    MouseArea {
        anchors.fill: parent
        z: 99
        visible: actionBar.dropdownOpen
        onClicked: actionBar.dropdownOpen = false
    }
}
