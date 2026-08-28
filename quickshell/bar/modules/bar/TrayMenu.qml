import QtQuick
import Quickshell
import "../../theme"

PopupWindow {
    id: root

    property QsMenuHandle menuHandle
    signal triggered

    visible: false
    color: "transparent"

    implicitWidth: 220
    implicitHeight: col.implicitHeight + 20

    onClosed: visible = false

    function show(handle, item) {
        if (handle !== menuHandle) menuHandle = handle
        anchor.item = item
        visible = true
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: 4
        color: Theme.bg
        radius: Theme.radiusLg
        border.color: Theme.border
        clip: true

        Column {
            id: col
            anchors.fill: parent
            anchors.margins: 8
            spacing: 2

            QsMenuOpener {
                id: menuOpener
                menu: root.menuHandle
            }

            Repeater {
                model: menuOpener.children

                delegate: Rectangle {
                    required property QsMenuEntry modelData

                    width: col.width
                    height: modelData.isSeparator ? 9 : 30
                    color: itemHover.hovered && !modelData.isSeparator && modelData.enabled ? Theme.surfaceHover : "transparent"
                    radius: Theme.radiusMd

                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width - 16
                        height: 1
                        color: Theme.border
                        visible: modelData.isSeparator
                    }

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        spacing: 8
                        visible: !modelData.isSeparator

                        Image {
                            anchors.verticalCenter: parent.verticalCenter
                            source: modelData.icon
                            width: 16
                            height: 16
                            sourceSize.width: 32
                            sourceSize.height: 32
                            smooth: true
                            visible: modelData.icon !== ""
                            fillMode: Image.PreserveAspectFit
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.text
                            color: modelData.enabled ? Theme.text : Theme.textSecondary
                            font.pixelSize: Theme.fontSizeTitle
                        }
                    }

                    HoverHandler { id: itemHover }

                    MouseArea {
                        anchors.fill: parent
                        visible: !modelData.isSeparator && modelData.enabled
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            modelData.triggered()
                            root.triggered()
                            root.visible = false
                        }
                    }
                }
            }
        }
    }
}
