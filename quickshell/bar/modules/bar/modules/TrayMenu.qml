import QtQuick
import Quickshell


PopupWindow {
    id: root

    property QsMenuHandle menuHandle
    signal triggered

    visible: false
    color: "transparent"
    grabFocus: true

    implicitWidth: 220
    implicitHeight: col.implicitHeight + 20

    onClosed: visible = false

    function show(handle, x, y) {
        var firstShow = !visible
        if (handle !== menuHandle) menuHandle = handle
        anchor.rect.x = x
        anchor.rect.y = y
        visible = true
        if (firstShow) {
            menuRect.opacity = 0
            menuRect.scale = 0.92
            menuAnim.restart()
        } else {
            menuRect.opacity = 1
            menuRect.scale = 1
        }
    }

    ParallelAnimation {
        id: menuAnim
        running: false

        NumberAnimation {
            target: menuRect
            property: "opacity"
            from: 0
            to: 1
            duration: 180
            easing.type: Easing.OutQuad
        }

        NumberAnimation {
            target: menuRect
            property: "scale"
            from: 0.92
            to: 1
            duration: 200
            easing.type: Easing.OutBack
            easing.overshoot: 0.6
        }
    }

    Rectangle {
        id: menuRect
        anchors.fill: parent
        anchors.margins: 4
        color: Theme.bg
        radius: 8
        border.color: Theme.border
        border.width: 1
        transformOrigin: Item.Top
        clip: true

        Column {
            id: col
            anchors.fill: parent
            anchors.margins: 6
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
                    color: itemHover.hovered && !modelData.isSeparator && modelData.enabled ? Theme.border : "transparent"
                    radius: 4

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
                            visible: modelData.icon !== ""
                            fillMode: Image.PreserveAspectFit
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.text
                            color: modelData.enabled ? Theme.text : Theme.textSecondary
                            font.pixelSize: 13
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
