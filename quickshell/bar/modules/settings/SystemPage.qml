import QtQuick
import QtQuick.Layouts
import "../../theme"
import "../../components"

// System Host & Operations — Sub-categorized into Host & Rebuild,
// Health & Storage, Preferences, and Applications.
Item {
    id: root

    property string brand: "system"
    property string title: "System"
    property string subtitle: "Host configuration, rebuilds, health sentinel, storage cleaner, preferences & apps."
    property bool isNixos: true

    property string tab: "rebuild"   // rebuild | health | preferences | apps

    readonly property var tabIds: ["rebuild", "health", "preferences", "apps"]

    // Card title to sub-tab mapping for omni-search deep linking
    readonly property var cardTabMap: ({
        "NixOS Generation & Store": "rebuild",
        "System Generation History": "rebuild",
        "Local Module Overrides": "rebuild",
        "System Health Sentinel": "health",
        "Sentinel Automation": "health",
        "Process Sentinel & Anomaly Tracker": "health",
        "Storage Reclamation & Cleaner": "health",
        "Default Applications": "preferences",
        "System Parameters & Host Config": "preferences",
        "Clipboard History (cliphist)": "preferences",
        "Applications & Integrations": "apps"
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
        if (root.tab === "rebuild") return flickRebuild
        if (root.tab === "health") return flickHealth
        if (root.tab === "preferences") return flickPref
        if (root.tab === "apps") return flickApps
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
                { id: "rebuild",     label: "Host & Rebuild",  icon: "autorenew" },
                { id: "health",      label: "Health & Storage", icon: "health_and_safety" },
                { id: "preferences", label: "Preferences",     icon: "tune" },
                { id: "apps",        label: "Applications",    icon: "apps" }
            ]
            current: root.tab
            onSelected: function(id) { root.tab = id }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            MujoFlickable {
                id: flickRebuild
                anchors.fill: parent
                visible: root.tab === "rebuild"
                contentHeight: colRebuild.implicitHeight + 20

                ColumnLayout {
                    id: colRebuild
                    width: parent.width
                    spacing: 14
                    NixosHostGroup { Layout.fillWidth: true }
                }
            }

            MujoFlickable {
                id: flickHealth
                anchors.fill: parent
                visible: root.tab === "health"
                contentHeight: colHealth.implicitHeight + 20

                ColumnLayout {
                    id: colHealth
                    width: parent.width
                    spacing: 14
                    HealthGroup { Layout.fillWidth: true }
                }
            }

            MujoFlickable {
                id: flickPref
                anchors.fill: parent
                visible: root.tab === "preferences"
                contentHeight: colPref.implicitHeight + 20

                ColumnLayout {
                    id: colPref
                    width: parent.width
                    spacing: 14
                    PreferencesGroup { Layout.fillWidth: true }
                }
            }

            MujoFlickable {
                id: flickApps
                anchors.fill: parent
                visible: root.tab === "apps"
                contentHeight: colApps.implicitHeight + 20

                ColumnLayout {
                    id: colApps
                    width: parent.width
                    spacing: 14
                    ApplicationsGroup { Layout.fillWidth: true }
                }
            }
        }
    }
}
