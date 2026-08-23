//@ pragma UseQApplication
//@ pragma IconTheme Colloid-Dark
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Niri
import "./modules/bar/modules"
import "./modules/desktop/modules"

ShellRoot {
    id: root

    Niri {
        id: wm
        Component.onCompleted: {
            connect()
            Launch.wm = wm // lets Launch dismiss the "Launching…" pill on window-open
        }

        onConnected: console.info("Connected to niri")
        onErrorOccurred: function(error) {
            console.error("Niri error:", error)
        }
    }

    function workspaceIsFocused(ws) {
        if (!ws) return false
        if (ws.isFocused !== undefined) return !!ws.isFocused
        if (ws.isActive !== undefined) return !!ws.isActive
        return false
    }

    function focusedScreenName() {
        if (!wm || !wm.workspaces) return ""
        for (var i = 0; i < wm.workspaces.count; i++) {
            var ws = wm.workspaces.get(i)
            if (workspaceIsFocused(ws)) return ws.output || ""
        }
        return ""
    }

    IpcHandler {
        target: "launcher"

        function toggle(): void {
            PopupCoordinator.toggleLauncher(root.focusedScreenName())
        }

        function open(): void {
            PopupCoordinator.openLauncher(root.focusedScreenName())
        }

        function close(): void {
            PopupCoordinator.closeLauncher()
        }
    }

    // Session-wide polkit authentication agent + themed prompt (one instance,
    // renders its own Overlay layer-shell surface when a request arrives).
    PolkitPrompt {}

    // Shell-side UI for the mujō keyring prompter (talks to the
    // mujo-keyring-prompter helper over a unix socket).
    KeyringPrompt {}

    // Per-screen wallpaper (image / video) with optional cursor-tracking
    // zoom/pan, plus blurred backdrop surfaces for niri's overview.
    // Config: ~/.config/quickshell/wallpaper.json  (managed by `mujo wallpaper`).
    Wallpaper {}

    // Right-click context menu on the empty desktop (per screen, below windows).
    DesktopMenu {}

    // Draggable, persistent desktop widgets (clock/weather/system), per screen.
    // Config: ~/.config/qsshell/widgets.json (managed by `mujo widgets`).
    DesktopWidgets {}

    // Multi-screen dismissal scrim: captures clicks outside any open GUI/menu
    // to close active popups/launcher immediately.
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: scrimWindow
            required property var modelData
            screen: modelData

            WlrLayershell.namespace: "qs-scrim"
            // Sit *below* the bar (Top) and its popups, but above the wallpaper
            // (Background). If the scrim shared the bar's layer it would re-commit
            // on top each time it became visible and swallow the next click —
            // that's what forced multiple clicks to switch/close menus.
            WlrLayershell.layer: WlrLayer.Bottom
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            visible: PopupCoordinator.hasActivePopup

            MouseArea {
                anchors.fill: parent
                onClicked: PopupCoordinator.closeAll()
            }
        }
    }

    // App launcher overlay — one per screen, shows on the focused one. Owns its
    // own layer-shell surface with exclusive keyboard focus (see Launcher.qml).
    Variants {
        model: Quickshell.screens
        Launcher {}
    }

    // Bottom-center "launching…" indicator, shown on the initiating screen while
    // an app spins up (driven by the Launch singleton). See LaunchFeedback.qml.
    Variants {
        model: Quickshell.screens
        LaunchFeedback {}
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: panelWindow
            property var modelData
            property bool launcherOpen: PopupCoordinator.isLauncherOpen && (PopupCoordinator.launcherScreen === "" || PopupCoordinator.launcherScreen === modelData.name)
            screen: modelData
            visible: true
            color: "transparent"
            WlrLayershell.namespace: "qs-bar"
            anchors {
                top: true
                left: true
                right: true
            }
            implicitHeight: Theme.barHeight + Theme.barMargin * 2

            Bar {
                anchors.fill: parent
                niri: wm
                screenName: panelWindow.modelData.name
                panelWindow: panelWindow
                launcherOpen: panelWindow.launcherOpen
            }
        }
    }
}
