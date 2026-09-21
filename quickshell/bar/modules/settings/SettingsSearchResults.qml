import QtQuick
import QtQuick.Layouts
import "../../theme"
import "../../components"

// Omni-search results with breadcrumb navigation chips, instant preview,
// clean typography, and suggested search queries for empty state.
MujoFlickable {
    id: results

    property var shell: null

    contentHeight: col.implicitHeight + 48

    ColumnLayout {
        id: col
        x: Math.max(28, (results.width - width) / 2)
        y: 24
        width: Math.min(840, results.width - 56)
        spacing: 8

        // Header: result count + shortcut cues
        RowLayout {
            Layout.fillWidth: true
            Layout.bottomMargin: 6
            spacing: 8

            Text {
                text: {
                    var n = results.shell ? results.shell.results.length : 0
                    return n === 1 ? "1 result" : n + " results"
                }
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeHeading
                font.weight: Font.DemiBold
                font.letterSpacing: -0.2
            }

            Item { Layout.fillWidth: true }

            Text {
                text: "↑↓ to move · enter to open · esc to clear"
                color: Theme.textDim
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
            }
        }

        // Search Result Items
        Repeater {
            model: results.shell ? results.shell.results : []

            delegate: Rectangle {
                id: hit
                required property var modelData
                required property int index
                readonly property bool sel: results.shell && index === results.shell.searchSel

                Layout.fillWidth: true
                implicitHeight: 62
                radius: Theme.radiusSm
                color: hit.sel ? Theme.accentDim : (hitHh.hovered ? Theme.surfaceHover : Theme.surface)
                border.width: 1
                border.color: hit.sel ? Theme.withAlpha(Theme.accent, 0.55) : Theme.border
                Behavior on color { ColorAnimation { duration: Anim.d(Anim.fast) } }
                Behavior on border.color { ColorAnimation { duration: Anim.d(Anim.fast) } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 16
                    spacing: 14

                    BrandIcon {
                        brand: hit.modelData.brand || hit.modelData.key
                        size: 32
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 3

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Text {
                                text: hit.modelData.title
                                color: hit.sel ? Theme.accent : Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeBody
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                                Behavior on color { ColorAnimation { duration: Anim.d(Anim.fast) } }
                            }

                            // Breadcrumb path chip
                            Rectangle {
                                implicitHeight: 20
                                implicitWidth: breadcrumbText.implicitWidth + 12
                                radius: 4
                                color: hit.sel ? Theme.withAlpha(Theme.accent, 0.18) : Theme.withAlpha(Theme.bg, 0.6)
                                border.width: 1
                                border.color: hit.sel ? Theme.withAlpha(Theme.accent, 0.35) : Theme.withAlpha(Theme.borderStrong, 0.4)
                                Behavior on color { ColorAnimation { duration: Anim.d(Anim.fast) } }

                                Text {
                                    id: breadcrumbText
                                    anchors.centerIn: parent
                                    text: hit.modelData.cat + " › " + (hit.modelData.card || hit.modelData.key)
                                    color: hit.sel ? Theme.accent : Theme.textDim
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeSmall - 1
                                    font.weight: Font.Medium
                                }
                            }

                            Item { Layout.fillWidth: true }
                        }

                        Text {
                            text: hit.modelData.desc
                            color: Theme.textSecondary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }

                    // Return / Jump Arrow Indicator on keyboard selection or hover
                    MaterialIcon {
                        visible: hit.sel || hitHh.hovered
                        iconName: "arrow_forward"
                        pixelSize: 18
                        color: hit.sel ? Theme.accent : Theme.textDim
                        Layout.alignment: Qt.AlignVCenter
                        Behavior on color { ColorAnimation { duration: Anim.d(Anim.fast) } }
                    }
                }

                HoverHandler { id: hitHh; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: if (results.shell) results.shell.activateResult(hit.index) }
            }
        }

        // Empty Search State
        ColumnLayout {
            visible: results.shell && results.shell.results.length === 0
            Layout.topMargin: 32
            Layout.alignment: Qt.AlignHCenter
            spacing: 16

            MaterialIcon {
                Layout.alignment: Qt.AlignHCenter
                iconName: "travel_explore"
                pixelSize: 44
                color: Theme.textDim
            }

            ColumnLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 4

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "Nothing matches “" + (results.shell ? results.shell.query : "") + "”"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeHeading
                    font.weight: Font.DemiBold
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "Search across hardware, themes, security policies, workspace tools, or try a suggested query:"
                    color: Theme.textSecondary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeBody
                }
            }

            // Suggested Query Chips
            Flow {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: Math.min(600, results.width - 60)
                spacing: 8

                Repeater {
                    model: [
                        { label: "Displays", query: "display" },
                        { label: "Dark & Light Mode", query: "dark" },
                        { label: "Mullvad VPN", query: "vpn" },
                        { label: "NixOS Rebuild", query: "rebuild" },
                        { label: "Storage Cleaner", query: "storage" },
                        { label: "AI Assistants", query: "ai" },
                        { label: "Encrypted Vault", query: "vault" },
                        { label: "Dynamic Island", query: "island" },
                        { label: "Shortcuts", query: "shortcuts" },
                        { label: "Do Not Disturb", query: "dnd" }
                    ]

                    delegate: Rectangle {
                        required property var modelData
                        implicitHeight: 30
                        implicitWidth: chipLabel.implicitWidth + 24
                        radius: Theme.radiusSm
                        color: suggHh.hovered ? Theme.surfaceHover : Theme.surface
                        border.width: 1
                        border.color: suggHh.hovered ? Theme.accent : Theme.border
                        Behavior on color { ColorAnimation { duration: Anim.d(Anim.fast) } }
                        Behavior on border.color { ColorAnimation { duration: Anim.d(Anim.fast) } }

                        Text {
                            id: chipLabel
                            anchors.centerIn: parent
                            text: modelData.label
                            color: suggHh.hovered ? Theme.accent : Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Medium
                        }

                        HoverHandler { id: suggHh; cursorShape: Qt.PointingHandCursor }
                        TapHandler {
                            onTapped: if (results.shell) results.shell.setQuery(modelData.query)
                        }
                    }
                }
            }
        }
    }
}
