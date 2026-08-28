import QtQuick
import "../../components"
import "../../services"

// Bar trigger for the launcher. The launcher surface itself lives in
// Launcher.qml (a layer-shell overlay owned by shell.qml); this is just the
// button that toggles it via PopupCoordinator.
IconButton {
    id: root
    property var panelWindow          // kept for Bar wiring compatibility
    property string screenName: ""
    property bool launcherOpen: false // (unused; overlay derives its own state)

    iconName: "search"
    active: PopupCoordinator.isLauncherOpen
        && (PopupCoordinator.launcherScreen === "" || PopupCoordinator.launcherScreen === root.screenName)

    onClicked: PopupCoordinator.toggleLauncher(root.screenName)
}
