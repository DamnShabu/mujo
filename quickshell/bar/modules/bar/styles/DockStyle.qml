import QtQuick
import QtQuick.Layouts
import "../../../theme"
import "../../../components"
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
    readonly property var combinedModules: leftModules.concat(centerModules).concat(rightModules)

    BarCluster {
        anchors.centerIn: parent
        spacing: 8
        radius: Theme.radiusLg
        implicitHeight: Math.max(Theme.barHeight, 38)
        auraColor: Theme.accent

        Repeater {
            model: root.combinedModules
            delegate: BarModuleLoader {
                required property var modelData
                moduleId: modelData
                panelWindow: root.panelWindow
                screenName: root.screenName
                niri: root.niri
                focusedOutput: root.focusedOutput
                launcherOpen: root.launcherOpen
            }
        }
    }
}
