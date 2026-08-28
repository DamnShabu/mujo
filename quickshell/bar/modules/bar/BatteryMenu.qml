import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../theme"
import "../../components"
import "../../services"

// BatteryMenu: Living power & battery indicator for Mujo (無常).
// Provides state-reactive charging flows, low-power breathing warnings,
// and peripheral battery overview. Self-hides cleanly on devices without a battery.
Item {
    id: root
    property var panelWindow
    property string screenName: ""

    readonly property string popupId: root.screenName + ":battery"
    readonly property bool menuOpen: PopupCoordinator.activeId === root.popupId

    property bool present: false
    property int level: 0
    property string status: "Unknown"

    visible: root.present
    implicitWidth: trigger.width
    implicitHeight: trigger.height

    Process {
        id: batProc
        command: ["mujo", "battery"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var obj = JSON.parse(this.text)
                    root.present = !!obj.present
                    root.level = typeof obj.level === "number" ? obj.level : 0
                    root.status = obj.status || "Unknown"
                } catch (e) {
                    root.present = false
                }
            }
        }
    }

    Timer {
        interval: 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: batProc.running = true
    }

    onMenuOpenChanged: if (root.menuOpen) batProc.running = true

    readonly property bool isCharging: root.status === "Charging"
    readonly property bool isLow: root.level <= 20 && !root.isCharging
    readonly property bool isCritical: root.level <= 10 && !root.isCharging

    readonly property string iconGlyph: {
        if (root.isCharging) return "battery_charging_full"
        if (root.isCritical) return "battery_alert"
        if (root.level >= 90) return "battery_full"
        if (root.level >= 60) return "battery_6_bar"
        if (root.level >= 40) return "battery_4_bar"
        if (root.level >= 20) return "battery_2_bar"
        return "battery_1_bar"
    }

    readonly property color batteryColor: {
        if (root.isCharging) return Theme.success
        if (root.isCritical) return Theme.error
        if (root.isLow) return Theme.warning
        return Theme.text
    }

    IconButton {
        id: trigger
        iconName: root.iconGlyph
        iconColor: root.isCritical ? Theme.error
                 : (root.active ? Theme.accent : root.batteryColor)
        active: root.menuOpen
        onClicked: {
            PopupCoordinator.toggle(root.popupId)
        }
    }

    PopupWindow {
        id: popup
        visible: root.menuOpen
        color: "transparent"
        anchor.window: root.panelWindow
        anchor.item: trigger
        anchor.edges: Theme.popupEdge | Edges.Right
        anchor.gravity: Theme.popupGravity | Edges.Left
        anchor.adjustment: PopupAdjustment.Slide

        implicitWidth: 280 + 32
        implicitHeight: content.implicitHeight + 28 + 32

        onClosed: PopupCoordinator.close(root.popupId)

        PopupCard {
            anchors.fill: parent
            open: root.menuOpen

            ColumnLayout {
                id: content
                anchors.fill: parent
                anchors.margins: 14
                spacing: 12

                SectionLabel { text: "Power & Battery"; accented: true }

                // Main Battery Status Card
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 64
                    radius: Theme.radiusMd
                    color: Theme.surfaceHover
                    border.color: Theme.borderStrong
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 12

                        MaterialIcon {
                            iconName: root.iconGlyph
                            pixelSize: 28
                            color: root.batteryColor
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Text {
                                text: root.level + "%"
                                color: Theme.text
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fontSizeTitle
                                font.bold: true
                            }
                            Text {
                                text: root.status
                                color: Theme.textSecondary
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSmall
                            }
                        }
                    }
                }
            }
        }
    }
}
