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

        onLoaded: {
            if (item) {
                item.niri = Qt.binding(function() { return root.niri })
                item.screenName = Qt.binding(function() { return root.screenName })
                item.focusedOutput = Qt.binding(function() { return root.focusedOutput })
                item.panelWindow = Qt.binding(function() { return root.panelWindow })
                item.launcherOpen = Qt.binding(function() { return root.launcherOpen })
            }
        }
    }

    Component { id: floatingStyleC; FloatingStyle {} }
    Component { id: fullStyleC;     FullWidthStyle {} }
    Component { id: islandStyleC;   IslandStyle {} }
    Component { id: dockStyleC;     DockStyle {} }
    Component { id: compactStyleC;  CompactStyle {} }
}
