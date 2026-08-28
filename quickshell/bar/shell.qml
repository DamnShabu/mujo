//@ pragma UseQApplication
//@ pragma IconTheme Colloid-Dark
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Niri
import "./theme"
import "./services"
import "./modules/bar"
import "./modules/launcher"
import "./modules/notifications"
import "./modules/desktop"
import "./modules/system"

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

    // Notification placement + fullscreen-suppression context (WP-04). niri
    // exposes no per-window fullscreen flag, so fullscreenActive is a heuristic:
    // a focused, non-floating window that fills its output. toastScreen selects
    // the output toasts render on (falls back to the primary).
    // Name of the output that currently holds focus ("" if none). Bars bind to this
    // to tell "my screen" from "the other one" — focusedScreenName() is a function,
    // so nothing can bind to it directly.
    property string focusedOutput: ""

    function updateNotifContext() {
        var out = focusedScreenName()
        root.focusedOutput = out
        Notifications.toastScreen = out || (Quickshell.screens.length ? Quickshell.screens[0].name : "")
        var w = wm ? wm.focusedWindow : null
        var fs = false
        if (w && !w.isFloating && out) {
            for (var i = 0; i < Quickshell.screens.length; i++) {
                var s = Quickshell.screens[i]
                if (s.name === out) { fs = (w.windowWidth >= s.width * 0.98 && w.windowHeight >= s.height * 0.9); break }
            }
        }
        Notifications.fullscreenActive = fs
    }
    Connections {
        target: wm
        function onFocusedWindowChanged() { root.updateNotifContext() }
    }
    // Focus can move between outputs without any window-focus event (switching to an
    // empty workspace on the other monitor), which used to leave focusedOutput — and
    // so the toast screen — pointing at the previous monitor.
    Connections {
        target: wm ? wm.workspaces : null
        function onDataChanged() { root.updateNotifContext() }
        function onCountChanged() { root.updateNotifContext() }
        function onModelReset() { root.updateNotifContext() }
    }
    Connections {
        target: wm ? wm.focusedWindow : null
        ignoreUnknownSignals: true
        function onLayoutChanged() { root.updateNotifContext() }
    }
    Component.onCompleted: updateNotifContext()

    // Crash detection + assistance (WP-09) — one live instance.
    CrashWatcher {}

    // Interactive AI Crash Recovery Modal
    CrashFixModal { id: crashFixModal }

    IpcHandler {
        target: "crashFix"
        function open(dataStr: string): void { crashFixModal.open(dataStr) }
        function close(): void { crashFixModal.close() }
    }

    IpcHandler {
        target: "sentinel"
        function scan(): void { SentinelService.refresh() }
        function reap(): void { SentinelService.reap() }
        function kill(pid: int): void { SentinelService.kill(pid) }
    }

    // Idle rules engine (WP-13) — owns the swayidle process.
    IdleService {}

    // Lock screen (WP-14) — native session-lock surfaces bound to Lock.locked.
    LockScreen {}

    IpcHandler {
        target: "lock"
        function lock(): void { Lock.lock() }
        function unlock(): void { Lock.unlock() }
        function toggle(): void { Lock.toggle() }
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

    // Drag-in staging shelf (WP-25): per-screen always-on-top edge drop surface;
    // the shared Shelf model also feeds the bar button/popup. State spills to
    // ~/.local/state/qsshell/shelf.json.
    ShelfSurface {}
    Connections {
        target: Shelf
        function onToggleRequested() { PopupCoordinator.toggle(root.focusedScreenName() + ":shelf") }
    }
    IpcHandler {
        target: "shelf"
        function toggle(): void { PopupCoordinator.toggle(root.focusedScreenName() + ":shelf") }
        function add(path: string): void { Shelf.addPath(path) }
        function clear(): void { Shelf.clear() }
    }

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

    // Escape closes whatever bar menu is open. Bar popups are xdg-popups of a
    // panel that never takes keyboard focus, so there is no surface to press
    // Escape *on*; this borrows the compositor keyboard for exactly as long as
    // a menu is up. Its input region is empty, so unlike the scrim it can never
    // swallow a click. The launcher is excluded — it owns its own
    // exclusive-focus surface and handles Escape itself.
    PanelWindow {
        id: popupKeys
        readonly property bool armed: PopupCoordinator.hasActivePopup
            && !PopupCoordinator.isLauncherOpen

        visible: armed
        color: "transparent"
        mask: Region {}
        exclusionMode: ExclusionMode.Ignore
        implicitWidth: 1
        implicitHeight: 1
        anchors { top: true; left: true }

        WlrLayershell.namespace: "qs-popup-keys"
        // Exclusive keyboard focus is only honoured on the Top/Overlay layers.
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: popupKeys.armed
            ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        Item {
            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: PopupCoordinator.closeAll()
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

    property var _hiddenMonitors: SettingsBus.get("bar.hiddenMonitors", [])
    Connections {
        target: SettingsBus
        function onValuesChanged() {
            var h = SettingsBus.get("bar.hiddenMonitors", [])
            if (JSON.stringify(h) !== JSON.stringify(root._hiddenMonitors)) {
                root._hiddenMonitors = h
            }
        }
    }

    Variants {
        // Drop monitors the user hid the bar on (WP-17). Build a plain JS array
        // (Quickshell.screens is a QML list without Array methods).
        model: {
            var out = []
            var hidden = root._hiddenMonitors || []
            for (var i = 0; i < Quickshell.screens.length; i++) {
                var s = Quickshell.screens[i]
                if (hidden.indexOf(s.name) < 0) out.push(s)
            }
            return out
        }

        PanelWindow {
            id: panelWindow
            required property var modelData
            property bool launcherOpen: PopupCoordinator.isLauncherOpen && (PopupCoordinator.launcherScreen === "" || PopupCoordinator.launcherScreen === modelData.name)
            screen: modelData
            visible: true
            color: "transparent"
            WlrLayershell.namespace: "qs-bar"

            // Position flip (WP-17): anchor to the configured edge.
            anchors {
                top: !Theme.barBottom
                bottom: Theme.barBottom
                left: true
                right: true
            }
            implicitHeight: Theme.barHeight + Theme.barMargin * 2

            // Auto-hide: stop reserving space and slide the groups off the edge
            // until the pointer enters the reveal band (WP-17).
            readonly property bool autoHide: SettingsBus.get("bar.autoHide", false)
            readonly property bool revealed: !autoHide || hoverZone.hovered || launcherOpen
            exclusionMode: autoHide ? ExclusionMode.Ignore : ExclusionMode.Auto

            HoverHandler { id: hoverZone }

            Bar {
                width: parent.width
                height: parent.height
                niri: wm
                screenName: panelWindow.modelData.name
                focusedOutput: root.focusedOutput
                panelWindow: panelWindow
                launcherOpen: panelWindow.launcherOpen

                // Slide out of view when auto-hidden (2px sliver stays for hover).
                y: panelWindow.revealed ? 0
                   : (Theme.barBottom ? panelWindow.height - 2 : -(panelWindow.height - 2))
                Behavior on y { NumberAnimation { duration: Anim.d(Anim.standard); easing.type: Easing.OutCubic } }
            }
        }
    }

    // Notification toasts — one click-through overlay per screen; only the
    // focused screen's overlay renders the stack (NotificationPopup, WP-04).
    Variants {
        model: Quickshell.screens
        NotificationPopup {
            active: Notifications.toastScreen === "" || Notifications.toastScreen === modelData.name
        }
    }
}
