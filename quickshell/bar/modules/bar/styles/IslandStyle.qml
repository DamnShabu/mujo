import QtQuick
import QtQuick.Layouts
import "../../../theme"
import "../../../services"
import ".."

Item {
    id: root
    property var niri
    property string screenName: ""
    property string focusedOutput: ""
    property var panelWindow
    property bool launcherOpen: false

    readonly property var leftModules: SettingsBus.get("bar.slots.left", ["launcher", "workspaces", "activeWindow"])
    readonly property var rightModules: SettingsBus.get("bar.slots.right", ["volume", "battery", "notifications", "tray", "session"])
    readonly property int clusterGap: SettingsBus.get("bar.spacing", 6)

    BarSlot {
        modules: root.leftModules
        alignment: Qt.AlignLeft
        spacing: root.clusterGap
        wrapInCluster: true
        panelWindow: root.panelWindow
        screenName: root.screenName
        niri: root.niri
        focusedOutput: root.focusedOutput
        launcherOpen: root.launcherOpen
        anchors {
            verticalCenter: parent.verticalCenter
            left: parent.left
            leftMargin: Theme.barMargin
        }
    }

    // Interactive Island Notch in center
    Island {
        panelWindow: root.panelWindow
        screenName: root.screenName
        anchors.centerIn: parent
    }

    BarSlot {
        modules: root.rightModules
        alignment: Qt.AlignRight
        spacing: Math.max(0, root.clusterGap - 2)
        wrapInCluster: true
        panelWindow: root.panelWindow
        screenName: root.screenName
        niri: root.niri
        focusedOutput: root.focusedOutput
        launcherOpen: root.launcherOpen
        anchors {
            verticalCenter: parent.verticalCenter
            right: parent.right
            rightMargin: Theme.barMargin
        }
    }
}
