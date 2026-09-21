import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../theme"
import "../../components"
import "../../services"

// Idle & power (WP-13/WP-14): the ordered swayidle rule list persisted in
// SettingsBus under idle.rules, plus the lock-screen master gate.
ColumnLayout {
    id: root
    Layout.fillWidth: true
    spacing: 14

    property string powerProfile: "balanced"
    readonly property var idleActions: ["dim", "screenOff", "lock", "suspend", "hibernate", "effects"]
    function idleRules() { return SettingsBus.get("idle.rules", []) }
    function _idleClone() { return root.idleRules().map(function (x) { return Object.assign({}, x) }) }
    function idleUpd(i, k, v) { var a = root._idleClone(); a[i][k] = v; SettingsBus.set("idle.rules", a) }
    function idleAdd() { var a = root._idleClone(); a.push({ timeoutSec: 300, action: "lock" }); SettingsBus.set("idle.rules", a) }
    function idleDel(i) { var a = root._idleClone(); a.splice(i, 1); SettingsBus.set("idle.rules", a) }

    Process {
        id: powerProc
        command: ["mujo", "power-profile", "get"]
        stdout: StdioCollector {
            onStreamFinished: {
                var p = this.text.trim()
                if (p === "performance" || p === "balanced" || p === "power-saver") root.powerProfile = p
            }
        }
    }
    Component.onCompleted: powerProc.running = true

    MujoCard {
        title: "Idle & Power"
        iconName: "bedtime"
        badgeText: SettingsBus.get("idle.enabled", true) ? "ON" : "OFF"
        badgeColor: SettingsBus.get("idle.enabled", true) ? Theme.success : Theme.textDim

        actions: ToggleSwitch {
            checked: SettingsBus.get("idle.enabled", true)
            onToggled: function (c) { SettingsBus.set("idle.enabled", c) }
        }

        MujoSettingRow {
            iconName: "bolt"
            title: "Hardware Power Profile"
            description: "CPU energy performance scaling governor."

            MujoSegmented {
                model: [
                    { id: "performance", label: "Performance", icon: "speed" },
                    { id: "balanced",    label: "Balanced",    icon: "balance" },
                    { id: "power-saver", label: "Power Saver", icon: "eco" }
                ]
                current: root.powerProfile
                onSelected: function(id) {
                    root.powerProfile = id
                    Quickshell.execDetached(["mujo", "power-profile", "set", id])
                }
            }
        }

        // Lock screen master gate (WP-14). Off = lock triggers (idle rule,
        // Mod+Ctrl+L, power menu) no-op with a toast.
        SettingRow {
            path: "lock.enable"
            def: true
            kind: "toggle"
            iconName: "lock"
            title: "Lock Screen"
            description: "Off makes every lock trigger no-op"
        }

        Text {
            Layout.fillWidth: true
            text: "Ordered timers fire after the given seconds of inactivity. Audio / AC "
                + "inhibits skip that step while sound plays or the machine is on mains."
            color: Theme.textDim
            font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSmall
            wrapMode: Text.WordWrap
        }

        Repeater {
            model: SettingsBus.get("idle.rules", [])
            delegate: InsetPanel {
                id: ruleCard
                required property int index
                required property var modelData
                Layout.fillWidth: true
                implicitHeight: ruleBody.implicitHeight + 24
                opacity: SettingsBus.get("idle.enabled", true) ? 1 : 0.5

                ColumnLayout {
                    id: ruleBody
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        Text { text: "After"; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSmall }
                        TextField {
                            Layout.preferredWidth: 80
                            text: String(ruleCard.modelData.timeoutSec)
                            onAccepted: root.idleUpd(ruleCard.index, "timeoutSec", Math.max(1, parseInt(text) || 1))
                        }
                        Text { text: "seconds"; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSmall }
                        Item { Layout.fillWidth: true }
                        DialogButton { text: "Remove"; onClicked: root.idleDel(ruleCard.index) }
                    }

                    Flow {
                        Layout.fillWidth: true
                        spacing: 7
                        Repeater {
                            model: root.idleActions
                            delegate: DisplayChip {
                                required property var modelData
                                label: modelData
                                selected: modelData === ruleCard.modelData.action
                                onClicked: root.idleUpd(ruleCard.index, "action", modelData)
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 18
                        RowLayout {
                            spacing: 7
                            ToggleSwitch {
                                checked: !!ruleCard.modelData.inhibitWhenAudio
                                onToggled: function (c) { root.idleUpd(ruleCard.index, "inhibitWhenAudio", c) }
                            }
                            Text { text: "Skip while audio plays"; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSmall }
                        }
                        RowLayout {
                            spacing: 7
                            ToggleSwitch {
                                checked: !!ruleCard.modelData.inhibitWhenCharging
                                onToggled: function (c) { root.idleUpd(ruleCard.index, "inhibitWhenCharging", c) }
                            }
                            Text { text: "Skip on AC power"; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSmall }
                        }
                        Item { Layout.fillWidth: true }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            DialogButton { text: "Add rule"; onClicked: root.idleAdd() }
            Item { Layout.fillWidth: true }
        }

        Text {
            Layout.fillWidth: true
            text: "Actions: dim (brightness→20%), screenOff, lock, suspend, hibernate, "
                + "effects. “custom” rules (a shell command) are editable via "
                + "`mujo settings set idle.rules …`."
            color: Theme.textDim
            font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSmall
            wrapMode: Text.WordWrap
        }
    }
}
