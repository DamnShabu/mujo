import QtQuick
import QtQuick.Layouts
import "../../theme"
import "../../components"

// Appearance & Personalization — Color presets, custom accent overrides,
// surface glassmorphism transparency, and motion dynamics.
SettingsPage {
    brand: "appearance"
    title: "Appearance"
    subtitle: "Theme presets, accent color overrides, surface opacity & motion architecture."

    ThemeGroup {}
    MotionGroup {}
}
