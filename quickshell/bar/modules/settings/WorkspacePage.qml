import QtQuick
import QtQuick.Layouts
import "../../theme"
import "../../components"

// Workspace & Desktop Chrome — Bar layout & widget styles, dynamic island,
// desktop overlay widgets, and edge shelf staging drawer.
SettingsPage {
    brand: "desktop"
    title: "Workspace"
    subtitle: "Desktop bar, dynamic island, overlay widgets, and edge shelf."

    BarGroup {}
    IslandGroup {}
    WidgetsGroup {}
    ShelfGroup {}
}
