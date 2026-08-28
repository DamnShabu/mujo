import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import "../../theme"
import "../../components"

// LauncherFolderCard: Bespoke Folder representation for Groups in Grid View.
// Features a signature 2x2 mini application icon preview, folder iconography,
// count badge, and smooth spring hover/selection animations.
Item {
    id: root

    property var group: null
    property bool selected: false
    property string screenName: ""
    signal opened(var group)

    function iconSource(name) {
        if (!name) return ""
        if (name.indexOf("://") >= 0) return name
        if (name.charAt(0) === "/") return "file://" + name
        return Quickshell.iconPath(name, "application-x-executable")
    }

    function appIconForId(id) {
        var a = (DesktopEntries.applications ? DesktopEntries.applications.values : []) || []
        for (var i = 0; i < a.length; i++) {
            if (a[i] && (a[i].id === id || a[i].name === id)) {
                return a[i].icon || ""
            }
        }
        return ""
    }

    readonly property var previewIcons: {
        if (!root.group || !root.group.apps) return []
        var out = []
        var appIds = root.group.apps
        for (var i = 0; i < appIds.length && out.length < 4; i++) {
            var iconName = root.appIconForId(appIds[i])
            if (iconName) out.push(iconName)
        }
        return out
    }

    Rectangle {
        id: card
        anchors.fill: parent
        anchors.margins: 4
        radius: Theme.radiusMd
        color: root.selected
               ? (Anim.ambient ? Theme.withAlpha(Theme.accent, 0.18) : Theme.accentDim)
               : (cardHover.hovered ? Theme.surfaceHover : Theme.surface)
        border.color: root.selected
                      ? Theme.accent
                      : (cardHover.hovered ? Theme.borderStrong : Theme.border)
        border.width: 1

        scale: Anim.microInteractions
               ? (root.selected ? 1.04 : (cardHover.hovered ? 1.02 : 1.0))
               : 1.0

        Behavior on scale {
            NumberAnimation {
                duration: Anim.d(Anim.fast)
                easing.type: Anim.easeStandard
            }
        }
        Behavior on color { ColorAnimation { duration: Anim.d(Anim.fast) } }
        Behavior on border.color { ColorAnimation { duration: Anim.d(Anim.fast) } }

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 5
            width: parent.width - 10

            // 2x2 Mini Preview Tile Frame
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 38
                Layout.preferredHeight: 38
                radius: Theme.radiusSm
                color: Theme.surfaceActive
                border.color: cardHover.hovered || root.selected ? Theme.withAlpha(Theme.accent, 0.4) : Theme.border
                border.width: 1
                clip: true

                // When apps exist: 2x2 preview grid
                Grid {
                    anchors.centerIn: parent
                    columns: 2
                    spacing: 2
                    visible: root.previewIcons.length > 0

                    Repeater {
                        model: root.previewIcons
                        delegate: Item {
                            required property var modelData
                            width: 15
                            height: 15

                            IconImage {
                                anchors.centerIn: parent
                                source: root.iconSource(modelData)
                                width: 14
                                height: 14
                            }
                        }
                    }
                }

                // Fallback icon when no preview apps are available
                MaterialIcon {
                    anchors.centerIn: parent
                    visible: root.previewIcons.length === 0
                    iconName: root.group ? (root.group.icon || "folder") : "folder"
                    pixelSize: 20
                    color: Theme.accent
                }

                // Folder Badge Overlay at bottom-right
                Rectangle {
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: -1
                    width: 14
                    height: 14
                    radius: 7
                    color: Theme.surface
                    border.color: Theme.accent
                    border.width: 1
                    visible: root.previewIcons.length > 0

                    MaterialIcon {
                        anchors.centerIn: parent
                        iconName: root.group ? (root.group.icon || "folder") : "folder"
                        pixelSize: 8
                        color: Theme.accent
                    }
                }
            }

            // Group Title
            Text {
                Layout.fillWidth: true
                text: root.group ? root.group.name : ""
                color: root.selected ? Theme.text : Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                font.bold: root.selected
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                maximumLineCount: 1
            }

            // Group Subtitle / App Count Pill
            Text {
                Layout.fillWidth: true
                text: {
                    var n = (root.group && root.group.apps) ? root.group.apps.length : 0
                    return n + " item" + (n === 1 ? "" : "s")
                }
                color: root.selected ? Theme.accent : Theme.textDim
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeLabel - 1
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                maximumLineCount: 1
            }
        }

        HoverHandler { id: cardHover; cursorShape: Qt.PointingHandCursor }
        TapHandler {
            onTapped: {
                if (root.group) root.opened(root.group)
            }
        }
    }
}
