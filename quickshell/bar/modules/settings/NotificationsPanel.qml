import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../theme"
import "../../components"
import "../../services"

// Notifications settings (WP-04). Writes the unified store via SettingsBus; the
// bar's Notifications singleton reads the same keys and reacts live.
// Features comprehensive configuration for behavior, sounds, placement, per-app rules,
// and an interactive notification testing lab.
Item {
    id: root

    function bset(k, v) { SettingsBus.set(k, v) }

    readonly property var corners: [
        { v: "bottom-right", l: "Bottom right" },
        { v: "bottom-left", l: "Bottom left" },
        { v: "top-right", l: "Top right" },
        { v: "top-left", l: "Top left" }
    ]
    readonly property string corner: SettingsBus.get("notifications.corner", "bottom-right")
    readonly property var muted: SettingsBus.get("notifications.muted", [])
    readonly property bool soundEnabled: SettingsBus.get("notifications.sound", true)
    readonly property string soundUrgency: SettingsBus.get("notifications.soundUrgency", "normal_and_critical")
    readonly property int toastTimeout: SettingsBus.get("notifications.toastTimeout", 5)
    readonly property int maxVisible: SettingsBus.get("notifications.maxVisible", 4)

    // Timer for simulating progress in test lab
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

    Flickable {
        anchors.fill: parent
        anchors.margins: 26
        contentHeight: col.implicitHeight + 40
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: col
            width: parent.width
            spacing: 20

            MujoHero {
                brand: "notifications"
                title: "Notifications"
                subtitle: "Toast banners, Do Not Disturb, sound alerts, and per-app notification rules."
                badgeText: SettingsBus.get("notifications.dnd", false) ? "DND ACTIVE" : "ENABLED"
                badgeColor: SettingsBus.get("notifications.dnd", false) ? Theme.warning : Theme.success
                activeState: !SettingsBus.get("notifications.dnd", false)
            }

            // ── 1. Behaviour & Do Not Disturb ──
            MujoCard {
                title: "Behaviour & Do Not Disturb"
                iconName: "notifications_active"

                MujoSettingRow {
                    title: "Do Not Disturb"
                    description: "Suppress all toast banners; notifications are still recorded in history."
                    ToggleSwitch {
                        checked: SettingsBus.get("notifications.dnd", false)
                        onToggled: function(c) { root.bset("notifications.dnd", c) }
                    }
                }

                MujoSettingRow {
                    title: "Suppress while fullscreen"
                    description: "Hold toasts while the focused window is fullscreen (history keeps them)."
                    ToggleSwitch {
                        checked: SettingsBus.get("notifications.fullscreenSuppress", true)
                        onToggled: function(c) { root.bset("notifications.fullscreenSuppress", c) }
                    }
                }

                MujoSettingRow {
                    title: "Auto-dismiss duration"
                    description: "How long normal notification toasts stay on screen before fading."
                    RowLayout {
                        spacing: 12
                        Slider {
                            from: 3; to: 15
                            value: root.toastTimeout
                            format: "s"
                            onMoved: function(v) { root.bset("notifications.toastTimeout", Math.round(v)) }
                        }
                        Text {
                            text: root.toastTimeout + "s"
                            color: Theme.accent
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSizeSmall
                            font.bold: true
                            Layout.preferredWidth: 32
                        }
                    }
                }

                MujoSettingRow {
                    title: "Max visible toasts"
                    description: "Maximum number of simultaneous notification banners on screen."
                    RowLayout {
                        spacing: 12
                        Slider {
                            from: 1; to: 6
                            value: root.maxVisible
                            format: " toasts"
                            onMoved: function(v) { root.bset("notifications.maxVisible", Math.round(v)) }
                        }
                        Text {
                            text: root.maxVisible + " toasts"
                            color: Theme.accent
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSizeSmall
                            font.bold: true
                            Layout.preferredWidth: 60
                        }
                    }
                }
            }

            // ── 2. Sound Alerts ──
            MujoCard {
                title: "Sound & Audio Alerts"
                iconName: "volume_up"

                MujoSettingRow {
                    title: "Sound alerts"
                    description: "Play subtle audio chimes when new notifications arrive."
                    ToggleSwitch {
                        checked: root.soundEnabled
                        onToggled: function(c) { root.bset("notifications.sound", c) }
                    }
                }

                MujoSettingRow {
                    title: "Urgency threshold"
                    description: "Choose which notification urgency levels trigger audio alerts."
                    RowLayout {
                        spacing: 6
                        DisplayChip {
                            label: "All"
                            selected: root.soundUrgency === "all"
                            onClicked: root.bset("notifications.soundUrgency", "all")
                        }
                        DisplayChip {
                            label: "Normal & Critical"
                            selected: root.soundUrgency === "normal_and_critical"
                            onClicked: root.bset("notifications.soundUrgency", "normal_and_critical")
                        }
                        DisplayChip {
                            label: "Critical Only"
                            selected: root.soundUrgency === "critical_only"
                            onClicked: root.bset("notifications.soundUrgency", "critical_only")
                        }
                    }
                }

                MujoSettingRow {
                    title: "Preview alert sound"
                    description: "Test current notification sound configuration."
                    DialogButton {
                        text: "Play Chime"
                        iconName: "play_arrow"
                        onClicked: Notifications.playAlertSound("normal", null)
                    }
                }
            }

            // ── 3. Toast Placement ──
            MujoCard {
                title: "Toast Position"
                iconName: "grid_view"

                MujoSettingRow {
                    title: "Screen corner"
                    description: "Corner of the display where notification toasts stack."
                    Flow {
                        spacing: 8
                        Repeater {
                            model: root.corners
                            delegate: DisplayChip {
                                required property var modelData
                                label: modelData.l
                                selected: root.corner === modelData.v
                                onClicked: root.bset("notifications.corner", modelData.v)
                            }
                        }
                    }
                }
            }

            // ── 4. Per-App Notification Rules ──
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
                            placeholder: "Enter application name to mute (e.g. Discord, Spotify)"
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

                    // Active Muted Apps Chips
                    Text {
                        visible: root.muted.length > 0
                        text: "Currently muted:"
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        font.bold: true
                    }

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

                                    MaterialIcon {
                                        iconName: "volume_off"
                                        pixelSize: 13
                                        color: Theme.warning
                                    }

                                    Text {
                                        text: chip.modelData
                                        color: Theme.text
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeSmall
                                    }

                                    MaterialIcon {
                                        iconName: "close"
                                        pixelSize: 14
                                        color: unmHover.hovered ? Theme.text : Theme.textDim
                                        HoverHandler { id: unmHover; cursorShape: Qt.PointingHandCursor }
                                        TapHandler {
                                            onTapped: root.bset("notifications.muted", root.muted.filter(function (x) { return x !== chip.modelData }))
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Recently seen apps to quickly mute/unmute
                    readonly property var recentApps: Notifications.getRecentApps()
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        visible: recentApps.length > 0

                        Text {
                            text: "Recently active apps:"
                            color: Theme.textDim
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeLabel
                            font.bold: true
                        }

                        Flow {
                            Layout.fillWidth: true
                            spacing: 6
                            Repeater {
                                model: recentApps
                                delegate: Rectangle {
                                    required property var modelData
                                    readonly property bool isMuted: root.muted.indexOf(modelData) >= 0
                                    implicitWidth: recRow.implicitWidth + 16
                                    implicitHeight: 26
                                    radius: Theme.radiusSm
                                    color: isMuted ? Theme.accentDim : (recHh.hovered ? Theme.surfaceHover : Theme.surface)
                                    border.color: isMuted ? Theme.accent : Theme.border

                                    RowLayout {
                                        id: recRow
                                        anchors.centerIn: parent
                                        spacing: 6
                                        Text {
                                            text: parent.parent.modelData
                                            color: parent.parent.isMuted ? Theme.accent : Theme.text
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontSizeSmall
                                        }
                                        MaterialIcon {
                                            iconName: parent.parent.isMuted ? "volume_up" : "volume_off"
                                            pixelSize: 13
                                            color: parent.parent.isMuted ? Theme.accent : Theme.textDim
                                        }
                                    }

                                    HoverHandler { id: recHh; cursorShape: Qt.PointingHandCursor }
                                    TapHandler {
                                        onTapped: {
                                            if (parent.isMuted) {
                                                root.bset("notifications.muted", root.muted.filter(function (x) { return x !== parent.modelData }))
                                            } else {
                                                root.bset("notifications.muted", root.muted.concat([parent.modelData]))
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ── 5. Interactive Test Lab & History ──
            MujoCard {
                title: "Interactive Test Lab & History"
                iconName: "science"

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 14

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Text {
                            text: "Total stored notifications in history: " + Notifications.history.length
                            color: Theme.textSecondary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                        }
                        Item { Layout.fillWidth: true }
                        DialogButton {
                            text: "Clear History"
                            iconName: "delete_sweep"
                            onClicked: Notifications.clearHistory()
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: Theme.border
                    }

                    Text {
                        text: "Fire test notifications to inspect styling, animations, and features:"
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        font.bold: true
                    }

                    Flow {
                        Layout.fillWidth: true
                        spacing: 8

                        DialogButton {
                            text: "Standard Message"
                            iconName: "chat"
                            onClicked: Notifications.notify(
                                "Workspace update",
                                "All system services are operating normally on host <b>main</b>.",
                                "check_circle", "normal", { appName: "mujō" }
                            )
                        }

                        DialogButton {
                            text: "Action Buttons"
                            iconName: "touch_app"
                            onClicked: Notifications.notify(
                                "Incoming Meeting",
                                "Weekly architecture sync starts in 5 minutes.",
                                "event_upcoming", "normal", {
                                    appName: "Calendar",
                                    actions: [
                                        { text: "Join Now", run: function() { console.info("Join clicked") } },
                                        { text: "Snooze 5m", run: function() { console.info("Snooze clicked") } }
                                    ]
                                }
                            )
                        }

                        DialogButton {
                            text: "Progress Bar"
                            iconName: "download"
                            onClicked: {
                                root.testProgress = 0
                                progressSimTimer.start()
                            }
                        }

                        DialogButton {
                            text: "Inline Reply"
                            iconName: "send"
                            onClicked: Notifications.notify(
                                "Message from Alice",
                                "Did you check the new notification layout on Wayland?",
                                "account_circle", "normal", {
                                    appName: "Chat",
                                    hasInlineReply: true,
                                    inlineReplyPlaceholder: "Write Alice a reply…",
                                    replyCallback: function(reply) {
                                        Notifications.notify("Reply sent", "Sent to Alice: " + reply, "check", "low", { transient: true })
                                    }
                                }
                            )
                        }

                        DialogButton {
                            text: "Critical Urgent"
                            danger: true
                            iconName: "warning"
                            onClicked: Notifications.notify(
                                "Critical Battery Alert",
                                "Battery level reached <b>5%</b>. Connect AC power immediately.",
                                "battery_alert", "critical", { appName: "Power Manager" }
                            )
                        }
                    }
                }
            }

            Item { implicitHeight: 10 }
        }
    }
}

