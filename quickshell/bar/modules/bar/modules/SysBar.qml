import QtQuick
import QtQuick.Layouts

// Labeled usage bar (CPU / RAM …) for the system-monitor widget.
ColumnLayout {
    id: root
    property string label: ""
    property int value: 0        // 0–100
    property string caption: ""

    Layout.fillWidth: true
    spacing: 4

    RowLayout {
        Layout.fillWidth: true
        Text { text: root.label; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeLabel; font.capitalization: Font.AllUppercase; font.letterSpacing: Theme.labelSpacing }
        Item { Layout.fillWidth: true }
        Text { text: root.caption; color: Theme.text; font.family: Theme.fontMono; font.pixelSize: Theme.fontSizeSmall }
    }
    Rectangle {
        Layout.fillWidth: true
        implicitWidth: 180
        height: 6
        radius: 3
        color: Theme.surfaceActive
        Rectangle {
            width: parent.width * Math.max(0, Math.min(1, root.value / 100))
            height: parent.height
            radius: parent.radius
            color: root.value > 85 ? Theme.error : (root.value > 60 ? Theme.warning : Theme.accent)
            Behavior on width { NumberAnimation { duration: Theme.durationSlow; easing.type: Easing.OutQuad } }
            Behavior on color { ColorAnimation { duration: Theme.durationFast } }
        }
    }
}
