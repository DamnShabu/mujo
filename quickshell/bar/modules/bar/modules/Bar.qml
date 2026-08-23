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

    // Center cluster: clock (opens the calendar).
    ClockPill {
        anchors.centerIn: parent
        panelWindow: root.panelWindow
        screenName: root.screenName
    }

    // Right cluster: LLM / network / bluetooth / volume / tray status icons.
    BarGroup {
        id: rightGroup
        anchors {
            verticalCenter: parent.verticalCenter
            right: parent.right
            rightMargin: Theme.barMargin
        }
        spacing: 4

        LlmTrackerMenu { Layout.alignment: Qt.AlignVCenter; panelWindow: root.panelWindow; screenName: root.screenName }
        NetworkMenu { Layout.alignment: Qt.AlignVCenter; panelWindow: root.panelWindow; screenName: root.screenName }
        BluetoothMenu { Layout.alignment: Qt.AlignVCenter; panelWindow: root.panelWindow; screenName: root.screenName }
        VolumeMenu { Layout.alignment: Qt.AlignVCenter; panelWindow: root.panelWindow; screenName: root.screenName }
        SystemTray { Layout.alignment: Qt.AlignVCenter; panelWindow: root.panelWindow; screenName: root.screenName }
    }
}
