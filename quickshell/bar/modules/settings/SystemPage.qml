import QtQuick
import QtQuick.Layouts
import "../../theme"
import "../../components"

// System Host & Operations — NixOS generations & rebuilds, health sentinel,
// storage cleaner, system preferences, and applications/integrations.
SettingsPage {
    brand: "system"
    title: "System"
    subtitle: "NixOS generation management, host health, storage optimizer, preferences & applications."
    isNixos: true

    NixosHostGroup {}
    HealthGroup {}
    PreferencesGroup {}
    ApplicationsGroup {}
}
