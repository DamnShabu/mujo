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
    MujoCard {
        title: "Installed Flatpaks"
        badgeText: section.flatpaksList.length + " INSTALLED"

        // The search belongs to the list, so it rides in the section header
        // rather than in a bar of its own above the card.
        actions: Rectangle {
            implicitWidth: 220
            implicitHeight: 30
            radius: Theme.radiusSm
            color: Theme.bg
            border.width: 1
            border.color: flatSearch.activeFocus ? Theme.borderInteractive : Theme.border
            Behavior on border.color { ColorAnimation { duration: Anim.d(Anim.fast) } }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 9
                anchors.rightMargin: 9
                spacing: 7

                MaterialIcon { iconName: "search"; pixelSize: 15; color: Theme.textDim }

                TextInput {
                    id: flatSearch
                    Layout.fillWidth: true
                    verticalAlignment: Text.AlignVCenter
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    clip: true
                    selectByMouse: true
                    onTextChanged: section.searchQuery = text.trim().toLowerCase()

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: flatSearch.text === ""
                        text: "Filter packages"
                        color: Theme.textDim
                        font: flatSearch.font
                    }
                }
            }
        }

        ColumnLayout {
            id: fpCol
            Layout.fillWidth: true
            spacing: 6

            readonly property var filteredFlatpaks: section.flatpaksList.filter(function (f) {
                if (section.searchQuery === "") return true
                return (f.name && f.name.toLowerCase().indexOf(section.searchQuery) >= 0)
                    || (f.id && f.id.toLowerCase().indexOf(section.searchQuery) >= 0)
            })

            EmptyState {
                Layout.fillWidth: true
                Layout.topMargin: 16
                Layout.bottomMargin: 16
                visible: fpCol.filteredFlatpaks.length === 0
                iconName: section.flatpaksList.length === 0 ? "inventory_2" : "search_off"
                title: section.flatpaksList.length === 0 ? "No Flatpaks installed" : "Nothing matches that filter"
                hint: section.flatpaksList.length === 0
                    ? "Install one with flatpak install, and it shows up here."
                    : "Try part of an application name or its app id."
            }

            Repeater {
                model: fpCol.filteredFlatpaks

                delegate: ListRow {
                    required property var modelData

                    MaterialIcon {
                        iconName: "inventory_2"
                        pixelSize: 18
                        color: Theme.accent
                        Layout.alignment: Qt.AlignVCenter
                        Layout.rightMargin: 2
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        RowLayout {
                            spacing: 7

                            Text {
                                text: modelData.name
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeBody
                                font.weight: Font.DemiBold
                            }

                            StatusTag {
                                visible: modelData.version !== undefined && modelData.version !== ""
                                text: modelData.version || ""
                            }
                        }

                        Text {
                            text: modelData.id + (modelData.size ? " · " + modelData.size : "")
                            color: Theme.textSecondary
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSizeLabel
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }

                    IconButton {
                        iconName: "folder_open"
                        onClicked: section.openDataFolder(".var/app/" + modelData.id)
                    }

                    DialogButton {
                        text: "Launch"
                        onClicked: Launch.run(["mujo-run", "flatpak", "run", modelData.id], modelData.name, "shield")
                    }
                }
            }
        }
    }
}
