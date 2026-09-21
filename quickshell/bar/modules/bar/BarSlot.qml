import QtQuick
import QtQuick.Layouts
import "../../theme"
import "../../components"
import "../notifications"
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

    // Hard ceiling from BarLayout: how much room this zone actually has before
    // it would run into its neighbour. -1 means unconstrained.
    property int maxWidth: -1
    // Corner radius of the group. The dock style rounds harder than the rest.
    property int clusterRadius: Theme.groupRadius
    // Width of the whole bar, so a module can size itself against the screen
    // rather than against a number someone typed once (see ActiveWindowPill).
    property int barWidth: 0

    visible: modules && modules.length > 0
    implicitHeight: Theme.barHeight
    implicitWidth: wrapInCluster ? cluster.implicitWidth : contentRow.implicitWidth
    width: root.maxWidth > 0 ? Math.min(implicitWidth, root.maxWidth) : implicitWidth

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
        radius: root.clusterRadius
        // Never spill past the zone. clip is already on, so an over-long cluster
        // is trimmed at the edge instead of drawing over its neighbour.
        width: Math.min(implicitWidth, root.width)

        Repeater {
            model: root.wrapInCluster ? (root.modules || []) : []
            delegate: Loader {
                required property var modelData
                Layout.alignment: Qt.AlignVCenter
                sourceComponent: root.componentFor(modelData)
                // A module that hides itself — no battery on this machine, no
                // tray items, no player — must give its cell back. A Loader
                // takes its implicit size from the item whatever the item's
                // visibility, which is what left a 28px hole between the volume
                // and notification icons on a desktop. Read the module's own
                // condition, never `item.visible`: Qt reflects a hidden parent
                // back down into the child's `visible`, so binding to it would
                // latch the module off for good.
                visible: item ? item.barVisible !== false : false
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
                visible: item ? item.barVisible !== false : false
            }
        }
    }

    Component { id: launcherC; LauncherPill { panelWindow: root.panelWindow; screenName: root.screenName; launcherOpen: root.launcherOpen } }
    Component { id: wsC; Workspaces { niri: root.niri; screenName: root.screenName } }
    Component { id: winC; ActiveWindowPill { niri: root.niri; screenName: root.screenName; focusedOutput: root.focusedOutput; barWidth: root.barWidth } }
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
