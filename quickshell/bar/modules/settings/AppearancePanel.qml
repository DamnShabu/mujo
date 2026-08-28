import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../theme"
import "../../components"
import "../../services"

// Appearance Settings Panel — Mujo (無常).
// Color theme presets, accent overrides, surface transparency, and desktop bar layout.
// Every change invokes `mujo theme …` or updates SettingsBus live.
Item {
    id: root

    // Fixed accent suggestions
    readonly property var accentSwatches: [
        "#ff385c", "#e63946", "#ff2a4b", "#e95678", "#ee6d85", "#f07178", "#f38ba8", "#eb6f92",
        "#5cc2ff", "#7aa2f7", "#89b4fa", "#61afef", "#82aaff", "#88c0d0", "#7e9cd8", "#58a6ff", "#268bd2",
        "#03edf9", "#3ddbd9", "#5de4c7", "#a6e3a1", "#a7c080", "#b8bb26", "#00ff9f",
        "#ffe600", "#ffd866", "#f9e2af", "#ffb454", "#fe8019",
        "#bd93f9", "#c4a7e7", "#c792ea", "#e879f9", "#ffffff"
    ]

    property real pendingTransparency: Theme.transparency
    property string selectedBarWidget: "workspaces"

    function runTheme(args) { Quickshell.execDetached(["mujo", "theme"].concat(args)) }

    // bar.rightModules reorder/remove helpers
    readonly property var barModules: SettingsBus.get("bar.rightModules", ["llm", "network", "bluetooth", "volume", "battery", "notifications", "tray", "session"])
    readonly property var barAllModules: ["llm", "network", "bluetooth", "volume", "battery", "notifications", "tray", "session"]

    function barSet(a) { SettingsBus.set("bar.rightModules", a) }
    function barMove(i, d) { var a = barModules.slice(), j = i + d; if (j < 0 || j >= a.length) return; var t = a[i]; a[i] = a[j]; a[j] = t; barSet(a) }
    function barRemove(i) { var a = barModules.slice(); a.splice(i, 1); barSet(a) }
    function barAdd(n) { var a = barModules.slice(); if (a.indexOf(n) < 0) { a.push(n); barSet(a) } }

    Timer {
        id: transparencyDebounce
        interval: 140
        onTriggered: {
            root.runTheme(["transparency", root.pendingTransparency.toFixed(2)])
            // Hand the property back to Theme once the write is away, so an
            // external `mujo theme` still moves this slider.
            root.pendingTransparency = Qt.binding(function () { return Theme.transparency })
        }
    }

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

            // ── Hero Banner ───────────────────────────────────────────────────
            MujoHero {
                brand: "appearance"
                title: "Appearance"
                subtitle: "Theme presets, accent color overrides, surface opacity, and bar configuration."
                badgeText: Theme.presetLabels[Theme.presetName] || Theme.presetName
                badgeColor: Theme.accent
            }

            // ── Theme Presets Card ────────────────────────────────────────────
            MujoCard {
                title: "Theme Presets"
                iconName: "palette"
                badgeText: Theme.presetLabels[Theme.presetName] || Theme.presetName

                // Flow with stretched cards: a fixed 154px card left a ragged
                // ~100px gutter down the right of the section, so the column
                // count comes from 154px as a *minimum* and the cards then
                // share the row evenly.
                Flow {
                    id: presetFlow
                    Layout.fillWidth: true
                    spacing: 10
                    readonly property int cols: Math.max(1, Math.floor((width + spacing) / (154 + spacing)))
                    readonly property real cardW: Math.floor((width - (cols - 1) * spacing) / cols)

                    Repeater {
                        model: Theme.presetOrder
                        delegate: Rectangle {
                            id: card
                            required property var modelData
                            readonly property var pal: Theme.presets[modelData]
                            readonly property bool selected: Theme.presetName === modelData
                            width: presetFlow.cardW
                            height: 88
                            radius: Theme.radiusMd
                            color: pal.surface
                            border.width: selected ? 2 : 1
                            border.color: selected ? Theme.accent : pal.border
                            Behavior on border.color { ColorAnimation { duration: Anim.d(Anim.fast) } }

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 8

                                // Mini palette preview
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 30
                                    radius: Theme.radiusSm
                                    color: card.pal.bg
                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: 6
                                        spacing: 6
                                        Repeater {
                                            model: [card.pal.accent, card.pal.success, card.pal.warning, card.pal.error]
                                            delegate: Rectangle {
                                                required property var modelData
                                                width: 10; height: 10; radius: 5
                                                color: modelData
                                            }
                                        }
                                        Item { Layout.fillWidth: true }
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 6
                                    Text {
                                        Layout.fillWidth: true
                                        text: Theme.presetLabels[card.modelData]
                                        color: card.pal.text
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeSmall
                                        font.bold: card.selected
                                        elide: Text.ElideRight
                                    }
                                    MaterialIcon {
                                        visible: card.selected
                                        iconName: "check_circle"
                                        pixelSize: 15
                                        color: Theme.accent
                                    }
                                }
                            }

                            HoverHandler { id: card_hh; cursorShape: Qt.PointingHandCursor }
                            TapHandler { onTapped: root.runTheme(["set", card.modelData]) }
                            scale: card_hh.hovered && !card.selected ? 1.02 : 1.0
                            Behavior on scale { NumberAnimation { duration: Anim.d(Anim.fast); easing.type: Easing.OutQuad } }
                        }
                    }
                }
            }

            // ── Accent Color & Transparency Card ──────────────────────────────
            MujoCard {
                title: "Accent Color & Surface Opacity"
                iconName: "colorize"

                // Accent swatches
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: "Accent Color Override"
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeBody
                        font.bold: true
                    }

                    Flow {
                        Layout.fillWidth: true
                        spacing: 8

                        // Default preset button
                        Rectangle {
                            implicitWidth: 68; implicitHeight: 28
                            radius: Theme.radiusSm
                            color: Theme.accentOverride === "" ? Theme.accentDim : Theme.bg
                            border.color: Theme.accentOverride === "" ? Theme.accent : Theme.border

                            Text {
                                anchors.centerIn: parent
                                text: "Default"
                                color: Theme.accentOverride === "" ? Theme.accent : Theme.textSecondary
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSmall
                            }
                            HoverHandler { cursorShape: Qt.PointingHandCursor }
                            TapHandler { onTapped: root.runTheme(["accent", ""]) }
                        }

                        Repeater {
                            model: root.accentSwatches
                            delegate: Rectangle {
                                id: swatchItem
                                required property var modelData
                                readonly property bool selected: Theme.accentOverride.toLowerCase() === modelData.toLowerCase()
                                width: 28; height: 28
                                radius: Theme.radiusSm
                                color: modelData
                                border.width: selected ? 2 : 0
                                border.color: Theme.text

                                MaterialIcon {
                                    visible: swatchItem.selected
                                    anchors.centerIn: parent
                                    iconName: "check"
                                    pixelSize: 14
                                    color: Theme.accentText
                                }
                                HoverHandler { id: sw_hh; cursorShape: Qt.PointingHandCursor }
                                TapHandler { onTapped: root.runTheme(["accent", modelData]) }
                                scale: sw_hh.hovered ? 1.12 : 1.0
                                Behavior on scale { NumberAnimation { duration: Anim.d(Anim.fast) } }
                            }
                        }
                    }
                }

                // Surface Opacity Slider
                MujoSettingRow {
                    iconName: "opacity"
                    title: "Surface Transparency"
                    description: "Opacity of floating bars, panels, menus, and overlays."

                    RowLayout {
                        spacing: 12

                        Slider {
                            id: opacitySlider
                            Layout.preferredWidth: 160
                            from: 0.6
                            to: 1.0
                            value: root.pendingTransparency
                            valueText: Math.round(root.pendingTransparency * 100) + "%"
                            onMoved: function(v) {
                                root.pendingTransparency = v
                                transparencyDebounce.restart()
                            }
                        }

                        Text {
                            Layout.preferredWidth: 42
                            horizontalAlignment: Text.AlignRight
                            text: Math.round(opacitySlider.value * 100) + "%"
                            color: Theme.text
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSizeSmall
                        }
                    }
                }
            }

            // ── Desktop Bar Configuration Card ────────────────────────────────
            MujoCard {
                title: "Top Bar Layout & Modules"
                iconName: "view_day"

                // Position
                MujoSettingRow {
                    iconName: "vertical_align_top"
                    title: "Screen Position"
                    description: "Attach the floating bar to the top or bottom edge."

                    RowLayout {
                        spacing: 6
                        Repeater {
                            model: ["top", "bottom"]
                            delegate: DisplayChip {
                                required property var modelData
                                label: modelData
                                selected: SettingsBus.get("bar.position", "top") === modelData
                                onClicked: SettingsBus.set("bar.position", modelData)
                            }
                        }
                    }
                }

                // Bar Sizing
                Repeater {
                    model: [
                        { key: "bar.height",  label: "Bar Height",  desc: "Vertical height of pill groups", from: 24, to: 56, def: 34, round: true, unit: "px" },
                        { key: "bar.margin",  label: "Edge Gap",    desc: "Distance from screen borders",    from: 0, to: 20, def: 7,  round: true, unit: "px" },
                        { key: "bar.spacing", label: "Group Spacing",desc: "Separation between pill clusters",from: 0, to: 16, def: 6, round: true, unit: "px" }
                    ]
                    delegate: MujoSettingRow {
                        required property var modelData
                        title: modelData.label
                        description: modelData.desc

                        RowLayout {
                            spacing: 12
                            Slider {
                                Layout.preferredWidth: 160
                                from: modelData.from
                                to: modelData.to
                                value: SettingsBus.get(modelData.key, modelData.def)
                                onMoved: function (v) { SettingsBus.set(modelData.key, modelData.round ? Math.round(v) : v) }
                            }
                            Text {
                                Layout.preferredWidth: 42
                                horizontalAlignment: Text.AlignRight
                                text: Math.round(SettingsBus.get(modelData.key, modelData.def)) + modelData.unit
                                color: Theme.text
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fontSizeSmall
                            }
                        }
                    }
                }

                // Toggles
                MujoSettingRow {
                    iconName: "visibility_off"
                    title: "Bar Auto-Hide"
                    description: "Automatically slide the bar away when windows approach the edge."

                    ToggleSwitch {
                        checked: SettingsBus.get("bar.autoHide", false)
                        onToggled: function (c) { SettingsBus.set("bar.autoHide", c) }
                    }
                }

                MujoSettingRow {
                    iconName: "mouse"
                    title: "Scroll Actions"
                    description: "Change volume or workspaces by scrolling over bar pills."

                    ToggleSwitch {
                        checked: SettingsBus.get("bar.scrollActions", true)
                        onToggled: function (c) { SettingsBus.set("bar.scrollActions", c) }
                    }
                }

                MujoSettingRow {
                    iconName: "format_color_fill"
                    title: "Recolor System Tray Icons"
                    description: "Apply active theme color palette to monochrome tray icons."

                    ToggleSwitch {
                        checked: SettingsBus.get("bar.trayRecolour", false)
                        onToggled: function (c) { SettingsBus.set("bar.trayRecolour", c) }
                    }
                }

                MujoSettingRow {
                    iconName: "keyboard_arrow_up"
                    title: "Collapse All Icons into Menu"
                    description: "Keep the bar minimal by placing all tray icons inside the chevron arrow flyout."

                    ToggleSwitch {
                        checked: SettingsBus.get("bar.trayInlineCount", 0) === 0
                        onToggled: function (c) { SettingsBus.set("bar.trayInlineCount", c ? 0 : 6) }
                    }
                }

                // Right-cluster modules order
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: "Right Cluster Modules & Ordering"
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeBody
                        font.bold: true
                    }

                    Repeater {
                        model: root.barModules
                        delegate: Rectangle {
                            required property int index
                            required property var modelData
                            Layout.fillWidth: true
                            radius: Theme.radiusMd
                            color: Theme.bg
                            border.color: Theme.border
                            implicitHeight: 38

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 8
                                spacing: 8

                                MaterialIcon {
                                    iconName: "drag_indicator"
                                    pixelSize: 16
                                    color: Theme.textDim
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: modelData
                                    color: Theme.text
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.fontSizeSmall
                                }

                                MaterialIcon {
                                    iconName: "keyboard_arrow_up"
                                    pixelSize: 18
                                    color: index > 0 ? Theme.textSecondary : Theme.textDim
                                    TapHandler { onTapped: root.barMove(index, -1) }
                                }

                                MaterialIcon {
                                    iconName: "keyboard_arrow_down"
                                    pixelSize: 18
                                    color: index < root.barModules.length - 1 ? Theme.textSecondary : Theme.textDim
                                    TapHandler { onTapped: root.barMove(index, 1) }
                                }

                                MaterialIcon {
                                    iconName: "close"
                                    pixelSize: 16
                                    color: Theme.error
                                    TapHandler { onTapped: root.barRemove(index) }
                                }
                            }
                        }
                    }

                    Flow {
                        Layout.fillWidth: true
                        spacing: 6
                        Repeater {
                            model: root.barAllModules
                            delegate: DisplayChip {
                                required property var modelData
                                visible: root.barModules.indexOf(modelData) < 0
                                label: "+ " + modelData
                                onClicked: root.barAdd(modelData)
                            }
                        }
                    }
                }
            }

            // ── Top Bar Widget Styles & Customization Card ────────────────────
            MujoCard {
                title: "Top Bar Widget Styles & Customization"
                iconName: "tune"
                badgeText: root.selectedBarWidget.toUpperCase()

                // Widget Selector Chips
                Flow {
                    Layout.fillWidth: true
                    spacing: 8

                    Repeater {
                        model: [
                            { k: "workspaces", l: "Workspaces", i: "view_carousel" },
                            { k: "clock", l: "Clock Pill", i: "schedule" },
                            { k: "launcher", l: "Launcher Pill", i: "search" },
                            { k: "activeWindow", l: "Active Window", i: "tab" },
                            { k: "volume", l: "Volume", i: "volume_up" },
                            { k: "battery", l: "Battery", i: "battery_charging_full" },
                            { k: "connectivity", l: "Network & Bluetooth", i: "wifi" },
                            { k: "notifications", l: "Notifications & AI", i: "notifications" }
                        ]
                        delegate: Rectangle {
                            required property var modelData
                            readonly property bool sel: root.selectedBarWidget === modelData.k
                            implicitWidth: bwRow.implicitWidth + 18
                            implicitHeight: 32
                            radius: Theme.radiusSm
                            color: sel ? Theme.accentDim : (bwhh.hovered ? Theme.surfaceHover : Theme.surfaceActive)
                            border.color: sel ? Theme.accent : Theme.border
                            border.width: sel ? 1.5 : 1

                            RowLayout {
                                id: bwRow
                                anchors.centerIn: parent
                                spacing: 6
                                MaterialIcon {
                                    iconName: parent.parent.modelData.i
                                    pixelSize: 15
                                    color: parent.parent.sel ? Theme.accent : Theme.textSecondary
                                }
                                Text {
                                    text: parent.parent.modelData.l
                                    color: parent.parent.sel ? Theme.text : Theme.textSecondary
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.bold: parent.parent.sel
                                }
                            }
                            HoverHandler { id: bwhh; cursorShape: Qt.PointingHandCursor }
                            TapHandler { onTapped: root.selectedBarWidget = modelData.k }
                        }
                    }
                }

                // ── 1. Workspaces Style Settings ──────────────────────────────
                ColumnLayout {
                    visible: root.selectedBarWidget === "workspaces"
                    Layout.fillWidth: true
                    spacing: 10

                    MujoSettingRow {
                        iconName: "format_list_numbered"
                        title: "Workspace Numeral Style"
                        description: "Format used to label workspace items in the pill."
                        RowLayout {
                            spacing: 6
                            Repeater {
                                model: [
                                    { k: "numbers", l: "1 2 3" },
                                    { k: "dots", l: "Dots (•)" },
                                    { k: "roman", l: "Roman (I II III)" }
                                ]
                                delegate: DisplayChip {
                                    required property var modelData
                                    label: modelData.l
                                    selected: SettingsBus.get("bar.workspaces.style", "numbers") === modelData.k
                                    onClicked: SettingsBus.set("bar.workspaces.style", modelData.k)
                                }
                            }
                        }
                    }

                    MujoSettingRow {
                        iconName: "animation"
                        title: "Glider Focus Indicator"
                        description: "Visual animation style behind the currently active workspace."
                        RowLayout {
                            spacing: 6
                            Repeater {
                                model: [
                                    { k: "morphic", l: "Morphic Glider" },
                                    { k: "pill", l: "Pill" },
                                    { k: "underline", l: "Underline" },
                                    { k: "outline", l: "Outline" },
                                    { k: "none", l: "None" }
                                ]
                                delegate: DisplayChip {
                                    required property var modelData
                                    label: modelData.l
                                    selected: SettingsBus.get("bar.workspaces.gliderStyle", "morphic") === modelData.k
                                    onClicked: SettingsBus.set("bar.workspaces.gliderStyle", modelData.k)
                                }
                            }
                        }
                    }

                    MujoSettingRow {
                        iconName: "lens"
                        title: "Show Window Presence Dots"
                        description: "Display subtle micro-dot on workspaces containing open windows."
                        ToggleSwitch {
                            checked: SettingsBus.get("bar.workspaces.showWindowDots", true)
                            onToggled: function(c) { SettingsBus.set("bar.workspaces.showWindowDots", c) }
                        }
                    }

                    MujoSettingRow {
                        iconName: "visibility_off"
                        title: "Hide Empty Workspaces"
                        description: "Only show workspaces that contain open windows or are currently focused."
                        ToggleSwitch {
                            checked: SettingsBus.get("bar.workspaces.hideEmpty", false)
                            onToggled: function(c) { SettingsBus.set("bar.workspaces.hideEmpty", c) }
                        }
                    }
                }

                // ── 2. Clock Pill Settings ────────────────────────────────────
                ColumnLayout {
                    visible: root.selectedBarWidget === "clock"
                    Layout.fillWidth: true
                    spacing: 10

                    MujoSettingRow {
                        iconName: "schedule"
                        title: "24-Hour Time Format"
                        description: "Display time as 24-hour clock (14:30) instead of 12-hour AM/PM (2:30 PM)."
                        ToggleSwitch {
                            checked: SettingsBus.get("bar.clock.format24", Theme.clock24h)
                            onToggled: function(c) { SettingsBus.set("bar.clock.format24", c) }
                        }
                    }

                    MujoSettingRow {
                        iconName: "timer"
                        title: "Show Live Seconds"
                        description: "Render live seconds in the top bar clock pill."
                        ToggleSwitch {
                            checked: SettingsBus.get("bar.clock.showSeconds", Theme.clockShowSeconds)
                            onToggled: function(c) { SettingsBus.set("bar.clock.showSeconds", c) }
                        }
                    }

                    MujoSettingRow {
                        iconName: "calendar_today"
                        title: "Show Date in Bar"
                        description: "Display date alongside clock numerals."
                        ToggleSwitch {
                            checked: SettingsBus.get("bar.clock.showDate", Theme.clockShowDate)
                            onToggled: function(c) { SettingsBus.set("bar.clock.showDate", c) }
                        }
                    }

                    MujoSettingRow {
                        iconName: "short_text"
                        title: "Date Format Pattern"
                        description: "Date string representation in the pill."
                        RowLayout {
                            spacing: 6
                            Repeater {
                                model: [
                                    { k: "short", l: "Thu, Aug 28" },
                                    { k: "compact", l: "8/28" },
                                    { k: "full", l: "Thursday, Aug 28" },
                                    { k: "iso", l: "2026-08-28" }
                                ]
                                delegate: DisplayChip {
                                    required property var modelData
                                    label: modelData.l
                                    selected: SettingsBus.get("bar.clock.dateFormat", "short") === modelData.k
                                    onClicked: SettingsBus.set("bar.clock.dateFormat", modelData.k)
                                }
                            }
                        }
                    }

                    MujoSettingRow {
                        iconName: "code"
                        title: "Monospace Typography"
                        description: "Use fixed-width numerals to prevent pill jitter during second ticks."
                        ToggleSwitch {
                            checked: SettingsBus.get("bar.clock.fontMono", true)
                            onToggled: function(c) { SettingsBus.set("bar.clock.fontMono", c) }
                        }
                    }

                    MujoSettingRow {
                        iconName: "format_bold"
                        title: "Bold Numerals"
                        description: "Emphasize clock text with heavier font weight."
                        ToggleSwitch {
                            checked: SettingsBus.get("bar.clock.bold", false)
                            onToggled: function(c) { SettingsBus.set("bar.clock.bold", c) }
                        }
                    }

                    MujoSettingRow {
                        iconName: "schedule"
                        title: "Show Clock Icon"
                        description: "Prepend a clock glyph inside the pill."
                        ToggleSwitch {
                            checked: SettingsBus.get("bar.clock.showIcon", false)
                            onToggled: function(c) { SettingsBus.set("bar.clock.showIcon", c) }
                        }
                    }
                }

                // ── 3. Launcher Trigger Settings ──────────────────────────────
                ColumnLayout {
                    visible: root.selectedBarWidget === "launcher"
                    Layout.fillWidth: true
                    spacing: 10

                    MujoSettingRow {
                        iconName: "category"
                        title: "Launcher Icon Style"
                        description: "Visual emblem used for the main menu and launcher trigger button."
                        RowLayout {
                            spacing: 6
                            Repeater {
                                model: [
                                    { k: "search", l: "Search Glass" },
                                    { k: "mujo", l: "Mujō Logo" },
                                    { k: "apps", l: "App Grid" },
                                    { k: "menu", l: "Hamburger" },
                                    { k: "dots", l: "Dots" }
                                ]
                                delegate: DisplayChip {
                                    required property var modelData
                                    label: modelData.l
                                    selected: SettingsBus.get("bar.launcher.icon", "search") === modelData.k
                                    onClicked: SettingsBus.set("bar.launcher.icon", modelData.k)
                                }
                            }
                        }
                    }

                    MujoSettingRow {
                        iconName: "label"
                        title: "Show Text Label"
                        description: "Display an explicit text label next to the launcher icon."
                        ToggleSwitch {
                            checked: SettingsBus.get("bar.launcher.showLabel", false)
                            onToggled: function(c) { SettingsBus.set("bar.launcher.showLabel", c) }
                        }
                    }

                    MujoSettingRow {
                        visible: SettingsBus.get("bar.launcher.showLabel", false)
                        iconName: "edit"
                        title: "Label Text"
                        description: "Text shown inside launcher pill."
                        RowLayout {
                            spacing: 6
                            Repeater {
                                model: ["Apps", "Menu", "Mujō", "Search", "Start"]
                                delegate: DisplayChip {
                                    required property var modelData
                                    label: modelData
                                    selected: SettingsBus.get("bar.launcher.label", "Apps") === modelData
                                    onClicked: SettingsBus.set("bar.launcher.label", modelData)
                                }
                            }
                        }
                    }
                }

                // ── 4. Active Window Pill Settings ────────────────────────────
                ColumnLayout {
                    visible: root.selectedBarWidget === "activeWindow"
                    Layout.fillWidth: true
                    spacing: 10

                    MujoSettingRow {
                        iconName: "image"
                        title: "Show Application Icon"
                        description: "Render high-DPI desktop app icon in active window pill."
                        ToggleSwitch {
                            checked: SettingsBus.get("bar.activeWindow.showIcon", true)
                            onToggled: function(c) { SettingsBus.set("bar.activeWindow.showIcon", c) }
                        }
                    }

                    MujoSettingRow {
                        iconName: "title"
                        title: "Show Window Title"
                        description: "Render active window title string."
                        ToggleSwitch {
                            checked: SettingsBus.get("bar.activeWindow.showTitle", true)
                            onToggled: function(c) { SettingsBus.set("bar.activeWindow.showTitle", c) }
                        }
                    }

                    MujoSettingRow {
                        iconName: "view_headline"
                        title: "Maximum Title Width"
                        description: "Title elision threshold to preserve bar layout space."
                        RowLayout {
                            spacing: 12
                            Slider {
                                Layout.preferredWidth: 160
                                from: 100; to: 360
                                value: SettingsBus.get("bar.activeWindow.maxWidth", 190)
                                valueText: Math.round(SettingsBus.get("bar.activeWindow.maxWidth", 190)) + "px"
                                onMoved: function (v) { SettingsBus.set("bar.activeWindow.maxWidth", Math.round(v)) }
                            }
                            Text {
                                Layout.preferredWidth: 42
                                horizontalAlignment: Text.AlignRight
                                text: Math.round(SettingsBus.get("bar.activeWindow.maxWidth", 190)) + "px"
                                color: Theme.text
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fontSizeSmall
                            }
                        }
                    }

                    MujoSettingRow {
                        iconName: "style"
                        title: "Pill Visual Mode"
                        description: "Pill surface styling."
                        RowLayout {
                            spacing: 6
                            Repeater {
                                model: [
                                    { k: "pill", l: "Standard Pill" },
                                    { k: "badge", l: "Accent Badge" }
                                ]
                                delegate: DisplayChip {
                                    required property var modelData
                                    label: modelData.l
                                    selected: SettingsBus.get("bar.activeWindow.style", "pill") === modelData.k
                                    onClicked: SettingsBus.set("bar.activeWindow.style", modelData.k)
                                }
                            }
                        }
                    }
                }

                // ── 5. Volume Settings ────────────────────────────────────────
                ColumnLayout {
                    visible: root.selectedBarWidget === "volume"
                    Layout.fillWidth: true
                    spacing: 10

                    MujoSettingRow {
                        iconName: "percent"
                        title: "Show Volume Percentage"
                        description: "Display numerical audio volume percentage directly in the bar pill."
                        ToggleSwitch {
                            checked: SettingsBus.get("bar.volume.showPercent", false)
                            onToggled: function(c) { SettingsBus.set("bar.volume.showPercent", c) }
                        }
                    }

                    MujoSettingRow {
                        iconName: "swap_vert"
                        title: "Volume Scroll Step"
                        description: "Percentage volume change per scroll tick over the pill."
                        RowLayout {
                            spacing: 6
                            Repeater {
                                model: [
                                    { k: 1, l: "1%" },
                                    { k: 2, l: "2%" },
                                    { k: 5, l: "5%" },
                                    { k: 10, l: "10%" }
                                ]
                                delegate: DisplayChip {
                                    required property var modelData
                                    label: modelData.l
                                    selected: SettingsBus.get("bar.volume.step", 5) === modelData.k
                                    onClicked: SettingsBus.set("bar.volume.step", modelData.k)
                                }
                            }
                        }
                    }
                }

                // ── 6. Battery Settings ───────────────────────────────────────
                ColumnLayout {
                    visible: root.selectedBarWidget === "battery"
                    Layout.fillWidth: true
                    spacing: 10

                    MujoSettingRow {
                        iconName: "battery_charging_full"
                        title: "Battery Percentage Mode"
                        description: "When to display battery percentage numeral in the bar pill."
                        RowLayout {
                            spacing: 6
                            Repeater {
                                model: [
                                    { k: "always", l: "Always" },
                                    { k: "charging", l: "Charging" },
                                    { k: "low", l: "When Low" },
                                    { k: "never", l: "Never" }
                                ]
                                delegate: DisplayChip {
                                    required property var modelData
                                    label: modelData.l
                                    selected: SettingsBus.get("bar.battery.showPercent", "charging") === modelData.k
                                    onClicked: SettingsBus.set("bar.battery.showPercent", modelData.k)
                                }
                            }
                        }
                    }

                    MujoSettingRow {
                        iconName: "battery_alert"
                        title: "Low Battery Warning Threshold"
                        description: "Battery level triggering amber warning state and low alert."
                        RowLayout {
                            spacing: 6
                            Repeater {
                                model: [
                                    { k: 10, l: "10%" },
                                    { k: 15, l: "15%" },
                                    { k: 20, l: "20%" },
                                    { k: 25, l: "25%" },
                                    { k: 30, l: "30%" }
                                ]
                                delegate: DisplayChip {
                                    required property var modelData
                                    label: modelData.l
                                    selected: SettingsBus.get("bar.battery.lowThreshold", 20) === modelData.k
                                    onClicked: SettingsBus.set("bar.battery.lowThreshold", modelData.k)
                                }
                            }
                        }
                    }
                }

                // ── 7. Network & Bluetooth Settings ───────────────────────────
                ColumnLayout {
                    visible: root.selectedBarWidget === "connectivity"
                    Layout.fillWidth: true
                    spacing: 10

                    MujoSettingRow {
                        iconName: "wifi"
                        title: "Show Wi-Fi Network Name (SSID)"
                        description: "Display current Wi-Fi network name directly in the bar pill."
                        ToggleSwitch {
                            checked: SettingsBus.get("bar.network.showSsid", false)
                            onToggled: function(c) { SettingsBus.set("bar.network.showSsid", c) }
                        }
                    }

                    MujoSettingRow {
                        iconName: "bluetooth"
                        title: "Show Connected Bluetooth Device"
                        description: "Display name of primary connected Bluetooth device in the bar pill."
                        ToggleSwitch {
                            checked: SettingsBus.get("bar.bluetooth.showDevice", false)
                            onToggled: function(c) { SettingsBus.set("bar.bluetooth.showDevice", c) }
                        }
                    }
                }

                // ── 8. Notifications & AI LLM Settings ────────────────────────
                ColumnLayout {
                    visible: root.selectedBarWidget === "notifications"
                    Layout.fillWidth: true
                    spacing: 10

                    MujoSettingRow {
                        iconName: "mark_chat_unread"
                        title: "Show Unread Notification Count Badge"
                        description: "Display living accent badge with unread notification tally over the bell."
                        ToggleSwitch {
                            checked: SettingsBus.get("bar.notifications.showCount", true)
                            onToggled: function(c) { SettingsBus.set("bar.notifications.showCount", c) }
                        }
                    }

                    MujoSettingRow {
                        iconName: "neurology"
                        title: "Show AI Daily Token Count in Bar"
                        description: "Display daily token count next to AI assistant icon in the bar."
                        ToggleSwitch {
                            checked: SettingsBus.get("bar.llm.showTokens", false)
                            onToggled: function(c) { SettingsBus.set("bar.llm.showTokens", c) }
                        }
                    }

                    MujoSettingRow {
                        iconName: "power_settings_new"
                        title: "Session Button Icon"
                        description: "Icon glyph used for power and session trigger."
                        RowLayout {
                            spacing: 6
                            Repeater {
                                model: [
                                    { k: "power", l: "Power" },
                                    { k: "user", l: "User" },
                                    { k: "logo", l: "Fingerprint" }
                                ]
                                delegate: DisplayChip {
                                    required property var modelData
                                    label: modelData.l
                                    selected: SettingsBus.get("bar.session.iconStyle", "power") === modelData.k
                                    onClicked: SettingsBus.set("bar.session.iconStyle", modelData.k)
                                }
                            }
                        }
                    }
                }
            }

            Item { implicitHeight: 12 }
        }
    }
}
