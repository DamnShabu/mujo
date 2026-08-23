import QtQuick

// Sliding highlight for a horizontal tab / segmented-control row. The parent
// supplies the item count and the active index; this animates a pill to sit
// behind the active segment (equal-width segments across `width`). Purely
// presentational — put it *behind* the row's labels. reduceMotion → instant.
//
//   TabIndicator { anchors.fill: parent; count: 3; currentIndex: sel }
Item {
    id: root

    property int count: 1
    property int currentIndex: 0
    // Equal-width segments by default; override segWidth for custom layouts.
    property real segWidth: count > 0 ? width / count : width

    property color fill: Theme.accentDim
    property color stroke: Theme.accent
    property int radius: Theme.radiusMd

    Rectangle {
        height: parent.height
        width: root.segWidth
        radius: root.radius
        color: root.fill
        border.color: root.stroke
        x: root.currentIndex * root.segWidth
        Behavior on x { NumberAnimation { duration: Anim.d(Anim.standard); easing.type: Anim.easeStandard } }
        Behavior on width { NumberAnimation { duration: Anim.d(Anim.standard); easing.type: Anim.easeStandard } }
    }
}
