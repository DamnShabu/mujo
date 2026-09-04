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

        MujoSettingRow {
            iconName: SecurityService.secureBootActive ? "verified" : "gpp_maybe"
            title: "UEFI Secure Boot"
            description: SecurityService.secureBootActive
                ? "Lanzaboote custom signing keys active and enforcing"
                : "Firmware setup mode (lanzaboote ready for enrollment)"

            DisplayChip {
                label: SecurityService.secureBootActive ? "ENFORCED" : "SETUP MODE"
                selected: SecurityService.secureBootActive
            }
        }

        MujoSettingRow {
            iconName: "memory"
            title: "TPM 2.0 Cryptographic Processor"
            description: SecurityService.tpmActive
                ? "Hardware TPM device (/dev/tpmrm0) active for boot measurements"
                : "TPM module not detected or unmeasured"

            DisplayChip {
                label: SecurityService.tpmActive ? "ACTIVE" : "ABSENT"
                selected: SecurityService.tpmActive
            }
        }

        MujoSettingRow {
            iconName: "shield"
            title: "Kernel Lockdown & BPF Security"
            description: "Restricts raw I/O, unsigned module loading, and unprivileged BPF access"

            DisplayChip {
                label: SecurityService.lockdownMode.toUpperCase()
                selected: SecurityService.lockdownMode !== "none"
            }
        }
    }

    // ── 2. LUKS2 Encrypted Storage Vault ─────────────────────────────────────
    MujoCard {
        title: "LUKS2 Encrypted Storage Vault"
        iconName: "lock"
        badgeText: SecurityService.vaultMounted ? "UNLOCKED" : (SecurityService.vaultContainerPresent ? "LOCKED" : "NOT CREATED")
        badgeColor: SecurityService.vaultMounted ? Theme.accent : (SecurityService.vaultContainerPresent ? Theme.warning : Theme.textDim)

        MujoSettingRow {
            iconName: SecurityService.vaultMounted ? "lock_open" : "lock"
            title: SecurityService.vaultMounted ? "Storage Vault Unlocked & Mounted" : "Storage Vault Locked"
            description: SecurityService.vaultMounted
                ? "Mounted at " + SecurityService.vaultMountPoint + " with 0700 permissions"
                : (SecurityService.vaultContainerPresent
                    ? "Container: /persist/secure/mujo-vault.luks (" + (SecurityService.vaultContainerSize || "Present") + ")"
                    : "Initialize with: sudo mujo-vault init 10G")

            DialogButton {
                text: SecurityService.vaultMounted ? "Lock Vault" : "Unlock"
                primary: !SecurityService.vaultMounted
                enabled: SecurityService.vaultMounted || SecurityService.vaultContainerPresent
                onClicked: SecurityService.vaultMounted ? SecurityService.closeVault() : SecurityService.openVault()
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
                        implicitWidth: sd_row.implicitWidth + 16
                        implicitHeight: 24
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

        MujoSettingRow {
            iconName: SecurityService.inventoryFailed ? "help" : "find_in_page"
            title: "Sensitive Plaintext Storage Audit"
            description: !SecurityService.inventoryAudited
                ? "Audits /persist for unencrypted private keys, tokens, and credentials"
                : SecurityService.inventoryFailed
                    ? "Scan did not complete — nothing was verified. Re-run it."
                    : (SecurityService.inventoryClean
                        ? "Clean: No unencrypted keys or tokens found on persistent storage"
                        : SecurityService.inventoryFindingsCount + " plaintext item(s) found outside the vault")

            DialogButton {
                text: SecurityService.inventoryAudited ? "Re-scan" : "Run Audit Scan"
                onClicked: SecurityService.auditInventory()
            }
        }
    }

    // ── 3. Host Hardening & Memory Isolation ───────────────────────────
    MujoCard {
        title: "Host Hardening & Memory Isolation"
        iconName: "memory"
        badgeText: "ACTIVE"
        badgeColor: Theme.success

        MujoSettingRow {
            iconName: SecurityService.encryptedSwapActive ? "key" : "key_off"
            title: "Per-Boot Encrypted Swap"
            description: SecurityService.encryptedSwapActive
                ? "Re-keyed on every boot with a random key; persistent hibernation disabled"
                : "Swap is not reporting as encrypted — pages may reach the disk in the clear"

            DisplayChip {
                label: SecurityService.encryptedSwapActive ? "ENCRYPTED" : "UNVERIFIED"
                selected: SecurityService.encryptedSwapActive
            }
        }

        MujoSettingRow {
            iconName: "hide_source"
            title: "Zero Core Dumps on Persistent Disk"
            description: SecurityService.coredumpDisabled
                ? "RAM images never persist to disk; crashes stay bounded in journald"
                : "Core dumps are not reporting as disabled — process memory can reach the disk"

            DisplayChip {
                label: SecurityService.coredumpDisabled ? "DISABLED" : "UNVERIFIED"
                selected: SecurityService.coredumpDisabled
            }
        }

        MujoSettingRow {
            iconName: "delete_sweep"
            title: "Ephemeral Scratch Directory (/tmp in RAM)"
            description: SecurityService.tmpfsTmpActive
                ? "All scratch files reside in tmpfs and are discarded on reboot"
                : "/tmp is not reporting as tmpfs — scratch files may survive a reboot on disk"

            DisplayChip {
                label: SecurityService.tmpfsTmpActive ? "TMPFS" : "UNVERIFIED"
                selected: SecurityService.tmpfsTmpActive
            }
        }

        MujoSettingRow {
            iconName: "local_fire_department"
            title: "NFTables Host Firewall"
            description: SecurityService.firewallActive
                ? "Default DROP for all inbound traffic; strictly managed interfaces"
                : "Firewall is not reporting as active — inbound traffic may not be dropped"

            DisplayChip {
                label: SecurityService.firewallActive ? "ENFORCING" : "UNVERIFIED"
                selected: SecurityService.firewallActive
            }
        }
    }

    // ── 4. Application Progressive Trust Overview ────────────────────────────
    MujoCard {
        title: "Progressive Trust & Sandboxing Overview"
        iconName: "shield"
        badgeText: (SecurityService.totalAppsCount) + " APPS TRACKED"
        badgeColor: Theme.accent

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

        MujoSettingRow {
            iconName: "policy"
            title: "Application Security Policy"
            description: "Manage individual application tiers and quarantine states under System → Applications."

            DialogButton {
                text: "Evaluate Policy"
                onClicked: SecurityService.evaluateTrust()
            }
        }
    }
}

