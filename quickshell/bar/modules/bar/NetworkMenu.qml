import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Networking
import "../../theme"
import "../../components"
import "../../services"

Item {
    id: root
    property var panelWindow
    property string screenName: ""

    readonly property string popupId: root.screenName + ":network"
    readonly property bool menuOpen: PopupCoordinator.activeId === root.popupId
    property string expandedNetwork: ""
    implicitWidth: trigger.width
    implicitHeight: trigger.height

    function wifiDevice() {
        if (!Networking.devices) return null
        var devices = Networking.devices.values
        for (var i = 0; i < devices.length; i++) {
            if (devices[i].type === DeviceType.Wifi) return devices[i]
        }
        return null
    }

    property var device: wifiDevice()
    Connections {
        target: Networking.devices
        function onValuesChanged() { root.device = root.wifiDevice() }
    }

    readonly property bool connected: root.device ? root.device.connected : false

    // Number of visible networks — used to switch between the "searching…"
    // placeholder and the results list. networks is an UntypedObjectModel, so
    // count via .values and re-read it whenever the model changes.
    property int networkCount: root.device && root.device.networks ? root.device.networks.values.length : 0
    Connections {
        target: root.device ? root.device.networks : null
        function onValuesChanged() {
            root.networkCount = root.device && root.device.networks ? root.device.networks.values.length : 0
        }
    }
    onDeviceChanged: networkCount = root.device && root.device.networks ? root.device.networks.values.length : 0

    // True while we've asked for a scan but nothing has come back yet.
    readonly property bool searching: root.device && root.device.scannerEnabled && root.networkCount === 0
    readonly property bool showSsid: SettingsBus.get("bar.network.showSsid", false)
    readonly property string activeSsid: root.device && root.device.connectedNetwork ? (root.device.connectedNetwork.ssid || "Wi-Fi") : ""

    Rectangle {
        id: trigger
        implicitHeight: Theme.barHeight - 6
        implicitWidth: (root.showSsid && root.connected && root.activeSsid !== "") ? (trigRow.implicitWidth + 14) : 28
        radius: Theme.radiusSm
        color: root.menuOpen ? Theme.accentDim : (trigHh.hovered ? Theme.surfaceHover : "transparent")
        border.color: root.menuOpen ? Theme.accent : (trigHh.hovered ? Theme.borderStrong : "transparent")
        border.width: 1

        Behavior on color { ColorAnimation { duration: Anim.d(Anim.fast) } }
        Behavior on border.color { ColorAnimation { duration: Anim.d(Anim.fast) } }

        RowLayout {
            id: trigRow
            anchors.centerIn: parent
            spacing: 4

            MaterialIcon {
                iconName: !Networking.wifiHardwareEnabled ? "signal_wifi_off" : (root.connected ? "wifi" : "wifi_off")
                pixelSize: 16
                color: root.menuOpen ? Theme.accent : (trigHh.hovered ? Theme.text : (root.connected ? Theme.accent : Theme.textSecondary))
                Layout.alignment: Qt.AlignVCenter
                Behavior on color { ColorAnimation { duration: Anim.d(Anim.fast) } }
            }

            Text {
                visible: root.showSsid && root.connected && root.activeSsid !== ""
                text: root.activeSsid
                color: root.menuOpen ? Theme.accent : (trigHh.hovered ? Theme.text : Theme.textSecondary)
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                font.bold: true
                elide: Text.ElideRight
                Layout.maximumWidth: 120
                Layout.alignment: Qt.AlignVCenter
                Behavior on color { ColorAnimation { duration: Anim.d(Anim.fast) } }
            }
        }

        HoverHandler { id: trigHh; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: PopupCoordinator.toggle(root.popupId) }
    }

    onMenuOpenChanged: {
        if (root.menuOpen) {
            if (root.device) root.device.scannerEnabled = true
        } else if (root.device) {
            root.device.scannerEnabled = false
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

        // card 320 + shadow pad 16*2; content margin 14*2 + shadow pad 16*2
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
                    SectionLabel { text: "Wi-Fi"; accented: true; Layout.alignment: Qt.AlignVCenter }
                    Spinner {
                        size: 12
                        Layout.alignment: Qt.AlignVCenter
                        visible: Networking.wifiEnabled && root.device && root.device.scannerEnabled && root.networkCount > 0
                    }
                    Item { Layout.fillWidth: true }
                    ToggleSwitch {
                        Layout.alignment: Qt.AlignVCenter
                        checked: Networking.wifiEnabled
                        onToggled: checked => Networking.wifiEnabled = checked
                    }
                }

                Text {
                    Layout.fillWidth: true
                    visible: !Networking.wifiHardwareEnabled
                    text: "Wi-Fi is disabled in hardware (check airplane mode / rfkill)."
                    color: Theme.textSecondary
                    font.pixelSize: Theme.fontSizeSmall
                    wrapMode: Text.WordWrap
                }

                Text {
                    Layout.fillWidth: true
                    visible: Networking.wifiHardwareEnabled && Networking.wifiEnabled && !root.device
                    text: "No Wi-Fi adapter found."
                    color: Theme.textSecondary
                    font.pixelSize: Theme.fontSizeSmall
                }

                // Searching placeholder — spinner + text so an empty window
                // never looks broken while the first scan is in flight.
                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 2
                    Layout.bottomMargin: 2
                    spacing: 10
                    visible: Networking.wifiEnabled && root.device && root.searching

                    Spinner { size: 16; Layout.alignment: Qt.AlignVCenter }
                    Text {
                        text: "Searching for networks…"
                        color: Theme.textSecondary
                        font.pixelSize: Theme.fontSizeBody
                        Layout.fillWidth: true
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    opacity: (Networking.wifiEnabled && root.device && root.networkCount > 0) ? 1 : 0
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: Anim.d(Anim.fast) } }

                    Repeater {
                        model: root.device ? root.device.networks : null

                        delegate: Rectangle {
                            id: netRow
                            required property var modelData
                            Layout.fillWidth: true
                            implicitWidth: content.width
                            implicitHeight: netCol.implicitHeight + 12
                            radius: Theme.radiusMd
                            color: netHover.hovered ? Theme.surfaceHover : "transparent"

                            property bool expanded: root.expandedNetwork === modelData.name
                            property string error: ""

                            Connections {
                                target: netRow.modelData
                                function onConnectionFailed(reason) {
                                    netRow.error = ConnectionFailReason.toString(reason)
                                }
                            }

                            HoverHandler { id: netHover }

                            ColumnLayout {
                                id: netCol
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: 6
                                spacing: 4

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    MaterialIcon {
                                        iconName: "wifi"
                                        pixelSize: 15
                                        color: netRow.modelData.connected ? Theme.accent : Theme.textSecondary
                                    }

                                    Text {
                                        text: netRow.modelData.name
                                        color: Theme.text
                                        font.pixelSize: Theme.fontSizeBody
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        visible: Math.round(netRow.modelData.signalStrength) > 0
                                        text: Math.round(netRow.modelData.signalStrength) + "%"
                                        color: Theme.textSecondary
                                        font.family: Theme.fontMono
                                        font.pixelSize: Theme.fontSizeLabel
                                    }

                                    MaterialIcon {
                                        visible: netRow.modelData.security !== WifiSecurityType.Open
                                        iconName: "lock"
                                        pixelSize: 12
                                        color: Theme.textSecondary
                                    }

                                    Text {
                                        visible: netRow.modelData.connected
                                        text: netRow.modelData.stateChanging ? "…" : "Connected"
                                        color: Theme.accent
                                        font.pixelSize: Theme.fontSizeLabel
                                    }
                                }

                                Text {
                                    visible: netRow.error !== ""
                                    text: netRow.error
                                    color: Theme.error
                                    font.pixelSize: Theme.fontSizeLabel
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    visible: netRow.expanded
                                    spacing: 6

                                    Rectangle {
                                        Layout.fillWidth: true
                                        implicitHeight: 26
                                        radius: Theme.radiusSm
                                        color: Theme.surface
                                        border.color: pskField.activeFocus ? Theme.accent : Theme.border

                                        TextInput {
                                            id: pskField
                                            anchors.fill: parent
                                            anchors.leftMargin: 8
                                            anchors.rightMargin: 8
                                            verticalAlignment: Text.AlignVCenter
                                            color: Theme.text
                                            font.pixelSize: Theme.fontSizeSmall
                                            echoMode: TextInput.Password
                                            selectByMouse: true
                                            Keys.onReturnPressed: {
                                                netRow.modelData.connectWithPsk(pskField.text)
                                                root.expandedNetwork = ""
                                            }
                                        }
                                    }

                                    Rectangle {
                                        implicitWidth: 22
                                        implicitHeight: 22
                                        radius: Theme.radiusSm
                                        color: Theme.surface
                                        MaterialIcon { anchors.centerIn: parent; iconName: "check"; pixelSize: 13 }
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                netRow.modelData.connectWithPsk(pskField.text)
                                                root.expandedNetwork = ""
                                            }
                                        }
                                    }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                z: -1
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (netRow.modelData.connected) return
                                    if (netRow.modelData.security !== WifiSecurityType.Open && !netRow.modelData.known) {
                                        root.expandedNetwork = (root.expandedNetwork === netRow.modelData.name) ? "" : netRow.modelData.name
                                    } else {
                                        netRow.modelData.connect()
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
