import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import "../../theme"
import "../../components"
import "../../services"

// LauncherResult: High-fidelity application search result delegate for Mujo (無常).
// Features rich icon badge framing, category chips, executable metadata,
// dynamic keyboard selection luminescence, micro-animations, and favorite status.
// Clicks on the favorite star toggle favorite state without launching or closing.
Rectangle {
    id: root

    property var entry: null
    property bool highlighted: false
    property string query: ""
    signal launchRequested(var entry)
    signal favoriteToggled(string id)
    signal selectRequested()

    readonly property var favorites: SettingsBus.get("apps.favorites", [])
    readonly property bool isFavorited: entry && entry.id ? favorites.indexOf(entry.id) >= 0 : false

    function iconSource(name) {
        if (!name) return ""
        if (name.indexOf("://") >= 0) return name
        if (name.charAt(0) === "/") return "file://" + name
        return Quickshell.iconPath(name, "application-x-executable")
    }

    function primaryCategory(entry) {
        if (!entry || !entry.categories || entry.categories.length === 0) return ""
        var c = entry.categories
        for (var i = 0; i < c.length; i++) {
            var cat = String(c[i])
            if (cat === "WebBrowser" || cat === "Network") return "Web"
            if (cat === "Development" || cat === "IDE") return "Dev"
            if (cat === "AudioVideo" || cat === "Audio" || cat === "Video" || cat === "Music") return "Media"
            if (cat === "Graphics" || cat === "Photography") return "Graphics"
            if (cat === "Game") return "Game"
            if (cat === "Office" || cat === "TextEditor") return "Office"
            if (cat === "System" || cat === "Settings" || cat === "Security") return "System"
            if (cat === "Utility" || cat === "Accessories") return "Utility"
        }
        return ""
    }

    readonly property string categoryLabel: primaryCategory(entry)

    width: parent ? parent.width : 0
    implicitHeight: 50
    radius: Theme.radiusMd

    // Surface styling with luminous aura on selection
    color: root.highlighted
           ? (Anim.ambient ? Theme.withAlpha(Theme.accent, 0.16) : Theme.accentDim)
           : (rowHover.hovered ? Theme.surfaceHover : "transparent")
    border.color: root.highlighted ? Theme.withAlpha(Theme.accent, 0.55) : (rowHover.hovered ? Theme.border : "transparent")
    border.width: 1

    Behavior on color { ColorAnimation { duration: Anim.d(Anim.fast) } }
    Behavior on border.color { ColorAnimation { duration: Anim.d(Anim.fast) } }

    // Left Active Selection Indicator Bar
    Rectangle {
        anchors.left: parent.left
        anchors.leftMargin: 4
        anchors.verticalCenter: parent.verticalCenter
        width: 3
        height: root.highlighted ? 24 : 0
        radius: 1.5
        color: Theme.accent
        opacity: root.highlighted ? 1.0 : 0.0

        Behavior on height {
            NumberAnimation {
                duration: Anim.d(Anim.fast)
                easing.type: Anim.easeStandard
            }
        }
        Behavior on opacity { NumberAnimation { duration: Anim.d(Anim.fast) } }
    }

    // Main Interactive Click Area for Launching (excludes right indicators)
    MouseArea {
        id: mainLaunchArea
        // rightControls lives inside the RowLayout, so it is not a sibling and
        // cannot be anchored to. Reserve its width via the margin instead —
        // 12 (RowLayout rightMargin) + its width + 4 gap.
        anchors.fill: parent
        anchors.rightMargin: rightControls.width + 16
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        // Only signal on a real change — otherwise every mouse-move pixel emits.
        onPositionChanged: if (!root.highlighted) root.selectRequested()
        onClicked: {
            if (root.entry) root.launchRequested(root.entry)
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 12

        // Icon container with elevated backdrop tile
        Rectangle {
            Layout.preferredWidth: 34
            Layout.preferredHeight: 34
            Layout.alignment: Qt.AlignVCenter
            radius: Theme.radiusSm
            color: root.highlighted ? Theme.withAlpha(Theme.accent, 0.22) : Theme.surface
            border.color: root.highlighted ? Theme.withAlpha(Theme.accent, 0.4) : Theme.border
            border.width: 1

            IconImage {
                anchors.centerIn: parent
                source: root.entry ? root.iconSource(root.entry.icon) : ""
                width: 24
                height: 24
                visible: root.entry && root.entry.icon !== ""
            }

            MaterialIcon {
                anchors.centerIn: parent
                visible: !root.entry || root.entry.icon === ""
                iconName: "apps"
                pixelSize: 18
                color: root.highlighted ? Theme.accent : Theme.textSecondary
            }
        }

        // Title and Subtitle / Metadata
        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 2

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: root.entry ? root.entry.name : ""
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeBody + 1
                    font.bold: root.highlighted
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                // Category pill
                Rectangle {
                    visible: root.categoryLabel !== ""
                    implicitWidth: catTxt.implicitWidth + 10
                    implicitHeight: 18
                    radius: Theme.radiusSm
                    color: root.highlighted ? Theme.withAlpha(Theme.accent, 0.24) : Theme.surfaceActive
                    border.color: root.highlighted ? Theme.withAlpha(Theme.accent, 0.4) : Theme.borderStrong

                    Text {
                        id: catTxt
                        anchors.centerIn: parent
                        text: root.categoryLabel
                        color: root.highlighted ? Theme.accent : Theme.textSecondary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeLabel
                        font.bold: true
                    }
                }
            }

            // Subtitle: generic name or executable string
            Text {
                text: {
                    if (!root.entry) return ""
                    if (root.entry.genericName && root.entry.genericName !== "" && root.entry.genericName !== root.entry.name) {
                        return root.entry.genericName
                    }
                    if (root.entry.comment && root.entry.comment !== "") {
                        return root.entry.comment
                    }
                    if (root.entry.execString && root.entry.execString !== "") {
                        return root.entry.execString
                    }
                    return ""
                }
                color: root.highlighted ? Theme.textSecondary : Theme.textDim
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                elide: Text.ElideRight
                Layout.fillWidth: true
                visible: text !== ""
            }
        }

        // Right side indicators (Favorite star & Enter Keycap)
        RowLayout {
            id: rightControls
            Layout.alignment: Qt.AlignVCenter
            spacing: 6

            // Dedicated Favorite toggle star
            Item {
                implicitWidth: 26
                implicitHeight: 26
                visible: root.isFavorited || rowHover.hovered || root.highlighted
                opacity: root.isFavorited ? 1.0 : (starHover.hovered ? 0.9 : 0.45)

                Rectangle {
                    anchors.fill: parent
                    radius: 13
                    color: starHover.hovered ? Theme.surfaceActive : "transparent"
                }

                MaterialIcon {
                    anchors.centerIn: parent
                    iconName: root.isFavorited ? "star" : "star_outline"
                    pixelSize: 16
                    color: root.isFavorited ? Theme.warning : (starHover.hovered ? Theme.text : Theme.textDim)
                    scale: starHover.hovered ? 1.25 : 1.0
                    Behavior on scale { NumberAnimation { duration: Anim.d(Anim.fast); easing.type: Anim.easeStandard } }
                }

                HoverHandler { id: starHover; cursorShape: Qt.PointingHandCursor }
                TapHandler {
                    onTapped: {
                        if (root.entry && root.entry.id) {
                            root.favoriteToggled(root.entry.id)
                        }
                    }
                }
            }

            // "↵" Launch Action Keycap Hint (shown when highlighted)
            Rectangle {
                visible: root.highlighted
                implicitWidth: 24
                implicitHeight: 22
                radius: Theme.radiusSm
                color: Theme.withAlpha(Theme.accent, 0.22)
                border.color: Theme.withAlpha(Theme.accent, 0.5)

                MaterialIcon {
                    anchors.centerIn: parent
                    iconName: "keyboard_return"
                    pixelSize: 13
                    color: Theme.accent
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.entry) root.launchRequested(root.entry)
                    }
                }
            }
        }
    }

    HoverHandler { id: rowHover }
}
