import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import Quickshell
import Quickshell.Io
import "../../theme"
import "../../components"
import "../../services"

// The settings app: a sidebar tree on the left, one category page on the right.
// This file owns the state and the routing; the sidebar, its rows and the
// search results are their own components.
//
// Navigation is three levels and stops there: a sidebar category, a
// sub-category under it, then the sections and rows on the page. Sub-categories
// are the section ids the pages already own, so the rail drives the page
// through the same route()/revealCard() path the omni-search uses — one
// navigation model, not two.
//
// Categories are data:
//   { key, label, icon, brand, subtitle, page: Component, keys: [...],
//     subs: [{ id, label, icon }] }
//
// `keys` are the routing aliases a category answers to, so every panel key that
// existed before the five-category consolidation still resolves — `mujo
// settings wallpaper`, `mujo settings dnd`, and the omni-search all enter here.
Item {
    id: layout

    property var categories: []
    property var searchIndex: []      // [{ title, desc, cat, key, card }]

    property string current: categories.length > 0 ? categories[0].key : ""
    readonly property int currentIndex: {
        for (var i = 0; i < categories.length; i++)
            if (categories[i].key === current) return i
        return 0
    }
    readonly property var currentCategory: categories.length > 0 ? categories[currentIndex] : ({ label: "", icon: "" })

    // ── Sidebar tree ─────────────────────────────────────────────────────────
    // Which category has its sub-categories open. An accordion, not independent
    // disclosures: at five categories, several open at once turns the rail into
    // a wall and buries the selected row.
    property string expandedKey: ""

    // The one place `current` changes, so selecting a category always opens it.
    function select(key) {
        layout.current = key
        layout.expandedKey = key
    }
    Component.onCompleted: layout.expandedKey = layout.current

    // The sub-category the live page is showing. Pages own their own `tab`, so
    // this follows whether the change came from the rail, from omni-search, or
    // from `mujo settings <key>`.
    readonly property string currentTab: (layout.currentPage && layout.currentPage.tab !== undefined)
        ? layout.currentPage.tab : ""

    // The rail flattened to one list — parents, plus the children of whichever
    // parent is open. One Repeater over this keeps arrow-key navigation to a
    // single index and lets the highlight live on the row that owns it.
    readonly property var railRows: {
        var rows = []
        for (var i = 0; i < layout.categories.length; i++) {
            var c = layout.categories[i]
            var subs = c.subs || []
            rows.push({ kind: "cat", id: c.key, cat: c.key, label: c.label, icon: c.icon,
                        subtitle: c.subtitle || "", count: subs.length })
            if (c.key === layout.expandedKey) {
                for (var j = 0; j < subs.length; j++)
                    rows.push({ kind: "sub", id: subs[j].id, cat: c.key,
                                label: subs[j].label, icon: subs[j].icon,
                                subtitle: "", count: 0 })
            }
        }
        return rows
    }

    function rowIsActive(row) {
        if (layout.searching) return false
        if (row.kind === "cat") return row.cat === layout.current && layout.expandedKey !== row.cat
        return row.cat === layout.current && row.id === layout.currentTab
    }

    function activateRow(row) {
        if (row.kind === "sub") {
            layout.route(row.cat, row.id)
            layout.expandedKey = row.cat
            return
        }
        // A parent row selects its category and opens it. Clicking the open
        // category again collapses it, which is the only way to close a branch.
        layout.clearSearch()
        if (layout.current === row.cat && layout.expandedKey === row.cat) layout.expandedKey = ""
        else layout.select(row.cat)
    }

    // Sidebar arrow-key navigation over the flattened rail, so Up/Down walk into
    // an open category rather than skipping the branch. Clamped rather than
    // wrapping: a wrap reads as a jump, not as continuing in the same direction.
    // Never collapses — that is a click-only action, or arrowing past a parent
    // would shut the branch you are walking through.
    function step(d) {
        var rows = layout.railRows
        if (rows.length === 0) return
        var cur = 0
        for (var i = 0; i < rows.length; i++) {
            if (layout.rowIsActive(rows[i])) { cur = i; break }
        }
        var n = Math.max(0, Math.min(rows.length - 1, cur + d))
        // Stepping onto the parent of the branch you are already inside would
        // land on a row that cannot hold the highlight (one of its children
        // has it), so Up out of a first child would look like a dead key. Carry
        // on one more row in the same direction instead.
        if (rows[n].kind === "cat" && rows[n].cat === layout.current && layout.expandedKey === rows[n].cat)
            n = Math.max(0, Math.min(rows.length - 1, n + d))

        var next = rows[n]
        if (next.kind === "sub") layout.route(next.cat, next.id)
        else layout.select(next.cat)
    }

    // ── Routing ──────────────────────────────────────────────────────────────
    // A search hit names the card it lives on. The page it belongs to may not be
    // loaded yet, so the name is parked here and the category host flushes it
    // once its Loader has produced an item.
    property string pendingCard: ""

    // Set by the current category host so route() can reach the live page.
    // Deliberately `var`, not `Item`: revealCard is duck-typed across the
    // category pages.
    property var currentPage: null

    // Accepts a category key or any key a page claims via `keys: [...]`, so
    // `mujo settings wallpaper`, `mujo settings dnd` and the omni-search all
    // keep working through one entry point. `card` is optional and names a
    // section or a MujoCard title on the destination page; when it is omitted
    // and `key` is an alias, the alias itself is handed to the page.
    function route(key, card) {
        if (!key) return
        for (var i = 0; i < categories.length; i++) {
            var c = categories[i]
            if (c.key === key || (c.keys && c.keys.indexOf(key) >= 0)) {
                if (card) layout.pendingCard = card
                else if (key !== c.key) layout.pendingCard = key
                else layout.pendingCard = ""
                layout.select(c.key)
                clearSearch()
                Qt.callLater(layout.flushPendingCard)
                return
            }
        }
    }

    function flushPendingCard() {
        if (layout.pendingCard === "" || !layout.currentPage) return
        if (typeof layout.currentPage.revealCard !== "function") {
            layout.pendingCard = ""
            return
        }
        layout.currentPage.revealCard(layout.pendingCard)
        layout.pendingCard = ""
    }

    // Panels and dashboard cards navigate through the bus; `mujo settings <key>`
    // writes the target file.
    Connections {
        target: SettingsBus
        function onNavigate(key) { layout.route(key) }
    }

    FileView {
        path: (Quickshell.env("HOME") || "/tmp") + "/.config/qsshell/settings-target"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: layout.route(text().trim())
    }

    // ── Omni-search ──────────────────────────────────────────────────────────
    property string query: ""
    property int searchSel: 0
    readonly property bool searching: query.trim() !== ""

    // Below this the sidebar drops its labels and becomes an icon rail: 236px of
    // chrome in a 700px window leaves too little for a settings column.
    //
    // searchExpanded overrides it, because an icon-only search box cannot be
    // typed into. It has to be its own flag rather than the field's focus: the
    // field is hidden while compact, and a hidden item cannot take focus, so
    // keying off focus would never let the rail open.
    property bool searchExpanded: false
    readonly property bool compact: layout.width < 860 && !layout.searchExpanded

    function focusSearch() {
        layout.searchExpanded = true
        Qt.callLater(sidebar.focusField)
    }

    function setQuery(q) {
        query = q
        sidebar.searchText = q
        searchSel = 0
        searchExpanded = true
        sidebar.focusField()
    }

    function clearSearch() {
        query = ""
        sidebar.clearField()
        layout.searchExpanded = false
    }

    function score(e, q) {
        var t = (e.title || "").toLowerCase()
        var d = (e.desc || "").toLowerCase()
        var c = (e.cat || "").toLowerCase()
        var cd = (e.card || "").toLowerCase()

        if (t.indexOf(q) === 0) return 100
        if (t.indexOf(q) >= 0) return 85

        if (Array.isArray(e.tags)) {
            for (var k = 0; k < e.tags.length; k++) {
                var tag = (e.tags[k] || "").toLowerCase()
                if (tag === q) return 80
                if (tag.indexOf(q) === 0) return 75
                if (tag.indexOf(q) >= 0) return 70
            }
        }

        if (c.indexOf(q) >= 0 || cd.indexOf(q) >= 0) return 60
        if (d.indexOf(q) >= 0) return 40

        var j = 0
        for (var i = 0; i < t.length && j < q.length; i++) {
            if (t[i] === q[j]) j++
        }
        return j === q.length ? 20 : -1
    }

    readonly property var results: {
        var q = query.trim().toLowerCase()
        if (q === "") return []
        var scored = []
        for (var i = 0; i < searchIndex.length; i++) {
            var s = score(searchIndex[i], q)
            if (s >= 0) scored.push({ e: searchIndex[i], s: s })
        }
        scored.sort(function (a, b) { return b.s - a.s })
        return scored.map(function (x) { return x.e })
    }

    function stepResult(d) {
        if (!layout.searching) return
        layout.searchSel = Math.max(0, Math.min(layout.results.length - 1, layout.searchSel + d))
    }

    function activateResult(i) {
        if (i < 0 || i >= results.length) return
        route(results[i].key, results[i].card)
    }

    // Ctrl+F is unambiguous. "/" is the fast path, but it is also a character
    // people type into the Wallhaven query, the API base URL and the persistence
    // path box — so it only grabs focus when a text field does not already have
    // it. echoMode is the cheap "is this a text input" test.
    Shortcut {
        sequences: ["Ctrl+F"]
        onActivated: layout.focusSearch()
    }
    Shortcut {
        sequence: "/"
        enabled: {
            var f = layout.Window.activeFocusItem
            return !f || f.echoMode === undefined
        }
        onActivated: layout.focusSearch()
    }

    // ── Composition ──────────────────────────────────────────────────────────
    RowLayout {
        anchors.fill: parent
        spacing: 0

        SettingsSidebar {
            id: sidebar
            shell: layout
            compact: layout.compact
            Layout.preferredWidth: implicitWidth
            Layout.fillHeight: true
            onSearchRequested: layout.focusSearch()
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Theme.bg
            clip: true

            // Category hosts. Every visited category keeps its instance, so
            // swapping back is instant and its scroll position holds.
            Repeater {
                model: layout.categories

                delegate: Item {
                    id: catHost
                    required property var modelData
                    required property int index

                    readonly property bool isCurrent: layout.currentIndex === index && !layout.searching
                    property bool loaded: false

                    anchors.fill: parent
                    enabled: isCurrent
                    visible: opacity > 0
                    opacity: isCurrent ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: Anim.d(Anim.enter); easing.type: Anim.easeStandard } }

                    onIsCurrentChanged: if (isCurrent) { loaded = true; catHost.publish() }
                    Component.onCompleted: if (isCurrent) { loaded = true; catHost.publish() }

                    // Hand the live page to the layout so route() can reach it.
                    function publish() {
                        if (!isCurrent) return
                        layout.currentPage = pageLoader.item
                        layout.flushPendingCard()
                    }

                    Loader {
                        id: pageLoader
                        anchors.fill: parent
                        active: catHost.loaded
                        sourceComponent: catHost.modelData.page
                        onLoaded: catHost.publish()
                    }
                }
            }

            SettingsSearchResults {
                anchors.fill: parent
                visible: layout.searching
                shell: layout
            }
        }
    }
}
