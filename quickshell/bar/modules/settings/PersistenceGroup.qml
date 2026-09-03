import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../theme"
import "../../components"

// Persistence (impermanence) manager group.
// Root filesystem is wiped on every boot (Btrfs impermanence) — only /persist bindings survive.
ColumnLayout {
    id: root
    Layout.fillWidth: true
    spacing: 14

    property var managed: ({ user: [], system: [] })
    property var current: ({ user: [], system: [] })
    property string addKind: "user"
    property string addPath: ""
    property string addError: ""

    function refresh() { listProc.running = true; curProc.running = true }

    // Combined {kind, path} rows
    function combine(obj) {
        var out = []
        var u = obj.user || [], s = obj.system || []
        for (var i = 0; i < u.length; i++) out.push({ kind: "user", path: u[i] })
        for (var j = 0; j < s.length; j++) out.push({ kind: "system", path: s[j] })
        return out
    }
    readonly property var managedRows: combine(managed)
    readonly property var currentRows: combine(current)

    Process {
        id: listProc
        command: ["mujo", "persist", "list"]
        stdout: StdioCollector {
            onStreamFinished: { try { root.managed = JSON.parse(this.text) } catch (e) {} }
        }
    }
    Process {
        id: curProc
        command: ["mujo", "persist", "current"]
        stdout: StdioCollector {
            onStreamFinished: { try { root.current = JSON.parse(this.text) } catch (e) {} }
        }
    }
    Component.onCompleted: refresh()

    Process {
        id: mutProc
        stderr: StdioCollector { onStreamFinished: { if (this.text.trim() !== "") root.addError = this.text.trim() } }
        onExited: function(code) { if (code === 0) { root.addPath = ""; pathField.text = ""; root.addError = "" } root.refresh() }
    }
    function addPersist() {
        if (root.addPath.trim() === "") return
        root.addError = ""
        mutProc.command = ["mujo", "persist", "add", root.addKind, root.addPath.trim()]
        mutProc.running = true
    }
    function removePersist(kind, path) {
        mutProc.command = ["mujo", "persist", "remove", kind, path]
        mutProc.running = true
    }

    // ── Add Persistence Path Card ─────────────────────────────────────────────
    MujoCard {
        title: "Add Persistence Directory"
        iconName: "create_new_folder"
        badgeText: "BTRFS IMPERMANENCE"
        badgeColor: Theme.accent
        isNixos: true

        actions: DialogButton {
            text: "Rebuild to apply"
            primary: true
            onClicked: Quickshell.execDetached(["mujo", "persist", "apply"])
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 10

            Text {
                Layout.fillWidth: true
                text: "The root filesystem is wiped on every boot. Folders added here are persisted in /persist and bind-mounted automatically upon system rebuild."
                color: Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                wrapMode: Text.WordWrap
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                DisplayChip { label: "User (~/)"; selected: root.addKind === "user"; onClicked: root.addKind = "user" }
                DisplayChip { label: "System (/var/...)"; selected: root.addKind === "system"; onClicked: root.addKind = "system" }
                TextField {
                    id: pathField
                    Layout.fillWidth: true
                    placeholder: root.addKind === "user" ? "Documents/vault  (relative to home)" : "/var/lib/service  (absolute)"
                    onTextChanged: root.addPath = text
                    onAccepted: root.addPersist()
                }
                DialogButton {
                    text: "Add Path"
                    primary: true
                    enabled: root.addPath.trim() !== ""
                    onClicked: root.addPersist()
                }
            }
            Text {
                visible: root.addError !== ""
                text: root.addError
                color: Theme.error
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
        }
    }

    // ── Managed Paths Card ────────────────────────────────────────────────────
    MujoCard {
        title: "Managed Persistence Paths"
        iconName: "edit_note"
        badgeText: root.managedRows.length + " MANAGED"
        badgeColor: Theme.accent

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6

            Repeater {
                model: root.managedRows
                delegate: Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: 40
                    radius: Theme.radiusSm
                    color: Theme.surface
                    border.color: Theme.border
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 6
                        spacing: 8
                        Rectangle {
                            implicitWidth: kindL.implicitWidth + 12; implicitHeight: 18
                            radius: Theme.radiusSm
                            color: Theme.accentDim
                            Text { id: kindL; anchors.centerIn: parent; text: modelData.kind; color: Theme.accent; font.family: Theme.fontMono; font.pixelSize: Theme.fontSizeLabel }
                        }
                        Text {
                            Layout.fillWidth: true
                            text: modelData.path
                            color: Theme.text
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSizeSmall
                            elide: Text.ElideMiddle
                        }
                        IconButton { iconName: "delete"; onClicked: root.removePersist(modelData.kind, modelData.path) }
                    }
                }
            }

            Text {
                visible: root.managedRows.length === 0
                text: "Nothing added here yet. Add a directory above."
                color: Theme.textDim
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
            }
        }
    }

    // ── Currently Persisted Paths Card ────────────────────────────────────────
    MujoCard {
        title: "Currently Active Bind Mounts"
        iconName: "folder_shared"
        badgeText: root.currentRows.length + " ACTIVE"
        badgeColor: Theme.success

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6

            Repeater {
                model: root.currentRows
                delegate: Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: 36
                    radius: Theme.radiusSm
                    color: Theme.bg
                    border.color: Theme.border
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 8
                        MaterialIcon { iconName: modelData.kind === "user" ? "person" : "dns"; pixelSize: 15; color: Theme.textDim }
                        Text {
                            Layout.fillWidth: true
                            text: modelData.path
                            color: Theme.textSecondary
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSizeSmall
                            elide: Text.ElideMiddle
                        }
                    }
                }
            }

            Text {
                visible: root.currentRows.length === 0
                text: "Reading persisted mounts..."
                color: Theme.textDim
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
            }
        }
    }
}
