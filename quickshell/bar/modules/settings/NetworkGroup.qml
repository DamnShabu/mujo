import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../theme"
import "../../components"

// Network & Mullvad VPN Integration Group.
ColumnLayout {
    id: root
    Layout.fillWidth: true
    spacing: 14

    property string vpnState: "…"
    property string relay: ""
    property bool autoConnect: false
    property string account: ""
    property string keyringId: ""
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
    Timer { id: poll; interval: 3000; running: root.visible; repeat: true; triggeredOnStart: true; onTriggered: root.refresh() }
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

    Process {
        id: loginStored
        stdout: StdioCollector { onStreamFinished: root._doLoginAndConnect(this.text.trim()) }
    }
    function loginWithStored() {
        if (root.keyringId === "") return
        loginStored.command = ["mujo-keyring", "get", root.keyringId]
        loginStored.running = true
    }

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

    // ── 1. Status Hero Card ───────────────────────────────────────────────────
    MujoCard {
        title: "Mullvad WireGuard Tunnel"
        iconName: "vpn_lock"
        badgeText: root.vpnState.toUpperCase()
        badgeColor: root.stateColor

        RowLayout {
            Layout.fillWidth: true
            spacing: 16

            BrandIcon { brand: "mullvad"; size: 44 }

            ColumnLayout {
                spacing: 2
                RowLayout {
                    spacing: 8
                    Rectangle {
                        width: 10; height: 10; radius: 5; color: root.stateColor
                        SequentialAnimation on opacity {
                            running: root.busy && !Anim.reduceMotion
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.3; duration: 500; easing.type: Easing.InOutQuad }
                            NumberAnimation { to: 1.0; duration: 500; easing.type: Easing.InOutQuad }
                        }
                    }
                    Text { text: root.vpnState; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeTitle; font.bold: true }
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

    // ── 2. Keyring Credentials & Login Card ───────────────────────────────────
    MujoCard {
        title: "Keyring Credentials & Login"
        iconName: "key"
        badgeText: root.keyringId !== "" ? "KEYRING ACTIVE" : "UNAUTHENTICATED"
        badgeColor: root.keyringId !== "" ? Theme.success : Theme.warning

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                MaterialIcon { iconName: root.keyringId !== "" ? "key" : "key_off"; pixelSize: 20; color: root.keyringId !== "" ? Theme.success : Theme.textDim }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    Text { text: root.keyringId !== "" ? "Account stored in secure keyring" : "No account stored in keyring"; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeBody }
                    Text { text: root.account; visible: root.account !== ""; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSmall }
                }
                DialogButton { text: "Log in with stored"; enabled: root.keyringId !== ""; opacity: root.keyringId !== "" ? 1 : 0.4; onClicked: root.loginWithStored() }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                TextField {
                    id: acctField
                    Layout.fillWidth: true
                    placeholder: "Enter 16-digit Mullvad account number"
                    password: true
                    onTextChanged: root.enterAccount = text
                    onAccepted: root.saveAndLogin()
                }
                DialogButton { text: "Save & Log In"; primary: true; enabled: root.enterAccount.trim() !== ""; onClicked: root.saveAndLogin() }
            }
        }
    }

    // ── 3. Relay Locations & Exit Nodes Card ──────────────────────────────────
    MujoCard {
        title: "Relay Locations & Exit Nodes"
        iconName: "public"

        Flow {
            Layout.fillWidth: true
            spacing: 7
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

    // ── 4. Tunnel Automation & Behavior Card ──────────────────────────────────
    MujoCard {
        title: "Tunnel Automation & Behavior"
        iconName: "settings_ethernet"

        MujoSettingRow {
            iconName: "bolt"
            title: "Auto-connect at login"
            description: "Establish the WireGuard tunnel automatically when the desktop session starts."

            ToggleSwitch {
                checked: root.autoConnect
                onToggled: function(c) { root.mullvad(["auto-connect", "set", c ? "on" : "off"]) }
            }
        }
    }
}
