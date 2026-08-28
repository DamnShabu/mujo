import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import "../../theme"
import "../../components"
import "../../services"

// Windows-style system tray:
// - Pinned/inline items (if configured via bar.trayPinned or bar.trayInlineCount)
//   are shown directly on the bar.
// - All other items are neatly tucked into the chevron arrow flyout popup.
// - Arrow button rotates 180° when the flyout is open.
// - Flyout card displays items in a responsive grid of 36x36 px tiles with
//   hover feedback, tooltips, left-click activate, and right-click context menu.
Item {
    id: root
    property var panelWindow
    property string screenName: ""

    readonly property var hidden: SettingsBus.get("bar.trayHidden", [])
    readonly property var pinned: SettingsBus.get("bar.trayPinned", [])
    readonly property int inlineCount: SettingsBus.get("bar.trayInlineCount", 0)
    readonly property bool recolour: SettingsBus.get("bar.trayRecolour", false)

    readonly property var allItems: SystemTray.items.values.filter(function (it) {
        return it && root.hidden.indexOf(it.id) < 0
    })

    readonly property var shownItems: {
        if (root.pinned && root.pinned.length > 0) {
            return root.allItems.filter(function (it) {
                return it && root.pinned.indexOf(it.id) >= 0
            })
        }
        if (root.inlineCount > 0) {
            return root.allItems.slice(0, root.inlineCount)
        }
        return []
    }

    readonly property var overflowItems: {
        return root.allItems.filter(function (it) {
            return it && root.shownItems.indexOf(it) < 0
        })
    }

    readonly property string popupId: root.screenName + ":tray"
    readonly property bool trayOpen: PopupCoordinator.activeId === root.popupId

    implicitWidth: rowL.implicitWidth
    implicitHeight: Theme.barHeight
    visible: root.allItems.length > 0

    onTrayOpenChanged: if (!root.trayOpen) trayMenu.visible = false

    RowLayout {
        id: rowL
        anchors.centerIn: parent
        spacing: 2

        Repeater {
            model: root.shownItems
            delegate: TrayIconDelegate {
                required property var modelData
                item: modelData
                root: root
                tip: tip
                menu: trayMenu
            }
        }

        // Windows-style chevron arrow trigger.
        Rectangle {
            id: overflowBtn
            visible: root.overflowItems.length > 0
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: 26
            implicitHeight: 24
            radius: Theme.radiusMd
            color: root.trayOpen ? Theme.surfaceActive : (ovHover.hovered ? Theme.surfaceHover : "transparent")

            Behavior on color { ColorAnimation { duration: Anim.d(Anim.fast) } }

            MaterialIcon {
                id: arrowIcon
                anchors.centerIn: parent
                iconName: Theme.barBottom ? "keyboard_arrow_up" : "keyboard_arrow_down"
                pixelSize: 18
                color: root.trayOpen ? Theme.accent : (ovHover.hovered ? Theme.text : Theme.textSecondary)
                rotation: root.trayOpen ? 180 : 0
                Behavior on rotation {
                    NumberAnimation {
                        duration: Anim.d(Anim.fast)
                        easing.type: Anim.easeStandard
                    }
                }
            }

            HoverHandler {
                id: ovHover
                onHoveredChanged: {
                    if (!tip) return
                    if (hovered) {
                        tip.target = overflowBtn
                        tip.text = root.trayOpen ? "Hide hidden icons" : "Show hidden icons"
                        tip.status = ""
                        tip.hovered = true
                    } else {
                        if (tip.target === overflowBtn) tip.hovered = false
                    }
                }
            }

            TapHandler { onTapped: PopupCoordinator.toggle(root.popupId) }
        }
    }

    // Shared tooltip + context menu.
    Tooltip { id: tip; panelWindow: root.panelWindow }
    TrayMenu {
        id: trayMenu
        anchor.edges: Theme.popupEdge | Edges.Right
        anchor.gravity: Theme.popupGravity | Edges.Right
        anchor.adjustment: PopupAdjustment.Slide
        onTriggered: PopupCoordinator.close(root.popupId)
    }

    // Windows-style flyout popup card.
    PopupWindow {
        id: overflowPopup
        visible: root.trayOpen
        color: "transparent"
        anchor.window: root.panelWindow
        anchor.item: overflowBtn
        anchor.edges: Theme.popupEdge | Edges.Right
        anchor.gravity: Theme.popupGravity | Edges.Left
        anchor.adjustment: PopupAdjustment.Slide

        readonly property int cols: Math.max(1, Math.min(4, root.overflowItems.length))
        readonly property int rows: Math.ceil(root.overflowItems.length / cols)
        readonly property int itemSize: 36
        readonly property int itemSpacing: 4
        readonly property int cardPadding: 8
        readonly property int popupMargin: 8

        implicitWidth: cols * itemSize + (cols - 1) * itemSpacing + (cardPadding * 2) + (popupMargin * 2)
        implicitHeight: rows * itemSize + (rows - 1) * itemSpacing + (cardPadding * 2) + (popupMargin * 2)

        onClosed: PopupCoordinator.close(root.popupId)

        PopupCard {
            anchors.fill: parent
            open: root.trayOpen
            pad: overflowPopup.popupMargin

            Grid {
                anchors.centerIn: parent
                columns: overflowPopup.cols
                spacing: overflowPopup.itemSpacing

                Repeater {
                    model: root.overflowItems
                    delegate: TrayIconDelegate {
                        required property var modelData
                        item: modelData
                        root: root
                        tip: tip
                        menu: trayMenu
                        inPopup: true
                        closeOnActivate: root.popupId
                    }
                }
            }
        }
    }
}
