import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth

Item {
    id: root
    property var panelWindow
    property string screenName: ""

    readonly property string popupId: root.screenName + ":bluetooth"
    readonly property bool menuOpen: PopupCoordinator.activeId === root.popupId
    implicitWidth: trigger.width
    implicitHeight: trigger.height

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool anyConnected: {
        if (!root.adapter || !root.adapter.devices) return false
        var devs = root.adapter.devices.values
        for (var i = 0; i < devs.length; i++) if (devs[i].connected) return true
        return false
    }

    // Device count drives the searching-vs-results switch (devices is an
    // UntypedObjectModel; count via .values and re-read on change).
    property int deviceCount: root.adapter && root.adapter.devices ? root.adapter.devices.values.length : 0
    Connections {
        target: root.adapter ? root.adapter.devices : null
        function onValuesChanged() {
            root.deviceCount = root.adapter && root.adapter.devices ? root.adapter.devices.values.length : 0
        }
    }
    readonly property bool searching: root.adapter && root.adapter.enabled && root.adapter.discovering && root.deviceCount === 0

    IconButton {
        id: trigger
        iconName: !root.adapter || !root.adapter.enabled ? "bluetooth_disabled" : (root.anyConnected ? "bluetooth_connected" : "bluetooth")
        active: root.menuOpen
        onClicked: PopupCoordinator.toggle(root.popupId)
    }

    onMenuOpenChanged: {
        if (root.menuOpen) {
            if (root.adapter) root.adapter.discovering = true
        } else if (root.adapter) {
            root.adapter.discovering = false
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

        implicitWidth: 320 + 32
        implicitHeight: content.implicitHeight + 28 + 32

        onClosed: PopupCoordinator.close(root.popupId)

        PopupCard {
            anchors.fill: parent
            open: root.menuOpen

            ColumnLayout {
                id: content
                anchors.fill: parent
                anchors.margins: 14
                spacing: 10

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    SectionLabel { text: "Bluetooth"; accented: true; Layout.alignment: Qt.AlignVCenter }
                    Spinner {
                        size: 12
                        Layout.alignment: Qt.AlignVCenter
                        visible: root.adapter && root.adapter.enabled && root.adapter.discovering && root.deviceCount > 0
                    }
                    Item { Layout.fillWidth: true }
                    ToggleSwitch {
                        Layout.alignment: Qt.AlignVCenter
                        checked: root.adapter ? root.adapter.enabled : false
                        onToggled: checked => { if (root.adapter) root.adapter.enabled = checked }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    visible: !root.adapter
                    text: "No Bluetooth adapter found."
                    color: Theme.textSecondary
                    font.pixelSize: 11
                }

                Text {
                    Layout.fillWidth: true
                    visible: root.adapter && !root.adapter.enabled
                    text: "Bluetooth is off."
                    color: Theme.textSecondary
                    font.pixelSize: 11
                }

                // Searching placeholder — spinner + text so the window never
                // sits empty while the first scan runs and no devices are known.
                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 2
                    Layout.bottomMargin: 2
                    spacing: 10
                    visible: root.searching

                    Spinner { size: 16; Layout.alignment: Qt.AlignVCenter }
                    Text {
                        text: "Searching for devices…"
                        color: Theme.textSecondary
                        font.pixelSize: 12
                        Layout.fillWidth: true
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    visible: root.adapter && root.adapter.enabled && root.deviceCount > 0
                    opacity: visible ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: Theme.reduceMotion ? 0 : Theme.durationFast } }

                    Repeater {
                        model: root.adapter ? root.adapter.devices : null

                        delegate: Rectangle {
                            id: devRow
                            required property var modelData
                            Layout.fillWidth: true
                            implicitWidth: content.width
                            implicitHeight: devRowLayout.implicitHeight + 12
                            radius: Theme.radiusMd
                            color: devHover.hovered ? Theme.surfaceHover : "transparent"

                            HoverHandler { id: devHover }

                            RowLayout {
                                id: devRowLayout
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.margins: 6
                                spacing: 8

                                MaterialIcon {
                                    iconName: devRow.modelData.connected ? "bluetooth_connected" : "bluetooth"
                                    pixelSize: 15
                                    color: devRow.modelData.connected ? Theme.accent : Theme.textSecondary
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0
                                    Text {
                                        text: devRow.modelData.deviceName || devRow.modelData.name
                                        color: Theme.text
                                        font.pixelSize: 12
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                    Text {
                                        visible: devRow.modelData.batteryAvailable
                                        text: Math.round(devRow.modelData.battery * 100) + "% battery"
                                        color: Theme.textSecondary
                                        font.pixelSize: 9
                                    }
                                }

                                Text {
                                    visible: devRow.modelData.pairing || devRow.modelData.state === BluetoothDeviceState.Connecting
                                    text: "…"
                                    color: Theme.textSecondary
                                    font.pixelSize: 11
                                }

                                Rectangle {
                                    id: actionBtn
                                    property bool hovered: actionBtnArea.containsMouse
                                    implicitWidth: actionLabel.implicitWidth + 18
                                    implicitHeight: 24
                                    radius: Theme.radiusMd
                                    color: actionBtn.hovered ? Theme.surfaceActive : Theme.surface
                                    border.color: devRow.modelData.connected ? Theme.accent : Theme.borderStrong

                                    Behavior on color { ColorAnimation { duration: Theme.durationFast } }

                                    Text {
                                        id: actionLabel
                                        anchors.centerIn: parent
                                        text: devRow.modelData.connected ? "Disconnect" : (devRow.modelData.paired ? "Connect" : "Pair")
                                        color: devRow.modelData.connected ? Theme.accent : Theme.text
                                        font.family: Theme.fontMono
                                        font.pixelSize: 10
                                    }

                                    MouseArea {
                                        id: actionBtnArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (devRow.modelData.connected) devRow.modelData.disconnect()
                                            else if (devRow.modelData.paired) devRow.modelData.connect()
                                            else devRow.modelData.pair()
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
