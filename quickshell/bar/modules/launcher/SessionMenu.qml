import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../theme"
import "../../components"
import "../../services"

// Bar power button + session menu (WP-10). Ends the right group. Lists the same
// Session actions as the `/` palette; dangerous ones (only present when
// launcher.enableDangerousActions is on) require a second click to confirm.
Item {
    id: root
    property var panelWindow
    property string screenName: ""

    readonly property string popupId: root.screenName + ":session"
    readonly property bool menuOpen: PopupCoordinator.activeId === root.popupId
    property string confirmId: ""
    implicitWidth: trigger.width
    implicitHeight: trigger.height

    onMenuOpenChanged: if (!menuOpen) root.confirmId = ""

    readonly property string iconStyle: SettingsBus.get("bar.session.iconStyle", "power")

    IconButton {
        id: trigger
        iconName: root.iconStyle === "user" ? "person" : (root.iconStyle === "logo" ? "fingerprint" : "power_settings_new")
        active: root.menuOpen
        iconColor: root.active ? Theme.accent : (root.hovered ? Theme.error : Theme.textSecondary)
        onClicked: PopupCoordinator.toggle(root.popupId)
    }


    PopupWindow {
        id: popup
        visible: root.menuOpen
        color: "transparent"
        anchor.window: root.panelWindow
        anchor.item: trigger
        anchor.edges: Theme.popupEdge | Edges.Right
        anchor.gravity: Theme.popupGravity | Edges.Left
        anchor.adjustment: PopupAdjustment.Slide

        implicitWidth: 240 + 32
        implicitHeight: content.implicitHeight + 28 + 32

        onClosed: PopupCoordinator.close(root.popupId)

        PopupCard {
            anchors.fill: parent
            open: root.menuOpen

            ColumnLayout {
                id: content
                anchors.fill: parent
                anchors.margins: 14
                spacing: 6

                SectionLabel { text: "Session"; accented: true }

                Repeater {
                    model: Session.all()
                    delegate: Rectangle {
                        required property var modelData
                        readonly property bool confirming: root.confirmId === modelData.id
                        Layout.fillWidth: true
                        implicitHeight: 38
                        radius: Theme.radiusMd
                        color: confirming ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.18)
                             : (hh.hovered ? Theme.surfaceHover : "transparent")
                        border.color: confirming ? Theme.error : "transparent"

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12; anchors.rightMargin: 12
                            spacing: 12
                            MaterialIcon {
                                iconName: parent.parent.confirming ? "priority_high" : modelData.icon
                                pixelSize: 18
                                color: parent.parent.confirming ? Theme.error : (modelData.danger ? Theme.text : Theme.textSecondary)
                            }
                            Text {
                                Layout.fillWidth: true
                                text: parent.parent.confirming ? "Confirm " + modelData.title + "?" : modelData.title
                                color: parent.parent.confirming ? Theme.error : Theme.text
                                font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeBody
                            }
                        }
                        HoverHandler { id: hh; cursorShape: Qt.PointingHandCursor }
                        TapHandler {
                            onTapped: {
                                if (modelData.danger && root.confirmId !== modelData.id) { root.confirmId = modelData.id; return }
                                PopupCoordinator.close(root.popupId)
                                Session.run(modelData.id)
                            }
                        }
                    }
                }
            }
        }
    }
}
