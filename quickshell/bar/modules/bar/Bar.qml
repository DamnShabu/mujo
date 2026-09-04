import QtQuick
import QtQuick.Layouts
import "../../theme"
import "../../components"
import "../../services"
import "./styles"

Item {
    id: root
    property var niri
    property string screenName: ""
    property string focusedOutput: ""
    property var panelWindow
    property bool launcherOpen: false

    // Catch clicks on empty / transparent space of the bar to dismiss open GUIs.
    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: PopupCoordinator.closeAll()
    }

    readonly property string barStyle: SettingsBus.get("bar.style", "floating")

    Loader {
        id: styleLoader
        anchors.fill: parent
        sourceComponent: {
            switch (root.barStyle) {
                case "full":    return fullStyleC
                case "island":  return islandStyleC
                case "dock":    return dockStyleC
                case "compact": return compactStyleC
                case "floating":
                default:        return floatingStyleC
            }
        }
    }

    Component {
        id: floatingStyleC
        FloatingStyle {
            niri: root.niri
            screenName: root.screenName
            focusedOutput: root.focusedOutput
            panelWindow: root.panelWindow
            launcherOpen: root.launcherOpen
        }
    }
    Component {
        id: fullStyleC
        FullWidthStyle {
            niri: root.niri
            screenName: root.screenName
            focusedOutput: root.focusedOutput
            panelWindow: root.panelWindow
            launcherOpen: root.launcherOpen
        }
    }
    Component {
        id: islandStyleC
        IslandStyle {
            niri: root.niri
            screenName: root.screenName
            focusedOutput: root.focusedOutput
            panelWindow: root.panelWindow
            launcherOpen: root.launcherOpen
        }
    }
    Component {
        id: dockStyleC
        DockStyle {
            niri: root.niri
            screenName: root.screenName
            focusedOutput: root.focusedOutput
            panelWindow: root.panelWindow
            launcherOpen: root.launcherOpen
        }
    }
    Component {
        id: compactStyleC
        CompactStyle {
            niri: root.niri
            screenName: root.screenName
            focusedOutput: root.focusedOutput
            panelWindow: root.panelWindow
            launcherOpen: root.launcherOpen
        }
    }
}
