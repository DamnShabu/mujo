pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Boot greeter state (WP-??). Runs once per session, the first time the shell
// comes up: if a vault container exists it asks for the passphrase and unlocks
// it; if none exists it offers to create one. Either way it is *skippable* —
// the vault is optional, and refusing it must still land you on your desktop.
//
// Mode selection is synchronous and unprivileged: /run/mujo/vault-present is a
// 0444 marker stamped by `mujo-vault marker` at boot (the container itself lives
// under 0700-root /persist/secure and cannot be stat'd by the user — see
// nixos/security/vault.nix). Nothing here shells out to pkexec just to decide
// what to draw, so the surface is up on the first frame.
//
// The privileged verbs go through `pkexec mujo-vault`, which the polkit rule in
// nixos/security/vault.nix grants to wheel with Result.YES — allowed, no prompt.
// The passphrase travels on stdin, never in argv.
QtObject {
    id: greeter

    // ── Mode ──────────────────────────────────────────────────────────────────
    readonly property string modeUnlock: "unlock"
    readonly property string modeSetup: "setup"

    readonly property bool enabled: SettingsBus.get("greeter.enable", true)

    // Set once at startup so the greeter cannot change shape underneath the user
    // mid-flow (a `mujo-vault init` finishing would otherwise flip the surface
    // out from under a half-typed passphrase).
    property string mode: modeUnlock

    property bool dismissed: false
    property bool vaultMounted: false

    // Nothing is drawn until the probe has answered. Without this the surface
    // flashes up for one frame on an already-unlocked vault, because
    // vaultMounted only becomes true once the probe returns.
    property bool probed: false

    // The greeter is up while there is something to do and the user has not
    // waved it away. Unlocking sets vaultMounted, which retires it for good.
    readonly property bool active: enabled && probed && !dismissed && !vaultMounted

    property bool busy: false
    property string error: ""
    property string progress: ""
    property int attempts: 0

    // Setup: container size, offered as a few sane choices rather than a text field.
    property string setupSize: "10G"

    function dismiss() {
        greeter.dismissed = true
    }

    // "Not now, and stop asking." Only offered on the setup pane: skipping an
    // *unlock* is a one-off, but being shown a setup wizard every boot for a
    // vault you have decided not to create is the kind of thing people disable
    // by deleting the shell.
    function dismissForever() {
        SettingsBus.set("greeter.enable", false)
        greeter.dismissed = true
    }

    // ── Unlock ────────────────────────────────────────────────────────────────
    function unlock(passphrase) {
        if (greeter.busy || passphrase.length === 0) return
        greeter.busy = true
        greeter.error = ""
        greeter.progress = "Unlocking vault…"
        _vault.run(["open"], passphrase)
    }

    // ── Setup ─────────────────────────────────────────────────────────────────
    // luksFormat with Argon2id is deliberately slow (seconds), and mkfs follows
    // it, so this is the one path that really needs the busy state.
    function createVault(passphrase) {
        if (greeter.busy || passphrase.length === 0) return
        greeter.busy = true
        greeter.error = ""
        greeter.progress = "Creating encrypted vault (" + greeter.setupSize + ")…"
        _vault.pendingUnlock = passphrase
        _vault.run(["init", greeter.setupSize], passphrase)
    }

    // ── Privileged runner ─────────────────────────────────────────────────────
    property Process _vault: Process {
        property string pw: ""
        property var pendingUnlock: null   // set by createVault: open right after init
        property bool sent: false
        property string verb: ""

        stdinEnabled: true
        stderr: StdioCollector {}

        function run(args, passphrase) {
            verb = args[0]
            pw = passphrase
            sent = false
            command = ["pkexec", "mujo-vault"].concat(args)
            stdinEnabled = true
            running = true
        }

        // Write only once the process is actually up, then close stdin so
        // cryptsetup's --key-file - read returns. Same handshake as Lock.qml's
        // qsshell-unlock; writing before `running` drops the bytes.
        onRunningChanged: {
            if (running && !sent) { write(pw + "\n"); stdinEnabled = false; sent = true }
        }

        onExited: (code, status) => {
            const wasInit = verb === "init"
            const carry = pendingUnlock
            pw = ""
            pendingUnlock = null

            if (code !== 0) {
                greeter.busy = false
                greeter.progress = ""
                greeter.attempts++
                // pkexec itself exits 126/127 when authorisation is refused or
                // the binary is missing; anything else came from cryptsetup and
                // for `open` that is overwhelmingly a wrong passphrase.
                greeter.error = code === 126 || code === 127
                    ? "Not authorised to manage the vault"
                    : (wasInit ? "Could not create the vault" : "Wrong passphrase")
                return
            }

            // init succeeded — chain straight into open so the user types the
            // passphrase once and lands in an unlocked vault.
            if (wasInit && carry) {
                greeter.progress = "Unlocking vault…"
                run(["open"], carry)
                return
            }

            greeter.busy = false
            greeter.progress = ""
            greeter.error = ""
            greeter.attempts = 0
            greeter.vaultMounted = true
            Notifications.notify("Vault unlocked", "Secure storage is available at /run/mujo/vault.",
                                 "lock_open", "low", { transient: true })
        }
    }

    // ── Startup probe ─────────────────────────────────────────────────────────
    // Reads the marker and the mountpoint in one shot. `mountpoint` needs no
    // privilege here: /run/mujo is 0755, only the mount *contents* are 0700.
    property Process _probe: Process {
        running: true
        command: ["sh", "-c",
            "mountpoint -q /run/mujo/vault && echo mounted; " +
            "test -f /run/mujo/vault-present && echo present"]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = this.text
                greeter.vaultMounted = out.indexOf("mounted") >= 0
                greeter.mode = out.indexOf("present") >= 0 ? greeter.modeUnlock : greeter.modeSetup
                greeter.probed = true
            }
        }
    }
}
