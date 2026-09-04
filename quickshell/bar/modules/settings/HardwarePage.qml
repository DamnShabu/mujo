import QtQuick
import QtQuick.Layouts
import "../../theme"
import "../../components"

// Hardware & Devices — Displays, Input & Keys, Network & VPN, Power & Sleep,
// and Virtual Machines.
Item {
    id: root

    property string brand: "display"
    property string title: "Hardware"
    property string subtitle: "Displays, input devices, keyboard shortcuts, network VPN, power & virtual machines."
    property bool isNixos: true

    property string tab: "displays"   // displays | input | network | power | vm
    readonly property var tabIds: ["displays", "input", "network", "power", "vm", "shortcuts", "vpn", "weather"]

    readonly property var cardTabMap: ({
        "Arrangement": "displays",
        "Keyboard": "input",
        "Pointer": "input",
        "Keyboard Shortcuts": "input",
        "Mullvad WireGuard Tunnel": "network",
        "Keyring Credentials & Login": "network",
        "Relay Locations & Exit Nodes": "network",
        "Current Atmospheric Conditions": "network",
        "Location & Geocoding": "network",
        "Idle & Power": "power",
        "Virtual Machines": "vm"
    })

    function revealCard(name) {
        if (name === "shortcuts") { root.tab = "input"; return true }
        if (name === "vpn" || name === "weather") { root.tab = "network"; return true }
        if (root.tabIds.indexOf(name) >= 0) {
            root.tab = name
            return true
        }
        var targetTab = root.cardTabMap[name]
        if (targetTab) {
            root.tab = targetTab
            var flick = _getActiveFlickable()
            if (flick) _scrollFlickToCard(flick, name)
            return true
        }
        return false
    }

    function _getActiveFlickable() {
        if (root.tab === "displays") return flickDisplays
        if (root.tab === "input") return flickInput
        if (root.tab === "network") return flickNetwork
        if (root.tab === "power") return flickPower
        if (root.tab === "vm") return flickVm
        return null
    }

    function _scrollFlickToCard(flick, cardTitle) {
        var card = _findCard(flick.contentItem, cardTitle)
        if (!card) return
        var maxY = Math.max(0, flick.contentHeight - flick.height)
        var p = card.mapToItem(flick.contentItem, 0, 0)
        flick.contentY = Math.max(0, Math.min(p.y, maxY))
    }

    function _findCard(node, cardTitle) {
        if (!node) return null
        var kids = node.children
        for (var i = 0; i < kids.length; i++) {
            var c = kids[i]
            if (c.collapsible !== undefined && c.title === cardTitle) return c
            var hit = _findCard(c, cardTitle)
            if (hit) return hit
        }
        return null
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 14

        MujoSegmented {
            Layout.alignment: Qt.AlignLeft
            model: [
                { id: "displays", label: "Displays",         icon: "monitor" },
                { id: "input",    label: "Input & Keys",     icon: "keyboard" },
                { id: "network",  label: "Network & VPN",    icon: "vpn_key" },
                { id: "power",    label: "Power & Sleep",    icon: "power_settings_new" },
                { id: "vm",       label: "Virtual Machines", icon: "dns" }
            ]
            current: root.tab
            onSelected: function(id) { root.tab = id }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            MujoFlickable {
                id: flickDisplays
                anchors.fill: parent
                visible: root.tab === "displays"
                contentHeight: colDisplays.implicitHeight + 20

                ColumnLayout {
                    id: colDisplays
                    width: parent.width
                    spacing: 14
                    DisplaysGroup { Layout.fillWidth: true }
                }
            }

            MujoFlickable {
                id: flickInput
                anchors.fill: parent
                visible: root.tab === "input"
                contentHeight: colInput.implicitHeight + 20

                ColumnLayout {
                    id: colInput
                    width: parent.width
                    spacing: 14
                    InputGroup { Layout.fillWidth: true }
                    ShortcutsGroup { Layout.fillWidth: true }
                }
            }

            MujoFlickable {
                id: flickNetwork
                anchors.fill: parent
                visible: root.tab === "network"
                contentHeight: colNetwork.implicitHeight + 20

                ColumnLayout {
                    id: colNetwork
                    width: parent.width
                    spacing: 14
                    NetworkGroup { Layout.fillWidth: true }
                    WeatherGroup { Layout.fillWidth: true }
                }
            }

            MujoFlickable {
                id: flickPower
                anchors.fill: parent
                visible: root.tab === "power"
                contentHeight: colPower.implicitHeight + 20

                ColumnLayout {
                    id: colPower
                    width: parent.width
                    spacing: 14
                    IdlePowerGroup { Layout.fillWidth: true }
                }
            }

            MujoFlickable {
                id: flickVm
                anchors.fill: parent
                visible: root.tab === "vm"
                contentHeight: colVm.implicitHeight + 20

                ColumnLayout {
                    id: colVm
                    width: parent.width
                    spacing: 14
                    VmGroup { Layout.fillWidth: true }
                }
            }
        }
    }
}

