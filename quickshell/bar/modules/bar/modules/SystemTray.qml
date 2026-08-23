import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import Qt5Compat.GraphicalEffects

// System tray (WP-18): up to 6 items inline in the bar, the rest behind a "+N"
// overflow popup. Per item: real icon or a themed monogram fallback, 400ms
// tooltip, attention dot, optional recolour to the theme foreground, and the
// context menu on right-click. Hidden items come from `bar.trayHidden[]` (by id).
//
// ponytail: tray items expose activeFocusOnTab + Return-to-activate, but the bar
// layer surface never holds keyboard focus, so Tab-focus is latent until some
// surface grabs it. Accepted — the wiring is free and correct if that changes.
Item {
    id: root
    property var panelWindow
    property string screenName: ""

    readonly property var hidden: SettingsBus.get("bar.trayHidden", [])
    readonly property bool recolour: SettingsBus.get("bar.trayRecolour", false)
    readonly property var allItems: SystemTray.items.values.filter(function (it) {
        return it && root.hidden.indexOf(it.id) < 0
    })
    readonly property var shownItems: allItems.slice(0, 6)
    readonly property var overflowItems: allItems.slice(6)

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

        // "+N" overflow trigger.
        Rectangle {
            id: overflowBtn
            visible: root.overflowItems.length > 0
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: 25; implicitHeight: 22
            radius: Theme.radiusMd
            color: root.trayOpen || ovHover.hovered ? Theme.surfaceHover : "transparent"
            Text {
                anchors.centerIn: parent
                text: "+" + root.overflowItems.length
                color: Theme.textSecondary
                font.family: Theme.fontMono; font.pixelSize: 10; font.bold: true
            }
            HoverHandler { id: ovHover }
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

    // Overflow popup — the items beyond the first 6.
    PopupWindow {
        id: overflowPopup
        visible: root.trayOpen
        color: "transparent"
        anchor.window: root.panelWindow
        anchor.item: overflowBtn
        anchor.edges: Theme.popupEdge | Edges.Right
        anchor.gravity: Theme.popupGravity | Edges.Left
        anchor.adjustment: PopupAdjustment.Slide

        readonly property int cols: Math.max(1, Math.min(5, root.overflowItems.length))
        readonly property int rows: Math.ceil(root.overflowItems.length / cols)
        implicitWidth: cols * 25 + (cols - 1) * 4 + 16 + 32
        implicitHeight: rows * 25 + (rows - 1) * 4 + 16 + 32

        onClosed: PopupCoordinator.close(root.popupId)

        PopupCard {
            anchors.fill: parent
            open: root.trayOpen
            Grid {
                anchors { top: parent.top; left: parent.left; margins: 8 }
                columns: overflowPopup.cols
                spacing: 4
                Repeater {
                    model: root.overflowItems
                    delegate: TrayIconDelegate {
                        required property var modelData
                        item: modelData
                        root: root
                        tip: tip
                        menu: trayMenu
                        closeOnActivate: root.popupId
                    }
                }
            }
        }
    }
}
