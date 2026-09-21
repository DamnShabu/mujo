import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../theme"
import "../../components"
import "../../services"

// Privacy group. Every row here changes something the shell actually controls:
// the recent-files index it writes, and the IP geolocation `mujo weather fetch`
// falls back to. Host hardening (sudo policy, screencast portal, telemetry) is
// owned by the NixOS modules and is reported — not toggled — in SecurityGroup.
ColumnLayout {
    id: root
    Layout.fillWidth: true
    spacing: 14

    property int recentCount: 0
    property string clearMessage: ""
    property bool clearFailed: false

    // ── Local activity trail ──────────────────────────────────────────────────
    MujoCard {
        title: "Local Activity Trail"
        iconName: "history"
        badgeText: root.recentCount + " ENTRIES"
        badgeColor: root.recentCount > 0 ? Theme.accent : Theme.textDim

        actions: DialogButton {
            text: "Clear recent files"
            enabled: root.recentCount > 0
            onClicked: clearProc.running = true
        }

        // Not a SettingRow: turning this off must also drop the trail that is
        // already stored, and that is two writes, not one.
        MujoSettingRow {
            iconName: "schedule"
            title: "Recently Launched Applications"
            description: "Keep the launcher's most-recent row. Turning this off also clears what is already recorded."

            ToggleSwitch {
                a11yName: "Recently Launched Applications"
                checked: SettingsBus.get("privacy.recentFiles", true)
                onToggled: function (c) {
                    SettingsBus.set("privacy.recentFiles", c)
                    if (!c) SettingsBus.set("apps.recent", [])
                }
            }
        }

        SettingRow {
            path: "privacy.locationAccess"
            def: true
            kind: "toggle"
            iconName: "location_on"
            title: "IP Geolocation Fallback"
            description: "When no city is set, let the weather service resolve your position from your IP address."
        }

        Text {
            visible: root.clearMessage !== ""
            text: root.clearMessage
            color: root.clearFailed ? Theme.warning : Theme.success
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
        }
    }

    Process {
        id: statusProc
        running: true
        command: ["mujo", "privacy", "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.recentCount = JSON.parse(this.text).recentFilesCount || 0 } catch (e) {}
            }
        }
    }

    Process {
        id: clearProc
        command: ["mujo", "privacy", "clear-recent"]
        onExited: function (code) {
            root.clearFailed = code !== 0
            root.clearMessage = code === 0 ? "Recent files history cleared." : "Could not clear recent files."
            if (code === 0) root.recentCount = 0
            messageTimer.restart()
        }
    }

    Timer {
        id: messageTimer
        interval: 4000
        onTriggered: root.clearMessage = ""
    }
}
