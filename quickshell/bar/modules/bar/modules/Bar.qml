import QtQuick
import QtQuick.Layouts

Item {
    id: root
    property var niri
    property string screenName: ""
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

    // Left cluster: launcher trigger + workspaces, grouped together.
    BarGroup {
        id: leftGroup
        anchors {
            verticalCenter: parent.verticalCenter
            left: parent.left
            leftMargin: Theme.barMargin
        }
        spacing: Theme.groupPadding + 2

        LauncherPill {
            Layout.alignment: Qt.AlignVCenter
            panelWindow: root.panelWindow
            screenName: root.screenName
            launcherOpen: root.launcherOpen
        }

        Rectangle {
            Layout.preferredWidth: 1
            Layout.preferredHeight: Theme.barHeight - 14
            Layout.alignment: Qt.AlignVCenter
            color: Theme.border
        }

        Workspaces {
            Layout.alignment: Qt.AlignVCenter
            niri: root.niri
            screenName: root.screenName
        }
    }

    // Center cluster: island (WP-16) when enabled, else the bare clock pill.
    // Both open the calendar; the island bundles clock + media + weather + cava.
    ClockPill {
        anchors.centerIn: parent
        visible: !SettingsBus.get("island.enabled", true)
        panelWindow: root.panelWindow
        screenName: root.screenName
    }

    Island {
        anchors.centerIn: parent
        visible: SettingsBus.get("island.enabled", true)
        panelWindow: root.panelWindow
        screenName: root.screenName
    }

    // Right cluster: data-driven (WP-17). `bar.rightModules` sets both order and
    // visibility — drop a name to hide it, reorder to rearrange.
    BarGroup {
        id: rightGroup
        anchors {
            verticalCenter: parent.verticalCenter
            right: parent.right
            rightMargin: Theme.barMargin
        }
        spacing: 4

        Repeater {
            model: SettingsBus.get("bar.rightModules", ["llm", "network", "bluetooth", "volume", "notifications", "tray", "session"])
            delegate: Loader {
                required property var modelData
                Layout.alignment: Qt.AlignVCenter
                sourceComponent: modelData === "llm" ? llmC
                               : modelData === "network" ? netC
                               : modelData === "bluetooth" ? btC
                               : modelData === "volume" ? volC
                               : modelData === "notifications" ? notifC
                               : modelData === "tray" ? trayC
                               : modelData === "session" ? sessC
                               : null
            }
        }
    }

    Component { id: llmC;   LlmTrackerMenu  { Layout.alignment: Qt.AlignVCenter; panelWindow: root.panelWindow; screenName: root.screenName } }
    Component { id: netC;   NetworkMenu     { Layout.alignment: Qt.AlignVCenter; panelWindow: root.panelWindow; screenName: root.screenName } }
    Component { id: btC;    BluetoothMenu   { Layout.alignment: Qt.AlignVCenter; panelWindow: root.panelWindow; screenName: root.screenName } }
    Component { id: volC;   VolumeMenu      { Layout.alignment: Qt.AlignVCenter; panelWindow: root.panelWindow; screenName: root.screenName } }
    Component { id: notifC; NotificationMenu{ Layout.alignment: Qt.AlignVCenter; panelWindow: root.panelWindow; screenName: root.screenName } }
    Component { id: trayC;  SystemTray      { Layout.alignment: Qt.AlignVCenter; panelWindow: root.panelWindow; screenName: root.screenName } }
    Component { id: sessC;  SessionMenu     { Layout.alignment: Qt.AlignVCenter; panelWindow: root.panelWindow; screenName: root.screenName } }
}
