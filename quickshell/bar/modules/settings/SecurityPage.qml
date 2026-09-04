import QtQuick
import QtQuick.Layouts
import "../../theme"
import "../../components"

// Security & AI — Verified boot, AI assistants, progressive trust sandbox,
// credentials, privacy & alerts.
Item {
    id: root

    property string brand: "security"
    property string title: "Security & AI"
    property string subtitle: "Verified boot, AI assistants, progressive trust sandbox, credentials, privacy & alerts."
    property bool isNixos: true

    property string tab: "integrity"   // integrity | ai | trust | keyring | privacy
    readonly property var tabIds: ["integrity", "ai", "trust", "keyring", "privacy", "vault", "notifications", "dnd", "persistence"]

    readonly property var cardTabMap: ({
        "Verified Boot & System Integrity": "integrity",
        "LUKS2 Encrypted Storage Vault": "integrity",
        "Host Hardening & Memory Isolation": "integrity",
        "Coding Assistant CLI": "ai",
        "API Provider & Endpoint": "ai",
        "AI Privacy & Safety Guardrails": "ai",
        "Progressive Trust & Isolation Engine": "trust",
        "Stored credentials": "keyring",
        "Managed Persistence Paths": "privacy",
        "Local Activity Trail": "privacy",
        "Session Lock": "privacy",
        "Behavior & Do Not Disturb": "privacy",
        "Sound Alerts & Placement": "privacy",
        "Per-App Mute Rules": "privacy"
    })

    function revealCard(name) {
        if (name === "vault") { root.tab = "integrity"; return true }
        if (name === "ai") { root.tab = "ai"; return true }
        if (name === "trust") { root.tab = "trust"; return true }
        if (name === "keyring") { root.tab = "keyring"; return true }
        if (name === "privacy" || name === "notifications" || name === "dnd" || name === "persistence") { root.tab = "privacy"; return true }
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
        if (root.tab === "integrity") return flickIntegrity
        if (root.tab === "ai") return flickAi
        if (root.tab === "trust") return flickTrust
        if (root.tab === "keyring") return flickKeyring
        if (root.tab === "privacy") return flickPrivacy
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
                { id: "integrity", label: "System Integrity",  icon: "verified_user" },
                { id: "ai",        label: "AI Assistants",     icon: "psychology" },
                { id: "trust",     label: "Trust & Sandbox",   icon: "shield" },
                { id: "keyring",   label: "Credentials",       icon: "password" },
                { id: "privacy",   label: "Privacy & Alerts",  icon: "security" }
            ]
            current: root.tab
            onSelected: function(id) { root.tab = id }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            MujoFlickable {
                id: flickIntegrity
                anchors.fill: parent
                visible: root.tab === "integrity"
                contentHeight: colIntegrity.implicitHeight + 20

                ColumnLayout {
                    id: colIntegrity
                    width: parent.width
                    spacing: 14
                    SecurityGroup { Layout.fillWidth: true }
                }
            }

            MujoFlickable {
                id: flickAi
                anchors.fill: parent
                visible: root.tab === "ai"
                contentHeight: colAi.implicitHeight + 20

                ColumnLayout {
                    id: colAi
                    width: parent.width
                    spacing: 14
                    AiGroup { Layout.fillWidth: true }
                }
            }

            MujoFlickable {
                id: flickTrust
                anchors.fill: parent
                visible: root.tab === "trust"
                contentHeight: colTrust.implicitHeight + 20

                ColumnLayout {
                    id: colTrust
                    width: parent.width
                    spacing: 14
                    ApplicationsTrustTab { Layout.fillWidth: true }
                }
            }

            MujoFlickable {
                id: flickKeyring
                anchors.fill: parent
                visible: root.tab === "keyring"
                contentHeight: colKeyring.implicitHeight + 20

                ColumnLayout {
                    id: colKeyring
                    width: parent.width
                    spacing: 14
                    KeyringGroup { Layout.fillWidth: true }
                }
            }

            MujoFlickable {
                id: flickPrivacy
                anchors.fill: parent
                visible: root.tab === "privacy"
                contentHeight: colPrivacy.implicitHeight + 20

                ColumnLayout {
                    id: colPrivacy
                    width: parent.width
                    spacing: 14
                    PersistenceGroup { Layout.fillWidth: true }
                    PrivacyGroup { Layout.fillWidth: true }
                    NotificationsGroup { Layout.fillWidth: true }
                }
            }
        }
    }
}
