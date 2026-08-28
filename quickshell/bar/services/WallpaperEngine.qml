pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../theme"

// Wallpaper Engine & Steam Workshop Provider Service for Mujo (無常).
// Manages Steam Workshop exploration (App ID: 431960), purity filters (SFW, Sketchy, NSFW),
// Steam client & library discovery, local project scanning, pagination/infinite-scrolling,
// tag autocomplete, metadata inspection, live wallpaper application, and engine settings.
QtObject {
    id: we

    // ── Search & Filter State ───────────────────────────────────────────────
    property ListModel resultsModel: ListModel { id: weResultsModel }
    property ListModel installedModel: ListModel { id: weInstalledModel }
    property var meta: ({ "current_page": 1, "last_page": 1, "total": 0, "per_page": 30 })

    property bool loading: false
    property bool loadingMore: false
    property bool loadingInstalled: false
    property string error: ""
    property string errorType: ""      // "", "rate_limited", "network_error", "empty"

    property string applyingId: ""
    property string downloadingId: ""
    property string lastAppliedPath: ""

    property string query: ""
    property var tags: []              // Array of string tags (e.g. ["Cyberpunk", "Anime"])
    property string selectedType: "all" // "all" | "scene" | "video" | "web"
    property string sorting: "trend"   // "trend" | "mostrecent" | "toprated" | "subscribed" | "relevance"
    property string activeSource: "workshop" // "workshop" | "installed"

    // ── Content Purity / Maturity Filters ───────────────────────────────────
    property bool puritySfw: true         // Everyone
    property bool puritySketchy: true     // Questionable
    property bool purityNsfw: false       // Mature / 18+
    property bool blurNsfw: true          // Blur NSFW thumbnails in browser until hovered

    // ── Steam Client & Library Integration ──────────────────────────────────
    property bool steamInstalled: false
    property bool steamRunning: false
    property string steamType: ""         // "native" | "flatpak" | "none"
    property var steamLibraries: []
    property int totalInstalledCount: 0

    readonly property int currentPage: meta && meta.current_page ? meta.current_page : 1
    readonly property int lastPage: meta && meta.last_page ? meta.last_page : 1
    readonly property int totalResults: meta && meta.total !== undefined ? meta.total : 0
    readonly property bool hasMore: currentPage < lastPage && !loading && !loadingMore

    readonly property int activeFiltersCount: {
        var count = 0
        if (selectedType !== "all") count++
        if (sorting !== "trend") count++
        if (tags.length > 0) count += tags.length
        if (!puritySfw || !puritySketchy || purityNsfw) count++
        return count
    }

    // ── Engine Performance Options (synced with wallpaper.json) ────────────
    property int targetFps: 30
    property int soundVolume: 50
    property bool isSilent: true
    property bool autoMute: true

    // ── Signals ─────────────────────────────────────────────────────────────
    signal searchCompleted()
    signal searchFailed(string message, string errorType)
    signal installedLoaded()
    signal steamStatusUpdated()
    signal wallpaperApplied(string path)
    signal wallpaperDownloaded(string id)
    signal detailsLoaded(string id, var details)
    signal actionError(string action, string message)

    // ── Search Execution ────────────────────────────────────────────────────
    property int _searchSeq: 0
    property int _activeSearchSeq: 0

    function search(resetPage) {
        if (resetPage === undefined) resetPage = true

        var page = resetPage ? 1 : (we.currentPage + 1)
        if (!resetPage && page > we.lastPage) return

        if (resetPage) {
            we.loading = true
            we.error = ""
            we.errorType = ""
        } else {
            we.loadingMore = true
        }

        var payload = {
            q: we.query.trim(),
            page: page,
            type: we.selectedType,
            sort: we.sorting,
            tags: we.tags,
            purity_sfw: we.puritySfw,
            purity_sketchy: we.puritySketchy,
            purity_nsfw: we.purityNsfw
        }

        if (searchProc.running) {
            searchProc.running = false
        }

        we._activeSearchSeq = ++we._searchSeq
        searchProc.currentSeq = we._activeSearchSeq
        searchProc.isReset = resetPage
        searchProc.command = ["mujo", "wallpaper", "engine", "search", JSON.stringify(payload)]
        searchProc.running = true
    }

    function loadMore() {
        if (we.hasMore && !we.loading && !we.loadingMore) {
            we.search(false)
        }
    }

    function cancel() {
        if (searchProc.running) {
            searchProc.running = false
            we.loading = false
            we.loadingMore = false
        }
    }

    function resetFilters() {
        we.query = ""
        we.tags = []
        we.selectedType = "all"
        we.sorting = "trend"
        we.puritySfw = true
        we.puritySketchy = true
        we.purityNsfw = false
        we.search(true)
    }

    function addTag(tag) {
        if (!tag) return
        var t = tag.trim().replace(/^#/, "")
        if (t === "") return
        var list = we.tags.slice()
        for (var i = 0; i < list.length; i++) {
            if (list[i].toLowerCase() === t.toLowerCase()) return
        }
        list.push(t)
        we.tags = list
        we.search(true)
    }

    function removeTag(tag) {
        if (!tag) return
        var t = tag.trim().replace(/^#/, "").toLowerCase()
        var list = we.tags.filter(function(item) {
            return item.toLowerCase() !== t
        })
        we.tags = list
        we.search(true)
    }

    function toggleTag(tag) {
        if (!tag) return
        var t = tag.trim().replace(/^#/, "")
        var exists = false
        for (var i = 0; i < we.tags.length; i++) {
            if (we.tags[i].toLowerCase() === t.toLowerCase()) {
                exists = true
                break
            }
        }
        if (exists) we.removeTag(t)
        else we.addTag(t)
    }

    function clearTags() {
        if (we.tags.length === 0) return
        we.tags = []
        we.search(true)
    }

    // ── Search Process ──────────────────────────────────────────────────────
    property Process _searchProc: Process {
        id: searchProc
        property int currentSeq: 0
        property bool isReset: true
        stdout: StdioCollector {
            onStreamFinished: {
                if (searchProc.currentSeq !== we._activeSearchSeq) return
                we.loading = false
                we.loadingMore = false

                try {
                    var resp = JSON.parse(this.text)
                    if (resp.error) {
                        we.errorType = resp.error
                        we.error = resp.message || "Steam Workshop search failed."
                        we.searchFailed(we.error, we.errorType)
                        return
                    }

                    var newItems = resp.data || []
                    if (searchProc.isReset) {
                        weResultsModel.clear()
                        for (var i = 0; i < newItems.length; i++) {
                            weResultsModel.append({ "itemData": newItems[i] })
                        }
                    } else {
                        var seen = {}
                        for (var k = 0; k < weResultsModel.count; k++) {
                            var entry = (weResultsModel.get(k) || {}).itemData
                            if (entry && entry.id) {
                                seen[entry.id] = true
                            }
                        }
                        for (var j = 0; j < newItems.length; j++) {
                            if (newItems[j] && newItems[j].id && !seen[newItems[j].id]) {
                                weResultsModel.append({ "itemData": newItems[j] })
                                seen[newItems[j].id] = true
                            }
                        }
                    }

                    we.meta = resp.meta || {
                        "current_page": 1,
                        "last_page": 1,
                        "total": weResultsModel.count,
                        "per_page": 30
                    }

                    if (weResultsModel.count === 0) {
                        we.error = "No Wallpaper Engine wallpapers found matching your filters."
                        we.errorType = "empty"
                    } else {
                        we.error = ""
                        we.errorType = ""
                    }

                    we.searchCompleted()
                } catch (e) {
                    we.error = "Unable to parse response from Steam Workshop."
                    we.errorType = "parse_error"
                    we.searchFailed(we.error, we.errorType)
                }
            }
        }
    }

    // ── Local Installed Projects Scanner ────────────────────────────────────
    function refreshInstalled() {
        we.loadingInstalled = true
        listInstalledProc.running = true
        checkSteamStatus()
    }

    property Process _listInstalledProc: Process {
        id: listInstalledProc
        command: ["mujo", "wallpaper", "engine", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                we.loadingInstalled = false
                try {
                    var list = JSON.parse(this.text) || []
                    weInstalledModel.clear()
                    for (var i = 0; i < list.length; i++) {
                        weInstalledModel.append({ "itemData": list[i] })
                    }
                    we.totalInstalledCount = list.length
                    we.installedLoaded()
                } catch (e) {
                    weInstalledModel.clear()
                }
            }
        }
    }

    // ── Steam Status Query ──────────────────────────────────────────────────
    function checkSteamStatus() {
        steamStatusProc.running = true
    }

    property Process _steamStatusProc: Process {
        id: steamStatusProc
        command: ["mujo", "wallpaper", "engine", "steam-status"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var res = JSON.parse(this.text)
                    we.steamInstalled = !!res.installed
                    we.steamRunning = !!res.running
                    we.steamType = res.type || "none"
                    we.steamLibraries = res.libraries || []
                    if (res.total_wallpapers !== undefined) {
                        we.totalInstalledCount = res.total_wallpapers
                    }
                    we.steamStatusUpdated()
                } catch (e) { /* ignore */ }
            }
        }
    }

    // ── Wallpaper Action: Apply Wallpaper ───────────────────────────────────
    property var _applyCallbacks: ({})
    function applyWallpaper(item, monitor, callback) {
        if (!item) return
        var target = typeof item === "string" ? item : (item.path || item.id || "")
        if (!target) return

        we.applyingId = item.id || target
        var cbId = "" + Date.now() + Math.random()
        if (callback) we._applyCallbacks[cbId] = callback

        applyProc.cbId = cbId
        applyProc.target = target
        var cmd = ["mujo", "wallpaper", "engine", "apply", target]
        if (monitor) {
            cmd.push("--monitor")
            cmd.push(monitor)
        }
        applyProc.command = cmd
        applyProc.running = true
    }

    property Process _applyProc: Process {
        id: applyProc
        property string cbId: ""
        property string target: ""
        stdout: StdioCollector {
            onStreamFinished: {
                we.applyingId = ""
                try {
                    var resp = JSON.parse(this.text)
                    if (resp.success) {
                        we.lastAppliedPath = applyProc.target
                        we.wallpaperApplied(applyProc.target)
                        if (applyProc.cbId && we._applyCallbacks[applyProc.cbId]) {
                            we._applyCallbacks[applyProc.cbId](true, applyProc.target)
                            delete we._applyCallbacks[applyProc.cbId]
                        }
                        return
                    }
                } catch (e) { /* ignore */ }

                we.actionError("apply", "Failed to apply wallpaper engine project.")
                if (applyProc.cbId && we._applyCallbacks[applyProc.cbId]) {
                    we._applyCallbacks[applyProc.cbId](false, "Failed to apply wallpaper")
                    delete we._applyCallbacks[applyProc.cbId]
                }
            }
        }
    }

    // ── Wallpaper Action: Subscribe in Steam Client ─────────────────────────
    property var _subscribeCallbacks: ({})
    function subscribeWallpaper(id, callback) {
        if (!id) return
        we.downloadingId = id
        var cbId = "" + Date.now() + Math.random()
        if (callback) we._subscribeCallbacks[cbId] = callback

        subscribeProc.cbId = cbId
        subscribeProc.targetId = id
        subscribeProc.command = ["mujo", "wallpaper", "engine", "subscribe", id]
        subscribeProc.running = true
    }

    property Process _subscribeProc: Process {
        id: subscribeProc
        property string cbId: ""
        property string targetId: ""
        stdout: StdioCollector {
            onStreamFinished: {
                we.downloadingId = ""
                try {
                    var resp = JSON.parse(this.text)
                    if (resp.success) {
                        we.wallpaperDownloaded(subscribeProc.targetId)
                        if (subscribeProc.cbId && we._subscribeCallbacks[subscribeProc.cbId]) {
                            we._subscribeCallbacks[subscribeProc.cbId](true, resp)
                            delete we._subscribeCallbacks[subscribeProc.cbId]
                        }
                        return
                    }
                } catch (e) { /* ignore */ }

                we.actionError("subscribe", "Failed to open Steam subscription.")
                if (subscribeProc.cbId && we._subscribeCallbacks[subscribeProc.cbId]) {
                    we._subscribeCallbacks[subscribeProc.cbId](false, "Subscription failed")
                    delete we._subscribeCallbacks[subscribeProc.cbId]
                }
            }
        }
    }

    function downloadWallpaper(item, callback) {
        if (!item) return
        var id = typeof item === "string" ? item : (item.id || "")
        var title = typeof item === "object" ? (item.title || "") : ("Workshop #" + id)
        var previewUrl = typeof item === "object" ? (item.preview || "") : ""
        if (previewUrl && previewUrl.startsWith("http")) {
            WallpaperDownloads.startDownload(previewUrl, title, "", function(ok, path) {
                if (ok) we.wallpaperDownloaded(id)
                if (callback) callback(ok, path)
            })
        } else {
            subscribeWallpaper(id, callback)
        }
    }

    // ── Wallpaper Details Fetcher ───────────────────────────────────────────
    property var _detailCallbacks: ({})
    property var _detailsCache: ({})

    function fetchDetails(id_or_path, callback) {
        if (!id_or_path) return
        if (we._detailsCache[id_or_path]) {
            if (callback) Qt.callLater(function() { callback(we._detailsCache[id_or_path]) })
            return
        }

        var cbId = id_or_path + "_" + Date.now()
        if (callback) we._detailCallbacks[cbId] = callback

        detailsProc.cbId = cbId
        detailsProc.targetId = id_or_path
        detailsProc.command = ["mujo", "wallpaper", "engine", "details", id_or_path]
        detailsProc.running = true
    }

    property Process _detailsProc: Process {
        id: detailsProc
        property string cbId: ""
        property string targetId: ""
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var parsed = JSON.parse(this.text)
                    if (parsed.data) {
                        we._detailsCache[detailsProc.targetId] = parsed.data
                        if (parsed.data.tags && parsed.data.tags.length > 0) {
                            we.harvestTags(parsed.data.tags)
                        }
                        we.detailsLoaded(detailsProc.targetId, parsed.data)
                        if (detailsProc.cbId && we._detailCallbacks[detailsProc.cbId]) {
                            we._detailCallbacks[detailsProc.cbId](parsed.data)
                            delete we._detailCallbacks[detailsProc.cbId]
                        }
                    }
                } catch (e) {
                    /* ignore */
                }
            }
        }
    }

    function openInSteam(id) {
        if (!id) return
        Quickshell.execDetached(["xdg-open", "steam://url/CommunityFilePage/" + id])
    }

    // ── Performance Config Updater ──────────────────────────────────────────
    function setEngineConfig(fps, volume, silent, automute) {
        var args = ["mujo", "wallpaper", "engine", "config"]
        if (fps !== undefined) { args.push("--fps"); args.push(String(fps)) }
        if (volume !== undefined) { args.push("--volume"); args.push(String(volume)) }
        if (silent !== undefined) { args.push("--silent"); args.push(silent ? "true" : "false") }
        if (automute !== undefined) { args.push("--automute"); args.push(automute ? "true" : "false") }
        Quickshell.execDetached(args)
    }

    // ── Tag Autocomplete Engine ─────────────────────────────────────────────
    property var _dynamicTags: ({})

    function harvestTags(tagList) {
        if (!tagList || !tagList.length) return
        var dyn = JSON.parse(JSON.stringify(we._dynamicTags))
        var changed = false
        for (var i = 0; i < tagList.length; i++) {
            var item = tagList[i]
            var name = typeof item === "string" ? item : (item.name || "")
            if (!name) continue
            var key = name.toLowerCase()
            if (!dyn[key]) {
                dyn[key] = { name: name, category: "Workshop" }
                changed = true
            }
        }
        if (changed) we._dynamicTags = dyn
    }

    readonly property var curatedTags: [
        { name: "Anime", category: "Genre", alias: "anime girls, manga, japanese" },
        { name: "Cyberpunk", category: "Style", alias: "neon, futuristic, sci-fi, edgerunners" },
        { name: "Game", category: "Genre", alias: "gaming, rpg, fps, genshin, honkai, nintendo" },
        { name: "Relaxing", category: "Mood", alias: "chill, peaceful, calm, lo-fi, study" },
        { name: "Sci-Fi", category: "Genre", alias: "space, galaxy, planet, spaceship, stars" },
        { name: "Nature", category: "Atmosphere", alias: "landscape, mountains, ocean, forest, rain" },
        { name: "Abstract", category: "Style", alias: "geometry, minimal, dark, 3d, shapes" },
        { name: "Pixel Art", category: "Style", alias: "8-bit, 16-bit, retro, pixel, nostalgic" },
        { name: "Retro / Synthwave", category: "Style", alias: "vaporwave, outrun, 80s, neon grid" },
        { name: "Music / Visualizer", category: "Audio", alias: "audio responsive, audio visualizer, sound" },
        { name: "Fantasy", category: "Genre", alias: "magic, medieval, castle, dragons, mystical" },
        { name: "CGI / 3D", category: "Technology", alias: "unreal engine, blender, render, octane" },
        { name: "4K UHD", category: "Resolution", alias: "ultra hd, high resolution, 3840x2160" },
        { name: "Ultrawide", category: "Resolution", alias: "21x9, 32x9, panoramic, dual monitor" },
        { name: "Vehicles", category: "Objects", alias: "cars, supercars, automotive, aircraft" },
        { name: "Minimalism", category: "Style", alias: "minimal, simple, clean, dark background" }
    ]

    function suggestTags(prefix, limit) {
        if (!prefix) return []
        var p = prefix.trim().toLowerCase().replace(/^#/, "").replace(/^\+/, "")
        if (p === "") return []
        var lim = limit || 8

        var matches = []
        var seen = {}

        function addCandidate(tagObj, score) {
            var key = tagObj.name.toLowerCase()
            if (seen[key]) return
            seen[key] = true
            matches.push({
                name: tagObj.name,
                category: tagObj.category || "General",
                alias: tagObj.alias || "",
                score: score
            })
        }

        for (var i = 0; i < we.curatedTags.length; i++) {
            var item = we.curatedTags[i]
            var nameLow = item.name.toLowerCase()
            var aliasLow = (item.alias || "").toLowerCase()

            if (nameLow === p) {
                addCandidate(item, 100)
            } else if (nameLow.startsWith(p)) {
                addCandidate(item, 80 - (nameLow.length - p.length))
            } else if (nameLow.indexOf(" " + p) >= 0) {
                addCandidate(item, 60)
            } else if (nameLow.indexOf(p) >= 0) {
                addCandidate(item, 40)
            } else if (aliasLow.indexOf(p) >= 0) {
                addCandidate(item, 30)
            }
        }

        for (var dKey in we._dynamicTags) {
            var dItem = we._dynamicTags[dKey]
            var dNameLow = dItem.name.toLowerCase()
            if (dNameLow === p) {
                addCandidate(dItem, 95)
            } else if (dNameLow.startsWith(p)) {
                addCandidate(dItem, 75 - (dNameLow.length - p.length))
            } else if (dNameLow.indexOf(p) >= 0) {
                addCandidate(dItem, 35)
            }
        }

        matches.sort(function(a, b) { return b.score - a.score })
        return matches.slice(0, lim)
    }

    Component.onCompleted: {
        we.checkSteamStatus()
        we.refreshInstalled()
        we.search(true)
    }
}
