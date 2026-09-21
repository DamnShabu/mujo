import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../theme"
import "../../components"
import "../../services"

// Mujo 2.0 Security Architecture & System Integrity Settings Center:
// Provides interactive management for Host Hardening, Core Dumps, Firewall,
// Memory Isolation, Verified Boot (Lanzaboote), LUKS2 Storage Vault, and Progressive Trust.
ColumnLayout {
    id: root
    Layout.fillWidth: true
    spacing: 14

    signal openTrustRequested()

    property var nixosPrefs: ({
        security: { coredumpDisabled: true, secureBoot: false, unprivilegedBpfDisabled: true },
        storage: { encryptedSwap: true, tmpfsTmp: true },
        firewall: { enable: true },
        trust: { launcherIntegration: false, flatpakNarrowing: true },
        vault: { autoLock: "30m" }
    })
    property bool nixosDirty: false

    function setNixosPref(path, val) {
        var p = JSON.parse(JSON.stringify(root.nixosPrefs))
        var parts = path.split(".")
        var o = p
        for (var i = 0; i < parts.length - 1; i++) {
            if (!o[parts[i]]) o[parts[i]] = {}
            o = o[parts[i]]
        }
        o[parts[parts.length - 1]] = val
        root.nixosPrefs = p
        root.nixosDirty = true
        Quickshell.execDetached(["mujo", "system-pref", "set", path, String(val)])
        SecurityService.refresh()
    }

    Process {
        id: loadPrefsProc
        command: ["mujo", "system-pref", "get"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var parsed = JSON.parse(this.text)
                    if (parsed && typeof parsed === "object") root.nixosPrefs = parsed
                } catch (e) {}
            }
        }
    }

    Component.onCompleted: {
        loadPrefsProc.running = true
        SecurityService.refresh()
    }

    // ── 1. Host Hardening & Memory Isolation ──────────────────────────────────
    MujoCard {
        title: "Host Hardening & Memory Isolation"
        iconName: "memory"
        isNixos: true
        badgeText: (SecurityService.coredumpDisabled && SecurityService.firewallActive && SecurityService.encryptedSwapActive) ? "HARDENED" : "CUSTOM"
        badgeColor: (SecurityService.coredumpDisabled && SecurityService.firewallActive && SecurityService.encryptedSwapActive) ? Theme.success : Theme.warning

        MujoSettingRow {
            iconName: "hide_source"
            title: "No core dumps on disk"
            description: (root.nixosPrefs.security ? root.nixosPrefs.security.coredumpDisabled !== false : SecurityService.coredumpDisabled)
                ? "RAM images never persist to disk; crashes stay bounded in journald"
                : "Core dumps enabled on disk (/var/lib/systemd/coredump) for crash analysis and debugging"

            ToggleSwitch {
                a11yName: "Zero Core Dumps on Persistent Disk"
                checked: root.nixosPrefs.security ? (root.nixosPrefs.security.coredumpDisabled !== false) : SecurityService.coredumpDisabled
                onToggled: function(c) {
                    root.setNixosPref("security.coredumpDisabled", c)
                    SecurityService.setCoredump(c)
                }
            }
        }

        MujoSettingRow {
            iconName: "local_fire_department"
            title: "Host firewall"
            description: (root.nixosPrefs.firewall ? root.nixosPrefs.firewall.enable !== false : SecurityService.firewallActive)
                ? "Default DROP for all inbound traffic; strictly managed interfaces"
                : "Firewall disabled; inbound traffic accepted without filtering"

            ToggleSwitch {
                a11yName: "NFTables Host Firewall"
                checked: root.nixosPrefs.firewall ? (root.nixosPrefs.firewall.enable !== false) : SecurityService.firewallActive
                onToggled: function(c) {
                    root.setNixosPref("firewall.enable", c)
                    SecurityService.setFirewall(c)
                }
            }
        }

        MujoSettingRow {
            iconName: "delete_sweep"
            title: "Scratch directory in RAM"
            description: (root.nixosPrefs.storage ? root.nixosPrefs.storage.tmpfsTmp !== false : SecurityService.tmpfsTmpActive)
                ? "All scratch files reside in tmpfs (RAM) and are discarded on reboot"
                : "Scratch files written to disk (/tmp persisted across reboots)"

            ToggleSwitch {
                a11yName: "Ephemeral Scratch Directory (/tmp in RAM)"
                checked: root.nixosPrefs.storage ? (root.nixosPrefs.storage.tmpfsTmp !== false) : SecurityService.tmpfsTmpActive
                onToggled: function(c) {
                    root.setNixosPref("storage.tmpfsTmp", c)
                    SecurityService.setTmpfsTmp(c)
                }
            }
        }

        MujoSettingRow {
            iconName: SecurityService.encryptedSwapActive ? "key" : "key_off"
            title: "Encrypted swap, re-keyed each boot"
            description: (root.nixosPrefs.storage ? root.nixosPrefs.storage.encryptedSwap !== false : SecurityService.encryptedSwapActive)
                ? "Re-keyed on every boot with a random key; persistent hibernation disabled"
                : "Static swap key; allows hibernation but swap contents persist across boots"

            ToggleSwitch {
                a11yName: "Per-Boot Encrypted Swap"
                checked: root.nixosPrefs.storage ? (root.nixosPrefs.storage.encryptedSwap !== false) : SecurityService.encryptedSwapActive
                onToggled: function(c) {
                    root.setNixosPref("storage.encryptedSwap", c)
                    SecurityService.setEncryptedSwap(c)
                }
            }
        }
    }

    // ── 2. Verified Boot & Kernel Integrity ──────────────────────────────────
    MujoCard {
        title: "Verified Boot & System Integrity"
        iconName: "verified_user"
        isNixos: true
        badgeText: SecurityService.secureBootActive ? "SECURE" : "SETUP MODE"
        badgeColor: SecurityService.secureBootActive ? Theme.success : Theme.warning

        MujoSettingRow {
            iconName: SecurityService.secureBootActive ? "verified" : "gpp_maybe"
            title: "UEFI Secure Boot"
            description: SecurityService.secureBootActive
                ? "Lanzaboote custom signing keys active and enforcing in UEFI firmware"
                : "Firmware setup mode or inactive (boots via GRUB); enable declarative Secure Boot and enroll keys"

            RowLayout {
                spacing: 8

                DialogButton {
                    visible: !SecurityService.secureBootActive
                    text: "Set up keys"
                    onClicked: Quickshell.execDetached(["kitty", "--title", "mujō — setup secureboot keys", "-e", "pkexec", "mujo-secureboot", "setup-keys"])
                }

                DialogButton {
                    visible: !SecurityService.secureBootActive
                    text: "Enroll"
                    onClicked: Quickshell.execDetached(["kitty", "--title", "mujō — enroll secureboot keys", "-e", "pkexec", "mujo-secureboot", "enroll"])
                }

                ToggleSwitch {
                    a11yName: "UEFI Secure Boot"
                    checked: root.nixosPrefs.security ? (root.nixosPrefs.security.secureBoot === true) : SecurityService.secureBootActive
                    onToggled: function(c) {
                        root.setNixosPref("security.secureBoot", c)
                        SecurityService.setSecureBoot(c)
                    }
                }
            }
        }

        MujoSettingRow {
            iconName: "memory"
            title: "TPM 2.0"
            description: SecurityService.tpmActive
                ? "Hardware TPM device (/dev/tpmrm0) active for boot measurements & secrets"
                : "TPM module not detected or unmeasured"

            RowLayout {
                spacing: 8

                DisplayChip {
                    label: SecurityService.tpmActive ? "ACTIVE" : "ABSENT"
                    selected: SecurityService.tpmActive
                }

                DialogButton {
                    text: "Verify PCRs"
                    onClicked: Quickshell.execDetached(["kitty", "--title", "mujō — TPM PCR measurements", "-e", "mujo-secureboot", "verify-tpm"])
                }
            }
        }

        MujoSettingRow {
            iconName: "shield"
            title: "Restrict unprivileged eBPF"
            description: "Disables unprivileged eBPF to prevent speculative execution and kernel memory inspection"

            ToggleSwitch {
                a11yName: "Unprivileged eBPF Restriction"
                checked: root.nixosPrefs.security ? (root.nixosPrefs.security.unprivilegedBpfDisabled !== false) : true
                onToggled: function(c) { root.setNixosPref("security.unprivilegedBpfDisabled", c) }
            }
        }
    }

    // ── 3. LUKS2 Encrypted Storage Vault ─────────────────────────────────────
    MujoCard {
        title: "LUKS2 Encrypted Storage Vault"
        iconName: "lock"
        badgeText: SecurityService.vaultMounted ? "UNLOCKED" : (SecurityService.vaultContainerPresent ? "LOCKED" : "NOT CREATED")
        badgeColor: SecurityService.vaultMounted ? Theme.accent : (SecurityService.vaultContainerPresent ? Theme.warning : Theme.textDim)

        MujoSettingRow {
            iconName: SecurityService.vaultMounted ? "lock_open" : "lock"
            title: SecurityService.vaultMounted ? "Vault unlocked" : "Vault locked"
            description: SecurityService.vaultMounted
                ? "Mounted at " + SecurityService.vaultMountPoint + " with 0700 permissions"
                : (SecurityService.vaultContainerPresent
                    ? "Container: /persist/secure/mujo-vault.luks (" + (SecurityService.vaultContainerSize || "Present") + ")"
                    : "Initialize with: sudo mujo-vault init 10G")

            DialogButton {
                text: SecurityService.vaultMounted ? "Lock" : "Unlock"
                primary: !SecurityService.vaultMounted
                enabled: SecurityService.vaultMounted || SecurityService.vaultContainerPresent
                onClicked: SecurityService.vaultMounted ? SecurityService.closeVault() : SecurityService.openVault()
            }
        }

        // What the unlocked vault holds. One tag shape, no folder glyph per
        // chip — the label above already says these are directories.
        ColumnLayout {
            visible: SecurityService.vaultMounted && SecurityService.vaultSubdirectories.length > 0
            Layout.fillWidth: true
            Layout.topMargin: 2
            spacing: 7

            Text {
                text: "Encrypted domains"
                color: Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
            }

            Flow {
                Layout.fillWidth: true
                spacing: 6

                Repeater {
                    model: SecurityService.vaultSubdirectories
                    delegate: StatusTag {
                        required property var modelData
                        text: modelData
                        tone: "accent"
                    }
                }
            }
        }

        MujoSettingRow {
            iconName: "timer"
            title: "Auto-lock timeout"
            description: "Automatically unmount and lock the encrypted container after inactivity."

            MujoSegmented {
                model: [
                    { id: "15m",   label: "15 min" },
                    { id: "30m",   label: "30 min" },
                    { id: "1h",    label: "1 hour" },
                    { id: "never", label: "Manual" }
                ]
                current: (root.nixosPrefs.vault && root.nixosPrefs.vault.autoLock) ? root.nixosPrefs.vault.autoLock : "30m"
                onSelected: function(id) { root.setNixosPref("vault.autoLock", id) }
            }
        }

        MujoSettingRow {
            iconName: SecurityService.inventoryFailed ? "help" : "find_in_page"
            title: "Plaintext storage audit"
            description: !SecurityService.inventoryAudited
                ? "Audits /persist for unencrypted private keys, tokens, and credentials"
                : SecurityService.inventoryFailed
                    ? "Scan did not complete — nothing was verified. Re-run it."
                    : (SecurityService.inventoryClean
                        ? "Clean: No unencrypted keys or tokens found on persistent storage"
                        : SecurityService.inventoryFindingsCount + " plaintext item(s) found outside the vault")

            DialogButton {
                text: SecurityService.inventoryAudited ? "Scan again" : "Run scan"
                onClicked: SecurityService.auditInventory()
            }
        }
    }

    // ── 4. Progressive Trust & Application Sandboxing ────────────────────────
    MujoCard {
        title: "Progressive Trust & Sandboxing"
        iconName: "shield"
        badgeText: (SecurityService.totalAppsCount) + " APPS TRACKED"
        badgeColor: Theme.accent


        // Four counts, one shape. They were four copies of the same forty-line
        // tile with only the colour and the words changed.
        RowLayout {
            id: trustStats
            Layout.fillWidth: true
            Layout.topMargin: 2
            spacing: 8

            readonly property var tiers: [
                { n: SecurityService.quarantinedAppsCount, label: "Quarantine", sub: "MicroVM domain",  tone: Theme.warning },
                { n: SecurityService.observingAppsCount,   label: "Observing",  sub: "Pre-graduation", tone: Theme.accent  },
                { n: SecurityService.graduatedAppsCount,   label: "Graduated",  sub: "Native sandbox", tone: Theme.success },
                { n: SecurityService.revokedAppsCount,     label: "Revoked",    sub: "Blocked",        tone: Theme.error   }
            ]

            Repeater {
                model: trustStats.tiers

                delegate: InsetPanel {
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: 52
                    color: tileHh.hovered ? Theme.surfaceHover : Theme.bg
                    accentBorder: tileHh.hovered ? modelData.tone : Theme.border
                    Behavior on color { ColorAnimation { duration: Anim.d(Anim.fast) } }

                    HoverHandler { id: tileHh; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: root.openTrustRequested() }

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

        MujoSettingRow {
            iconName: "rocket_launch"
            title: "Quarantine new applications"
            description: (root.nixosPrefs.trust ? root.nixosPrefs.trust.launcherIntegration === true : SecurityService.launcherIntegrationActive)
                ? "Launcher automatically runs untrusted applications inside isolated quarantine domains"
                : "Launcher starts applications directly on host (bypasses automatic quarantine on first click)"

            ToggleSwitch {
                a11yName: "Quarantine new applications"
                checked: root.nixosPrefs.trust ? (root.nixosPrefs.trust.launcherIntegration === true) : SecurityService.launcherIntegrationActive
                onToggled: function(c) {
                    root.setNixosPref("trust.launcherIntegration", c)
                    SecurityService.setLauncherIntegration(c)
                }
            }
        }

        MujoSettingRow {
            iconName: "security"
            title: "Narrow Flatpak permissions"
            description: "Subtractive overrides: strip raw /dev, ptrace, and smartcard access from graduated Flatpaks"

            ToggleSwitch {
                a11yName: "Narrow Flatpak permissions"
                checked: root.nixosPrefs.trust ? (root.nixosPrefs.trust.flatpakNarrowing !== false) : true
                onToggled: function(c) { root.setNixosPref("trust.flatpakNarrowing", c) }
            }
        }

        MujoSettingRow {
            iconName: "policy"
            title: "Per-application policy"
            description: "Configure individual application risk tiers, quarantine overrides, and graduation logs."

            RowLayout {
                spacing: 8

                DialogButton {
                    text: "Evaluate now"
                    onClicked: SecurityService.evaluateTrust()
                }

                DialogButton {
                    text: "Manage apps"
                    primary: true
                    onClicked: root.openTrustRequested()
                }
            }
        }
    }
}


