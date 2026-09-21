import QtQuick
import QtQuick.Layouts
import "../../theme"
import "../../components"
import "../../services"

// Progressive trust: which applications are quarantined, observed, graduated or
// revoked, and the controls that move them between those states. The filter and
// search are private to this view.
ColumnLayout {
    id: section

    property string filterState: "ALL"   // ALL | QUARANTINE | OBSERVING | GRADUATED | REVOKED
    property string searchQuery: ""

    spacing: 14


    MujoCard {
        title: "Progressive Trust & Isolation Engine"
        badgeText: SecurityService.totalAppsCount + " APPS"

        actions: DialogButton {
            text: "Evaluate now"
            onClicked: SecurityService.evaluateTrust()
        }

        Text {
            Layout.fillWidth: true
            Layout.bottomMargin: 4
            text: "A new or updated application runs isolated in a MicroVM until it has gone 72 hours without a boundary violation. Low and medium risk applications then graduate to native seccomp and systemd sandboxing."
            color: Theme.textSecondary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            lineHeight: 1.25
            wrapMode: Text.WordWrap
        }

        // Four counts, one shape — and the same shape the Security page uses
        // for them, since they are the same four numbers.
        RowLayout {
            id: tiers
            Layout.fillWidth: true
            spacing: 8

            readonly property var model: [
                { n: SecurityService.quarantinedAppsCount, label: "Quarantine", sub: "MicroVM domain",  tone: Theme.warning, state: "QUARANTINE" },
                { n: SecurityService.observingAppsCount,   label: "Observing",  sub: "Pre-graduation", tone: Theme.accent,  state: "OBSERVING"  },
                { n: SecurityService.graduatedAppsCount,   label: "Graduated",  sub: "Native sandbox", tone: Theme.success, state: "GRADUATED"  },
                { n: SecurityService.revokedAppsCount,     label: "Revoked",    sub: "Launch denied",  tone: Theme.error,   state: "REVOKED"    }
            ]

            Repeater {
                model: tiers.model

                delegate: InsetPanel {
                    required property var modelData
                    readonly property bool picked: section.filterState === modelData.state

                    Layout.fillWidth: true
                    implicitHeight: 52
                    color: picked ? Theme.surfaceHover : (tileHh.hovered ? Theme.surfaceHover : Theme.bg)
                    accentBorder: picked || tileHh.hovered ? modelData.tone : Theme.border
                    Behavior on color { ColorAnimation { duration: Anim.d(Anim.fast) } }

                    // The counts were decoration; now they filter the list
                    // below, which is what you wanted them for.
                    HoverHandler { id: tileHh; cursorShape: Qt.PointingHandCursor }
                    TapHandler {
                        onTapped: section.filterState = picked ? "ALL" : modelData.state
                    }

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 9

                        Text {
                            text: String(modelData.n)
                            color: modelData.tone
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSizeHeading + 2
                            font.weight: Font.DemiBold
                        }

                        ColumnLayout {
                            spacing: 1

                            Text {
                                text: modelData.label
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSmall
                            }

                            Text {
                                text: modelData.sub
                                color: Theme.textDim
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeLabel
                            }
                        }
                    }
                }
            }
        }

        InfoRow {
            label: "Launcher integration"
            mono: false
            iconName: SecurityService.launcherIntegrationActive ? "check_circle" : "cancel"
            iconColor: SecurityService.launcherIntegrationActive ? Theme.success : Theme.textDim
            value: SecurityService.launcherIntegrationActive
                ? "Applications start through mujo-trust"
                : "The menu starts applications directly"
        }
    }

    MujoCard {
        title: "Application Trust Registry"

        actions: RowLayout {
            spacing: 6

            Rectangle {
                implicitWidth: 220
                implicitHeight: 30
                radius: Theme.radiusSm
                color: Theme.bg
                border.width: 1
                border.color: trustSearchInput.activeFocus ? Theme.borderInteractive : Theme.border
                Behavior on border.color { ColorAnimation { duration: Anim.d(Anim.fast) } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 9
                    anchors.rightMargin: 9
                    spacing: 7

                    MaterialIcon { iconName: "search"; pixelSize: 15; color: Theme.textDim }

                    TextInput {
                        id: trustSearchInput
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
                            visible: trustSearchInput.text === ""
                            text: "Search by name or path"
                            color: Theme.textDim
                            font: trustSearchInput.font
                        }
                    }
                }
            }

            DialogButton {
                visible: section.filterState !== "ALL" || section.searchQuery !== ""
                text: "Clear filter"
                onClicked: {
                    section.filterState = "ALL"
                    trustSearchInput.text = ""
                }
            }
        }

        ColumnLayout {
            id: trustAppCol
            Layout.fillWidth: true
            spacing: 6

            readonly property var filteredTrustApps: SecurityService.trustApps.filter(function (a) {
                if (section.filterState !== "ALL" && a.state !== section.filterState) return false
                if (section.searchQuery !== "") {
                    var matchName = a.name && a.name.toLowerCase().indexOf(section.searchQuery) >= 0
                    var matchPath = a.storePath && a.storePath.toLowerCase().indexOf(section.searchQuery) >= 0
                    return matchName || matchPath
                }
                return true
            })

            EmptyState {
                Layout.fillWidth: true
                Layout.topMargin: 20
                Layout.bottomMargin: 20
                visible: trustAppCol.filteredTrustApps.length === 0
                iconName: SecurityService.trustApps.length === 0 ? "policy" : "search_off"
                title: SecurityService.trustApps.length === 0
                    ? "Nothing registered yet"
                    : "Nothing matches this filter"
                hint: SecurityService.trustApps.length === 0
                    ? "Start an application with mujo-trust run, or register one with sudo mujo-trust register."
                    : "Try a different tier, or clear the search."
            }

            Repeater {
                model: trustAppCol.filteredTrustApps

                delegate: ListRow {
                    required property var modelData
                    readonly property string st: modelData.state || "QUARANTINE"
                    readonly property color stateColor: st === "GRADUATED" ? Theme.success
                                                      : (st === "OBSERVING" ? Theme.accent
                                                      : (st === "REVOKED" ? Theme.error : Theme.warning))
                    readonly property int observed: Math.min(72, modelData.observedHours || 0)

                    implicitHeight: 62

                    MaterialIcon {
                        iconName: st === "GRADUATED" ? "verified"
                                : (st === "OBSERVING" ? "visibility"
                                : (st === "REVOKED" ? "gpp_bad" : "hourglass_top"))
                        pixelSize: 20
                        color: stateColor
                        Layout.alignment: Qt.AlignVCenter
                        Layout.rightMargin: 2
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 3

                        RowLayout {
                            spacing: 7

                            Text {
                                text: modelData.name || modelData.id
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeBody
                                font.weight: Font.DemiBold
                            }

                            StatusTag { text: st; toneColor: stateColor }
                            StatusTag { text: (modelData.tier || "medium").toUpperCase() }
                            StatusTag {
                                visible: (modelData.violations || 0) > 0
                                text: modelData.violations + (modelData.violations > 1 ? " VIOLATIONS" : " VIOLATION")
                                tone: "error"
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            Text {
                                text: modelData.storePath || "No store path"
                                color: Theme.textSecondary
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fontSizeLabel
                                elide: Text.ElideMiddle
                                Layout.fillWidth: true
                            }

                            // How far through the 72-hour watch it is.
                            Rectangle {
                                visible: st === "QUARANTINE" || st === "OBSERVING"
                                implicitWidth: 90
                                implicitHeight: 4
                                radius: 2
                                color: Theme.surfaceActive
                                Layout.alignment: Qt.AlignVCenter

                                Rectangle {
                                    anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                                    width: Math.max(3, parent.width * (observed / 72.0))
                                    radius: 2
                                    color: stateColor
                                }
                            }

                            Text {
                                visible: st === "QUARANTINE" || st === "OBSERVING"
                                text: observed + "h of 72h"
                                color: Theme.textDim
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fontSizeLabel
                                Layout.alignment: Qt.AlignVCenter
                            }
                        }
                    }

                    DialogButton {
                        visible: st === "REVOKED" && modelData.previousStorePath
                        text: "Roll back"
                        onClicked: SecurityService.rollbackApp(modelData.id)
                    }

                    DialogButton {
                        visible: st === "QUARANTINE" || st === "OBSERVING"
                        text: "Graduate"
                        onClicked: SecurityService.graduateApp(modelData.id)
                    }

                    DialogButton {
                        visible: st === "GRADUATED"
                        text: "Quarantine"
                        onClicked: SecurityService.quarantineApp(modelData.id)
                    }

                    DialogButton {
                        text: "Launch"
                        primary: true
                        onClicked: Launch.run(["mujo-run", modelData.id], modelData.name, "shield")
                    }
                }
            }
        }
    }
}
