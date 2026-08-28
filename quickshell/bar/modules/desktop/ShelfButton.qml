import QtQuick
import Quickshell
import "../../theme"
import "../../components"
import "../../services"

// The Mujo Shelf Bar Entry (無常).
// Visible while the shelf has items or while its popup is active.
// Toggling opens an anchored, elevated PopupCard hosting ShelfView.
Item {
    id: root
    property var panelWindow
    property string screenName: ""

    readonly property string popupId: root.screenName + ":shelf"
    readonly property bool menuOpen: PopupCoordinator.activeId === root.popupId

    visible: Shelf.enabled && (Shelf.count > 0 || menuOpen)
    implicitWidth: trigger.width
    implicitHeight: trigger.height

    Connections {
        target: Shelf
        function onCountChanged() {
            if (Shelf.count === 0 && root.menuOpen) {
                PopupCoordinator.close(root.popupId)
            }
        }
    }

    IconButton {
        id: trigger
        iconName: "inventory_2"
        active: root.menuOpen || buttonDrop.containsDrag
        onClicked: PopupCoordinator.toggle(root.popupId)

        DropArea {
            id: buttonDrop
            anchors.fill: parent
            keys: ["text/uri-list", "text/plain", "text/x-moz-url"]
            onDropped: (e) => {
                if (e.hasUrls) {
                    for (var i = 0; i < e.urls.length; i++) Shelf.addUri("" + e.urls[i])
                } else {
                    Shelf.addUriList(e.getDataAsString("text/uri-list") || e.getDataAsString("text/plain"))
                }
                e.accept(Qt.CopyAction)
            }
        }

        // Living Count Badge
        Rectangle {
            visible: Shelf.count > 0
            anchors { right: parent.right; top: parent.top; rightMargin: -1; topMargin: -1 }
            width: Math.max(16, badge.implicitWidth + 8)
            height: 16
            radius: 8
            color: Theme.accent
            border.color: Theme.bg
            border.width: 1.5

            scale: visible ? 1.0 : 0.0
            Behavior on scale {
                NumberAnimation {
                    duration: Anim.d(Anim.fast)
                    easing.type: Anim.easeStandard
                }
            }

            Text {
                id: badge
                anchors.centerIn: parent
                text: Shelf.count > 99 ? "99+" : Shelf.count
                color: Theme.accentText
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeLabel - 1
                font.bold: true
            }
        }
    }

    PopupWindow {
        id: popup
        visible: root.menuOpen
        color: "transparent"
        anchor.window: root.panelWindow
        anchor.item: trigger
        anchor.edges: Theme.popupEdge | Edges.Right
        anchor.gravity: Theme.popupGravity | Edges.Left
        anchor.adjustment: PopupAdjustment.Slide

        implicitWidth: 320 + 32
        implicitHeight: Math.min(580, content.implicitHeight + 28 + 32)

        onClosed: PopupCoordinator.close(root.popupId)

        PopupCard {
            anchors.fill: parent
            open: root.menuOpen

            Flickable {
                id: content
                anchors.fill: parent
                anchors.margins: 14
                implicitHeight: view.implicitHeight
                contentHeight: view.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                clip: true

                ShelfView {
                    id: view
                    width: content.width
                    panelWindow: root.panelWindow
                    onMinimizeRequested: PopupCoordinator.close(root.popupId)
                }
            }
        }
    }
}
