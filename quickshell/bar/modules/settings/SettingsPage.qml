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
