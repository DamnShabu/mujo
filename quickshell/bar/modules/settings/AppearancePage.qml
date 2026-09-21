import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../theme"
import "../../components"
import "../../services"

// Appearance — how the desktop looks: palette, wallpaper, and how much it
// moves.
SettingsPage {
    id: root

    brand: "appearance"
    title: "Appearance"
    subtitle: "Theme presets, accent colors, wallpaper catalog, live engines and motion dynamics."
    tab: "themes"

    // Wallpaper state, read once here and handed to the browse section so the
    // library, Wallhaven and Wallpaper Engine all agree on what is set.
    property var localList: []
    property string currentImage: ""
    property string letterbox: Theme.active.bg
    property bool motionOn: false
    // Which of the three catalogs the Wallpapers section is showing.
    property string wpSource: "library"


    function runWp(args) { Quickshell.execDetached(["mujo", "wallpaper"].concat(args)) }
    function refreshLocal() { listProc.running = true }

    Component.onCompleted: root.refreshLocal()

    sections: [
        { id: "themes", label: "Themes & Colors", component: themesSection,
          description: "Pick a palette, set an accent, and tune how solid surfaces are." },
        { id: "wallpapers", label: "Wallpapers", component: wallpapersSection, fill: true,
          description: "Your local library, plus the Wallhaven and Wallpaper Engine catalogs." },
        { id: "effects", label: "Wallpaper Effects", component: effectsSection,
          description: "Parallax, motion, and how much work the wallpaper is allowed to do." },
        { id: "motion", label: "Motion Dynamics", component: motionSection,
          description: "How fast the desktop animates, domain by domain, down to not at all." }
    ]

    cardMap: ({
        "Appearance Mode": "themes",
        "Automated Day & Night Schedule": "themes",
        "Theme Presets": "themes",
        "Accent Color & Surface Opacity": "themes",
        "Wallpaper Engine Performance": "effects",
        "Parallax & Background": "effects",
        "Motion Intensity Profile": "motion",
        "Interactive Motion Playground": "motion",
        "Granular Motion Domains": "motion",
        "Accessibility & Performance": "motion"
    })

    // The wallpaper section has three browsers of its own, so a deep link names
    // one of them rather than a card.
    aliases: ({ "library": "wallpapers", "wallhaven": "wallpapers", "wallpaperengine": "wallpapers" })
    function revealCard(name) {
        var inner = (name === "library" || name === "wallhaven" || name === "wallpaperengine")
        var ok = root.revealSection(name)
        if (ok && inner) root.wpSource = name
        return ok
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

    Component { id: themesSection; ColumnLayout { spacing: 14; ThemeGroup { Layout.fillWidth: true } } }
    Component { id: motionSection; ColumnLayout { spacing: 14; MotionGroup { Layout.fillWidth: true } } }
    Component {
        id: effectsSection
        ColumnLayout {
            spacing: 14
            WallpaperEffectsGroup {
                Layout.fillWidth: true
                motionOn: root.motionOn
                letterbox: root.letterbox
                onWpRun: function (args) { root.runWp(args) }
            }
        }
    }
    Component {
        id: wallpapersSection
        ColumnLayout {
            spacing: 14

            // Three catalogs, one control. They had none: the page pinned the
            // browser to the local library and only an omni-search hit could
            // reach Wallhaven or Wallpaper Engine.
            MujoSegmented {
                Layout.alignment: Qt.AlignLeft
                a11yName: "Wallpaper source"
                model: [
                    { id: "library", label: "Library" },
                    { id: "wallhaven", label: "Wallhaven" },
                    { id: "wallpaperengine", label: "Wallpaper Engine" }
                ]
                current: root.wpSource
                onSelected: function (id) { root.wpSource = id }
            }

            WallpaperBrowseGroup {
                Layout.fillWidth: true
                Layout.fillHeight: true
                tab: root.wpSource
                localList: root.localList
                currentImage: root.currentImage
                onWpRun: function (args) { root.runWp(args) }
            }
        }
    }
}
