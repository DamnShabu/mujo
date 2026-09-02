import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../theme"
import "../../components"
import "../../services"

// Installed Flatpaks and their sandbox permissions. Owns the `mujo apps
// flatpaks` read and the search box over it, because nothing else uses either.
ColumnLayout {
    id: section

    property var flatpaksList: []
    property string searchQuery: ""

    spacing: 14

    Process {
        id: flatpaksProc
        command: ["mujo", "apps", "flatpaks"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { section.flatpaksList = JSON.parse(this.text) }
                catch (e) { section.flatpaksList = [] }
            }
        }
    }
    function refresh() { flatpaksProc.running = true }
    Component.onCompleted: refresh()

    // xdg-open under `sh -c` so ~ expands in the guest's own shell; the path is
    // a fixed relative string from the caller, never user input.
    function openDataFolder(relPath) {
        if (relPath && relPath !== "")
            Quickshell.execDetached(["sh", "-c", 'xdg-open "$HOME/' + relPath + '" || true'])
    }


    // Flatpak Summary Card
    MujoCard {
        title: "Flatpak Environment"
        iconName: "inventory_2"
        badgeText: section.flatpaksList.length + " APPS"
        badgeColor: Theme.accent

        MujoSettingRow {
            iconName: "security"
            title: "Application Permissions & Sandbox"
            description: "Fine-tune filesystem, network socket, and device permissions with Flatseal."

            DialogButton {
                text: "Open Flatseal"
                onClicked: Quickshell.execDetached(["sh", "-c", "flatpak run com.github.tchx84.Flatseal || true"])
            }
        }
    }

    // Filter search bar
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 38
        radius: Theme.radiusMd
        color: Theme.surface
        border.color: Theme.border

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 8
            MaterialIcon { iconName: "search"; pixelSize: 17; color: Theme.textDim }
            TextInput {
                id: flatSearch
                Layout.fillWidth: true
                verticalAlignment: Text.AlignVCenter
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeBody
                onTextChanged: section.searchQuery = text.trim().toLowerCase()
                Text {
                    visible: flatSearch.text === ""
                    text: "Filter installed Flatpak packages…"
                    color: Theme.textDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeBody
                }
            }
        }
    }

    // Flatpak List Card
    MujoCard {
        title: "Installed Flatpaks"
        iconName: "apps"
        badgeText: (section.flatpaksList.length) + " INSTALLED"

        ColumnLayout {
            id: fpCol
            Layout.fillWidth: true
            spacing: 4

            Text {
                visible: fpCol.filteredFlatpaks.length === 0
                text: section.flatpaksList.length === 0 ? "No Flatpaks installed." : "No Flatpaks matching the search query."
                color: Theme.textDim
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
            }

            readonly property var filteredFlatpaks: section.flatpaksList.filter(function(f) {
                if (section.searchQuery === "") return true
                return (f.name && f.name.toLowerCase().indexOf(section.searchQuery) >= 0)
                    || (f.id && f.id.toLowerCase().indexOf(section.searchQuery) >= 0)
            })

            Repeater {
                model: fpCol.filteredFlatpaks
                delegate: Rectangle {
                    id: fpRow
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: 56
                    radius: Theme.radiusMd
                    color: fp_hh.hovered ? Theme.surfaceHover : "transparent"
                    border.color: fp_hh.hovered ? Theme.borderStrong : "transparent"
                    Behavior on color { ColorAnimation { duration: Anim.d(Anim.fast) } }

                    HoverHandler { id: fp_hh }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 12

                        Rectangle {
                            Layout.preferredWidth: 32
                            Layout.preferredHeight: 32
                            Layout.alignment: Qt.AlignVCenter
                            radius: Theme.radiusSm
                            color: Theme.surfaceActive
                            MaterialIcon {
                                anchors.centerIn: parent
                                iconName: "inventory_2"
                                pixelSize: 17
                                color: Theme.accent
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 2

                            RowLayout {
                                spacing: 8
                                Layout.fillWidth: true

                                Text {
                                    text: fpRow.modelData.name
                                    color: Theme.text
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeBody
                                    font.bold: true
                                }

                                Rectangle {
                                    visible: fpRow.modelData.version !== undefined && fpRow.modelData.version !== ""
                                    implicitWidth: fpVerTxt.implicitWidth + 8
                                    implicitHeight: 16
                                    radius: Theme.radiusSm
                                    color: Theme.bg
                                    border.color: Theme.border
                                    Text {
                                        id: fpVerTxt
                                        anchors.centerIn: parent
                                        text: fpRow.modelData.version || ""
                                        color: Theme.textDim
                                        font.family: Theme.fontMono
                                        font.pixelSize: Theme.fontSizeLabel - 1
                                    }
                                }
                            }

                            Text {
                                text: fpRow.modelData.id + (fpRow.modelData.size ? " · " + fpRow.modelData.size : "")
                                color: Theme.textSecondary
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fontSizeSmall
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }

                        Rectangle {
                            Layout.preferredWidth: 30
                            Layout.preferredHeight: 30
                            Layout.alignment: Qt.AlignVCenter
                            radius: Theme.radiusSm
                            color: fp_data_hh.hovered ? Theme.surfaceActive : "transparent"
                            border.color: Theme.border
                            MaterialIcon {
                                anchors.centerIn: parent
                                iconName: "folder_open"
                                pixelSize: 15
                                color: Theme.textSecondary
                            }
                            HoverHandler { id: fp_data_hh; cursorShape: Qt.PointingHandCursor }
                            TapHandler { onTapped: section.openDataFolder(".var/app/" + fpRow.modelData.id) }
                        }

                        DialogButton {
                            Layout.alignment: Qt.AlignVCenter
                            text: "Launch"
                            onClicked: Launch.run(["mujo-run", "flatpak", "run", fpRow.modelData.id], fpRow.modelData.name, "shield")
                        }
                    }
                }
            }
        }
    }
}
