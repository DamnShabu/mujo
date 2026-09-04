import QtQuick
import QtQuick.Layouts
import "../../theme"
import "../../components"
import "../notifications"
import "../launcher"
import "."

Item {
    id: root
    property var modules: []
    property int alignment: Qt.AlignLeft
    property int spacing: Theme.groupPadding
    property bool wrapInCluster: true
    property var panelWindow
    property string screenName: ""
    property var niri
    property string focusedOutput: ""
    property bool launcherOpen: false

    visible: modules && modules.length > 0
    implicitHeight: Theme.barHeight
    implicitWidth: wrapInCluster ? cluster.implicitWidth : contentRow.implicitWidth

    function componentFor(id) {
        switch (id) {
            case "launcher":     return launcherC
            case "workspaces":   return wsC
            case "activeWindow": return winC
            case "clock":        return clockC
            case "media":        return mediaC
            case "weather":      return weatherC
            case "cava":         return cavaC
            case "volume":       return volC
            case "network":      return netC
            case "bluetooth":    return btC
            case "battery":      return batC
            case "notifications":return notifC
            case "tray":         return trayC
            case "llm":          return llmC
            case "session":      return sessC
            case "divider":      return divC
            case "spacer":       return spacerC
            default:             return null
        }
    }

    BarCluster {
        id: cluster
        visible: root.wrapInCluster
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: root.alignment === Qt.AlignLeft ? parent.left : undefined
        anchors.right: root.alignment === Qt.AlignRight ? parent.right : undefined
        anchors.horizontalCenter: root.alignment === Qt.AlignHCenter ? parent.horizontalCenter : undefined
        spacing: root.spacing
        contentAlign: root.alignment

        Repeater {
            model: root.wrapInCluster ? (root.modules || []) : []
            delegate: Loader {
                required property var modelData
                Layout.alignment: Qt.AlignVCenter
                sourceComponent: root.componentFor(modelData)
            }
        }
    }

    RowLayout {
        id: contentRow
        visible: !root.wrapInCluster
        anchors.centerIn: parent
        spacing: root.spacing
        Repeater {
            model: !root.wrapInCluster ? (root.modules || []) : []
            delegate: Loader {
                required property var modelData
                Layout.alignment: Qt.AlignVCenter
                sourceComponent: root.componentFor(modelData)
            }
        }
    }

    Component { id: launcherC; LauncherPill { panelWindow: root.panelWindow; screenName: root.screenName; launcherOpen: root.launcherOpen } }
    Component { id: wsC; Workspaces { niri: root.niri; screenName: root.screenName } }
    Component { id: winC; ActiveWindowPill { niri: root.niri; screenName: root.screenName; focusedOutput: root.focusedOutput } }
    Component { id: clockC; ClockPill { panelWindow: root.panelWindow; screenName: root.screenName } }
    Component { id: mediaC; MediaPill { panelWindow: root.panelWindow; screenName: root.screenName } }
    Component { id: weatherC; WeatherPill { panelWindow: root.panelWindow; screenName: root.screenName } }
    Component { id: cavaC; CavaPill { panelWindow: root.panelWindow; screenName: root.screenName } }
    Component { id: volC; VolumeMenu { panelWindow: root.panelWindow; screenName: root.screenName } }
    Component { id: netC; NetworkMenu { panelWindow: root.panelWindow; screenName: root.screenName } }
    Component { id: btC; BluetoothMenu { panelWindow: root.panelWindow; screenName: root.screenName } }
    Component { id: batC; BatteryMenu { panelWindow: root.panelWindow; screenName: root.screenName } }
    Component { id: notifC; NotificationMenu { panelWindow: root.panelWindow; screenName: root.screenName } }
    Component { id: trayC; SystemTray { panelWindow: root.panelWindow; screenName: root.screenName } }
    Component { id: llmC; LlmTrackerMenu { panelWindow: root.panelWindow; screenName: root.screenName } }
    Component { id: sessC; SessionMenu { panelWindow: root.panelWindow; screenName: root.screenName } }
    Component { id: divC; DividerPill {} }
    Component { id: spacerC; SpacerPill {} }
}
