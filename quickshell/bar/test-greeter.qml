import QtQuick
import "./services"

// Self-check for the boot greeter's mode/visibility logic (`qs -p ./test-greeter.qml`).
// The state machine is the part that can silently go wrong: a greeter that shows
// on an already-unlocked vault steals the session at every login, and one that
// never shows makes the vault unreachable without a terminal. Neither failure is
// visible from a screenshot, so it is asserted here instead.
//
// The privileged verbs are not exercised — `pkexec mujo-vault init` would format
// a real container. Those are covered by tests/storage/test-vault-isolation.sh
// against the running system.
Item {
    property int failures: 0

    function check(name, cond) {
        console.log((cond ? "PASS" : "FAIL") + ": " + name)
        if (!cond) failures++
    }

    // Assertions run from a zero-interval Timer, never Component.onCompleted:
    // Quickshell only connects Qt.exit() after the config finishes loading, so a
    // check that exits from onCompleted prints its verdict and then hangs.
    Timer {
        interval: 0
        running: true
        onTriggered: {
            // ── Visibility ────────────────────────────────────────────────────
            Greeter.probed = false
            Greeter.dismissed = false
            Greeter.vaultMounted = false
            check("hidden until the startup probe has answered", !Greeter.active)

            Greeter.probed = true
            check("shown once probed, with a locked vault", Greeter.active)

            Greeter.vaultMounted = true
            check("retired the moment the vault is mounted", !Greeter.active)

            Greeter.vaultMounted = false
            Greeter.dismissed = true
            check("stays down after Skip", !Greeter.active)

            // ── Mode ──────────────────────────────────────────────────────────
            // Both panes must be reachable; a typo in either constant would
            // silently pin the greeter to one of them forever.
            check("unlock and setup are distinct modes", Greeter.modeUnlock !== Greeter.modeSetup)

            Greeter.mode = Greeter.modeSetup
            check("setup mode holds", Greeter.mode === Greeter.modeSetup)
            Greeter.mode = Greeter.modeUnlock
            check("unlock mode holds", Greeter.mode === Greeter.modeUnlock)

            // ── Guards ────────────────────────────────────────────────────────
            // An empty passphrase must not reach cryptsetup, and a second submit
            // while one is in flight must not spawn a second pkexec.
            Greeter.busy = false
            Greeter.unlock("")
            check("empty passphrase is refused", !Greeter.busy)

            Greeter.busy = true
            Greeter.progress = "sentinel"
            Greeter.unlock("something")
            check("submit while busy is ignored", Greeter.progress === "sentinel")

            Greeter.createVault("something")
            check("createVault while busy is ignored", Greeter.progress === "sentinel")
            Greeter.busy = false

            console.log(failures === 0 ? "ALL PASS" : (failures + " FAILED"))
            Qt.exit(failures === 0 ? 0 : 1)
        }
    }
}
