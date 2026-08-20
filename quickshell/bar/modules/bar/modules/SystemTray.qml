import QtQuick
import Quickshell
import Quickshell.Services.SystemTray

Row {
    id: root
    property var panelWindow
    spacing: 6

    property bool trayOpen: false

    Rectangle {
        id: trayChevron
        width: 30
        height: 30
        radius: 5
        color: Theme.bg
        border.color: Theme.border

        MaterialIcon {
            id: chevronIcon
            iconName: "expand_more"
            pixelSize: 20
            anchors.centerIn: parent
        }
        rotation: root.trayOpen ? 180 : 0
        Behavior on rotation { NumberAnimation { duration: 200; easing.type: Easing.OutQuad } }

        MouseArea {
            anchors.fill: parent
            onClicked: {
                root.trayOpen = !root.trayOpen
                if (!root.trayOpen) {
                    trayMenu.visible = false
                } else {
                    var pos = trayChevron.mapToItem(panelWindow.contentItem, 0, trayChevron.height)
                    trayListPopup.anchor.rect.x = pos.x + trayChevron.width
                    trayListPopup.anchor.rect.y = pos.y + 40
                    openAnim.start()
                }
            }
        }
    }

    PopupWindow {
        id: trayListPopup
        visible: root.trayOpen
        color: "transparent"
        grabFocus: true
        anchor.window: panelWindow
        anchor.gravity: Edges.Left

        readonly property int cols: 5
        readonly property int rows: Math.ceil(SystemTray.items.values.length / cols)
        implicitWidth: cols * 25 + (cols - 1) * 4 + 16
        implicitHeight: rows * 25 + (rows - 1) * 4 + 16

        onClosed: {
            trayMenu.visible = false
            root.trayOpen = false
        }

        TrayMenu {
            id: trayMenu
            anchor.window: trayListPopup
            anchor.edges: Edges.Top | Edges.Left
            anchor.gravity: Edges.Bottom | Edges.Right
            onTriggered: root.trayOpen = false
        }

        ParallelAnimation {
            id: openAnim
            running: false

            NumberAnimation {
                target: trayBg
                property: "height"
                from: trayChevron.height
                to: trayBg.parent.height
                duration: 200
                easing.type: Easing.OutQuad
            }

            NumberAnimation {
                target: trayBg
                property: "opacity"
                from: 0
                to: 1
                duration: 160
                easing.type: Easing.OutQuad
            }
        }

        Rectangle {
            id: trayBg
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            width: parent.width
            height: trayChevron.height
            clip: true
            color: Theme.bg
            radius: 8
            border.color: Theme.border
            border.width: 1
            opacity: 0

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
            }

            Grid {
                id: gridCol
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.margins: 8
                columns: trayListPopup.cols
                spacing: 4

                Repeater {
                    model: SystemTray.items

                    delegate: Rectangle {
                        id: trayGridEntry
                        required property var modelData
                        required property int index

                        width: 25
                        height: 25
                        radius: 5
                        color: entryHover.hovered ? Theme.border : "transparent"

                        Image {
                            anchors.centerIn: parent
                            width: 19
                            height: 19
                            source: modelData.icon
                            sourceSize.width: 19
                            sourceSize.height: 19
                            fillMode: Image.PreserveAspectFit
                        }

                        Rectangle {
                            visible: entryHover.hovered && modelData.title
                            anchors.bottom: parent.top
                            anchors.bottomMargin: 4
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: trayTooltip.implicitWidth + 12
                            height: 22
                            radius: 4
                            color: Theme.surface
                            border.color: Theme.border

                            Text {
                                id: trayTooltip
                                anchors.centerIn: parent
                                text: modelData.title || ""
                                color: Theme.text
                                font.pixelSize: 10
                                font.family: "monospace"
                            }
                        }

                        HoverHandler { id: entryHover }

                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: mouse => {
                                if (mouse.button === Qt.LeftButton) {
                                    modelData.activate()
                                    root.trayOpen = false
                                } else if (mouse.button === Qt.RightButton && modelData.hasMenu) {
                                    var pos = trayGridEntry.mapToItem(trayListPopup.contentItem, 0, 0)
                                    trayMenu.show(modelData.menu, pos.x, pos.y + 35)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
