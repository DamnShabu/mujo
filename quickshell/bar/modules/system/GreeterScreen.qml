import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../../theme"
import "../../components"
import "../../services"

// Boot greeter surfaces. Same ext-session-lock protocol the lock screen uses, so
// the compositor hands us exclusive input and nothing behind can be poked at
// while it is up — but unlike LockScreen this one is *dismissible*: the vault is
// optional and Esc/Skip drops you straight onto the desktop. State lives in the
// Greeter singleton; this only renders it.
//
// Two panes off Greeter.mode: unlock (a container exists) and setup (none does).
// They share the backdrop, the clock and the passphrase field, so the pane only
// swaps the copy, the icon and the action.
WlSessionLock {
    id: greetLock
    locked: Greeter.active

    WlSessionLockSurface {
        id: surface
        color: Theme.active.bg

        readonly property bool setup: Greeter.mode === Greeter.modeSetup
        readonly property bool confirming: setup && pw.text.length > 0

        Component.onCompleted: pw.forceActiveFocus()

        Connections {
            target: Greeter
            function onAttemptsChanged() {
                if (Greeter.attempts > 0) { pw.text = ""; confirm.text = ""; shake.restart() }
                pw.forceActiveFocus()
            }
        }

        // ── Backdrop ──────────────────────────────────────────────────────────
        // The session-lock protocol hides the real wallpaper, so this is the
        // whole background: a vertical wash plus one slow accent bloom behind
        // the card. Cheap — two gradients and a radial, no Canvas repaints.
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.darker(Theme.active.bg, 1.1) }
                GradientStop { position: 1.0; color: Qt.darker(Theme.active.bg, 1.7) }
            }
        }

        Rectangle {
            anchors.centerIn: parent
            width: Math.min(parent.width, parent.height) * 1.2
            height: width
            radius: width / 2
            // Breathes with the global ambient phase when motion is on, sits
            // still at its midpoint when it is not.
            opacity: Anim.ambient ? 0.10 + 0.05 * Math.sin(Anim.breathPhase) : 0.12
            gradient: Gradient {
                GradientStop { position: 0.0; color: Theme.accent }
                GradientStop { position: 0.55; color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.0) }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }

        // ── Content ───────────────────────────────────────────────────────────
        ColumnLayout {
            anchors.centerIn: parent
            spacing: 30
            width: 380

            // Clock. Identical treatment to the lock screen so the two read as
            // the same surface at different moments.
            ColumnLayout {
                id: clock
                Layout.alignment: Qt.AlignHCenter
                spacing: 4
                property date now: new Date()
                Timer { interval: 1000; running: greetLock.locked; repeat: true; triggeredOnStart: true; onTriggered: clock.now = new Date() }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: Qt.formatDateTime(clock.now, Theme.clock24h ? "HH:mm" : "hh:mm AP")
                    color: Theme.text
                    font.family: Theme.fontMono
                    font.pixelSize: 84
                    font.weight: Font.Light
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: Qt.formatDateTime(clock.now, "dddd, MMMM d")
                    color: Theme.textSecondary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeTitle
                }
            }

            // Vault glyph + headline.
            ColumnLayout {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 6
                spacing: 10

                Item {
                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth: 64
                    implicitHeight: 64

                    // Halo ring — grows and fades on a loop while work is in
                    // flight, so a slow luksFormat looks deliberate instead of
                    // hung. Stopped otherwise; an idle infinite animation is a
                    // permanent repaint for nothing.
                    Rectangle {
                        id: halo
                        anchors.centerIn: parent
                        width: 64; height: 64
                        radius: width / 2
                        color: "transparent"
                        border.width: 2
                        border.color: Theme.accent
                        opacity: 0
                        SequentialAnimation {
                            running: Greeter.busy && !Anim.reduceMotion
                            loops: Animation.Infinite
                            onStopped: { halo.opacity = 0; halo.scale = 1 }
                            ParallelAnimation {
                                NumberAnimation { target: halo; property: "opacity"; from: 0.55; to: 0; duration: 1400; easing.type: Easing.OutCubic }
                                NumberAnimation { target: halo; property: "scale"; from: 1.0; to: 1.7; duration: 1400; easing.type: Easing.OutCubic }
                            }
                        }
                    }

                    Rectangle {
                        anchors.centerIn: parent
                        width: 56; height: 56
                        radius: width / 2
                        color: Theme.accentDim
                        border.width: 1
                        border.color: Theme.accent
                        MaterialIcon {
                            anchors.centerIn: parent
                            iconName: surface.setup ? "add_moderator" : "shield_lock"
                            pixelSize: 26
                            color: Theme.accent
                        }
                    }
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: surface.setup ? "Set up your vault" : "Unlock your vault"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeHeading
                    font.weight: Font.DemiBold
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.maximumWidth: 340
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    text: surface.setup
                          ? "An encrypted container for keys, tokens and private documents. Choose a passphrase — it cannot be recovered."
                          : "Enter your passphrase to mount encrypted storage for this session."
                    color: Theme.textDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                }
            }

            // Size picker — setup only. Kept to three choices; a free-text size
            // field is a validation problem for a gain nobody asked for.
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 8
                visible: surface.setup
                enabled: !Greeter.busy

                Repeater {
                    model: ["5G", "10G", "25G"]
                    delegate: Rectangle {
                        required property string modelData
                        readonly property bool selected: Greeter.setupSize === modelData
                        implicitWidth: 62
                        implicitHeight: 30
                        radius: Theme.radiusSm
                        color: selected ? Theme.accentDim : Theme.surface
                        border.color: selected ? Theme.accent : Theme.border
                        Behavior on color { ColorAnimation { duration: Anim.d(Anim.fast) } }
                        Text {
                            anchors.centerIn: parent
                            text: parent.modelData
                            color: parent.selected ? Theme.accent : Theme.textSecondary
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSizeSmall
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Greeter.setupSize = parent.modelData
                        }
                    }
                }
            }

            // ── Passphrase ────────────────────────────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8
                transform: Translate { id: fieldShake; x: 0 }

                SequentialAnimation {
                    id: shake
                    loops: 1
                    NumberAnimation { target: fieldShake; property: "x"; to: -10; duration: Anim.d(45) }
                    NumberAnimation { target: fieldShake; property: "x"; to: 10; duration: Anim.d(90) }
                    NumberAnimation { target: fieldShake; property: "x"; to: 0; duration: Anim.d(45) }
                }

                TextField {
                    id: pw
                    Layout.fillWidth: true
                    implicitHeight: 42
                    password: true
                    enabled: !Greeter.busy
                    placeholder: surface.setup ? "New passphrase" : "Passphrase"
                    invalid: Greeter.error !== ""
                    onTextChanged: if (Greeter.error !== "") Greeter.error = ""
                    onAccepted: surface.submit()
                }

                // Confirmation appears only once there is something to confirm,
                // so the setup pane opens as a single field like the unlock one.
                TextField {
                    id: confirm
                    Layout.fillWidth: true
                    implicitHeight: 42
                    visible: surface.confirming
                    password: true
                    enabled: !Greeter.busy
                    placeholder: "Confirm passphrase"
                    invalid: text.length > 0 && text !== pw.text
                    onAccepted: surface.submit()
                }
            }

            // ── Status line ───────────────────────────────────────────────────
            // Always in the layout, faded — toggling `visible` re-centres the
            // whole column and makes the card jump the instant something fails.
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredHeight: 18
                spacing: 8
                opacity: (Greeter.busy || Greeter.error !== "") ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Anim.d(Anim.fast) } }

                Spinner { size: 14; visible: Greeter.busy; spinning: Greeter.busy }
                Text {
                    text: Greeter.error !== "" ? Greeter.error : Greeter.progress
                    color: Greeter.error !== "" ? Theme.error : Theme.textSecondary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                }
            }

            // ── Actions ───────────────────────────────────────────────────────
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 10

                DialogButton {
                    text: surface.setup ? "Not now" : "Skip"
                    onClicked: Greeter.dismiss()
                    enabled: !Greeter.busy
                }

                DialogButton {
                    text: surface.setup ? "Create vault" : "Unlock"
                    primary: true
                    enabled: !Greeter.busy && surface.canSubmit()
                    onClicked: surface.submit()
                }
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                visible: surface.setup && !Greeter.busy
                text: "Don't ask again"
                color: Theme.textDim
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                font.underline: dontAsk.containsMouse
                MouseArea {
                    id: dontAsk
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Greeter.dismissForever()
                }
            }
        }

        // Esc dismisses — the deliberate difference from LockScreen, where it
        // must not. Nothing here is guarding a session that is already yours.
        Keys.onEscapePressed: if (!Greeter.busy) Greeter.dismiss()
        focus: true

        function canSubmit() {
            if (pw.text.length === 0) return false
            if (setup && confirm.text !== pw.text) return false
            return true
        }

        function submit() {
            if (Greeter.busy || !canSubmit()) return
            if (setup) Greeter.createVault(pw.text)
            else Greeter.unlock(pw.text)
        }
    }
}
