import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../theme"
import "../../components"
import "../../services"

// Wallpaper Manager Panel — Mujo (無常).
// Local wallpaper library, Wallhaven online browser, Wallpaper Engine & Steam Workshop integration,
// purity filters (SFW, Sketchy, NSFW), real-time streaming download progress bar, NVMe thumbnail pre-caching,
// parallax motion effects, search filters, tag autocomplete, infinite scrolling, and metadata inspection.
Item {
    id: root

    property string tab: "library" // "library" | "wallhaven" | "wallpaperengine" | "effects"
    property var localList: []
    property string currentImage: ""
    property string background: Theme.active.bg
    property bool motion: false
    property bool filtersExpanded: false
    property bool weFiltersExpanded: false

    // Wallhaven autocomplete state
    property var suggestions: []
    property int selectedSuggestionIndex: -1

    // Wallpaper Engine autocomplete state
    property var weSuggestions: []
    property int selectedWeSuggestionIndex: -1

    readonly property var bgSwatches: [
        "#000000", "#0b0e13", "#111111", "#181825",
        "#1d2021", "#16161e", "#191724", "#21252b"
    ]

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

    function runWp(args) { Quickshell.execDetached(["mujo", "wallpaper"].concat(args)) }

    // ── Tag Search & Deduplication Engine ────────────────────────────────────
    function isTagInQuery(query, tag) {
        if (!query || !tag) return false
        var cleanTag = tag.trim().replace(/^[#+]/, "").replace(/^"/, "").replace(/"$/, "").toLowerCase()
        if (cleanTag === "") return false

        var q = query.toLowerCase().trim()
        if (q === "") return false

        if (q === cleanTag || q === "#" + cleanTag || q === "+" + cleanTag || q === '"' + cleanTag + '"') return true
        if (q.indexOf('"' + cleanTag + '"') >= 0) return true

        var re = /"([^"]+)"|(\S+)/g
        var match
        while ((match = re.exec(q)) !== null) {
            var token = (match[1] || match[2]).replace(/^[#+]/, "").replace(/^"/, "").replace(/"$/, "").toLowerCase()
            if (token === cleanTag) return true
        }
        return false
    }

    function addTagToSearch(tag) {
        if (!tag) return
        var cleanTag = tag.trim().replace(/^[#+]/, "").replace(/^"/, "").replace(/"$/, "")
        if (cleanTag === "") return

        if (isTagInQuery(searchInput.text, cleanTag)) return

        var formattedTag = cleanTag.indexOf(" ") >= 0 ? ('"' + cleanTag + '"') : cleanTag
        var currentText = searchInput.text.trim()
        var newText = currentText === "" ? formattedTag : (currentText + " " + formattedTag)

        searchInput.text = newText
        Wallhaven.query = newText
        root.suggestions = []
        root.selectedSuggestionIndex = -1
        Wallhaven.search(true)
    }

    function applySuggestion(suggestedName) {
        if (!suggestedName) return
        var cleanTag = suggestedName.trim().replace(/^[#+]/, "").replace(/^"/, "").replace(/"$/, "")
        if (cleanTag === "") return

        var txt = searchInput.text.trim()
        var lastSpace = txt.lastIndexOf(" ")
        var formatted = cleanTag.indexOf(" ") >= 0 ? ('"' + cleanTag + '"') : cleanTag

        var newText = ""
        if (lastSpace >= 0) {
            var prefix = txt.substring(0, lastSpace).trim()
            if (isTagInQuery(prefix, cleanTag)) {
                newText = prefix
            } else {
                newText = prefix === "" ? formatted : (prefix + " " + formatted)
            }
        } else {
            newText = formatted
        }

        searchInput.text = newText
        Wallhaven.query = newText
        root.suggestions = []
        root.selectedSuggestionIndex = -1
        Wallhaven.search(true)
    }

    // ── Wallpaper Engine Tag Helpers ─────────────────────────────────────────
    function addWeTagToSearch(tag) {
        if (!tag) return
        var cleanTag = tag.trim().replace(/^[#+]/, "").replace(/^"/, "").replace(/"$/, "")
        if (cleanTag === "") return

        if (isTagInQuery(weSearchInput.text, cleanTag)) return

        var formattedTag = cleanTag.indexOf(" ") >= 0 ? ('"' + cleanTag + '"') : cleanTag
        var currentText = weSearchInput.text.trim()
        var newText = currentText === "" ? formattedTag : (currentText + " " + formattedTag)

        weSearchInput.text = newText
        WallpaperEngine.query = newText
        root.weSuggestions = []
        root.selectedWeSuggestionIndex = -1
        WallpaperEngine.search(true)
    }

    function applyWeSuggestion(suggestedName) {
        if (!suggestedName) return
        var cleanTag = suggestedName.trim().replace(/^[#+]/, "").replace(/^"/, "").replace(/"$/, "")
        if (cleanTag === "") return

        var txt = weSearchInput.text.trim()
        var lastSpace = txt.lastIndexOf(" ")
        var formatted = cleanTag.indexOf(" ") >= 0 ? ('"' + cleanTag + '"') : cleanTag

        var newText = ""
        if (lastSpace >= 0) {
            var prefix = txt.substring(0, lastSpace).trim()
            if (isTagInQuery(prefix, cleanTag)) {
                newText = prefix
            } else {
                newText = prefix === "" ? formatted : (prefix + " " + formatted)
            }
        } else {
            newText = formatted
        }

        weSearchInput.text = newText
        WallpaperEngine.query = newText
        root.weSuggestions = []
        root.selectedWeSuggestionIndex = -1
        WallpaperEngine.search(true)
    }

    // ── Current wallpaper & effects state ────────────────────────────────────
    FileView {
        id: wpConf
        path: (Quickshell.env("HOME") || "/tmp") + "/.config/quickshell/wallpaper.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                var c = JSON.parse(text())
                root.currentImage = (c["default"] || {}).image || (c["default"] || {}).video || (c["default"] || {}).engine || ""
                root.background = c.background || Theme.active.bg
                root.motion = !!(c.effects && c.effects.motion)
            } catch (e) { /* ignore */ }
        }
    }

    // ── Local library listing ────────────────────────────────────────────────
    Process {
        id: listProc
        command: ["mujo", "wallpaper", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.localList = JSON.parse(this.text) }
                catch (e) { root.localList = [] }
            }
        }
    }
    function refreshLocal() { listProc.running = true }
    Component.onCompleted: refreshLocal()

    Connections {
        target: WallpaperDownloads
        function onDownloadFinished(url, destPath) {
            root.refreshLocal()
        }
    }

    // ── Autocomplete Debounce Timers ─────────────────────────────────────────
    Timer {
        id: autocompleteTimer
        interval: 220
        repeat: false
        onTriggered: {
            var txt = searchInput.text.trim()
            if (txt.length >= 2) {
                var lastToken = txt
                var lastSpace = txt.lastIndexOf(" ")
                if (lastSpace >= 0 && lastSpace < txt.length - 1) {
                    lastToken = txt.substring(lastSpace + 1).trim()
                }
                var term = (lastToken.length >= 2) ? lastToken : txt
                root.suggestions = Wallhaven.suggestTags(term, 8)
                root.selectedSuggestionIndex = -1
            } else {
                root.suggestions = []
                root.selectedSuggestionIndex = -1
            }
        }
    }

    Timer {
        id: weAutocompleteTimer
        interval: 220
        repeat: false
        onTriggered: {
            var txt = weSearchInput.text.trim()
            if (txt.length >= 2) {
                var lastToken = txt
                var lastSpace = txt.lastIndexOf(" ")
                if (lastSpace >= 0 && lastSpace < txt.length - 1) {
                    lastToken = txt.substring(lastSpace + 1).trim()
                }
                var term = (lastToken.length >= 2) ? lastToken : txt
                root.weSuggestions = WallpaperEngine.suggestTags(term, 8)
                root.selectedWeSuggestionIndex = -1
            } else {
                root.weSuggestions = []
                root.selectedWeSuggestionIndex = -1
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 14

        // ── Hero Banner ───────────────────────────────────────────────────────
        MujoHero {
            brand: root.tab === "wallhaven" ? "wallhaven" : (root.tab === "wallpaperengine" ? "wallpaperengine" : "wallpaper")
            title: root.tab === "wallhaven" ? "Wallhaven Explorer" : (root.tab === "wallpaperengine" ? "Wallpaper Engine" : "Wallpaper")
            subtitle: {
                if (root.tab === "wallhaven") return "Search millions of high-resolution wallpapers with fast NVMe thumbnail caching, filters, and real-time downloads."
                if (root.tab === "wallpaperengine") return "Browse Steam Workshop Wallpaper Engine items (431960), manage installed projects, and configure live rendering."
                return "Browse your local library, download from Wallhaven or Wallpaper Engine, or customize parallax effects."
            }
            badgeText: {
                if (root.tab === "library") return root.localList.length + " IN LIBRARY"
                if (root.tab === "wallhaven") return (Wallhaven.totalResults > 0 ? (Wallhaven.totalResults.toLocaleString() + " WALLPAPERS") : "ONLINE GALLERY")
                if (root.tab === "wallpaperengine") return (WallpaperEngine.activeSource === "installed" ? (WallpaperEngine.totalInstalledCount + " INSTALLED") : (WallpaperEngine.steamRunning ? "STEAM CONNECTED" : "STEAM WORKSHOP"))
                return "MOTION & AMBIENCE"
            }
            badgeColor: Theme.accent

            // Segmented tab switch in hero
            RowLayout {
                spacing: 6
                Repeater {
                    model: [
                        { id: "library",         label: "Library",          icon: "photo_library" },
                        { id: "wallhaven",       label: "Wallhaven",        icon: "cloud_download" },
                        { id: "wallpaperengine", label: "Wallpaper Engine", icon: "sports_esports" },
                        { id: "effects",         label: "Effects",          icon: "tune" }
                    ]
                    delegate: Rectangle {
                        id: heroTabBtn
                        required property var modelData
                        readonly property bool on: root.tab === modelData.id
                        implicitWidth: tbLbl.implicitWidth + 24
                        implicitHeight: 30
                        radius: Theme.radiusSm
                        color: on ? Theme.accent : (heroTabMa.containsMouse ? Theme.surfaceHover : Theme.surfaceActive)
                        border.color: on ? Theme.accent : Theme.border

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 6
                            MaterialIcon {
                                iconName: heroTabBtn.modelData.icon
                                pixelSize: 14
                                color: heroTabBtn.on ? Theme.accentText : Theme.textSecondary
                            }
                            Text {
                                id: tbLbl
                                text: heroTabBtn.modelData.label
                                color: heroTabBtn.on ? Theme.accentText : Theme.textSecondary
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSmall
                                font.bold: heroTabBtn.on
                            }
                        }
                        MouseArea {
                            id: heroTabMa
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            onClicked: root.tab = heroTabBtn.modelData.id
                        }
                    }
                }
            }
        }

        // ── Wallhaven Tab Controls ────────────────────────────────────────────
        ColumnLayout {
            id: wallhavenControls
            visible: root.tab === "wallhaven"
            Layout.fillWidth: true
            spacing: 10
            z: root.suggestions.length > 0 ? 100 : 20

            // Search Bar Row
            RowLayout {
                id: searchBarRow
                Layout.fillWidth: true
                spacing: 8
                z: root.suggestions.length > 0 ? 100 : 1

                // Search Input Box with Autocomplete Dropdown
                Rectangle {
                    id: searchBox
                    Layout.fillWidth: true
                    implicitHeight: 38
                    radius: Theme.radiusMd
                    color: Theme.surface
                    border.color: searchInput.activeFocus ? Theme.accent : Theme.border
                    border.width: 1
                    z: root.suggestions.length > 0 ? 100 : 1

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
                                if (root.suggestions.length > 0 && root.selectedSuggestionIndex >= 0 && root.selectedSuggestionIndex < root.suggestions.length) {
                                    var picked = root.suggestions[root.selectedSuggestionIndex]
                                    root.applySuggestion(picked.name)
                                } else {
                                    Wallhaven.search(true)
                                    root.suggestions = []
                                    root.selectedSuggestionIndex = -1
                                }
                            }

                            Keys.onDownPressed: {
                                if (root.suggestions.length > 0) {
                                    root.selectedSuggestionIndex = Math.min(root.suggestions.length - 1, root.selectedSuggestionIndex + 1)
                                }
                            }

                            Keys.onUpPressed: {
                                if (root.suggestions.length > 0) {
                                    root.selectedSuggestionIndex = Math.max(-1, root.selectedSuggestionIndex - 1)
                                }
                            }

                            Keys.onEscapePressed: {
                                root.suggestions = []
                                root.selectedSuggestionIndex = -1
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
                        visible: root.suggestions.length > 0
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
                                    model: root.suggestions
                                    delegate: Rectangle {
                                        id: sugItem
                                        required property var modelData
                                        required property int index
                                        readonly property bool isSelected: root.selectedSuggestionIndex === index

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
                                            onEntered: root.selectedSuggestionIndex = sugItem.index
                                            onClicked: {
                                                var chosenTag = sugItem.modelData.name
                                                root.applySuggestion(chosenTag)
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
                        root.suggestions = []
                    }
                }

                // Filter Drawer Toggle Button
                Rectangle {
                    implicitHeight: 38
                    implicitWidth: filterBtnRow.implicitWidth + 24
                    radius: Theme.radiusMd
                    color: root.filtersExpanded || Wallhaven.activeFiltersCount > 0 ? Theme.accentDim : (filtMa.containsMouse ? Theme.surfaceHover : Theme.surface)
                    border.color: root.filtersExpanded || Wallhaven.activeFiltersCount > 0 ? Theme.accent : Theme.border

                    RowLayout {
                        id: filterBtnRow
                        anchors.centerIn: parent
                        spacing: 6

                        MaterialIcon {
                            iconName: "tune"
                            pixelSize: 16
                            color: root.filtersExpanded || Wallhaven.activeFiltersCount > 0 ? Theme.accent : Theme.textSecondary
                        }

                        Text {
                            text: "Filters"
                            color: root.filtersExpanded || Wallhaven.activeFiltersCount > 0 ? Theme.accent : Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeBody
                            font.bold: root.filtersExpanded || Wallhaven.activeFiltersCount > 0
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
                        onClicked: root.filtersExpanded = !root.filtersExpanded
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
                        model: root.sortOptions
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
                implicitHeight: root.filtersExpanded ? advCol.implicitHeight + 20 : 0
                clip: true
                radius: Theme.radiusMd
                color: Theme.surfaceActive
                border.color: root.filtersExpanded ? Theme.borderStrong : "transparent"
                border.width: root.filtersExpanded ? 1 : 0

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
                                model: root.topRangeOptions
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
                                model: root.resolutionOptions
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
                                model: root.ratioOptions
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
                                model: root.whColorSwatches
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

        // ── Wallpaper Engine Tab Controls ─────────────────────────────────────
        ColumnLayout {
            id: wallpaperEngineControls
            visible: root.tab === "wallpaperengine"
            Layout.fillWidth: true
            spacing: 10
            z: root.weSuggestions.length > 0 ? 100 : 20

            // Search Bar Row
            RowLayout {
                id: weSearchBarRow
                Layout.fillWidth: true
                spacing: 8
                z: root.weSuggestions.length > 0 ? 100 : 1

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
                    z: root.weSuggestions.length > 0 ? 100 : 1

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
                                if (root.weSuggestions.length > 0 && root.selectedWeSuggestionIndex >= 0 && root.selectedWeSuggestionIndex < root.weSuggestions.length) {
                                    var picked = root.weSuggestions[root.selectedWeSuggestionIndex]
                                    root.applyWeSuggestion(picked.name)
                                } else {
                                    WallpaperEngine.search(true)
                                    root.weSuggestions = []
                                    root.selectedWeSuggestionIndex = -1
                                }
                            }

                            Keys.onDownPressed: {
                                if (root.weSuggestions.length > 0) {
                                    root.selectedWeSuggestionIndex = Math.min(root.weSuggestions.length - 1, root.selectedWeSuggestionIndex + 1)
                                }
                            }

                            Keys.onUpPressed: {
                                if (root.weSuggestions.length > 0) {
                                    root.selectedWeSuggestionIndex = Math.max(-1, root.selectedWeSuggestionIndex - 1)
                                }
                            }

                            Keys.onEscapePressed: {
                                root.weSuggestions = []
                                root.selectedWeSuggestionIndex = -1
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
                        visible: root.weSuggestions.length > 0
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
                                    model: root.weSuggestions
                                    delegate: Rectangle {
                                        id: weSugItem
                                        required property var modelData
                                        required property int index
                                        readonly property bool isSelected: root.selectedWeSuggestionIndex === index

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
                                            onEntered: root.selectedWeSuggestionIndex = weSugItem.index
                                            onClicked: root.applyWeSuggestion(weSugItem.modelData.name)
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
                        root.weSuggestions = []
                    }
                }

                // Filter Drawer Toggle Button
                Rectangle {
                    implicitHeight: 38
                    implicitWidth: weFilterBtnRow.implicitWidth + 24
                    radius: Theme.radiusMd
                    color: root.weFiltersExpanded || WallpaperEngine.activeFiltersCount > 0 ? Theme.accentDim : (weFiltMa.containsMouse ? Theme.surfaceHover : Theme.surface)
                    border.color: root.weFiltersExpanded || WallpaperEngine.activeFiltersCount > 0 ? Theme.accent : Theme.border

                    RowLayout {
                        id: weFilterBtnRow
                        anchors.centerIn: parent
                        spacing: 6

                        MaterialIcon {
                            iconName: "tune"
                            pixelSize: 16
                            color: root.weFiltersExpanded || WallpaperEngine.activeFiltersCount > 0 ? Theme.accent : Theme.textSecondary
                        }

                        Text {
                            text: "Filters"
                            color: root.weFiltersExpanded || WallpaperEngine.activeFiltersCount > 0 ? Theme.accent : Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeBody
                            font.bold: root.weFiltersExpanded || WallpaperEngine.activeFiltersCount > 0
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
                        onClicked: root.weFiltersExpanded = !root.weFiltersExpanded
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
                        model: root.weTypeOptions
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
                        model: root.weSortOptions
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
                            root.weFiltersExpanded = true
                        }
                    }
                }
            }

            // Expandable Filter Drawer for WE
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: root.weFiltersExpanded ? weAdvCol.implicitHeight + 20 : 0
                clip: true
                radius: Theme.radiusMd
                color: Theme.surfaceActive
                border.color: root.weFiltersExpanded ? Theme.borderStrong : "transparent"
                border.width: root.weFiltersExpanded ? 1 : 0

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

        // ── Effects Tab Content ───────────────────────────────────────────────
        ColumnLayout {
            visible: root.tab === "effects"
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 14

            MujoCard {
                title: "Parallax & Background"
                iconName: "blur_on"

                MujoSettingRow {
                    iconName: "pan_tool_alt"
                    title: "Cursor Parallax Effect"
                    description: "Subtle zoom and directional pan that follows cursor coordinates."

                    ToggleSwitch {
                        checked: root.motion
                        onToggled: function(c) {
                            root.motion = c
                            root.runWp(["motion", c ? "on" : "off"])
                        }
                    }
                }

                // Letterbox background color swatches
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: "Letterbox Fill Color"
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeBody
                        font.bold: true
                    }

                    Flow {
                        Layout.fillWidth: true
                        spacing: 8

                        // Default / Theme background button
                        Rectangle {
                            implicitWidth: 68; implicitHeight: 30
                            radius: Theme.radiusSm
                            color: root.background.toLowerCase() === Theme.active.bg.toLowerCase() ? Theme.accentDim : Theme.surfaceActive
                            border.color: root.background.toLowerCase() === Theme.active.bg.toLowerCase() ? Theme.accent : Theme.border

                            Text {
                                anchors.centerIn: parent
                                text: "Theme"
                                color: root.background.toLowerCase() === Theme.active.bg.toLowerCase() ? Theme.accent : Theme.textSecondary
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSmall
                                font.bold: root.background.toLowerCase() === Theme.active.bg.toLowerCase()
                            }
                            HoverHandler { cursorShape: Qt.PointingHandCursor }
                            TapHandler { onTapped: root.runWp(["background", Theme.active.bg]) }
                        }

                        Repeater {
                            model: root.bgSwatches
                            delegate: Rectangle {
                                required property var modelData
                                readonly property bool selected: root.background.toLowerCase() === modelData.toLowerCase()
                                width: 30; height: 30
                                radius: Theme.radiusSm
                                color: modelData
                                border.width: selected ? 2 : 1
                                border.color: selected ? Theme.accent : Theme.borderStrong

                                MaterialIcon {
                                    visible: parent.selected
                                    anchors.centerIn: parent
                                    iconName: "check"
                                    pixelSize: 15
                                    color: Theme.accent
                                }
                                HoverHandler { cursorShape: Qt.PointingHandCursor }
                                TapHandler { onTapped: root.runWp(["background", modelData]) }
                            }
                        }
                    }
                }
            }

            MujoCard {
                title: "Wallpaper Engine Performance"
                iconName: "sports_esports"

                MujoSettingRow {
                    iconName: "speed"
                    title: "Frame Rate Target"
                    description: "Maximum render FPS limit for live scene and video wallpapers."

                    RowLayout {
                        spacing: 6
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
                }

                MujoSettingRow {
                    iconName: "volume_up"
                    title: "Live Wallpaper Audio"
                    description: "Background audio playback and sound effects for video and interactive scenes."

                    RowLayout {
                        spacing: 8
                        DisplayChip {
                            label: WallpaperEngine.isSilent ? "Muted" : "Active"
                            selected: !WallpaperEngine.isSilent
                            onClicked: WallpaperEngine.setEngineConfig(undefined, undefined, !WallpaperEngine.isSilent, undefined)
                        }
                        Slider {
                            implicitWidth: 120
                            value: WallpaperEngine.soundVolume
                            from: 0; to: 100
                            onMoved: function(v) { WallpaperEngine.setEngineConfig(undefined, Math.round(v), undefined, undefined) }
                        }
                    }
                }

                MujoSettingRow {
                    iconName: "volume_off"
                    title: "Auto-Mute on Other Audio"
                    description: "Automatically mute wallpaper sound when another application plays audio or gains window focus."

                    ToggleSwitch {
                        checked: WallpaperEngine.autoMute
                        onToggled: function(c) { WallpaperEngine.setEngineConfig(undefined, undefined, undefined, c) }
                    }
                }
            }

            Item { Layout.fillHeight: true }
        }

        // ── Grid Views (Library, Wallhaven, Wallpaper Engine) ─────────────────
        Item {
            visible: root.tab !== "effects"
            Layout.fillWidth: true
            Layout.fillHeight: true

            // ── Local Library Grid ───────────────────────────────────────────
            GridView {
                id: libGrid
                anchors.fill: parent
                visible: root.tab === "library"
                clip: true
                cellWidth: (width - (width % 180)) / Math.max(1, Math.floor(width / 180))
                cellHeight: cellWidth * 0.62 + 6
                model: root.localList
                boundsBehavior: Flickable.DragAndOvershootBounds
                flickDeceleration: 1800
                maximumFlickVelocity: 3500

                property real targetContentY: contentY

                NumberAnimation {
                    id: libScrollAnim
                    target: libGrid
                    property: "contentY"
                    duration: Anim.d(Anim.enter)
                    easing.type: Easing.OutCubic
                }

                WheelHandler {
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: function(event) {
                        libGrid.cancelFlick()
                        var maxContentY = Math.max(0, libGrid.contentHeight - libGrid.height)
                        var delta = (event.angleDelta.y !== 0) ? -event.angleDelta.y : -event.pixelDelta.y
                        var step = delta * 1.2
                        var currentTarget = libScrollAnim.running ? libGrid.targetContentY : libGrid.contentY
                        var nextTarget = Math.max(0, Math.min(maxContentY, currentTarget + step))
                        libGrid.targetContentY = nextTarget
                        libScrollAnim.stop()
                        libScrollAnim.duration = Anim.d(Anim.enter)
                        libScrollAnim.to = nextTarget
                        libScrollAnim.start()
                        event.accepted = true
                    }
                }

                onMovementStarted: libScrollAnim.stop()
                onFlickStarted: libScrollAnim.stop()
                onMovementEnded: libGrid.targetContentY = libGrid.contentY
                onFlickEnded: libGrid.targetContentY = libGrid.contentY

                delegate: Item {
                    required property var modelData
                    width: libGrid.cellWidth
                    height: libGrid.cellHeight

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 5
                        radius: Theme.radiusMd
                        color: Theme.surface
                        clip: true
                        border.width: modelData === root.currentImage ? 2 : 1
                        border.color: modelData === root.currentImage ? Theme.accent : Theme.border

                        Image {
                            anchors.fill: parent
                            anchors.margins: 2
                            source: "file://" + modelData
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: true
                            sourceSize.width: 320
                            sourceSize.height: 180
                            clip: true
                        }

                        Rectangle {
                            visible: modelData === root.currentImage
                            anchors { top: parent.top; right: parent.right; margins: 6 }
                            width: 22; height: 22; radius: 11
                            color: Theme.accent
                            MaterialIcon {
                                anchors.centerIn: parent
                                iconName: "check"
                                pixelSize: 14
                                color: Theme.accentText
                            }
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            color: Theme.accent
                            opacity: lib_hh.hovered && modelData !== root.currentImage ? 0.12 : 0
                            Behavior on opacity { NumberAnimation { duration: Anim.d(Anim.fast) } }
                        }

                        HoverHandler { id: lib_hh; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: root.runWp(["set", modelData]) }
                    }
                }
            }

            // ── Wallhaven Online Grid ─────────────────────────────────────────
            GridView {
                id: whGrid
                anchors.fill: parent
                visible: root.tab === "wallhaven" && !Wallhaven.loading && Wallhaven.resultsModel.count > 0
                clip: true
                cellWidth: Math.floor((width - 6) / Math.max(1, Math.floor((width - 6) / 230)))
                cellHeight: cellWidth * 0.62 + 8
                model: Wallhaven.resultsModel
                boundsBehavior: Flickable.DragAndOvershootBounds
                flickDeceleration: 1800
                maximumFlickVelocity: 3500

                property real targetContentY: contentY

                NumberAnimation {
                    id: scrollAnimation
                    target: whGrid
                    property: "contentY"
                    duration: Anim.d(Anim.enter)
                    easing.type: Easing.OutCubic
                }

                WheelHandler {
                    id: whWheelHandler
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: function(event) {
                        whGrid.cancelFlick()
                        var maxContentY = Math.max(0, whGrid.contentHeight - whGrid.height)
                        var delta = (event.angleDelta.y !== 0) ? -event.angleDelta.y : -event.pixelDelta.y
                        var step = delta * 1.2
                        var currentTarget = scrollAnimation.running ? whGrid.targetContentY : whGrid.contentY
                        var nextTarget = Math.max(0, Math.min(maxContentY, currentTarget + step))
                        whGrid.targetContentY = nextTarget
                        scrollAnimation.stop()
                        scrollAnimation.duration = Anim.d(Anim.enter)
                        scrollAnimation.to = nextTarget
                        scrollAnimation.start()
                        event.accepted = true
                    }
                }

                onMovementStarted: scrollAnimation.stop()
                onFlickStarted: scrollAnimation.stop()
                onMovementEnded: whGrid.targetContentY = whGrid.contentY
                onFlickEnded: whGrid.targetContentY = whGrid.contentY

                onContentYChanged: {
                    if (!Wallhaven.loading && !Wallhaven.loadingMore && Wallhaven.hasMore) {
                        if (contentY + height >= contentHeight - cellHeight * 2.5) {
                            Wallhaven.loadMore()
                        }
                    }
                }

                delegate: Item {
                    id: cardItem
                    required property var itemData
                    readonly property var modelData: itemData
                    readonly property string targetUrl: (itemData && itemData.path) ? itemData.path : ""
                    readonly property var dlInfo: targetUrl ? WallpaperDownloads.getDownload(targetUrl) : null
                    readonly property bool isDlActive: dlInfo !== null && dlInfo.status === "downloading"
                    readonly property bool isDlDone: targetUrl ? (WallpaperDownloads.isCompleted(targetUrl) || (dlInfo !== null && dlInfo.status === "done")) : false

                    width: whGrid.cellWidth
                    height: whGrid.cellHeight

                    Rectangle {
                        id: cardBox
                        anchors.fill: parent
                        anchors.margins: 5
                        radius: Theme.radiusMd
                        color: Theme.surface
                        clip: true
                        border.width: isDlActive ? 2 : (wh_hh.hovered ? 2 : 1)
                        border.color: isDlActive ? Theme.accent : (wh_hh.hovered ? Theme.accent : Theme.border)

                        Behavior on border.color { ColorAnimation { duration: Anim.d(Anim.fast) } }

                        Image {
                            id: thumbImg
                            anchors.fill: parent
                            anchors.margins: 2
                            source: {
                                if (itemData.cached_preview) return itemData.cached_preview
                                if (itemData.thumbs && itemData.thumbs.small) return itemData.thumbs.small
                                return ""
                            }
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: true
                            smooth: true
                            sourceSize.width: 320
                            sourceSize.height: 180
                            clip: true

                            Rectangle {
                                anchors.fill: parent
                                color: Theme.surfaceActive
                                visible: thumbImg.status !== Image.Ready
                                Spinner { anchors.centerIn: parent; visible: thumbImg.status === Image.Loading }
                            }
                        }

                        // Dimension Pill
                        Rectangle {
                            anchors { bottom: parent.bottom; left: parent.left; margins: 6 }
                            visible: !wh_hh.hovered && !isDlActive && itemData.dimension_x !== undefined
                            radius: Theme.radiusSm
                            color: "#cc000000"
                            implicitWidth: dimLabel.implicitWidth + 10
                            implicitHeight: 18

                            Text {
                                id: dimLabel
                                anchors.centerIn: parent
                                text: itemData.dimension_x + "×" + itemData.dimension_y
                                color: "#ffffff"
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fontSizeLabel
                            }
                        }

                        // Purity dot
                        Rectangle {
                            anchors { top: parent.top; left: parent.left; margins: 6 }
                            visible: !wh_hh.hovered && !isDlActive
                            width: 8; height: 8; radius: 4
                            color: {
                                var p = (itemData.purity || "sfw").toLowerCase()
                                if (p === "sfw") return Theme.success
                                if (p === "sketchy") return Theme.warning
                                return Theme.error
                            }
                        }

                        // Downloaded Checkmark Badge
                        Rectangle {
                            anchors { top: parent.top; right: parent.right; margins: 6 }
                            visible: isDlDone && !isDlActive && !wh_hh.hovered
                            width: 18; height: 18; radius: 9
                            color: Theme.success

                            MaterialIcon {
                                anchors.centerIn: parent
                                iconName: "check"
                                pixelSize: 12
                                color: "#000000"
                            }
                        }

                        // Active Download Progress Overlay on Card
                        Rectangle {
                            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 4 }
                            implicitHeight: 40
                            radius: Theme.radiusSm
                            color: "#ee090c14"
                            border.color: Theme.accent
                            visible: isDlActive
                            z: 20

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 6
                                spacing: 4

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 4

                                    Spinner { implicitWidth: 12; implicitHeight: 12 }

                                    Text {
                                        text: (dlInfo ? Math.round(dlInfo.progress) + "%" : "0%")
                                        color: Theme.accent
                                        font.family: Theme.fontMono
                                        font.pixelSize: Theme.fontSizeSmall
                                        font.bold: true
                                    }

                                    Text {
                                        text: dlInfo ? dlInfo.speed : ""
                                        color: Theme.textSecondary
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeLabel - 1
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                    }

                                    IconButton {
                                        iconName: "close"
                                        implicitWidth: 18; implicitHeight: 18
                                        onClicked: {
                                            if (targetUrl) WallpaperDownloads.cancelDownload(targetUrl)
                                        }
                                    }
                                }

                                // Progress track & fill
                                Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: 4
                                    radius: 2
                                    color: Theme.surfaceActive

                                    Rectangle {
                                        anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                                        width: parent.width * (dlInfo ? (dlInfo.progress / 100.0) : 0)
                                        radius: 2
                                        color: Theme.accent
                                        Behavior on width { NumberAnimation { duration: Anim.d(Anim.fast) } }
                                    }
                                }
                            }
                        }

                        TapHandler {
                            onTapped: detailModal.show(itemData)
                        }

                        HoverHandler {
                            id: wh_hh
                            cursorShape: Qt.PointingHandCursor
                            onHoveredChanged: {
                                if (hovered && itemData && itemData.id) {
                                    Wallhaven.fetchDetails(itemData.id)
                                }
                            }
                        }

                        // Hover Actions Overlay
                        Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            color: "#cc000000"
                            opacity: wh_hh.hovered && !isDlActive ? 1 : 0
                            visible: opacity > 0
                            Behavior on opacity { NumberAnimation { duration: Anim.d(Anim.fast) } }

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 6

                                RowLayout {
                                    Layout.alignment: Qt.AlignHCenter
                                    spacing: 6

                                    DialogButton {
                                        text: Wallhaven.applyingUrl === itemData.path ? "Applying…" : "Apply"
                                        primary: true
                                        iconName: "wallpaper"
                                        onClicked: {
                                            Wallhaven.applyWallpaper(itemData.path, function(ok, path) {
                                                if (ok) Notifications.notify("Wallpaper Set", "Active on all screens.", "wallpaper", "normal", { appName: "Wallhaven" })
                                            })
                                        }
                                    }

                                    DialogButton {
                                        text: isDlDone ? "Saved ✓" : "Save"
                                        iconName: isDlDone ? "check" : "download"
                                        onClicked: {
                                            if (!isDlActive && !isDlDone) {
                                                Wallhaven.saveWallpaper(itemData.path, "Wallhaven #" + itemData.id)
                                            }
                                        }
                                    }
                                }

                                DialogButton {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: "Inspect Details"
                                    iconName: "info"
                                    onClicked: detailModal.show(itemData)
                                }
                            }
                        }
                    }
                }
            }

            // ── Wallpaper Engine Grid (Workshop & Installed) ───────────────────
            GridView {
                id: weGrid
                anchors.fill: parent
                visible: root.tab === "wallpaperengine" && !WallpaperEngine.loading && currentWeModel.count > 0
                clip: true
                cellWidth: Math.floor((width - 6) / Math.max(1, Math.floor((width - 6) / 230)))
                cellHeight: cellWidth * 0.62 + 8
                model: WallpaperEngine.activeSource === "installed" ? WallpaperEngine.installedModel : WallpaperEngine.resultsModel
                readonly property var currentWeModel: model
                boundsBehavior: Flickable.DragAndOvershootBounds
                flickDeceleration: 1800
                maximumFlickVelocity: 3500

                property real targetContentY: contentY

                NumberAnimation {
                    id: weScrollAnimation
                    target: weGrid
                    property: "contentY"
                    duration: Anim.d(Anim.enter)
                    easing.type: Easing.OutCubic
                }

                WheelHandler {
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: function(event) {
                        weGrid.cancelFlick()
                        var maxContentY = Math.max(0, weGrid.contentHeight - weGrid.height)
                        var delta = (event.angleDelta.y !== 0) ? -event.angleDelta.y : -event.pixelDelta.y
                        var step = delta * 1.2
                        var currentTarget = weScrollAnimation.running ? weGrid.targetContentY : weGrid.contentY
                        var nextTarget = Math.max(0, Math.min(maxContentY, currentTarget + step))
                        weGrid.targetContentY = nextTarget
                        weScrollAnimation.stop()
                        weScrollAnimation.duration = Anim.d(Anim.enter)
                        weScrollAnimation.to = nextTarget
                        weScrollAnimation.start()
                        event.accepted = true
                    }
                }

                onMovementStarted: weScrollAnimation.stop()
                onFlickStarted: weScrollAnimation.stop()
                onMovementEnded: weGrid.targetContentY = weGrid.contentY
                onFlickEnded: weGrid.targetContentY = weGrid.contentY

                onContentYChanged: {
                    if (WallpaperEngine.activeSource === "workshop" && !WallpaperEngine.loading && !WallpaperEngine.loadingMore && WallpaperEngine.hasMore) {
                        if (contentY + height >= contentHeight - cellHeight * 2.5) {
                            WallpaperEngine.loadMore()
                        }
                    }
                }

                delegate: Item {
                    id: weCardItem
                    required property var itemData
                    readonly property var modelData: itemData
                    readonly property string weTargetUrl: (itemData && (itemData.cached_preview || itemData.preview || itemData.url)) ? (itemData.cached_preview || itemData.preview || itemData.url) : ""
                    readonly property var weDlInfo: weTargetUrl ? WallpaperDownloads.getDownload(weTargetUrl) : null
                    readonly property bool isWeDlActive: weDlInfo !== null && weDlInfo.status === "downloading"

                    width: weGrid.cellWidth
                    height: weGrid.cellHeight

                    Rectangle {
                        id: weCardBox
                        anchors.fill: parent
                        anchors.margins: 5
                        radius: Theme.radiusMd
                        color: Theme.surface
                        clip: true
                        border.width: isWeDlActive ? 2 : (we_hh.hovered ? 2 : 1)
                        border.color: isWeDlActive ? Theme.accent : (we_hh.hovered ? Theme.accent : Theme.border)

                        Behavior on border.color { ColorAnimation { duration: Anim.d(Anim.fast) } }

                        Image {
                            id: weThumbImg
                            anchors.fill: parent
                            anchors.margins: 2
                            source: {
                                var p = (itemData && (itemData.cached_preview || itemData.preview)) ? (itemData.cached_preview || itemData.preview) : ""
                                if (p.startsWith("/")) return "file://" + p
                                return p
                            }
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: true
                            smooth: true
                            sourceSize.width: 320
                            sourceSize.height: 180
                            clip: true

                            Rectangle {
                                anchors.fill: parent
                                color: Theme.surfaceActive
                                visible: weThumbImg.status !== Image.Ready
                                Spinner { anchors.centerIn: parent; visible: weThumbImg.status === Image.Loading }
                            }
                        }

                        // NSFW Blur / Shield Overlay
                        Rectangle {
                            anchors.fill: parent
                            visible: WallpaperEngine.blurNsfw && (itemData.purity === "nsfw" || itemData.age_rating === "Mature") && !we_hh.hovered && !isWeDlActive
                            color: "#ee0f121a"

                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 4
                                MaterialIcon {
                                    Layout.alignment: Qt.AlignHCenter
                                    iconName: "visibility_off"
                                    pixelSize: 22
                                    color: Theme.error
                                }
                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: "NSFW (18+)"
                                    color: Theme.error
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeLabel
                                    font.bold: true
                                }
                            }
                        }

                        // Purity indicator dot at top-left
                        Rectangle {
                            anchors { top: parent.top; left: parent.left; margins: 6 }
                            visible: !we_hh.hovered && !isWeDlActive
                            width: 8; height: 8; radius: 4
                            color: {
                                var p = (itemData && itemData.purity ? itemData.purity : "sfw").toLowerCase()
                                if (p === "sfw") return Theme.success
                                if (p === "sketchy") return Theme.warning
                                return Theme.error
                            }
                        }

                        // Type Pill at top-left (offset right of purity dot)
                        Rectangle {
                            anchors { top: parent.top; left: parent.left; leftMargin: 18; topMargin: 6 }
                            visible: !we_hh.hovered && !isWeDlActive
                            radius: Theme.radiusSm
                            implicitHeight: 18
                            implicitWidth: weTypeTxt.implicitWidth + 10
                            color: "#cc000000"

                            Text {
                                id: weTypeTxt
                                anchors.centerIn: parent
                                text: ((itemData && itemData.type) ? itemData.type : "scene").toUpperCase()
                                color: Theme.accent
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeLabel - 1
                                font.bold: true
                            }
                        }

                        // Rating badge at bottom-left
                        Rectangle {
                            anchors { bottom: parent.bottom; left: parent.left; margins: 6 }
                            visible: !we_hh.hovered && !isWeDlActive && itemData.rating !== undefined && itemData.rating > 0
                            radius: Theme.radiusSm
                            color: "#cc000000"
                            implicitWidth: weRatingLabel.implicitWidth + 10
                            implicitHeight: 18

                            RowLayout {
                                id: weRatingLabel
                                anchors.centerIn: parent
                                spacing: 2
                                MaterialIcon { iconName: "star"; pixelSize: 11; color: "#ffca28" }
                                Text {
                                    text: "" + itemData.rating
                                    color: "#ffffff"
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.fontSizeLabel
                                }
                            }
                        }

                        // Installed badge at top-right
                        Rectangle {
                            anchors { top: parent.top; right: parent.right; margins: 6 }
                            visible: !we_hh.hovered && !isWeDlActive && itemData && itemData.is_local
                            width: 18; height: 18; radius: 9
                            color: Theme.success
                            MaterialIcon {
                                anchors.centerIn: parent
                                iconName: "check"
                                pixelSize: 12
                                color: "#000000"
                            }
                        }

                        // Active Direct Download Progress Bar Overlay
                        Rectangle {
                            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 4 }
                            implicitHeight: 40
                            radius: Theme.radiusSm
                            color: "#ee090c14"
                            border.color: Theme.accent
                            visible: isWeDlActive
                            z: 20

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 6
                                spacing: 4

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 4

                                    Spinner { implicitWidth: 12; implicitHeight: 12 }

                                    Text {
                                        text: (weDlInfo ? Math.round(weDlInfo.progress) + "%" : "0%")
                                        color: Theme.accent
                                        font.family: Theme.fontMono
                                        font.pixelSize: Theme.fontSizeSmall
                                        font.bold: true
                                    }

                                    Text {
                                        text: weDlInfo ? weDlInfo.speed : ""
                                        color: Theme.textSecondary
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeLabel - 1
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                    }

                                    IconButton {
                                        iconName: "close"
                                        implicitWidth: 18; implicitHeight: 18
                                        onClicked: {
                                            if (weTargetUrl) WallpaperDownloads.cancelDownload(weTargetUrl)
                                        }
                                    }
                                }

                                // Progress track & fill
                                Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: 4
                                    radius: 2
                                    color: Theme.surfaceActive

                                    Rectangle {
                                        anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                                        width: parent.width * (weDlInfo ? (weDlInfo.progress / 100.0) : 0)
                                        radius: 2
                                        color: Theme.accent
                                        Behavior on width { NumberAnimation { duration: Anim.d(Anim.fast) } }
                                    }
                                }
                            }
                        }

                        TapHandler {
                            onTapped: weDetailModal.show(itemData)
                        }

                        HoverHandler {
                            id: we_hh
                            cursorShape: Qt.PointingHandCursor
                            onHoveredChanged: {
                                if (hovered && itemData && (itemData.id || itemData.path)) {
                                    WallpaperEngine.fetchDetails(itemData.path || itemData.id)
                                }
                            }
                        }

                        // Hover Actions Overlay
                        Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            color: "#cc000000"
                            opacity: we_hh.hovered && !isWeDlActive ? 1 : 0
                            visible: opacity > 0
                            Behavior on opacity { NumberAnimation { duration: Anim.d(Anim.fast) } }

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 6

                                RowLayout {
                                    Layout.alignment: Qt.AlignHCenter
                                    spacing: 6
                                    DialogButton {
                                        text: WallpaperEngine.applyingId === (itemData ? (itemData.id || itemData.path) : "") ? "Applying…" : "Apply Live"
                                        primary: true
                                        iconName: "wallpaper"
                                        onClicked: {
                                            WallpaperEngine.applyWallpaper(itemData, "", function(ok, path) {
                                                if (ok) Notifications.notify("Wallpaper Applied", "Wallpaper Engine project active.", "wallpaper", "normal", { appName: "Wallpaper Engine" })
                                            })
                                        }
                                    }

                                    DialogButton {
                                        visible: itemData && !itemData.is_local
                                        text: "Steam"
                                        iconName: "sports_esports"
                                        onClicked: {
                                            WallpaperEngine.openInSteam(itemData.id)
                                        }
                                    }
                                }

                                DialogButton {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: "Inspect Details"
                                    iconName: "info"
                                    onClicked: weDetailModal.show(itemData)
                                }

                                Text {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignHCenter
                                    horizontalAlignment: Text.AlignHCenter
                                    text: (itemData && itemData.title) ? itemData.title : ""
                                    color: Theme.text
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.bold: true
                                    elide: Text.ElideRight
                                    maximumLineCount: 1
                                }
                            }
                        }
                    }
                }
            }

            // ── Floating Active Downloads Status Pill ────────────────────────
            Rectangle {
                anchors { right: parent.right; bottom: parent.bottom; margins: 20 }
                visible: WallpaperDownloads.activeCount > 0
                implicitHeight: 44
                implicitWidth: activeDlRow.implicitWidth + 24
                radius: Theme.radiusMd
                color: Theme.surface
                border.color: Theme.accent
                border.width: 1.5
                z: 80

                scale: WallpaperDownloads.activeCount > 0 ? 1.0 : 0.8
                Behavior on scale { NumberAnimation { duration: Anim.d(Anim.standard); easing.type: Anim.easeStandard } }

                RowLayout {
                    id: activeDlRow
                    anchors.centerIn: parent
                    spacing: 10

                    Spinner {
                        implicitWidth: 16; implicitHeight: 16
                    }

                    ColumnLayout {
                        spacing: 1
                        Text {
                            text: "Downloading " + WallpaperDownloads.activeCount + " wallpaper" + (WallpaperDownloads.activeCount > 1 ? "s" : "") + "…"
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            font.bold: true
                        }
                        Text {
                            text: "Saving straight to your library"
                            color: Theme.textSecondary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeLabel
                        }
                    }
                }
            }

            // ── Floating Scroll-to-Top Button ────────────────────────────────
            Rectangle {
                anchors { right: parent.right; bottom: parent.bottom; margins: 16 }
                visible: (root.tab === "wallhaven" && whGrid.contentY > 500 && WallpaperDownloads.activeCount === 0) || (root.tab === "wallpaperengine" && weGrid.contentY > 500 && WallpaperDownloads.activeCount === 0)
                implicitWidth: 38; implicitHeight: 38
                radius: 19
                color: Theme.accent
                border.color: Theme.borderStrong
                z: 30

                MaterialIcon {
                    anchors.centerIn: parent
                    iconName: "arrow_upward"
                    pixelSize: 18
                    color: Theme.accentText
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: {
                        if (root.tab === "wallhaven") {
                            whGrid.cancelFlick()
                            whGrid.targetContentY = 0
                            scrollAnimation.stop()
                            scrollAnimation.duration = Anim.d(Anim.slow)
                            scrollAnimation.to = 0
                            scrollAnimation.start()
                        } else {
                            weGrid.cancelFlick()
                            weGrid.targetContentY = 0
                            weScrollAnimation.stop()
                            weScrollAnimation.duration = Anim.d(Anim.slow)
                            weScrollAnimation.to = 0
                            weScrollAnimation.start()
                        }
                    }
                }
            }

            // ── Pagination Loading Indicator ──────────────────────────────────
            Rectangle {
                anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter; margins: 10 }
                visible: (root.tab === "wallhaven" && Wallhaven.loadingMore) || (root.tab === "wallpaperengine" && WallpaperEngine.loadingMore)
                implicitHeight: 32
                implicitWidth: loadMoreRow.implicitWidth + 24
                radius: Theme.radiusSm
                color: Theme.surface
                border.color: Theme.border
                z: 25

                RowLayout {
                    id: loadMoreRow
                    anchors.centerIn: parent
                    spacing: 8
                    Spinner { implicitWidth: 16; implicitHeight: 16 }
                    Text {
                        text: "Loading more wallpapers…"
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                    }
                }
            }

            // ── Initial Loading State ─────────────────────────────────────────
            ColumnLayout {
                anchors.centerIn: parent
                visible: (root.tab === "wallhaven" && Wallhaven.loading) || (root.tab === "wallpaperengine" && (WallpaperEngine.loading || WallpaperEngine.loadingInstalled))
                spacing: 12

                Spinner {
                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth: 36; implicitHeight: 36
                }

                Text {
                    text: root.tab === "wallhaven" ? "Exploring Wallhaven wallpapers…" : "Exploring Wallpaper Engine wallpapers…"
                    color: Theme.textSecondary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeBody
                }
            }

            // ── Rate Limit / General Error State ──────────────────────────────
            Rectangle {
                anchors.centerIn: parent
                visible: (root.tab === "wallhaven" && !Wallhaven.loading && Wallhaven.error !== "" && Wallhaven.errorType !== "empty") ||
                         (root.tab === "wallpaperengine" && !WallpaperEngine.loading && WallpaperEngine.error !== "" && WallpaperEngine.errorType !== "empty")
                implicitWidth: Math.min(parent.width - 60, 480)
                implicitHeight: errCol.implicitHeight + 36
                radius: Theme.radiusLg
                color: Theme.surface
                border.color: Theme.error

                ColumnLayout {
                    id: errCol
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 12

                    MaterialIcon {
                        Layout.alignment: Qt.AlignHCenter
                        iconName: "cloud_off"
                        pixelSize: 36
                        color: Theme.error
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "Connection Issue"
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeTitle
                        font.bold: true
                    }

                    Text {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: root.tab === "wallhaven" ? Wallhaven.error : WallpaperEngine.error
                        color: Theme.textSecondary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeBody
                        wrapMode: Text.WordWrap
                    }

                    DialogButton {
                        Layout.alignment: Qt.AlignHCenter
                        text: "Retry Search"
                        primary: true
                        iconName: "refresh"
                        onClicked: {
                            if (root.tab === "wallhaven") Wallhaven.search(true)
                            else WallpaperEngine.search(true)
                        }
                    }
                }
            }

            // ── Empty State ───────────────────────────────────────────────────
            ColumnLayout {
                anchors.centerIn: parent
                visible: (root.tab === "wallhaven" && !Wallhaven.loading && (Wallhaven.resultsModel.count === 0 && (Wallhaven.errorType === "empty" || Wallhaven.error === ""))) ||
                         (root.tab === "wallpaperengine" && !WallpaperEngine.loading && !WallpaperEngine.loadingInstalled && ((WallpaperEngine.activeSource === "installed" ? WallpaperEngine.installedModel.count : WallpaperEngine.resultsModel.count) === 0))
                spacing: 14

                MaterialIcon {
                    Layout.alignment: Qt.AlignHCenter
                    iconName: "image_search"
                    pixelSize: 44
                    color: Theme.textDim
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.tab === "wallpaperengine" && WallpaperEngine.activeSource === "installed" ? "No Installed Wallpapers Found" : "No Wallpapers Found"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeTitle
                    font.bold: true
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.tab === "wallpaperengine" && WallpaperEngine.activeSource === "installed"
                        ? "Subscribe to items on Steam Workshop, or place project folders into ~/Pictures/Wallpapers/WallpaperEngine"
                        : "Try broadening your keywords, removing active tag filters, or resetting filters."
                    color: Theme.textSecondary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeBody
                }

                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 8

                    DialogButton {
                        text: root.tab === "wallpaperengine" && WallpaperEngine.activeSource === "installed" ? "Switch to Steam Workshop" : "Clear All Filters"
                        iconName: root.tab === "wallpaperengine" && WallpaperEngine.activeSource === "installed" ? "cloud_download" : "restart_alt"
                        primary: true
                        onClicked: {
                            if (root.tab === "wallhaven") {
                                Wallhaven.resetFilters()
                            } else {
                                if (WallpaperEngine.activeSource === "installed") {
                                    WallpaperEngine.activeSource = "workshop"
                                    WallpaperEngine.search(true)
                                } else {
                                    WallpaperEngine.resetFilters()
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ── Dismiss scrims for tag suggestions dropdowns ─────────────────────────
    MouseArea {
        anchors.fill: parent
        z: 45
        visible: (root.suggestions.length > 0 && searchInput.activeFocus) || (root.weSuggestions.length > 0 && weSearchInput.activeFocus)
        onClicked: {
            root.suggestions = []
            root.selectedSuggestionIndex = -1
            root.weSuggestions = []
            root.selectedWeSuggestionIndex = -1
        }
    }

    // ── Wallpaper Inspector Modals ────────────────────────────────────────────
    WallhavenDetailModal {
        id: detailModal
        onTagClicked: function(t) {
            root.addTagToSearch(t)
        }
        onColorClicked: function(c) {
            Wallhaven.setColor(c)
        }
        onCategoryClicked: function(cat) {
            root.addTagToSearch(cat)
        }
        onResolutionClicked: function(res) {
            Wallhaven.atleast = res
            Wallhaven.search(true)
        }
    }

    WallpaperEngineDetailModal {
        id: weDetailModal
        onTagClicked: function(t) {
            root.addWeTagToSearch(t)
        }
        onTypeClicked: function(t) {
            WallpaperEngine.selectedType = t
            WallpaperEngine.search(true)
        }
    }
}
