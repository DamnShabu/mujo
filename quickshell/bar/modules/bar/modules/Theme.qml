pragma Singleton
import QtQuick

QtObject {
    // --- Colors ---
    property color accent: "#e6b450"
    property color bg: "#0d1017"
    property color surface: "#151922"
    property color surfaceHover: "#1c2230"
    property color border: "#1e2530"
    property color borderInteractive: "#2a3545"
    property color text: "#bfbab4"
    property color textSecondary: "#6e7681"
    property color workspaceActive: "#e6b450"
    property color workspaceInactive: "#3a4555"
    property color error: "#e63030"

    // --- Bar ---
    property int barHeight: 40
    property int barPadding: 10

    // --- Clock ---
    property bool clock24h: true
    property bool clockShowSeconds: false
    property bool clockShowDate: true
    property int clockFontSize: 13

    // --- Launcher ---
    property int launcherWidth: 520
    property int launcherHeight: 400
    property real launcherOpacity: 1.0
    property string launcherWallpaper: ""

    // --- Workspace ---
    property int workspacePillSize: 15
    property int workspacePillRadius: 5
    property int workspaceSpacing: 5

    // --- Widget visibility ---
    property bool showClockPill: true
    property bool showWorkspaces: true
    property bool showSystemTray: true
    property bool showWeather: true

    // --- Weather config ---
    property real weatherLat: 42.4501
    property real weatherLon: -73.2454
    property bool weatherCelsius: false
    property string weatherCity: ""

    // --- Theme name ---
    property string themeName: "Default"
}
