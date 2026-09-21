import QtQuick
import QtQuick.Layouts
import "../../theme"
import "../../components"
import "../../services"
import "../bar"

// Top Bar Layout, Geometry, 3-Zone Slots Canvas Builder, and Widget Styles Group.
ColumnLayout {
    id: root
    Layout.fillWidth: true
    spacing: 14

    property string selectedBarWidget: "workspaces"
    property string selectedZone: "left" // "left" | "center" | "right"

    // ── 3-Zone Slots Models ──
    readonly property var leftModules: SettingsBus.get("bar.slots.left", ["launcher", "workspaces", "activeWindow"])
    readonly property var centerModules: SettingsBus.get("bar.slots.center", ["clock", "weather"])
    readonly property var rightModules: SettingsBus.get("bar.slots.right", ["llm", "network", "bluetooth", "volume", "battery", "notifications", "tray", "session"])
    readonly property var allActiveModules: [].concat(leftModules, centerModules, rightModules)

    function setLeftModules(arr) { SettingsBus.set("bar.slots.left", arr) }
    function setCenterModules(arr) { SettingsBus.set("bar.slots.center", arr) }
    function setRightModules(arr) { SettingsBus.set("bar.slots.right", arr) }

    function getZoneModules(zone) {
        if (zone === "left") return root.leftModules
        if (zone === "center") return root.centerModules
        if (zone === "right") return root.rightModules
        return []
    }

    function setZoneModules(zone, arr) {
        if (zone === "left") setLeftModules(arr)
        else if (zone === "center") setCenterModules(arr)
        else if (zone === "right") setRightModules(arr)
    }

    function removeModuleFromZone(zone, idx) {
        var a = getZoneModules(zone).slice()
        if (idx >= 0 && idx < a.length) {
            a.splice(idx, 1)
            setZoneModules(zone, a)
        }
    }

    function addModuleToZone(zone, modId) {
        var a = getZoneModules(zone).slice()
        if (modId === "divider" || modId === "spacer" || a.indexOf(modId) < 0) {
            a.push(modId)
            setZoneModules(zone, a)
        }
    }

    function applyLayoutPreset(presetId) {
        if (presetId === "default") {
            setLeftModules(["launcher", "workspaces", "activeWindow"])
            setCenterModules(["clock", "weather"])
            setRightModules(["llm", "network", "bluetooth", "volume", "battery", "notifications", "tray", "session"])
        } else if (presetId === "media") {
            setLeftModules(["workspaces", "activeWindow"])
            setCenterModules(["media", "cava", "clock"])
            setRightModules(["volume", "battery", "network", "session"])
        } else if (presetId === "dock") {
            setLeftModules([])
            setCenterModules(["launcher", "workspaces", "clock", "volume", "battery"])
            setRightModules([])
        } else if (presetId === "classic") {
            setLeftModules(["launcher", "workspaces", "activeWindow"])
            setCenterModules([])
            setRightModules(["tray", "network", "bluetooth", "volume", "battery", "clock", "session"])
        }
    }


    // ── 1. Top Bar Layout & Geometry Card ─────────────────────────────────────
    MujoCard {
        title: "Desktop Bar Layout & Geometry"
        iconName: "dock_to_bottom"
        badgeText: SettingsBus.get("bar.style", "floating").toUpperCase()
        badgeColor: Theme.accent

        MujoSettingRow {
            iconName: "style"
            title: "Bar Style Presentation"
            description: "Select desktop bar layout mode (Floating, Full-Width, Island, Dock, Compact)."

            MujoSegmented {
                model: [
                    { id: "floating", label: "Floating" },
                    { id: "full",     label: "Full-Width" },
                    { id: "island",   label: "Island" },
                    { id: "dock",     label: "Dock" },
                    { id: "compact",  label: "Compact" }
                ]
                current: SettingsBus.get("bar.style", "floating")
                onSelected: function(id) { SettingsBus.set("bar.style", id) }
            }
        }

        MujoSettingRow {
            iconName: "vertical_align_top"
            title: "Screen Position"
            description: "Attach the floating bar to the top or bottom edge of the screen."

            MujoSegmented {
                model: [
                    { id: "top", label: "Top" },
                    { id: "bottom", label: "Bottom" }
                ]
                current: SettingsBus.get("bar.position", "top")
                onSelected: function(id) { SettingsBus.set("bar.position", id) }
            }
        }

        MujoSettingRow {
            iconName: "density_medium"
            title: "Bar Element Density"
            description: "Padding inside every bar control and group. Auto follows bar height."

            MujoSegmented {
                model: [
                    { id: "auto",    label: "Auto" },
                    { id: "normal",  label: "Normal" },
                    { id: "compact", label: "Compact" },
                    { id: "dense",   label: "Dense" }
                ]
                current: SettingsBus.get("bar.density", "auto")
                onSelected: function(id) { SettingsBus.set("bar.density", id) }
            }
        }

        SettingRow {
            path: "bar.height"
            def: 34
            kind: "slider"
            from: 24
            to: 56
            format: "px"
            iconName: "height"
            title: "Bar Height"
            description: "Vertical content height of the bar pill clusters."
        }

        SettingRow {
            path: "bar.margin"
            def: 7
            kind: "slider"
            from: 0
            to: 20
            format: "px"
            iconName: "margin"
            title: "Screen Edge Margin"
            description: "Distance between the outer screen edge and the floating bar."
        }

        SettingRow {
            path: "bar.spacing"
            def: 6
            kind: "slider"
            from: 0
            to: 16
            format: "px"
            iconName: "space_bar"
            title: "Cluster Gap Spacing"
            description: "Separation between pill groups in the bar."
        }

        SettingRow {
            path: "bar.opacity"
            def: 1
            kind: "slider"
            from: 0.3
            to: 1
            roundValue: false
            format: "%"
            valueText: (Number(SettingsBus.get("bar.opacity", 1)) * 100).toFixed(0) + "%"
            iconName: "opacity"
            title: "Bar Surface Opacity"
            description: "Translucency level of the floating bar pill background."
        }

        SettingRow {
            path: "bar.autoHide"
            def: false
            kind: "toggle"
            iconName: "visibility_off"
            title: "Intelligent Auto-Hide"
            description: "Automatically slide the bar away when windows approach the edge."
        }

        SettingRow {
            path: "bar.scrollActions"
            def: true
            kind: "toggle"
            iconName: "mouse"
            title: "Scroll Actions"
            description: "Change volume or switch workspaces by scrolling over bar pills."
        }

        SettingRow {
            path: "bar.trayRecolour"
            def: false
            kind: "toggle"
            iconName: "format_color_fill"
            title: "Recolor System Tray Icons"
            description: "Apply active theme color palette to monochrome tray icons."
        }

        MujoSettingRow {
            iconName: "keyboard_arrow_up"
            title: "Collapse All Tray Icons"
            description: "Keep the bar minimal by placing all tray icons inside the flyout."

            ToggleSwitch {
                checked: SettingsBus.get("bar.trayInlineCount", 0) === 0
                onToggled: function(c) { SettingsBus.set("bar.trayInlineCount", c ? 0 : 6) }
            }
        }
    }

    // ── 2. 3-Zone Slot Canvas Builder Card ────────────────────────────────────
    MujoCard {
        title: "3-Zone Slot Canvas Builder"
        iconName: "reorder"
        badgeText: root.allActiveModules.length + " ACTIVE"

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 12

            Text {
                Layout.fillWidth: true
                text: "Design your desktop topbar by assigning and ordering modules across Left, Center, and Right zones. Reorder with drag or arrow keys, remove with ✕, or pick from available modules below."
                color: Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                wrapMode: Text.WordWrap
            }

            // Quick Layout Presets
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6

                Text {
                    text: "LAYOUT PRESETS"
                    color: Theme.textDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeLabel
                    font.bold: true
                }

                Flow {
                    Layout.fillWidth: true
                    spacing: 8

                    DisplayChip {
                        label: "Default Mujō"
                        onClicked: root.applyLayoutPreset("default")
                    }

                    DisplayChip {
                        label: "Media Hub"
                        onClicked: root.applyLayoutPreset("media")
                    }

                    DisplayChip {
                        label: "Minimalist Dock"
                        onClicked: root.applyLayoutPreset("dock")
                    }

                    DisplayChip {
                        label: "Classic Desktop"
                        onClicked: root.applyLayoutPreset("classic")
                    }
                }
            }

            // Zone Switcher / Visual Canvas Mini Bar Preview
            InsetPanel {
                Layout.fillWidth: true
                implicitHeight: 48

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 6
                    spacing: 8

                    // Left Zone Mini Pill
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: Theme.radiusSm
                        color: root.selectedZone === "left" ? Theme.surfaceActive : Theme.surface
                        border.color: root.selectedZone === "left" ? Theme.accent : Theme.border
                        border.width: root.selectedZone === "left" ? 1.5 : 1

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 4
                            MaterialIcon {
                                iconName: "align_horizontal_left"
                                pixelSize: 14
                                color: root.selectedZone === "left" ? Theme.accent : Theme.textSecondary
                            }
                            Text {
                                text: "Left (" + root.leftModules.length + ")"
                                color: root.selectedZone === "left" ? Theme.accent : Theme.textSecondary
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSmall
                                font.bold: root.selectedZone === "left"
                            }
                        }

                        TapHandler { onTapped: root.selectedZone = "left" }
                    }

                    // Center Zone Mini Pill
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: Theme.radiusSm
                        color: root.selectedZone === "center" ? Theme.surfaceActive : Theme.surface
                        border.color: root.selectedZone === "center" ? Theme.accent : Theme.border
                        border.width: root.selectedZone === "center" ? 1.5 : 1

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 4
                            MaterialIcon {
                                iconName: "align_horizontal_center"
                                pixelSize: 14
                                color: root.selectedZone === "center" ? Theme.accent : Theme.textSecondary
                            }
                            Text {
                                text: "Center (" + root.centerModules.length + ")"
                                color: root.selectedZone === "center" ? Theme.accent : Theme.textSecondary
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSmall
                                font.bold: root.selectedZone === "center"
                            }
                        }

                        TapHandler { onTapped: root.selectedZone = "center" }
                    }

                    // Right Zone Mini Pill
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: Theme.radiusSm
                        color: root.selectedZone === "right" ? Theme.surfaceActive : Theme.surface
                        border.color: root.selectedZone === "right" ? Theme.accent : Theme.border
                        border.width: root.selectedZone === "right" ? 1.5 : 1

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 4
                            MaterialIcon {
                                iconName: "align_horizontal_right"
                                pixelSize: 14
                                color: root.selectedZone === "right" ? Theme.accent : Theme.textSecondary
                            }
                            Text {
                                text: "Right (" + root.rightModules.length + ")"
                                color: root.selectedZone === "right" ? Theme.accent : Theme.textSecondary
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSmall
                                font.bold: root.selectedZone === "right"
                            }
                        }

                        TapHandler { onTapped: root.selectedZone = "right" }
                    }
                }
            }

            // Zone Reorder List
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: root.selectedZone === "left" ? "LEFT ZONE MODULES" : root.selectedZone === "center" ? "CENTER ZONE MODULES" : "RIGHT ZONE MODULES"
                    color: Theme.textDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeLabel
                    font.bold: true
                }

                InsetPanel {
                    visible: root.getZoneModules(root.selectedZone).length === 0
                    Layout.fillWidth: true
                    implicitHeight: 52

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 8
                        MaterialIcon {
                            iconName: "info"
                            pixelSize: 16
                            color: Theme.textDim
                        }
                        Text {
                            text: "Nothing in this zone yet. Add a module from the pool below."
                            color: Theme.textSecondary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                        }
                    }
                }

                MujoReorderList {
                    visible: root.getZoneModules(root.selectedZone).length > 0
                    model: root.getZoneModules(root.selectedZone)
                    formatter: function(id) { return BarModuleRegistry.metadata(id).name }
                    iconResolver: function(id) { return BarModuleRegistry.metadata(id).icon }
                    badgeResolver: function(id) { return BarModuleRegistry.metadata(id).category.toUpperCase() }
                    onReordered: function(newModel) { root.setZoneModules(root.selectedZone, newModel) }
                    onItemRemoved: function(index, item) { root.removeModuleFromZone(root.selectedZone, index) }
                }
            }

            // Available Modules Pool to Add
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: "+ ADD MODULE TO " + (root.selectedZone === "left" ? "LEFT" : root.selectedZone === "center" ? "CENTER" : "RIGHT") + " ZONE"
                    color: Theme.textDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeLabel
                    font.bold: true
                }

                Flow {
                    Layout.fillWidth: true
                    spacing: 6

                    Repeater {
                        model: BarModuleRegistry.allModules
                        delegate: DisplayChip {
                            required property var modelData
                            visible: modelData.id === "divider" || modelData.id === "spacer" || root.allActiveModules.indexOf(modelData.id) < 0
                            label: "+ " + modelData.name
                            onClicked: root.addModuleToZone(root.selectedZone, modelData.id)
                        }
                    }
                }
            }
        }
    }

    // ── 3. Bar Widget Style Customizer Card ───────────────────────────────────
    MujoCard {
        title: "Bar Widget Style Customizer"
        iconName: "tune"

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 12

            MujoFlickable {
                Layout.fillWidth: true
                Layout.preferredHeight: 38
                contentWidth: barWidgetsRow.implicitWidth + 24
                flickableDirection: Flickable.HorizontalFlick

                RowLayout {
                    id: barWidgetsRow
                    spacing: 6
                    Repeater {
                        model: [
                            { id: "workspaces",   label: "Workspaces",    icon: "view_carousel" },
                            { id: "clock",        label: "Clock",         icon: "schedule" },
                            { id: "launcher",     label: "Launcher",      icon: "category" },
                            { id: "activeWindow", label: "Active Window", icon: "tab" },
                            { id: "media",        label: "Media",         icon: "play_circle" },
                            { id: "weather",      label: "Weather",       icon: "wb_sunny" },
                            { id: "volume",       label: "Volume",        icon: "volume_up" },
                            { id: "battery",      label: "Battery",       icon: "battery_full" },
                            { id: "network",      label: "Network",       icon: "wifi" },
                            { id: "bluetooth",    label: "Bluetooth",     icon: "bluetooth" },
                            { id: "notifications",label: "Notifications", icon: "notifications" },
                            { id: "llm",          label: "AI Tokens",     icon: "psychology" },
                            { id: "session",      label: "Session",       icon: "power_settings_new" }
                        ]
                        delegate: DisplayChip {
                            required property var modelData
                            label: modelData.label
                            selected: root.selectedBarWidget === modelData.id
                            onClicked: root.selectedBarWidget = modelData.id
                        }
                    }
                }
            }

            // ── Workspaces Settings ──
            ColumnLayout {
                visible: root.selectedBarWidget === "workspaces"
                Layout.fillWidth: true
                spacing: 10

                MujoSettingRow {
                    iconName: "format_list_numbered"
                    title: "Workspace Numeral Style"
                    description: "Format used to label workspace items in the pill."
                    MujoSegmented {
                        model: [
                            { id: "numbers", label: "1 2 3" },
                            { id: "dots",    label: "Dots (•)" },
                            { id: "roman",   label: "Roman (I II)" },
                            { id: "kanji",   label: "Kanji (一 二)" }
                        ]
                        current: SettingsBus.get("bar.workspaces.style", "numbers")
                        onSelected: function(id) { SettingsBus.set("bar.workspaces.style", id) }
                    }
                }

                MujoSettingRow {
                    iconName: "animation"
                    title: "Glider Focus Indicator"
                    description: "Visual animation style behind the currently active workspace."
                    MujoSegmented {
                        model: [
                            { id: "morphic", label: "Morphic" },
                            { id: "pill",    label: "Pill" },
                            { id: "line",    label: "Line" },
                            { id: "glow",    label: "Glow" }
                        ]
                        current: SettingsBus.get("bar.workspaces.gliderStyle", "morphic")
                        onSelected: function(id) { SettingsBus.set("bar.workspaces.gliderStyle", id) }
                    }
                }

                SettingRow {
                    path: "bar.workspaces.showWindowDots"
                    def: true
                    kind: "toggle"
                    iconName: "lens"
                    title: "Show Window Presence Dots"
                    description: "Display subtle micro-dot on workspaces containing open windows."
                }

                SettingRow {
                    path: "bar.workspaces.hideEmpty"
                    def: false
                    kind: "toggle"
                    iconName: "visibility_off"
                    title: "Hide Empty Workspaces"
                    description: "Only show workspaces that contain open windows or are focused."
                }
            }

            // ── Clock Settings ──
            ColumnLayout {
                visible: root.selectedBarWidget === "clock"
                Layout.fillWidth: true
                spacing: 10

                SettingRow {
                    path: "bar.clock.format24"
                    def: true
                    kind: "toggle"
                    iconName: "schedule"
                    title: "24-Hour Time Format"
                    description: "Display time as 24-hour clock (14:30) instead of 12-hour AM/PM."
                }

                SettingRow {
                    path: "bar.clock.showSeconds"
                    def: false
                    kind: "toggle"
                    iconName: "timer"
                    title: "Show Live Seconds"
                    description: "Render live seconds in the top bar clock pill."
                }

                SettingRow {
                    path: "bar.clock.showDate"
                    def: true
                    kind: "toggle"
                    iconName: "calendar_today"
                    title: "Show Date in Bar"
                    description: "Display date alongside clock numerals."
                }

                MujoSettingRow {
                    iconName: "short_text"
                    title: "Date Format Pattern"
                    description: "Date string representation in the pill."
                    MujoSegmented {
                        model: [
                            { id: "short",  label: "Thu, Aug 28" },
                            { id: "medium", label: "8/28" },
                            { id: "iso",    label: "2026-08-28" }
                        ]
                        current: SettingsBus.get("bar.clock.dateFormat", "short")
                        onSelected: function(id) { SettingsBus.set("bar.clock.dateFormat", id) }
                    }
                }

                SettingRow {
                    path: "bar.clock.fontMono"
                    def: true
                    kind: "toggle"
                    iconName: "code"
                    title: "Monospace Typography"
                    description: "Use fixed-width numerals to prevent pill jitter during second ticks."
                }

                SettingRow {
                    path: "bar.clock.bold"
                    def: false
                    kind: "toggle"
                    iconName: "format_bold"
                    title: "Bold Numerals"
                    description: "Emphasize clock text with heavier font weight."
                }

                SettingRow {
                    path: "bar.clock.showIcon"
                    def: false
                    kind: "toggle"
                    iconName: "schedule"
                    title: "Show Clock Icon"
                    description: "Prepend a clock glyph inside the pill."
                }
            }

            // ── Launcher Settings ──
            ColumnLayout {
                visible: root.selectedBarWidget === "launcher"
                Layout.fillWidth: true
                spacing: 10

                MujoSettingRow {
                    iconName: "category"
                    title: "Launcher Icon Style"
                    description: "Visual emblem used for the main menu and launcher trigger button."
                    MujoSegmented {
                        model: [
                            { id: "search", label: "Search" },
                            { id: "grid",   label: "Grid" },
                            { id: "nixos",  label: "NixOS" },
                            { id: "mujo",   label: "Mujō" }
                        ]
                        current: SettingsBus.get("bar.launcher.icon", "search")
                        onSelected: function(id) { SettingsBus.set("bar.launcher.icon", id) }
                    }
                }

                SettingRow {
                    path: "bar.launcher.showLabel"
                    def: false
                    kind: "toggle"
                    iconName: "label"
                    title: "Show Text Label"
                    description: "Display an explicit text label next to the launcher icon."
                }

                SettingRow {
                    path: "bar.launcher.label"
                    def: "Apps"
                    kind: "text"
                    placeholder: "Apps"
                    iconName: "edit"
                    title: "Custom Label Text"
                    description: "Text shown inside launcher button pill."
                }
            }

            // ── Active Window Settings ──
            ColumnLayout {
                visible: root.selectedBarWidget === "activeWindow"
                Layout.fillWidth: true
                spacing: 10

                SettingRow {
                    path: "bar.activeWindow.showIcon"
                    def: true
                    kind: "toggle"
                    iconName: "image"
                    title: "Show Application Icon"
                    description: "Render high-DPI desktop app icon in active window pill."
                }

                SettingRow {
                    path: "bar.activeWindow.showTitle"
                    def: true
                    kind: "toggle"
                    iconName: "title"
                    title: "Show Window Title"
                    description: "Render active window title string."
                }

                SettingRow {
                    path: "bar.activeWindow.maxWidth"
                    def: 190
                    kind: "slider"
                    from: 80
                    to: 400
                    format: "px"
                    iconName: "straighten"
                    title: "Maximum Title Width"
                    description: "Elide long window titles when exceeding this pixel boundary."
                }

                MujoSettingRow {
                    iconName: "style"
                    title: "Active Window Pill Style"
                    description: "Background surface styling."
                    MujoSegmented {
                        model: [
                            { id: "pill",  label: "Pill" },
                            { id: "glass", label: "Glass" },
                            { id: "plain", label: "Plain" }
                        ]
                        current: SettingsBus.get("bar.activeWindow.style", "pill")
                        onSelected: function(id) { SettingsBus.set("bar.activeWindow.style", id) }
                    }
                }
            }

            // ── Media Settings ──
            ColumnLayout {
                visible: root.selectedBarWidget === "media"
                Layout.fillWidth: true
                spacing: 10

                SettingRow {
                    path: "bar.media.showControls"
                    def: true
                    kind: "toggle"
                    iconName: "play_circle"
                    title: "Show Playback Controls"
                    description: "Display play/pause and skip action buttons in the media pill."
                }

                SettingRow {
                    path: "bar.media.maxWidth"
                    def: 180
                    kind: "slider"
                    from: 80
                    to: 350
                    format: "px"
                    iconName: "straighten"
                    title: "Maximum Title Width"
                    description: "Elide track title and artist name when exceeding this limit."
                }
            }

            // ── Weather Settings ──
            ColumnLayout {
                visible: root.selectedBarWidget === "weather"
                Layout.fillWidth: true
                spacing: 10

                SettingRow {
                    path: "bar.weather.showIcon"
                    def: true
                    kind: "toggle"
                    iconName: "wb_sunny"
                    title: "Show Condition Glyph"
                    description: "Render weather icon next to temperature."
                }

                SettingRow {
                    path: "bar.weather.showCity"
                    def: false
                    kind: "toggle"
                    iconName: "location_city"
                    title: "Show City Name"
                    description: "Display localized city name inside the weather pill."
                }
            }

            // ── Volume & Battery Settings ──
            ColumnLayout {
                visible: root.selectedBarWidget === "volume"
                Layout.fillWidth: true
                spacing: 10

                SettingRow {
                    path: "bar.volume.showPercent"
                    def: false
                    kind: "toggle"
                    iconName: "percent"
                    title: "Show Numeric Percentage"
                    description: "Display exact volume percentage next to speaker icon."
                }

                SettingRow {
                    path: "bar.volume.step"
                    def: 5
                    kind: "slider"
                    from: 1
                    to: 10
                    format: "%"
                    iconName: "exposure"
                    title: "Volume Step Increment"
                    description: "Volume percentage adjusted per mouse wheel scroll."
                }
            }

            ColumnLayout {
                visible: root.selectedBarWidget === "battery"
                Layout.fillWidth: true
                spacing: 10

                MujoSettingRow {
                    iconName: "battery_charging_full"
                    title: "Battery Percentage Mode"
                    description: "When to render the numeric battery charge percentage."
                    MujoSegmented {
                        model: [
                            { id: "always",   label: "Always" },
                            { id: "charging", label: "Charging" },
                            { id: "low",      label: "Low" },
                            { id: "never",    label: "Never" }
                        ]
                        current: SettingsBus.get("bar.battery.showPercent", "charging")
                        onSelected: function(id) { SettingsBus.set("bar.battery.showPercent", id) }
                    }
                }

                SettingRow {
                    path: "bar.battery.lowThreshold"
                    def: 20
                    kind: "slider"
                    from: 10
                    to: 50
                    format: "%"
                    iconName: "battery_alert"
                    title: "Low Battery Threshold"
                    description: "Percentage that triggers low battery warning tint."
                }
            }

            // ── Network & Bluetooth & Notifications & LLM & Session ──
            ColumnLayout {
                visible: root.selectedBarWidget === "network"
                Layout.fillWidth: true
                spacing: 10

                SettingRow {
                    path: "bar.network.showSsid"
                    def: false
                    kind: "toggle"
                    iconName: "wifi"
                    title: "Show Wi-Fi SSID"
                    description: "Render active wireless network name directly in the pill."
                }
            }

            ColumnLayout {
                visible: root.selectedBarWidget === "bluetooth"
                Layout.fillWidth: true
                spacing: 10

                SettingRow {
                    path: "bar.bluetooth.showDevice"
                    def: false
                    kind: "toggle"
                    iconName: "bluetooth"
                    title: "Show Connected Bluetooth Device"
                    description: "Display primary Bluetooth accessory name in bar."
                }
            }

            ColumnLayout {
                visible: root.selectedBarWidget === "notifications"
                Layout.fillWidth: true
                spacing: 10

                SettingRow {
                    path: "bar.notifications.showCount"
                    def: true
                    kind: "toggle"
                    iconName: "mark_chat_unread"
                    title: "Show Unread Count Badge"
                    description: "Render numerical badge for unread notification alerts."
                }
            }

            ColumnLayout {
                visible: root.selectedBarWidget === "llm"
                Layout.fillWidth: true
                spacing: 10

                SettingRow {
                    path: "bar.llm.showTokens"
                    def: false
                    kind: "toggle"
                    iconName: "token"
                    title: "Show Active Token Count"
                    description: "Display estimated context tokens consumed by active agent."
                }
            }

            ColumnLayout {
                visible: root.selectedBarWidget === "session"
                Layout.fillWidth: true
                spacing: 10

                MujoSettingRow {
                    iconName: "power_settings_new"
                    title: "Session Button Icon Style"
                    description: "Visual emblem for power and lock menu."
                    MujoSegmented {
                        model: [
                            { id: "power",  label: "Power" },
                            { id: "lock",   label: "Lock" },
                            { id: "avatar", label: "Avatar" }
                        ]
                        current: SettingsBus.get("bar.session.iconStyle", "power")
                        onSelected: function(id) { SettingsBus.set("bar.session.iconStyle", id) }
                    }
                }
            }
        }
    }
}
