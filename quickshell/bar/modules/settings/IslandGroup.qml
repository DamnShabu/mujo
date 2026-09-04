import QtQuick
import QtQuick.Layouts
import "../../theme"
import "../../components"
import "../../services"

// Dynamic Island settings group: Module selection, ordering, geometry, appearance & behavior.
ColumnLayout {
    id: root
    Layout.fillWidth: true
    spacing: 14

    readonly property var allModules: ["clock", "media", "weather", "cava-mini"]
    readonly property var modules: SettingsBus.get("island.modules", ["clock", "media", "weather"])
    readonly property bool islandOn: SettingsBus.get("island.enabled", true)

    function setModules(a) { SettingsBus.set("island.modules", a) }
    function move(i, dir) {
        var a = modules.slice(), j = i + dir
        if (j < 0 || j >= a.length) return
        var t = a[i]; a[i] = a[j]; a[j] = t
        setModules(a)
    }
    function removeAt(i) { var a = modules.slice(); a.splice(i, 1); setModules(a) }
    function add(name) { var a = modules.slice(); if (a.indexOf(name) < 0) { a.push(name); setModules(a) } }

    // ── 1. Dynamic Island Modules & Order ─────────────────────────────────────
    MujoCard {
        title: "Dynamic Island Notch"
        iconName: "dynamic_form"
        badgeText: root.islandOn ? (root.modules.length + " ACTIVE") : "DISABLED"
        badgeColor: root.islandOn ? Theme.accent : Theme.textDim

        MujoSettingRow {
            iconName: "blur_on"
            title: "Dynamic Island Cluster"
            description: "Show floating status notch at the top of the focused monitor."

            ToggleSwitch {
                checked: root.islandOn
                onToggled: function (c) { SettingsBus.set("island.enabled", c) }
            }
        }

        SectionLabel { text: "Module Hierarchy (Top to Bottom)" }

        MujoReorderList {
            model: root.modules
            itemHeight: 40
            onReordered: function(newModel) { root.setModules(newModel) }
        }

        // Available modules to add
        Flow {
            Layout.fillWidth: true
            spacing: 6
            visible: root.modules.length < root.allModules.length

            Repeater {
                model: root.allModules
                delegate: DisplayChip {
                    required property var modelData
                    visible: root.modules.indexOf(modelData) < 0
                    label: "+ " + modelData
                    onClicked: root.add(modelData)
                }
            }
        }
    }

    // ── 2. Island Geometry & Appearance ───────────────────────────────────────
    MujoCard {
        title: "Island Geometry & Surface"
        iconName: "style"

        SettingRow {
            path: "island.maxWidth"
            def: 520
            kind: "slider"
            from: 300
            to: 800
            format: "px"
            iconName: "straighten"
            title: "Maximum Expanded Width"
            description: "Widest the cluster may grow before its content elides."
        }

        SettingRow {
            path: "island.radius"
            def: 18
            kind: "slider"
            from: 0
            to: 30
            format: "px"
            iconName: "rounded_corner"
            title: "Corner Radius"
            description: "Roundness of the dynamic island's outer edge."
        }

        SettingRow {
            path: "island.opacity"
            def: 1
            kind: "slider"
            from: 0.3
            to: 1
            roundValue: false
            format: "%"
            valueText: (Number(SettingsBus.get("island.opacity", 1)) * 100).toFixed(0) + "%"
            iconName: "opacity"
            title: "Surface Translucency"
            description: "Alpha opacity of the island glass background."
        }

        // Fixed surface colours, not theme tokens: this is a user-selectable
        // palette, so the swatch must render the colour it names.
        MujoSettingRow {
            iconName: "format_color_fill"
            title: "Surface Colour"
            description: "Follow the theme surface, or pin the island to a fixed colour."

            Flow {
                spacing: 6
                DisplayChip {
                    label: "Auto"
                    selected: SettingsBus.get("island.background", "") === ""
                    onClicked: SettingsBus.set("island.background", "")
                }
                Repeater {
                    model: ["#11111b", "#1e1e2e", "#181825", "#232634"]
                    delegate: Rectangle {
                        required property var modelData
                        readonly property bool sel: SettingsBus.get("island.background", "") === modelData
                        width: 28; height: 28; radius: Theme.radiusSm
                        color: modelData
                        border.width: sel ? 2 : 1
                        border.color: sel ? Theme.accent : Theme.borderStrong
                        MaterialIcon {
                            visible: parent.sel
                            anchors.centerIn: parent
                            iconName: "check"
                            pixelSize: 13
                            color: Theme.text
                        }
                        HoverHandler { cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: SettingsBus.set("island.background", modelData) }
                    }
                }
            }
        }

        SettingRow {
            path: "island.yOffset"
            def: 0
            kind: "slider"
            from: -10
            to: 20
            format: "px"
            iconName: "vertical_align_top"
            title: "Vertical Position Offset"
            description: "Nudge the cluster up or down from the top screen border."
        }
    }

    // ── 3. Island Expansion Behavior ──────────────────────────────────────────
    MujoCard {
        title: "Expansion & Alert Behavior"
        iconName: "motion_photos_on"

        SettingRow {
            path: "island.autoExpandMs"
            def: 4000
            kind: "slider"
            from: 1000
            to: 8000
            format: "ms"
            valueText: (Number(SettingsBus.get("island.autoExpandMs", 4000)) / 1000).toFixed(1) + "s"
            iconName: "timer"
            title: "Auto-Expand Duration"
            description: "How long the island stays expanded before collapsing again."
        }

        SettingRow {
            path: "island.expandOnNotify"
            def: true
            kind: "toggle"
            iconName: "notifications"
            title: "Expand on Notification"
            description: "Briefly reveal incoming notification alerts in dynamic island banner."
        }
    }
}
