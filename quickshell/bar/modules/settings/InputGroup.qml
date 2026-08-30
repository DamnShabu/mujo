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
    Rectangle {
        Layout.fillWidth: true
        visible: root.dirty
        implicitHeight: 46
        radius: Theme.radiusMd
        color: Theme.withAlpha(Theme.warning, 0.1)
        border.color: Theme.withAlpha(Theme.warning, 0.45)

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 10
            spacing: 10

            MaterialIcon { iconName: "sync_problem"; pixelSize: 18; color: Theme.warning }
            Text {
                Layout.fillWidth: true
                text: "Input changes are saved but not live yet — they apply on the next rebuild."
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
        iconName: "keyboard"
        isNixos: true
        badgeText: (root.input.keyboard_layout || "US").toUpperCase()

        ColumnLayout {
            Layout.fillWidth: true; spacing: 8
            SectionLabel { text: "Layout" }
            Flow {
                Layout.fillWidth: true; spacing: 7
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

        DeviceSlider {
            label: "Repeat rate"; suffix: " keys/s"; from: 10; to: 100; step: 1
            value: root.input.repeat_rate !== undefined ? root.input.repeat_rate : 40
            onEdited: function(v) { root.setSoon("repeat_rate", Math.round(v)) }
        }
        DeviceSlider {
            label: "Repeat delay"; suffix: " ms"; from: 100; to: 600; step: 10
            value: root.input.repeat_delay !== undefined ? root.input.repeat_delay : 250
            onEdited: function(v) { root.setSoon("repeat_delay", Math.round(v)) }
        }
    }

    MujoCard {
        title: "Pointer"
        iconName: "mouse"
        isNixos: true

        SectionLabel { text: "Mouse" }

        ColumnLayout {
            Layout.fillWidth: true; spacing: 8
            SectionLabel { text: "Acceleration profile" }
            Flow {
                Layout.fillWidth: true; spacing: 7
                Repeater {
                    model: [{ v: "flat", l: "Flat (no accel)" }, { v: "adaptive", l: "Adaptive" }]
                    delegate: DisplayChip {
                        required property var modelData
                        label: modelData.l
                        selected: (root.input.mouse_accel_profile || "flat") === modelData.v
                        onClicked: root.set("mouse_accel_profile", modelData.v)
                    }
                }
            }
        }
        DeviceSlider {
            label: "Pointer speed"; suffix: ""; from: -1.0; to: 1.0; step: 0.05; decimals: 2
            value: root.input.mouse_accel_speed !== undefined ? root.input.mouse_accel_speed : 0.0
            onEdited: function(v) { root.setSoon("mouse_accel_speed", Math.round(v * 100) / 100) }
        }
        DeviceToggle {
            label: "Natural scrolling"; desc: "Reverse the scroll direction"
            checked: !!root.input.mouse_natural_scroll
            onToggledTo: function(c) { root.set("mouse_natural_scroll", c) }
        }
        DeviceToggle {
            label: "Middle-button emulation"; desc: "Left+right click acts as middle click"
            checked: !!root.input.mouse_middle_emulation
            onToggledTo: function(c) { root.set("mouse_middle_emulation", c) }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: Theme.border }

        SectionLabel { text: "Touchpad" }

        DeviceToggle {
            label: "Tap to click"; desc: "Tap the touchpad to click"
            checked: root.input.touchpad_tap !== undefined ? root.input.touchpad_tap : true
            onToggledTo: function(c) { root.set("touchpad_tap", c) }
        }
        DeviceToggle {
            label: "Natural scrolling"; desc: "Reverse the scroll direction"
            checked: root.input.touchpad_natural_scroll !== undefined ? root.input.touchpad_natural_scroll : true
            onToggledTo: function(c) { root.set("touchpad_natural_scroll", c) }
        }
        DeviceToggle {
            label: "Disable while typing"; desc: "Ignore the touchpad as you type"
            checked: !!root.input.touchpad_dwt
            onToggledTo: function(c) { root.set("touchpad_dwt", c) }
        }

        Text {
            Layout.fillWidth: true
            text: "Input settings are written to the NixOS niri configuration and applied on rebuild."
            color: Theme.textDim
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            wrapMode: Text.WordWrap
        }
    }
}
