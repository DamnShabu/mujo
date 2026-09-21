import QtQuick
import QtQuick.Layouts
import "../../theme"
import "../../components"
import "../../services"

// One store-backed setting. `path` is the SettingsBus key, `kind` picks the
// control — the row reads and writes the store itself, so panels stop repeating
// get/set + control wiring on every line.
//
//   SettingRow { path: "bar.autoHide"; title: "Auto-hide"; kind: "toggle"; def: false }
//   SettingRow { path: "bar.height"; kind: "slider"; from: 24; to: 56; format: "px" }
//   SettingRow { path: "bar.position"; kind: "segment"; options: ["top", "bottom"] }
//   SettingRow { path: "general.hostname"; kind: "text"; placeholder: "main" }
//
// Anything with a bespoke control keeps using MujoSettingRow directly and puts
// the control in its default slot — this is the shortcut for the common four,
// not a replacement.
MujoSettingRow {
    id: row

    property string path: ""
    property var def: undefined
    property string kind: "toggle"        // toggle | slider | segment | text
    property var options: []              // segment: ["a", "b"] or [{ id, label }]
    property real from: 0
    property real to: 100
    property string format: ""            // slider bubble suffix, e.g. "px" / "%"
    property string placeholder: ""
    property int controlWidth: 190
    property bool roundValue: true
    property string valueText: ""

    readonly property var value: SettingsBus.get(row.path, row.def)
    function commit(v) { SettingsBus.set(row.path, v) }

    // Invisible items are skipped by QtQuick.Layouts, so only the selected
    // control occupies the slot. Cheaper than a Loader with five Components,
    // which the default control slot (a list<Item>) cannot hold anyway.
    ToggleSwitch {
        visible: row.kind === "toggle"
        a11yName: row.title
        checked: row.value === true
        onToggled: function (c) { row.commit(c) }
    }

    Slider {
        id: slider
        visible: row.kind === "slider"
        Layout.preferredWidth: row.controlWidth
        a11yName: row.title
        from: row.from
        to: row.to
        format: row.format
        value: Number(row.value)
        valueText: row.valueText !== "" ? row.valueText : (row.roundValue ? (Math.round(value) + row.format) : (Number(value).toFixed(2) + row.format))
        onMoved: function (v) { row.commit(row.roundValue ? Math.round(v) : Number(v.toFixed(2))) }
    }

    // The slider's own bubble only appears while you point at it, which left a
    // page of sliders showing no numbers at all. The value is the setting, so
    // it stays on screen. Fixed width so a column of sliders lines up.
    Text {
        visible: row.kind === "slider"
        Layout.preferredWidth: 46
        text: slider.valueText
        color: Theme.textSecondary
        font.family: Theme.fontMono
        font.pixelSize: Theme.fontSizeSmall
        horizontalAlignment: Text.AlignRight
        elide: Text.ElideRight
    }

    MujoSegmented {
        visible: row.kind === "segment"
        a11yName: row.title
        model: row.options
        current: row.value
        onSelected: function (id) { row.commit(id) }
    }

    TextField {
        id: field
        visible: row.kind === "text"
        Layout.preferredWidth: row.controlWidth
        a11yName: row.title
        placeholder: row.placeholder
        onAccepted: row.commit(text)
        // Follow the store while idle; stop fighting the user mid-edit.
        Binding {
            target: field
            property: "text"
            value: row.value === undefined ? "" : String(row.value)
            when: !field.input.activeFocus
        }
    }
}
