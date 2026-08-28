pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../theme"

// Wallhaven API & Wallpaper Provider Service for Mujo (無常).
// Manages reactive search filters, pagination/infinite-scrolling, tag autocomplete,
// rate limit handling (429 cooldowns), wallpaper detail retrieval, and wallpaper downloads.
QtObject {
    id: wh

    // ── Search State ────────────────────────────────────────────────────────
    property ListModel resultsModel: ListModel { id: whListModel }
    property var meta: ({ "current_page": 1, "last_page": 1, "total": 0, "per_page": 24 })
    property bool loading: false
    property bool loadingMore: false
    property string error: ""
    property string errorType: ""      // "", "rate_limited", "unauthorized", "network_error", "empty"
    property int rateLimitCountdown: 0
    property string applyingUrl: ""
    property string savingUrl: ""
    property string lastAppliedPath: ""

    // ── Filter State ────────────────────────────────────────────────────────
    property string query: ""
    property var tags: []              // Array of string tags (e.g. ["cyberpunk", "anime"])
    property bool categoryGeneral: true
    property bool categoryAnime: true
    property bool categoryPeople: true
    property bool puritySfw: true
    property bool puritySketchy: false
    property bool purityNsfw: false
    property string sorting: "toplist"  // "toplist" | "hot" | "views" | "favorites" | "relevance" | "random" | "date_added"
    property string order: "desc"       // "desc" | "asc"
    property string topRange: "1M"      // "1d" | "3d" | "1w" | "1M" | "3M" | "6M" | "1y"
    property string atleast: ""         // "", "1920x1080", "2560x1440", "3840x2160", etc.
    property string ratios: ""          // "", "16x9", "16x10", "21x9", "32x9", "9x16", "1x1", "4x3"
    property string color: ""           // 6-char hex e.g. "660000" or ""

    readonly property string categories:
        (categoryGeneral ? "1" : "0") + (categoryAnime ? "1" : "0") + (categoryPeople ? "1" : "0")

    readonly property string purity:
        (puritySfw ? "1" : "0") + (puritySketchy ? "1" : "0") + (purityNsfw ? "1" : "0")

    readonly property int currentPage: meta && meta.current_page ? meta.current_page : 1
    readonly property int lastPage: meta && meta.last_page ? meta.last_page : 1
    readonly property int totalResults: meta && meta.total !== undefined ? meta.total : 0
    readonly property bool hasMore: currentPage < lastPage && !loading && !loadingMore

    readonly property int activeFiltersCount: {
        var count = 0
        if (categories !== "111") count++
        if (purity !== "100") count++
        if (sorting !== "toplist") count++
        if (order !== "desc") count++
        if (topRange !== "1M" && (sorting === "toplist" || sorting === "hot")) count++
        if (atleast !== "") count++
        if (ratios !== "") count++
        if (color !== "") count++
        if (tags.length > 0) count += tags.length
        return count
    }

    // ── Signals ─────────────────────────────────────────────────────────────
    signal searchCompleted()
    signal searchFailed(string message, string errorType)
    signal wallpaperApplied(string path)
    signal wallpaperSaved(string path)
    signal detailsLoaded(string id, var details)
    signal actionError(string action, string message)

    // ── Search Execution ────────────────────────────────────────────────────
    property int _searchSeq: 0
    property int _activeSearchSeq: 0

    function search(resetPage) {
        if (resetPage === undefined) resetPage = true

        if (rateLimitCountdown > 0) {
            wh.error = "Rate limit active. Please wait " + rateLimitCountdown + "s."
            wh.errorType = "rate_limited"
            return
        }

        var page = resetPage ? 1 : (wh.currentPage + 1)
        if (!resetPage && page > wh.lastPage) return

        if (resetPage) {
            wh.loading = true
            wh.error = ""
            wh.errorType = ""
        } else {
            wh.loadingMore = true
        }

        // Build composite query: text query + active tags
        var qParts = []
        var rawQ = wh.query.trim()
        if (rawQ !== "") qParts.push(rawQ)
        for (var i = 0; i < wh.tags.length; i++) {
            var t = wh.tags[i].trim()
            if (t !== "") {
                if (t.indexOf(" ") >= 0) qParts.push('"' + t + '"')
                else if (t.startsWith("#") || t.startsWith("+") || t.startsWith("-") || t.startsWith("@") || t.startsWith("id:") || t.startsWith("like:")) qParts.push(t)
                else qParts.push("+" + t)
            }
        }
        var fullQuery = qParts.join(" ")

        var payload = {
            q: fullQuery,
            page: page,
            categories: wh.categories,
            purity: wh.purity,
            sorting: wh.sorting,
            order: wh.order,
            topRange: wh.topRange,
            atleast: wh.atleast,
            ratios: wh.ratios,
            colors: wh.color
        }

        // Cancel previous search process if in flight
        if (searchProc.running) {
            searchProc.running = false
        }

        wh._activeSearchSeq = ++wh._searchSeq
        searchProc.currentSeq = wh._activeSearchSeq
        searchProc.isReset = resetPage
        searchProc.command = ["mujo", "wallpaper", "search", JSON.stringify(payload)]
        searchProc.running = true
    }

    function loadMore() {
        if (wh.hasMore && !wh.loading && !wh.loadingMore) {
            wh.search(false)
        }
    }

    function cancel() {
        if (searchProc.running) {
            searchProc.running = false
            wh.loading = false
            wh.loadingMore = false
        }
    }

    function resetFilters() {
        wh.query = ""
        wh.tags = []
        wh.categoryGeneral = true
        wh.categoryAnime = true
        wh.categoryPeople = true
        wh.puritySfw = true
        wh.puritySketchy = false
        wh.purityNsfw = false
        wh.sorting = "toplist"
        wh.order = "desc"
        wh.topRange = "1M"
        wh.atleast = ""
        wh.ratios = ""
        wh.color = ""
        wh.search(true)
    }

    function addTag(tag) {
        if (!tag) return
        var t = tag.trim().replace(/^#/, "")
        if (t === "") return
        var list = wh.tags.slice()
        for (var i = 0; i < list.length; i++) {
            if (list[i].toLowerCase() === t.toLowerCase()) return
        }
        list.push(t)
        wh.tags = list
        wh.search(true)
    }

    function removeTag(tag) {
        if (!tag) return
        var t = tag.trim().replace(/^#/, "").toLowerCase()
        var list = wh.tags.filter(function(item) {
            return item.toLowerCase() !== t
        })
        wh.tags = list
        wh.search(true)
    }

    function toggleTag(tag) {
        if (!tag) return
        var t = tag.trim().replace(/^#/, "")
        var exists = false
        for (var i = 0; i < wh.tags.length; i++) {
            if (wh.tags[i].toLowerCase() === t.toLowerCase()) {
                exists = true
                break
            }
        }
        if (exists) wh.removeTag(t)
        else wh.addTag(t)
    }

    function clearTags() {
        if (wh.tags.length === 0) return
        wh.tags = []
        wh.search(true)
    }

    function setColor(hex) {
        var cleanHex = hex ? hex.replace(/^#/, "").toLowerCase() : ""
        if (wh.color === cleanHex) wh.color = ""
        else wh.color = cleanHex
        wh.search(true)
    }

    // ── Search Process ──────────────────────────────────────────────────────
    property Process _searchProc: Process {
        id: searchProc
        property int currentSeq: 0
        property bool isReset: true
        stdout: StdioCollector {
            onStreamFinished: {
                if (searchProc.currentSeq !== wh._activeSearchSeq) return
                wh.loading = false
                wh.loadingMore = false

                try {
                    var resp = JSON.parse(this.text)
                    if (resp.error) {
                        wh.errorType = resp.error
                        wh.error = resp.message || "Wallhaven search failed (" + resp.error + ")"
                        if (resp.error === "rate_limited") {
                            wh.rateLimitCountdown = 30
                            rateLimitTimer.restart()
                        }
                        wh.searchFailed(wh.error, wh.errorType)
                        return
                    }

                    var newItems = resp.data || []
                    if (searchProc.isReset) {
                        whListModel.clear()
                        for (var i = 0; i < newItems.length; i++) {
                            whListModel.append({ "itemData": newItems[i] })
                        }
                    } else {
                        // Deduplicate by ID
                        var seen = {}
                        for (var k = 0; k < whListModel.count; k++) {
                            var entry = (whListModel.get(k) || {}).itemData
                            if (entry && entry.id) {
                                seen[entry.id] = true
                            }
                        }
                        for (var j = 0; j < newItems.length; j++) {
                            if (newItems[j] && newItems[j].id && !seen[newItems[j].id]) {
                                whListModel.append({ "itemData": newItems[j] })
                                seen[newItems[j].id] = true
                            }
                        }
                    }

                    wh.meta = resp.meta || {
                        "current_page": 1,
                        "last_page": 1,
                        "total": whListModel.count,
                        "per_page": 24
                    }

                    if (whListModel.count === 0) {
                        wh.error = "No wallpapers found matching your filters."
                        wh.errorType = "empty"
                    } else {
                        wh.error = ""
                        wh.errorType = ""
                    }

                    wh.searchCompleted()
                } catch (e) {
                    wh.error = "Unable to parse response from Wallhaven."
                    wh.errorType = "parse_error"
                    wh.searchFailed(wh.error, wh.errorType)
                }
            }
        }
    }

    // Rate Limit Cooldown Timer
    property Timer _rateLimitTimer: Timer {
        id: rateLimitTimer
        interval: 1000
        repeat: true
        running: wh.rateLimitCountdown > 0
        onTriggered: {
            if (wh.rateLimitCountdown > 0) {
                wh.rateLimitCountdown--
                if (wh.rateLimitCountdown === 0) {
                    if (wh.errorType === "rate_limited") {
                        wh.error = ""
                        wh.errorType = ""
                    }
                }
            }
        }
    }

    // ── Wallpaper Action: Apply Wallpaper ───────────────────────────────────
    property var _applyCallbacks: ({})
    function applyWallpaper(url, callback) {
        if (!url) return
        wh.applyingUrl = url
        var cbId = "" + Date.now() + Math.random()
        if (callback) wh._applyCallbacks[cbId] = callback

        applyProc.cbId = cbId
        applyProc.targetUrl = url
        applyProc.command = ["mujo", "wallpaper", "apply-url", url]
        applyProc.running = true
    }

    property Process _applyProc: Process {
        id: applyProc
        property string cbId: ""
        property string targetUrl: ""
        stdout: StdioCollector {
            onStreamFinished: {
                wh.applyingUrl = ""
                var dest = this.text.trim().replace(/^Applied:\s*/, "")
                if (dest !== "" && !dest.startsWith("Error")) {
                    wh.lastAppliedPath = dest
                    wh.wallpaperApplied(dest)
                    if (applyProc.cbId && wh._applyCallbacks[applyProc.cbId]) {
                        wh._applyCallbacks[applyProc.cbId](true, dest)
                        delete wh._applyCallbacks[applyProc.cbId]
                    }
                } else {
                    wh.actionError("apply", "Failed to apply wallpaper.")
                    if (applyProc.cbId && wh._applyCallbacks[applyProc.cbId]) {
                        wh._applyCallbacks[applyProc.cbId](false, "Failed to apply wallpaper")
                        delete wh._applyCallbacks[applyProc.cbId]
                    }
                }
            }
        }
    }

    // ── Wallpaper Action: Save Wallpaper ────────────────────────────────────
    function saveWallpaper(url, title, callback) {
        if (typeof title === "function") {
            callback = title
            title = ""
        }
        if (!url) return
        var itemTitle = title || ("Wallhaven #" + (url.split("-").pop() || "").split(".")[0])
        wh.savingUrl = url
        WallpaperDownloads.startDownload(url, itemTitle, "", function(ok, path) {
            wh.savingUrl = ""
            if (ok) {
                wh.wallpaperSaved(path)
                if (callback) callback(true, path)
            } else {
                wh.actionError("save", "Failed to download wallpaper: " + path)
                if (callback) callback(false, path)
            }
        })
    }

    // ── Wallpaper Details Fetcher ───────────────────────────────────────────
    property var _detailCallbacks: ({})
    property var _detailsCache: ({})

    function fetchDetails(id, callback) {
        if (!id) return
        if (wh._detailsCache[id]) {
            if (callback) Qt.callLater(function() { callback(wh._detailsCache[id]) })
            return
        }

        var cbId = id + "_" + Date.now()
        if (callback) wh._detailCallbacks[cbId] = callback

        detailsProc.cbId = cbId
        detailsProc.targetId = id
        detailsProc.command = ["mujo", "wallpaper", "details", id]
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
                        wh._detailsCache[detailsProc.targetId] = parsed.data
                        if (parsed.data.tags && parsed.data.tags.length > 0) {
                            wh.harvestTags(parsed.data.tags)
                        }
                        wh.detailsLoaded(detailsProc.targetId, parsed.data)
                        if (detailsProc.cbId && wh._detailCallbacks[detailsProc.cbId]) {
                            wh._detailCallbacks[detailsProc.cbId](parsed.data)
                            delete wh._detailCallbacks[detailsProc.cbId]
                        }
                    }
                } catch (e) {
                    /* ignore detail failure */
                }
            }
        }
    }

    // ── Dynamic & Curated Tag Autocomplete Engine ───────────────────────────
    property var _dynamicTags: ({})

    function harvestTags(tagList) {
        if (!tagList || !tagList.length) return
        var dyn = JSON.parse(JSON.stringify(wh._dynamicTags))
        var changed = false
        for (var i = 0; i < tagList.length; i++) {
            var item = tagList[i]
            var name = typeof item === "string" ? item : (item.name || "")
            if (!name) continue
            var key = name.toLowerCase()
            if (!dyn[key]) {
                dyn[key] = {
                    name: name,
                    category: (typeof item === "object" && item.category) ? item.category : "General",
                    purity: (typeof item === "object" && item.purity) ? item.purity : "sfw",
                    alias: (typeof item === "object" && item.alias) ? item.alias : "",
                    id: (typeof item === "object" && item.id) ? item.id : 0
                }
                changed = true
            }
        }
        if (changed) wh._dynamicTags = dyn
    }

    // Comprehensive curated catalog of popular Wallhaven tags
    readonly property var curatedTags: [
        // Anime & Manga
        { name: "anime", category: "Anime & Manga", purity: "sfw", alias: "japanese animation, manga, 2d" },
        { name: "anime girls", category: "Anime & Manga", purity: "sfw", alias: "anime girl, waifu, manga girl" },
        { name: "anime boys", category: "Anime & Manga", purity: "sfw", alias: "anime boy, husbando" },
        { name: "Cyberpunk: Edgerunners", category: "Anime & Manga", purity: "sfw", alias: "edgerunners, lucy, david martinez, rebecca" },
        { name: "Genshin Impact", category: "Anime & Manga", purity: "sfw", alias: "genshin, hoyoverse, teyvat, raiden shogun" },
        { name: "Honkai: Star Rail", category: "Anime & Manga", purity: "sfw", alias: "hsr, star rail, kafka, firefly, acheron" },
        { name: "Studio Ghibli", category: "Anime & Manga", purity: "sfw", alias: "ghibli, spirited away, totoro, mononoke, howls moving castle" },
        { name: "Makoto Shinkai", category: "Anime & Manga", purity: "sfw", alias: "your name, kimi no na wa, weathering with you, suzume" },
        { name: "Neon Genesis Evangelion", category: "Anime & Manga", purity: "sfw", alias: "evangelion, eva, asuka, rei ayanami, shinji" },
        { name: "Fate/stay night", category: "Anime & Manga", purity: "sfw", alias: "fate, fgo, saber, artoria, archer, rin tohsaka" },
        { name: "Demon Slayer: Kimetsu no Yaiba", category: "Anime & Manga", purity: "sfw", alias: "kimetsu no yaiba, nezuko, tanjiro" },
        { name: "Jujutsu Kaisen", category: "Anime & Manga", purity: "sfw", alias: "jjk, gojo satoru, megumi, itadori, sukuna" },
        { name: "Attack on Titan", category: "Anime & Manga", purity: "sfw", alias: "shingeki no kyojin, aot, levi, eren, mikasa" },
        { name: "Chainsaw Man", category: "Anime & Manga", purity: "sfw", alias: "makima, power, denji, csm" },
        { name: "Frieren: Beyond Journey's End", category: "Anime & Manga", purity: "sfw", alias: "sousou no frieren, frieren, fern" },
        { name: "Spy x Family", category: "Anime & Manga", purity: "sfw", alias: "anya forger, yor forger, loid" },
        { name: "Vocaloid", category: "Anime & Manga", purity: "sfw", alias: "hatsune miku, miku, luka, rin, len" },
        { name: "Hololive", category: "Anime & Manga", purity: "sfw", alias: "vtuber, gawr gura, pekora, suisei, calliope" },
        { name: "NieR:Automata", category: "Anime & Manga", purity: "sfw", alias: "2b, 9s, a2, yorha, nier" },

        // Art, Aesthetics & Styles
        { name: "digital art", category: "Art & Design", purity: "sfw", alias: "artwork, illustration, digital painting, cgi" },
        { name: "concept art", category: "Art & Design", purity: "sfw", alias: "matte painting, environment art, visual development" },
        { name: "pixel art", category: "Art & Design", purity: "sfw", alias: "8-bit, 16-bit, retro gaming, pixelated" },
        { name: "minimalism", category: "Art & Design", purity: "sfw", alias: "minimal, simple, clean, flat, minimalist" },
        { name: "synthwave", category: "Art & Design", purity: "sfw", alias: "retrowave, vaporwave, outrun, 80s aesthetic, neon grid" },
        { name: "cyberpunk", category: "Art & Design", purity: "sfw", alias: "futuristic, neon, high tech low life, cyber" },
        { name: "sci-fi", category: "Art & Design", purity: "sfw", alias: "science fiction, futuristic, space, technology" },
        { name: "fantasy", category: "Art & Design", purity: "sfw", alias: "magic, medieval, mythical, dragons, castle" },
        { name: "steampunk", category: "Art & Design", purity: "sfw", alias: "victorian, gears, brass, clockwork, industrial" },
        { name: "solarpunk", category: "Art & Design", purity: "sfw", alias: "green future, eco, plants, bright sci-fi" },
        { name: "isometric", category: "Art & Design", purity: "sfw", alias: "isometric room, 3d isometric, diorama" },
        { name: "abstract", category: "Art & Design", purity: "sfw", alias: "geometry, patterns, shapes, generative art" },
        { name: "lo-fi", category: "Art & Design", purity: "sfw", alias: "lofi, chill, cozy, study, relaxing, bedroom" },
        { name: "dark background", category: "Art & Design", purity: "sfw", alias: "dark, amoled, black, pitch black, moody" },
        { name: "surrealism", category: "Art & Design", purity: "sfw", alias: "dreamlike, bizarre, floating islands, cosmic" },
        { name: "3D", category: "Art & Design", purity: "sfw", alias: "blender, render, octane, cinema 4d, unreal engine" },
        { name: "vector art", category: "Art & Design", purity: "sfw", alias: "flat design, illustration, vector" },

        // Nature & Landscapes
        { name: "landscape", category: "Nature", purity: "sfw", alias: "scenery, outdoors, vista, panoramic" },
        { name: "mountains", category: "Nature", purity: "sfw", alias: "peaks, alps, mount fuji, snow mountains, cliffs" },
        { name: "forest", category: "Nature", purity: "sfw", alias: "trees, woods, jungle, pine forest, misty forest" },
        { name: "lake", category: "Nature", purity: "sfw", alias: "water reflection, calm lake, pond, loch" },
        { name: "ocean", category: "Nature", purity: "sfw", alias: "sea, waves, beach, coast, tropical, underwater" },
        { name: "sunset", category: "Nature", purity: "sfw", alias: "sunrise, dusk, dawn, golden hour, evening sky" },
        { name: "night", category: "Nature", purity: "sfw", alias: "dark, moonlight, midnight, evening" },
        { name: "starry sky", category: "Nature", purity: "sfw", alias: "stars, milky way, night sky, constellations, aurora" },
        { name: "northern lights", category: "Nature", purity: "sfw", alias: "aurora borealis, polar lights, green sky" },
        { name: "clouds", category: "Nature", purity: "sfw", alias: "cloudscape, sky, fluffy clouds, dramatic sky" },
        { name: "rain", category: "Nature", purity: "sfw", alias: "rainy, rain drops, storm, wet street, puddle" },
        { name: "winter", category: "Nature", purity: "sfw", alias: "snow, ice, blizzard, frozen, frosty" },
        { name: "autumn", category: "Nature", purity: "sfw", alias: "fall, autumn leaves, red trees, orange foliage" },
        { name: "spring", category: "Nature", purity: "sfw", alias: "cherry blossoms, sakura, blooming flowers, pink trees" },
        { name: "waterfall", category: "Nature", purity: "sfw", alias: "cascades, river, rapids, stream" },
        { name: "desert", category: "Nature", purity: "sfw", alias: "sand dunes, sahara, canyon, rocks" },
        { name: "flowers", category: "Nature", purity: "sfw", alias: "roses, sunflowers, garden, floral, petals" },

        // City & Architecture
        { name: "cityscape", category: "Architecture", purity: "sfw", alias: "city, skyline, downtown, metropolis" },
        { name: "cyberpunk city", category: "Architecture", purity: "sfw", alias: "neo tokyo, futuristic city, neon signs, skyscrapers" },
        { name: "Tokyo", category: "Architecture", purity: "sfw", alias: "japan, shibuya, shinjuku, akihabara, japanese streets" },
        { name: "neon", category: "Architecture", purity: "sfw", alias: "neon glow, glowing signs, vibrant lights" },
        { name: "street", category: "Architecture", purity: "sfw", alias: "alley, road, crosswalk, sidewalk, storefront" },
        { name: "bridge", category: "Architecture", purity: "sfw", alias: "golden gate, suspension bridge, overpass" },
        { name: "interior", category: "Architecture", purity: "sfw", alias: "room, bedroom, desk setup, cozy room, living room" },
        { name: "balcony", category: "Architecture", purity: "sfw", alias: "terrace, window view, overlooking city" },
        { name: "abandoned", category: "Architecture", purity: "sfw", alias: "ruins, overgrown, post-apocalyptic, decay" },
        { name: "castle", category: "Architecture", purity: "sfw", alias: "palace, fortress, fantasy castle, stronghold" },

        // Sci-Fi & Space
        { name: "space", category: "Sci-Fi", purity: "sfw", alias: "outer space, cosmos, universe, deep space" },
        { name: "galaxy", category: "Sci-Fi", purity: "sfw", alias: "nebula, spiral galaxy, cosmic dust" },
        { name: "planet", category: "Sci-Fi", purity: "sfw", alias: "earth, moon, mars, saturn, ringed planet" },
        { name: "spaceship", category: "Sci-Fi", purity: "sfw", alias: "starship, spacecraft, space station, fleet" },
        { name: "astronaut", category: "Sci-Fi", purity: "sfw", alias: "cosmonaut, space suit, spacewalk" },
        { name: "robot", category: "Sci-Fi", purity: "sfw", alias: "cyborg, android, mech, mecha, automaton, gundam" },

        // Vehicles & Tech
        { name: "car", category: "Vehicles", purity: "sfw", alias: "supercar, sports car, automotive, jdm, porsche, ferrari" },
        { name: "motorcycle", category: "Vehicles", purity: "sfw", alias: "motorbike, biker, cafe racer, superbike" },
        { name: "aircraft", category: "Vehicles", purity: "sfw", alias: "airplane, jet fighter, aviation, cockpit" },

        // Characters & People
        { name: "women", category: "People", purity: "sfw", alias: "woman, female, girl, lady, model, portrait" },
        { name: "samurai", category: "People", purity: "sfw", alias: "katana, ronin, warrior, ninja" },
        { name: "warrior", category: "People", purity: "sfw", alias: "knight, armor, sword, shield, fighter" },
        { name: "cosplay", category: "People", purity: "sfw", alias: "costume, dressed up, convention" },

        // Animals
        { name: "animals", category: "Animals", purity: "sfw", alias: "wildlife, pets, fauna, creature" },
        { name: "cat", category: "Animals", purity: "sfw", alias: "kitten, feline, kitty, black cat" },
        { name: "dog", category: "Animals", purity: "sfw", alias: "puppy, canine, wolf, fox" },
        { name: "wolf", category: "Animals", purity: "sfw", alias: "howling wolf, white wolf, pack" },
        { name: "fox", category: "Animals", purity: "sfw", alias: "kitsune, red fox, arctic fox" },
        { name: "birds", category: "Animals", purity: "sfw", alias: "eagle, owl, sparrow, raven, feathers" },
        { name: "dragon", category: "Animals", purity: "sfw", alias: "mythical dragon, wyvern, fire dragon" }
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
                purity: tagObj.purity || "sfw",
                alias: tagObj.alias || "",
                score: score
            })
        }

        // 1. Check curated tags
        for (var i = 0; i < wh.curatedTags.length; i++) {
            var item = wh.curatedTags[i]
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

        // 2. Check dynamically harvested tags
        for (var dKey in wh._dynamicTags) {
            var dItem = wh._dynamicTags[dKey]
            var dNameLow = dItem.name.toLowerCase()
            var dAliasLow = (dItem.alias || "").toLowerCase()

            if (dNameLow === p) {
                addCandidate(dItem, 95)
            } else if (dNameLow.startsWith(p)) {
                addCandidate(dItem, 75 - (dNameLow.length - p.length))
            } else if (dNameLow.indexOf(" " + p) >= 0) {
                addCandidate(dItem, 55)
            } else if (dNameLow.indexOf(p) >= 0) {
                addCandidate(dItem, 35)
            } else if (dAliasLow.indexOf(p) >= 0) {
                addCandidate(dItem, 25)
            }
        }

        // Sort by score descending
        matches.sort(function(a, b) { return b.score - a.score })
        return matches.slice(0, lim)
    }

    Component.onCompleted: {
        // Initial search to prefill popular wallpapers
        wh.search(true)
    }
}
