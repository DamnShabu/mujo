import QtQuick
import Quickshell
import "../../theme"
import "../../components"

// The Mujo Shelf Drag Preview Ghost (無常).
// Renders the clean 48x48 Nautilus-style file MIME icon
// to attach directly to the Wayland pointer cursor via Drag.imageSource.
Item {
    id: root

    property string name: ""
    property string path: ""
    property bool isDir: false
    property bool missing: false

    readonly property string iconSource: Icons.fileIcon(root.name, root.isDir)

    width: 48
    height: 48

    function capture(callback) {
        root.grabToImage(function (result) {
            if (callback) callback(result.url)
        })
    }

    // 48x48 File / MIME Icon
    Image {
        anchors.fill: parent
        visible: root.iconSource !== "" && !root.missing
        source: root.iconSource
        fillMode: Image.PreserveAspectFit
        sourceSize.width: 48
        sourceSize.height: 48
        smooth: true
        mipmap: true
    }

    MaterialIcon {
        anchors.fill: parent
        visible: root.iconSource === "" || root.missing
        iconName: root.missing ? "warning" : (root.isDir ? "folder" : "draft")
        pixelSize: 36
        color: root.missing ? Theme.warning : (root.isDir ? Theme.accent : Theme.text)
    }
}
