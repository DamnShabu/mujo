import QtQuick
import QtQuick.Layouts
import Quickshell.Services.SystemTray
import QtQuick.Effects
import "../../theme"
import "../../services"

// One tray item (WP-18): real icon or monogram fallback, optional recolour to
// the theme foreground, attention dot, tooltip, left-click activate, right-click
// context menu. Used both inline in the bar (compact) and in the Windows-style
// flyout popup (36x36 tile).
Rectangle {
    id: d
    property var item: null
    property var root: null
    property var tip: null
    property var menu: null
    property bool inPopup: false
    property string closeOnActivate: ""     // non-empty ⇒ lives in the overflow popup

    Layout.alignment: Qt.AlignVCenter
    implicitWidth: d.inPopup ? 36 : 25
    implicitHeight: d.inPopup ? 36 : 22
    radius: Theme.radiusMd
    color: ma.pressed ? Theme.surfaceActive : (hh.hovered ? Theme.surfaceHover : "transparent")
    activeFocusOnTab: true

    Behavior on color { ColorAnimation { duration: Anim.d(Anim.fast) } }

    readonly property bool hasIcon: d.item && d.item.icon && String(d.item.icon).length > 0
    readonly property bool attention: d.item && d.item.status === Status.NeedsAttention
    readonly property int iconDimension: d.inPopup ? 20 : 18

    Image {
        id: img
        visible: d.hasIcon
        anchors.centerIn: parent
        width: d.iconDimension; height: d.iconDimension
        source: d.hasIcon ? d.item.icon : ""
        sourceSize.width: 36; sourceSize.height: 36
        smooth: true
        mipmap: true
        fillMode: Image.PreserveAspectFit
        layer.enabled: d.root && d.root.recolour
        layer.effect: MultiEffect { colorization: 1.0; colorizationColor: Theme.text }
    }

    // Themed monogram fallback for icon-less items.
    Rectangle {
        visible: !d.hasIcon
        anchors.centerIn: parent
        width: d.iconDimension; height: d.iconDimension
        radius: d.inPopup ? 6 : 5
        color: Theme.accentDim
        border.color: Theme.accent
        Text {
            anchors.centerIn: parent
            text: (d.item && (d.item.title || d.item.id) ? String(d.item.title || d.item.id).charAt(0) : "?").toUpperCase()
            color: Theme.accent
            font.family: Theme.fontFamily
            font.pixelSize: d.inPopup ? Theme.fontSizeBody : Theme.fontSizeSmall
            font.bold: true
        }
    }

    // Attention dot.
    Rectangle {
        visible: d.attention
        anchors {
            top: parent.top
            right: parent.right
            topMargin: d.inPopup ? 4 : 3
            rightMargin: d.inPopup ? 4 : 3
        }
        width: 6; height: 6; radius: 3
        color: Theme.error
    }

    HoverHandler {
        id: hh
        onHoveredChanged: {
            if (!d.tip) return
            if (hovered) {
                d.tip.target = d
                d.tip.text = d.item ? (d.item.tooltipTitle || d.item.title || d.item.id || "") : ""
                d.tip.status = ""
                d.tip.hovered = true
            } else {
                if (d.tip.target === d) d.tip.hovered = false
            }
        }
    }

    function activate() {
        if (d.item) d.item.activate()
        if (d.closeOnActivate !== "") PopupCoordinator.close(d.closeOnActivate)
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: function (mouse) {
            if (mouse.button === Qt.LeftButton) {
                d.activate()
            } else if (mouse.button === Qt.RightButton && d.item && d.item.hasMenu && d.menu) {
                d.menu.show(d.item.menu, d)
            }
        }
    }

    Keys.onReturnPressed: d.activate()
}
