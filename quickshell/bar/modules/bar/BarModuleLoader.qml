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
            if (item.panelWindow !== undefined) item.panelWindow = root.panelWindow
            if (item.screenName !== undefined) item.screenName = root.screenName
            if (item.niri !== undefined) item.niri = root.niri
            if (item.focusedOutput !== undefined) item.focusedOutput = root.focusedOutput
            if (item.launcherOpen !== undefined) item.launcherOpen = root.launcherOpen
        }
    }
}
