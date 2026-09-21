import QtQuick
import "../../../theme"
import "../../../services"
import ".."

// A single centred group holding every module, macOS-dock style. One zone, so
// there is nothing for BarLayout to arbitrate — but it goes through the same
// BarSlot as the other styles, because the imperative Loader it used to use
// re-bound `panelWindow` from an `onLoaded` handler mid-incubation and took
// PopupAnchor down with it (`QQuickItem::window()` on a half-built item).
Item {
    id: root
    property var niri
    property string screenName: ""
    property string focusedOutput: ""
    property var panelWindow
    property bool launcherOpen: false

    readonly property var combinedModules: BarModuleRegistry.slot("left")
        .concat(BarModuleRegistry.slot("center"))
        .concat(BarModuleRegistry.slot("right"))

    BarSlot {
        anchors.centerIn: parent
        modules: root.combinedModules
        alignment: Qt.AlignHCenter
        spacing: SettingsBus.get("bar.spacing", 8)
        wrapInCluster: true
        clusterRadius: Theme.radiusLg
        // Never wider than the screen it sits on.
        maxWidth: root.width - Theme.barMargin * 2
        barWidth: root.width
        panelWindow: root.panelWindow
        screenName: root.screenName
        niri: root.niri
        focusedOutput: root.focusedOutput
        launcherOpen: root.launcherOpen
    }
}
