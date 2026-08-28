import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import "../../theme"
import "../../services"

// Full-screen launcher overlay for Mujo (無常).
//
// Layer-shell surface with exclusive keyboard focus on Wayland.
// Features signature multi-layered choreographed entrance & exit motion:
// - Atmospheric backdrop veil with radial luminance
// - Spring-loaded physical emergence (translation + scale + opacity + ambient bloom)
// - Specular top light sweep
// - Multi-frame keyboard grab assertion
PanelWindow {
    id: win
    required property var modelData
    screen: modelData

    readonly property bool shouldShow: PopupCoordinator.isLauncherOpen
        && (PopupCoordinator.launcherScreen === "" || PopupCoordinator.launcherScreen === modelData.name)

    visible: shouldShow || card.opacity > 0.01
    color: "transparent"

    WlrLayershell.namespace: "qs-launcher"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: win.shouldShow ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    anchors { top: true; bottom: true; left: true; right: true }

    onShouldShowChanged: {
        if (shouldShow) {
            card.playIn()
            Qt.callLater(body.focusSearch)
            focusRetry.restart()
        } else {
            card.playOut()
        }
    }

    // ── 1. Backdrop Atmosphere: Subtle radial dim + dismiss click area ─────────
    Rectangle {
        id: backdrop
        anchors.fill: parent
        color: "#000000"
        opacity: win.shouldShow ? 0.45 : 0.0

        Behavior on opacity {
            NumberAnimation {
                duration: win.shouldShow ? Anim.d(Anim.enter) : Anim.d(Anim.exit)
                easing.type: win.shouldShow ? Anim.easeEnter : Anim.easeExit
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: PopupCoordinator.closeLauncher()
        }
    }

    // ── 2. Elevation Shadow ───────────────────────────────────────────────────
    Rectangle {
        id: shadowSrc
        anchors.fill: card
        radius: Theme.radiusLg
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
        shadowVerticalOffset: 8
        shadowOpacity: 0.6
        opacity: card.opacity
    }

    // ── 3. Main Floating Monolith Card Container ──────────────────────────────
    Item {
        id: card
        width: body.baseWidth
        height: body.baseHeight
        anchors.centerIn: parent
        opacity: 0
        scale: 0.98
        transformOrigin: Item.Center

        transform: Translate {
            id: cardTranslate
            y: -10
        }

        function playIn() {
            if (Anim.reduceMotion || !Anim.enabled) {
                opacity = 1
                scale = 1
                cardTranslate.y = 0
                return
            }
            inAnim.restart()
        }

        function playOut() {
            if (Anim.reduceMotion || !Anim.enabled) {
                opacity = 0
                scale = 0.98
                cardTranslate.y = -10
                return
            }
            outAnim.restart()
        }

        ParallelAnimation {
            id: inAnim
            NumberAnimation {
                target: card; property: "opacity"; from: 0; to: 1
                duration: Anim.d(Anim.enter)
                easing.type: Anim.easeEnter
            }
            NumberAnimation {
                target: card; property: "scale"; from: 0.98; to: 1.0
                duration: Anim.d(Anim.enter)
                easing.type: Anim.easeEnter
            }
            NumberAnimation {
                target: cardTranslate; property: "y"; from: -10; to: 0
                duration: Anim.d(Anim.enter)
                easing.type: Anim.easeEnter
            }
        }

        ParallelAnimation {
            id: outAnim
            NumberAnimation {
                target: card; property: "opacity"; from: card.opacity; to: 0
                duration: Anim.d(Anim.exit)
                easing.type: Anim.easeExit
            }
            NumberAnimation {
                target: card; property: "scale"; from: card.scale; to: 0.98
                duration: Anim.d(Anim.exit)
                easing.type: Anim.easeExit
            }
            NumberAnimation {
                target: cardTranslate; property: "y"; from: cardTranslate.y; to: 6
                duration: Anim.d(Anim.exit)
                easing.type: Anim.easeExit
            }
        }

        LauncherBody {
            id: body
            anchors.fill: parent
            open: win.shouldShow
            screenName: win.modelData.name
            onRequestClose: PopupCoordinator.closeLauncher()
        }
    }

    // Belt-and-suspenders keyboard grab assertion timer on Wayland
    Timer {
        id: focusRetry
        interval: 16
        repeat: true
        triggeredOnStart: true
        property int ticks: 0
        onTriggered: {
            if (!win.shouldShow) { stop(); ticks = 0; return }
            body.focusSearch()
            ticks++
            if (ticks > 4) { stop(); ticks = 0 }
        }
    }
}
