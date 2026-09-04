import QtQuick
import QtQuick.Layouts

Loader {
    id: root
    property string moduleId: ""
    property var panelWindow
    property string screenName: ""
    property var niri
    property string focusedOutput: ""
    property bool launcherOpen: false

    Layout.alignment: Qt.AlignVCenter
    sourceComponent: BarModuleRegistry.getComponent(moduleId)

    onLoaded: {
        if (item) {
            if ("panelWindow" in item || item.panelWindow !== undefined) {
                item.panelWindow = Qt.binding(function() { return root.panelWindow })
            }
            if ("screenName" in item || item.screenName !== undefined) {
                item.screenName = Qt.binding(function() { return root.screenName })
            }
            if ("niri" in item || item.niri !== undefined) {
                item.niri = Qt.binding(function() { return root.niri })
            }
            if ("focusedOutput" in item || item.focusedOutput !== undefined) {
                item.focusedOutput = Qt.binding(function() { return root.focusedOutput })
            }
            if ("launcherOpen" in item || item.launcherOpen !== undefined) {
                item.launcherOpen = Qt.binding(function() { return root.launcherOpen })
            }
        }
    }
}
