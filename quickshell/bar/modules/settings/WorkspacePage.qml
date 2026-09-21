import QtQuick
import QtQuick.Layouts
import "../../theme"
import "../../components"

// Workspace — the desktop chrome: the bar, the notch, the overlay widgets,
// notifications, live weather telemetry and the staging shelf.
SettingsPage {
    id: root

    brand: "desktop"
    title: "Workspace"
    subtitle: "Desktop bar layout, dynamic island notch, overlay widgets, notifications, weather and staging shelf."
    tab: "bar"

    sections: [
        { id: "bar", label: "Desktop Bar", component: barSection,
          description: "Where the bar sits, how big it is, and which modules fill its three zones." },
        { id: "island", label: "Dynamic Island", component: islandSection,
          description: "The notch at the top of the screen, and what makes it expand." },
        { id: "widgets", label: "Overlay Widgets", component: widgetsSection,
          description: "Clocks, meters and panels that live on the desktop behind your windows." },
        { id: "notifications", label: "Notifications & DND", component: notificationsSection,
          description: "Toast banners, Do Not Disturb, sound alerts, placement and per-app rules." },
        { id: "weather", label: "Weather", component: weatherSection,
          description: "Live atmospheric telemetry, 5-day forecast, location search and display units." },
        { id: "shelf", label: "Shelf", component: shelfSection,
          description: "The screen-edge drop zone for staging files between windows." }
    ]

    aliases: ({ "dnd": "notifications" })

    cardMap: ({
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
        "Behavior & Do Not Disturb": "notifications",
        "Sound Alerts & Placement": "notifications",
        "Per-App Mute Rules": "notifications",
        "Notification Testing Lab": "notifications",
        "Current Atmospheric Conditions": "weather",
        "5-Day Forecast": "weather",
        "Location & Geocoding": "weather",
        "Display Preferences & Frequency": "weather",
        "Shelf File Staging Drop Zone": "shelf"
    })

    Component { id: barSection; ColumnLayout { spacing: 14; BarGroup { Layout.fillWidth: true } } }
    Component { id: islandSection; ColumnLayout { spacing: 14; IslandGroup { Layout.fillWidth: true } } }
    Component { id: widgetsSection; ColumnLayout { spacing: 14; WidgetsGroup { Layout.fillWidth: true } } }
    Component { id: notificationsSection; ColumnLayout { spacing: 14; NotificationsGroup { Layout.fillWidth: true } } }
    Component { id: weatherSection; ColumnLayout { spacing: 14; WeatherGroup { Layout.fillWidth: true } } }
    Component { id: shelfSection; ColumnLayout { spacing: 14; ShelfGroup { Layout.fillWidth: true } } }
}

