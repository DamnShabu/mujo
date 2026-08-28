import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import "../../theme"
import "../../components"
import "../../services"

// Bottom-center "launching…" indicator. One per screen; shows on the screen the
// launch was initiated from (Launch.activeScreen). Slides up + fades in on show,
// slides down + fades out on hide. Dismissed by Launch once the launched app's
// window appears in niri (or by a watchdog timer if it never does). Kept mapped
// through the exit animation so the fade-out is visible.
PanelWindow {
    id: fb
    required property var modelData
    screen: modelData

    readonly property bool shown: Launch.showing
        && (Launch.activeScreen === "" || Launch.activeScreen === modelData.name)

    WlrLayershell.namespace: "qs-launch-feedback"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    // Stay mapped while the pill is still visibly animating out.
    visible: shown || pill.opacity > 0.01

    anchors { bottom: true }
    margins.bottom: 54
    implicitWidth: Math.max(1, pill.width)
    implicitHeight: pill.height + 28

    function iconSource(name) {
        if (!name) return ""
        if (name.indexOf("://") >= 0) return name
        if (name.charAt(0) === "/") return "file://" + name
        return Quickshell.iconPath(name, "application-x-executable")
    }

    // Soft shadow so the pill reads as elevated over the wallpaper.
    Rectangle {
        id: shadowSrc
        anchors.centerIn: pill
        width: pill.width
        height: pill.height
        radius: pill.radius
        color: "#000000"
        visible: false
        layer.enabled: true
    }
    MultiEffect {
        anchors.fill: shadowSrc
        source: shadowSrc
        autoPaddingEnabled: true
        shadowEnabled: true
        shadowColor: "#000000"
        shadowBlur: 0.9
        shadowVerticalOffset: 6
        shadowOpacity: 0.45
        opacity: pill.opacity
    }

    Rectangle {
        id: pill
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 8

        radius: Theme.radiusLg
        color: Theme.bg
        border.color: Theme.border
        implicitWidth: row.implicitWidth + 32
        implicitHeight: 44

        opacity: fb.shown ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Anim.d(Anim.enter); easing.type: Anim.easeEnter } }

        transform: Translate {
            y: fb.shown ? 0 : 14
            Behavior on y { NumberAnimation { duration: Anim.d(Anim.slow); easing.type: Anim.easeStandard } }
        }

        Row {
            id: row
            anchors.centerIn: parent
            spacing: 11

            Spinner {
                anchors.verticalCenter: parent.verticalCenter
                size: 17
                color: Theme.accent
                spinning: fb.shown
            }

            IconImage {
                anchors.verticalCenter: parent.verticalCenter
                width: 22
                height: 22
                source: fb.iconSource(Launch.activeIcon)
                visible: Launch.activeIcon !== ""
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1

                Text {
                    text: "Launching"
                    color: Theme.textSecondary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeLabel - 1
                    font.letterSpacing: Theme.labelSpacing
                    font.capitalization: Font.AllUppercase
                }
                Text {
                    text: Launch.activeName
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeTitle
                    font.bold: true
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }
            }
        }
    }
}
