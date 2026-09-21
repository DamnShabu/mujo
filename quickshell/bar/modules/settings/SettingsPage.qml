import QtQuick
import QtQuick.Layouts
import "../../theme"
import "../../components"

// A settings category, expressed as data.
//
//     SettingsPage {
//         title: "Workspace"
//         sections: [
//             { id: "bar", label: "Desktop Bar",
//               description: "Where the bar sits and what it carries.",
//               component: barSection }
//         ]
//         cardMap: ({ "Bar Layout & Geometry": "bar" })
//         Component { id: barSection; ColumnLayout { BarGroup { Layout.fillWidth: true } } }
//     }
//
// Each section is one pane with its own heading, description and scroll
// position, loaded the first time it is opened and kept alive after. The five
// category pages used to spell this out by hand — a stack of Flickables plus
// identical copies of `_findCard`, `_scrollFlickToCard` and
// `_getActiveFlickable`, some ninety duplicated lines each. They are data now.
Item {
    id: page

    // Published for the shell header and the omni-search.
    property string brand: "general"
    property string title: ""
    property string subtitle: ""
    property bool isNixos: false

    // [{ id, label, description, component, fill }]
    // `fill` hands the whole pane to the component instead of putting it in a
    // scrolling column — for a section that scrolls itself, like the wallpaper
    // browsers.
    property var sections: []
    // Card title → section id, so omni-search lands on a card rather than the
    // top of the page.
    property var cardMap: ({})
    // Extra ids the page answers to, mapped onto a section: `mujo settings vpn`
    // is the Network section.
    property var aliases: ({})

    property string tab: sections.length > 0 ? sections[0].id : ""

    readonly property var tabIds: {
        var ids = []
        for (var i = 0; i < page.sections.length; i++) ids.push(page.sections[i].id)
        for (var a in page.aliases) if (ids.indexOf(a) < 0) ids.push(a)
        return ids
    }

    readonly property int tabIndex: {
        for (var i = 0; i < page.sections.length; i++)
            if (page.sections[i].id === page.tab) return i
        return 0
    }

    readonly property real contentY: {
        var h = hosts.itemAt(page.tabIndex)
        return h ? h.contentY : 0
    }

    // Content column: flush left in a narrow window, centred once the pane is
    // wider than a comfortable measure. Settings text stops being readable long
    // before a 2560px row does, and a label 1600px from its control is not a
    // layout.
    property int contentMax: 840
    property int gutter: 28

    // Select a section, or scroll to a named card inside one. The sidebar,
    // `mujo settings <key>` and the omni-search all arrive here. Pages with
    // their own inner navigation override `revealCard` and delegate here.
    function revealSection(name) {
        if (page.tabIds.indexOf(name) >= 0) {
            page.tab = page.aliases[name] !== undefined ? page.aliases[name] : name
            return true
        }
        var target = page.cardMap[name]
        if (target === undefined) return false
        page.tab = target
        var host = hosts.itemAt(page.tabIndex)
        if (host) host.scrollToCard(name)
        return true
    }
    function revealCard(name) { return page.revealSection(name) }

    Repeater {
        id: hosts
        model: page.sections

        delegate: Item {
            id: host
            required property var modelData
            required property int index

            readonly property bool isCurrent: page.tabIndex === index
            readonly property bool fills: modelData.fill === true
            readonly property real colW: Math.min(page.contentMax, host.width - page.gutter * 2)
            readonly property real contentY: flick.contentY
            property bool loaded: false

            anchors.fill: parent
            visible: isCurrent
            enabled: isCurrent

            // Sections load on first visit and stay alive after, so each keeps
            // its scroll position, and live state — a running process, a
            // watched file — is not torn down by looking at a sibling.
            onIsCurrentChanged: if (isCurrent) loaded = true
            Component.onCompleted: if (isCurrent) loaded = true

            function scrollToCard(cardTitle) {
                var card = page._findCard(col, cardTitle)
                if (!card) return
                var maxY = Math.max(0, flick.contentHeight - flick.height)
                var p = card.mapToItem(col, 0, 0)
                flick.contentY = Math.max(0, Math.min(p.y - 12, maxY))
            }

            ColumnLayout {
                anchors.fill: parent
                // A settings column is capped and centred so a label never
                // ends up half a screen from its control. A section that fills
                // the pane is a grid browser and wants every pixel of it.
                anchors.leftMargin: host.fills ? page.gutter
                                               : Math.max(page.gutter, (host.width - host.colW) / 2)
                anchors.rightMargin: anchors.leftMargin
                anchors.topMargin: 26
                anchors.bottomMargin: 0
                spacing: 0

                // The page heading scrolls away with the content rather than
                // sitting in a fixed bar: it is orientation, not chrome, and
                // the fixed bar it replaces spent 52px of every page restating
                // the sidebar.
                Text {
                    text: host.modelData.label || page.title
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeHeading + 3
                    font.weight: Font.Bold
                    font.letterSpacing: -0.3
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                Text {
                    visible: text !== ""
                    text: host.modelData.description || ""
                    color: Theme.textSecondary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    lineHeight: 1.3
                    wrapMode: Text.WordWrap
                    Layout.topMargin: 5
                    Layout.fillWidth: true
                    Layout.maximumWidth: 640
                }

                MujoSegmented {
                    visible: page.sections.length > 1
                    Layout.topMargin: 14
                    model: {
                        var m = []
                        for (var i = 0; i < page.sections.length; i++) {
                            var s = page.sections[i]
                            m.push({ id: s.id, label: s.label || s.id })
                        }
                        return m
                    }
                    current: page.tab
                    onSelected: function(id) { page.revealSection(id) }
                }

                // A section that scrolls itself gets the pane; everything else
                // scrolls inside one.
                Loader {
                    visible: host.fills
                    active: host.loaded && host.fills
                    sourceComponent: host.modelData.component
                    Layout.topMargin: 20
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                }

                MujoFlickable {
                    id: flick
                    visible: !host.fills
                    Layout.topMargin: 20
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    contentHeight: col.implicitHeight + 40

                    ColumnLayout {
                        id: col
                        width: flick.width
                        spacing: 14

                        Loader {
                            Layout.fillWidth: true
                            active: host.loaded && !host.fills
                            sourceComponent: host.modelData.component
                        }
                    }
                }
            }
        }
    }

    // MujoCard is the only thing carrying `collapsible`, which keeps
    // MujoSettingRow (which also has a `title`) from matching.
    function _findCard(node, cardTitle) {
        if (!node) return null
        var kids = node.children
        for (var i = 0; i < kids.length; i++) {
            var c = kids[i]
            if (c.collapsible !== undefined && c.title === cardTitle) return c
            var hit = page._findCard(c, cardTitle)
            if (hit) return hit
        }
        return null
    }
}
