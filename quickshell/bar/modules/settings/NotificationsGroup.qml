import QtQuick
import QtQuick.Layouts
import "../../theme"
import "../../components"
import "../../services"

// Notification Banners, Do Not Disturb, Audio Chimes, and Per-App Rules Group.
ColumnLayout {
    id: root
    Layout.fillWidth: true
    spacing: 14

    function bset(k, v) { SettingsBus.set(k, v) }

    readonly property var corners: [
        { v: "bottom-right", l: "Bottom Right" },
        { v: "bottom-left", l: "Bottom Left" },
        { v: "top-right", l: "Top Right" },
        { v: "top-left", l: "Top Left" }
    ]
    readonly property string corner: SettingsBus.get("notifications.corner", "bottom-right")
    readonly property var muted: SettingsBus.get("notifications.muted", [])
    readonly property bool soundEnabled: SettingsBus.get("notifications.sound", true)
    readonly property string soundUrgency: SettingsBus.get("notifications.soundUrgency", "normal_and_critical")

    property int testProgress: -1
    Timer {
        id: progressSimTimer
        interval: 150
        repeat: true
        onTriggered: {
            root.testProgress += 5
            if (root.testProgress <= 100) {
                Notifications.notify("Downloading Update…", "Package mujo-desktop-2.0.tar.gz", "download", "normal", {
                    appName: "System Updater",
                    progress: root.testProgress,
                    transient: false
                })
            } else {
                progressSimTimer.stop()
                Notifications.notify("Update Complete", "All files verified and ready to install.", "check_circle", "normal", {
                    appName: "System Updater"
                })
            }
        }
    }

    // ── 1. Behavior & Do Not Disturb Card ─────────────────────────────────────
    MujoCard {
        title: "Behavior & Do Not Disturb"
        iconName: "notifications_active"
        badgeText: SettingsBus.get("notifications.dnd", false) ? "DND ACTIVE" : "ENABLED"
        badgeColor: SettingsBus.get("notifications.dnd", false) ? Theme.warning : Theme.success

        SettingRow {
            path: "notifications.dnd"
            def: false
            kind: "toggle"
            iconName: "do_not_disturb_on"
            title: "Do Not Disturb"
            description: "Suppress all toast banners; alerts are still recorded in history."
        }

        SettingRow {
            path: "notifications.fullscreenSuppress"
            def: true
            kind: "toggle"
            iconName: "fullscreen"
            title: "Suppress During Fullscreen"
            description: "Hold toasts while focused window is fullscreen (history keeps them)."
        }

        SettingRow {
            path: "notifications.toastTimeout"
            def: 5
            kind: "slider"
            from: 3
            to: 15
            format: "s"
            iconName: "timer"
            title: "Auto-Dismiss Timeout"
            description: "How long normal notification toasts stay on screen before fading."
        }

        SettingRow {
            path: "notifications.maxVisible"
            def: 4
            kind: "slider"
            from: 1
            to: 6
            format: " toasts"
            iconName: "layers"
            title: "Maximum Visible Toasts"
            description: "Maximum simultaneous notification banners on screen."
        }
    }

    // ── 2. Audio Chimes & Placement Card ──────────────────────────────────────
    MujoCard {
        title: "Sound Alerts & Placement"
        iconName: "volume_up"

        SettingRow {
            path: "notifications.sound"
            def: true
            kind: "toggle"
            iconName: "volume_up"
            title: "Sound Alerts"
            description: "Play subtle audio chimes when new notifications arrive."
        }

        MujoSettingRow {
            iconName: "priority_high"
            title: "Sound Urgency Filter"
            description: "Notification urgency levels that trigger audio alert chimes."

            MujoSegmented {
                model: [
                    { id: "all", label: "All" },
                    { id: "normal_and_critical", label: "Normal & Critical" },
                    { id: "critical_only", label: "Critical Only" }
                ]
                current: root.soundUrgency
                onSelected: function(id) { root.bset("notifications.soundUrgency", id) }
            }
        }

        MujoSettingRow {
            iconName: "grid_view"
            title: "Screen Gravity Corner"
            description: "Corner of the display where notification toasts stack."

            MujoSegmented {
                model: [
                    { id: "bottom-right", label: "Bottom Right" },
                    { id: "bottom-left", label: "Bottom Left" },
                    { id: "top-right", label: "Top Right" },
                    { id: "top-left", label: "Top Left" }
                ]
                current: root.corner
                onSelected: function(id) { root.bset("notifications.corner", id) }
            }
        }

        MujoSettingRow {
            iconName: "play_arrow"
            title: "Preview Audio Alert"
            description: "Test current notification audio chime configuration."

            DialogButton {
                text: "Play Chime"
                onClicked: Notifications.playAlertSound("normal", null)
            }
        }
    }

    // ── 3. Per-App Mute Rules Card ────────────────────────────────────────────
    MujoCard {
        title: "Per-App Mute Rules"
        iconName: "tune"

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 12

            Text {
                text: "Muted applications still record history but do not pop up toasts."
                color: Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                TextField {
                    id: muteField
                    Layout.fillWidth: true
                    placeholder: "Enter app name to mute (e.g. Discord, Spotify)"
                    onAccepted: {
                        var val = text.trim()
                        if (val !== "" && root.muted.indexOf(val) < 0) {
                            root.bset("notifications.muted", root.muted.concat([val]))
                            text = ""
                        }
                    }
                }
                DialogButton {
                    text: "Mute App"
                    iconName: "volume_off"
                    onClicked: {
                        var val = muteField.text.trim()
                        if (val !== "" && root.muted.indexOf(val) < 0) {
                            root.bset("notifications.muted", root.muted.concat([val]))
                            muteField.text = ""
                        }
                    }
                }
            }

            // Currently muted chips
            Flow {
                Layout.fillWidth: true
                spacing: 7
                visible: root.muted.length > 0
                Repeater {
                    model: root.muted
                    delegate: Rectangle {
                        id: chip
                        required property var modelData
                        implicitWidth: mrow.implicitWidth + 18
                        implicitHeight: 28
                        radius: Theme.radiusMd
                        color: Theme.surface
                        border.color: Theme.borderStrong

                        RowLayout {
                            id: mrow
                            anchors.centerIn: parent
                            spacing: 6
                            MaterialIcon { iconName: "volume_off"; pixelSize: 13; color: Theme.warning }
                            Text { text: chip.modelData; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSmall }
                            MaterialIcon {
                                iconName: "close"
                                pixelSize: 14
                                color: unmHover.hovered ? Theme.text : Theme.textDim
                                HoverHandler { id: unmHover; cursorShape: Qt.PointingHandCursor }
                                TapHandler { onTapped: root.bset("notifications.muted", root.muted.filter(function (x) { return x !== chip.modelData })) }
                            }
                        }
                    }
                }
            }
        }
    }

    // ── 4. Notification Testing Lab Card ──────────────────────────────────────
    MujoCard {
        title: "Notification Testing Lab"
        iconName: "science"

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 12

            Text {
                text: "Simulate incoming desktop notification toasts."
                color: Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                DialogButton {
                    text: "Normal Alert"
                    iconName: "notifications"
                    onClicked: Notifications.notify("New Message", "Alex: The deployment succeeded on server 4.", "chat", "normal", { appName: "Slack" })
                }

                DialogButton {
                    text: "Critical Alert"
                    iconName: "warning"
                    onClicked: Notifications.notify("High Temperature Alert", "CPU Core 0 reached 92°C thermal throttle threshold.", "thermostat", "critical", { appName: "Hardware Sentinel" })
                }

                DialogButton {
                    text: "Simulate Progress"
                    iconName: "download"
                    onClicked: { root.testProgress = 0; progressSimTimer.start() }
                }

                DialogButton {
                    text: "Action Buttons"
                    iconName: "touch_app"
                    onClicked: Notifications.notify("Device Connected", "USB-C Portable SSD detected. Open with Nautilus?", "usb", "normal", {
                        appName: "Device Manager",
                        actions: ["open", "Open File Manager", "eject", "Eject Drive"]
                    })
                }
            }
        }
    }
}
