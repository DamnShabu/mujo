import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import "../../theme"
import "../../components"
import "../../services"

// Every dialog the groups view puts over itself: create, rename, delete, and the
// application picker. It owns the modal state and the writes to `apps.groups`
// that the dialogs perform, so the view behind it only says which dialog to
// open and which group is current.
Item {
    id: modals

    // Which dialog is up: "" | "create" | "rename" | "delete" | "add-apps"
    property string dialog: ""
    readonly property bool active: dialog !== ""

    required property var groups
    required property var currentGroup
    required property int activeGroupIndex
    required property var availableApps

    // Pre-filled by open(), then edited in the dialog.
    property string groupName: ""
    property string groupIcon: "folder"
    property string filterQuery: ""

    // The group list was rewritten. `selectIndex` is which group to make current
    // afterwards, or -1 to leave the selection where it is — the view owns that,
    // because it also owns the keyboard cursor.
    signal groupsWritten(int selectIndex)

    anchors.fill: parent
    visible: active
    z: 90

    readonly property var iconChoices: [
        "folder", "code", "work", "sports_esports", "terminal",
        "language", "music_note", "play_circle", "image", "palette",
        "edit_note", "settings", "build", "bookmark", "star", "dashboard"
    ]


    function open(which, name, icon) {
        modals.groupName = name === undefined ? "" : name
        modals.groupIcon = icon === undefined ? "folder" : icon
        modals.filterQuery = ""
        modals.dialog = which
    }

    function close() { modals.dialog = "" }

    function iconSource(name) {
        if (!name) return ""
        if (name.indexOf("://") >= 0) return name
        if (name.charAt(0) === "/") return "file://" + name
        return Quickshell.iconPath(name, "application-x-executable")
    }

    // ── The four writes to apps.groups ────────────────────────────────────────

    function createGroup(name, icon) {
        const cleanName = name.trim()
        if (!cleanName) return
        const updated = modals.groups.slice()
        updated.push({ id: "group-" + Date.now(), name: cleanName, icon: icon || "folder", apps: [] })
        SettingsBus.set("apps.groups", updated)
        modals.dialog = ""
        modals.groupsWritten(updated.length - 1)
        Notifications.notify("Group created", cleanName, icon || "folder", "low", { transient: true })
    }

    function renameGroup(newName, newIcon) {
        if (!modals.currentGroup) return
        const cleanName = newName.trim()
        if (!cleanName) return
        const updated = modals.groups.slice()
        const g = JSON.parse(JSON.stringify(modals.currentGroup))
        g.name = cleanName
        g.icon = newIcon || g.icon || "folder"
        updated[modals.activeGroupIndex] = g
        SettingsBus.set("apps.groups", updated)
        modals.dialog = ""
        modals.groupsWritten(-1)
        Notifications.notify("Group updated", cleanName, g.icon, "low", { transient: true })
    }

    function deleteCurrentGroup() {
        if (!modals.currentGroup) return
        const name = modals.currentGroup.name
        const removed = modals.activeGroupIndex
        const updated = modals.groups.filter(function (g, idx) { return idx !== removed })
        SettingsBus.set("apps.groups", updated)
        modals.dialog = ""
        modals.groupsWritten(Math.max(0, removed - 1))
        Notifications.notify("Group deleted", name, "delete", "low", { transient: true })
    }

    function addAppToCurrentGroup(appId) {
        if (!modals.currentGroup || !appId) return
        const updated = modals.groups.slice()
        const g = JSON.parse(JSON.stringify(modals.currentGroup))
        if (!g.apps) g.apps = []
        if (g.apps.indexOf(appId) >= 0) return
        g.apps.push(appId)
        updated[modals.activeGroupIndex] = g
        SettingsBus.set("apps.groups", updated)
        modals.groupsWritten(-1)
    }

    function removeAppFromCurrentGroup(appId) {
        if (!modals.currentGroup || !appId) return
        const updated = modals.groups.slice()
        const g = JSON.parse(JSON.stringify(modals.currentGroup))
        if (!g.apps) return
        g.apps = g.apps.filter(function (id) { return id !== appId })
        updated[modals.activeGroupIndex] = g
        SettingsBus.set("apps.groups", updated)
        modals.groupsWritten(-1)
    }

        // 1. Scrim for active modal
        Rectangle {
            anchors.fill: parent
            z: 90
            opacity: modals.dialog !== "" ? 1 : 0
            visible: opacity > 0
            color: Theme.withAlpha("#000000", 0.65)
            Behavior on opacity { NumberAnimation { duration: Anim.d(Anim.fast) } }

            MouseArea {
                anchors.fill: parent
                onClicked: modals.dialog = ""
            }
        }

        // 2. Create / Rename Group Dialog
        Rectangle {
            id: groupEditModal
            anchors.centerIn: parent
            z: 100
            readonly property bool shown: modals.dialog === "create" || modals.dialog === "rename"
            visible: opacity > 0
            width: 380
            height: editCol.implicitHeight + 28
            radius: Theme.radiusLg
            color: Theme.surface
            border.color: Theme.borderStrong
            border.width: 1

            scale: groupEditModal.shown ? 1.0 : 0.94
            opacity: groupEditModal.shown ? 1.0 : 0.0
            Behavior on scale { NumberAnimation { duration: Anim.d(Anim.fast); easing.type: Anim.easeStandard } }
            Behavior on opacity { NumberAnimation { duration: Anim.d(Anim.fast) } }

            ColumnLayout {
                id: editCol
                anchors.fill: parent
                anchors.margins: 16
                spacing: 14

                RowLayout {
                    Layout.fillWidth: true
                    MaterialIcon {
                        iconName: modals.groupIcon || "folder"
                        pixelSize: 20
                        color: Theme.accent
                    }
                    Text {
                        text: modals.dialog === "create" ? "Create New Group" : "Rename Group"
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeTitle + 1
                        font.bold: true
                        Layout.fillWidth: true
                    }
                    IconButton {
                        iconName: "close"
                        onClicked: modals.dialog = ""
                    }
                }

                // Group Name Input
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 38
                    radius: Theme.radiusSm
                    color: Theme.bg
                    border.color: nameInput.activeFocus ? Theme.accent : Theme.border
                    border.width: 1

                    TextInput {
                        id: nameInput
                        anchors.fill: parent
                        anchors.margins: 8
                        verticalAlignment: Text.AlignVCenter
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeTitle
                        text: modals.groupName
                        onTextChanged: modals.groupName = text
                        focus: modals.dialog === "create" || modals.dialog === "rename"
                        Keys.onReturnPressed: {
                            if (modals.dialog === "create") modals.createGroup(nameInput.text, modals.groupIcon)
                            else modals.renameGroup(nameInput.text, modals.groupIcon)
                        }
                        Keys.onEscapePressed: modals.dialog = ""

                        Text {
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            text: "Enter group name (e.g. Work, Gaming, Creative)…"
                            color: Theme.textDim
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeTitle
                            visible: nameInput.text === ""
                        }
                    }
                }

                // Icon Picker
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    Text { text: "Choose Icon"; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeLabel }

                    Flow {
                        Layout.fillWidth: true
                        spacing: 6
                        Repeater {
                            model: modals.iconChoices
                            delegate: Rectangle {
                                id: iChoice
                                required property var modelData
                                readonly property bool isSelected: modals.groupIcon === modelData
                                implicitWidth: 32
                                implicitHeight: 32
                                radius: Theme.radiusSm
                                color: isSelected ? Theme.withAlpha(Theme.accent, 0.25) : (iHover.hovered ? Theme.surfaceHover : Theme.bg)
                                border.color: isSelected ? Theme.accent : Theme.border

                                MaterialIcon {
                                    anchors.centerIn: parent
                                    iconName: iChoice.modelData
                                    pixelSize: 16
                                    color: iChoice.isSelected ? Theme.accent : Theme.textSecondary
                                }
                                HoverHandler { id: iHover; cursorShape: Qt.PointingHandCursor }
                                TapHandler { onTapped: modals.groupIcon = iChoice.modelData }
                            }
                        }
                    }
                }

                // Dialog Actions
                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    spacing: 8
                    Item { Layout.fillWidth: true }

                    Rectangle {
                        Layout.preferredHeight: 30
                        Layout.preferredWidth: 80
                        radius: Theme.radiusSm
                        color: cancelH.hovered ? Theme.surfaceHover : Theme.surface
                        border.color: Theme.border
                        Text { anchors.centerIn: parent; text: "Cancel"; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeBody }
                        HoverHandler { id: cancelH; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: modals.dialog = "" }
                    }

                    Rectangle {
                        Layout.preferredHeight: 30
                        Layout.preferredWidth: 80
                        radius: Theme.radiusSm
                        color: saveH.hovered ? Theme.accent : Theme.withAlpha(Theme.accent, 0.85)
                        opacity: modals.groupName.trim() !== "" ? 1.0 : 0.5
                        Text { anchors.centerIn: parent; text: "Save"; color: Theme.bg; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeBody; font.bold: true }
                        HoverHandler { id: saveH; cursorShape: Qt.PointingHandCursor }
                        TapHandler {
                            onTapped: {
                                if (modals.dialog === "create") modals.createGroup(modals.groupName, modals.groupIcon)
                                else modals.renameGroup(modals.groupName, modals.groupIcon)
                            }
                        }
                    }
                }
            }
        }

        // 3. Delete Group Confirmation Dialog
        Rectangle {
            anchors.centerIn: parent
            z: 100
            visible: modals.dialog === "delete"
            width: 360
            height: delCol.implicitHeight + 28
            radius: Theme.radiusLg
            color: Theme.surface
            border.color: Theme.error
            border.width: 1

            ColumnLayout {
                id: delCol
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12

                RowLayout {
                    spacing: 8
                    MaterialIcon { iconName: "warning"; pixelSize: 22; color: Theme.error }
                    Text {
                        text: "Delete Group?"
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeTitle + 1
                        font.bold: true
                    }
                }

                Text {
                    text: "Are you sure you want to delete the group \"" + (modals.currentGroup ? modals.currentGroup.name : "") + "\"? Applications inside will remain installed on your system."
                    color: Theme.textSecondary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 6
                    spacing: 8
                    Item { Layout.fillWidth: true }

                    Rectangle {
                        Layout.preferredHeight: 30
                        Layout.preferredWidth: 80
                        radius: Theme.radiusSm
                        color: delCancH.hovered ? Theme.surfaceHover : Theme.surface
                        border.color: Theme.border
                        Text { anchors.centerIn: parent; text: "Cancel"; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeBody }
                        HoverHandler { id: delCancH; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: modals.dialog = "" }
                    }

                    Rectangle {
                        Layout.preferredHeight: 30
                        Layout.preferredWidth: 90
                        radius: Theme.radiusSm
                        color: delConfH.hovered ? Theme.error : Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.85)
                        Text { anchors.centerIn: parent; text: "Delete Group"; color: "#ffffff"; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeBody; font.bold: true }
                        HoverHandler { id: delConfH; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: modals.deleteCurrentGroup() }
                    }
                }
            }
        }

        // 4. Add Applications to Group Picker Modal
        Rectangle {
            anchors.centerIn: parent
            z: 100
            visible: modals.dialog === "add-apps"
            width: 440
            height: 380
            radius: Theme.radiusLg
            color: Theme.surface
            border.color: Theme.borderStrong
            border.width: 1

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 10

                RowLayout {
                    Layout.fillWidth: true
                    MaterialIcon { iconName: "add_circle"; pixelSize: 18; color: Theme.accent }
                    Text {
                        text: "Add to " + (modals.currentGroup ? modals.currentGroup.name : "Group")
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeTitle
                        font.bold: true
                        Layout.fillWidth: true
                    }
                    IconButton {
                        iconName: "close"
                        onClicked: modals.dialog = ""
                    }
                }

                // Search filter for available apps
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    radius: Theme.radiusSm
                    color: Theme.bg
                    border.color: addAppSearch.activeFocus ? Theme.accent : Theme.border

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 6
                        MaterialIcon { iconName: "search"; pixelSize: 15; color: Theme.textSecondary }
                        TextInput {
                            id: addAppSearch
                            Layout.fillWidth: true
                            verticalAlignment: Text.AlignVCenter
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeTitle
                            onTextChanged: modals.filterQuery = text
                            focus: modals.dialog === "add-apps"
                            Text {
                                anchors.fill: parent
                                verticalAlignment: Text.AlignVCenter
                                text: "Filter applications…"
                                color: Theme.textDim
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeTitle
                                visible: addAppSearch.text === ""
                            }
                        }
                    }
                }

                // Scrollable list of applications
                ListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 3
                    model: modals.availableApps
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: Rectangle {
                        id: addRow
                        required property var modelData
                        width: parent ? parent.width : 0
                        implicitHeight: 38
                        radius: Theme.radiusSm
                        color: addRowH.hovered ? Theme.surfaceHover : "transparent"

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 10

                            IconImage {
                                source: modals.iconSource(addRow.modelData.icon)
                                width: 24
                                height: 24
                            }

                            Text {
                                text: addRow.modelData.name
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSmall
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            Rectangle {
                                Layout.preferredHeight: 22
                                Layout.preferredWidth: 64
                                radius: Theme.radiusSm
                                color: addBtnH.hovered ? Theme.accent : Theme.surfaceActive
                                border.color: Theme.borderStrong

                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: 2
                                    MaterialIcon { iconName: "add"; pixelSize: 12; color: addBtnH.hovered ? Theme.bg : Theme.accent }
                                    Text { text: "Add"; color: addBtnH.hovered ? Theme.bg : Theme.text; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeLabel; font.bold: true }
                                }
                                HoverHandler { id: addBtnH; cursorShape: Qt.PointingHandCursor }
                                TapHandler {
                                    onTapped: modals.addAppToCurrentGroup(addRow.modelData.id)
                                }
                            }
                        }
                        HoverHandler { id: addRowH }
                    }
                }
            }
        }
}
