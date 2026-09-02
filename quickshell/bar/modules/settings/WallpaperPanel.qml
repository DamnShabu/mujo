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

    readonly property var bgSwatches: [
        "#000000", "#0b0e13", "#111111", "#181825",
        "#1d2021", "#16161e", "#191724", "#21252b"
    ]

    function runWp(args) { Quickshell.execDetached(["mujo", "wallpaper"].concat(args)) }

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

        WallhavenControls {
            id: whControls
            visible: root.tab === "wallhaven"
            Layout.fillWidth: true
        }

        WallpaperEngineControls {
            id: weControls
            visible: root.tab === "wallpaperengine"
            Layout.fillWidth: true
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

            WallpaperLibraryGrid {
                id: libGrid
                anchors.fill: parent
                visible: root.tab === "library"
                model: root.localList
                currentImage: root.currentImage
                onWallpaperChosen: function(path) { root.runWp(["set", path]) }
            }

            WallhavenGrid {
                id: whGrid
                anchors.fill: parent
                visible: root.tab === "wallhaven" && !Wallhaven.loading && count > 0
                onItemActivated: function(itemData) { detailModal.show(itemData) }
            }

            WallpaperEngineGrid {
                id: weGrid
                anchors.fill: parent
                visible: root.tab === "wallpaperengine" && !WallpaperEngine.loading && count > 0
                onItemActivated: function(itemData) { weDetailModal.show(itemData) }
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
                visible: WallpaperDownloads.activeCount === 0
                         && ((root.tab === "wallhaven" && whGrid.contentY > 500)
                             || (root.tab === "wallpaperengine" && weGrid.contentY > 500))
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
                    onClicked: root.tab === "wallhaven" ? whGrid.scrollToTop() : weGrid.scrollToTop()
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
                         (root.tab === "wallpaperengine" && !WallpaperEngine.loading && !WallpaperEngine.loadingInstalled
                          && (WallpaperEngine.errorType === "empty" || WallpaperEngine.error === "")
                          && ((WallpaperEngine.activeSource === "installed" ? WallpaperEngine.installedModel.count : WallpaperEngine.resultsModel.count) === 0))
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

    // ── Dismiss scrim for the tag suggestion dropdowns ───────────────────────
    MouseArea {
        anchors.fill: parent
        z: 45
        visible: whControls.suggestionsOpen || weControls.suggestionsOpen
        onClicked: {
            whControls.dismissSuggestions()
            weControls.dismissSuggestions()
        }
    }

    // ── Wallpaper Inspector Modals ────────────────────────────────────────────
    WallhavenDetailModal {
        id: detailModal
        onTagClicked: function(t) { whControls.addTag(t) }
        onColorClicked: function(c) { Wallhaven.setColor(c) }
        onCategoryClicked: function(cat) { whControls.addTag(cat) }
        onResolutionClicked: function(res) {
            Wallhaven.atleast = res
            Wallhaven.search(true)
        }
    }

    WallpaperEngineDetailModal {
        id: weDetailModal
        onTagClicked: function(t) { weControls.addTag(t) }
        onTypeClicked: function(t) {
            WallpaperEngine.selectedType = t
            WallpaperEngine.search(true)
        }
    }
}
