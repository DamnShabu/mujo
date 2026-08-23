import QtQuick
import QtQuick.Effects

// Standard popup surface: the deep-bg card with hairline border and large
// radius shared by every menu popup, plus a soft drop shadow (so cards read as
// elevated over the wallpaper) and a subtle fade+scale entrance animation.
//
// Usage: place inside a PopupWindow, `anchors.fill: parent`, bind `open` to the
// popup's visible/menuOpen flag, and put the popup content as children. The
// window must reserve `pad` px of transparent room on every side for the shadow
// (see the implicitWidth/implicitHeight formulas in the menu components).
Item {
    id: root

    // Drives the entrance animation. Bind to the popup's open flag.
    property bool open: false
    // Transparent breathing room around the card, used by the shadow.
    property int pad: 16
    // Content goes inside the card.
    default property alias content: card.data
    // Expose the card so callers can reference its usable geometry if needed.
    readonly property alias card: card

    // Invisible source rect the MultiEffect blurs into a shadow behind the card.
    Rectangle {
        id: shadowSrc
        anchors.fill: card
        radius: card.radius
        color: "#000000"
        visible: false
        layer.enabled: true
    }

    MultiEffect {
        anchors.fill: shadowSrc
        source: shadowSrc
        autoPaddingEnabled: true
        shadowEnabled: true
        shadowColor: "#000000"
        shadowBlur: 1.0
        shadowVerticalOffset: 5
        shadowOpacity: 0.55
        opacity: card.opacity
    }

    Rectangle {
        id: card
        anchors.fill: parent
        anchors.margins: root.pad
        color: Theme.bg
        radius: Theme.radiusLg
        border.color: Theme.border
        clip: true

        opacity: 0
        scale: 0.96
        transformOrigin: Item.Top
    }

    ParallelAnimation {
        id: showAnim
        NumberAnimation {
            target: card; property: "opacity"; from: 0; to: 1
            duration: Theme.reduceMotion ? 0 : Theme.durationFast
            easing.type: Easing.OutQuad
        }
        NumberAnimation {
            target: card; property: "scale"; from: 0.96; to: 1
            duration: Theme.reduceMotion ? 0 : Theme.durationSlow
            easing.type: Easing.OutCubic
        }
    }

    function play() {
        if (Theme.reduceMotion) { card.opacity = 1; card.scale = 1; return }
        showAnim.restart()
    }

    onOpenChanged: if (open) play()
    Component.onCompleted: if (open) play()
}
