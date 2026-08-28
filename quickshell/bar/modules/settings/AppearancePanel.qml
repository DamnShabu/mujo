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
        "#5cc2ff", "#7aa2f7", "#89b4fa", "#61afef", "#88c0d0", "#7e9cd8", "#58a6ff", "#268bd2",
        "#03edf9", "#3ddbd9", "#a6e3a1", "#a7c080", "#b8bb26", "#f9e2af", "#ffd866", "#ffb454",
        "#fe8019", "#f38ba8", "#eb6f92", "#bd93f9", "#c4a7e7", "#c792ea"
    ]

    property real pendingTransparency: Theme.transparency

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

                // Flow, not a fixed 4-column Grid: the cards are a fixed 154px,
                // so a Grid left most of the card empty on a wide window.
                Flow {
                    Layout.fillWidth: true
                    spacing: 10

                    Repeater {
                        model: Theme.presetOrder
                        delegate: Rectangle {
                            id: card
                            required property var modelData
                            readonly property var pal: Theme.presets[modelData]
                            readonly property bool selected: Theme.presetName === modelData
                            width: 154
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

            Item { implicitHeight: 12 }
        }
    }
}
