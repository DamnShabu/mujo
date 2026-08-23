import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import Qt5Compat.GraphicalEffects

// One tray item (WP-18): real icon or monogram fallback, optional recolour to
// the theme foreground, attention dot, tooltip (inline only), left-click
// activate, right-click context menu. Reused inline in the bar and in the
// overflow popup.
Rectangle {
    id: d
    property var item: null
    property var root: null
    property var tip: null
    property var menu: null
    property string closeOnActivate: ""     // non-empty ⇒ lives in the overflow popup

    Layout.alignment: Qt.AlignVCenter
    implicitWidth: 25
    implicitHeight: 22
    radius: Theme.radiusMd
    color: hh.hovered ? Theme.surfaceHover : "transparent"
    activeFocusOnTab: true

    readonly property bool hasIcon: d.item && d.item.icon && String(d.item.icon).length > 0
    readonly property bool attention: d.item && d.item.status === Status.NeedsAttention
    readonly property bool inline: d.closeOnActivate === ""

    Image {
        id: img
        visible: d.hasIcon
        anchors.centerIn: parent
        width: 18; height: 18
        source: d.hasIcon ? d.item.icon : ""
        sourceSize.width: 18; sourceSize.height: 18
        fillMode: Image.PreserveAspectFit
        layer.enabled: d.root && d.root.recolour
        layer.effect: ColorOverlay { color: Theme.text }
    }

    // Themed monogram fallback for icon-less items.
    Rectangle {
        visible: !d.hasIcon
        anchors.centerIn: parent
        width: 18; height: 18; radius: 5
        color: Theme.accentDim
        border.color: Theme.accent
        Text {
            anchors.centerIn: parent
            text: (d.item && (d.item.title || d.item.id) ? String(d.item.title || d.item.id).charAt(0) : "?").toUpperCase()
            color: Theme.accent
            font.family: Theme.fontFamily; font.pixelSize: 11; font.bold: true
        }
    }

    // Attention dot.
    Rectangle {
        visible: d.attention
        anchors { top: parent.top; right: parent.right; topMargin: 3; rightMargin: 3 }
        width: 6; height: 6; radius: 3
        color: Theme.error
    }

    HoverHandler {
        id: hh
        onHoveredChanged: {
            if (!d.tip || !d.inline) return
            if (hovered) {
                d.tip.target = d
                d.tip.text = d.item ? (d.item.tooltipTitle || d.item.title || d.item.id || "") : ""
                d.tip.status = ""
                d.tip.hovered = true
            } else {
                d.tip.hovered = false
            }
        }
    }

    function activate() {
        if (d.item) d.item.activate()
        if (d.closeOnActivate !== "") PopupCoordinator.close(d.closeOnActivate)
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: function (mouse) {
            if (mouse.button === Qt.LeftButton) d.activate()
            else if (mouse.button === Qt.RightButton && d.item && d.item.hasMenu && d.menu) d.menu.show(d.item.menu, d)
        }
    }

    Keys.onReturnPressed: d.activate()
}
