import QtQuick
import QtQuick.Layouts
import "../../theme"
import "../../components"
import "../../services"
import "TagQuery.js" as TagQuery

// Wallhaven search box, active-tag row, quick filter bar and advanced filter
// drawer. The tag-completion state is private to this component — nothing
// outside it ever read `suggestions`, which is why it moved out of the panel.
ColumnLayout {
    id: controls

    property var suggestions: []
    property int selectedSuggestionIndex: -1
    property bool filtersExpanded: false

    // The panel's dismiss scrim needs to know when a dropdown is open.
    readonly property bool suggestionsOpen: suggestions.length > 0 && searchInput.activeFocus

    readonly property var whColorSwatches: [
        "660000", "990000", "cc0000", "cc3333", "ea4c88",
        "993399", "663399", "333399", "0066cc", "0099ff",
        "42a5f5", "00ffff", "00ffcc", "339900", "66cc00",
        "ffcc00", "ff9900", "ff6600", "cc6633", "ffffff",
        "424153", "000000"
    ]

    readonly property var sortOptions: [
        { id: "toplist",    label: "Toplist",    icon: "trending_up" },
        { id: "hot",        label: "Hot",        icon: "whatshot" },
        { id: "views",      label: "Views",      icon: "visibility" },
        { id: "favorites",  label: "Favorites",  icon: "star" },
        { id: "random",     label: "Random",     icon: "shuffle" },
        { id: "date_added", label: "Latest",     icon: "schedule" },
        { id: "relevance",  label: "Relevance",  icon: "sort" }
    ]

    readonly property var topRangeOptions: [
        { id: "1d", label: "24 Hours" },
        { id: "3d", label: "3 Days" },
        { id: "1w", label: "1 Week" },
        { id: "1M", label: "1 Month" },
        { id: "3M", label: "3 Months" },
        { id: "6M", label: "6 Months" },
        { id: "1y", label: "1 Year" }
    ]

    readonly property var resolutionOptions: [
        { id: "",          label: "Any Resolution" },
        { id: "1920x1080", label: "1080p (FHD)" },
        { id: "2560x1440", label: "2K (QHD)" },
        { id: "3840x2160", label: "4K (UHD)" },
        { id: "5120x2880", label: "5K" },
        { id: "7680x4320", label: "8K" }
    ]

    readonly property var ratioOptions: [
        { id: "",      label: "Any Aspect" },
        { id: "16x9",  label: "16:9 (Standard)" },
        { id: "16x10", label: "16:10" },
        { id: "21x9",  label: "21:9 (Ultrawide)" },
        { id: "32x9",  label: "32:9 (Superwide)" },
        { id: "9x16",  label: "9:16 (Portrait)" },
        { id: "1x1",   label: "1:1 (Square)" },
        { id: "4x3",   label: "4:3" }
    ]

    spacing: 10
    z: suggestions.length > 0 ? 100 : 20

    function dismissSuggestions() {
        suggestions = []
        selectedSuggestionIndex = -1
    }

    // Add a whole tag — what clicking a tag chip in the inspector modal does.
    function addTag(tag) {
        const next = TagQuery.append(searchInput.text, tag)
        if (next !== null) search(next)
    }

    // Accept a completion, replacing the partial word being typed.
    function applySuggestion(suggestedName) {
        const next = TagQuery.replaceLastToken(searchInput.text, suggestedName)
        if (next !== null) search(next)
    }

    // Autocomplete debounce: one query per pause in typing, not per keystroke.
    Timer {
        id: autocompleteTimer
        interval: 220
        repeat: false
        onTriggered: {
            const txt = searchInput.text.trim()
            controls.suggestions = txt.length >= 2 ? Wallhaven.suggestTags(TagQuery.lastToken(txt), 8) : []
            controls.selectedSuggestionIndex = -1
        }
    }

    function search(query) {
        searchInput.text = query
        Wallhaven.query = query
        dismissSuggestions()
        Wallhaven.search(true)
    }

    // Search Bar Row
    RowLayout {
        id: searchBarRow
        Layout.fillWidth: true
        spacing: 8
        z: controls.suggestions.length > 0 ? 100 : 1

        // Search Input Box with Autocomplete Dropdown
        Rectangle {
            id: searchBox
            Layout.fillWidth: true
            implicitHeight: 38
            radius: Theme.radiusMd
            color: Theme.surface
            border.color: searchInput.activeFocus ? Theme.accent : Theme.border
            border.width: 1
            z: controls.suggestions.length > 0 ? 100 : 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 8
                spacing: 8

                MaterialIcon {
                    iconName: "search"
                    pixelSize: 18
                    color: searchInput.activeFocus ? Theme.accent : Theme.textSecondary
                }

                TextInput {
                    id: searchInput
                    Layout.fillWidth: true
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeBody
                    verticalAlignment: TextInput.AlignVCenter
                    clip: true
                    selectByMouse: true

                    onTextChanged: {
                        Wallhaven.query = text
                        autocompleteTimer.restart()
                    }

                    Keys.onReturnPressed: {
                        if (controls.suggestions.length > 0 && controls.selectedSuggestionIndex >= 0 && controls.selectedSuggestionIndex < controls.suggestions.length) {
                            var picked = controls.suggestions[controls.selectedSuggestionIndex]
                            controls.applySuggestion(picked.name)
                        } else {
                            Wallhaven.search(true)
                            controls.suggestions = []
                            controls.selectedSuggestionIndex = -1
                        }
                    }

                    Keys.onDownPressed: {
                        if (controls.suggestions.length > 0) {
                            controls.selectedSuggestionIndex = Math.min(controls.suggestions.length - 1, controls.selectedSuggestionIndex + 1)
                        }
                    }

                    Keys.onUpPressed: {
                        if (controls.suggestions.length > 0) {
                            controls.selectedSuggestionIndex = Math.max(-1, controls.selectedSuggestionIndex - 1)
                        }
                    }

                    Keys.onEscapePressed: {
                        controls.suggestions = []
                        controls.selectedSuggestionIndex = -1
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: searchInput.text === ""
                        text: "Search Wallhaven wallpapers (keywords, #tags, e.g. cyberpunk, nature, anime)…"
                        color: Theme.textDim
                        font: searchInput.font
                    }
                }

                IconButton {
                    visible: searchInput.text !== ""
                    iconName: "close"
                    implicitWidth: 24; implicitHeight: 24
                    onClicked: {
                        searchInput.text = ""
                        Wallhaven.query = ""
                        Wallhaven.search(true)
                    }
                }
            }

            // Autocomplete Dropdown
            Rectangle {
                id: autocompleteDropdown
                visible: controls.suggestions.length > 0
                anchors.top: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.topMargin: 4
                implicitHeight: Math.min(320, suggestionCol.implicitHeight + 10)
                radius: Theme.radiusMd
                color: Theme.active.surface
                border.color: Theme.borderStrong
                border.width: 1
                clip: true
                z: 100

                MujoFlickable {
                    anchors.fill: parent
                    anchors.margins: 4
                    contentHeight: suggestionCol.implicitHeight

                    ColumnLayout {
                        id: suggestionCol
                        width: parent.width
                        spacing: 2

                        Repeater {
                            model: controls.suggestions
                            delegate: Rectangle {
                                id: sugItem
                                required property var modelData
                                required property int index
                                readonly property bool isSelected: controls.selectedSuggestionIndex === index

                                Layout.fillWidth: true
                                implicitHeight: 34
                                radius: Theme.radiusSm
                                color: isSelected ? Theme.accentDim : (sugMa.containsMouse ? Theme.surfaceHover : "transparent")
                                border.color: isSelected ? Theme.accent : "transparent"

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    spacing: 8

                                    MaterialIcon {
                                        iconName: "tag"
                                        pixelSize: 14
                                        color: sugItem.isSelected ? Theme.accent : Theme.textSecondary
                                    }

                                    Text {
                                        text: sugItem.modelData.name
                                        color: sugItem.isSelected ? Theme.accent : Theme.text
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeBody
                                        font.bold: sugItem.isSelected
                                    }

                                    Text {
                                        visible: sugItem.modelData.alias !== ""
                                        text: "(" + sugItem.modelData.alias + ")"
                                        color: Theme.textDim
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeSmall
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }

                                    Item { Layout.fillWidth: true; visible: sugItem.modelData.alias === "" }

                                    Rectangle {
                                        implicitHeight: 18
                                        implicitWidth: catLabel.implicitWidth + 10
                                        radius: Theme.radiusSm
                                        color: Theme.surfaceActive
                                        border.color: Theme.border
                                        Text {
                                            id: catLabel
                                            anchors.centerIn: parent
                                            text: sugItem.modelData.category
                                            color: Theme.textSecondary
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontSizeLabel
                                        }
                                    }
                                }

                                MouseArea {
                                    id: sugMa
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    hoverEnabled: true
                                    preventStealing: true
                                    onEntered: controls.selectedSuggestionIndex = sugItem.index
                                    onClicked: {
                                        var chosenTag = sugItem.modelData.name
                                        controls.applySuggestion(chosenTag)
                                    }
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
                Wallhaven.search(true)
                controls.suggestions = []
            }
        }

        // Filter Drawer Toggle Button
        Rectangle {
            implicitHeight: 38
            implicitWidth: filterBtnRow.implicitWidth + 24
            radius: Theme.radiusMd
            color: controls.filtersExpanded || Wallhaven.activeFiltersCount > 0 ? Theme.accentDim : (filtMa.containsMouse ? Theme.surfaceHover : Theme.surface)
            border.color: controls.filtersExpanded || Wallhaven.activeFiltersCount > 0 ? Theme.accent : Theme.border

            RowLayout {
                id: filterBtnRow
                anchors.centerIn: parent
                spacing: 6

                MaterialIcon {
                    iconName: "tune"
                    pixelSize: 16
                    color: controls.filtersExpanded || Wallhaven.activeFiltersCount > 0 ? Theme.accent : Theme.textSecondary
                }

                Text {
                    text: "Filters"
                    color: controls.filtersExpanded || Wallhaven.activeFiltersCount > 0 ? Theme.accent : Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeBody
                    font.bold: controls.filtersExpanded || Wallhaven.activeFiltersCount > 0
                }

                Rectangle {
                    visible: Wallhaven.activeFiltersCount > 0
                    implicitWidth: badgeNum.implicitWidth + 8
                    implicitHeight: 18
                    radius: 9
                    color: Theme.accent

                    Text {
                        id: badgeNum
                        anchors.centerIn: parent
                        text: "" + Wallhaven.activeFiltersCount
                        color: Theme.accentText
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeLabel
                        font.bold: true
                    }
                }
            }

            MouseArea {
                id: filtMa
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                onClicked: controls.filtersExpanded = !controls.filtersExpanded
            }
        }

        // Refresh Button
        IconButton {
            iconName: "refresh"
            implicitWidth: 38; implicitHeight: 38
            onClicked: Wallhaven.search(true)
        }
    }

    // Active Tags Row
    Flow {
        Layout.fillWidth: true
        spacing: 6
        visible: Wallhaven.tags.length > 0

        Repeater {
            model: Wallhaven.tags
            delegate: Rectangle {
                id: activeTagPill
                required property var modelData
                implicitHeight: 26
                implicitWidth: tagTextRow.implicitWidth + 14
                radius: Theme.radiusSm
                color: act_hh.hovered ? Theme.surfaceHover : Theme.accentDim
                border.color: act_hh.hovered ? Theme.accent : Theme.accent

                RowLayout {
                    id: tagTextRow
                    anchors.centerIn: parent
                    spacing: 4

                    Text {
                        text: "#" + activeTagPill.modelData
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

                HoverHandler { id: act_hh; cursorShape: Qt.PointingHandCursor }
                TapHandler {
                    onTapped: Wallhaven.removeTag(activeTagPill.modelData)
                }
            }
        }

        Rectangle {
            implicitHeight: 26
            implicitWidth: clrTagsLbl.implicitWidth + 14
            radius: Theme.radiusSm
            color: clr_hh.hovered ? Theme.surfaceHover : Theme.surface
            border.color: clr_hh.hovered ? Theme.borderInteractive : Theme.border

            Text {
                id: clrTagsLbl
                anchors.centerIn: parent
                text: "Clear Tags"
                color: Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
            }
            HoverHandler { id: clr_hh; cursorShape: Qt.PointingHandCursor }
            TapHandler {
                onTapped: Wallhaven.clearTags()
            }
        }
    }

    // Quick Filter Bar (Categories, Purity, Sort)
    RowLayout {
        Layout.fillWidth: true
        spacing: 12

        RowLayout {
            spacing: 4
            Text {
                text: "Categories:"
                color: Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
            }

            DisplayChip {
                label: "General"
                selected: Wallhaven.categoryGeneral
                onClicked: {
                    Wallhaven.categoryGeneral = !Wallhaven.categoryGeneral
                    Wallhaven.search(true)
                }
            }

            DisplayChip {
                label: "Anime"
                selected: Wallhaven.categoryAnime
                onClicked: {
                    Wallhaven.categoryAnime = !Wallhaven.categoryAnime
                    Wallhaven.search(true)
                }
            }

            DisplayChip {
                label: "People"
                selected: Wallhaven.categoryPeople
                onClicked: {
                    Wallhaven.categoryPeople = !Wallhaven.categoryPeople
                    Wallhaven.search(true)
                }
            }
        }

        Rectangle { width: 1; height: 18; color: Theme.border }

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
                selected: Wallhaven.puritySfw
                onClicked: {
                    Wallhaven.puritySfw = !Wallhaven.puritySfw
                    Wallhaven.search(true)
                }
            }

            DisplayChip {
                label: "Sketchy"
                selected: Wallhaven.puritySketchy
                onClicked: {
                    Wallhaven.puritySketchy = !Wallhaven.puritySketchy
                    Wallhaven.search(true)
                }
            }

            DisplayChip {
                label: "NSFW"
                selected: Wallhaven.purityNsfw
                onClicked: {
                    Wallhaven.purityNsfw = !Wallhaven.purityNsfw
                    Wallhaven.search(true)
                }
            }
        }

        Item { Layout.fillWidth: true }

        RowLayout {
            spacing: 4
            Text {
                text: "Sort:"
                color: Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
            }

            Repeater {
                model: controls.sortOptions
                delegate: DisplayChip {
                    required property var modelData
                    label: modelData.label
                    selected: Wallhaven.sorting === modelData.id
                    onClicked: {
                        Wallhaven.sorting = modelData.id
                        Wallhaven.search(true)
                    }
                }
            }

            IconButton {
                iconName: Wallhaven.order === "desc" ? "arrow_downward" : "arrow_upward"
                onClicked: {
                    Wallhaven.order = (Wallhaven.order === "desc") ? "asc" : "desc"
                    Wallhaven.search(true)
                }
            }
        }
    }

    // Expandable Advanced Filters Drawer for Wallhaven
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: controls.filtersExpanded ? advCol.implicitHeight + 20 : 0
        clip: true
        radius: Theme.radiusMd
        color: Theme.surfaceActive
        border.color: controls.filtersExpanded ? Theme.borderStrong : "transparent"
        border.width: controls.filtersExpanded ? 1 : 0

        Behavior on implicitHeight {
            NumberAnimation { duration: Anim.d(Anim.standard); easing.type: Anim.easeStandard }
        }

        ColumnLayout {
            id: advCol
            anchors.fill: parent
            anchors.margins: 12
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                visible: Wallhaven.sorting === "toplist" || Wallhaven.sorting === "hot"

                Text {
                    text: "Toplist Window:"
                    color: Theme.textSecondary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    Layout.preferredWidth: 120
                }

                Flow {
                    Layout.fillWidth: true
                    spacing: 5
                    Repeater {
                        model: controls.topRangeOptions
                        delegate: DisplayChip {
                            required property var modelData
                            label: modelData.label
                            selected: Wallhaven.topRange === modelData.id
                            onClicked: {
                                Wallhaven.topRange = modelData.id
                                Wallhaven.search(true)
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: "Min Resolution:"
                    color: Theme.textSecondary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    Layout.preferredWidth: 120
                }

                Flow {
                    Layout.fillWidth: true
                    spacing: 5
                    Repeater {
                        model: controls.resolutionOptions
                        delegate: DisplayChip {
                            required property var modelData
                            label: modelData.label
                            selected: Wallhaven.atleast === modelData.id
                            onClicked: {
                                Wallhaven.atleast = modelData.id
                                Wallhaven.search(true)
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: "Aspect Ratio:"
                    color: Theme.textSecondary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    Layout.preferredWidth: 120
                }

                Flow {
                    Layout.fillWidth: true
                    spacing: 5
                    Repeater {
                        model: controls.ratioOptions
                        delegate: DisplayChip {
                            required property var modelData
                            label: modelData.label
                            selected: Wallhaven.ratios === modelData.id
                            onClicked: {
                                Wallhaven.ratios = modelData.id
                                Wallhaven.search(true)
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: "Color Palette:"
                    color: Theme.textSecondary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    Layout.preferredWidth: 120
                }

                Flow {
                    Layout.fillWidth: true
                    spacing: 6

                    DisplayChip {
                        visible: Wallhaven.color !== ""
                        label: "Clear Color"
                        onClicked: Wallhaven.setColor("")
                    }

                    Repeater {
                        model: controls.whColorSwatches
                        delegate: Rectangle {
                            id: colorFilterSwatch
                            required property var modelData
                            readonly property bool isSelected: Wallhaven.color === modelData
                            width: 24; height: 24
                            radius: Theme.radiusSm
                            color: "#" + modelData
                            border.width: isSelected ? 2 : 1
                            border.color: isSelected ? Theme.accent : Theme.borderStrong

                            MaterialIcon {
                                visible: colorFilterSwatch.isSelected
                                anchors.centerIn: parent
                                iconName: "check"
                                pixelSize: 13
                                color: (colorFilterSwatch.modelData === "ffffff" || colorFilterSwatch.modelData === "00ffff" || colorFilterSwatch.modelData === "00ffcc" || colorFilterSwatch.modelData === "ffcc00") ? "#000000" : "#ffffff"
                            }

                            MouseArea {
                                id: colMa
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true
                                onClicked: Wallhaven.setColor(colorFilterSwatch.modelData)
                            }

                            scale: colMa.containsMouse ? 1.15 : 1.0
                            Behavior on scale { NumberAnimation { duration: Anim.d(Anim.fast) } }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Text {
                    text: "Wallhaven API Key:"
                    color: Theme.textSecondary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    Layout.preferredWidth: 120
                }

                TextField {
                    id: apiKeyField
                    Layout.fillWidth: true
                    placeholder: "Optional API Key for NSFW & Higher Limits"
                    password: true
                    text: SettingsBus.get("wallhaven.apiKey", "")
                    onAccepted: {
                        SettingsBus.set("wallhaven.apiKey", text.trim())
                        Notifications.notify("API Key Saved", "Wallhaven API key updated in settings.", "key", "low", { appName: "Wallhaven", transient: true })
                    }
                }

                DialogButton {
                    text: "Save Key"
                    onClicked: {
                        SettingsBus.set("wallhaven.apiKey", apiKeyField.text.trim())
                        Notifications.notify("API Key Saved", "Wallhaven API key updated in settings.", "key", "low", { appName: "Wallhaven", transient: true })
                    }
                }

                Item { Layout.fillWidth: true }

                DialogButton {
                    text: "Reset All Filters"
                    iconName: "restart_alt"
                    onClicked: Wallhaven.resetFilters()
                }
            }
        }
    }
}
