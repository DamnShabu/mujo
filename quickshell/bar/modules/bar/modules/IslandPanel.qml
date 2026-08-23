import QtQuick
import QtQuick.Layouts
import Quickshell

// Island settings (WP-16): module selection + ordering, appearance, behavior.
Item {
    id: root

    readonly property var allModules: ["clock", "media", "weather", "cava-mini"]
    readonly property var modules: SettingsBus.get("island.modules", ["clock", "media", "weather"])

    function setModules(a) { SettingsBus.set("island.modules", a) }
    function move(i, dir) {
        var a = modules.slice(), j = i + dir
        if (j < 0 || j >= a.length) return
        var t = a[i]; a[i] = a[j]; a[j] = t
        setModules(a)
    }
    function removeAt(i) { var a = modules.slice(); a.splice(i, 1); setModules(a) }
    function add(name) { var a = modules.slice(); if (a.indexOf(name) < 0) { a.push(name); setModules(a) } }

    Flickable {
        anchors.fill: parent
        anchors.margins: 26
        contentHeight: col.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: col
            width: parent.width
            spacing: 20

            // Header + master toggle.
            RowLayout {
                Layout.fillWidth: true
                ColumnLayout {
                    spacing: 3
                    Text {
                        text: "Island"
                        color: Theme.text
                        font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeTitle + 7; font.bold: true
                    }
                    Text {
                        text: "Floating top-center cluster: clock, media, weather, spectrum."
                        color: Theme.textSecondary
                        font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeBody
                    }
                }
                Item { Layout.fillWidth: true }
                ToggleSwitch {
                    checked: SettingsBus.get("island.enabled", true)
                    onToggled: function (c) { SettingsBus.set("island.enabled", c) }
                }
            }

            // ── Modules (ordered) ──────────────────────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 10
                SectionLabel { text: "Modules — order top to bottom" }

                Repeater {
                    model: root.modules
                    delegate: Rectangle {
                        required property int index
                        required property var modelData
                        Layout.fillWidth: true
                        radius: Theme.radiusMd
                        color: Theme.surface
                        border.color: Theme.border
                        implicitHeight: 44

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 14
                            anchors.rightMargin: 10
                            spacing: 8
                            Text {
                                Layout.fillWidth: true
                                text: modelData
                                color: Theme.text
                                font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeBody
                            }
                            MaterialIcon {
                                iconName: "keyboard_arrow_up"; pixelSize: 20
                                color: index > 0 ? Theme.textSecondary : Theme.textDim
                                TapHandler { onTapped: root.move(index, -1) }
                            }
                            MaterialIcon {
                                iconName: "keyboard_arrow_down"; pixelSize: 20
                                color: index < root.modules.length - 1 ? Theme.textSecondary : Theme.textDim
                                TapHandler { onTapped: root.move(index, 1) }
                            }
                            MaterialIcon {
                                iconName: "close"; pixelSize: 18; color: Theme.error
                                TapHandler { onTapped: root.removeAt(index) }
                            }
                        }
                    }
                }

                // Add any module not already present.
                Flow {
                    Layout.fillWidth: true
                    spacing: 8
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

            // ── Appearance ─────────────────────────────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 12
                SectionLabel { text: "Appearance" }

                Repeater {
                    model: [
                        { key: "island.maxWidth", label: "Max width", from: 300, to: 800, def: 520 },
                        { key: "island.radius",   label: "Corner radius", from: 0, to: 30, def: 18 },
                        { key: "island.opacity",  label: "Opacity", from: 0.3, to: 1, def: 1 },
                        { key: "island.yOffset",  label: "Vertical offset", from: -10, to: 20, def: 0 }
                    ]
                    delegate: RowLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: 12
                        Text {
                            Layout.preferredWidth: 110
                            text: modelData.label
                            color: Theme.text
                            font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeBody
                        }
                        Slider {
                            Layout.fillWidth: true
                            from: modelData.from; to: modelData.to
                            value: SettingsBus.get(modelData.key, modelData.def)
                            onMoved: function (v) { SettingsBus.set(modelData.key, v) }
                        }
                    }
                }

                // Background override.
                Flow {
                    Layout.fillWidth: true
                    spacing: 8
                    DisplayChip {
                        label: "Auto bg"
                        selected: SettingsBus.get("island.background", "") === ""
                        onClicked: SettingsBus.set("island.background", "")
                    }
                    Repeater {
                        model: ["#11111b", "#1e1e2e", "#181825", "#232634"]
                        delegate: Rectangle {
                            required property var modelData
                            readonly property bool sel: SettingsBus.get("island.background", "") === modelData
                            width: 30; height: 30; radius: Theme.radiusSm
                            color: modelData
                            border.width: sel ? 3 : 1
                            border.color: sel ? Theme.accent : Theme.borderStrong
                            TapHandler { onTapped: SettingsBus.set("island.background", modelData) }
                        }
                    }
                }
            }

            // ── Behavior ───────────────────────────────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 12
                SectionLabel { text: "Behavior" }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12
                    Text {
                        Layout.preferredWidth: 110
                        text: "Auto-expand"
                        color: Theme.text
                        font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeBody
                    }
                    Slider {
                        Layout.fillWidth: true
                        from: 1000; to: 8000
                        value: SettingsBus.get("island.autoExpandMs", 4000)
                        onMoved: function (v) { SettingsBus.set("island.autoExpandMs", Math.round(v)) }
                    }
                    Text {
                        text: (SettingsBus.get("island.autoExpandMs", 4000) / 1000).toFixed(1) + "s"
                        color: Theme.textSecondary
                        font.family: Theme.fontMono; font.pixelSize: Theme.fontSizeSmall
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "Expand on notification"
                        color: Theme.text
                        font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeBody
                    }
                    Item { Layout.fillWidth: true }
                    ToggleSwitch {
                        checked: SettingsBus.get("island.expandOnNotify", true)
                        onToggled: function (c) { SettingsBus.set("island.expandOnNotify", c) }
                    }
                }
            }
        }
    }
}
