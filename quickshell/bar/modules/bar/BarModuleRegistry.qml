pragma Singleton
import QtQuick
import "../notifications"
import "../launcher"

QtObject {
    id: registry

    readonly property var allModules: [
        { id: "launcher",     name: "App Launcher",        icon: "apps",             category: "navigation", defaultSlot: "left" },
        { id: "workspaces",   name: "Workspace Switcher",  icon: "view_carousel",    category: "navigation", defaultSlot: "left" },
        { id: "activeWindow", name: "Active Window Title", icon: "tab",              category: "navigation", defaultSlot: "left" },
        { id: "clock",        name: "Clock & Calendar",    icon: "schedule",         category: "system",     defaultSlot: "center" },
        { id: "media",        name: "Media Player",        icon: "play_circle",      category: "media",      defaultSlot: "center" },
        { id: "weather",      name: "Weather Status",      icon: "wb_sunny",         category: "info",       defaultSlot: "center" },
        { id: "cava",         name: "Audio Visualizer",    icon: "graphic_eq",       category: "media",      defaultSlot: "center" },
        { id: "volume",       name: "Audio Volume",        icon: "volume_up",        category: "hardware",   defaultSlot: "right" },
        { id: "network",      name: "Network & Wi-Fi",     icon: "wifi",             category: "hardware",   defaultSlot: "right" },
        { id: "bluetooth",    name: "Bluetooth",           icon: "bluetooth",        category: "hardware",   defaultSlot: "right" },
        { id: "battery",      name: "Battery & Power",     icon: "battery_full",     category: "hardware",   defaultSlot: "right" },
        { id: "notifications",name: "Notification Center", icon: "notifications",    category: "system",     defaultSlot: "right" },
        { id: "tray",         name: "System Tray",         icon: "widgets",          category: "system",     defaultSlot: "right" },
        { id: "llm",          name: "AI Tokens / Agent",   icon: "psychology",       category: "ai",         defaultSlot: "right" },
        { id: "session",      name: "Session / Power",     icon: "power_settings_new",category: "system",    defaultSlot: "right" },
        { id: "divider",      name: "Visual Separator",    icon: "more_vert",        category: "layout",     defaultSlot: "none" },
        { id: "spacer",       name: "Flexible Spacer",     icon: "space_bar",        category: "layout",     defaultSlot: "none" }
    ]

    function metadata(id) {
        for (var i = 0; i < allModules.length; i++) {
            if (allModules[i].id === id) return allModules[i]
        }
        return { id: id, name: id, icon: "widgets", category: "custom", defaultSlot: "none" }
    }

    // Component references
    readonly property Component launcherComp: Component { LauncherPill {} }
    readonly property Component workspacesComp: Component { Workspaces {} }
    readonly property Component activeWinComp: Component { ActiveWindowPill {} }
    readonly property Component clockComp: Component { ClockPill {} }
    readonly property Component mediaComp: Component { MediaPill {} }
    readonly property Component weatherComp: Component { WeatherPill {} }
    readonly property Component cavaComp: Component { CavaPill {} }
    readonly property Component volumeComp: Component { VolumeMenu {} }
    readonly property Component networkComp: Component { NetworkMenu {} }
    readonly property Component bluetoothComp: Component { BluetoothMenu {} }
    readonly property Component batteryComp: Component { BatteryMenu {} }
    readonly property Component notifComp: Component { NotificationMenu {} }
    readonly property Component trayComp: Component { SystemTray {} }
    readonly property Component llmComp: Component { LlmTrackerMenu {} }
    readonly property Component sessionComp: Component { SessionMenu {} }
    readonly property Component dividerComp: Component { DividerPill {} }
    readonly property Component spacerComp: Component { SpacerPill {} }

    function getComponent(id) {
        switch (id) {
            case "launcher":     return launcherComp
            case "workspaces":   return workspacesComp
            case "activeWindow": return activeWinComp
            case "clock":        return clockComp
            case "media":        return mediaComp
            case "weather":      return weatherComp
            case "cava":         return cavaComp
            case "volume":       return volumeComp
            case "network":      return networkComp
            case "bluetooth":    return bluetoothComp
            case "battery":      return batteryComp
            case "notifications":return notifComp
            case "tray":         return trayComp
            case "llm":          return llmComp
            case "session":      return sessionComp
            case "divider":      return dividerComp
            case "spacer":       return spacerComp
            default:
                console.warn("BarModuleRegistry: Unknown module id:", id)
                return null
        }
    }
}
