import QtQuick
import QtQuick.Layouts
import "../theme"

// Labeled toggle row: title + description on the left, switch on the right.
RowLayout {
    id: root
    property string label: ""
    property string desc: ""
    property bool checked: false
    signal toggledTo(bool c)

    Layout.fillWidth: true
    spacing: 12

    ColumnLayout {
        spacing: 1
        Text {
            text: root.label
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeBody
        }
        Text {
            visible: root.desc !== ""
            text: root.desc
            color: Theme.textSecondary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
        }
    }
    Item { Layout.fillWidth: true }
    ToggleSwitch {
        checked: root.checked
        onToggled: function(c) { root.toggledTo(c) }
    }
}
