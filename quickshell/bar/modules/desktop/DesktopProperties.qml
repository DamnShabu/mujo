import QtQuick
import QtQuick.Effects
import Quickshell
import "../../theme"
import "../../components"

// The Properties sheet for one ~/Desktop item — name, kind, size, location,
// modified, permissions. Fed by `mujo desktop info`, so what it shows is the
// filesystem's answer rather than anything the shell has cached.
Item {
    id: root

    property var info: null
    property bool open: false

    signal closed()

    implicitWidth: 340
    implicitHeight: col.implicitHeight + 24
    width: implicitWidth
    height: implicitHeight

    opacity: root.open ? 1 : 0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: Anim.d(Anim.fast) } }

    function human(bytes) {
        if (bytes === undefined || bytes === null) return "—"
        var u = ["B", "KB", "MB", "GB", "TB"]
        var i = 0
        var v = bytes
        while (v >= 1024 && i < u.length - 1) { v /= 1024; i++ }
        return (i === 0 ? v : v.toFixed(1)) + " " + u[i]
    }

    Rectangle {
        id: shadowSrc
        anchors.fill: card
        radius: card.radius
        color: "#000000"
        visible: false
        layer.enabled: true
    }
    MultiEffect {
        anchors.fill: shadowSrc
        source: shadowSrc
        autoPaddingEnabled: true
        shadowEnabled: true
        shadowColor: "#000000"
        shadowBlur: 1.0
        shadowVerticalOffset: 8
        shadowOpacity: 0.55
    }

    Rectangle {
        id: card
        anchors.fill: parent
        color: Theme.bg
        radius: Theme.radiusLg
        border.color: Theme.border
        scale: root.open ? 1 : 0.96
        transformOrigin: Item.TopLeft
        Behavior on scale { NumberAnimation { duration: Anim.d(Anim.fast); easing.type: Easing.OutCubic } }

        // Swallow clicks on the card itself: the desktop underneath dismisses
        // this sheet on any press, and clicking a dialog must not close it.
        MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons }

        Column {
            id: col
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
            spacing: 10

            Row {
                width: parent.width
                spacing: 12

                Image {
                    width: 40
                    height: 40
                    source: root.info ? Icons.fileIcon(root.info.name, root.info.kind === "Folder") : ""
                    fillMode: Image.PreserveAspectFit
                    sourceSize.width: 40
                    sourceSize.height: 40
                    smooth: true
                    mipmap: true
                }

                Column {
                    width: parent.width - 52 - 30
                    spacing: 2
                    anchors.verticalCenter: parent.verticalCenter
                    Text {
                        width: parent.width
                        text: root.info ? root.info.name : ""
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeTitle
                        font.bold: true
                        elide: Text.ElideMiddle
                    }
                    Text {
                        width: parent.width
                        text: root.info ? root.info.kind : ""
                        color: Theme.textSecondary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        elide: Text.ElideRight
                    }
                }

                Rectangle {
                    width: 26
                    height: 26
                    radius: Theme.radiusSm
                    anchors.verticalCenter: parent.verticalCenter
                    color: close_hh.hovered ? Theme.surfaceHover : "transparent"
                    MaterialIcon {
                        anchors.centerIn: parent
                        iconName: "close"
                        pixelSize: 16
                        color: Theme.textSecondary
                    }
                    HoverHandler { id: close_hh; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: root.closed() }
                }
            }

            Rectangle { width: parent.width; height: 1; color: Theme.border }

            Repeater {
                model: root.info ? [
                    { k: "Size", v: root.human(root.info.bytes) },
                    { k: "Contains", v: root.info.items === null ? "—" : (root.info.items + " item" + (root.info.items === 1 ? "" : "s")) },
                    { k: "Location", v: root.info.path },
                    { k: "Modified", v: root.info.modified },
                    { k: "Permissions", v: root.info.mode }
                ] : []
                delegate: Row {
                    required property var modelData
                    width: col.width
                    spacing: 10
                    visible: modelData.v !== "—" || modelData.k === "Size"
                    Text {
                        width: 92
                        text: modelData.k
                        color: Theme.textSecondary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                    }
                    Text {
                        width: parent.width - 102
                        text: modelData.v
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        elide: Text.ElideMiddle
                    }
                }
            }

            Row {
                anchors.right: parent.right
                spacing: 8
                Rectangle {
                    width: pathLabel.implicitWidth + 20; height: 30; radius: Theme.radiusSm
                    color: path_hh.hovered ? Theme.surfaceHover : Theme.surface
                    border.color: Theme.border
                    Text {
                        id: pathLabel
                        anchors.centerIn: parent
                        text: "Copy path"
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                    }
                    HoverHandler { id: path_hh; cursorShape: Qt.PointingHandCursor }
                    TapHandler {
                        onTapped: {
                            if (root.info) Quickshell.execDetached(["wl-copy", "--", root.info.path])
                            root.closed()
                        }
                    }
                }
            }
        }
    }

    Keys.onEscapePressed: root.closed()
}
