import QtQuick
import QtQuick.Layouts
import Quickshell

// Notifications settings (WP-04). Writes the unified store via SettingsBus; the
// bar's Notifications singleton reads the same keys and reacts live (cross-process
// via the settings.json FileView watch). Test fires a real notify-send so it
// exercises the actual server; history clear goes through `mujo notify clear`.
Item {
    id: root

    function bset(k, v) { SettingsBus.set(k, v) }
    readonly property var corners: [
        { v: "bottom-right", l: "Bottom right" }, { v: "bottom-left", l: "Bottom left" },
        { v: "top-right", l: "Top right" }, { v: "top-left", l: "Top left" }
    ]
    readonly property string corner: SettingsBus.get("notifications.corner", "bottom-right")
    readonly property var muted: SettingsBus.get("notifications.muted", [])
    readonly property var thresholds: SettingsBus.get("notifications.batteryThresholds", [20, 10, 5])

    Flickable {
        anchors.fill: parent
        anchors.margins: 26
        contentHeight: col.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: col
            width: parent.width
            spacing: 22

            Text { text: "Notifications"; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeTitle + 7; font.bold: true }

            // ── behaviour toggles ──
            ColumnLayout {
                Layout.fillWidth: true; spacing: 10
                SectionLabel { text: "Behaviour" }

                RowLayout {
                    Layout.fillWidth: true; spacing: 12
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 1
                        Text { text: "Do Not Disturb"; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeBody }
                        Text { text: "Suppress toasts; notifications are still recorded in history."; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSmall; wrapMode: Text.WordWrap; Layout.fillWidth: true }
                    }
                    ToggleSwitch { Layout.alignment: Qt.AlignVCenter; checked: SettingsBus.get("notifications.dnd", false); onToggled: function (c) { root.bset("notifications.dnd", c) } }
                }

                RowLayout {
                    Layout.fillWidth: true; spacing: 12
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 1
                        Text { text: "Suppress while fullscreen"; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeBody }
                        Text { text: "Hold toasts while the focused window is fullscreen (history keeps them)."; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSmall; wrapMode: Text.WordWrap; Layout.fillWidth: true }
                    }
                    ToggleSwitch { Layout.alignment: Qt.AlignVCenter; checked: SettingsBus.get("notifications.fullscreenSuppress", true); onToggled: function (c) { root.bset("notifications.fullscreenSuppress", c) } }
                }
            }

            // ── position ──
            ColumnLayout {
                Layout.fillWidth: true; spacing: 10
                SectionLabel { text: "Toast position" }
                Flow {
                    Layout.fillWidth: true; spacing: 7
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

            // ── battery thresholds ──
            ColumnLayout {
                Layout.fillWidth: true; spacing: 10
                SectionLabel { text: "Battery warnings (%)" }
                RowLayout {
                    Layout.fillWidth: true; spacing: 8
                    TextField { id: t0; Layout.preferredWidth: 80; text: String(root.thresholds[0] !== undefined ? root.thresholds[0] : 20); onAccepted: root.bset("notifications.batteryThresholds", [parseInt(t0.text) || 0, parseInt(t1.text) || 0, parseInt(t2.text) || 0]) }
                    TextField { id: t1; Layout.preferredWidth: 80; text: String(root.thresholds[1] !== undefined ? root.thresholds[1] : 10); onAccepted: root.bset("notifications.batteryThresholds", [parseInt(t0.text) || 0, parseInt(t1.text) || 0, parseInt(t2.text) || 0]) }
                    TextField { id: t2; Layout.preferredWidth: 80; text: String(root.thresholds[2] !== undefined ? root.thresholds[2] : 5); onAccepted: root.bset("notifications.batteryThresholds", [parseInt(t0.text) || 0, parseInt(t1.text) || 0, parseInt(t2.text) || 0]) }
                    DialogButton { text: "Save"; primary: true; onClicked: root.bset("notifications.batteryThresholds", [parseInt(t0.text) || 0, parseInt(t1.text) || 0, parseInt(t2.text) || 0]) }
                    Item { Layout.fillWidth: true }
                }
                Text { text: "Only used on devices with a battery. Each threshold warns once per discharge."; color: Theme.textDim; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSmall; wrapMode: Text.WordWrap; Layout.fillWidth: true }
            }

            // ── per-app mute ──
            ColumnLayout {
                Layout.fillWidth: true; spacing: 10
                SectionLabel { text: "Muted apps" }
                RowLayout {
                    Layout.fillWidth: true; spacing: 8
                    TextField {
                        id: muteField
                        Layout.fillWidth: true
                        placeholder: "App name to mute (exact, e.g. Discord)"
                        onAccepted: if (text.trim() !== "") { root.bset("notifications.muted", root.muted.concat([text.trim()])); text = "" }
                    }
                    DialogButton { text: "Mute"; onClicked: if (muteField.text.trim() !== "") { root.bset("notifications.muted", root.muted.concat([muteField.text.trim()])); muteField.text = "" } }
                }
                Flow {
                    Layout.fillWidth: true; spacing: 7
                    visible: root.muted.length > 0
                    Repeater {
                        model: root.muted
                        delegate: Rectangle {
                            id: chip
                            required property var modelData
                            implicitWidth: mrow.implicitWidth + 18; implicitHeight: 28
                            radius: Theme.radiusMd; color: Theme.surface; border.color: Theme.borderStrong
                            RowLayout {
                                id: mrow; anchors.centerIn: parent; spacing: 6
                                Text { text: chip.modelData; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSmall }
                                MaterialIcon {
                                    iconName: "close"; pixelSize: 14; color: unmHover.hovered ? Theme.text : Theme.textDim
                                    HoverHandler { id: unmHover; cursorShape: Qt.PointingHandCursor }
                                    TapHandler { onTapped: root.bset("notifications.muted", root.muted.filter(function (x) { return x !== chip.modelData })) }
                                }
                            }
                        }
                    }
                }
                Text { visible: root.muted.length === 0; text: "No muted apps."; color: Theme.textDim; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSmall }
            }

            // ── history + test ──
            ColumnLayout {
                Layout.fillWidth: true; spacing: 10
                SectionLabel { text: "History" }
                RowLayout {
                    Layout.fillWidth: true; spacing: 8
                    DialogButton { text: "Send test notification"; primary: true; onClicked: Quickshell.execDetached(["notify-send", "mujō", "This is a test notification."]) }
                    DialogButton { text: "Clear history"; onClicked: Quickshell.execDetached(["mujo", "notify", "clear"]) }
                    Item { Layout.fillWidth: true }
                }
            }
            Item { implicitHeight: 4 }
        }
    }
}
