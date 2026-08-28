pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../theme"

// Global Wallpaper Download Manager Service for Mujo (無常).
// Manages concurrent wallpaper downloads with real-time percentage, speed (MB/s),
// estimated time remaining (ETA), error handling, and background task queueing.
QtObject {
    id: dl

    // activeDownloads: map of key (url) -> {
    //   url: string,
    //   title: string,
    //   dest: string,
    //   progress: real (0..100),
    //   speed: string,
    //   eta: string,
    //   downloadedBytes: int,
    //   totalBytes: int,
    //   status: "downloading" | "done" | "error",
    //   errorMsg: string,
    //   worker: WallpaperDownloadWorker
    // }
    property var activeDownloads: ({})
    property int activeCount: 0
    property var completedUrls: ({})

    property Component _workerComp: Component {
        WallpaperDownloadWorker {}
    }

    signal downloadStarted(string url, string title)
    signal downloadProgress(string url, real percent, string speed, string eta)
    signal downloadFinished(string url, string destPath)
    signal downloadFailed(string url, string errorMsg)

    function startDownload(url, title, customDest, callback) {
        if (!url) return
        var key = url.trim()
        if (dl.isDownloading(key)) return

        var itemTitle = title || ("Wallpaper " + (key.split("/").pop() || "").split("?")[0])
        var worker = _workerComp.createObject(dl, {
            downloadUrl: key,
            downloadDest: customDest || "",
            downloadTitle: itemTitle
        })

        if (!worker) {
            if (callback) callback(false, "Failed to create download worker")
            return
        }

        var downloadsMap = JSON.parse(JSON.stringify(dl.activeDownloads))
        downloadsMap[key] = {
            url: key,
            title: itemTitle,
            dest: customDest || "",
            progress: 0.0,
            speed: "",
            eta: "",
            downloadedBytes: 0,
            totalBytes: 0,
            status: "downloading",
            errorMsg: ""
        }
        dl.activeDownloads = downloadsMap
        dl._recount()

        worker.progressUpdated.connect(function(pct, spd, timeRem, dlBytes, totBytes) {
            var m = JSON.parse(JSON.stringify(dl.activeDownloads))
            if (m[key]) {
                m[key].progress = pct
                m[key].speed = spd
                m[key].eta = timeRem
                m[key].downloadedBytes = dlBytes
                m[key].totalBytes = totBytes
                dl.activeDownloads = m
                dl.downloadProgress(key, pct, spd, timeRem)
            }
        })

        worker.downloadCompleted.connect(function(finalPath) {
            var m = JSON.parse(JSON.stringify(dl.activeDownloads))
            if (m[key]) {
                m[key].status = "done"
                m[key].progress = 100
                m[key].dest = finalPath
                dl.activeDownloads = m
                dl._recount()
            }
            var comp = JSON.parse(JSON.stringify(dl.completedUrls))
            comp[key] = finalPath
            dl.completedUrls = comp

            dl.downloadFinished(key, finalPath)
            if (callback) callback(true, finalPath)
            Notifications.notify(
                "Wallpaper Saved",
                itemTitle + " downloaded to your library.",
                "photo_library",
                "normal",
                { appName: "Wallpapers", transient: false }
            )
            // Auto clean worker
            worker.destroy(3000)
        })

        worker.downloadFailed.connect(function(err) {
            var m = JSON.parse(JSON.stringify(dl.activeDownloads))
            if (m[key]) {
                m[key].status = "error"
                m[key].errorMsg = err
                dl.activeDownloads = m
                dl._recount()
            }
            dl.downloadFailed(key, err)
            if (callback) callback(false, err)
            Notifications.notify(
                "Download Failed",
                "Could not download " + itemTitle + ": " + err,
                "error",
                "normal",
                { appName: "Wallpapers" }
            )
            worker.destroy(5000)
        })

        dl.downloadStarted(key, itemTitle)
        worker.running = true
    }

    function cancelDownload(url) {
        if (!url) return
        var key = url.trim()
        var m = JSON.parse(JSON.stringify(dl.activeDownloads))
        if (m[key]) {
            delete m[key]
            dl.activeDownloads = m
            dl._recount()
        }
    }

    function isDownloading(url) {
        if (!url) return false
        var key = url.trim()
        var info = dl.activeDownloads[key]
        return !!(info && info.status === "downloading")
    }

    function isCompleted(url) {
        if (!url) return false
        var key = url.trim()
        return !!(dl.completedUrls[key] || (dl.activeDownloads[key] && dl.activeDownloads[key].status === "done"))
    }

    function getDownload(url) {
        if (!url) return null
        return dl.activeDownloads[url.trim()] || null
    }

    function _recount() {
        var count = 0
        for (var k in dl.activeDownloads) {
            if (dl.activeDownloads[k] && dl.activeDownloads[k].status === "downloading") {
                count++
            }
        }
        dl.activeCount = count
    }
}
