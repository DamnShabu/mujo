import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../theme"
import "../../components"

// Network / VPN — the Mullvad integration, and the reference for the integration
// architecture: connection state, connect/disconnect/reconnect, location, and
// account management backed by the system keyring (the account number is never
// shown). Runtime control via the `mullvad` CLI; declarative bits (DNS blocking,
// relay lists) stay in the NixOS mullvad module.
Item {
    id: root

    property string vpnState: "…"   // was `state`: shadows Item.state. Connected / Connecting / Disconnected / Blocked
    property string relay: ""
    property bool autoConnect: false
    property string account: ""         // device/expiry summary, never the number
    property string keyringId: ""       // stored mullvad credential, if any
    property string enterAccount: ""

    readonly property bool connected: vpnState === "Connected"
    readonly property bool busy: vpnState === "Connecting" || vpnState === "Disconnecting"
    readonly property color stateColor: connected ? Theme.success
                                       : busy ? Theme.warning
                                       : (vpnState === "Blocked" ? Theme.error : Theme.textDim)

    readonly property var locations: [
        { cc: "se", n: "Sweden" }, { cc: "de", n: "Germany" }, { cc: "nl", n: "Netherlands" },
        { cc: "ch", n: "Switzerland" }, { cc: "fr", n: "France" }, { cc: "gb", n: "UK" },
        { cc: "us", n: "USA" }, { cc: "ca", n: "Canada" }, { cc: "jp", n: "Japan" },
        { cc: "sg", n: "Singapore" }, { cc: "au", n: "Australia" }, { cc: "no", n: "Norway" }
    ]

    function mullvad(args, thenRefresh) {
        Quickshell.execDetached(["mullvad"].concat(args))
        if (thenRefresh !== false) repoll.restart()
    }
    function refresh() { statusProc.running = true; autoProc.running = true; acctProc.running = true; keyProc.running = true }
    Timer { id: poll; interval: 3000; running: true; repeat: true; onTriggered: root.refresh() }
    Timer { id: repoll; interval: 600; onTriggered: root.refresh() }
    Component.onCompleted: refresh()

    Process {
        id: statusProc
        command: ["mullvad", "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                var t = this.text
                var first = t.trim().split("\n")[0].trim()
                root.vpnState = first || "Disconnected"
                var m = t.match(/Relay:\s*(\S+)/)
                root.relay = m ? m[1] : ""
            }
        }
    }
    Process {
        id: autoProc
        command: ["mullvad", "auto-connect", "get"]
        stdout: StdioCollector { onStreamFinished: root.autoConnect = /on/i.test(this.text) }
    }
    Process {
        id: acctProc
        command: ["mullvad", "account", "get"]
        stdout: StdioCollector {
            onStreamFinished: {
                var m = this.text.match(/Expires:\s*(.+)/)
                root.account = m ? ("Expires " + m[1].trim()) : (this.text.match(/not logged in/i) ? "Not logged in" : "")
            }
        }
    }
    Process {
        id: keyProc
        command: ["mujo-keyring", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.keyringId = ""
                try {
                    var items = JSON.parse(this.text)
                    for (var i = 0; i < items.length; i++)
                        if ((items[i].service || "").toLowerCase() === "mullvad") { root.keyringId = items[i].id; break }
                } catch (e) {}
            }
        }
    }

    function _doLoginAndConnect(num) {
        var clean = (num || "").replace(/\s+/g, "")
        if (clean === "" || !/^[0-9]+$/.test(clean)) return
        Quickshell.execDetached(["sh", "-lc", 'mullvad account login "$1" && mullvad connect', "sh", clean])
        repoll.restart()
    }

    // Log in with the stored keyring account, then connect.
    Process {
        id: loginStored
        stdout: StdioCollector {
            onStreamFinished: {
                var num = this.text.trim()
                root._doLoginAndConnect(num)
            }
        }
    }
    function loginWithStored() {
        if (root.keyringId === "") return
        loginStored.command = ["mujo-keyring", "get", root.keyringId]
        loginStored.running = true
    }

    // Save entered account to keyring, then log in + connect.
    Process {
        id: storeAcct
        property string num: ""
        stdinEnabled: true
        property bool sent: false
        onRunningChanged: { if (running && !sent) { write(num); stdinEnabled = false; sent = true } }
        onExited: function(code) {
            storeAcct.sent = false
            if (code === 0 && num !== "") root._doLoginAndConnect(num)
            root.enterAccount = ""; acctField.text = ""
        }
    }
    function saveAndLogin() {
        var num = root.enterAccount.replace(/\s+/g, "")
        if (num === "") return
        storeAcct.num = num
        storeAcct.command = ["mujo-keyring", "add", "Mullvad", "account", "mullvad"]
        storeAcct.running = true
    }

    MujoFlickable {
        anchors.fill: parent
        contentHeight: col.implicitHeight + 48

        ColumnLayout {
            id: col
            x: 24
            y: 24
            width: parent.width - 48
            spacing: 20

            MujoHero {
                brand: "network"
                title: "Network & VPN"
                subtitle: "Mullvad WireGuard VPN connection, secure tunneling, and keyring account integration."
                badgeText: root.vpnState.toUpperCase()
                badgeColor: root.stateColor
                activeState: root.connected
            }

            // ── Status hero card ──────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                radius: Theme.radiusLg
                color: Theme.surface
                border.color: Theme.border
                implicitHeight: hero.implicitHeight + 32
                // subtle status-tinted wash
                Rectangle {
                    anchors.fill: parent; radius: parent.radius
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Qt.rgba(root.stateColor.r, root.stateColor.g, root.stateColor.b, 0.10) }
                        GradientStop { position: 1.0; color: "transparent" }
                    }
                }
                RowLayout {
                    id: hero
                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 18; rightMargin: 18 }
                    spacing: 16
                    BrandIcon { brand: "mullvad"; size: 52 }
                    ColumnLayout {
                        spacing: 3
                        RowLayout {
                            spacing: 8
                            Rectangle { width: 10; height: 10; radius: 5; color: root.stateColor
                                SequentialAnimation on opacity {
                                    running: root.busy && !Anim.reduceMotion
                                    loops: Animation.Infinite
                                    NumberAnimation { to: 0.3; duration: 500; easing.type: Easing.InOutQuad }
                                    NumberAnimation { to: 1.0; duration: 500; easing.type: Easing.InOutQuad }
                                }
                            }
                            Text { text: root.vpnState; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeTitle + 3; font.bold: true }
                        }
                        Text {
                            text: root.relay !== "" ? ("Relay " + root.relay) : (root.account || "Mullvad VPN")
                            color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSmall
                        }
                    }
                    Item { Layout.fillWidth: true }
                    DialogButton { text: "Reconnect"; visible: root.connected; onClicked: root.mullvad(["reconnect"]) }
                    DialogButton {
                        text: root.connected ? "Disconnect" : "Connect"
                        primary: true
                        onClicked: root.mullvad([root.connected ? "disconnect" : "connect"])
                    }
                }
            }

            // ── Account (keyring-backed) ──────────────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true; spacing: 10
                SectionLabel { text: "Account" }
                RowLayout {
                    Layout.fillWidth: true; spacing: 10
                    MaterialIcon { iconName: root.keyringId !== "" ? "key" : "key_off"; pixelSize: 20; color: root.keyringId !== "" ? Theme.success : Theme.textDim }
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 1
                        Text { text: root.keyringId !== "" ? "Account stored in keyring" : "No account stored"; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeBody }
                        Text { text: root.account; visible: root.account !== ""; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSmall }
                    }
                    DialogButton { text: "Log in with stored"; enabled: root.keyringId !== ""; opacity: root.keyringId !== "" ? 1 : 0.4; onClicked: root.loginWithStored() }
                }
                RowLayout {
                    Layout.fillWidth: true; spacing: 8
                    TextField {
                        id: acctField
                        Layout.fillWidth: true
                        placeholder: "Mullvad account number"
                        password: true
                        onTextChanged: root.enterAccount = text
                        onAccepted: root.saveAndLogin()
                    }
                    DialogButton { text: "Save to keyring & log in"; primary: true; enabled: root.enterAccount.trim() !== ""; onClicked: root.saveAndLogin() }
                }
            }

            // ── Location ──────────────────────────────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true; spacing: 10
                SectionLabel { text: "Location" }
                Flow {
                    Layout.fillWidth: true; spacing: 7
                    Repeater {
                        model: root.locations
                        delegate: DisplayChip {
                            required property var modelData
                            label: modelData.n
                            selected: root.relay.indexOf(modelData.cc + "-") === 0
                            onClicked: root.mullvad(["relay", "set", "location", modelData.cc])
                        }
                    }
                }
            }

            // ── Behavior ──────────────────────────────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true; spacing: 10
                SectionLabel { text: "Behavior" }
                DeviceToggle {
                    label: "Auto-connect at login"; desc: "Establish the tunnel automatically when the daemon starts"
                    checked: root.autoConnect
                    onToggledTo: function(c) { root.mullvad(["auto-connect", "set", c ? "on" : "off"]) }
                }
            }

            Text {
                Layout.fillWidth: true
                text: "DNS content blocking and relay lists are managed declaratively in the NixOS mullvad module."
                color: Theme.textDim
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                wrapMode: Text.WordWrap
            }
            Item { implicitHeight: 4 }
        }
    }
}
