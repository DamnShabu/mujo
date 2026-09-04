import QtQuick
import QtQuick.Layouts
import "../../theme"
import "../../components"
import "../../services"

// Top Bar Layout, Geometry, Cluster Modules, and Widget Styles Group.
ColumnLayout {
    id: root
    Layout.fillWidth: true
    spacing: 14

    property string selectedBarWidget: "workspaces"

    readonly property var barModules: SettingsBus.get("bar.rightModules", ["llm", "network", "bluetooth", "volume", "battery", "notifications", "tray", "session"])
    readonly property var barAllModules: ["llm", "network", "bluetooth", "volume", "battery", "notifications", "tray", "session"]

    function barSet(a) { SettingsBus.set("bar.rightModules", a) }
    function barMove(i, d) { var a = barModules.slice(), j = i + d; if (j < 0 || j >= a.length) return; var t = a[i]; a[i] = a[j]; a[j] = t; barSet(a) }
    function barRemove(i) { var a = barModules.slice(); a.splice(i, 1); barSet(a) }
    function barAdd(n) { var a = barModules.slice(); if (a.indexOf(n) < 0) { a.push(n); barSet(a) } }

    // ── 1. Top Bar Layout & Geometry Card ─────────────────────────────────────
    MujoCard {
        title: "Desktop Bar Layout & Geometry"
        iconName: "dock_to_bottom"
        badgeText: SettingsBus.get("bar.position", "top").toUpperCase()
        badgeColor: Theme.accent

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

        SettingRow {
            path: "bar.height"
            def: 34
            kind: "slider"
            from: 24
            to: 56
            format: "px"
            iconName: "height"
            title: "Bar Height"
            description: "Vertical content height of the floating pill clusters."
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

    // ── 2. Right Cluster Modules & Ordering Card ──────────────────────────────
    MujoCard {
        title: "Right Cluster Modules & Order"
        iconName: "reorder"
        badgeText: root.barModules.length + " MODULES"

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                Layout.fillWidth: true
                text: "Drag or reorder modules in the right cluster. Items on top render leftmost in the group."
                color: Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
            }

            MujoReorderList {
                model: root.barModules
                onReordered: function(newModel) { root.barSet(newModel) }
            }

            // Available modules to add
            Flow {
                Layout.fillWidth: true
                spacing: 6
                visible: root.barModules.length < root.barAllModules.length

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
                            { id: "workspaces", label: "Workspaces", icon: "view_carousel" },
                            { id: "clock", label: "Clock", icon: "schedule" },
                            { id: "launcher", label: "Launcher", icon: "category" },
                            { id: "activeWindow", label: "Active Window", icon: "tab" },
                            { id: "volume", label: "Volume", icon: "volume_up" },
                            { id: "battery", label: "Battery", icon: "battery_full" },
                            { id: "network", label: "Network", icon: "wifi" },
                            { id: "notifications", label: "Notifications", icon: "notifications" },
                            { id: "llm", label: "AI Tokens", icon: "psychology" },
                            { id: "session", label: "Session", icon: "power_settings_new" }
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
                            { id: "dots", label: "Dots (•)" },
                            { id: "roman", label: "Roman (I II)" },
                            { id: "kanji", label: "Kanji (一 二)" }
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
                            { id: "pill", label: "Pill" },
                            { id: "line", label: "Line" },
                            { id: "glow", label: "Glow" }
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
                            { id: "short", label: "Thu, Aug 28" },
                            { id: "medium", label: "8/28" },
                            { id: "iso", label: "2026-08-28" }
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
                            { id: "grid", label: "Grid" },
                            { id: "nixos", label: "NixOS" },
                            { id: "mujo", label: "Mujō" }
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
                            { id: "pill", label: "Pill" },
                            { id: "glass", label: "Glass" },
                            { id: "plain", label: "Plain" }
                        ]
                        current: SettingsBus.get("bar.activeWindow.style", "pill")
                        onSelected: function(id) { SettingsBus.set("bar.activeWindow.style", id) }
                    }
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
                            { id: "always", label: "Always" },
                            { id: "charging", label: "Charging" },
                            { id: "low", label: "Low" },
                            { id: "never", label: "Never" }
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

            // ── Network & Notifications & LLM & Session ──
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
                            { id: "power", label: "Power" },
                            { id: "lock", label: "Lock" },
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
