import QtQuick
import QtQuick.Layouts
import "../../theme"
import "../../components"

// Level-2 host: one sidebar category = one hero + a scrolling column of
// MujoCards. Every consolidated page uses this instead of hand-rolling its own
// Flickable/margins/hero, which is what left the twenty panels drifting apart.
//
//   SettingsPage {
//       brand: "appearance"; title: "Appearance"; subtitle: "Theme, motion, bar"
//       MujoCard { title: "Theme"; SettingRow { path: "theme.preset"; … } }
//       MujoCard { title: "Bar";   SettingRow { path: "bar.height";  … } }
//   }
//
// The page instance stays alive while another category is on screen, so
// contentY (scroll position) survives switching away and back.
Item {
    id: page

    property string brand: "general"
    property string title: ""
    property string subtitle: ""
    property string badgeText: ""
    property bool isNixos: false
    property alias contentY: flick.contentY

    default property alias content: col.children

    // Reveal a named MujoCard. Omni-search calls this so a hit on
    // "Storage Reclamation" lands on the card rather than the top of the page.
    // Cards live inside the *Group children, not directly in `col`, so the
    // lookup recurses. Returns false when no card carries that title.
    function revealCard(cardTitle) {
        var card = page._findCard(col, cardTitle)
        if (!card) return false
        var maxY = Math.max(0, flick.contentHeight - flick.height)
        var p = card.mapToItem(col, 0, 0)
        scrollAnim.stop()
        scrollAnim.to = Math.max(0, Math.min(p.y, maxY))
        scrollAnim.start()
        return true
    }

    // MujoCard is the only thing here carrying both `title` and `collapsible`,
    // which keeps MujoHero and MujoSettingRow (both of which have a `title`)
    // from matching.
    function _findCard(node, cardTitle) {
        var kids = node.children
        for (var i = 0; i < kids.length; i++) {
            var c = kids[i]
            if (c.collapsible !== undefined && c.title === cardTitle) return c
            var hit = page._findCard(c, cardTitle)
            if (hit) return hit
        }
        return null
    }

    NumberAnimation {
        id: scrollAnim
        target: flick
        property: "contentY"
        duration: Anim.d(Anim.enter)
        easing.type: Easing.OutCubic
    }

    MujoFlickable {
        id: flick
        anchors.fill: parent
        contentHeight: col.implicitHeight + 48

        ColumnLayout {
            id: col
            x: 24
            y: 24
            width: flick.width - 48
            spacing: 14

            MujoHero {
                Layout.fillWidth: true
                visible: page.title !== ""
                brand: page.brand
                title: page.title
                subtitle: page.subtitle
                badgeText: page.badgeText
                isNixos: page.isNixos
            }
        }
    }
}
