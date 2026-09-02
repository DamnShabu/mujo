pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Central app-launch service + launch-feedback state.
//
// Why this exists: quickshell's DesktopEntry.execute() spawns the child in the
// *caller's* cgroup. Under the qs-bar systemd service that means every launched
// app lands inside qs-bar.service's cgroup and is killed the moment qs-bar
// restarts — which happens on every `nixos-rebuild switch` (restartTriggers).
// That is the "apps don't launch reliably" bug.
//
// The fix: launch each app in its own transient systemd *user* scope via
// `systemd-run --user --scope`. The scope is registered directly under the user
// manager's app.slice, independent of qs-bar's cgroup, so the app survives shell
// restarts exactly like one spawned by niri. `Quickshell.execDetached` fully
// detaches the systemd-run client so nothing is tracked by the shell.
QtObject {
    id: launch

    // ── Launch-feedback state (drives LaunchFeedback.qml) ────────────────────
    property string activeName: ""
    property string activeIcon: ""     // icon name / path for the launching app
    property string activeScreen: ""   // screen name to show the indicator on ("" = all)
    property bool showing: false

    // Niri connection (assigned by shell.qml) used to dismiss the indicator as
    // soon as the launched app's window actually maps, instead of after a fixed
    // delay.
    property var wm: null
    // Lowercased app-id candidates (startupClass / desktop entry id) of the
    // launch we're waiting for.
    property var _expectIds: []

    readonly property Timer _hideTimer: Timer {
        // Watchdog only: apps that never open a window (background tools,
        // crashed launches) still clear the pill eventually.
        interval: 15000
        onTriggered: launch._clear()
    }

    // Dismiss on niri's WindowOpenedOrChanged event for the expected app_id.
    readonly property Connections _niriConn: Connections {
        target: launch.wm
        function onRawEventReceived(ev) {
            if (!launch.showing || launch._expectIds.length === 0) return
            var w = ev && ev.WindowOpenedOrChanged && ev.WindowOpenedOrChanged.window
            if (!w || !w.app_id) return
            if (launch._expectIds.indexOf(String(w.app_id).toLowerCase()) >= 0) launch._clear()
        }
    }

    function _clear() {
        showing = false
        _expectIds = []
    }

    // Phase 11/24: when the trust engine owns launching, a desktop entry is not
    // spawned directly — `mujo-trust run` resolves the app's identity and picks
    // its runtime (quarantine MicroVM or native sandbox) from its trust state.
    // The user still clicks the same icon; the runtime changes underneath.
    //
    // Off unless the host wrote the marker: with it on, an application nobody
    // has graduated yet boots a VM on first launch, which is not a change to
    // make silently. See `apps.trust.launcherIntegration` and
    // docs/application-trust.md §8.
    property bool trustRouting: true
    property FileView _trustMarker: FileView {
        path: "/etc/mujo/launcher-integration"
        onLoaded: launch.trustRouting = (text() || "").trim() === "enabled"
        onLoadFailed: function (err) { /* keep default */ }
    }

    // Build an argv from a DesktopEntry, dropping desktop field codes (%U, %F…).
    // entry.command is already tokenized by quickshell with field codes handled,
    // but bare "%U"-style tokens can survive for entries that use them alone.
    function _argvFor(entry) {
        var raw = entry ? entry.command : null
        var argv = []
        if (raw && raw.length !== undefined) {
            for (var i = 0; i < raw.length; i++) {
                var tok = String(raw[i])
                if (tok.length === 2 && tok.charAt(0) === "%") continue
                argv.push(tok)
            }
        }
        return argv
    }

    function _spawn(argv) {
        // --collect: GC the scope once the app exits. --quiet: no chatter.
        var full = ["systemd-run", "--user", "--scope", "--collect", "--quiet", "--"].concat(argv)
        // Route through `sh -c 'exec "$0" "$@"'`: execDetached invoking systemd-run
        // *directly* silently spawns nothing (the detach breaks systemd-run's scope
        // registration), but running it via a shell works reliably. The exec/$0/$@
        // idiom forwards argv without any quoting/escaping of the app's own args.
        Quickshell.execDetached(["bash", "-c", "exec \"$0\" \"$@\""].concat(full))
    }

    // Launch a DesktopEntry. `screen` (optional) scopes the feedback indicator.
    function app(entry, screen) {
        if (!entry)
            return
        var argv = _argvFor(entry)
        var name = entry.name || (argv.length ? argv[0] : "Application")
        // startupWMClass is designed to equal the Wayland app_id; the entry id
        // is the common fallback. Either matching a new window ends the wait.
        var ids = []
        if (entry.startupClass) ids.push(String(entry.startupClass).toLowerCase())
        if (entry.id && entry.id !== entry.startupClass) ids.push(String(entry.id).toLowerCase())
        if (argv.length > 0) {
            // Trust routing wraps the application, not the terminal:
            // `kitty -e mujo-run foo`, never `mujo-run kitty`, which
            // would evaluate the terminal instead of what the user asked for.
            var isTerminal = argv[0] === "kitty" || argv[0] === "terminal"
            var cmd = (launch.trustRouting && !isTerminal) ? ["mujo-run"].concat(argv) : argv
            if (entry.runInTerminal) cmd = ["kitty", "-e"].concat(cmd)
            _spawn(cmd)
        } else {
            // No parsed command available — let quickshell parse the Exec line.
            // (Rare; loses the dedicated-scope guarantee but still launches.)
            entry.execute()
        }
        launch.recordRecent(entry)
        notify(name, entry.icon || "", screen, ids)
    }

    // WP-06: maintain apps.recent[] (most-recent-first, deduped, cap 10) so the
    // launcher grid can surface a recents row.
    function recordRecent(entry) {
        var id = entry && entry.id ? entry.id : (entry ? entry.name : "")
        if (!id) return
        var r = (SettingsBus.get("apps.recent", [])).filter(function (x) { return x !== id })
        r.unshift(id)
        if (r.length > 10) r = r.slice(0, 10)
        SettingsBus.set("apps.recent", r)
    }

    // Launch an arbitrary argv in its own scope (desktop menu, integrations…).
    function run(argv, name, icon, screen, expectIds) {
        if (!argv || argv.length === 0)
            return
        var cmd = argv
        if (launch.trustRouting && argv[0] !== "mujo-run" && argv[0] !== "mujo-trust" && argv[0] !== "pkexec" && argv[0] !== "mujo" && argv[0] !== "qs" && argv[0] !== "niri" && argv[0] !== "wl-copy" && argv[0] !== "cliphist" && argv[0] !== "kitty" && argv[0] !== "terminal") {
            cmd = ["mujo-run"].concat(argv)
        }
        _spawn(cmd)
        notify(name || argv[0], icon || "", screen, expectIds || [])
    }

    // Same, for a CLI that needs a terminal (agent CLIs, integrations). The
    // kitty wrapper lives here and in app()'s Terminal=true branch only.
    function terminal(argv, name, icon, screen) {
        if (!argv || argv.length === 0)
            return
        launch.run(["kitty", "-e"].concat(argv), name, icon || "terminal", screen)
    }

    function notify(name, icon, screen, expectIds) {
        activeName = name
        activeIcon = icon || ""
        activeScreen = screen || ""
        _expectIds = expectIds || []
        showing = true
        _hideTimer.restart()
    }
}
