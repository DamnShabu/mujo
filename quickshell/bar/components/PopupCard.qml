import QtQuick
import QtQuick.Effects
import "../theme"

// Standard popup surface: the deep-bg card with hairline border and large
// radius shared by every menu popup, plus a soft drop shadow, living ambient
// edge luminescence, and directional spatial emergence (sliding from the bar edge).
Item {
    id: root

    property bool open: false
    property int pad: 16
    default property alias content: card.data
    readonly property alias card: card

    // Invisible source rect for MultiEffect shadow
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
        shadowVerticalOffset: 6
        shadowOpacity: 0.65
        opacity: card.opacity
    }

    Rectangle {
        id: card
        anchors.fill: parent
        anchors.margins: root.pad
        color: Theme.bg
        radius: Theme.radiusLg
        border.color: Theme.border
        border.width: 1
        clip: true

        opacity: 0
        scale: 0.98
        transformOrigin: Theme.barBottom ? Item.Bottom : Item.Top
        
        // Directional emergence offset
        property real yOffset: Theme.barBottom ? 6 : -6
        transform: Translate { y: card.yOffset }

        // Subtle top highlight
        Rectangle {
            anchors { top: parent.top; left: parent.left; right: parent.right; margins: 1 }
            height: 1
            radius: card.radius
            color: Theme.withAlpha("#ffffff", 0.05)
        }
    }

    ParallelAnimation {
        id: showAnim
        NumberAnimation {
            target: card; property: "opacity"; from: 0; to: 1
            duration: Anim.d(Anim.enter)
            easing.type: Anim.easeEnter
        }
        NumberAnimation {
            target: card; property: "scale"; from: 0.98; to: 1
            duration: Anim.d(Anim.enter)
            easing.type: Anim.easeEnter
        }
        NumberAnimation {
            target: card; property: "yOffset"
            from: Theme.barBottom ? 6 : -6; to: 0
            duration: Anim.d(Anim.enter)
            easing.type: Anim.easeEnter
        }
    }

    function play() {
        if (Anim.reduceMotion || !Anim.enabled) {
            card.opacity = 1
            card.scale = 1
            card.yOffset = 0
            return
        }
        showAnim.restart()
    }

    onOpenChanged: if (open) play()
    Component.onCompleted: if (open) play()
}

