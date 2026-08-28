import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Polkit
import "../../theme"
import "../../components"

// The Mujo Security Authority (無常) — High-Fidelity Polkit Authentication Modal.
//
// Features:
// - Security Authority header with living radiant bloom and shield badge
// - Parsed action breakdown card (command line chip, action description, token pill)
// - Identity & privilege level indicators
// - High-fidelity monospace password field with focus glow & reveal toggle
// - Caps Lock detection and warning alert
// - State machine: Idle -> Verifying (with spinner) -> Physical Error Shake & Banner -> Success Exit
// - Multi-frame keyboard grab assertion on Wayland
Item {
    id: root

    property bool isAuthenticating: false
    property bool hasError: false
    property bool capsLockOn: false
    property bool passwordRevealed: false

    PolkitAgent {
        id: agent
        path: "/org/mujo/PolkitAgent"

        onAuthenticationRequestStarted: {
            root.isAuthenticating = false
            root.hasError = false
            root.passwordRevealed = false
            passwordField.text = ""
            focusTimer.restart()
        }
    }

    readonly property var flow: agent.flow
    readonly property bool showing: agent.flow !== null && !agent.flow.isCompleted

    // Single-user desktop auto-select identity
    Connections {
        target: agent
        function onFlowChanged() {
            var f = agent.flow
            if (f && f.identities && f.identities.length > 0 && !f.selectedIdentity) {
                f.selectedIdentity = f.identities[0]
            }
            if (f && f.supplementaryMessage && f.supplementaryIsError) {
                root.isAuthenticating = false
                root.hasError = true
                errorShake.restart()
                passwordField.text = ""
                focusTimer.restart()
            }
        }
    }

    // Helper functions for parsing polkit payload
    function extractCommand(msg) {
        if (!msg) return ""
        var match = msg.match(/`([^`]+)`/)
        if (match && match[1]) return match[1]
        return ""
    }

    function getIdentityLabel() {
        if (!root.flow || !root.flow.selectedIdentity) return "Administrator (root)"
        var id = root.flow.selectedIdentity
        if (typeof id === "string") return id
        if (id.realName) return id.realName + " (" + (id.name || "root") + ")"
        if (id.name) return id.name
        return "Administrator (root)"
    }

    function submit() {
        if (root.flow && root.flow.isResponseRequired) {
            root.isAuthenticating = true
            root.hasError = false
            root.flow.submit(passwordField.text)
        }
    }

    function cancel() {
        root.isAuthenticating = false
        root.hasError = false
        if (root.flow) root.flow.cancelAuthenticationRequest()
    }

    // Multi-frame keyboard grab assertion timer on Wayland
    Timer {
        id: focusTimer
        interval: 30
        repeat: true
        triggeredOnStart: true
        property int ticks: 0
        onTriggered: {
            if (!root.showing) { stop(); ticks = 0; return }
            passwordField.forceActiveFocus()
            ticks++
            if (ticks > 5) { stop(); ticks = 0 }
        }
    }

    PanelWindow {
        id: win
        visible: root.showing
        color: "transparent"

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.namespace: "mujo-polkit"

        anchors { top: true; bottom: true; left: true; right: true }

        // ── 1. Atmospheric Backdrop Scrim ─────────────────────────────────────
        Rectangle {
            anchors.fill: parent
            color: "#000000"
            opacity: root.showing ? 0.55 : 0.0
            Behavior on opacity { NumberAnimation { duration: Anim.d(Anim.enter); easing.type: Anim.easeEnter } }
            MouseArea { anchors.fill: parent; onClicked: root.cancel() }
        }

        // ── 2. Ambient Radiant Bloom behind Card ───────────────────────────────
        Rectangle {
            id: radiantBloom
            anchors.centerIn: card
            width: card.width + 48
            height: card.height + 48
            radius: Theme.radiusLg + 24
            color: root.hasError ? Theme.error : Theme.accent
            opacity: root.showing && Anim.ambient ? Anim.breath(0.04, 0.12) : 0.0
            scale: root.showing && Anim.ambient ? Anim.breath(0.98, 1.03) : 0.95
            visible: !Anim.reduceMotion

            Behavior on color { ColorAnimation { duration: Anim.d(Anim.fast) } }
            Behavior on opacity { NumberAnimation { duration: Anim.d(Anim.enter) } }
            Behavior on scale { NumberAnimation { duration: Anim.d(Anim.slow); easing.type: Anim.easeStandard } }
        }

        // ── 3. Elevation Drop Shadow ───────────────────────────────────────────
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

        // ── 4. Main Security Monolith Card ────────────────────────────────────
        Rectangle {
            id: card
            anchors.centerIn: parent
            width: 460
            implicitHeight: col.implicitHeight + 44
            radius: Theme.radiusLg
            color: Theme.bg
            border.color: root.hasError
                          ? Theme.error
                          : (root.showing && Anim.ambient ? Theme.withAlpha(Theme.borderStrong, Anim.breath(0.6, 0.9)) : Theme.borderStrong)
            border.width: 1
            clip: true

            Behavior on border.color { ColorAnimation { duration: Anim.d(Anim.fast) } }

            // Spatial emergence + Error shake translate
            transform: [
                Translate { id: cardTranslate; y: root.showing ? 0 : -14 },
                Translate { id: cardShake; x: 0 }
            ]

            opacity: root.showing ? 1.0 : 0.0
            scale: root.showing ? 1.0 : 0.94

            Behavior on opacity { NumberAnimation { duration: Anim.d(Anim.enter); easing.type: Anim.easeEnter } }
            Behavior on scale {
                NumberAnimation {
                    duration: Anim.d(Anim.slow)
                    easing.type: Anim.easeStandard
                }
            }
            Behavior on y {
                NumberAnimation {
                    duration: Anim.d(Anim.slow)
                    easing.type: Anim.easeStandard
                }
            }

            // Error Physical Shake Animation
            SequentialAnimation {
                id: errorShake
                loops: 1
                NumberAnimation { target: cardShake; property: "x"; to: -12; duration: Anim.d(40); easing.type: Easing.OutQuad }
                NumberAnimation { target: cardShake; property: "x"; to: 12; duration: Anim.d(70); easing.type: Easing.InOutQuad }
                NumberAnimation { target: cardShake; property: "x"; to: -8; duration: Anim.d(50); easing.type: Easing.InOutQuad }
                NumberAnimation { target: cardShake; property: "x"; to: 8; duration: Anim.d(50); easing.type: Easing.InOutQuad }
                NumberAnimation { target: cardShake; property: "x"; to: 0; duration: Anim.d(40); easing.type: Easing.OutQuad }
            }

            // Specular top highlight line
            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 1
                color: Theme.withAlpha("#ffffff", 0.06)
            }

            // Specular Light Sweep Animation on emergence
            Item {
                id: lightSweepContainer
                anchors.fill: parent
                clip: true
                visible: !Anim.reduceMotion

                Rectangle {
                    id: lightSweep
                    x: -width
                    y: 0
                    width: 140
                    height: 2
                    radius: 1
                    color: root.hasError ? Theme.error : Theme.accent
                    opacity: 0.85

                    NumberAnimation {
                        id: sweepAnim
                        target: lightSweep
                        property: "x"
                        from: -140
                        to: card.width + 140
                        duration: Anim.d(Anim.deliberate)
                        easing.type: Easing.OutQuad
                    }
                }
            }

            onOpacityChanged: if (opacity > 0.1 && root.showing) sweepAnim.restart()

            // Swallow clicks so scrim doesn't cancel
            MouseArea { anchors.fill: parent }

            ColumnLayout {
                id: col
                anchors.fill: parent
                anchors.margins: 22
                spacing: 16

                // ── 4a. Security Authority Header ─────────────────────────────
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    // Pulsing Shield Authority Badge
                    Rectangle {
                        implicitWidth: 44
                        implicitHeight: 44
                        radius: Theme.radiusMd
                        color: root.hasError ? Theme.withAlpha(Theme.error, 0.15) : Theme.accentDim
                        border.color: root.hasError ? Theme.error : Theme.accent
                        border.width: 1
                        Layout.alignment: Qt.AlignTop

                        scale: root.showing && Anim.ambient ? Anim.breath(0.97, 1.03) : 1.0
                        Behavior on scale { NumberAnimation { duration: Anim.d(Anim.slow); easing.type: Anim.easeStandard } }

                        MaterialIcon {
                            anchors.centerIn: parent
                            iconName: root.hasError ? "gpp_bad" : "admin_panel_settings"
                            pixelSize: 24
                            color: root.hasError ? Theme.error : Theme.accent
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
                                text: "// SECURITY AUTHORITY"
                                accented: true
                            }

                            Item { Layout.fillWidth: true }

                            Rectangle {
                                implicitWidth: statusPillTxt.implicitWidth + 10
                                implicitHeight: 18
                                radius: 9
                                color: root.hasError
                                       ? Theme.withAlpha(Theme.error, 0.15)
                                       : Theme.withAlpha(Theme.accent, 0.14)
                                border.color: root.hasError ? Theme.error : Theme.accent
                                border.width: 1

                                Text {
                                    id: statusPillTxt
                                    anchors.centerIn: parent
                                    text: root.hasError ? "AUTHENTICATION ERROR" : "ELEVATED PRIVILEGES"
                                    color: root.hasError ? Theme.error : Theme.accent
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.fontSizeLabel - 2
                                    font.bold: true
                                }
                            }
                        }

                        Text {
                            text: "Authentication Required"
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeTitle + 2
                            font.bold: true
                        }

                        Text {
                            text: "An administrative action requires elevated authorization."
                            color: Theme.textSecondary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                        }
                    }
                }

                // ── 4b. Target Action Breakdown Card ──────────────────────────
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: actionCol.implicitHeight + 20
                    radius: Theme.radiusMd
                    color: Theme.surface
                    border.color: Theme.borderStrong
                    border.width: 1

                    ColumnLayout {
                        id: actionCol
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 8

                        // Parsed Command Line Chip
                        Rectangle {
                            readonly property string cmd: root.extractCommand(root.flow ? root.flow.message : "")
                            visible: cmd !== ""
                            Layout.fillWidth: true
                            implicitHeight: 28
                            radius: Theme.radiusSm
                            color: Theme.bg
                            border.color: Theme.border
                            border.width: 1

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                spacing: 6

                                Text {
                                    text: "$"
                                    color: Theme.accent
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.bold: true
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: parent.parent.cmd
                                    color: Theme.text
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.bold: true
                                    elide: Text.ElideMiddle
                                }
                            }
                        }

                        // Human-Readable Action Explanation
                        Text {
                            Layout.fillWidth: true
                            text: root.flow ? root.flow.message : "System operation authorization requested."
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeBody
                            wrapMode: Text.WordWrap
                        }

                        // Security Action Token Tag
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            visible: root.flow && root.flow.actionId !== ""

                            MaterialIcon {
                                iconName: "lock"
                                pixelSize: 13
                                color: Theme.textDim
                            }

                            Text {
                                Layout.fillWidth: true
                                text: root.flow ? root.flow.actionId : ""
                                color: Theme.textDim
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fontSizeLabel
                                elide: Text.ElideRight
                            }
                        }
                    }
                }

                // ── 4c. Target Identity Chip ──────────────────────────────────
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 30
                        radius: Theme.radiusSm
                        color: Theme.withAlpha(Theme.surface, 0.6)
                        border.color: Theme.border
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 8

                            MaterialIcon {
                                iconName: "account_circle"
                                pixelSize: 16
                                color: Theme.accent
                            }

                            Text {
                                text: "Target Identity:"
                                color: Theme.textSecondary
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSmall
                            }

                            Text {
                                Layout.fillWidth: true
                                text: root.getIdentityLabel()
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSmall
                                font.bold: true
                                elide: Text.ElideRight
                            }

                            Text {
                                text: "ROOT"
                                color: Theme.accent
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fontSizeLabel - 1
                                font.bold: true
                            }
                        }
                    }
                }

                // ── 4d. Password Input Field ──────────────────────────────────
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    visible: root.flow && root.flow.isResponseRequired

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: root.flow && root.flow.inputPrompt ? root.flow.inputPrompt.replace(":", "") : "PASSWORD"
                            color: Theme.textSecondary
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSizeLabel
                            font.letterSpacing: Theme.labelSpacing
                            font.capitalization: Font.AllUppercase
                        }

                        Item { Layout.fillWidth: true }

                        // Caps Lock Warning Indicator
                        RowLayout {
                            visible: root.capsLockOn
                            spacing: 4

                            MaterialIcon {
                                iconName: "warning"
                                pixelSize: 13
                                color: Theme.warning
                            }

                            Text {
                                text: "Caps Lock Active"
                                color: Theme.warning
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeLabel
                                font.bold: true
                            }
                        }
                    }

                    Rectangle {
                        id: inputContainer
                        Layout.fillWidth: true
                        implicitHeight: 42
                        radius: Theme.radiusMd
                        color: Theme.surface
                        border.color: root.hasError
                                      ? Theme.error
                                      : (passwordField.activeFocus ? Theme.accent : Theme.border)
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
                                Behavior on color { ColorAnimation { duration: Anim.d(Anim.fast) } }
                            }

                            TextInput {
                                id: passwordField
                                Layout.fillWidth: true
                                verticalAlignment: Text.AlignVCenter
                                enabled: !root.isAuthenticating
                                color: Theme.text
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fontSizeBody + 1
                                echoMode: (root.passwordRevealed || (root.flow && root.flow.responseVisible))
                                          ? TextInput.Normal
                                          : TextInput.Password
                                selectByMouse: true
                                clip: true

                                onTextChanged: {
                                    if (root.hasError) root.hasError = false
                                }

                                onAccepted: root.submit()

                                Keys.onPressed: (event) => {
                                    root.capsLockOn = (event.modifiers & Qt.ShiftModifier) === 0
                                        && event.text !== ""
                                        && event.text.toUpperCase() === event.text
                                        && event.text.toLowerCase() !== event.text
                                }

                                Keys.onEscapePressed: root.cancel()
                            }

                            // Password Reveal Toggle
                            IconButton {
                                iconName: root.passwordRevealed ? "visibility_off" : "visibility"
                                iconColor: hovered ? Theme.text : Theme.textDim
                                visible: !(root.flow && root.flow.responseVisible)
                                onClicked: root.passwordRevealed = !root.passwordRevealed
                                Tooltip {
                                    panelWindow: win
                                    target: parent
                                    text: root.passwordRevealed ? "Hide Password" : "Show Password"
                                    hovered: parent.hovered
                                }
                            }
                        }
                    }
                }

                // ── 4e. Authentication Error Banner ───────────────────────────
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: errorRow.implicitHeight + 12
                    radius: Theme.radiusSm
                    color: Theme.withAlpha(Theme.error, 0.15)
                    border.color: Theme.error
                    border.width: 1
                    visible: root.hasError || (root.flow && root.flow.supplementaryMessage !== "" && root.flow.supplementaryIsError)

                    RowLayout {
                        id: errorRow
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
                            text: (root.flow && root.flow.supplementaryMessage !== "")
                                  ? root.flow.supplementaryMessage
                                  : "Authentication failed. Please verify your credentials and try again."
                            color: Theme.error
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            font.bold: true
                            wrapMode: Text.WordWrap
                        }
                    }
                }

                // ── 4f. Action Buttons Footer ─────────────────────────────────
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Item { Layout.fillWidth: true }

                    DialogButton {
                        text: "Cancel"
                        enabled: !root.isAuthenticating
                        onClicked: root.cancel()
                    }

                    DialogButton {
                        text: root.isAuthenticating ? "Verifying…" : "Authenticate"
                        primary: true
                        loading: root.isAuthenticating
                        iconName: root.isAuthenticating ? "" : "lock_open"
                        enabled: !root.isAuthenticating && root.flow && root.flow.isResponseRequired
                        onClicked: root.submit()
                    }
                }
            }
        }
    }
}
