import QtQuick
import "../../../theme"
import "../../../services"
import ".."

// One opaque band across the whole edge; the zones sit on it bare, with no
// pill of their own.
BarLayout {
    id: root
    edgeMargin: 12
    gap: SettingsBus.get("bar.spacing", 8)
    wrapInCluster: false

    Rectangle {
        anchors.fill: parent
        z: -1
        color: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, Theme.surface.a * Theme.barGroupOpacity)
        border.width: 1
        border.color: Theme.border
    }
}
