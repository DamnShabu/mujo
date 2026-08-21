//@ pragma UseQApplication
//@ pragma IconTheme Colloid-Dark
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Niri
import "./modules/bar/modules"

ShellRoot{
    id: root

    Niri {
        id: wm
        Component.onCompleted: connect()

        onConnected: console.info("Connected to niri")
        onErrorOccurred: function(error) {
            console.error("Niri error:", error)
        }
    }

    function workspaceIsFocused(ws) {
        if (!ws) return false
        if (ws.isFocused !== undefined) return !!ws.isFocused
        if (ws.isActive !== undefined) return !!ws.isActive
        return false
    }

    function focusedScreenName() {
        if (!wm || !wm.workspaces) return ""
        for (var i = 0; i < wm.workspaces.count; i++) {
            var ws = wm.workspaces.get(i)
            if (workspaceIsFocused(ws)) return ws.output || ""
        }
        return ""
    }

    property bool launcherOpen: false
    property string launcherScreen: ""

    function focusedScreen() {
        if (!wm || !wm.workspaces) return null
        var screens = Quickshell.screens || []
        for (var i = 0; i < wm.workspaces.count; i++) {
            var ws = wm.workspaces.get(i)
            if (workspaceIsFocused(ws)) {
                for (var j = 0; j < screens.length; j++) {
                    if (screens[j].name === ws.output) return screens[j]
                }
            }
        }
        return null
    }

    IpcHandler {
        target: "launcher"

        function toggle(): void {
            if (root.launcherOpen) {
                root.launcherOpen = false
            } else {
                root.launcherScreen = root.focusedScreenName()
                root.launcherOpen = true
            }
        }

        function open(): void {
            root.launcherScreen = root.focusedScreenName()
            root.launcherOpen = true
        }

        function close(): void {
            root.launcherOpen = false
        }
    }

    IpcHandler {
        target: "settings"

        function toggle(): void {
            if (settingsMenu.visible) settingsMenu.close()
            else settingsMenu.open()
        }

        function open(): void {
            settingsMenu.open()
        }

        function close(): void {
            settingsMenu.close()
        }
    }

    Process {
        id: superMonitor
        command: ["perl", Qt.resolvedUrl("super-monitor.pl").toString().slice(7)]
        running: true
        onRunningChanged: if (!running) restartTimer.restart()
    }

    Timer {
        id: restartTimer
        interval: 1000
        onTriggered: superMonitor.running = true
    }

    Process {
        id: configLoad
        command: ["sh", "-c", "cat \"$1\" 2>/dev/null || echo '{}'", "_", Quickshell.env("HOME") + "/.config/qsshell/settings.json"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var obj = JSON.parse(this.text)
                    var keys = Object.keys(obj)
                    console.log("Settings: loaded config with " + keys.length + " keys:", keys.join(", "))
                    if (keys.length === 0) console.log("Settings: config empty or missing, using defaults")
                    var map = {
                        accent: "accent", bg: "bg", surface: "surface", surfaceHover: "surfaceHover",
                        border: "border", borderInteractive: "borderInteractive",
                        text: "text", textSecondary: "textSecondary",
                        workspaceActive: "workspaceActive", workspaceInactive: "workspaceInactive",
                        barHeight: "barHeight", barPadding: "barPadding",
                        clock24h: "clock24h", clockShowSeconds: "clockShowSeconds",
                        clockShowDate: "clockShowDate", clockFontSize: "clockFontSize",
                        launcherWidth: "launcherWidth", launcherHeight: "launcherHeight",
                        launcherOpacity: "launcherOpacity", launcherWallpaper: "launcherWallpaper",
                        workspacePillSize: "workspacePillSize", workspacePillRadius: "workspacePillRadius",
                        workspaceSpacing: "workspaceSpacing",
                        showClockPill: "showClockPill", showWorkspaces: "showWorkspaces",
                        showSystemTray: "showSystemTray", showWeather: "showWeather",
                        weatherLat: "weatherLat", weatherLon: "weatherLon",
                        weatherCelsius: "weatherCelsius", weatherCity: "weatherCity",
                        themeName: "themeName"
                    }
                    for (var k in map) {
                        if (obj[k] !== undefined) Theme[map[k]] = obj[k]
                    }
                } catch (e) {
                    console.log("Config: no valid settings.json found, using defaults")
                }
            }
        }
    }

    Component.onCompleted: configLoad.running = true

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: panelWindow
            property var modelData
            property string screenName: modelData.name
            property bool launcherOpen: root.launcherOpen && root.launcherScreen === modelData.name
            visible: true
            color: "transparent"
            screen: modelData
            anchors {
                top: true
                left: true
                right: true
                bottom: false
            }
            implicitHeight: Theme.barHeight

            Component.onCompleted: heightAnimation.start()

            NumberAnimation {
                id: heightAnimation
                target: panelWindow
                property: "implicitHeight"
                from: 0
                to: Theme.barHeight
                duration: 200
                easing.type: Easing.OutCubic
            }

            Rectangle {
                anchors.fill: parent
                color: "transparent"

                // ALIGN LEFT
                RowLayout {
                    anchors {
                        verticalCenter: parent.verticalCenter
                        left: parent.left
                        margins: Theme.barPadding
                    }
                    Workspaces {
                        niri: wm
                        screenName: panelWindow.screenName
                        visible: Theme.showWorkspaces
                    }
                }
                // ALIGN CENTER
                RowLayout {
                    anchors {
                        verticalCenter: parent.verticalCenter
                        centerIn: parent
                    }
                    DynamicIsland {
                        panelWindow: panelWindow
                        launcherOpen: panelWindow.launcherOpen
                        weather: sharedWeather
                    }
                }
                // ALIGN RIGHT
                RowLayout {
                    anchors {
                        verticalCenter: parent.verticalCenter
                        right: parent.right
                        rightMargin: Theme.barPadding
                    }
                    SystemTray {
                        panelWindow: panelWindow
                        visible: Theme.showSystemTray
                    }

                    Rectangle {
                        id: settingsBtn
                        width: 30
                        height: 30
                        radius: 5
                        color: settingsHover.hovered ? Theme.surfaceHover : Theme.bg
                        border.color: settingsMenu.visible ? Theme.accent : Theme.border

                        MaterialIcon {
                            iconName: "settings"
                            pixelSize: 18
                            anchors.centerIn: parent
                            rotation: settingsMenu.visible ? 90 : 0
                            Behavior on rotation { NumberAnimation { duration: 200; easing.type: Easing.OutQuad } }
                        }

                        HoverHandler { id: settingsHover }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (settingsMenu.visible) settingsMenu.close()
                                else settingsMenu.open()
                            }
                        }
                    }
                }
            }
        }
    }

    SettingsMenu {
        id: settingsMenu
        weather: sharedWeather
        onVisibleChanged: {
            if (visible) {
                var s = root.focusedScreen()
                if (s) settingsMenu.screen = s
            }
        }
    }

    WeatherIcon {
        id: sharedWeather
        visible: false
    }
}
