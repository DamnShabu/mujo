import QtQuick
import QtQuick.Layouts
import "../../../theme"
import "../../../services"
import ".."

Rectangle {
    id: root
    property var niri
    property string screenName: ""
    property string focusedOutput: ""
    property var panelWindow
    property bool launcherOpen: false

    anchors.fill: parent
    color: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, Theme.surface.a * Theme.barGroupOpacity)
    border.width: 1
    border.color: Theme.border

    readonly property var leftModules: SettingsBus.get("bar.slots.left", ["launcher", "workspaces", "activeWindow"])
    readonly property var centerModules: SettingsBus.get("bar.slots.center", ["clock", "weather"])
    readonly property var rightModules: SettingsBus.get("bar.slots.right", ["llm", "network", "bluetooth", "volume", "battery", "notifications", "tray", "session"])
    readonly property int clusterGap: SettingsBus.get("bar.spacing", 8)

    BarSlot {
        modules: root.leftModules
        alignment: Qt.AlignLeft
        spacing: root.clusterGap
        wrapInCluster: false
        panelWindow: root.panelWindow
        screenName: root.screenName
        niri: root.niri
        focusedOutput: root.focusedOutput
        launcherOpen: root.launcherOpen
        anchors {
            verticalCenter: parent.verticalCenter
            left: parent.left
            leftMargin: 12
        }
    }

    BarSlot {
        modules: root.centerModules
        alignment: Qt.AlignHCenter
        spacing: root.clusterGap
        wrapInCluster: false
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
        spacing: root.clusterGap
        wrapInCluster: false
        panelWindow: root.panelWindow
        screenName: root.screenName
        niri: root.niri
        focusedOutput: root.focusedOutput
        launcherOpen: root.launcherOpen
        anchors {
            verticalCenter: parent.verticalCenter
            right: parent.right
            rightMargin: 12
        }
    }
}
