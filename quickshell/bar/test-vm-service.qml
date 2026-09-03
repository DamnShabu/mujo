import QtQuick
import Quickshell
import "services"

// Self-check for VmService's subprocess log parser.
// Run: qs -p ./test-vm-service.qml
//
// `mujo vm` emits structured progress lines, but it drives quickemu and the
// image downloaders, which print their own. The regex fallback that reads those
// is the only non-trivial logic in the service, and a wrong match shows the user
// a progress bar that moves to the wrong place -- or a status line made of "===".
ShellRoot {
    id: root

    property var fails: []
    function check(name, ok) { if (!ok) root.fails.push(name) }

    function reset() {
        VmService.opProgress = -1
        VmService.opStatus = ""
        VmService.opSpeed = ""
        VmService.opEta = ""
        VmService.logLines = []
    }

    Timer {
        interval: 0
        running: true
        onTriggered: {
            // 1. Structured progress wins outright and never reaches the regexes.
            root.reset()
            VmService.appendLog('{"type":"progress","percent":42,"status":"Downloading","speed":"3.2 MB/s","eta":"0:31"}')
            root.check("structured percent", VmService.opProgress === 42)
            root.check("structured status", VmService.opStatus === "Downloading")
            root.check("structured speed", VmService.opSpeed === "3.2 MB/s")
            root.check("structured eta", VmService.opEta === "0:31")

            // 2. quickemu-style free text: percent, speed and ETA off one line.
            root.reset()
            VmService.appendLog("ubuntu-24.04.iso  37% [====>    ]  11.4 MB/s  eta 2:15")
            root.check("free-text percent", VmService.opProgress === 37)
            root.check("free-text speed", VmService.opSpeed === "11.4 MB/s")
            root.check("free-text eta", VmService.opEta === "2:15")
            root.check("free-text status keeps the line", VmService.opStatus.indexOf("ubuntu") === 0)

            // 3. A bare progress bar is not a status message.
            root.reset()
            VmService.appendLog("=== 50% ===")
            root.check("bar sets progress", VmService.opProgress === 50)
            root.check("bar is not a status", VmService.opStatus === "")

            // 4. Out-of-range and non-numeric percents are ignored, not clamped
            //    to something that looks like real progress.
            root.reset()
            VmService.appendLog("cpu load 999% spike")
            root.check("out-of-range percent ignored", VmService.opProgress === -1)

            // 5. Blank lines never enter the log.
            root.reset()
            VmService.appendLog("")
            VmService.appendLog("   ")
            root.check("blank lines dropped", VmService.logLines.length === 0)

            // 6. The log is capped, so a chatty install cannot grow forever.
            root.reset()
            for (var i = 0; i < 320; i++) VmService.appendLog("line " + i)
            root.check("log is capped", VmService.logLines.length <= 301)
            root.check("log keeps the newest line",
                       VmService.logLines[VmService.logLines.length - 1] === "line 319")

            // 7. Malformed JSON falls through to the text path instead of throwing.
            root.reset()
            VmService.appendLog('{"type":"progress",BROKEN}')
            root.check("bad JSON is logged, not thrown", VmService.logLines.length === 1)

            if (root.fails.length === 0) {
                console.log("PASS  VmService: progress parsing, log cap, and malformed input handled")
            } else {
                console.log("FAIL  VmService: " + root.fails.length + " check(s) failed")
                for (const f of root.fails) console.log("        - " + f)
            }
            Qt.exit(root.fails.length === 0 ? 0 : 1)
        }
    }
}
