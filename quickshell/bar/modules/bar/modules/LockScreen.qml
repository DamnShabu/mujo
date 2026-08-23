import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

// Lock-screen surfaces (WP-14). Uses the native ext-session-lock protocol via
// WlSessionLock — the compositor blanks every other surface and hands us
// exclusive input, so this is a real lock, not a Top-layer overlay that can be
// bypassed. One WlSessionLockSurface per screen; state lives in the Lock
// singleton (this only renders it). Esc does NOT unlock — only a correct
// password does. Password auth runs through Lock.authenticate → qsshell-unlock.
//
// ponytail: solid dimmed backdrop instead of a blurred copy of the wallpaper —
// the session-lock protocol hides the real wallpaper, so showing it would mean
// re-reading wallpaper.json + blurring here; not worth it. Add if the look bites.
WlSessionLock {
    id: sessionLock
    locked: Lock.locked

    WlSessionLockSurface {
        id: surface
        color: Theme.active.bg

        Component.onCompleted: pw.forceActiveFocus()
        Connections {
            target: Lock
            // Refocus + clear on each lock and after every failed attempt.
            function onLockedChanged() { if (Lock.locked) { pw.text = ""; pw.forceActiveFocus() } }
            function onAttemptsChanged() { pw.text = ""; pw.forceActiveFocus(); if (Lock.attempts > 0) shake.restart() }
        }

        // Dim wash over the theme background for depth.
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.darker(Theme.active.bg, 1.15) }
                GradientStop { position: 1.0; color: Qt.darker(Theme.active.bg, 1.6) }
            }
        }

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 28
            width: 360

            // Big mono clock.
            ColumnLayout {
                id: clock
                Layout.alignment: Qt.AlignHCenter
                spacing: 4
                property date now: new Date()
                Timer { interval: 1000; running: sessionLock.locked; repeat: true; triggeredOnStart: true; onTriggered: clock.now = new Date() }
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

            // Password field.
            Rectangle {
                id: field
                Layout.fillWidth: true
                implicitHeight: 46
                radius: Theme.radiusLg
                color: Theme.surface
                border.color: Lock.error !== "" ? Theme.error : (pw.activeFocus ? Theme.accent : Theme.border)
                Behavior on border.color { ColorAnimation { duration: Theme.durationFast } }

                // Error shake.
                SequentialAnimation {
                    id: shake
                    loops: 1
                    NumberAnimation { target: field; property: "anchors.horizontalCenterOffset"; to: -10; duration: 45 }
                    NumberAnimation { target: field; property: "anchors.horizontalCenterOffset"; to: 10; duration: 90 }
                    NumberAnimation { target: field; property: "anchors.horizontalCenterOffset"; to: 0; duration: 45 }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    spacing: 10

                    MaterialIcon { iconName: Lock.busy ? "hourglass_empty" : "lock"; pixelSize: 18; color: Theme.textDim }

                    TextInput {
                        id: pw
                        Layout.fillWidth: true
                        verticalAlignment: Text.AlignVCenter
                        enabled: !Lock.busy
                        color: Theme.text
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeBody
                        echoMode: TextInput.Password
                        selectByMouse: true
                        clip: true
                        onTextChanged: if (Lock.error !== "") Lock.error = ""
                        onAccepted: if (text.length) Lock.authenticate(text)
                        // Esc intentionally does nothing — no bypass.
                    }
                }
            }

            // Attempts / error line.
            Text {
                Layout.alignment: Qt.AlignHCenter
                visible: Lock.attempts > 0
                text: Lock.error !== ""
                      ? Lock.error + " · " + Lock.attempts + (Lock.attempts === 1 ? " attempt" : " attempts")
                      : ""
                color: Theme.error
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
            }
        }
    }
}
