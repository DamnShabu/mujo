import QtQuick
import QtQuick.Layouts
import "../../theme"
import "../../components"

// Workspace & Desktop Chrome — Desktop Bar, Dynamic Island,
// Overlay Widgets, and Edge Staging Shelf.
Item {
    id: root

    property string brand: "desktop"
    property string title: "Workspace"
    property string subtitle: "Desktop bar layout, dynamic island notch, overlay widgets & staging shelf."

    property string tab: "bar"   // bar | island | widgets | shelf
    readonly property var tabIds: ["bar", "island", "widgets", "shelf"]

    readonly property var cardTabMap: ({
        "Desktop Bar Layout & Geometry": "bar",
        "3-Zone Slot Canvas Builder": "bar",
        "Right Cluster Modules & Order": "bar",
        "Bar Widget Style Customizer": "bar",
        "Dynamic Island Notch": "island",
        "Island Geometry & Surface": "island",
        "Expansion & Alert Behavior": "island",
        "Desktop Overlay Widgets": "widgets",
        "Global Widget Styles & Glassmorphism": "widgets",
        "Widget Customization & Styles": "widgets",
        "Shelf File Staging Drop Zone": "shelf"
    })

    function revealCard(name) {
        if (root.tabIds.indexOf(name) >= 0) {
            root.tab = name
            return true
        }
        var targetTab = root.cardTabMap[name]
        if (targetTab) {
            root.tab = targetTab
            var flick = _getActiveFlickable()
            if (flick) _scrollFlickToCard(flick, name)
            return true
        }
        return false
    }

    function _getActiveFlickable() {
        if (root.tab === "bar") return flickBar
        if (root.tab === "island") return flickIsland
        if (root.tab === "widgets") return flickWidgets
        if (root.tab === "shelf") return flickShelf
        return null
    }

    function _scrollFlickToCard(flick, cardTitle) {
        var card = _findCard(flick.contentItem, cardTitle)
        if (!card) return
        var maxY = Math.max(0, flick.contentHeight - flick.height)
        var p = card.mapToItem(flick.contentItem, 0, 0)
        flick.contentY = Math.max(0, Math.min(p.y, maxY))
    }

    function _findCard(node, cardTitle) {
        if (!node) return null
        var kids = node.children
        for (var i = 0; i < kids.length; i++) {
            var c = kids[i]
            if (c.collapsible !== undefined && c.title === cardTitle) return c
            var hit = _findCard(c, cardTitle)
            if (hit) return hit
        }
        return null
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 14

        MujoSegmented {
            Layout.alignment: Qt.AlignLeft
            model: [
                { id: "bar",     label: "Desktop Bar",     icon: "dock_to_bottom" },
                { id: "island",  label: "Dynamic Island",  icon: "notifications_active" },
                { id: "widgets", label: "Overlay Widgets", icon: "widgets" },
                { id: "shelf",   label: "Shelf",           icon: "inventory_2" }
            ]
            current: root.tab
            onSelected: function(id) { root.tab = id }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            MujoFlickable {
                id: flickBar
                anchors.fill: parent
                visible: root.tab === "bar"
                contentHeight: colBar.implicitHeight + 20

                ColumnLayout {
                    id: colBar
                    width: parent.width
                    spacing: 14
                    BarGroup { Layout.fillWidth: true }
                }
            }

            MujoFlickable {
                id: flickIsland
                anchors.fill: parent
                visible: root.tab === "island"
                contentHeight: colIsland.implicitHeight + 20

                ColumnLayout {
                    id: colIsland
                    width: parent.width
                    spacing: 14
                    IslandGroup { Layout.fillWidth: true }
                }
            }

            MujoFlickable {
                id: flickWidgets
                anchors.fill: parent
                visible: root.tab === "widgets"
                contentHeight: colWidgets.implicitHeight + 20

                ColumnLayout {
                    id: colWidgets
                    width: parent.width
                    spacing: 14
                    WidgetsGroup { Layout.fillWidth: true }
                }
            }

            MujoFlickable {
                id: flickShelf
                anchors.fill: parent
                visible: root.tab === "shelf"
                contentHeight: colShelf.implicitHeight + 20

                ColumnLayout {
                    id: colShelf
                    width: parent.width
                    spacing: 14
                    ShelfGroup { Layout.fillWidth: true }
                }
            }
        }
    }
}
