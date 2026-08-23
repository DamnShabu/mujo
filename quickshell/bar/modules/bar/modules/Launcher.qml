import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland

// Full-screen launcher overlay (one per screen, shown on the focused one).
//
// This is a layer-shell surface with *exclusive* keyboard focus — that's the
// reliable way to capture typing on Wayland. The previous launcher used a
// PopupWindow anchored to the bar plus focus/hide timers, which both dropped
// keystrokes (XDG popups don't get a keyboard grab) and added ~0.5s of latency.
// Here the surface simply maps when open (instant) and the search field is
// focused on the next frame; a fast fade+scale gives the entrance without
// delaying interaction.
PanelWindow {
    id: win
    required property var modelData
    screen: modelData

    readonly property bool shouldShow: PopupCoordinator.isLauncherOpen
        && (PopupCoordinator.launcherScreen === "" || PopupCoordinator.launcherScreen === modelData.name)

    visible: shouldShow
    color: "transparent"

    WlrLayershell.namespace: "qs-launcher"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore

    anchors { top: true; bottom: true; left: true; right: true }

    onVisibleChanged: {
        if (visible) {
            card.playIn()
            // Focus once the surface is mapped and the grab is live.
            Qt.callLater(body.focusSearch)
            focusRetry.restart()
        }
    }

    // Backdrop: subtle dim + click-anywhere-outside to dismiss.
    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: win.shouldShow ? 0.32 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.reduceMotion ? 0 : Theme.durationFast } }

        MouseArea { anchors.fill: parent; onClicked: PopupCoordinator.closeLauncher() }
    }

    // Soft drop shadow so the card reads as elevated over the wallpaper.
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
        shadowOpacity: 0.5
        opacity: card.opacity
    }

    Item {
        id: card
        width: body.baseWidth
        height: body.baseHeight
        anchors.centerIn: parent
        opacity: 0
        scale: 0.97
        transformOrigin: Item.Center

        function playIn() {
            if (Theme.reduceMotion) { opacity = 1; scale = 1; return }
            inAnim.restart()
        }

        ParallelAnimation {
            id: inAnim
            NumberAnimation {
                target: card; property: "opacity"; from: 0; to: 1
                duration: Theme.durationFast; easing.type: Easing.OutQuad
            }
            NumberAnimation {
                target: card; property: "scale"; from: 0.97; to: 1
                duration: Theme.durationSlow; easing.type: Easing.OutCubic
            }
        }

        LauncherBody {
            id: body
            anchors.fill: parent
            open: win.visible
            screenName: win.modelData.name
            onRequestClose: PopupCoordinator.closeLauncher()
        }
    }

    // Belt-and-suspenders: some compositors deliver the keyboard grab a frame
    // or two after map; re-assert focus briefly so the first keystroke lands.
    Timer {
        id: focusRetry
        interval: 16
        repeat: true
        triggeredOnStart: true
        property int ticks: 0
        onTriggered: {
            if (!win.visible) { stop(); ticks = 0; return }
            body.focusSearch()
            ticks++
            if (ticks > 4) { stop(); ticks = 0 }
        }
    }
}
