import QtQuick
import QtQuick.Layouts
import "../../theme"
import "../../components"
import "../../services"
import "../notifications"
import "../launcher"

Item {
    id: root
    property var niri
    property string screenName: ""
    property string focusedOutput: ""
    property var panelWindow
    property bool launcherOpen: false

    // Transparent panel — the bar reads as detached floating groups over the
    // wallpaper, not an edge-to-edge slab. Each cluster is its own BarGroup.

    // Catch clicks on empty / transparent space of the bar to dismiss open GUIs.
    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: PopupCoordinator.closeAll()
    }

    // Left cluster: launcher trigger + workspaces + active window nexus
    BarGroup {
        id: leftGroup
        anchors {
            verticalCenter: parent.verticalCenter
            left: parent.left
            leftMargin: Theme.barMargin
        }
        spacing: Theme.groupPadding + 2   // pills need more air than icons do
        contentAlign: Qt.AlignLeft        // pinned left, so a leaving pill never shifts the launcher
        auraColor: Theme.accent

        LauncherPill {
            Layout.alignment: Qt.AlignVCenter
            panelWindow: root.panelWindow
            screenName: root.screenName
            launcherOpen: root.launcherOpen
        }

        Workspaces {
            id: wsModule
            Layout.alignment: Qt.AlignVCenter
            niri: root.niri
            screenName: root.screenName
        }

        ActiveWindowPill {
            id: activeWinPill
            Layout.alignment: Qt.AlignVCenter
            niri: root.niri
            screenName: root.screenName
            focusedOutput: root.focusedOutput
        }
    }

    // Center cluster: island (WP-16) when enabled, else the bare clock pill.
    // Both open the calendar; the island bundles clock + media + weather + cava.
    // Only one is built — they used to both exist with one hidden, which left
    // the unused one's clock ticking once a second for the life of the session.
    Loader {
        anchors.centerIn: parent
        sourceComponent: SettingsBus.get("island.enabled", true) ? islandC : clockPillC
    }
    Component { id: clockPillC; ClockPill { panelWindow: root.panelWindow; screenName: root.screenName } }
    Component { id: islandC;    Island    { panelWindow: root.panelWindow; screenName: root.screenName } }

    // Right cluster: data-driven (WP-17). `bar.rightModules` sets both order and
    // visibility — drop a name to hide it, reorder to rearrange.
    BarGroup {
        id: rightGroup
        anchors {
            verticalCenter: parent.verticalCenter
            right: parent.right
            rightMargin: Theme.barMargin
        }
        spacing: Theme.groupPadding
        contentAlign: Qt.AlignRight
        auraColor: Theme.accent

        Repeater {
            model: SettingsBus.get("bar.rightModules", ["llm", "network", "bluetooth", "volume", "battery", "notifications", "tray", "session"])
            delegate: Loader {
                required property var modelData
                Layout.alignment: Qt.AlignVCenter
                sourceComponent: modelData === "llm" ? llmC
                               : modelData === "network" ? netC
                               : modelData === "bluetooth" ? btC
                               : modelData === "volume" ? volC
                               : modelData === "battery" ? batC
                               : modelData === "notifications" ? notifC
                               : modelData === "tray" ? trayC
                               : modelData === "session" ? sessC
                               : null
            }
        }
    }

    Component { id: llmC;   LlmTrackerMenu  { panelWindow: root.panelWindow; screenName: root.screenName } }
    Component { id: netC;   NetworkMenu     { panelWindow: root.panelWindow; screenName: root.screenName } }
    Component { id: btC;    BluetoothMenu   { panelWindow: root.panelWindow; screenName: root.screenName } }
    Component { id: volC;   VolumeMenu      { panelWindow: root.panelWindow; screenName: root.screenName } }
    Component { id: batC;   BatteryMenu     { panelWindow: root.panelWindow; screenName: root.screenName } }
    Component { id: notifC; NotificationMenu{ panelWindow: root.panelWindow; screenName: root.screenName } }
    Component { id: trayC;  SystemTray      { panelWindow: root.panelWindow; screenName: root.screenName } }
    Component { id: sessC;  SessionMenu     { panelWindow: root.panelWindow; screenName: root.screenName } }
}
