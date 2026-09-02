import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../theme"
import "../../components"
import "../../services"
import "TagQuery.js" as TagQuery

// Wallpaper Engine search box, active-tag row, quick filter bar and filter
// drawer. Mirrors WallhavenControls in shape but not in content: the two
// services expose different filter axes, so only the tag parsing is shared.
ColumnLayout {
    id: controls

    property var weSuggestions: []
    property int selectedWeSuggestionIndex: -1
    property bool weFiltersExpanded: false

    // The panel's dismiss scrim needs to know when a dropdown is open.
    readonly property bool suggestionsOpen: weSuggestions.length > 0 && weSearchInput.activeFocus

    readonly property var weSortOptions: [
        { id: "trend",      label: "Trending",   icon: "trending_up" },
        { id: "toprated",   label: "Top Rated",  icon: "star" },
        { id: "subscribed", label: "Subscribed", icon: "favorite" },
        { id: "mostrecent", label: "Latest",     icon: "schedule" },
        { id: "relevance",  label: "Relevance",  icon: "sort" }
    ]

    readonly property var weTypeOptions: [
        { id: "all",   label: "All Types" },
        { id: "scene", label: "Scene (2D/3D)" },
        { id: "video", label: "Video" },
        { id: "web",   label: "Web" }
    ]

    spacing: 10
    z: weSuggestions.length > 0 ? 100 : 20

    function dismissSuggestions() {
        weSuggestions = []
        selectedWeSuggestionIndex = -1
    }

    // Add a whole tag — what clicking a tag chip in the inspector modal does.
    function addTag(tag) {
        const next = TagQuery.append(weSearchInput.text, tag)
        if (next !== null) search(next)
    }

    // Accept a completion, replacing the partial word being typed.
    function applyWeSuggestion(suggestedName) {
        const next = TagQuery.replaceLastToken(weSearchInput.text, suggestedName)
        if (next !== null) search(next)
    }

    // Autocomplete debounce: one query per pause in typing, not per keystroke.
    Timer {
        id: weAutocompleteTimer
        interval: 220
        repeat: false
        onTriggered: {
            const txt = weSearchInput.text.trim()
            controls.weSuggestions = txt.length >= 2 ? WallpaperEngine.suggestTags(TagQuery.lastToken(txt), 8) : []
            controls.selectedWeSuggestionIndex = -1
        }
    }

    function search(query) {
        weSearchInput.text = query
        WallpaperEngine.query = query
        dismissSuggestions()
        WallpaperEngine.search(true)
    }

    // Search Bar Row
    RowLayout {
        id: weSearchBarRow
        Layout.fillWidth: true
        spacing: 8
        z: controls.weSuggestions.length > 0 ? 100 : 1

        // Source Toggle (Steam Workshop vs Installed)
        RowLayout {
            spacing: 4
            DisplayChip {
                label: "Steam Workshop"
                selected: WallpaperEngine.activeSource === "workshop"
                onClicked: {
                    WallpaperEngine.activeSource = "workshop"
                    WallpaperEngine.search(true)
                }
            }
            DisplayChip {
                label: "Installed (" + WallpaperEngine.totalInstalledCount + ")"
                selected: WallpaperEngine.activeSource === "installed"
                onClicked: {
                    WallpaperEngine.activeSource = "installed"
                    WallpaperEngine.refreshInstalled()
                }
            }
        }

        Rectangle { width: 1; height: 20; color: Theme.border }

        // Search Input Box with Autocomplete Dropdown
        Rectangle {
            id: weSearchBox
            Layout.fillWidth: true
            implicitHeight: 38
            radius: Theme.radiusMd
            color: Theme.surface
            border.color: weSearchInput.activeFocus ? Theme.accent : Theme.border
            border.width: 1
            z: controls.weSuggestions.length > 0 ? 100 : 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 8
                spacing: 8

                MaterialIcon {
                    iconName: "search"
                    pixelSize: 18
                    color: weSearchInput.activeFocus ? Theme.accent : Theme.textSecondary
                }

                TextInput {
                    id: weSearchInput
                    Layout.fillWidth: true
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeBody
                    verticalAlignment: TextInput.AlignVCenter
                    clip: true
                    selectByMouse: true

                    onTextChanged: {
                        WallpaperEngine.query = text
                        weAutocompleteTimer.restart()
                    }

                    Keys.onReturnPressed: {
                        if (controls.weSuggestions.length > 0 && controls.selectedWeSuggestionIndex >= 0 && controls.selectedWeSuggestionIndex < controls.weSuggestions.length) {
                            var picked = controls.weSuggestions[controls.selectedWeSuggestionIndex]
                            controls.applyWeSuggestion(picked.name)
                        } else {
                            WallpaperEngine.search(true)
                            controls.weSuggestions = []
                            controls.selectedWeSuggestionIndex = -1
                        }
                    }

                    Keys.onDownPressed: {
                        if (controls.weSuggestions.length > 0) {
                            controls.selectedWeSuggestionIndex = Math.min(controls.weSuggestions.length - 1, controls.selectedWeSuggestionIndex + 1)
                        }
                    }

                    Keys.onUpPressed: {
                        if (controls.weSuggestions.length > 0) {
                            controls.selectedWeSuggestionIndex = Math.max(-1, controls.selectedWeSuggestionIndex - 1)
                        }
                    }

                    Keys.onEscapePressed: {
                        controls.weSuggestions = []
                        controls.selectedWeSuggestionIndex = -1
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: weSearchInput.text === ""
                        text: "Search Steam Workshop items (e.g. Cyberpunk, Anime, Gaming, 4K)…"
                        color: Theme.textDim
                        font: weSearchInput.font
                    }
                }

                IconButton {
                    visible: weSearchInput.text !== ""
                    iconName: "close"
                    implicitWidth: 24; implicitHeight: 24
                    onClicked: {
                        weSearchInput.text = ""
                        WallpaperEngine.query = ""
                        WallpaperEngine.search(true)
                    }
                }
            }

            // Autocomplete Dropdown
            Rectangle {
                id: weAutocompleteDropdown
                visible: controls.weSuggestions.length > 0
                anchors.top: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.topMargin: 4
                implicitHeight: Math.min(300, weSuggestionCol.implicitHeight + 10)
                radius: Theme.radiusMd
                color: Theme.active.surface
                border.color: Theme.borderStrong
                border.width: 1
                clip: true
                z: 100

                MujoFlickable {
                    anchors.fill: parent
                    anchors.margins: 4
                    contentHeight: weSuggestionCol.implicitHeight

                    ColumnLayout {
                        id: weSuggestionCol
                        width: parent.width
                        spacing: 2

                        Repeater {
                            model: controls.weSuggestions
                            delegate: Rectangle {
                                id: weSugItem
                                required property var modelData
                                required property int index
                                readonly property bool isSelected: controls.selectedWeSuggestionIndex === index

                                Layout.fillWidth: true
                                implicitHeight: 34
                                radius: Theme.radiusSm
                                color: isSelected ? Theme.accentDim : (weSugMa.containsMouse ? Theme.surfaceHover : "transparent")
                                border.color: isSelected ? Theme.accent : "transparent"

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    spacing: 8

                                    MaterialIcon {
                                        iconName: "tag"
                                        pixelSize: 14
                                        color: weSugItem.isSelected ? Theme.accent : Theme.textSecondary
                                    }

                                    Text {
                                        text: weSugItem.modelData.name
                                        color: weSugItem.isSelected ? Theme.accent : Theme.text
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeBody
                                        font.bold: weSugItem.isSelected
                                    }

                                    Text {
                                        visible: weSugItem.modelData.alias !== ""
                                        text: "(" + weSugItem.modelData.alias + ")"
                                        color: Theme.textDim
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeSmall
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }

                                    Item { Layout.fillWidth: true; visible: weSugItem.modelData.alias === "" }

                                    Rectangle {
                                        implicitHeight: 18
                                        implicitWidth: weCatLabel.implicitWidth + 10
                                        radius: Theme.radiusSm
                                        color: Theme.surfaceActive
                                        border.color: Theme.border
                                        Text {
                                            id: weCatLabel
                                            anchors.centerIn: parent
                                            text: weSugItem.modelData.category
                                            color: Theme.textSecondary
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontSizeLabel
                                        }
                                    }
                                }

                                MouseArea {
                                    id: weSugMa
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    hoverEnabled: true
                                    preventStealing: true
                                    onEntered: controls.selectedWeSuggestionIndex = weSugItem.index
                                    onClicked: controls.applyWeSuggestion(weSugItem.modelData.name)
                                }
                            }
                        }
                    }
                }
            }
        }

        // Search Button
        DialogButton {
            text: "Search"
            iconName: "search"
            primary: true
            onClicked: {
                WallpaperEngine.search(true)
                controls.weSuggestions = []
            }
        }

        // Filter Drawer Toggle Button
        Rectangle {
            implicitHeight: 38
            implicitWidth: weFilterBtnRow.implicitWidth + 24
            radius: Theme.radiusMd
            color: controls.weFiltersExpanded || WallpaperEngine.activeFiltersCount > 0 ? Theme.accentDim : (weFiltMa.containsMouse ? Theme.surfaceHover : Theme.surface)
            border.color: controls.weFiltersExpanded || WallpaperEngine.activeFiltersCount > 0 ? Theme.accent : Theme.border

            RowLayout {
                id: weFilterBtnRow
                anchors.centerIn: parent
                spacing: 6

                MaterialIcon {
                    iconName: "tune"
                    pixelSize: 16
                    color: controls.weFiltersExpanded || WallpaperEngine.activeFiltersCount > 0 ? Theme.accent : Theme.textSecondary
                }

                Text {
                    text: "Filters"
                    color: controls.weFiltersExpanded || WallpaperEngine.activeFiltersCount > 0 ? Theme.accent : Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeBody
                    font.bold: controls.weFiltersExpanded || WallpaperEngine.activeFiltersCount > 0
                }

                Rectangle {
                    visible: WallpaperEngine.activeFiltersCount > 0
                    implicitWidth: weBadgeNum.implicitWidth + 8
                    implicitHeight: 18
                    radius: 9
                    color: Theme.accent

                    Text {
                        id: weBadgeNum
                        anchors.centerIn: parent
                        text: "" + WallpaperEngine.activeFiltersCount
                        color: Theme.accentText
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeLabel
                        font.bold: true
                    }
                }
            }

            MouseArea {
                id: weFiltMa
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                onClicked: controls.weFiltersExpanded = !controls.weFiltersExpanded
            }
        }

        // Refresh Button
        IconButton {
            iconName: "refresh"
            implicitWidth: 38; implicitHeight: 38
            onClicked: {
                if (WallpaperEngine.activeSource === "installed") {
                    WallpaperEngine.refreshInstalled()
                } else {
                    WallpaperEngine.search(true)
                }
            }
        }
    }

    // Active Tags Row for WE
    Flow {
        Layout.fillWidth: true
        spacing: 6
        visible: WallpaperEngine.tags.length > 0

        Repeater {
            model: WallpaperEngine.tags
            delegate: Rectangle {
                id: weActiveTagPill
                required property var modelData
                implicitHeight: 26
                implicitWidth: weTagTextRow.implicitWidth + 14
                radius: Theme.radiusSm
                color: we_act_hh.hovered ? Theme.surfaceHover : Theme.accentDim
                border.color: Theme.accent

                RowLayout {
                    id: weTagTextRow
                    anchors.centerIn: parent
                    spacing: 4

                    Text {
                        text: "#" + weActiveTagPill.modelData
                        color: Theme.accent
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        font.bold: true
                    }

                    MaterialIcon {
                        iconName: "close"
                        pixelSize: 12
                        color: Theme.accent
                    }
                }

                HoverHandler { id: we_act_hh; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: WallpaperEngine.removeTag(weActiveTagPill.modelData) }
            }
        }

        Rectangle {
            implicitHeight: 26
            implicitWidth: weClrTagsLbl.implicitWidth + 14
            radius: Theme.radiusSm
            color: we_clr_hh.hovered ? Theme.surfaceHover : Theme.surface
            border.color: we_clr_hh.hovered ? Theme.borderInteractive : Theme.border

            Text {
                id: weClrTagsLbl
                anchors.centerIn: parent
                text: "Clear Tags"
                color: Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
            }
            HoverHandler { id: we_clr_hh; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: WallpaperEngine.clearTags() }
        }
    }

    // Quick Filter Bar (Purity, Type, Sort & Steam Status)
    RowLayout {
        Layout.fillWidth: true
        spacing: 10

        // Purity Filters (SFW, Sketchy, NSFW)
        RowLayout {
            spacing: 4
            Text {
                text: "Purity:"
                color: Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
            }

            DisplayChip {
                label: "SFW"
                selected: WallpaperEngine.puritySfw
                onClicked: {
                    WallpaperEngine.puritySfw = !WallpaperEngine.puritySfw
                    WallpaperEngine.search(true)
                }
            }

            DisplayChip {
                label: "Sketchy"
                selected: WallpaperEngine.puritySketchy
                onClicked: {
                    WallpaperEngine.puritySketchy = !WallpaperEngine.puritySketchy
                    WallpaperEngine.search(true)
                }
            }

            DisplayChip {
                label: "NSFW"
                selected: WallpaperEngine.purityNsfw
                onClicked: {
                    WallpaperEngine.purityNsfw = !WallpaperEngine.purityNsfw
                    WallpaperEngine.search(true)
                }
            }
        }

        Rectangle { width: 1; height: 18; color: Theme.border }

        // Type Filter Chips
        RowLayout {
            spacing: 4
            Text {
                text: "Type:"
                color: Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
            }

            Repeater {
                model: controls.weTypeOptions
                delegate: DisplayChip {
                    required property var modelData
                    label: modelData.label
                    selected: WallpaperEngine.selectedType === modelData.id
                    onClicked: {
                        WallpaperEngine.selectedType = modelData.id
                        WallpaperEngine.search(true)
                    }
                }
            }
        }

        Rectangle { width: 1; height: 18; color: Theme.border }

        // Sort Filter Chips
        RowLayout {
            spacing: 4
            Text {
                text: "Sort:"
                color: Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
            }

            Repeater {
                model: controls.weSortOptions
                delegate: DisplayChip {
                    required property var modelData
                    label: modelData.label
                    selected: WallpaperEngine.sorting === modelData.id
                    onClicked: {
                        WallpaperEngine.sorting = modelData.id
                        WallpaperEngine.search(true)
                    }
                }
            }
        }

        Item { Layout.fillWidth: true }

        // Steam Status Pill
        Rectangle {
            implicitHeight: 26
            implicitWidth: steamPillRow.implicitWidth + 16
            radius: Theme.radiusSm
            color: WallpaperEngine.steamRunning ? Theme.withAlpha(Theme.success, 0.15) : (WallpaperEngine.steamInstalled ? Theme.surfaceActive : Theme.surface)
            border.color: WallpaperEngine.steamRunning ? Theme.success : Theme.border

            RowLayout {
                id: steamPillRow
                anchors.centerIn: parent
                spacing: 5

                BrandIcon {
                    brand: "steam"
                    size: 14
                }

                Text {
                    text: {
                        if (WallpaperEngine.steamRunning) return "Steam: Active"
                        if (WallpaperEngine.steamInstalled) return "Steam: Ready (" + WallpaperEngine.steamType + ")"
                        return "Steam: Offline"
                    }
                    color: WallpaperEngine.steamRunning ? Theme.success : Theme.textSecondary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeLabel
                    font.bold: WallpaperEngine.steamRunning
                }
            }

            HoverHandler { id: steamPillHh; cursorShape: Qt.PointingHandCursor }
            TapHandler {
                onTapped: {
                    if (!WallpaperEngine.steamRunning && WallpaperEngine.steamInstalled) {
                        if (WallpaperEngine.steamType === "flatpak") {
                            Quickshell.execDetached(["flatpak", "run", "com.valvesoftware.Steam"])
                        } else {
                            Quickshell.execDetached(["steam"])
                        }
                    }
                    controls.weFiltersExpanded = true
                }
            }
        }
    }

    // Expandable Filter Drawer for WE
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: controls.weFiltersExpanded ? weAdvCol.implicitHeight + 20 : 0
        clip: true
        radius: Theme.radiusMd
        color: Theme.surfaceActive
        border.color: controls.weFiltersExpanded ? Theme.borderStrong : "transparent"
        border.width: controls.weFiltersExpanded ? 1 : 0

        Behavior on implicitHeight {
            NumberAnimation { duration: Anim.d(Anim.standard); easing.type: Anim.easeStandard }
        }

        ColumnLayout {
            id: weAdvCol
            anchors.fill: parent
            anchors.margins: 12
            spacing: 12

            // Steam Integration Card
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: steamLibCol.implicitHeight + 16
                radius: Theme.radiusMd
                color: Theme.surface
                border.color: Theme.border

                ColumnLayout {
                    id: steamLibCol
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        BrandIcon { brand: "steam"; size: 18 }

                        Text {
                            text: "Steam Integration & Storage Libraries"
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            font.bold: true
                        }

                        Rectangle {
                            radius: Theme.radiusSm
                            implicitHeight: 18
                            implicitWidth: steamTypeTxt.implicitWidth + 10
                            color: Theme.surfaceActive
                            border.color: Theme.border
                            Text {
                                id: steamTypeTxt
                                anchors.centerIn: parent
                                text: (WallpaperEngine.steamType || "detected").toUpperCase()
                                color: Theme.accent
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fontSizeLabel - 1
                            }
                        }

                        Item { Layout.fillWidth: true }

                        DialogButton {
                            text: WallpaperEngine.steamRunning ? "Steam Running" : "Launch Steam"
                            iconName: "sports_esports"
                            onClicked: {
                                if (WallpaperEngine.steamType === "flatpak") {
                                    Quickshell.execDetached(["flatpak", "run", "com.valvesoftware.Steam"])
                                } else {
                                    Quickshell.execDetached(["steam"])
                                }
                            }
                        }

                        IconButton {
                            iconName: "refresh"
                            implicitWidth: 26; implicitHeight: 26
                            onClicked: {
                                WallpaperEngine.refreshInstalled()
                                Notifications.notify("Steam Rescanned", "Steam library folders and workshops updated.", "sports_esports", "low", { appName: "Wallpaper Engine", transient: true })
                            }
                        }
                    }

                    // Discovered libraries list
                    Flow {
                        Layout.fillWidth: true
                        spacing: 6

                        Repeater {
                            model: WallpaperEngine.steamLibraries
                            delegate: Rectangle {
                                required property var modelData
                                implicitHeight: 24
                                implicitWidth: libRow.implicitWidth + 12
                                radius: Theme.radiusSm
                                color: Theme.surfaceActive
                                border.color: Theme.border

                                RowLayout {
                                    id: libRow
                                    anchors.centerIn: parent
                                    spacing: 5
                                    MaterialIcon { iconName: "folder"; pixelSize: 12; color: Theme.accent }
                                    Text {
                                        text: modelData.path + " (" + modelData.wallpaper_count + " items)"
                                        color: Theme.textSecondary
                                        font.family: Theme.fontMono
                                        font.pixelSize: Theme.fontSizeLabel
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Popular Genre & Aesthetic Tags
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: "Popular Tags:"
                    color: Theme.textSecondary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    Layout.preferredWidth: 120
                }

                Flow {
                    Layout.fillWidth: true
                    spacing: 5
                    Repeater {
                        model: WallpaperEngine.curatedTags
                        delegate: DisplayChip {
                            required property var modelData
                            label: modelData.name
                            selected: WallpaperEngine.tags.indexOf(modelData.name) >= 0
                            onClicked: {
                                WallpaperEngine.toggleTag(modelData.name)
                            }
                        }
                    }
                }
            }

            // Performance & Content Options Row
            RowLayout {
                Layout.fillWidth: true
                spacing: 16

                Text {
                    text: "Preferences:"
                    color: Theme.textSecondary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    Layout.preferredWidth: 120
                }

                RowLayout {
                    spacing: 8
                    Text {
                        text: "FPS Target:"
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                    }
                    Repeater {
                        model: [15, 30, 60]
                        delegate: DisplayChip {
                            required property var modelData
                            label: modelData + " FPS"
                            selected: WallpaperEngine.targetFps === modelData
                            onClicked: WallpaperEngine.setEngineConfig(modelData, undefined, undefined, undefined)
                        }
                    }
                }

                Rectangle { width: 1; height: 18; color: Theme.border }

                RowLayout {
                    spacing: 8
                    Text {
                        text: "Blur NSFW Previews:"
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                    }
                    ToggleSwitch {
                        checked: WallpaperEngine.blurNsfw
                        onToggled: function(c) {
                            WallpaperEngine.blurNsfw = c
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                DialogButton {
                    text: "Reset All Filters"
                    iconName: "restart_alt"
                    onClicked: WallpaperEngine.resetFilters()
                }
            }
        }
    }
}
