import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Shell-side UI for the mujō keyring prompter. The `mujo-keyring-prompter`
// helper (a gcr system-prompter replacement) connects to our unix socket when
// an app needs a keyring unlocked or a secret confirmed, sends the prompt as one
// JSON line, and reads one JSON line back with the user's answer.
//
// Protocol (newline-delimited JSON, one request per connection):
//   → {"type":"password"|"confirm","title","message","description","warning",
//      "choice_label","choice_chosen","password_new","continue_label","cancel_label"}
//   ← {"response":"yes"|"no","password":"…","choice_chosen":bool}
Item {
    id: root

    property var conn: null
    property bool showing: false

    property string reqType: "password"
    property string title: ""
    property string message: ""
    property string description: ""
    property string warning: ""
    property string choiceLabel: ""
    property bool choiceChosen: false
    property bool passwordNew: false
    property string continueLabel: ""
    property string cancelLabel: ""

    readonly property string socketPath:
        (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/mujo-keyring.sock"

    function handleRequest(sock, line) {
        var r
        try {
            r = JSON.parse(line)
        } catch (e) {
            sock.write('{"response":"no"}\n'); sock.flush()
            return
        }
        root.conn = sock
        root.reqType = r.type || "password"
        root.title = r.title || ""
        root.message = r.message || ""
        root.description = r.description || ""
        root.warning = r.warning || ""
        root.choiceLabel = r.choice_label || ""
        root.choiceChosen = !!r.choice_chosen
        root.passwordNew = !!r.password_new
        root.continueLabel = r.continue_label || ""
        root.cancelLabel = r.cancel_label || ""
        passwordField.text = ""
        root.showing = true
        focusTimer.restart()
    }

    function respond(obj) {
        if (root.conn) {
            root.conn.write(JSON.stringify(obj) + "\n")
            root.conn.flush()
        }
        root.showing = false
        root.conn = null
    }

    function submit() {
        if (root.reqType === "password")
            root.respond({ response: "yes", password: passwordField.text, choice_chosen: root.choiceChosen })
        else
            root.respond({ response: "yes", choice_chosen: root.choiceChosen })
    }

    function cancel() {
        root.respond({ response: "no" })
    }

    Timer {
        id: focusTimer
        interval: 40
        onTriggered: if (root.showing && root.reqType === "password") passwordField.forceActiveFocus()
    }

    SocketServer {
        active: true
        path: root.socketPath
        handler: Socket {
            id: sock
            parser: SplitParser {
                splitMarker: "\n"
                onRead: line => root.handleRequest(sock, line)
            }
            // If the helper drops the connection (requesting app cancelled,
            // timed out, or the helper died) while we're still showing this
            // prompt, dismiss it — there's no one left to answer.
            onConnectedChanged: {
                if (!connected && root.conn === sock) {
                    root.showing = false
                    root.conn = null
                }
            }
        }
    }

    PanelWindow {
        id: win
        visible: root.showing
        color: "transparent"

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.namespace: "mujo-keyring"

        anchors { top: true; bottom: true; left: true; right: true }

        Rectangle {
            anchors.fill: parent
            color: "#000000"
            opacity: root.showing ? 0.5 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.durationSlow } }
            MouseArea { anchors.fill: parent; onClicked: root.cancel() }
        }

        Rectangle {
            id: card
            anchors.centerIn: parent
            width: 420
            implicitHeight: col.implicitHeight + 44
            radius: Theme.radiusLg
            color: Theme.bg
            border.color: Theme.borderStrong

            opacity: root.showing ? 1 : 0
            scale: root.showing ? 1 : 0.96
            Behavior on opacity { NumberAnimation { duration: Theme.durationFast } }
            Behavior on scale { NumberAnimation { duration: Theme.durationSlow; easing.type: Easing.OutCubic } }

            MouseArea { anchors.fill: parent }

            ColumnLayout {
                id: col
                anchors.fill: parent
                anchors.margins: 22
                spacing: 16

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Rectangle {
                        Layout.preferredWidth: 40
                        Layout.preferredHeight: 40
                        radius: Theme.radiusMd
                        color: Theme.accentDim
                        border.color: Theme.accent
                        MaterialIcon {
                            anchors.centerIn: parent
                            iconName: "key_vertical"
                            pixelSize: 22
                            color: Theme.accent
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        SectionLabel {
                            text: root.title !== "" ? root.title : "Keyring"
                            accented: true
                        }
                        Text {
                            Layout.fillWidth: true
                            visible: root.message !== ""
                            text: root.message
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeBody
                            wrapMode: Text.WordWrap
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    visible: root.description !== ""
                    text: root.description
                    color: Theme.textSecondary
                    font.pixelSize: Theme.fontSizeSmall
                    wrapMode: Text.WordWrap
                }

                // Password / response input.
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    visible: root.reqType === "password"

                    Text {
                        text: root.passwordNew ? "NEW PASSWORD" : "PASSWORD"
                        color: Theme.textSecondary
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeLabel
                        font.letterSpacing: Theme.labelSpacing
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 38
                        radius: Theme.radiusMd
                        color: Theme.surface
                        border.color: passwordField.activeFocus ? Theme.accent : Theme.border
                        Behavior on border.color { ColorAnimation { duration: Theme.durationFast } }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 8

                            MaterialIcon { iconName: "key"; pixelSize: 16; color: Theme.textDim }

                            TextInput {
                                id: passwordField
                                Layout.fillWidth: true
                                verticalAlignment: Text.AlignVCenter
                                color: Theme.text
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fontSizeBody
                                echoMode: TextInput.Password
                                selectByMouse: true
                                clip: true
                                onAccepted: root.submit()
                                Keys.onEscapePressed: root.cancel()
                            }
                        }
                    }
                }

                // Warning (e.g. "The unlock password was incorrect").
                Text {
                    Layout.fillWidth: true
                    visible: root.warning !== ""
                    text: root.warning
                    color: Theme.error
                    font.pixelSize: Theme.fontSizeSmall
                    wrapMode: Text.WordWrap
                }

                // Optional choice, e.g. "Automatically unlock whenever I log in".
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    visible: root.choiceLabel !== ""

                    Rectangle {
                        Layout.preferredWidth: 20
                        Layout.preferredHeight: 20
                        radius: Theme.radiusSm
                        color: root.choiceChosen ? Theme.accent : Theme.surface
                        border.color: root.choiceChosen ? Theme.accent : Theme.borderStrong
                        Behavior on color { ColorAnimation { duration: Theme.durationFast } }
                        MaterialIcon {
                            anchors.centerIn: parent
                            visible: root.choiceChosen
                            iconName: "check"
                            pixelSize: 14
                            color: Theme.accentText
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.choiceChosen = !root.choiceChosen
                        }
                    }
                    Text {
                        Layout.fillWidth: true
                        text: root.choiceLabel
                        color: Theme.textSecondary
                        font.pixelSize: Theme.fontSizeSmall
                        wrapMode: Text.WordWrap
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.choiceChosen = !root.choiceChosen
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Item { Layout.fillWidth: true }

                    DialogButton {
                        text: root.cancelLabel !== "" ? root.cancelLabel : "Cancel"
                        onClicked: root.cancel()
                    }

                    DialogButton {
                        text: root.continueLabel !== "" ? root.continueLabel
                              : (root.reqType === "password" ? "Unlock" : "Continue")
                        primary: true
                        onClicked: root.submit()
                    }
                }
            }
        }
    }
}
