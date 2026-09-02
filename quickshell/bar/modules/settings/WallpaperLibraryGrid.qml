import QtQuick
import "../../theme"
import "../../components"

// The wallpapers already on disk. `model` and `currentImage` come from the
// panel, which owns the `mujo wallpaper list` process that fills them.
MujoGridView {
    id: grid

    required property string currentImage

    signal wallpaperChosen(string path)

    cellWidth: (width - (width % 180)) / Math.max(1, Math.floor(width / 180))
    cellHeight: cellWidth * 0.62 + 6

    delegate: Item {
        required property var modelData
        width: grid.cellWidth
        height: grid.cellHeight

        Rectangle {
            anchors.fill: parent
            anchors.margins: 5
            radius: Theme.radiusMd
            color: Theme.surface
            clip: true
            border.width: modelData === grid.currentImage ? 2 : 1
            border.color: modelData === grid.currentImage ? Theme.accent : Theme.border

            Image {
                anchors.fill: parent
                anchors.margins: 2
                source: "file://" + modelData
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                sourceSize.width: 320
                sourceSize.height: 180
                clip: true
            }

            Rectangle {
                visible: modelData === grid.currentImage
                anchors { top: parent.top; right: parent.right; margins: 6 }
                width: 22; height: 22; radius: 11
                color: Theme.accent
                MaterialIcon {
                    anchors.centerIn: parent
                    iconName: "check"
                    pixelSize: 14
                    color: Theme.accentText
                }
            }

            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: Theme.accent
                opacity: lib_hh.hovered && modelData !== grid.currentImage ? 0.12 : 0
                Behavior on opacity { NumberAnimation { duration: Anim.d(Anim.fast) } }
            }

            HoverHandler { id: lib_hh; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: grid.wallpaperChosen(modelData) }
        }
    }
}
