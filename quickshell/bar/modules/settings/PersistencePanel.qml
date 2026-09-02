import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../theme"
import "../../components"

// Persistence (impermanence) manager. The root is wiped on every boot; only
// listed paths survive. "Managed here" is a GUI-owned list folded into the same
// NixOS impermanence config (nixos/user-persistence.json → user-persistence.nix)
// — one source of truth, applied by a rebuild. "Currently persisted" is the live
// read-only truth (active bind mounts). All edits go through `mujo persist`.
Item {
    id: root

    property var managed: ({ user: [], system: [] })
    property var current: ({ user: [], system: [] })
    property string addKind: "user"
    property string addPath: ""
    property string addError: ""

    function refresh() { listProc.running = true; curProc.running = true }

    // combined {kind, path} rows
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
                brand: "persistence"
                title: "Persistence & Storage"
                subtitle: "Root filesystem is wiped on every boot (Btrfs impermanence) — only /persist bindings survive."
                isNixos: true
                badgeText: root.managedRows.length + " PATHS"
                badgeColor: Theme.accent

                DialogButton {
                    text: "Rebuild to apply"
                    primary: true
                    onClicked: Quickshell.execDetached(["mujo", "persist", "apply"])
                }
            }

            // ── Add ───────────────────────────────────────────────────────────
            MujoCard {
                title: "Add Persistence Directory"
                iconName: "create_new_folder"

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        DisplayChip { label: "User"; selected: root.addKind === "user"; onClicked: root.addKind = "user" }
                        DisplayChip { label: "System"; selected: root.addKind === "system"; onClicked: root.addKind = "system" }
                        TextField {
                            id: pathField
                            Layout.fillWidth: true
                            placeholder: root.addKind === "user" ? "Documents/vault  (relative to home)" : "/var/lib/service  (absolute)"
                            onTextChanged: root.addPath = text
                            onAccepted: root.addPersist()
                        }
                        DialogButton {
                            text: "Add"
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

            // ── Managed Paths Card ────────────────────────────────────────────
            MujoCard {
                title: "Managed by Settings (Needs Rebuild)"
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

            // ── Currently Persisted Paths Card ────────────────────────────────
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

            Item { implicitHeight: 12 }
        }
    }
}
