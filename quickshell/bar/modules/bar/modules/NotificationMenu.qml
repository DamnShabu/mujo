import QtQuick
import QtQuick.Layouts
import Quickshell

// Bar bell (WP-04): opens the notification center, shows an unread badge, and
// reflects DND. Trigger + popup pattern copied from NetworkMenu.
Item {
    id: root
    property var panelWindow
    property string screenName: ""

    readonly property string popupId: root.screenName + ":notifications"
    readonly property bool menuOpen: PopupCoordinator.activeId === root.popupId
    implicitWidth: trigger.width
    implicitHeight: trigger.height

    IconButton {
        id: trigger
        iconName: Notifications.dnd ? "notifications_off"
                : (Notifications.unread > 0 ? "notifications_active" : "notifications")
        active: root.menuOpen
        onClicked: PopupCoordinator.toggle(root.popupId)

        // unread badge
        Rectangle {
            visible: Notifications.unread > 0 && !root.menuOpen
            anchors { right: parent.right; top: parent.top; rightMargin: -2; topMargin: -2 }
            implicitWidth: Math.max(14, badge.implicitWidth + 6); implicitHeight: 14
            radius: 7
            color: Notifications.dnd ? Theme.warning : Theme.accent
            border.color: Theme.bg; border.width: 1.5
            Text {
                id: badge
                anchors.centerIn: parent
                text: Notifications.unread > 99 ? "99+" : Notifications.unread
                color: Theme.accentText
                font.family: Theme.fontMono; font.pixelSize: 9; font.bold: true
            }
        }
    }

    onMenuOpenChanged: if (root.menuOpen) Notifications.markSeen()

    PopupWindow {
        id: popup
        visible: root.menuOpen
        color: "transparent"
        anchor.window: root.panelWindow
        anchor.item: trigger
        anchor.edges: Theme.popupEdge | Edges.Right
        anchor.gravity: Theme.popupGravity | Edges.Left
        anchor.adjustment: PopupAdjustment.Slide

        implicitWidth: 380 + 32
        implicitHeight: content.implicitHeight + 28 + 32

        onClosed: PopupCoordinator.close(root.popupId)

        PopupCard {
            anchors.fill: parent
            open: root.menuOpen
            NotificationCenter {
                id: content
                anchors.fill: parent
                anchors.margins: 14
            }
        }
    }
}
