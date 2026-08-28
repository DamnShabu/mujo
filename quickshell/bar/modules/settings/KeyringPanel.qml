import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "../../theme"
import "../../components"

// Keyring / credentials manager over the Secret Service (gnome-keyring), via the
// mujo-keyring helper. Lists stored items with their service/account, lets you
// add and remove, and reveals a secret only on explicit request (masked by
// default). No custom credential store — this is the native desktop keyring.
Item {
    id: root

    property var items: []
    property string error: ""
    property string revealedId: ""
    property string revealedSecret: ""

    // add-form fields
    property string fLabel: ""
    property string fAccount: ""
    property string fService: ""

    function refresh() { listProc.running = true }

    Process {
        id: listProc
        command: ["mujo-keyring", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.items = JSON.parse(this.text); root.error = "" }
                catch (e) { root.items = []; root.error = "Keyring unavailable or locked." }
            }
        }
        stderr: StdioCollector {
            onStreamFinished: { if (this.text.trim() !== "" && root.items.length === 0) root.error = "Keyring unavailable or locked." }
        }
    }
    Component.onCompleted: refresh()

    Process {
        id: getProc
        property string forId: ""
        stdout: StdioCollector {
            onStreamFinished: { root.revealedId = getProc.forId; root.revealedSecret = this.text }
        }
    }
    function reveal(id) {
        if (root.revealedId === id) { root.revealedId = ""; root.revealedSecret = ""; return }
        getProc.forId = id
        getProc.command = ["mujo-keyring", "get", id]
        getProc.running = true
    }

    Process {
        id: rmProc
        onExited: function(code) { root.revealedId = ""; root.refresh() }
    }
    function remove(id) { rmProc.command = ["mujo-keyring", "remove", id]; rmProc.running = true }

    Process {
        id: addProc
        property string secret: ""
        property bool sent: false
        stdinEnabled: true
        onRunningChanged: {
            if (running && !sent) { write(secret); stdinEnabled = false; sent = true }
        }
        onExited: function(code) {
            addProc.sent = false
            if (code === 0) { root.fLabel = ""; root.fAccount = ""; root.fService = ""; secretField.text = ""; root.refresh() }
        }
    }
    function addItem(secret) {
        if (root.fLabel.trim() === "" || secret === "") return
        addProc.secret = secret
        addProc.command = ["mujo-keyring", "add", root.fLabel.trim(), root.fAccount.trim(), root.fService.trim()]
        addProc.running = true
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 26
        spacing: 18

        MujoHero {
            brand: "keyring"
            title: "Keyring & Secrets"
            subtitle: "Hardware-backed credentials stored in the system keyring. Secrets stay hidden until revealed."
            badgeText: (root.error !== "" ? "LOCKED" : (root.items.length + " KEYS"))
            badgeColor: root.error !== "" ? Theme.warning : Theme.accent
            activeState: root.revealedId !== ""
        }

        // ── Add form ─────────────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            radius: Theme.radiusMd
            color: Theme.surface
            border.color: Theme.border
            implicitHeight: addCol.implicitHeight + 24

            ColumnLayout {
                id: addCol
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
                spacing: 10
                SectionLabel { text: "Add credential" }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    TextField { Layout.fillWidth: true; placeholder: "Label *"; text: root.fLabel; onTextChanged: root.fLabel = text }
                    TextField { Layout.fillWidth: true; placeholder: "Service"; text: root.fService; onTextChanged: root.fService = text }
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    TextField { Layout.fillWidth: true; placeholder: "Account / username"; text: root.fAccount; onTextChanged: root.fAccount = text }
                    TextField {
                        id: secretField
                        Layout.fillWidth: true
                        placeholder: "Secret *"
                        password: true
                        onAccepted: root.addItem(text)
                    }
                    DialogButton {
                        text: "Add"
                        primary: true
                        enabled: root.fLabel.trim() !== "" && secretField.text !== ""
                        onClicked: root.addItem(secretField.text)
                    }
                }
            }
        }

        // ── List ─────────────────────────────────────────────────────────────
        ListView {
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 8
            model: root.items

            delegate: Rectangle {
                required property var modelData
                width: list.width
                implicitHeight: 58
                radius: Theme.radiusMd
                color: Theme.surface
                border.color: Theme.border

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 10
                    spacing: 12

                    Rectangle {
                        width: 36; height: 36; radius: Theme.radiusSm
                        color: Theme.accentDim
                        MaterialIcon { anchors.centerIn: parent; iconName: modelData.locked ? "lock" : "key"; pixelSize: 19; color: Theme.accent }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1
                        Text {
                            text: (modelData.service && modelData.service !== "") ? modelData.service : modelData.label
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeBody
                            font.bold: true
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        Text {
                            readonly property bool revealed: root.revealedId === modelData.id
                            text: revealed ? root.revealedSecret
                                  : (modelData.account && modelData.account !== "" ? modelData.account : modelData.label)
                            color: revealed ? Theme.accent : Theme.textSecondary
                            font.family: revealed ? Theme.fontMono : Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }

                    IconButton {
                        iconName: root.revealedId === modelData.id ? "visibility_off" : "visibility"
                        enabled: !modelData.locked
                        opacity: modelData.locked ? 0.4 : 1
                        onClicked: root.reveal(modelData.id)
                    }
                    IconButton {
                        iconName: "delete"
                        onClicked: root.remove(modelData.id)
                    }
                }
            }

            // empty / error state
            Text {
                anchors.centerIn: parent
                visible: root.items.length === 0
                horizontalAlignment: Text.AlignHCenter
                text: root.error !== "" ? root.error : "No stored credentials yet."
                color: Theme.textDim
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeBody
            }
        }
    }
}
