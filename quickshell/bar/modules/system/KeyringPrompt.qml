import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../../theme"
import "../../components"

// Shell-side UI for the mujō keyring prompter. The `mujo-keyring-prompter`
// helper (a gcr system-prompter replacement) connects to our unix socket when
// an app needs a keyring unlocked or a secret confirmed, sends the prompt as one
// JSON line, and reads one JSON line back with the user's answer.
Item {
    id: root

    property var conn: null
    property bool showing: false
    property bool passwordRevealed: false

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
        root.passwordRevealed = false
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
        interval: 30
        repeat: true
        triggeredOnStart: true
        property int ticks: 0
        onTriggered: {
            if (!root.showing) { stop(); ticks = 0; return }
            if (root.reqType === "password") passwordField.forceActiveFocus()
            ticks++
            if (ticks > 5) { stop(); ticks = 0 }
        }
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

        // Backdrop scrim
        Rectangle {
            anchors.fill: parent
            color: "#000000"
            opacity: root.showing ? 0.55 : 0.0
            Behavior on opacity { NumberAnimation { duration: Anim.d(Anim.enter); easing.type: Anim.easeEnter } }
            MouseArea { anchors.fill: parent; onClicked: root.cancel() }
        }

        // Ambient Radiant Bloom
        Rectangle {
            id: radiantBloom
            anchors.centerIn: card
            width: card.width + 48
            height: card.height + 48
            radius: Theme.radiusLg + 24
            color: root.warning !== "" ? Theme.error : Theme.accent
            opacity: root.showing && Anim.ambient ? Anim.breath(0.04, 0.12) : 0.0
            scale: root.showing && Anim.ambient ? Anim.breath(0.98, 1.03) : 0.95
            visible: !Anim.reduceMotion

            Behavior on color { ColorAnimation { duration: Anim.d(Anim.fast) } }
            Behavior on opacity { NumberAnimation { duration: Anim.d(Anim.enter) } }
            Behavior on scale { NumberAnimation { duration: Anim.d(Anim.slow); easing.type: Anim.easeStandard } }
        }

        // Elevation Drop Shadow
        Rectangle {
            id: shadowSrc
            anchors.fill: card
            radius: Theme.radiusLg
            color: "#000000"
            visible: false
            layer.enabled: true
        }
        MultiEffect {
            anchors.fill: shadowSrc
            source: shadowSrc
            autoPaddingEnabled: true
            shadowEnabled: true
            shadowColor: "#000000"
            shadowBlur: 1.2
            shadowVerticalOffset: 8
            shadowOpacity: 0.65
            opacity: card.opacity
        }

        Rectangle {
            id: card
            anchors.centerIn: parent
            width: 440
            implicitHeight: col.implicitHeight + 44
            radius: Theme.radiusLg
            color: Theme.bg
            border.color: root.warning !== ""
                          ? Theme.error
                          : (root.showing && Anim.ambient ? Theme.withAlpha(Theme.borderStrong, Anim.breath(0.6, 0.9)) : Theme.borderStrong)
            border.width: 1
            clip: true

            Behavior on border.color { ColorAnimation { duration: Anim.d(Anim.fast) } }

            opacity: root.showing ? 1.0 : 0.0
            scale: root.showing ? 1.0 : 0.94
            Behavior on opacity { NumberAnimation { duration: Anim.d(Anim.enter); easing.type: Anim.easeEnter } }
            Behavior on scale {
                NumberAnimation {
                    duration: Anim.d(Anim.slow)
                    easing.type: Anim.easeStandard
                }
            }

            // Specular top highlight line
            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 1
                color: Theme.withAlpha("#ffffff", 0.06)
            }

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
                        implicitWidth: 44
                        implicitHeight: 44
                        radius: Theme.radiusMd
                        color: Theme.accentDim
                        border.color: Theme.accent
                        border.width: 1
                        Layout.alignment: Qt.AlignTop

                        scale: root.showing && Anim.ambient ? Anim.breath(0.97, 1.03) : 1.0
                        Behavior on scale { NumberAnimation { duration: Anim.d(Anim.slow); easing.type: Anim.easeStandard } }

                        MaterialIcon {
                            anchors.centerIn: parent
                            iconName: "key_vertical"
                            pixelSize: 24
                            color: Theme.accent
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 3
                        Layout.alignment: Qt.AlignVCenter

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            SectionLabel {
                                text: root.title !== "" ? root.title : "KEYRING SECURITY"
                                accented: true
                            }

                            Item { Layout.fillWidth: true }

                            Rectangle {
                                implicitWidth: 64
                                implicitHeight: 18
                                radius: 9
                                color: Theme.withAlpha(Theme.accent, 0.14)
                                border.color: Theme.accent
                                border.width: 1

                                Text {
                                    anchors.centerIn: parent
                                    text: "KEYRING"
                                    color: Theme.accent
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.fontSizeLabel - 2
                                    font.bold: true
                                }
                            }
                        }

                        Text {
                            text: root.message !== "" ? root.message : "Unlock Secret Keyring"
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeTitle + 2
                            font.bold: true
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    visible: root.description !== ""
                    text: root.description
                    color: Theme.textSecondary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    wrapMode: Text.WordWrap
                }

                // Password / response input
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
                        implicitHeight: 42
                        radius: Theme.radiusMd
                        color: Theme.surface
                        border.color: passwordField.activeFocus ? Theme.accent : Theme.border
                        border.width: passwordField.activeFocus ? 2 : 1
                        clip: true

                        Behavior on border.color { ColorAnimation { duration: Anim.d(Anim.fast) } }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 8
                            spacing: 8

                            MaterialIcon {
                                iconName: "key"
                                pixelSize: 18
                                color: passwordField.activeFocus ? Theme.accent : Theme.textDim
                            }

                            TextInput {
                                id: passwordField
                                Layout.fillWidth: true
                                verticalAlignment: Text.AlignVCenter
                                color: Theme.text
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fontSizeBody + 1
                                echoMode: root.passwordRevealed ? TextInput.Normal : TextInput.Password
                                selectByMouse: true
                                clip: true
                                onAccepted: root.submit()
                                Keys.onEscapePressed: root.cancel()
                            }

                            IconButton {
                                iconName: root.passwordRevealed ? "visibility_off" : "visibility"
                                iconColor: hovered ? Theme.text : Theme.textDim
                                onClicked: root.passwordRevealed = !root.passwordRevealed
                            }
                        }
                    }
                }

                // Warning
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: warnRow.implicitHeight + 12
                    radius: Theme.radiusSm
                    color: Theme.withAlpha(Theme.error, 0.15)
                    border.color: Theme.error
                    border.width: 1
                    visible: root.warning !== ""

                    RowLayout {
                        id: warnRow
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 8

                        MaterialIcon {
                            iconName: "error"
                            pixelSize: 16
                            color: Theme.error
                            Layout.alignment: Qt.AlignVCenter
                        }

                        Text {
                            Layout.fillWidth: true
                            text: root.warning
                            color: Theme.error
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            font.bold: true
                            wrapMode: Text.WordWrap
                        }
                    }
                }

                // Optional choice checkbox
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
                        Behavior on color { ColorAnimation { duration: Anim.d(Anim.fast) } }

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
                        font.family: Theme.fontFamily
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
                    spacing: 10

                    Item { Layout.fillWidth: true }

                    DialogButton {
                        text: root.cancelLabel !== "" ? root.cancelLabel : "Cancel"
                        onClicked: root.cancel()
                    }

                    DialogButton {
                        text: root.continueLabel !== "" ? root.continueLabel
                              : (root.reqType === "password" ? "Unlock" : "Continue")
                        primary: true
                        iconName: "lock_open"
                        onClicked: root.submit()
                    }
                }
            }
        }
    }
}
