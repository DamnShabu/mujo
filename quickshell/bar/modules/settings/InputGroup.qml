import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../theme"
import "../../components"

// Keyboard, mouse and touchpad. These are niri config, not runtime-settable via
// `niri msg`, so changes are written to the niri-settings.json source of truth
// (via `mujo niri input set`) and applied by a rebuild. The group tracks a dirty
// flag and surfaces a rebuild banner above the cards.
ColumnLayout {
    id: root
    Layout.fillWidth: true
    spacing: 14

    property var input: ({})
    property bool dirty: false

    function refresh() { getProc.running = true }
    function set(key, val) {
        var m = root.input; m[key] = val; root.input = m
        root.dirty = true
        Quickshell.execDetached(["mujo", "niri", "input", "set", key, String(val)])
    }
    // debounced set for sliders
    property var _pending: ({})
    Timer {
        id: debounce
        interval: 200
        onTriggered: { for (var k in root._pending) root.set(k, root._pending[k]); root._pending = {} }
    }
    function setSoon(key, val) {
        var m = root.input; m[key] = val; root.input = m
        var p = root._pending; p[key] = val; root._pending = p
        debounce.restart()
    }

    Process {
        id: getProc
        command: ["mujo", "niri", "get"]
        stdout: StdioCollector {
            onStreamFinished: { try { root.input = JSON.parse(this.text).input || {} } catch (e) {} }
        }
    }
    Component.onCompleted: refresh()

    readonly property var layouts: ["us", "de", "fr", "gb", "ru", "ua", "es", "it"]

    // Pending-rebuild banner — one per group, because a change to any card
    // needs the same rebuild.
    InsetPanel {
        Layout.fillWidth: true
        Layout.bottomMargin: 10
        visible: root.dirty
        implicitHeight: 46
        color: Theme.withAlpha(Theme.warning, 0.08)
        accentBorder: Theme.withAlpha(Theme.warning, 0.45)

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 10
            spacing: 10

            MaterialIcon { iconName: "sync_problem"; pixelSize: 18; color: Theme.warning }

            Text {
                Layout.fillWidth: true
                text: "Saved, but not live yet — input settings apply on the next rebuild."
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                elide: Text.ElideRight
            }

            DialogButton {
                text: "Rebuild to apply"
                primary: true
                onClicked: Quickshell.execDetached(["mujo", "niri", "apply"])
            }
        }
    }

    MujoCard {
        title: "Keyboard"
        isNixos: true
        badgeText: (root.input.keyboard_layout || "US").toUpperCase()

        MujoSettingRow {
            title: "Layout"
            description: "Which keymap the compositor loads at session start."

            Flow {
                Layout.preferredWidth: 380
                spacing: 6

                Repeater {
                    model: root.layouts

                    delegate: DisplayChip {
                        required property var modelData
                        label: modelData.toUpperCase()
                        selected: (root.input.keyboard_layout || "us") === modelData
                        onClicked: root.set("keyboard_layout", modelData)
                    }
                }
            }
        }

        MujoSettingRow {
            title: "Repeat rate"
            description: "How fast a held key repeats."

            Slider {
                Layout.preferredWidth: 190
                a11yName: "Key repeat rate"
                from: 10
                to: 100
                value: root.input.repeat_rate !== undefined ? root.input.repeat_rate : 40
                valueText: Math.round(value) + " keys/s"
                onMoved: function (v) { root.setSoon("repeat_rate", Math.round(v)) }
            }

            Text {
                text: (root.input.repeat_rate !== undefined ? root.input.repeat_rate : 40) + "/s"
                color: Theme.textSecondary
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeSmall
                horizontalAlignment: Text.AlignRight
                Layout.preferredWidth: 46
            }
        }

        MujoSettingRow {
            title: "Repeat delay"
            description: "How long a key must be held before it starts repeating."

            Slider {
                Layout.preferredWidth: 190
                a11yName: "Key repeat delay"
                from: 100
                to: 600
                value: root.input.repeat_delay !== undefined ? root.input.repeat_delay : 250
                valueText: Math.round(value) + " ms"
                onMoved: function (v) { root.setSoon("repeat_delay", Math.round(v)) }
            }

            Text {
                text: (root.input.repeat_delay !== undefined ? root.input.repeat_delay : 250) + "ms"
                color: Theme.textSecondary
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeSmall
                horizontalAlignment: Text.AlignRight
                Layout.preferredWidth: 46
            }
        }
    }

    MujoCard {
        title: "Pointer"
        isNixos: true

        MujoSettingRow {
            title: "Acceleration"
            description: "Flat moves the cursor a fixed distance per count; adaptive speeds up as you move faster."

            MujoSegmented {
                a11yName: "Pointer acceleration profile"
                current: root.input.mouse_accel_profile || "flat"
                model: [
                    { id: "flat", label: "Flat" },
                    { id: "adaptive", label: "Adaptive" }
                ]
                onSelected: function (id) { root.set("mouse_accel_profile", id) }
            }
        }

        MujoSettingRow {
            title: "Pointer speed"
            description: "Negative slows the cursor down, positive speeds it up."

            Slider {
                Layout.preferredWidth: 190
                a11yName: "Pointer speed"
                from: -1.0
                to: 1.0
                value: root.input.mouse_accel_speed !== undefined ? root.input.mouse_accel_speed : 0.0
                valueText: Number(value).toFixed(2)
                onMoved: function (v) { root.setSoon("mouse_accel_speed", Math.round(v * 100) / 100) }
            }

            Text {
                text: Number(root.input.mouse_accel_speed !== undefined ? root.input.mouse_accel_speed : 0).toFixed(2)
                color: Theme.textSecondary
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeSmall
                horizontalAlignment: Text.AlignRight
                Layout.preferredWidth: 46
            }
        }

        MujoSettingRow {
            title: "Natural scrolling"
            description: "Content follows your fingers instead of the scrollbar."

            ToggleSwitch {
                a11yName: "Mouse natural scrolling"
                checked: !!root.input.mouse_natural_scroll
                onToggled: function (c) { root.set("mouse_natural_scroll", c) }
            }
        }

        MujoSettingRow {
            title: "Middle-button emulation"
            description: "Pressing left and right together acts as a middle click."

            ToggleSwitch {
                a11yName: "Middle-button emulation"
                checked: !!root.input.mouse_middle_emulation
                onToggled: function (c) { root.set("mouse_middle_emulation", c) }
            }
        }
    }

    MujoCard {
        title: "Touchpad"
        isNixos: true

        MujoSettingRow {
            title: "Tap to click"
            description: "A tap counts as a click without pressing down."

            ToggleSwitch {
                a11yName: "Tap to click"
                checked: root.input.touchpad_tap !== undefined ? root.input.touchpad_tap : true
                onToggled: function (c) { root.set("touchpad_tap", c) }
            }
        }

        MujoSettingRow {
            title: "Natural scrolling"
            description: "Content follows your fingers instead of the scrollbar."

            ToggleSwitch {
                a11yName: "Touchpad natural scrolling"
                checked: root.input.touchpad_natural_scroll !== undefined ? root.input.touchpad_natural_scroll : true
                onToggled: function (c) { root.set("touchpad_natural_scroll", c) }
            }
        }

        MujoSettingRow {
            title: "Disable while typing"
            description: "Ignore the touchpad for a moment after a keystroke, so a palm does not move the cursor."

            ToggleSwitch {
                a11yName: "Disable touchpad while typing"
                checked: !!root.input.touchpad_dwt
                onToggled: function (c) { root.set("touchpad_dwt", c) }
            }
        }

        Text {
            Layout.fillWidth: true
            Layout.topMargin: 6
            text: "These are written to the NixOS niri configuration and take effect on the next rebuild."
            color: Theme.textDim
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            wrapMode: Text.WordWrap
        }
    }
}
