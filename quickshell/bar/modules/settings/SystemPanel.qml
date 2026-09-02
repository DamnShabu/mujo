import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../theme"
import "../../components"

// System / NixOS (WP-11). Generation card, a streaming rebuild/update/GC/rollback
// log pane (cancel kills the process; failure surfaces a rollback), generations
// list with typed-confirm rollback, store size, and a flake.lock update checker.
// Every long op is async — the UI never blocks.
Item {
    id: root

    readonly property string homeNixconf: (Quickshell.env("HOME") || "") + "/nixconf"

    property var gens: []
    property var status: ({})
    property string storeUsed: ""
    property string storeSize: ""

    // streaming op state (shared by rebuild / update / gc / rollback)
    property bool running: false
    property string opLabel: ""
    property var logLines: []
    property int exitCode: -999          // -999 = not finished
    property bool failed: false

    // confirm states
    property bool confirmGc: false
    property int rollbackTarget: -1      // generation awaiting typed confirmation

    // local overrides (WP-12)
    property var overrides: []
    property string confirmRemove: ""

    function refresh() { genProc.running = true; statusProc.running = true; storeProc.running = true; root.refreshOverrides() }
    function refreshOverrides() { ovProc.running = true }
    Component.onCompleted: root.refresh()

    Process { id: ovProc; command: ["mujo", "overrides", "list"]; stdout: StdioCollector { onStreamFinished: { try { root.overrides = JSON.parse(this.text) } catch (e) { root.overrides = [] } } } }
    Process { id: ovMutate; onExited: root.refreshOverrides() }
    function ovRun(args) { if (ovMutate.running) return; ovMutate.command = ["mujo", "overrides"].concat(args); ovMutate.running = true }
    function ovShow(name) { root.runStreaming(["mujo", "overrides", "show", name], "Override: " + name) }

    Process { id: genProc; command: ["mujo", "generations"]; stdout: StdioCollector { onStreamFinished: { try { root.gens = JSON.parse(this.text) } catch (e) { root.gens = [] } } } }
    Process { id: statusProc; command: ["mujo", "update-status"]; stdout: StdioCollector { onStreamFinished: { try { root.status = JSON.parse(this.text) } catch (e) { root.status = ({}) } } } }
    Process {
        id: storeProc
        command: ["sh", "-c", "df -h --output=used,size /nix/store 2>/dev/null | tail -1"]
        stdout: StdioCollector { onStreamFinished: { var p = this.text.trim().split(/\s+/); root.storeUsed = p[0] || "?"; root.storeSize = p[1] || "?" } }
    }

    Process {
        id: runProc
        stdout: SplitParser { splitMarker: "\n"; onRead: line => root._append(line) }
        stderr: SplitParser { splitMarker: "\n"; onRead: line => root._append(line) }
        onExited: (code, st) => {
            root.running = false
            root.exitCode = code
            root.failed = code !== 0
            root._append(code === 0 ? "✓ done" : "✗ exited with code " + code)
            if (code === 0) root.refresh()
        }
    }
    function _append(l) {
        var a = root.logLines.slice()
        a.push(l)
        if (a.length > 500) a = a.slice(a.length - 500)
        root.logLines = a
    }
    function runStreaming(cmd, label) {
        if (root.running) return
        root.logLines = []; root.exitCode = -999; root.failed = false
        root.running = true; root.opLabel = label
        runProc.command = cmd
        runProc.running = true
    }
    function cancel() { if (root.running) runProc.running = false }   // best-effort SIGTERM to the client

    function doRebuild() { root.runStreaming(["pkexec", "nixos-rebuild", "switch", "--flake", root.homeNixconf + "#main"], "Rebuild & switch") }
    function doUpdate() { root.runStreaming(["mujo", "update"], "Update — pull · flake update · rebuild") }
    function doGc() { root.confirmGc = false; root.runStreaming(["pkexec", "nix-collect-garbage", "-d"], "Garbage collect") }
    function doRollback(n) {
        root.rollbackTarget = -1
        root.runStreaming(["pkexec", "sh", "-c",
            "nix-env --switch-generation " + n + " -p /nix/var/nix/profiles/system && /nix/var/nix/profiles/system/bin/switch-to-configuration switch"],
            "Rollback to generation " + n)
    }
    readonly property int currentGen: { for (var i = 0; i < root.gens.length; i++) if (root.gens[i].current) return root.gens[i].number; return -1 }
    readonly property int prevGen: { for (var i = 0; i < root.gens.length; i++) if (root.gens[i].number < root.currentGen) return root.gens[i].number; return -1 }

    MujoFlickable {
        anchors.fill: parent
        contentHeight: mainCol.implicitHeight + 48

        ColumnLayout {
            id: mainCol
            x: 24
            y: 24
            width: parent.width - 48
            spacing: 16

            MujoHero {
                brand: "system"
                title: "System / NixOS"
                subtitle: "System generations, live rebuild logs, flake updates, and local module overrides."
                isNixos: true
                activeState: root.running
                badgeText: root.running ? "BUILDING" : (root.currentGen >= 0 ? "GEN #" + root.currentGen : "")
                badgeColor: root.running ? Theme.accent : Theme.success
            }

            // ── generation + store card ──
            MujoCard {
                title: "System Generation & Store"
                iconName: "memory"
                badgeText: root.currentGen >= 0 ? "GEN #" + root.currentGen : ""
                badgeColor: Theme.accent

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true; spacing: 10
                        Text { text: "Generation"; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeBody; Layout.preferredWidth: 120 }
                        Text { text: root.currentGen >= 0 ? "#" + root.currentGen + " (current)" : "…"; color: Theme.text; font.family: Theme.fontMono; font.pixelSize: Theme.fontSizeSmall }
                        Rectangle {
                            visible: !!root.status.rebootRequired
                            implicitWidth: rbl.implicitWidth + 16; implicitHeight: 20; radius: Theme.radiusSm
                            color: Qt.rgba(Theme.warning.r, Theme.warning.g, Theme.warning.b, 0.18); border.color: Theme.warning
                            Text { id: rbl; anchors.centerIn: parent; text: "reboot to apply"; color: Theme.warning; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeLabel }
                        }
                        Item { Layout.fillWidth: true }
                    }

                    RowLayout {
                        Layout.fillWidth: true; spacing: 10
                        Text { text: "Nix store"; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeBody; Layout.preferredWidth: 120 }
                        Text { text: (root.storeUsed || "…") + " used of " + (root.storeSize || "…"); color: Theme.text; font.family: Theme.fontMono; font.pixelSize: Theme.fontSizeSmall }
                        Item { Layout.fillWidth: true }
                    }

                    // update badge
                    RowLayout {
                        Layout.fillWidth: true; spacing: 10
                        visible: root.status.updateSuggested !== undefined
                        Text { text: "Updates"; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeBody; Layout.preferredWidth: 120 }
                        MaterialIcon { iconName: root.status.updateSuggested ? "sync_problem" : "check_circle"; pixelSize: 15; color: root.status.updateSuggested ? Theme.warning : Theme.success }
                        Text {
                            text: root.status.updateSuggested
                                ? (root.status.lockNewerThanSystem ? "flake.lock changed — not yet switched" : "lock is " + root.status.lockAgeDays + " days old")
                                : "up to date (" + (root.status.lockAgeDays || 0) + "d)"
                            color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSmall
                        }
                        Item { Layout.fillWidth: true }
                    }
                }
            }

            // ── actions ──
            RowLayout {
                Layout.fillWidth: true; spacing: 10
                DialogButton { text: "Rebuild & switch"; primary: true; enabled: !root.running; onClicked: root.doRebuild() }
                DialogButton { text: "Update"; enabled: !root.running; onClicked: root.doUpdate() }
                DialogButton { text: root.confirmGc ? "Confirm GC?" : "Garbage collect"; enabled: !root.running; onClicked: { if (root.confirmGc) root.doGc(); else root.confirmGc = true } }
                DialogButton { text: "Reload niri"; enabled: !root.running; onClicked: Quickshell.execDetached(["niri", "msg", "action", "reload-config"]) }
                Item { Layout.fillWidth: true }
            }

            // ── log pane (rebuild/update/gc/rollback output) ──
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 220
                visible: root.running || root.logLines.length > 0
                radius: Theme.radiusMd
                color: Theme.bg
                border.color: root.failed ? Theme.error : (root.running ? Theme.accent : Theme.border)

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 6
                    RowLayout {
                        Layout.fillWidth: true; spacing: 8
                        Spinner { size: 13; visible: root.running }
                        MaterialIcon { visible: !root.running; iconName: root.failed ? "error" : "check_circle"; pixelSize: 14; color: root.failed ? Theme.error : Theme.success }
                        Text { text: root.opLabel; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSmall; Layout.fillWidth: true; elide: Text.ElideRight }
                        DialogButton { text: "Cancel"; visible: root.running; onClicked: root.cancel() }
                        DialogButton { text: "Roll back to #" + root.prevGen; visible: root.failed && root.prevGen >= 0 && !root.running; onClicked: root.doRollback(root.prevGen) }
                        DialogButton { text: "Clear"; visible: !root.running && root.logLines.length > 0; onClicked: root.logLines = [] }
                    }
                    ListView {
                        id: logView
                        Layout.fillWidth: true; Layout.fillHeight: true
                        clip: true
                        model: root.logLines
                        boundsBehavior: Flickable.DragAndOvershootBounds
                        onCountChanged: positionViewAtEnd()
                        delegate: Text {
                            required property var modelData
                            width: logView.width
                            text: modelData
                            color: Theme.textSecondary
                            font.family: Theme.fontMono; font.pixelSize: Theme.fontSizeLabel
                            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                        }
                    }
                }
            }

            // ── local overrides card (WP-12) ──
            MujoCard {
                visible: !(root.running || root.logLines.length > 0)
                title: "Local Module Overrides"
                iconName: "tune"
                badgeText: root.overrides.length + " OVERRIDES"

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Repeater {
                        model: root.overrides
                        delegate: Rectangle {
                            required property var modelData
                            Layout.fillWidth: true
                            implicitHeight: 38
                            radius: Theme.radiusMd
                            color: Theme.surface
                            border.color: Theme.border
                            RowLayout {
                                anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 10; spacing: 10
                                Rectangle { implicitWidth: 8; implicitHeight: 8; radius: 4; color: modelData.enabled ? Theme.success : Theme.textSecondary }
                                Text { text: modelData.name; color: Theme.text; font.family: Theme.fontMono; font.pixelSize: Theme.fontSizeSmall; Layout.fillWidth: true; elide: Text.ElideRight }
                                DialogButton { text: "Show"; onClicked: root.ovShow(modelData.name) }
                                DialogButton { text: modelData.enabled ? "Disable" : "Enable"; onClicked: root.ovRun([modelData.enabled ? "disable" : "enable", modelData.name]) }
                                DialogButton {
                                    text: root.confirmRemove === modelData.name ? "Confirm?" : "Remove"
                                    onClicked: { if (root.confirmRemove === modelData.name) { root.confirmRemove = ""; root.ovRun(["remove", modelData.name]) } else root.confirmRemove = modelData.name }
                                }
                            }
                        }
                    }

                    Text {
                        visible: root.overrides.length === 0
                        text: "No overrides. Add one below, then Rebuild & switch to apply."
                        color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeLabel
                    }

                    RowLayout {
                        Layout.fillWidth: true; spacing: 8
                        TextField { id: ovAddField; Layout.fillWidth: true; placeholder: "new-override-name" }
                        DialogButton {
                            text: "Add from template"; primary: true
                            enabled: /^[a-zA-Z0-9_-]+$/.test(ovAddField.text.trim()) && ovAddField.text.trim() !== "template"
                            onClicked: { root.ovRun(["add", ovAddField.text.trim()]); ovAddField.text = "" }
                        }
                    }
                }
            }

            // ── generations history card ──
            MujoCard {
                visible: !(root.running || root.logLines.length > 0)
                title: "System Generation History"
                iconName: "history"
                badgeText: root.gens.length + " GENERATIONS"

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Repeater {
                        model: root.gens
                        delegate: Rectangle {
                            required property var modelData
                            Layout.fillWidth: true
                            implicitHeight: 40
                            radius: Theme.radiusMd
                            color: modelData.current ? Theme.accentDim : Theme.surface
                            border.color: modelData.current ? Theme.accent : Theme.border
                            RowLayout {
                                anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 10; spacing: 10
                                Text { text: "#" + modelData.number; color: Theme.text; font.family: Theme.fontMono; font.pixelSize: Theme.fontSizeSmall; Layout.preferredWidth: 60 }
                                Text { text: modelData.date; color: Theme.textSecondary; font.family: Theme.fontMono; font.pixelSize: Theme.fontSizeLabel; Layout.fillWidth: true; elide: Text.ElideRight }
                                Text { visible: modelData.current; text: "current"; color: Theme.accent; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeLabel }
                                DialogButton { text: "Roll back"; visible: !modelData.current; enabled: !root.running; onClicked: root.rollbackTarget = modelData.number }
                            }
                        }
                    }

                    // typed-confirm rollback
                    RowLayout {
                        Layout.fillWidth: true; spacing: 8
                        visible: root.rollbackTarget >= 0
                        Text { text: "Type " + root.rollbackTarget + " to roll back:"; color: Theme.warning; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSmall }
                        TextField { id: rbField; Layout.preferredWidth: 100; placeholder: String(root.rollbackTarget); onAccepted: if (text.trim() === String(root.rollbackTarget)) root.doRollback(root.rollbackTarget) }
                        DialogButton { text: "Confirm rollback"; primary: true; enabled: rbField.text.trim() === String(root.rollbackTarget); onClicked: root.doRollback(root.rollbackTarget) }
                        DialogButton { text: "Cancel"; onClicked: { root.rollbackTarget = -1; rbField.text = "" } }
                    }
                }
            }

            Item { implicitHeight: 12 }
        }
    }
}
