import QtQuick
import "../../../theme"
import "../../../services"
import ".."

// Everything tightened: minimal edge margin and the smallest gap that still
// reads as three separate groups.
BarLayout {
    edgeMargin: 4
    gap: 3
    wrapInCluster: true
}
