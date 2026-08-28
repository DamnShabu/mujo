import QtQuick
import QtQuick.Layouts
import "../../theme"
import "../../components"
import "../../services"

// Bar trigger for the launcher. The launcher surface itself lives in
// Launcher.qml (a layer-shell overlay owned by shell.qml); this is just the
// button that toggles it via PopupCoordinator.
Rectangle {
    id: root
    property var panelWindow          // kept for Bar wiring compatibility
    property string screenName: ""
    property bool launcherOpen: false // (unused; overlay derives its own state)

    readonly property string iconStyle: SettingsBus.get("bar.launcher.icon", "search")
    readonly property bool showLabel: SettingsBus.get("bar.launcher.showLabel", false)
    readonly property string labelText: SettingsBus.get("bar.launcher.label", "Apps")

    readonly property bool active: PopupCoordinator.isLauncherOpen
        && (PopupCoordinator.launcherScreen === "" || PopupCoordinator.launcherScreen === root.screenName)

    implicitHeight: Theme.barHeight - 6
    implicitWidth: contentRow.implicitWidth + (root.showLabel ? 16 : 8)
    radius: Theme.radiusSm

    color: root.active ? Theme.accentDim
         : (hh.hovered ? Theme.surfaceHover : "transparent")
    border.color: root.active ? Theme.accent
                : (hh.hovered ? Theme.borderStrong : "transparent")
    border.width: 1

    Behavior on color { ColorAnimation { duration: Anim.d(Anim.fast) } }
    Behavior on border.color { ColorAnimation { duration: Anim.d(Anim.fast) } }

    RowLayout {
        id: contentRow
        anchors.centerIn: parent
        spacing: 6

        BrandIcon {
            visible: root.iconStyle === "mujo"
            brand: "mujo"
            size: 16
            Layout.alignment: Qt.AlignVCenter
        }

        MaterialIcon {
            visible: root.iconStyle !== "mujo"
            iconName: {
                if (root.iconStyle === "apps") return "apps"
                if (root.iconStyle === "menu") return "menu"
                if (root.iconStyle === "dots") return "more_horiz"
                return "search"
            }
            pixelSize: 16
            color: root.active ? Theme.accent : (hh.hovered ? Theme.text : Theme.textSecondary)
            Layout.alignment: Qt.AlignVCenter
            Behavior on color { ColorAnimation { duration: Anim.d(Anim.fast) } }
        }

        Text {
            visible: root.showLabel
            text: root.labelText
            color: root.active ? Theme.accent : (hh.hovered ? Theme.text : Theme.textSecondary)
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            font.bold: true
            Layout.alignment: Qt.AlignVCenter
            Behavior on color { ColorAnimation { duration: Anim.d(Anim.fast) } }
        }
    }

    HoverHandler { id: hh; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: PopupCoordinator.toggleLauncher(root.screenName) }
}
