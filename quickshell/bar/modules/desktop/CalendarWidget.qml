import QtQuick
import "../../theme"
import "../../components"
import "../../services"
import "../bar"

// Desktop month calendar. Reuses the bar's CalendarMenu verbatim rather than
// growing a second calendar: that component is fixed-cell (28x26 day cells), so
// resizing the widget scales it uniformly instead of reflowing the grid.
BaseWidget {
    id: root

    property var wcfg: ({})
    readonly property string cardStyle: wcfg.cardStyle !== undefined ? wcfg.cardStyle : "glass"

    chromeless: cardStyle === "chromeless"
    title: ""
    iconName: ""

    Item {
        anchors.fill: parent

        CalendarMenu {
            id: cal
            anchors.centerIn: parent
            transformOrigin: Item.Center
            scale: Math.max(0.4, Math.min(parent.width / Math.max(1, cal.implicitWidth),
                                          parent.height / Math.max(1, cal.implicitHeight)))
        }
    }
}
