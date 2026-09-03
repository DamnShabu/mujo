import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../theme"
import "../../components"
import "../../services"

// Wallpapers & Backgrounds.
//
// The one category that is half catalogue, half settings, so it hosts both
// shapes behind a single hero and one MujoSegmented rail:
//
//   Library / Wallhaven / Wallpaper Engine → WallpaperBrowseGroup, full-height
//                                            grids that own their own scrolling
//   Effects                                → SettingsPage, the same scrolling
//                                            MujoCard column as every other
//                                            category (hero suppressed, since
//                                            this page already drew one)
//
// wallpaper.json is watched once, here, and `mujo wallpaper …` is run from one
// place, so both children stay in sync off the same reload.
Item {
    id: root

    property string tab: "library"   // library | wallhaven | wallpaperengine | effects
    property var localList: []
    property string currentImage: ""
    property string letterbox: Theme.active.bg
    property bool motionOn: false

    function runWp(args) { Quickshell.execDetached(["mujo", "wallpaper"].concat(args)) }
    function refreshLocal() { listProc.running = true }

    Component.onCompleted: root.refreshLocal()

    // Same contract as SettingsPage.revealCard, so SettingsLayout can route
    // into this page without knowing it is the odd one out. Here `name` is
    // either a tab id (the three catalogue browsers, which have no cards) or a
    // MujoCard title on the Effects tab.
    readonly property var tabIds: ["library", "wallhaven", "wallpaperengine", "effects"]
    function revealCard(name) {
        if (root.tabIds.indexOf(name) >= 0) {
            root.tab = name
            return true
        }
        root.tab = "effects"
        return true
    }


    FileView {
        path: (Quickshell.env("HOME") || "/tmp") + "/.config/quickshell/wallpaper.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                var c = JSON.parse(text())
                var d = c["default"] || {}
                root.currentImage = d.image || d.video || d.engine || ""
                root.letterbox = c.background || Theme.active.bg
                root.motionOn = !!(c.effects && c.effects.motion)
            } catch (e) {
                console.warn("WallpapersPage: wallpaper.json parse error:", e)
            }
        }
    }

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

    Connections {
        target: WallpaperDownloads
        function onDownloadFinished(url, destPath) { root.refreshLocal() }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 14

        MujoHero {
            Layout.fillWidth: true
            brand: root.tab === "wallhaven" ? "wallhaven"
                 : (root.tab === "wallpaperengine" ? "wallpaperengine" : "wallpaper")
            title: root.tab === "wallhaven" ? "Wallhaven Explorer"
                 : (root.tab === "wallpaperengine" ? "Wallpaper Engine"
                 : (root.tab === "effects" ? "Wallpaper Effects" : "Wallpaper Library"))
            subtitle: {
                if (root.tab === "wallhaven") return "Search millions of high-resolution wallpapers with fast NVMe thumbnail caching, filters, and real-time downloads."
                if (root.tab === "wallpaperengine") return "Browse Steam Workshop Wallpaper Engine items (431960), manage installed projects, and configure live rendering."
                if (root.tab === "effects") return "Cursor parallax, letterbox fill colour, and the Wallpaper Engine render budget."
                return "Apply a wallpaper from your local collection, or download more from Wallhaven and Wallpaper Engine."
            }
            badgeText: {
                if (root.tab === "library") return root.localList.length + " IN LIBRARY"
                if (root.tab === "wallhaven") return Wallhaven.totalResults > 0
                    ? (Wallhaven.totalResults.toLocaleString() + " WALLPAPERS") : "ONLINE GALLERY"
                if (root.tab === "wallpaperengine") return WallpaperEngine.activeSource === "installed"
                    ? (WallpaperEngine.totalInstalledCount + " INSTALLED")
                    : (WallpaperEngine.steamRunning ? "STEAM CONNECTED" : "STEAM WORKSHOP")
                return "MOTION & AMBIENCE"
            }
            badgeColor: Theme.accent

            MujoSegmented {
                model: [
                    { id: "library",         label: "Library",          icon: "photo_library" },
                    { id: "wallhaven",       label: "Wallhaven",        icon: "cloud_download" },
                    { id: "wallpaperengine", label: "Wallpaper Engine", icon: "sports_esports" },
                    { id: "effects",         label: "Effects",          icon: "tune" }
                ]
                current: root.tab
                onSelected: function (id) { root.tab = id }
            }
        }

        // Catalogue browsers — full remaining height, their own scrolling.
        WallpaperBrowseGroup {
            visible: root.tab !== "effects"
            Layout.fillWidth: true
            Layout.fillHeight: true
            tab: root.tab
            localList: root.localList
            currentImage: root.currentImage
            onWpRun: function (args) { root.runWp(args) }
        }

        // Settings — the standard scrolling MujoCard column. Uses MujoFlickable
        // directly rather than SettingsPage: the page already drew the hero and
        // already applies the 24px margin, and SettingsPage would add both again.
        MujoFlickable {
            visible: root.tab === "effects"
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: width
            contentHeight: effectsCol.implicitHeight

            ColumnLayout {
                id: effectsCol
                width: parent.width
                spacing: 14

                WallpaperEffectsGroup {
                    Layout.fillWidth: true
                    motionOn: root.motionOn
                    letterbox: root.letterbox
                    onWpRun: function (args) { root.runWp(args) }
                }
            }
        }
    }
}
