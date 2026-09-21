import QtQuick
import "../../../theme"
import "../../../services"
import ".."

// Three detached pill groups over the wallpaper — the default.
BarLayout {
    edgeMargin: Theme.barMargin
    gap: SettingsBus.get("bar.spacing", 6)
    wrapInCluster: true
}
