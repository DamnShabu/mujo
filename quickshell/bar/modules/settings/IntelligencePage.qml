import QtQuick
import QtQuick.Layouts
import "../../theme"
import "../../components"

// Intelligence & Connectivity — AI assistants & keyring credentials,
// notifications & DND, Mullvad VPN tunnel, and weather telemetry.
SettingsPage {
    brand: "ai"
    title: "Intelligence"
    subtitle: "Coding-agent CLIs, notifications, Mullvad VPN & weather telemetry."

    AiGroup {}
    NotificationsGroup {}
    NetworkGroup {}
    WeatherGroup {}
}
