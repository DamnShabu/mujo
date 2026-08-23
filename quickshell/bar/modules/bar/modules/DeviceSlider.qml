import QtQuick
import QtQuick.Layouts

// Labeled slider row with a live numeric read-out. Emits edited(value) on drag.
ColumnLayout {
    id: root
    property string label: ""
    property string suffix: ""
    property real from: 0
    property real to: 1
    property real step: 1
    property int decimals: 0
    property real value: 0
    signal edited(real v)

    Layout.fillWidth: true
    spacing: 7

    RowLayout {
        Layout.fillWidth: true
        Text {
            text: root.label
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeBody
        }
        Item { Layout.fillWidth: true }
        Text {
            text: root.value.toFixed(root.decimals) + root.suffix
            color: Theme.accent
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontSizeBody
        }
    }
    Slider {
        id: s
        Layout.fillWidth: true
        from: root.from
        to: root.to
        value: root.value
        onMoved: function(v) {
            var snapped = root.step > 0 ? Math.round(v / root.step) * root.step : v
            root.value = snapped
            root.edited(snapped)
        }
    }
}
