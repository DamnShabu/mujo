pragma Singleton
import QtQuick

QtObject {
    property string activeId: ""
    property string launcherScreen: ""

    readonly property bool hasActivePopup: activeId !== ""
    readonly property bool isLauncherOpen: activeId.endsWith(":launcher") || activeId === "launcher"

    function open(id) {
        activeId = id
    }

    function close(id) {
        if (id === undefined || activeId === id) activeId = ""
    }

    function closeAll() {
        activeId = ""
    }

    function toggle(id) {
        activeId = (activeId === id) ? "" : id
    }

    function openLauncher(screen) {
        launcherScreen = screen || ""
        activeId = (screen ? screen + ":" : "") + "launcher"
    }

    function closeLauncher() {
        if (isLauncherOpen) activeId = ""
    }

    function toggleLauncher(screen) {
        if (isLauncherOpen) {
            closeLauncher()
        } else {
            openLauncher(screen)
        }
    }
}
