import QtQuick

Text {
    id: root

    property string iconName: ""
    property real pixelSize: 16

    font.family: "Material Symbols Rounded"
    font.pixelSize: root.pixelSize
    color: Theme.text
    text: root.iconName
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
    elide: Text.ElideNone
}
