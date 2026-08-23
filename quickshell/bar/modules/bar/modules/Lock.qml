pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Lock-screen state + PAM auth (WP-14). Single source of truth for the lock;
// LockScreen.qml renders the WlSessionLock surfaces bound to `locked`, and the
// `lock` IpcHandler / Session / IdleService all drive it through here. Gated by
// the `lock.enable` setting — when off, lock() no-ops with a toast.
QtObject {
    id: lock

    property bool locked: false
    property bool busy: false        // auth in flight
    property int attempts: 0
    property string error: ""

    readonly property bool enabled: SettingsBus.get("lock.enable", true)

    function lock() {
        if (lock.locked) return
        if (!lock.enabled) { Notifications.notify("Lock disabled", "Enable it in Display → Idle & power.", "lock", "normal", { transient: true }); return }
        lock.attempts = 0
        lock.error = ""
        lock.locked = true
    }
    function unlock() { lock.locked = false }        // programmatic release (not via password)
    function toggle() { if (lock.locked) lock.unlock(); else lock.lock() }

    function authenticate(pw) {
        if (lock.busy || !lock.locked) return
        lock.busy = true
        lock.error = ""
        _auth.sent = false
        _auth.pw = pw
        _auth.stdinEnabled = true
        _auth.running = true
    }

    property Process _auth: Process {
        command: ["qsshell-unlock"]
        property string pw: ""
        property bool sent: false
        stdinEnabled: true
        // Write the password only once the process is actually running, then
        // close stdin so the helper's fgets() returns (mirrors AiPanel keyring).
        onRunningChanged: {
            if (running && !sent) { write(pw + "\n"); stdinEnabled = false; sent = true }
        }
        onExited: (code, status) => {
            pw = ""
            lock.busy = false
            if (code === 0) { lock.attempts = 0; lock.error = ""; lock.locked = false }
            else { lock.attempts++; lock.error = "Authentication failed" }
        }
    }
}
