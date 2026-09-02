pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Mujo 2.0 Security Architecture & Progressive Trust Service Singleton.
// Provides live reactive telemetry for Verified Boot, Storage Vault, Host Hardening, and Application Trust.
QtObject {
    id: security

    readonly property bool enabled: true

    // ── Verified Boot & Kernel ────────────────────────────────────────────────
    property bool secureBootActive: false
    property bool tpmActive: false
    property string lockdownMode: "none"

    // ── Storage Vault ─────────────────────────────────────────────────────────
    property bool vaultContainerPresent: false
    property string vaultContainerSize: ""
    property bool vaultMounted: false
    property string vaultMountPoint: "/run/mujo/vault"
    property var vaultSubdirectories: []
    property string vaultStatus: vaultMounted ? "unlocked" : (vaultContainerPresent ? "locked" : "not_configured")

    // ── Memory & Host Isolation ──────────────────────────────────────────────
    // All false until a summary actually says otherwise. These drive the four
    // hardening cards in SecurityGroup, which read "UNVERIFIED" when false --
    // so an optimistic default here would be the panel asserting a protection
    // is on before anything checked, and would stay asserted forever if the
    // summary process failed. _pollTimer has triggeredOnStart, so the real
    // value arrives one round-trip after load.
    property bool encryptedSwapActive: false
    property bool coredumpDisabled: false
    property bool tmpfsTmpActive: false
    property bool firewallActive: false

    // ── Progressive Application Trust ─────────────────────────────────────────
    property var trustApps: []
    property int quarantinedAppsCount: 0
    property int observingAppsCount: 0
    property int graduatedAppsCount: 0
    property int revokedAppsCount: 0
    property int totalAppsCount: 0
    property bool launcherIntegrationActive: false

    // ── Sensitive Inventory Audit ────────────────────────────────────────────
    property bool inventoryAudited: false
    property bool inventoryClean: false
    // Distinct from "audited and not clean": the scan did not produce a result
    // we can read. "Clean" is a positive claim about the user's disk and must
    // never be the fallback for a scan that failed -- see inventoryProc.
    property bool inventoryFailed: false
    property int inventoryFindingsCount: 0
    property string inventoryOutput: ""

    // ── Overall Health & Status ──────────────────────────────────────────────
    property string overallStatus: "secure" // "secure", "attention", "warning"

    signal statusUpdated()

    function refresh() {
        if (!statusProc.running) statusProc.running = true
        if (!trustProc.running) trustProc.running = true
    }

    function _optimisticUpdate(appName, newState) {
        if (!appName || !security.trustApps) return
        var list = security.trustApps.map(function(a) {
            if (a.id === appName || a.name === appName) {
                var copy = Object.assign({}, a)
                copy.state = newState
                return copy
            }
            return a
        })
        security.trustApps = list
        security.quarantinedAppsCount = list.filter(function(a) { return a.state === "QUARANTINE" }).length
        security.observingAppsCount = list.filter(function(a) { return a.state === "OBSERVING" }).length
        security.graduatedAppsCount = list.filter(function(a) { return a.state === "GRADUATED" }).length
        security.revokedAppsCount = list.filter(function(a) { return a.state === "REVOKED" }).length
        security.statusUpdated()
    }

    // Run the action as a tracked child and refresh when it exits: that is the
    // only moment its result is actually on disk. A blind timer refresh raced
    // the write and stomped the optimistic state back to the stale one.
    property Process actionProc: Process {
        stderr: StdioCollector {
            onStreamFinished: {
                if (this.text.trim() !== "") console.warn("SecurityService action failed:", this.text.trim())
            }
        }
        onExited: security.refresh()
    }

    function _runAction(argv) {
        if (actionProc.running) return
        actionProc.command = argv
        actionProc.running = true
    }

    function openVault() {
        _runAction(["mujo", "vault", "open"])
    }

    function closeVault() {
        _runAction(["mujo", "vault", "close"])
    }

    function auditInventory() {
        if (!inventoryProc.running) {
            inventoryProc.running = true
        }
    }

    function evaluateTrust() {
        _runAction(["mujo", "trust", "evaluate"])
    }

    function graduateApp(appName) {
        if (!appName) return
        _optimisticUpdate(appName, "GRADUATED")
        _runAction(["mujo", "trust", "graduate", appName])
    }

    function quarantineApp(appName) {
        if (!appName) return
        _optimisticUpdate(appName, "QUARANTINE")
        _runAction(["mujo", "trust", "quarantine", appName])
    }

    function rollbackApp(appName) {
        if (!appName) return
        _optimisticUpdate(appName, "GRADUATED")
        _runAction(["mujo", "trust", "rollback", appName])
    }

    function revokeApp(appName) {
        if (!appName) return
        _optimisticUpdate(appName, "REVOKED")
        _runAction(["mujo", "trust", "revoke", appName])
    }

    // ── Background Processes ──────────────────────────────────────────────────
    property Process statusProc: Process {
        command: ["mujo", "security", "summary"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var d = JSON.parse(this.text)
                    if (d.verifiedBoot) {
                        security.secureBootActive = d.verifiedBoot.secureBoot || false
                        security.tpmActive = d.verifiedBoot.tpm || false
                        security.lockdownMode = d.verifiedBoot.lockdown || "none"
                    }
                    if (d.vault) {
                        security.vaultContainerPresent = d.vault.containerPresent || false
                        security.vaultContainerSize = d.vault.containerSize || ""
                        security.vaultMounted = d.vault.mounted || false
                        security.vaultMountPoint = d.vault.mountPoint || "/run/mujo/vault"
                        security.vaultSubdirectories = d.vault.subdirectories || []
                    }
                    // `=== true`, not `!== false`: a field the summary omitted
                    // is a protection nothing confirmed, which is exactly what
                    // "UNVERIFIED" is for. `!== false` read a missing key as on.
                    if (d.storage) {
                        security.encryptedSwapActive = d.storage.encryptedSwap === true
                        security.coredumpDisabled = d.storage.coredumpDisabled === true
                        security.tmpfsTmpActive = d.storage.tmpfsTmp === true
                    }
                    if (d.network) {
                        security.firewallActive = d.network.firewallActive === true
                    }
                    if (d.overallStatus) {
                        security.overallStatus = d.overallStatus
                    }
                    security.statusUpdated()
                } catch (e) {
                    // Leave every flag where it is -- false, or the last value a
                    // summary actually reported. Swallowing this silently was
                    // how a failed probe kept the panel green.
                    console.warn("SecurityService: security summary unreadable:", e)
                }
            }
        }
    }

    property Process trustProc: Process {
        command: ["mujo", "trust", "summary"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var d = JSON.parse(this.text)
                    security.trustApps = d.applications || []
                    if (d.counts) {
                        security.quarantinedAppsCount = d.counts.quarantine || 0
                        security.observingAppsCount = d.counts.observing || 0
                        security.graduatedAppsCount = d.counts.graduated || 0
                        security.revokedAppsCount = d.counts.revoked || 0
                        security.totalAppsCount = d.counts.total || 0
                    }
                    security.launcherIntegrationActive = d.launcherIntegration || false
                    security.statusUpdated()
                } catch (e) {}
            }
        }
    }

    property Process inventoryProc: Process {
        command: ["mujo", "security", "inventory"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var d = JSON.parse(this.text)
                    security.inventoryAudited = true
                    security.inventoryFailed = false
                    security.inventoryClean = d.clean || false
                    security.inventoryFindingsCount = d.findingsCount || 0
                    security.inventoryOutput = d.output || ""
                    security.statusUpdated()
                } catch (e) {
                    // Previously this reported clean: 0 findings -- so a scan
                    // that crashed or printed nothing drew a green "no
                    // unencrypted keys found on persistent storage". Saying the
                    // disk is clean is the one thing a failed audit cannot do.
                    console.warn("SecurityService: inventory scan produced no readable result:", e)
                    security.inventoryAudited = true
                    security.inventoryFailed = true
                    security.inventoryClean = false
                    security.inventoryFindingsCount = 0
                    security.inventoryOutput = ""
                    security.statusUpdated()
                }
            }
        }
    }

    property Timer _pollTimer: Timer {
        interval: 15000
        running: security.enabled
        repeat: true
        triggeredOnStart: true
        onTriggered: security.refresh()
    }
}
