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


    // Trust Engine Summary Card
    MujoCard {
        title: "Progressive Trust & Isolation Engine"
        iconName: "shield"
        badgeText: (SecurityService.totalAppsCount) + " APPS"
        badgeColor: Theme.accent

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 12

            Text {
                Layout.fillWidth: true
                text: "New and updated applications initially run isolated in a temporary MicroVM quarantine domain. Following 72 hours of clean observation without boundary violations, low and medium risk applications graduate to native seccomp/systemd sandboxing."
                color: Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                wrapMode: Text.Wrap
            }

            // Statistics Pills Row
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 46
                    radius: Theme.radiusMd
                    color: Theme.bg
                    border.color: Theme.border
                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 8
                        Text { text: SecurityService.quarantinedAppsCount.toString(); color: Theme.warning; font.bold: true; font.pixelSize: Theme.fontSizeHeading }
                        ColumnLayout {
                            spacing: 0
                            Text { text: "Quarantine"; color: Theme.text; font.pixelSize: Theme.fontSizeSmall; font.bold: true }
                            Text { text: "MicroVM Domain"; color: Theme.textDim; font.pixelSize: Theme.fontSizeLabel - 1 }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 46
                    radius: Theme.radiusMd
                    color: Theme.bg
                    border.color: Theme.border
                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 8
                        Text { text: SecurityService.observingAppsCount.toString(); color: Theme.accent; font.bold: true; font.pixelSize: Theme.fontSizeHeading }
                        ColumnLayout {
                            spacing: 0
                            Text { text: "Observing"; color: Theme.text; font.pixelSize: Theme.fontSizeSmall; font.bold: true }
                            Text { text: "Pre-Graduation"; color: Theme.textDim; font.pixelSize: Theme.fontSizeLabel - 1 }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 46
                    radius: Theme.radiusMd
                    color: Theme.bg
                    border.color: Theme.border
                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 8
                        Text { text: SecurityService.graduatedAppsCount.toString(); color: Theme.success; font.bold: true; font.pixelSize: Theme.fontSizeHeading }
                        ColumnLayout {
                            spacing: 0
                            Text { text: "Graduated"; color: Theme.text; font.pixelSize: Theme.fontSizeSmall; font.bold: true }
                            Text { text: "Native Sandbox"; color: Theme.textDim; font.pixelSize: Theme.fontSizeLabel - 1 }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 46
                    radius: Theme.radiusMd
                    color: Theme.bg
                    border.color: Theme.border
                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 8
                        Text { text: SecurityService.revokedAppsCount.toString(); color: Theme.error; font.bold: true; font.pixelSize: Theme.fontSizeHeading }
                        ColumnLayout {
                            spacing: 0
                            Text { text: "Revoked"; color: Theme.text; font.pixelSize: Theme.fontSizeSmall; font.bold: true }
                            Text { text: "Launch Denied"; color: Theme.textDim; font.pixelSize: Theme.fontSizeLabel - 1 }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    Layout.fillWidth: true
                    text: "Launcher Integration: " + (SecurityService.launcherIntegrationActive ? "Enabled (apps route through mujo-trust run)" : "Disabled (menu launches directly)")
                    color: Theme.textDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                }

                DialogButton {
                    text: "Evaluate Policy Now"
                    onClicked: SecurityService.evaluateTrust()
                }
            }
        }
    }

    // Filter & Search bar
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
                id: trustSearchInput
                Layout.fillWidth: true
                verticalAlignment: Text.AlignVCenter
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeBody
                onTextChanged: section.searchQuery = text.trim().toLowerCase()
                Text {
                    visible: trustSearchInput.text === ""
                    text: "Search registered applications by name or store path…"
                    color: Theme.textDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeBody
                }
            }

            RowLayout {
                spacing: 4
                Repeater {
                    model: ["ALL", "QUARANTINE", "OBSERVING", "GRADUATED", "REVOKED"]
                    delegate: Rectangle {
                        required property var modelData
                        readonly property bool active: section.filterState === modelData
                        implicitWidth: fText.implicitWidth + 12
                        implicitHeight: 26
                        radius: Theme.radiusSm
                        color: active ? Theme.surfaceActive : (f_hh.hovered ? Theme.surfaceHover : "transparent")
                        border.color: active ? Theme.borderStrong : "transparent"

                        Text {
                            id: fText
                            anchors.centerIn: parent
                            text: modelData
                            color: active ? Theme.text : Theme.textDim
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeLabel - 1
                            font.bold: active
                        }

                        HoverHandler { id: f_hh; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: section.filterState = modelData }
                    }
                }
            }
        }
    }

    // Applications Trust List Card
    MujoCard {
        title: "Application Trust Registry"
        iconName: "policy"

        ColumnLayout {
            id: trustAppCol
            Layout.fillWidth: true
            spacing: 8

            readonly property var filteredTrustApps: SecurityService.trustApps.filter(function(a) {
                if (section.filterState !== "ALL" && a.state !== section.filterState) return false
                if (section.searchQuery !== "") {
                    var matchName = a.name && a.name.toLowerCase().indexOf(section.searchQuery) >= 0
                    var matchPath = a.storePath && a.storePath.toLowerCase().indexOf(section.searchQuery) >= 0
                    return matchName || matchPath
                }
                return true
            })

            Text {
                visible: trustAppCol.filteredTrustApps.length === 0
                text: SecurityService.trustApps.length === 0
                    ? "No applications registered yet in /var/lib/mujo-trust/registry.json. Run an app via 'mujo-trust run <app>' or register via 'sudo mujo-trust register <app>'."
                    : "No applications matching the selected filter."
                color: Theme.textDim
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
            }

            Repeater {
                model: trustAppCol.filteredTrustApps
                delegate: Rectangle {
                    required property var modelData
                    readonly property string st: modelData.state || "QUARANTINE"
                    readonly property color stateColor: st === "GRADUATED" ? Theme.success : (st === "OBSERVING" ? Theme.accent : (st === "REVOKED" ? Theme.error : Theme.warning))
                    readonly property color stateDimColor: st === "GRADUATED" ? Theme.successDim : (st === "OBSERVING" ? Theme.accentDim : (st === "REVOKED" ? Theme.errorDim : Theme.warningDim))

                    Layout.fillWidth: true
                    implicitHeight: 70
                    radius: Theme.radiusMd
                    color: tr_hh.hovered ? Theme.surfaceHover : "transparent"
                    border.color: tr_hh.hovered ? Theme.borderStrong : "transparent"
                    Behavior on color { ColorAnimation { duration: Anim.d(Anim.fast) } }

                    HoverHandler { id: tr_hh }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 12

                        Rectangle {
                            Layout.preferredWidth: 36
                            Layout.preferredHeight: 36
                            Layout.alignment: Qt.AlignVCenter
                            radius: Theme.radiusSm
                            color: stateDimColor
                            MaterialIcon {
                                anchors.centerIn: parent
                                iconName: st === "GRADUATED" ? "verified" : (st === "OBSERVING" ? "visibility" : (st === "REVOKED" ? "gpp_bad" : "hourglass_top"))
                                pixelSize: 18
                                color: stateColor
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Layout.alignment: Qt.AlignVCenter

                            RowLayout {
                                spacing: 8
                                Text {
                                    text: modelData.name || modelData.id
                                    color: Theme.text
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeBody
                                    font.bold: true
                                }

                                // State Badge
                                Rectangle {
                                    implicitWidth: stText.implicitWidth + 10; implicitHeight: 18
                                    radius: Theme.radiusSm
                                    color: stateDimColor
                                    border.color: stateColor
                                    Text {
                                        id: stText
                                        anchors.centerIn: parent
                                        text: st
                                        color: stateColor
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeLabel - 1
                                        font.bold: true
                                    }
                                }

                                // Risk Tier Chip
                                Rectangle {
                                    implicitWidth: tierText.implicitWidth + 8; implicitHeight: 16
                                    radius: Theme.radiusSm
                                    color: Theme.surface
                                    border.color: Theme.border
                                    Text {
                                        id: tierText
                                        anchors.centerIn: parent
                                        text: (modelData.tier || "medium").toUpperCase()
                                        color: Theme.textDim
                                        font.family: Theme.fontMono
                                        font.pixelSize: Theme.fontSizeLabel - 1
                                    }
                                }

                                // Violations badge if > 0
                                Rectangle {
                                    visible: (modelData.violations || 0) > 0
                                    implicitWidth: violText.implicitWidth + 8; implicitHeight: 16
                                    radius: Theme.radiusSm
                                    color: Theme.errorDim
                                    border.color: Theme.error
                                    Text {
                                        id: violText
                                        anchors.centerIn: parent
                                        text: modelData.violations + " VIOLATION" + (modelData.violations > 1 ? "S" : "")
                                        color: Theme.error
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeLabel - 1
                                        font.bold: true
                                    }
                                }
                            }

                            // Store path
                            Text {
                                text: modelData.storePath || "No store path"
                                color: Theme.textSecondary
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fontSizeSmall - 1
                                elide: Text.ElideMiddle
                                Layout.fillWidth: true
                            }

                            // Progress Bar Row (Observation progress towards 72 hours)
                            RowLayout {
                                spacing: 8
                                visible: st === "QUARANTINE" || st === "OBSERVING"

                                Rectangle {
                                    implicitWidth: 120; implicitHeight: 5
                                    radius: 2.5
                                    color: Theme.surfaceActive

                                    Rectangle {
                                        anchors.left: parent.left
                                        anchors.top: parent.top
                                        anchors.bottom: parent.bottom
                                        width: Math.min(parent.width, Math.max(4, parent.width * (Math.min(72, (modelData.observedHours || 0)) / 72.0)))
                                        radius: 2.5
                                        color: stateColor
                                    }
                                }

                                Text {
                                    text: (modelData.observedHours || 0) + "h / 72h observation"
                                    color: Theme.textDim
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeLabel - 1
                                }
                            }
                        }

                        // Context actions
                        RowLayout {
                            spacing: 6
                            Layout.alignment: Qt.AlignVCenter

                            // Rollback button for revoked
                            DialogButton {
                                visible: st === "REVOKED" && modelData.previousStorePath
                                text: "Rollback"
                                onClicked: SecurityService.rollbackApp(modelData.id)
                            }

                            // Graduate action
                            DialogButton {
                                visible: st === "QUARANTINE" || st === "OBSERVING"
                                text: "Graduate"
                                onClicked: SecurityService.graduateApp(modelData.id)
                            }

                            // Force Quarantine action
                            DialogButton {
                                visible: st === "GRADUATED"
                                text: "Quarantine"
                                onClicked: SecurityService.quarantineApp(modelData.id)
                            }

                            // Launch button
                            DialogButton {
                                text: "Launch"
                                onClicked: Launch.run(["mujo-run", modelData.id], modelData.name, "shield")
                            }
                        }
                    }
                }
            }
        }
    }
}
