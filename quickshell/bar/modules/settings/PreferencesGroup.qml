import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../theme"
import "../../components"
import "../../services"

// General System Preferences, Default App Associations (XDG MIME), and Clipboard History Group.
ColumnLayout {
    id: root
    Layout.fillWidth: true
    spacing: 14

    property var nixosPrefs: ({
        hostname: "main",
        timezone: "Europe/Berlin",
        locale: "en_US.UTF-8",
        autoOptimiseStore: false
    })
    property bool nixosDirty: false
    property var defaultsMap: ({})
    property int clipCount: 0
    property bool clipActive: true
    property string clipClearMessage: ""

    readonly property var defaultAppDefs: [
        { key: "browser",     name: "Web Browser",       icon: "public",
          defaultId: "helium.desktop",
          options: [
              { id: "helium.desktop",              name: "Helium Browser" },
              { id: "app.zen_browser.zen.desktop", name: "Zen Browser" },
              { id: "com.brave.Browser.desktop",   name: "Brave Browser" }
          ] },
        { key: "terminal",    name: "Terminal Emulator", icon: "terminal",
          defaultId: "kitty.desktop",
          options: [
              { id: "kitty.desktop", name: "Kitty Terminal" }
          ] },
        { key: "editor",      name: "Text & Code Editor",icon: "code",
          defaultId: "org.gnome.TextEditor.desktop",
          options: [
              { id: "com.visualstudio.code.desktop", name: "Visual Studio Code" },
              { id: "dev.zed.Zed.desktop",           name: "Zed" },
              { id: "md.obsidian.Obsidian.desktop",  name: "Obsidian" },
              { id: "org.gnome.TextEditor.desktop",  name: "GNOME Text Editor" },
              { id: "kitty.desktop",                 name: "Kitty (Neovim)" }
          ] },
        { key: "filemanager", name: "File Manager",      icon: "folder",
          defaultId: "org.gnome.Nautilus.desktop",
          options: [
              { id: "org.gnome.Nautilus.desktop", name: "Nautilus" },
              { id: "kitty.desktop",              name: "Kitty (Yazi)" }
          ] },
        { key: "media",       name: "Video & Audio Player", icon: "movie",
          defaultId: "org.videolan.VLC.desktop",
          options: [
              { id: "org.videolan.VLC.desktop",    name: "VLC Media Player" },
              { id: "org.jeffvli.feishin.desktop", name: "Feishin Music Player" }
          ] }
    ]

    function setDefaultApp(category, desktopId) {
        var m = Object.assign({}, root.defaultsMap)
        m[category] = desktopId
        root.defaultsMap = m
        Quickshell.execDetached(["mujo", "apps", "defaults", "set", category, desktopId])
    }

    function setNixosPref(path, val) {
        var p = JSON.parse(JSON.stringify(root.nixosPrefs))
        var parts = path.split(".")
        var o = p
        for (var i = 0; i < parts.length - 1; i++) {
            if (!o[parts[i]]) o[parts[i]] = {}
            o = o[parts[i]]
        }
        o[parts[parts.length - 1]] = val
        root.nixosPrefs = p
        root.nixosDirty = true
        Quickshell.execDetached(["mujo", "system-pref", "set", path, String(val)])
    }

    Process {
        id: loadPrefsProc
        command: ["mujo", "system-pref", "get"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var parsed = JSON.parse(this.text)
                    if (parsed && typeof parsed === "object") root.nixosPrefs = parsed
                } catch (e) {}
            }
        }
    }
    Process {
        id: defaultsProc
        command: ["mujo", "apps", "defaults", "get"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.defaultsMap = JSON.parse(this.text) } catch (e) { root.defaultsMap = {} }
            }
        }
    }
    Process {
        id: clipProc
        command: ["mujo", "clipboard", "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var st = JSON.parse(this.text)
                    root.clipCount = st.count || 0
                    root.clipActive = st.active !== false
                } catch (e) {}
            }
        }
    }
    function refreshAll() {
        loadPrefsProc.running = true
        defaultsProc.running = true
        clipProc.running = true
    }
    Component.onCompleted: root.refreshAll()

    // ── 1. Default Applications (XDG MIME) Card ───────────────────────────────
    MujoCard {
        title: "Default Applications"
        iconName: "apps"
        badgeText: "XDG MIME"

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 10

            Repeater {
                model: root.defaultAppDefs
                delegate: MujoSettingRow {
                    id: defRow
                    required property var modelData
                    readonly property string activeId: root.defaultsMap[modelData.key] || modelData.defaultId

                    iconName: modelData.icon
                    title: modelData.name
                    description: "Default handler for " + modelData.name.toLowerCase() + " actions."

                    MujoSegmented {
                        model: {
                            var items = []
                            for (var i = 0; i < defRow.modelData.options.length; i++) {
                                var opt = defRow.modelData.options[i]
                                items.push({ id: opt.id, label: opt.name })
                            }
                            return items
                        }
                        current: defRow.activeId
                        onSelected: function(id) { root.setDefaultApp(defRow.modelData.key, id) }
                    }
                }
            }
        }
    }

    // ── 2. System Parameters & Host Configuration Card ────────────────────────
    MujoCard {
        title: "System Parameters & Host Config"
        iconName: "tune"
        isNixos: true

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                MaterialIcon { iconName: "dns"; pixelSize: 20; color: Theme.accent }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    Text { text: "System Hostname"; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeBody }
                    Text { text: "Network identifier for this machine."; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSmall }
                }
                TextField {
                    id: hostField
                    Layout.preferredWidth: 160
                    text: root.nixosPrefs.hostname || "main"
                    onAccepted: root.setNixosPref("hostname", text.trim())
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                MaterialIcon { iconName: "schedule"; pixelSize: 20; color: Theme.accent }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    Text { text: "Timezone"; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeBody }
                    Text { text: "Regional time clock mapping."; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSmall }
                }
                TextField {
                    id: tzField
                    Layout.preferredWidth: 160
                    text: root.nixosPrefs.timezone || "Europe/Berlin"
                    onAccepted: root.setNixosPref("timezone", text.trim())
                }
            }

            MujoSettingRow {
                iconName: "auto_fix_high"
                title: "Auto-Optimise Nix Store"
                description: "Automatically deduplicate store files via hardlinks on system build."

                ToggleSwitch {
                    checked: root.nixosPrefs.autoOptimiseStore === true
                    onToggled: function(c) { root.setNixosPref("autoOptimiseStore", c) }
                }
            }
        }
    }

    // ── 3. Clipboard History Card ─────────────────────────────────────────────
    MujoCard {
        title: "Clipboard History (cliphist)"
        iconName: "content_paste"
        badgeText: root.clipCount + " CLIPS"
        badgeColor: Theme.accent

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                MaterialIcon { iconName: "delete_sweep"; pixelSize: 20; color: Theme.warning }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    Text { text: "Wipe clipboard"; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeBody }
                    Text { text: root.clipClearMessage || "Purge all recorded text and image clips from database."; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSmall }
                }
                DialogButton {
                    text: "Clear history"
                    onClicked: {
                        Quickshell.execDetached(["mujo", "clipboard", "clear"])
                        root.clipCount = 0
                        root.clipClearMessage = "✓ Clipboard history wiped."
                    }
                }
            }
        }
    }
}
