import QtQuick
import "../../../theme"
import "../../../services"
import ".."

// Left and right pill groups with the interactive notch in place of the centre
// zone. The notch is measured like any other centre content, so a wide left
// cluster now pushes it aside instead of drawing underneath it.
BarLayout {
    id: root
    edgeMargin: Theme.barMargin
    gap: SettingsBus.get("bar.spacing", 6)
    wrapInCluster: true
    centerContent: islandC

    Component {
        id: islandC
        Island {
            panelWindow: root.panelWindow
            screenName: root.screenName
        }
    }
}
