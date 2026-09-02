import QtQuick
import QtQuick.Layouts
import "../../theme"
import "../../components"
import "../../services"

// Mujo 2.0 Security Architecture Center:
// Visualizes Verified Boot, LUKS2 Storage Vault, Memory & Host Hardening, and Progressive Trust.
ColumnLayout {
    id: root
    Layout.fillWidth: true
    spacing: 14

    // ── 1. Verified Boot & Kernel Integrity ──────────────────────────────────
    MujoCard {
        title: "Verified Boot & System Integrity"
        iconName: "verified_user"
        badgeText: SecurityService.secureBootActive ? "SECURE" : "SETUP MODE"
        badgeColor: SecurityService.secureBootActive ? Theme.success : Theme.warning

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 10

            // Secure Boot Row
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 52
                radius: Theme.radiusMd
                color: Theme.bg
                border.color: Theme.border

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 12

                    Rectangle {
                        width: 32; height: 32; radius: Theme.radiusSm
                        color: SecurityService.secureBootActive ? Theme.successDim : Theme.warningDim
                        MaterialIcon {
                            anchors.centerIn: parent
                            iconName: SecurityService.secureBootActive ? "verified" : "gpp_maybe"
                            pixelSize: 18
                            color: SecurityService.secureBootActive ? Theme.success : Theme.warning
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text {
                            text: "UEFI Secure Boot"
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeBody
                            font.bold: true
                        }
                        Text {
                            text: SecurityService.secureBootActive ? "Lanzaboote custom signing keys active and enforcing" : "Firmware setup mode (lanzaboote ready for enrollment)"
                            color: Theme.textSecondary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                        }
                    }

                    DisplayChip {
                        label: SecurityService.secureBootActive ? "ENFORCED" : "SETUP MODE"
                        selected: SecurityService.secureBootActive
                    }
                }
            }

            // TPM 2.0 Row
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 52
                radius: Theme.radiusMd
                color: Theme.bg
                border.color: Theme.border

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 12

                    Rectangle {
                        width: 32; height: 32; radius: Theme.radiusSm
                        color: SecurityService.tpmActive ? Theme.accentDim : Theme.surface
                        MaterialIcon {
                            anchors.centerIn: parent
                            iconName: "memory"
                            pixelSize: 18
                            color: SecurityService.tpmActive ? Theme.accent : Theme.textDim
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text {
                            text: "TPM 2.0 Cryptographic Processor"
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeBody
                            font.bold: true
                        }
                        Text {
                            text: SecurityService.tpmActive ? "Hardware TPM device (/dev/tpmrm0) active for boot measurements" : "TPM module not detected or unmeasured"
                            color: Theme.textSecondary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                        }
                    }

                    DisplayChip {
                        label: SecurityService.tpmActive ? "ACTIVE" : "ABSENT"
                        selected: SecurityService.tpmActive
                    }
                }
            }

            // Kernel Lockdown Row
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 52
                radius: Theme.radiusMd
                color: Theme.bg
                border.color: Theme.border

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 12

                    Rectangle {
                        width: 32; height: 32; radius: Theme.radiusSm
                        color: SecurityService.lockdownMode !== "none" ? Theme.successDim : Theme.surface
                        MaterialIcon {
                            anchors.centerIn: parent
                            iconName: "shield"
                            pixelSize: 18
                            color: SecurityService.lockdownMode !== "none" ? Theme.success : Theme.textDim
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text {
                            text: "Kernel Lockdown & BPF Security"
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeBody
                            font.bold: true
                        }
                        Text {
                            text: "Restricts raw I/O, unsigned module loading, and unprivileged BPF access"
                            color: Theme.textSecondary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                        }
                    }

                    DisplayChip {
                        label: SecurityService.lockdownMode.toUpperCase()
                        selected: SecurityService.lockdownMode !== "none"
                    }
                }
            }
        }
    }

    // ── 2. LUKS2 Encrypted Storage Vault ─────────────────────────────────────
    MujoCard {
        title: "LUKS2 Encrypted Storage Vault"
        iconName: "lock"
        badgeText: SecurityService.vaultMounted ? "UNLOCKED" : (SecurityService.vaultContainerPresent ? "LOCKED" : "NOT CREATED")
        badgeColor: SecurityService.vaultMounted ? Theme.accent : (SecurityService.vaultContainerPresent ? Theme.warning : Theme.textDim)

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 10

            // Vault Status & Unlock/Lock Action
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 52
                radius: Theme.radiusMd
                color: Theme.bg
                border.color: Theme.border

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 12

                    Rectangle {
                        width: 32; height: 32; radius: Theme.radiusSm
                        color: SecurityService.vaultMounted ? Theme.accentDim : Theme.surface
                        MaterialIcon {
                            anchors.centerIn: parent
                            iconName: SecurityService.vaultMounted ? "lock_open" : "lock"
                            pixelSize: 18
                            color: SecurityService.vaultMounted ? Theme.accent : Theme.textDim
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text {
                            text: SecurityService.vaultMounted ? "Storage Vault Unlocked & Mounted" : "Storage Vault Locked"
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeBody
                            font.bold: true
                        }
                        Text {
                            text: SecurityService.vaultMounted
                                ? "Mounted at " + SecurityService.vaultMountPoint + " with 0700 permissions"
                                : (SecurityService.vaultContainerPresent
                                    ? "Container: /persist/secure/mujo-vault.luks (" + (SecurityService.vaultContainerSize || "Present") + ")"
                                    : "Initialize with: sudo mujo-vault init 10G")
                            color: Theme.textSecondary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                        }
                    }

                    DialogButton {
                        text: SecurityService.vaultMounted ? "Lock Vault" : "Unlock"
                        primary: !SecurityService.vaultMounted
                        enabled: SecurityService.vaultMounted || SecurityService.vaultContainerPresent
                        onClicked: SecurityService.vaultMounted ? SecurityService.closeVault() : SecurityService.openVault()
                    }
                }
            }

            // Subdirectories Overview (When Mounted)
            ColumnLayout {
                visible: SecurityService.vaultMounted && SecurityService.vaultSubdirectories.length > 0
                Layout.fillWidth: true
                spacing: 6

                Text {
                    text: "Encrypted Domains Available:"
                    color: Theme.textSecondary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                }

                Flow {
                    Layout.fillWidth: true
                    spacing: 6

                    Repeater {
                        model: SecurityService.vaultSubdirectories
                        delegate: Rectangle {
                            required property var modelData
                            implicitWidth: sd_row.implicitWidth + 16; implicitHeight: 24
                            radius: Theme.radiusSm
                            color: Theme.surface
                            border.color: Theme.border

                            RowLayout {
                                id: sd_row
                                anchors.centerIn: parent
                                spacing: 4
                                MaterialIcon { iconName: "folder"; pixelSize: 13; color: Theme.accent }
                                Text {
                                    text: modelData
                                    color: Theme.text
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.fontSizeLabel - 1
                                }
                            }
                        }
                    }
                }
            }

            // Sensitive Data Inventory Audit Row
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 52
                radius: Theme.radiusMd
                color: Theme.bg
                border.color: Theme.border

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 12

                    Rectangle {
                        width: 32; height: 32; radius: Theme.radiusSm
                        color: SecurityService.inventoryAudited
                            ? (SecurityService.inventoryClean ? Theme.successDim : Theme.errorDim)
                            : Theme.surface
                        MaterialIcon {
                            anchors.centerIn: parent
                            iconName: "find_in_page"
                            pixelSize: 18
                            color: SecurityService.inventoryAudited
                                ? (SecurityService.inventoryClean ? Theme.success : Theme.error)
                                : Theme.textDim
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text {
                            text: "Sensitive Plaintext Storage Audit"
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeBody
                            font.bold: true
                        }
                        Text {
                            text: SecurityService.inventoryAudited
                                ? (SecurityService.inventoryClean
                                    ? "Clean: No unencrypted keys or tokens found on persistent storage"
                                    : SecurityService.inventoryFindingsCount + " plaintext item(s) found outside the vault")
                                : "Audits /persist for unencrypted private keys, tokens, and credentials"
                            color: Theme.textSecondary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                        }
                    }

                    DialogButton {
                        text: SecurityService.inventoryAudited ? "Re-scan" : "Run Audit Scan"
                        onClicked: SecurityService.auditInventory()
                    }
                }
            }
        }
    }

    // ── 3. Host Hardening & Memory Leak Prevention ───────────────────────────
    MujoCard {
        title: "Host Hardening & Memory Isolation"
        iconName: "memory"
        badgeText: "ACTIVE"
        badgeColor: Theme.success

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 10

            // Encrypted Swap
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 52
                radius: Theme.radiusMd
                color: Theme.bg
                border.color: Theme.border

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 12

                    Rectangle {
                        width: 32; height: 32; radius: Theme.radiusSm
                        color: Theme.successDim
                        MaterialIcon { anchors.centerIn: parent; iconName: "key"; pixelSize: 18; color: Theme.success }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text { text: "Per-Boot Encrypted Swap"; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeBody; font.bold: true }
                        Text { text: "Re-keyed on every boot with a random key; persistent hibernation disabled"; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSmall }
                    }
                    DisplayChip { label: "ENCRYPTED"; selected: true }
                }
            }

            // Zero Core Dumps
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 52
                radius: Theme.radiusMd
                color: Theme.bg
                border.color: Theme.border

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 12

                    Rectangle {
                        width: 32; height: 32; radius: Theme.radiusSm
                        color: Theme.successDim
                        MaterialIcon { anchors.centerIn: parent; iconName: "hide_source"; pixelSize: 18; color: Theme.success }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text { text: "Zero Core Dumps on Persistent Disk"; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeBody; font.bold: true }
                        Text { text: "RAM images never persist to disk; crashes stay bounded in journald"; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSmall }
                    }
                    DisplayChip { label: "DISABLED"; selected: true }
                }
            }

            // Ephemeral /tmp
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 52
                radius: Theme.radiusMd
                color: Theme.bg
                border.color: Theme.border

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 12

                    Rectangle {
                        width: 32; height: 32; radius: Theme.radiusSm
                        color: Theme.accentDim
                        MaterialIcon { anchors.centerIn: parent; iconName: "delete_sweep"; pixelSize: 18; color: Theme.accent }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text { text: "Ephemeral Scratch Directory (/tmp in RAM)"; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeBody; font.bold: true }
                        Text { text: "All scratch files reside in tmpfs and are discarded on reboot"; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSmall }
                    }
                    DisplayChip { label: "TMPFS"; selected: true }
                }
            }

            // Firewall
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 52
                radius: Theme.radiusMd
                color: Theme.bg
                border.color: Theme.border

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 12

                    Rectangle {
                        width: 32; height: 32; radius: Theme.radiusSm
                        color: Theme.successDim
                        MaterialIcon { anchors.centerIn: parent; iconName: "local_fire_department"; pixelSize: 18; color: Theme.success }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text { text: "NFTables Host Firewall"; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeBody; font.bold: true }
                        Text { text: "Default DROP for all inbound traffic; strictly managed interfaces"; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSmall }
                    }
                    DisplayChip { label: "ENFORCING"; selected: true }
                }
            }
        }
    }

    // ── 4. Application Progressive Trust Overview ────────────────────────────
    MujoCard {
        title: "Progressive Trust & Sandboxing Overview"
        iconName: "shield"
        badgeText: (SecurityService.totalAppsCount) + " APPS TRACKED"
        badgeColor: Theme.accent

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 44
                    radius: Theme.radiusSm
                    color: Theme.bg
                    border.color: Theme.border
                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 6
                        Text { text: SecurityService.quarantinedAppsCount.toString(); color: Theme.warning; font.bold: true; font.pixelSize: Theme.fontSizeHeading }
                        Text { text: "Quarantine"; color: Theme.textSecondary; font.pixelSize: Theme.fontSizeSmall }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 44
                    radius: Theme.radiusSm
                    color: Theme.bg
                    border.color: Theme.border
                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 6
                        Text { text: SecurityService.observingAppsCount.toString(); color: Theme.accent; font.bold: true; font.pixelSize: Theme.fontSizeHeading }
                        Text { text: "Observing"; color: Theme.textSecondary; font.pixelSize: Theme.fontSizeSmall }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 44
                    radius: Theme.radiusSm
                    color: Theme.bg
                    border.color: Theme.border
                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 6
                        Text { text: SecurityService.graduatedAppsCount.toString(); color: Theme.success; font.bold: true; font.pixelSize: Theme.fontSizeHeading }
                        Text { text: "Graduated"; color: Theme.textSecondary; font.pixelSize: Theme.fontSizeSmall }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 44
                    radius: Theme.radiusSm
                    color: Theme.bg
                    border.color: Theme.border
                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 6
                        Text { text: SecurityService.revokedAppsCount.toString(); color: Theme.error; font.bold: true; font.pixelSize: Theme.fontSizeHeading }
                        Text { text: "Revoked"; color: Theme.textSecondary; font.pixelSize: Theme.fontSizeSmall }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    Layout.fillWidth: true
                    text: "Manage individual application tiers and quarantine states under System → Applications."
                    color: Theme.textSecondary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                }

                DialogButton {
                    text: "Evaluate Policy"
                    onClicked: SecurityService.evaluateTrust()
                }
            }
        }
    }
}

