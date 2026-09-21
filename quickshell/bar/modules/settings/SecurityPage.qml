import QtQuick
import QtQuick.Layouts
import "../../theme"
import "../../components"

// Security & Privacy — what the machine trusts: verified boot, the encrypted vault,
// per-application sandboxing, stored credentials, AI assistants, and persistence privacy.
SettingsPage {
    id: root

    brand: "security"
    title: "Security & Privacy"
    subtitle: "Verified boot, progressive trust sandbox, credentials, AI assistants, persistence and privacy."
    isNixos: true
    tab: "integrity"

    sections: [
        { id: "integrity", label: "System Integrity", component: integritySection,
          description: "Verified boot, the encrypted vault, and how far the host is hardened." },
        { id: "trust", label: "Trust & Sandbox", component: trustSection,
          description: "Per-application isolation, and what each app is allowed to reach." },
        { id: "keyring", label: "Credentials", component: keyringSection,
          description: "Secrets held in the keyring, and what unlocks them." },
        { id: "ai", label: "AI Assistants", component: aiSection,
          description: "Which coding assistant runs, where it connects, and what it may touch." },
        { id: "persistence", label: "Persistence & Privacy", component: persistenceSection,
          description: "Persisted directories surviving reboot and local activity privacy." }
    ]

    aliases: ({ "vault": "integrity", "privacy": "persistence" })

    cardMap: ({
        "Verified Boot & System Integrity": "integrity",
        "LUKS2 Encrypted Storage Vault": "integrity",
        "Host Hardening & Memory Isolation": "integrity",
        "Progressive Trust & Sandboxing": "trust",
        "Progressive Trust & Isolation Engine": "trust",
        "Application Trust Registry": "trust",
        "Stored credentials": "keyring",
        "Add credential": "keyring",
        "Coding Assistant CLI": "ai",
        "API Provider & Endpoint": "ai",
        "API Credentials & Keyring": "ai",
        "Generation Parameters": "ai",
        "AI Privacy & Safety Guardrails": "ai",
        "Add Persistence Directory": "persistence",
        "Managed Persistence Paths": "persistence",
        "Currently Active Bind Mounts": "persistence",
        "Local Activity Trail": "persistence"
    })

    Component {
        id: integritySection
        ColumnLayout {
            spacing: 14
            SecurityGroup {
                Layout.fillWidth: true
                onOpenTrustRequested: root.tab = "trust"
            }
        }
    }
    Component { id: trustSection; ColumnLayout { spacing: 14; ApplicationsTrustTab { Layout.fillWidth: true } } }
    Component { id: keyringSection; ColumnLayout { spacing: 14; KeyringGroup { Layout.fillWidth: true } } }
    Component { id: aiSection; ColumnLayout { spacing: 14; AiGroup { Layout.fillWidth: true } } }
    Component {
        id: persistenceSection
        ColumnLayout {
            spacing: 14
            PersistenceGroup { Layout.fillWidth: true }
            PrivacyGroup { Layout.fillWidth: true }
        }
    }
}

