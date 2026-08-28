import QtQuick
import Quickshell
import "../../theme"
import "../../components"
import "../../services"

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

    // Bell sway animation on new notification arrival
    property real bellRotation: 0.0
    Connections {
        target: Notifications
        function onLastPushedIdChanged() {
            if (!Anim.reduceMotion && Notifications.unread > 0) {
                bellSwayAnim.restart()
            }
        }
    }

    SequentialAnimation {
        id: bellSwayAnim
        NumberAnimation { target: root; property: "bellRotation"; to: 14; duration: Anim.d(60); easing.type: Easing.OutQuad }
        NumberAnimation { target: root; property: "bellRotation"; to: -12; duration: Anim.d(80); easing.type: Easing.InOutQuad }
        NumberAnimation { target: root; property: "bellRotation"; to: 8; duration: Anim.d(80); easing.type: Easing.InOutQuad }
        NumberAnimation { target: root; property: "bellRotation"; to: -4; duration: Anim.d(70); easing.type: Easing.InOutQuad }
        NumberAnimation { target: root; property: "bellRotation"; to: 0; duration: Anim.d(60); easing.type: Easing.OutQuad }
    }

    IconButton {
        id: trigger
        iconName: Notifications.dnd ? "notifications_off"
                : (Notifications.unread > 0 ? "notifications_active" : "notifications")
        active: root.menuOpen
        rotation: root.bellRotation
        iconColor: Notifications.dnd ? Theme.warning
                 : (root.menuOpen ? Theme.accent : (trigger.hovered ? Theme.text : (Notifications.unread > 0 ? Theme.accent : Theme.textSecondary)))
        onClicked: PopupCoordinator.toggle(root.popupId)

        // Middle-click to quickly toggle DND
        TapHandler {
            acceptedButtons: Qt.MiddleButton
            onTapped: Notifications.toggleDnd()
        }

        Tooltip {
            text: Notifications.dnd ? "Do Not Disturb (Middle-click to disable)"
                : (Notifications.unread > 0 ? (Notifications.unread + " unread notification" + (Notifications.unread > 1 ? "s" : "")) : "Notifications (Middle-click for DND)")
        }

        // Living unread badge
        Rectangle {
            visible: Notifications.unread > 0 && !root.menuOpen
            anchors { right: parent.right; top: parent.top; rightMargin: -2; topMargin: -2 }
            implicitWidth: Math.max(14, badge.implicitWidth + 6)
            implicitHeight: 14
            radius: 7
            color: Notifications.dnd ? Theme.warning
                 : (Notifications.unread > 0 && !root.menuOpen && Anim.ambient ? Theme.withAlpha(Theme.accent, Anim.breath(0.85, 1.0)) : Theme.accent)
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
                text: Notifications.unread > 99 ? "99+" : Notifications.unread
                color: Theme.accentText
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeLabel - 1
                font.bold: true
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

        implicitWidth: 400 + 32
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

