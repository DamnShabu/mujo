import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../theme"
import "../../components"
import "../../services"

// Appearance & Personalization — Themes & Colors, Wallpaper Catalog,
// Wallpaper Effects, and Motion Dynamics.
Item {
    id: root

    property string brand: "appearance"
    property string title: "Appearance"
    property string subtitle: "Theme presets, accent colors, wallpaper catalog, live engines & motion dynamics."

    property string tab: "themes"   // themes | wallpapers | effects | motion
    readonly property var tabIds: ["themes", "wallpapers", "effects", "motion", "library", "wallhaven", "wallpaperengine"]

    // Wallpaper state
    property var localList: []
    property string currentImage: ""
    property string letterbox: Theme.active.bg
    property bool motionOn: false

    function runWp(args) { Quickshell.execDetached(["mujo", "wallpaper"].concat(args)) }
    function refreshLocal() { listProc.running = true }

    Component.onCompleted: root.refreshLocal()

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
                console.warn("AppearancePage: wallpaper.json parse error:", e)
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

    readonly property var cardTabMap: ({
        "Theme Presets": "themes",
        "Accent Color & Surface Opacity": "themes",
        "Wallpaper Engine Performance": "effects",
        "Parallax & Background": "effects",
        "Motion Intensity Profile": "motion",
        "Interactive Motion Playground": "motion",
        "Granular Motion Domains": "motion",
        "Accessibility & Performance": "motion"
    })

    function revealCard(name) {
        if (name === "library" || name === "wallhaven" || name === "wallpaperengine" || name === "wallpapers") {
            root.tab = "wallpapers"
            if (browseGroup && (name === "library" || name === "wallhaven" || name === "wallpaperengine")) {
                browseGroup.tab = name
            }
            return true
        }
        if (root.tabIds.indexOf(name) >= 0) {
            root.tab = name
            return true
        }
        var targetTab = root.cardTabMap[name]
        if (targetTab) {
            root.tab = targetTab
            var flick = _getActiveFlickable()
            if (flick) _scrollFlickToCard(flick, name)
            return true
        }
        return false
    }

    function _getActiveFlickable() {
        if (root.tab === "themes") return flickThemes
        if (root.tab === "effects") return flickEffects
        if (root.tab === "motion") return flickMotion
        return null
    }

    function _scrollFlickToCard(flick, cardTitle) {
        var card = _findCard(flick.contentItem, cardTitle)
        if (!card) return
        var maxY = Math.max(0, flick.contentHeight - flick.height)
        var p = card.mapToItem(flick.contentItem, 0, 0)
        flick.contentY = Math.max(0, Math.min(p.y, maxY))
    }

    function _findCard(node, cardTitle) {
        if (!node) return null
        var kids = node.children
        for (var i = 0; i < kids.length; i++) {
            var c = kids[i]
            if (c.collapsible !== undefined && c.title === cardTitle) return c
            var hit = _findCard(c, cardTitle)
            if (hit) return hit
        }
        return null
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 14

        MujoSegmented {
            Layout.alignment: Qt.AlignLeft
            model: [
                { id: "themes",     label: "Themes & Colors",   icon: "palette" },
                { id: "wallpapers", label: "Wallpapers",        icon: "photo_library" },
                { id: "effects",    label: "Wallpaper Effects", icon: "tune" },
                { id: "motion",     label: "Motion Dynamics",   icon: "animation" }
            ]
            current: root.tab
            onSelected: function(id) { root.tab = id }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            MujoFlickable {
                id: flickThemes
                anchors.fill: parent
                visible: root.tab === "themes"
                contentHeight: colThemes.implicitHeight + 20

                ColumnLayout {
                    id: colThemes
                    width: parent.width
                    spacing: 14
                    ThemeGroup { Layout.fillWidth: true }
                }
            }

            WallpaperBrowseGroup {
                id: browseGroup
                anchors.fill: parent
                visible: root.tab === "wallpapers"
                tab: "library"
                localList: root.localList
                currentImage: root.currentImage
                onWpRun: function(args) { root.runWp(args) }
            }

            MujoFlickable {
                id: flickEffects
                anchors.fill: parent
                visible: root.tab === "effects"
                contentHeight: colEffects.implicitHeight + 20

                ColumnLayout {
                    id: colEffects
                    width: parent.width
                    spacing: 14
                    WallpaperEffectsGroup {
                        Layout.fillWidth: true
                        motionOn: root.motionOn
                        letterbox: root.letterbox
                        onWpRun: function(args) { root.runWp(args) }
                    }
                }
            }

            MujoFlickable {
                id: flickMotion
                anchors.fill: parent
                visible: root.tab === "motion"
                contentHeight: colMotion.implicitHeight + 20

                ColumnLayout {
                    id: colMotion
                    width: parent.width
                    spacing: 14
                    MotionGroup { Layout.fillWidth: true }
                }
            }
        }
    }
}
