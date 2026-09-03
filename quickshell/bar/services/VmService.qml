pragma Singleton
import QtQuick
import Quickshell.Io

// Hypervisor engine: the `mujo vm` process layer, the parsed inventory, and the
// one long-running operation the UI watches. Split out of VmGroup so the panel
// is view code only, the same way SecurityService backs SecurityGroup.
//
// Deliberately not self-polling. `mujo vm list` shells out to quickemu/QEMU and
// the panel wants it every 2s while on screen — a singleton timer at that rate
// would keep running for the life of the session. The view owns the cadence and
// calls refresh(); the service owns everything else.
QtObject {
    id: vm

    readonly property var emptyInventory: ({ kvm: true, vms: [], totalCount: 0, activeCount: 0, vcpusAllocated: 0 })

    property var inventory: vm.emptyInventory
    property var catalog: []

    // ── The one in-flight operation ───────────────────────────────────────────
    property bool running: false
    property bool failed: false
    property string opTitle: ""
    property string opStatus: ""
    property real opProgress: -1        // -1 = indeterminate
    property string opSpeed: ""
    property string opEta: ""
    property var logLines: []

    function refresh() {
        if (!listProc.running) listProc.running = true
        if (vm.catalog.length === 0 && !catalogProc.running) catalogProc.running = true
    }

    property Process _listProc: Process {
        id: listProc
        command: ["mujo", "vm", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { vm.inventory = JSON.parse(this.text) }
                catch (e) { vm.inventory = vm.emptyInventory }
            }
        }
    }

    property Process _catalogProc: Process {
        id: catalogProc
        command: ["mujo", "vm", "catalog"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { vm.catalog = JSON.parse(this.text) }
                catch (e) { vm.catalog = [] }
            }
        }
    }

    property Process _actionProc: Process {
        id: actionProc
        stdout: SplitParser { splitMarker: "\n"; onRead: line => vm.appendLog(line) }
        stderr: SplitParser { splitMarker: "\n"; onRead: line => vm.appendLog(line) }
        onExited: function (code) {
            vm.running = false
            if (code !== 0) {
                vm.failed = true
                vm.opStatus = "Operation failed (exit code " + code + ")"
            } else {
                vm.failed = false
                vm.opProgress = 100
                vm.opStatus = "Setup completed successfully"
            }
            vm.refresh()
        }
    }

    // Append one line of subprocess output and pull progress out of it.
    //
    // `mujo vm` emits structured `{"type":"progress",…}` lines where it can, but
    // quickemu and the image downloaders it drives print their own free-form
    // progress, so the regexes below are the fallback for tools this repo does
    // not control. Public because test-vm-service.qml drives it directly.
    function appendLog(raw) {
        if (!raw || raw.trim() === "") return
        var line = raw.trim()

        var logs = vm.logLines.slice()
        if (logs.length > 300) logs.shift()
        logs.push(line)
        vm.logLines = logs

        if (line.startsWith("{") && line.endsWith("}")) {
            try {
                var obj = JSON.parse(line)
                if (obj.type === "progress") {
                    if (obj.percent !== undefined) vm.opProgress = obj.percent
                    if (obj.status) vm.opStatus = obj.status
                    if (obj.speed) vm.opSpeed = obj.speed
                    if (obj.eta) vm.opEta = obj.eta
                    return
                }
            } catch (e) {}
        }

        var pct = line.match(/\b([0-9]{1,3}(?:\.[0-9]+)?)\s*%/)
        if (pct && pct[1]) {
            var val = parseFloat(pct[1])
            if (!isNaN(val) && val >= 0 && val <= 100) vm.opProgress = val
        }

        var spd = line.match(/([0-9.]+\s*[kMG]B\/s|[0-9.]+\s*[kMG]b\/s)/i)
        if (spd) vm.opSpeed = spd[1]

        var eta = line.match(/(?:ETA|eta|time)\s*([0-9:]+)/i)
        if (eta) vm.opEta = eta[1]

        // A bare progress bar ("=== 42% ===") is not a status message.
        if (!line.startsWith("{") && line.length > 3 && !line.match(/^[0-9\s%#=-]+$/))
            vm.opStatus = line
    }

    // ── Verbs ─────────────────────────────────────────────────────────────────
    function run(args, titleMsg, statusMsg) {
        if (actionProc.running) return
        vm.running = true
        vm.failed = false
        vm.opProgress = -1
        vm.opSpeed = ""
        vm.opEta = ""
        vm.opTitle = titleMsg || "Virtual Machine Operation"
        vm.opStatus = statusMsg || "Initializing..."
        vm.logLines = []
        actionProc.command = ["mujo", "vm"].concat(args)
        actionProc.running = true
    }

    function cancel() {
        if (!actionProc.running) return
        actionProc.running = false
        vm.running = false
        vm.failed = true
        vm.opStatus = "Operation cancelled"
        vm.appendLog("[!] Process cancelled by user")
    }

    function start(name, openViewer) {
        vm.run(["start", name, "--viewer", openViewer ? "true" : "false"],
               "Starting " + name, "Launching QEMU and connecting SPICE visual server...")
    }

    function stop(name, force) {
        var args = ["stop", name]
        if (force) args.push("--force")
        vm.run(args, "Stopping " + name, "Sending ACPI shutdown signal...")
    }

    function display(name) {
        vm.run(["display", name], "Connecting Display", "Opening SPICE viewer for " + name + "...")
    }

    function remove(name) {
        vm.run(["delete", name], "Deleting " + name, "Removing VM disk and configuration files...")
    }

    function create(preset, name, cores, ramGb, diskGb) {
        vm.run(["create", preset.os, preset.release,
                "--name", name, "--cores", String(cores),
                "--ram", String(ramGb), "--disk", String(diskGb)],
               "Provisioning " + name, "Fetching OS image and preparing VM environment...")
    }

    function createFromIso(name, isoPath, cores, ramGb, diskGb, os) {
        vm.run(["create-iso", name, isoPath,
                "--cores", String(cores), "--ram", String(ramGb),
                "--disk", String(diskGb), "--os", os],
               "Creating Custom VM: " + name, "Configuring VM from ISO " + name + "...")
    }
}
