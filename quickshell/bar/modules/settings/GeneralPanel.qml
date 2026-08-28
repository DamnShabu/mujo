import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../theme"
import "../../components"
import "../../services"

// General Settings & System Preferences Panel — Mujo (無常) Control Center.
// Unified manager for system-wide NixOS preferences, default application associations (XDG MIME),
// clipboard history controls, privacy options, security configurations, and desktop behavior.
Item {
    id: root

    // ── Active Category Filter ────────────────────────────────────────────────
    property string activeCategory: "all" // all | defaults | nixos | clipboard | privacy | security | behavior
    readonly property var categoryTabs: [
        { id: "all",       label: "All Settings",      icon: "tune" },
        { id: "defaults",  label: "Default Apps",      icon: "apps" },
        { id: "nixos",     label: "NixOS Config",      icon: "terminal" },
        { id: "clipboard", label: "Clipboard",         icon: "content_paste" },
        { id: "privacy",   label: "Privacy",           icon: "shield" },
        { id: "security",  label: "Security",          icon: "lock" },
        { id: "behavior",  label: "System Behavior",   icon: "settings_suggest" }
    ]

    function isVisibleCat(catId) {
        return root.activeCategory === "all" || root.activeCategory === catId
    }

    // ── State & NixOS Preferences ─────────────────────────────────────────────
    property var nixosPrefs: ({
        hostname: "main",
        timezone: "Europe/Berlin",
        locale: "en_US.UTF-8",
        firewall: { enable: true, allowedTCPPorts: [11434] },
        ssh: { enable: false },
        autoOptimiseStore: true,
        zramSwap: { enable: true, memoryPercent: 50 }
    })
    property bool nixosDirty: false
    property var defaultsMap: ({})
    property int clipCount: 0
    property bool clipActive: true
    property string powerProfile: "balanced"
    property string clipClearMessage: ""
    property string privacyClearMessage: ""

    // ── SettingsBus Helper ────────────────────────────────────────────────────
    function bget(key, fallback) { return SettingsBus.get(key, fallback) }
    function bset(key, val) { SettingsBus.set(key, val) }

    // ── NixOS Preferences Mutation ────────────────────────────────────────────
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

    // ── Default Applications Data ─────────────────────────────────────────────
    readonly property var defaultAppDefs: [
        { key: "browser",     name: "Web Browser",       icon: "public",
          defaultId: "app.zen_browser.zen.desktop",
          options: [
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
        { key: "image",       name: "Image Viewer",      icon: "image",
          defaultId: "org.gimp.GIMP.desktop",
          options: [
              { id: "org.gimp.GIMP.desktop",       name: "GIMP" },
              { id: "app.zen_browser.zen.desktop", name: "Zen Browser" }
          ] },
        { key: "media",       name: "Video & Audio Player", icon: "movie",
          defaultId: "org.videolan.VLC.desktop",
          options: [
              { id: "org.videolan.VLC.desktop",    name: "VLC Media Player" },
              { id: "org.jeffvli.feishin.desktop", name: "Feishin Music Player" }
          ] },
        { key: "pdf",         name: "PDF Viewer",        icon: "picture_as_pdf",
          defaultId: "app.zen_browser.zen.desktop",
          options: [
              { id: "app.zen_browser.zen.desktop", name: "Zen Browser" },
              { id: "com.brave.Browser.desktop",   name: "Brave Browser" }
          ] }
    ]

    function setDefaultApp(category, desktopId) {
        var m = Object.assign({}, root.defaultsMap)
        m[category] = desktopId
        root.defaultsMap = m
        Quickshell.execDetached(["mujo", "apps", "defaults", "set", category, desktopId])
    }

    // ── Backend Processes ─────────────────────────────────────────────────────
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

    Process {
        id: powerProc
        command: ["mujo", "power-profile", "get"]
        stdout: StdioCollector {
            onStreamFinished: {
                var p = this.text.trim()
                if (p === "performance" || p === "balanced" || p === "power-saver") root.powerProfile = p
            }
        }
    }

    function refreshAll() {
        loadPrefsProc.running = true
        defaultsProc.running = true
        clipProc.running = true
        powerProc.running = true
    }

    Component.onCompleted: root.refreshAll()

    // ── Dynamic Hero Branding ─────────────────────────────────────────────────
    readonly property string currentHeroBrand: {
        if (root.activeCategory === "defaults") return "applications"
        if (root.activeCategory === "nixos") return "system"
        if (root.activeCategory === "clipboard") return "clipboard"
        if (root.activeCategory === "privacy") return "privacy"
        if (root.activeCategory === "security") return "security"
        if (root.activeCategory === "behavior") return "behavior"
        return "general"
    }
    readonly property string currentHeroTitle: {
        if (root.activeCategory === "defaults") return "Default Applications"
        if (root.activeCategory === "nixos") return "NixOS Configuration"
        if (root.activeCategory === "clipboard") return "Clipboard History"
        if (root.activeCategory === "privacy") return "Privacy & Isolation"
        if (root.activeCategory === "security") return "Security & Firewall"
        if (root.activeCategory === "behavior") return "System Behavior & Power"
        return "General Preferences"
    }
    readonly property string currentHeroSubtitle: {
        if (root.activeCategory === "defaults") return "XDG MIME associations for web browser, terminal, editor, file manager, and media."
        if (root.activeCategory === "nixos") return "Declarative system parameters: hostname, timezone, locale, and nix store optimization."
        if (root.activeCategory === "clipboard") return "Cliphist recording buffer, image cache, sensitive password filtering, and retention."
        if (root.activeCategory === "privacy") return "Global telemetry opt-out, screen share protection, and GTK recent files buffer."
        if (root.activeCategory === "security") return "nftables kernel firewall, OpenSSH remote daemon, and screen lock policies."
        if (root.activeCategory === "behavior") return "Hardware CPU governors, zram compressed swap, and auditory alerts."
        return "Unified manager for system preferences, default applications, privacy, and desktop behavior."
    }

    // ── Main Scroll View ──────────────────────────────────────────────────────
    Flickable {
        anchors.fill: parent
        anchors.margins: 24
        contentHeight: mainCol.implicitHeight + 30
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: mainCol
            width: parent.width
            spacing: 16

            // ── Dynamic Hero Banner ───────────────────────────────────────────
            MujoHero {
                brand: root.currentHeroBrand
                title: root.currentHeroTitle
                subtitle: root.currentHeroSubtitle
                badgeText: root.nixosDirty ? "MODIFIED" : (root.activeCategory === "nixos" ? "SYNCED" : "")
                badgeColor: root.nixosDirty ? Theme.warning : Theme.success
                isNixos: root.activeCategory === "nixos"

                IconButton {
                    iconName: "refresh"
                    onClicked: root.refreshAll()
                }
            }

            // ── Pending NixOS Rebuild Notice ──────────────────────────────────
            Rectangle {
                visible: root.nixosDirty
                Layout.fillWidth: true
                implicitHeight: rbdRow.implicitHeight + 16
                radius: Theme.radiusMd
                color: Theme.withAlpha(Theme.warning, 0.12)
                border.color: Theme.warning

                RowLayout {
                    id: rbdRow
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 12

                    MaterialIcon {
                        iconName: "sync_problem"
                        pixelSize: 20
                        color: Theme.warning
                        Layout.alignment: Qt.AlignVCenter
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1
                        Layout.alignment: Qt.AlignVCenter

                        Text {
                            text: "NixOS preferences modified"
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeBody
                            font.bold: true
                        }
                        Text {
                            text: "Declarative changes are staged in nixos/system-preferences.json. Rebuild system to apply."
                            color: Theme.textSecondary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                        }
                    }

                    DialogButton {
                        text: "Rebuild & Switch"
                        primary: true
                        onClicked: {
                            root.nixosDirty = false
                            Quickshell.execDetached(["mujo", "system-pref", "apply"])
                        }
                    }
                }
            }

            // ── Category Filter Tabs ──────────────────────────────────────────
            Flow {
                Layout.fillWidth: true
                spacing: 8

                Repeater {
                    model: root.categoryTabs
                    delegate: Rectangle {
                        required property var modelData
                        readonly property bool active: root.activeCategory === modelData.id
                        implicitWidth: tabRow.implicitWidth + 20
                        implicitHeight: 32
                        radius: Theme.radiusMd
                        color: active ? Theme.accentDim : (tb_hh.hovered ? Theme.surfaceHover : Theme.surface)
                        border.color: active ? Theme.accent : Theme.border
                        Behavior on color { ColorAnimation { duration: Anim.d(Anim.fast) } }

                        RowLayout {
                            id: tabRow
                            anchors.centerIn: parent
                            spacing: 6

                            MaterialIcon {
                                iconName: modelData.icon
                                pixelSize: 15
                                color: active ? Theme.accent : Theme.textSecondary
                            }
                            Text {
                                text: modelData.label
                                color: active ? Theme.text : Theme.textSecondary
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSmall
                                font.bold: active
                            }
                        }
                        HoverHandler { id: tb_hh; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: root.activeCategory = modelData.id }
                    }
                }
            }

            // ═════════════════════════════════════════════════════════════════
            // SECTION 1: DEFAULT APPLICATIONS (XDG MIME)
            // ═════════════════════════════════════════════════════════════════
            MujoCard {
                visible: root.isVisibleCat("defaults")
                title: "Default Applications"
                iconName: "apps"
                badgeText: "XDG MIME"
                badgeColor: Theme.accent

                Repeater {
                    model: root.defaultAppDefs
                    delegate: ColumnLayout {
                        required property var modelData
                        readonly property string currentAppId: root.defaultsMap[modelData.key] || modelData.defaultId
                        readonly property bool isOverridden: currentAppId !== modelData.defaultId
                        Layout.fillWidth: true
                        spacing: 6

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            MaterialIcon {
                                iconName: modelData.icon
                                pixelSize: 16
                                color: Theme.accent
                            }
                            Text {
                                text: modelData.name
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeBody
                                font.bold: true
                            }
                            Rectangle {
                                implicitWidth: inhTxt.implicitWidth + 8
                                implicitHeight: 16
                                radius: Theme.radiusSm
                                color: isOverridden ? Theme.withAlpha(Theme.warning, 0.14) : Theme.withAlpha(Theme.success, 0.14)
                                border.color: isOverridden ? Theme.warning : Theme.success
                                Text {
                                    id: inhTxt
                                    anchors.centerIn: parent
                                    text: isOverridden ? "User Override" : "NixOS Default"
                                    color: isOverridden ? Theme.warning : Theme.success
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.fontSizeLabel - 1
                                }
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: currentAppId
                                color: Theme.textDim
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fontSizeSmall - 1
                            }
                        }

                        Flow {
                            Layout.fillWidth: true
                            spacing: 6

                            Repeater {
                                model: modelData.options
                                delegate: Rectangle {
                                    required property var modelData
                                    readonly property bool isSel: currentAppId === modelData.id
                                    implicitWidth: chRow.implicitWidth + 18
                                    implicitHeight: 28
                                    radius: Theme.radiusSm
                                    color: isSel ? Theme.accentDim : (ch_hh.hovered ? Theme.surfaceHover : Theme.bg)
                                    border.color: isSel ? Theme.accent : Theme.border

                                    RowLayout {
                                        id: chRow
                                        anchors.centerIn: parent
                                        spacing: 5
                                        MaterialIcon {
                                            visible: isSel
                                            iconName: "check"
                                            pixelSize: 13
                                            color: Theme.accent
                                        }
                                        Text {
                                            text: modelData.name
                                            color: isSel ? Theme.text : Theme.textSecondary
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontSizeSmall
                                            font.bold: isSel
                                        }
                                    }
                                    HoverHandler { id: ch_hh; cursorShape: Qt.PointingHandCursor }
                                    TapHandler { onTapped: root.setDefaultApp(parent.parent.parent.modelData.key, modelData.id) }
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: Theme.border
                            opacity: 0.5
                            Layout.topMargin: 2
                            Layout.bottomMargin: 2
                        }
                    }
                }
            }

            // ═════════════════════════════════════════════════════════════════
            // SECTION 2: NIXOS DECLARATIVE PREFERENCES
            // ═════════════════════════════════════════════════════════════════
            MujoCard {
                visible: root.isVisibleCat("nixos")
                title: "NixOS Configuration"
                iconName: "terminal"
                isNixos: true

                // Hostname
                MujoSettingRow {
                    iconName: "dns"
                    title: "System Hostname"
                    description: "Network identity and machine name."
                    isNixos: true

                    TextField {
                        Layout.preferredWidth: 150
                        text: root.nixosPrefs.hostname || "main"
                        onAccepted: root.setNixosPref("hostname", text.trim() || "main")
                    }
                }

                // Timezone
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    MujoSettingRow {
                        iconName: "schedule"
                        title: "System Timezone"
                        description: "Local time zone resolution for clock and scheduler."
                        isNixos: true
                    }

                    Flow {
                        Layout.fillWidth: true
                        Layout.leftMargin: 8
                        spacing: 6

                        Repeater {
                            model: ["Europe/Berlin", "UTC", "America/New_York", "Asia/Tokyo", "Europe/London", "Asia/Singapore"]
                            delegate: DisplayChip {
                                required property var modelData
                                label: modelData
                                selected: (root.nixosPrefs.timezone || "Europe/Berlin") === modelData
                                onClicked: root.setNixosPref("timezone", modelData)
                            }
                        }
                    }
                }

                // Locale
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    MujoSettingRow {
                        iconName: "translate"
                        title: "Default System Locale"
                        description: "Language, numeric formatting, and character encoding."
                        isNixos: true
                    }

                    Flow {
                        Layout.fillWidth: true
                        Layout.leftMargin: 8
                        spacing: 6

                        Repeater {
                            model: ["en_US.UTF-8", "en_GB.UTF-8", "de_DE.UTF-8", "uk_UA.UTF-8", "fr_FR.UTF-8"]
                            delegate: DisplayChip {
                                required property var modelData
                                label: modelData
                                selected: (root.nixosPrefs.locale || "en_US.UTF-8") === modelData
                                onClicked: root.setNixosPref("locale", modelData)
                            }
                        }
                    }
                }

                // Nix Store Auto Optimisation
                MujoSettingRow {
                    iconName: "auto_fix_high"
                    title: "Automatic Store Optimisation"
                    description: "Deduplicate identical files in /nix/store via hardlinks during builds."
                    isNixos: true

                    ToggleSwitch {
                        checked: root.nixosPrefs.autoOptimiseStore !== false
                        onToggled: function(c) { root.setNixosPref("autoOptimiseStore", c) }
                    }
                }
            }

            // ═════════════════════════════════════════════════════════════════
            // SECTION 3: CLIPBOARD HISTORY
            // ═════════════════════════════════════════════════════════════════
            MujoCard {
                visible: root.isVisibleCat("clipboard")
                title: "Clipboard History"
                iconName: "content_paste"
                badgeText: "cliphist"
                badgeColor: Theme.accent

                MujoSettingRow {
                    iconName: "history"
                    title: "Clipboard History Tracking"
                    description: "Record copied text into local buffer for quick search and pasting."

                    ToggleSwitch {
                        checked: root.bget("clipboard.enabled", true)
                        onToggled: function(c) { root.bset("clipboard.enabled", c) }
                    }
                }

                // History limit
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    MujoSettingRow {
                        iconName: "format_list_numbered"
                        title: "History Retention Limit"
                        description: "Maximum number of clips stored in history buffer."
                    }

                    Flow {
                        Layout.fillWidth: true
                        Layout.leftMargin: 8
                        spacing: 6

                        Repeater {
                            model: [
                                { v: 50, l: "50 clips" },
                                { v: 100, l: "100 clips" },
                                { v: 250, l: "250 clips" },
                                { v: 500, l: "500 clips" },
                                { v: 1000, l: "1000 clips" }
                            ]
                            delegate: DisplayChip {
                                required property var modelData
                                label: modelData.l
                                selected: root.bget("clipboard.maxItems", 100) === modelData.v
                                onClicked: root.bset("clipboard.maxItems", modelData.v)
                            }
                        }
                    }
                }

                MujoSettingRow {
                    iconName: "password"
                    title: "Filter Sensitive Content"
                    description: "Automatically omit credentials copied from password managers."

                    ToggleSwitch {
                        checked: root.bget("clipboard.filterSensitive", true)
                        onToggled: function(c) { root.bset("clipboard.filterSensitive", c) }
                    }
                }

                MujoSettingRow {
                    iconName: "image"
                    title: "Store Images in History"
                    description: "Capture copied image screenshots and bitmaps."

                    ToggleSwitch {
                        checked: root.bget("clipboard.storeImages", true)
                        onToggled: function(c) { root.bset("clipboard.storeImages", c) }
                    }
                }

                // Wipe buffer
                MujoSettingRow {
                    iconName: "delete_sweep"
                    title: "Buffer: " + root.clipCount + " clips"
                    description: root.clipClearMessage !== "" ? root.clipClearMessage : "Permanently clear all recorded clipboard history."

                    DialogButton {
                        text: "Clear History"
                        onClicked: {
                            Quickshell.execDetached(["mujo", "clipboard", "clear"])
                            root.clipCount = 0
                            root.clipClearMessage = "History wiped."
                            clipProc.running = true
                        }
                    }
                }
            }

            // ═════════════════════════════════════════════════════════════════
            // SECTION 4: PRIVACY & PERMISSIONS
            // ═════════════════════════════════════════════════════════════════
            MujoCard {
                visible: root.isVisibleCat("privacy")
                title: "Privacy & Permissions"
                iconName: "shield"
                badgeText: "Isolated"
                badgeColor: Theme.accent

                MujoSettingRow {
                    iconName: "do_not_disturb_on"
                    title: "Global Telemetry Opt-Out"
                    description: "Set DO_NOT_TRACK=1 and DOTNET_CLI_TELEMETRY_OPTOUT=1 environment flags."

                    ToggleSwitch {
                        checked: root.bget("privacy.telemetryOptOut", true)
                        onToggled: function(c) { root.bset("privacy.telemetryOptOut", c) }
                    }
                }

                MujoSettingRow {
                    iconName: "history_toggle_off"
                    title: "Recent Files Tracking"
                    description: "Maintain list of recently opened files in desktop choosers."

                    ToggleSwitch {
                        checked: root.bget("privacy.recentFiles", true)
                        onToggled: function(c) { root.bset("privacy.recentFiles", c) }
                    }
                }

                MujoSettingRow {
                    iconName: "location_on"
                    title: "Location Access & GeoIP"
                    description: "Allow weather widget to resolve location via network IP."

                    ToggleSwitch {
                        checked: root.bget("privacy.locationAccess", true)
                        onToggled: function(c) { root.bset("privacy.locationAccess", c) }
                    }
                }

                MujoSettingRow {
                    iconName: "screen_share"
                    title: "Screen Sharing Protection"
                    description: "Prompt for approval whenever an app requests portal screencast."

                    ToggleSwitch {
                        checked: root.bget("privacy.screencastProtection", true)
                        onToggled: function(c) { root.bset("privacy.screencastProtection", c) }
                    }
                }

                MujoSettingRow {
                    iconName: "folder_delete"
                    title: "Recent Files Buffer"
                    description: root.privacyClearMessage !== "" ? root.privacyClearMessage : "Wipe GTK recently-used files history list."

                    DialogButton {
                        text: "Clear Recent"
                        onClicked: {
                            Quickshell.execDetached(["mujo", "privacy", "clear-recent"])
                            root.privacyClearMessage = "Recent files cleared."
                        }
                    }
                }
            }

            // ═════════════════════════════════════════════════════════════════
            // SECTION 5: SECURITY & ACCESS
            // ═════════════════════════════════════════════════════════════════
            MujoCard {
                visible: root.isVisibleCat("security")
                title: "Security & Firewall"
                iconName: "lock"
                badgeText: "Hardened"
                badgeColor: Theme.accent

                MujoSettingRow {
                    iconName: "security"
                    title: "NixOS Kernel Firewall"
                    description: "Enforce packet filtering (nftables) for incoming traffic."
                    isNixos: true

                    ToggleSwitch {
                        checked: (root.nixosPrefs.firewall && root.nixosPrefs.firewall.enable !== false)
                        onToggled: function(c) { root.setNixosPref("firewall.enable", c) }
                    }
                }

                MujoSettingRow {
                    iconName: "terminal"
                    title: "OpenSSH Remote Daemon"
                    description: "Allow incoming remote SSH shell access to this machine."
                    isNixos: true

                    ToggleSwitch {
                        checked: !!(root.nixosPrefs.ssh && root.nixosPrefs.ssh.enable)
                        onToggled: function(c) { root.setNixosPref("ssh.enable", c) }
                    }
                }

                MujoSettingRow {
                    iconName: "lock_clock"
                    title: "Lock Screen on Suspend / Sleep"
                    description: "Require authentication immediately upon waking."

                    ToggleSwitch {
                        checked: root.bget("security.lockOnSuspend", true)
                        onToggled: function(c) { root.bset("security.lockOnSuspend", c) }
                    }
                }

                // Grace Period
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    MujoSettingRow {
                        iconName: "timer"
                        title: "Lock Screen Grace Period"
                        description: "Delay before password authentication is strictly enforced."
                    }

                    Flow {
                        Layout.fillWidth: true
                        Layout.leftMargin: 8
                        spacing: 6

                        Repeater {
                            model: [
                                { v: 0, l: "Immediate (0s)" },
                                { v: 5, l: "5s" },
                                { v: 15, l: "15s" },
                                { v: 30, l: "30s" },
                                { v: 60, l: "1m" }
                            ]
                            delegate: DisplayChip {
                                required property var modelData
                                label: modelData.l
                                selected: root.bget("security.lockGraceSec", 0) === modelData.v
                                onClicked: root.bset("security.lockGraceSec", modelData.v)
                            }
                        }
                    }
                }
            }

            // ═════════════════════════════════════════════════════════════════
            // SECTION 6: SYSTEM BEHAVIOR & POWER
            // ═════════════════════════════════════════════════════════════════
            MujoCard {
                visible: root.isVisibleCat("behavior")
                title: "System Behavior & Power"
                iconName: "settings_suggest"
                badgeText: "Runtime"
                badgeColor: Theme.accent

                // Power Profiles
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    MujoSettingRow {
                        iconName: "bolt"
                        title: "Power Management Profile"
                        description: "Tune hardware CPU governor and thermal throttle policies."
                    }

                    Flow {
                        Layout.fillWidth: true
                        Layout.leftMargin: 8
                        spacing: 6

                        Repeater {
                            model: [
                                { id: "performance", label: "Performance", icon: "bolt" },
                                { id: "balanced",    label: "Balanced",    icon: "balance" },
                                { id: "power-saver", label: "Power Saver", icon: "eco" }
                            ]
                            delegate: DisplayChip {
                                required property var modelData
                                label: modelData.label
                                selected: root.powerProfile === modelData.id
                                onClicked: {
                                    root.powerProfile = modelData.id
                                    root.bset("system.powerProfile", modelData.id)
                                    Quickshell.execDetached(["mujo", "power-profile", "set", modelData.id])
                                }
                            }
                        }
                    }
                }

                MujoSettingRow {
                    iconName: "memory"
                    title: "ZRAM Compressed Swap"
                    description: "In-memory swap device (50% RAM quota) with priority 5."
                    isNixos: true

                    ToggleSwitch {
                        checked: (root.nixosPrefs.zramSwap && root.nixosPrefs.zramSwap.enable !== false)
                        onToggled: function(c) { root.setNixosPref("zramSwap.enable", c) }
                    }
                }

                MujoSettingRow {
                    iconName: "volume_up"
                    title: "Notification Audio Alerts"
                    description: "Play auditory cues for high-priority desktop toasts."

                    ToggleSwitch {
                        checked: root.bget("system.soundAlerts", true)
                        onToggled: function(c) { root.bset("system.soundAlerts", c) }
                    }
                }
            }

            Item { implicitHeight: 14 }
        }
    }
}
