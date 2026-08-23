import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Polkit

// Themed polkit authentication agent (the dialog pkexec / any polkit action
// pops up). Registers a PolkitAgent for the session and renders a mujō-styled
// modal over an Overlay layer-shell surface with exclusive keyboard focus.
//
// There is currently no other polkit agent on the system, so this fills a real
// gap: GUI polkit actions (pkexec, mounting, etc.) previously had nowhere to
// prompt.
Item {
    id: root

    PolkitAgent {
        id: agent
        path: "/org/mujo/PolkitAgent"

        onAuthenticationRequestStarted: {
            passwordField.text = ""
            focusTimer.restart()
        }
    }

    readonly property var flow: agent.flow
    // Show while a request is live and not yet finished.
    readonly property bool showing: agent.flow !== null && !agent.flow.isCompleted

    // Single-user desktop: auto-select the first identity if the backend
    // hasn't. Multi-identity selection is surfaced in the UI below.
    Connections {
        target: agent
        function onFlowChanged() {
            var f = agent.flow
            if (f && f.identities && f.identities.length > 0 && !f.selectedIdentity)
                f.selectedIdentity = f.identities[0]
        }
    }

    Timer {
        id: focusTimer
        interval: 40
        onTriggered: if (root.showing) passwordField.forceActiveFocus()
    }

    function submit() {
        if (root.flow && root.flow.isResponseRequired)
            root.flow.submit(passwordField.text)
    }

    function cancel() {
        if (root.flow) root.flow.cancelAuthenticationRequest()
    }

    PanelWindow {
        id: win
        visible: root.showing
        color: "transparent"

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.namespace: "mujo-polkit"

        anchors { top: true; bottom: true; left: true; right: true }

        // Dim scrim. Clicking outside the card cancels.
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

            // Swallow clicks so scrim-cancel doesn't fire through the card.
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
                            iconName: "admin_panel_settings"
                            pixelSize: 22
                            color: Theme.accent
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        SectionLabel { text: "Authentication Required"; accented: true }
                        Text {
                            Layout.fillWidth: true
                            text: root.flow ? root.flow.message : ""
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeBody
                            wrapMode: Text.WordWrap
                        }
                    }
                }

                // Identity picker — only when more than one is offered.
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    visible: root.flow && root.flow.identities && root.flow.identities.length > 1
                    MaterialIcon { iconName: "person"; pixelSize: 15; color: Theme.textSecondary }
                    Text {
                        Layout.fillWidth: true
                        text: root.flow && root.flow.identities
                              ? root.flow.identities.length + " identities available"
                              : ""
                        color: Theme.textSecondary
                        font.pixelSize: Theme.fontSizeSmall
                    }
                }

                // Password / response input.
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    visible: root.flow && root.flow.isResponseRequired

                    Text {
                        text: root.flow ? root.flow.inputPrompt : ""
                        color: Theme.textSecondary
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeLabel
                        font.letterSpacing: Theme.labelSpacing
                        font.capitalization: Font.AllUppercase
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
                                echoMode: (root.flow && root.flow.responseVisible) ? TextInput.Normal : TextInput.Password
                                selectByMouse: true
                                clip: true
                                onAccepted: root.submit()
                                Keys.onEscapePressed: root.cancel()
                            }
                        }
                    }
                }

                // Supplementary message (errors like "Authentication failure").
                Text {
                    Layout.fillWidth: true
                    visible: root.flow && root.flow.supplementaryMessage !== ""
                    text: root.flow ? root.flow.supplementaryMessage : ""
                    color: (root.flow && root.flow.supplementaryIsError) ? Theme.error : Theme.textSecondary
                    font.pixelSize: Theme.fontSizeSmall
                    wrapMode: Text.WordWrap
                }

                Text {
                    Layout.fillWidth: true
                    visible: root.flow && root.flow.actionId !== ""
                    text: root.flow ? root.flow.actionId : ""
                    color: Theme.textDim
                    font.family: Theme.fontMono
                    font.pixelSize: 9
                    elide: Text.ElideRight
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Item { Layout.fillWidth: true }

                    DialogButton {
                        text: "Cancel"
                        onClicked: root.cancel()
                    }

                    DialogButton {
                        text: "Authenticate"
                        primary: true
                        enabled: root.flow && root.flow.isResponseRequired
                        onClicked: root.submit()
                    }
                }
            }
        }
    }
}
