import Quickshell
import QtQuick
import Quickshell.Widgets

Item {
    id: root
    property var panelWindow
    property bool launcherOpen: false
    property string wallpaperPath: Theme.launcherWallpaper || Quickshell.env("QSSHELL_WALLPAPER") || ""
    property string cityName: Theme.weatherCity
    property var weather
    width: 150
    height: 30

    onLauncherOpenChanged: {
        if (launcherOpen) openLauncher()
        else closeLauncher()
    }

    ClockPill {
        id: clock
        anchors.fill: parent
        weather: root.weather
        visible: Theme.showClockPill
        scale: root.pillOpen ? 0.3 : 1
        opacity: root.pillOpen ? 0 : 1
        Behavior on scale { NumberAnimation { duration: 63; easing.type: Easing.InQuad } }
        Behavior on opacity { NumberAnimation { duration: 63; easing.type: Easing.InQuad } }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: launcherPopup.open ? closeLauncher() : openLauncher()
    }

    property bool pillOpen: false

    Component.onCompleted: root.panelWindow.focusable = true

    function openLauncher() {
        if (launcherPopup.open) return
        pillOpen = true
        launcherPopup.open = true
        launcherPopup.visible = true
    }

    function closeLauncher() {
        if (!launcherPopup.open) return
        launcherPopup.open = false
        pillOpen = false
        hideTimer.restart()
    }

    PopupWindow {
        id: launcherPopup
        visible: false
        color: "transparent"
        grabFocus: true
        anchor.window: root.panelWindow
        anchor.rect.x: (root.panelWindow.width - implicitWidth) / 2
        anchor.rect.y: (root.panelWindow.screen.height - implicitHeight) / 2

        implicitWidth: launcher.baseWidth
        implicitHeight: launcher.baseHeight

        property bool open: false

        onVisibleChanged: {
            if (visible) {
                open = true
                launcher.focusSearch()
                focusTimer.restart()
            } else {
                root.pillOpen = false
            }
        }

        LauncherBody {
            id: launcher
            anchors.fill: parent
            opacity: Theme.launcherOpacity
            open: launcherPopup.open
            weather: root.weather
            wallpaperPath: root.wallpaperPath
            cityName: root.cityName
            onRequestClose: root.closeLauncher()
        }

        Timer {
            id: focusTimer
            interval: 30
            onTriggered: { if (launcherPopup.visible) launcher.focusSearch() }
          } // 30ms delay to ensure focus after open

        Timer {
            id: hideTimer
            interval: 100
            onTriggered: launcherPopup.visible = false
          } // 100ms delay before hiding popup
    }
}
