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
    readonly property var centerModules: SettingsBus.get("bar.slots.center", ["clock", "weather"])
    readonly property var rightModules: SettingsBus.get("bar.slots.right", ["llm", "network", "bluetooth", "volume", "battery", "notifications", "tray", "session"])

    BarSlot {
        modules: root.leftModules
        alignment: Qt.AlignLeft
        spacing: 3
        wrapInCluster: true
        panelWindow: root.panelWindow
        screenName: root.screenName
        niri: root.niri
        focusedOutput: root.focusedOutput
        launcherOpen: root.launcherOpen
        anchors {
            verticalCenter: parent.verticalCenter
            left: parent.left
            leftMargin: 4
        }
    }

    BarSlot {
        modules: root.centerModules
        alignment: Qt.AlignHCenter
        spacing: 3
        wrapInCluster: true
        panelWindow: root.panelWindow
        screenName: root.screenName
        niri: root.niri
        focusedOutput: root.focusedOutput
        launcherOpen: root.launcherOpen
        anchors.centerIn: parent
    }

    BarSlot {
        modules: root.rightModules
        alignment: Qt.AlignRight
        spacing: 2
        wrapInCluster: true
        panelWindow: root.panelWindow
        screenName: root.screenName
        niri: root.niri
        focusedOutput: root.focusedOutput
        launcherOpen: root.launcherOpen
        anchors {
            verticalCenter: parent.verticalCenter
            right: parent.right
            rightMargin: 4
        }
    }
}
