import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import Quickshell
import Quickshell.Io
import "../../theme"
import "../../components"
import "../../services"

// The settings shell: fixed 260px sidebar (brand, omni-search, seven categories
// with a sliding glider and count badges) + a fluid content pane that crossfades
// between category pages without reloading them.
//
// Navigation depth stops at two: a sidebar category, then the cards inside it.
// Nothing here routes to a third level.
//
// Categories are data:
//   { key, label, icon, brand, subtitle, badge, page: Component, keys: [...] }
//
// `keys` are the routing aliases the category answers to, so every panel key
// that existed before the seven-category consolidation still resolves through
// route() — `mujo settings wallpaper`, `mujo settings dnd`, and the omni-search
// all enter here.
Item {
    id: layout

    property var categories: []
    property var searchIndex: []          // [{ title, desc, cat, key, card }] — key routes
                                          // like route(); card names a MujoCard
                                          // title to scroll to on arrival.

    property string current: categories.length > 0 ? categories[0].key : ""
    readonly property int currentIndex: {
        for (var i = 0; i < categories.length; i++)
            if (categories[i].key === current) return i
        return 0
    }
    readonly property var currentCategory: categories.length > 0 ? categories[currentIndex] : ({ label: "", icon: "" })


    // A search hit names the card it lives on. The page it belongs to may not
    // be loaded yet, so the name is parked here and the category host flushes
    // it once its Loader has produced an item.
    property string pendingCard: ""

    // Accepts a category key or any key a page claims via `keys: [...]` — so
    // `mujo settings wallpaper`, `mujo settings dnd` and the omni-search all
    // keep working through one entry point. `card` is optional and names a
    // MujoCard title on the destination page.
    function route(key, card) {
        if (!key) return
        for (var i = 0; i < categories.length; i++) {
            var c = categories[i]
            if (c.key === key || (c.keys && c.keys.indexOf(key) >= 0)) {
                layout.pendingCard = card || ""
                current = c.key
                clearSearch()
                Qt.callLater(layout.flushPendingCard)
                return
            }
        }
    }

    // Set by the current category host so route() can reach the live page.
    // Deliberately `var`, not `Item`: revealCard is duck-typed across
    // SettingsPage (six categories) and WallpapersPage (which cannot be one,
    // because its grids need the full viewport). They share no base type that
    // could declare the function, so the call is guarded rather than typed.
    property var currentPage: null
    function flushPendingCard() {
        if (layout.pendingCard === "" || !layout.currentPage) return
        if (typeof layout.currentPage.revealCard !== "function") {
            layout.pendingCard = ""
            return
        }
        layout.currentPage.revealCard(layout.pendingCard)
        layout.pendingCard = ""
    }

    // Below this the sidebar drops its labels and becomes an icon rail: at 260px
    // of chrome a 700px window leaves too little for a card column.
    //
    // searchExpanded overrides it, because an icon-only search box cannot be
    // typed into. It has to be its own flag rather than searchField.activeFocus:
    // the field is hidden while compact, and a hidden item cannot take focus, so
    // keying off focus would never let the rail open.
    property bool searchExpanded: false
    readonly property bool compact: layout.width < 860 && !layout.searchExpanded

    function focusSearch() {
        layout.searchExpanded = true
        Qt.callLater(function () { searchField.forceActiveFocus() })
    }

    // Sidebar arrow-key navigation. Clamped rather than wrapping: at seven
    // entries a wrap reads as a jump, not as continuing in the same direction.
    function step(d) {
        if (categories.length === 0) return
        var i = Math.max(0, Math.min(categories.length - 1, currentIndex + d))
        current = categories[i].key
    }

    // ── Omni-search ──────────────────────────────────────────────────────────
    property string query: ""
    property int searchSel: 0
    readonly property bool searching: query.trim() !== ""

    function clearSearch() {
        query = ""
        searchField.text = ""
        layout.searchExpanded = false
    }

    function score(e, q) {
        var t = e.title.toLowerCase(), d = e.desc.toLowerCase(), c = e.cat.toLowerCase()
        if (t.indexOf(q) === 0) return 100
        if (t.indexOf(q) >= 0) return 80
        if (c.indexOf(q) >= 0) return 60
        if (d.indexOf(q) >= 0) return 40
        var j = 0
        for (var i = 0; i < t.length && j < q.length; i++) if (t[i] === q[j]) j++
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
    function activateResult(i) {
        if (i < 0 || i >= results.length) return
        route(results[i].key, results[i].card)
    }

    // ── External routing ─────────────────────────────────────────────────────
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

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // ═════ SIDEBAR ═══════════════════════════════════════════════════════
        Rectangle {
            Layout.preferredWidth: layout.compact ? 64 : 260
            Layout.fillHeight: true
            color: Theme.surface
            Behavior on Layout.preferredWidth {
                NumberAnimation { duration: Anim.d(Anim.standard); easing.type: Anim.easeStandard }
            }

            Rectangle {
                anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
                width: 1
                color: Theme.border
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 12

                // Brand header
                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 2
                    spacing: 10

                    BrandIcon { brand: "mujo"; size: 28; Layout.alignment: Qt.AlignVCenter }

                    Text {
                        visible: !layout.compact
                        text: "Settings"
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeTitle + 3
                        font.bold: true
                        Layout.alignment: Qt.AlignVCenter
                    }

                    Item { Layout.fillWidth: true }

                    Rectangle {
                        visible: !layout.compact
                        implicitWidth: mujoBadge.implicitWidth + 8
                        implicitHeight: 18
                        radius: Theme.radiusSm
                        color: Theme.accentDim
                        border.color: Theme.withAlpha(Theme.accent, 0.35)
                        Layout.alignment: Qt.AlignVCenter

                        Text {
                            id: mujoBadge
                            anchors.centerIn: parent
                            text: "mujō"
                            color: Theme.accent
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSizeLabel
                            font.bold: true
                        }
                    }
                }

                // Omni-search
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 36
                    radius: Theme.radiusMd
                    color: Theme.withAlpha(Theme.bg, 0.85)
                    border.color: searchField.activeFocus ? Theme.accent : Theme.border
                    Behavior on border.color { ColorAnimation { duration: Anim.d(Anim.fast) } }

                    // Ctrl+F is unambiguous. "/" is the fast path, but it is also a
                    // character people type into the Wallhaven query, the API
                    // base URL and the persistence path box — so it only grabs
                    // focus when a text field does not already have it.
                    // echoMode is the cheap "is this a text input" test.
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

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.IBeamCursor
                        onClicked: layout.focusSearch()
                    }

                    RowLayout {
                        anchors.fill: parent
                        // Compact: no room for a query, so the box becomes a
                        // centred magnifier. Clicking or Ctrl+F focuses the
                        // field, which clears `compact` and expands the rail.
                        anchors.leftMargin: layout.compact ? 0 : 10
                        anchors.rightMargin: layout.compact ? 0 : 8
                        spacing: layout.compact ? 0 : 8

                        Item { visible: layout.compact; Layout.fillWidth: true }

                        MaterialIcon {
                            iconName: "search"
                            pixelSize: 17
                            color: searchField.activeFocus ? Theme.accent : Theme.textSecondary
                            Behavior on color { ColorAnimation { duration: Anim.d(Anim.fast) } }
                        }

                        Item { visible: layout.compact; Layout.fillWidth: true }

                        TextInput {
                            id: searchField
                            visible: !layout.compact
                            Layout.fillWidth: !layout.compact
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeBody
                            verticalAlignment: TextInput.AlignVCenter
                            clip: true
                            selectByMouse: true
                            activeFocusOnTab: true
                            cursorVisible: activeFocus
                            onTextChanged: { layout.query = text; layout.searchSel = 0 }
                            Keys.onDownPressed: if (layout.searching) layout.searchSel = Math.min(layout.searchSel + 1, layout.results.length - 1)
                            Keys.onUpPressed: if (layout.searching) layout.searchSel = Math.max(layout.searchSel - 1, 0)
                            Keys.onReturnPressed: layout.activateResult(layout.searchSel)
                            Keys.onEscapePressed: { if (text === "") Qt.quit(); else layout.clearSearch() }
                            // Let the rail collapse again once the user leaves an
                            // empty search behind.
                            onActiveFocusChanged: if (!activeFocus && text === "") layout.searchExpanded = false

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: searchField.text === ""
                                text: "Search settings…"
                                color: Theme.textDim
                                font: searchField.font
                            }
                        }

                        Rectangle {
                            visible: !layout.compact
                            implicitWidth: hintTxt.implicitWidth + 10
                            implicitHeight: 18
                            radius: Theme.radiusSm
                            color: Theme.withAlpha(Theme.surfaceActive, 0.7)
                            border.color: Theme.border

                            Text {
                                id: hintTxt
                                anchors.centerIn: parent
                                text: searchField.text === "" ? "/" : "esc"
                                color: Theme.textDim
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fontSizeLabel - 1
                            }
                            MouseArea {
                                anchors.fill: parent
                                enabled: searchField.text !== ""
                                cursorShape: Qt.PointingHandCursor
                                onClicked: layout.clearSearch()
                            }
                        }
                    }
                }

                // Category rail — one row per category, a sliding glider, count
                // badges. Focusable, so Up/Down walk the categories without
                // the pointer.
                Item {
                    id: navRail
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    activeFocusOnTab: true
                    Keys.onUpPressed: layout.step(-1)
                    Keys.onDownPressed: layout.step(1)
                    // Keys has no onHome/onEndPressed attached signal.
                    Keys.onPressed: function (event) {
                        if (event.key === Qt.Key_Home) { layout.step(-layout.categories.length); event.accepted = true }
                        else if (event.key === Qt.Key_End) { layout.step(layout.categories.length); event.accepted = true }
                    }

                    Accessible.role: Accessible.PageTabList
                    Accessible.name: "Settings categories"

                    readonly property int rowH: 42
                    readonly property int rowGap: 4

                    // Active glider. Geometry is derived from the index, so it
                    // never depends on delegate ids surviving a rebuild.
                    Rectangle {
                        id: glider
                        width: parent.width
                        height: parent.rowH
                        radius: Theme.radiusMd
                        y: layout.currentIndex * (parent.rowH + parent.rowGap)
                        color: Theme.accentDim
                        // The glider doubles as the rail's focus ring: a full-strength
                        // accent border means "arrow keys move this".
                        border.color: navRail.activeFocus ? Theme.accent : Theme.withAlpha(Theme.accent, 0.45)
                        border.width: navRail.activeFocus ? 2 : 1
                        Behavior on border.color { ColorAnimation { duration: Anim.d(Anim.fast) } }
                        opacity: layout.searching ? 0 : 1
                        Behavior on y { NumberAnimation { duration: Anim.d(Anim.standard); easing.type: Anim.easeStandard } }
                        Behavior on opacity { NumberAnimation { duration: Anim.d(Anim.fast) } }

                        Rectangle {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            width: 3
                            height: parent.height * 0.5
                            radius: 2
                            color: Theme.accent
                        }
                    }

                    Column {
                        anchors.fill: parent
                        spacing: parent.rowGap

                        Repeater {
                            model: layout.categories

                            delegate: Rectangle {
                                id: navItem
                                required property var modelData
                                required property int index

                                readonly property bool isActive: layout.currentIndex === index && !layout.searching
                                readonly property int count: modelData.badge !== undefined ? modelData.badge : 0

                                width: parent.width
                                height: 42
                                radius: Theme.radiusMd
                                color: (!isActive && navHh.hovered) ? Theme.surfaceHover : "transparent"
                                Behavior on color { ColorAnimation { duration: Anim.d(Anim.fast) } }

                                RowLayout {
                                    anchors.fill: parent
                                    // Compact: the icon centres in the rail and the
                                    // label and badge drop out. Accessible.name on
                                    // the row still carries the category name.
                                    anchors.leftMargin: layout.compact ? 0 : 12
                                    anchors.rightMargin: layout.compact ? 0 : 10
                                    spacing: layout.compact ? 0 : 10

                                    Item { visible: layout.compact; Layout.fillWidth: true }

                                    MaterialIcon {
                                        iconName: navItem.modelData.icon
                                        pixelSize: 17
                                        color: navItem.isActive ? Theme.accent : (navHh.hovered ? Theme.text : Theme.textSecondary)
                                        Behavior on color { ColorAnimation { duration: Anim.d(Anim.fast) } }
                                    }

                                    Item { visible: layout.compact; Layout.fillWidth: true }

                                    Text {
                                        visible: !layout.compact
                                        text: navItem.modelData.label
                                        color: navItem.isActive ? Theme.text : (navHh.hovered ? Theme.text : Theme.textSecondary)
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeBody
                                        font.bold: navItem.isActive
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                        Behavior on color { ColorAnimation { duration: Anim.d(Anim.fast) } }
                                    }

                                    Rectangle {
                                        visible: navItem.count > 0 && !layout.compact
                                        implicitWidth: Math.max(18, cntTxt.implicitWidth + 10)
                                        implicitHeight: 18
                                        radius: Theme.radiusSm
                                        color: navItem.isActive ? Theme.withAlpha(Theme.accent, 0.18) : Theme.withAlpha(Theme.surfaceActive, 0.7)
                                        border.color: navItem.isActive ? Theme.withAlpha(Theme.accent, 0.4) : Theme.border

                                        Text {
                                            id: cntTxt
                                            anchors.centerIn: parent
                                            text: navItem.count
                                            color: navItem.isActive ? Theme.accent : Theme.textDim
                                            font.family: Theme.fontMono
                                            font.pixelSize: Theme.fontSizeLabel
                                            font.bold: true
                                        }
                                    }
                                }

                                Accessible.role: Accessible.PageTab
                                Accessible.name: navItem.modelData.label
                                Accessible.description: navItem.modelData.subtitle || ""
                                Accessible.checked: navItem.isActive

                                HoverHandler { id: navHh; cursorShape: Qt.PointingHandCursor }
                                TapHandler {
                                    onTapped: {
                                        layout.clearSearch()
                                        layout.current = navItem.modelData.key
                                        navRail.forceActiveFocus()
                                    }
                                }
                            }
                        }
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: Theme.border }

                // Footer: active theme + close. Compact drops the theme chip —
                // its label does not fit — and keeps the close button, which is
                // the one control with no other route.
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Rectangle {
                        visible: !layout.compact
                        Layout.fillWidth: true
                        implicitHeight: 30
                        radius: Theme.radiusSm
                        color: Theme.withAlpha(Theme.accent, 0.1)
                        border.color: thHh.hovered ? Theme.accent : Theme.withAlpha(Theme.accent, 0.3)
                        Behavior on border.color { ColorAnimation { duration: Anim.d(Anim.fast) } }

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 6
                            Rectangle { width: 8; height: 8; radius: 4; color: Theme.accent }
                            Text {
                                text: Theme.presetLabels[Theme.presetName] || Theme.presetName
                                color: Theme.text
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fontSizeLabel
                                font.bold: true
                            }
                        }
                        HoverHandler { id: thHh; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: layout.route("appearance") }
                    }

                    Item { visible: layout.compact; Layout.fillWidth: true }

                    IconButton {
                        iconName: "close"
                        onClicked: Qt.quit()
                    }

                    Item { visible: layout.compact; Layout.fillWidth: true }
                }
            }
        }

        // ═════ CONTENT PANE ══════════════════════════════════════════════════
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Theme.bg

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                // Header
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 52
                    color: Theme.surface

                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: 1
                        color: Theme.border
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 24
                        anchors.rightMargin: 24
                        spacing: 8

                        Text {
                            visible: !layout.searching
                            text: layout.currentCategory.label.toUpperCase()
                            color: Theme.accent
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeLabel
                            font.bold: true
                            font.letterSpacing: Theme.labelSpacing
                            Layout.alignment: Qt.AlignVCenter
                        }

                        Text {
                            visible: !layout.searching
                            text: "•"
                            color: Theme.textDim
                            font.pixelSize: Theme.fontSizeLabel
                            Layout.alignment: Qt.AlignVCenter
                        }

                        Text {
                            text: layout.searching
                                ? "Search Results"
                                : (layout.currentCategory.subtitle || layout.currentCategory.label)
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeTitle + 1
                            font.bold: true
                            Layout.alignment: Qt.AlignVCenter
                        }

                        Item { Layout.fillWidth: true }

                        Rectangle {
                            visible: !layout.searching
                            implicitWidth: keyRow.implicitWidth + 14
                            implicitHeight: 24
                            radius: Theme.radiusSm
                            color: Theme.withAlpha(Theme.accent, 0.12)
                            border.color: Theme.withAlpha(Theme.accent, 0.3)
                            Layout.alignment: Qt.AlignVCenter

                            RowLayout {
                                id: keyRow
                                anchors.centerIn: parent
                                spacing: 5
                                MaterialIcon {
                                    iconName: layout.currentCategory.icon
                                    pixelSize: 14
                                    color: Theme.accent
                                }
                                Text {
                                    text: layout.currentCategory.key || ""
                                    color: Theme.accent
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.fontSizeLabel
                                    font.bold: true
                                }
                            }
                        }
                    }
                }

                // Viewport
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    // Category hosts. Every visited category keeps its instance,
                    // so swapping back is instant and its scroll position holds.
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

                            // Pages load on first visit and are then kept alive,
                            // so each category holds its own scroll position.
                            onIsCurrentChanged: if (isCurrent) { loaded = true; catHost.publish() }
                            Component.onCompleted: if (isCurrent) { loaded = true; catHost.publish() }

                            // Hand the live page to the layout so route() can
                            // scroll it to a named card.
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

                    // Search overlay
                    MujoFlickable {
                        anchors.fill: parent
                        anchors.margins: 24
                        visible: layout.searching
                        contentHeight: resCol.implicitHeight + 30

                        ColumnLayout {
                            id: resCol
                            width: parent.width
                            spacing: 10

                            RowLayout {
                                spacing: 8
                                Layout.bottomMargin: 4

                                Text {
                                    text: layout.results.length + (layout.results.length === 1 ? " setting found" : " settings found")
                                    color: Theme.textSecondary
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeSmall
                                }

                                Text {
                                    text: "• ↑↓ to navigate, Enter to open, Esc to clear"
                                    color: Theme.textDim
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.fontSizeLabel
                                }
                            }

                            Repeater {
                                model: layout.results

                                delegate: Rectangle {
                                    id: resCard
                                    required property var modelData
                                    required property int index
                                    readonly property bool sel: index === layout.searchSel

                                    Layout.fillWidth: true
                                    implicitHeight: 56
                                    radius: Theme.radiusMd
                                    color: sel ? Theme.accentDim : (resHh.hovered ? Theme.surfaceHover : Theme.surface)
                                    border.color: sel ? Theme.accent : Theme.border
                                    border.width: sel ? 1.5 : 1
                                    Behavior on color { ColorAnimation { duration: Anim.d(Anim.fast) } }
                                    Behavior on border.color { ColorAnimation { duration: Anim.d(Anim.fast) } }

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 14
                                        anchors.rightMargin: 16
                                        spacing: 14

                                        BrandIcon { brand: resCard.modelData.key; size: 30 }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 2

                                            Text {
                                                text: resCard.modelData.title
                                                color: Theme.text
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.fontSizeBody
                                                font.bold: true
                                            }

                                            Text {
                                                text: resCard.modelData.desc
                                                color: Theme.textSecondary
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.fontSizeSmall
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                            }
                                        }

                                        Rectangle {
                                            implicitWidth: catBadge.implicitWidth + 14
                                            implicitHeight: 22
                                            radius: Theme.radiusSm
                                            color: Theme.bg
                                            border.color: Theme.border

                                            Text {
                                                id: catBadge
                                                anchors.centerIn: parent
                                                text: resCard.modelData.cat
                                                color: Theme.accent
                                                font.family: Theme.fontMono
                                                font.pixelSize: Theme.fontSizeLabel
                                                font.bold: true
                                            }
                                        }
                                    }

                                    HoverHandler { id: resHh; cursorShape: Qt.PointingHandCursor }
                                    TapHandler { onTapped: layout.activateResult(resCard.index) }
                                }
                            }

                            Text {
                                visible: layout.results.length === 0
                                text: "No settings match “" + layout.query + "”. Try display, theme, nixos, or ai."
                                color: Theme.textDim
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeBody
                                Layout.topMargin: 24
                            }
                        }
                    }
                }
            }
        }
    }
}
