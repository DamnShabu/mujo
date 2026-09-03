import QtQuick
import QtQuick.Layouts
import "../../theme"
import "../../components"

// Security & Storage — Verified boot, encrypted vault, keyring credentials,
// progressive trust, impermanence persistence, and privacy protections.
SettingsPage {
    brand: "security"
    title: "Security & Storage"
    subtitle: "Verified boot, LUKS2 vault, credentials, trust sandbox, persistence & privacy."
    isNixos: true

    SecurityGroup {}
    KeyringGroup {}
    // Already a column of its own MujoCards, so it needs the width, not a
    // wrapper card — nesting one inside another double-frames it.
    ApplicationsTrustTab { Layout.fillWidth: true }
    PersistenceGroup {}
    PrivacyGroup {}
}
