import QtQuick
import Quickshell
import Quickshell.Io

// Background download process worker for wallpaper files with real-time streaming progress.
Process {
    id: proc

    property string downloadUrl: ""
    property string downloadDest: ""
    property string downloadTitle: ""
    property real progress: 0
    property string speed: ""
    property string eta: ""
    property int downloadedBytes: 0
    property int totalBytes: 0
    property string status: "idle" // "idle" | "downloading" | "done" | "error"
    property string errorMsg: ""
    property string resultPath: ""

    signal progressUpdated(real pct, string spd, string timeRemaining, int downloaded, int total)
    signal downloadCompleted(string path)
    signal downloadFailed(string message)

    command: {
        var args = ["mujo", "wallpaper", "download-progress", downloadUrl]
        if (downloadDest) args.push(downloadDest)
        return args
    }

    stdout: SplitParser {
        splitMarker: "\n"
        onRead: function(line) {
            if (!line || line.trim() === "") return
            try {
                var ev = JSON.parse(line.trim())
                if (ev.type === "start") {
                    proc.status = "downloading"
                    proc.totalBytes = ev.total_bytes || 0
                } else if (ev.type === "progress") {
                    proc.status = "downloading"
                    proc.progress = ev.percent || 0
                    proc.speed = ev.speed || ""
                    proc.eta = ev.eta || ""
                    proc.downloadedBytes = ev.downloaded_bytes || 0
                    proc.totalBytes = ev.total_bytes || proc.totalBytes
                    proc.progressUpdated(proc.progress, proc.speed, proc.eta, proc.downloadedBytes, proc.totalBytes)
                } else if (ev.type === "done") {
                    proc.status = "done"
                    proc.progress = 100
                    proc.resultPath = ev.dest || proc.downloadDest
                    proc.downloadCompleted(proc.resultPath)
                } else if (ev.type === "error") {
                    proc.status = "error"
                    proc.errorMsg = ev.error || "Download failed"
                    proc.downloadFailed(proc.errorMsg)
                }
            } catch (e) {
                // Ignore parsing errors on non-json lines
            }
        }
    }

    onExited: function(code, exitStatus) {
        if (proc.status === "downloading") {
            if (code === 0 && proc.progress >= 99) {
                proc.status = "done"
                proc.downloadCompleted(proc.resultPath || proc.downloadDest)
            } else {
                proc.status = "error"
                proc.errorMsg = "Download was interrupted or terminated."
                proc.downloadFailed(proc.errorMsg)
            }
        }
    }
}
