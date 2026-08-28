//@ pragma UseQApplication
//@ pragma IconTheme Colloid-Dark
import QtQuick
import Quickshell
import "./modules/screenshot"

ShellRoot {
    id: root

    ScreenshotOverlay {
        id: overlay
        standalone: true
        Component.onCompleted: overlay.open()
    }
}
