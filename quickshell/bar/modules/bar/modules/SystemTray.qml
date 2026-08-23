import QtQuick
import Quickshell
import Quickshell.Services.SystemTray

Item {
    id: root
    property var panelWindow
    property string screenName: ""

    readonly property string popupId: root.screenName + ":tray"
    readonly property bool trayOpen: PopupCoordinator.activeId === root.popupId
    implicitWidth: chevron.width
    implicitHeight: chevron.height
    visible: SystemTray.items.values.length > 0

    IconButton {
        id: chevron
        iconName: "expand_more"
        active: root.trayOpen
        rotation: root.trayOpen ? 180 : 0
        Behavior on rotation { NumberAnimation { duration: Theme.reduceMotion ? 0 : Theme.durationSlow; easing.type: Easing.OutQuad } }

        onClicked: PopupCoordinator.toggle(root.popupId)
    }

    onTrayOpenChanged: if (!root.trayOpen) trayMenu.visible = false

    PopupWindow {
        id: trayListPopup
        visible: root.trayOpen
        color: "transparent"
        anchor.window: root.panelWindow
        anchor.item: chevron
        anchor.edges: Edges.Bottom | Edges.Right
        anchor.gravity: Edges.Bottom | Edges.Left
        anchor.adjustment: PopupAdjustment.Slide

        readonly property int cols: Math.max(1, Math.min(5, SystemTray.items.values.length))
        readonly property int rows: Math.ceil(SystemTray.items.values.length / cols)
        implicitWidth: cols * 25 + (cols - 1) * 4 + 16 + 32
        implicitHeight: rows * 25 + (rows - 1) * 4 + 16 + 32

        onClosed: PopupCoordinator.close(root.popupId)

        TrayMenu {
            id: trayMenu
            anchor.edges: Edges.Bottom | Edges.Right
            anchor.gravity: Edges.Bottom | Edges.Right
            anchor.adjustment: PopupAdjustment.Slide
            onTriggered: PopupCoordinator.close(root.popupId)
        }

        PopupCard {
            anchors.fill: parent
            open: root.trayOpen

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
            }

            Grid {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.margins: 8
                columns: trayListPopup.cols
                spacing: 4

                Repeater {
                    model: SystemTray.items

                    delegate: Rectangle {
                        id: trayEntry
                        required property var modelData

                        width: 25
                        height: 25
                        radius: Theme.radiusMd
                        color: entryHover.hovered ? Theme.surfaceHover : "transparent"

                        Image {
                            anchors.centerIn: parent
                            width: 19
                            height: 19
                            source: trayEntry.modelData.icon
                            sourceSize.width: 19
                            sourceSize.height: 19
                            fillMode: Image.PreserveAspectFit
                        }

                        Rectangle {
                            visible: entryHover.hovered && trayEntry.modelData.title
                            anchors.bottom: parent.top
                            anchors.bottomMargin: 4
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: trayTooltip.implicitWidth + 14
                            height: 22
                            radius: Theme.radiusMd
                            color: Theme.surface
                            border.color: Theme.borderStrong

                            Text {
                                id: trayTooltip
                                anchors.centerIn: parent
                                text: trayEntry.modelData.title || ""
                                color: Theme.text
                                font.family: Theme.fontMono
                                font.pixelSize: 10
                            }
                        }

                        HoverHandler { id: entryHover }

                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: mouse => {
                                if (mouse.button === Qt.LeftButton) {
                                    trayEntry.modelData.activate()
                                    PopupCoordinator.close(root.popupId)
                                } else if (mouse.button === Qt.RightButton && trayEntry.modelData.hasMenu) {
                                    trayMenu.show(trayEntry.modelData.menu, trayEntry)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
