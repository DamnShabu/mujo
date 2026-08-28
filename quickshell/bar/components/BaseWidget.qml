import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import "../theme"

// BaseWidget: Unified, reusable base component for all desktop widgets.
// Provides standardized visual encapsulation, modern glassmorphism styling,
// dynamic elevation and drop shadows (scaled during drag/focus), specular highlights,
// optional header with title/icon/badge/actions, DPI-aware scalable layout,
// and declarative loading & error states.
Item {
    id: root

    // ── Widget Metadata & Properties ─────────────────────────────────────────
    property string title: ""
    property string iconName: ""
    property color iconColor: Theme.accent
    property string badgeText: ""
    property color badgeColor: Theme.accent
    property bool showHeader: title !== "" || iconName !== "" || badgeText !== ""
    property bool showGlass: true
    // Chromeless: no card, no shadow, no padding - just the content. The
    // border still shows while unlocked/active/focused so the widget stays a
    // visible grab target on the desktop instead of an invisible one.
    property bool chromeless: false

    // ── Interaction & State ──────────────────────────────────────────────────
    property bool locked: true
    property bool dragging: false
    property bool resizing: false
    readonly property bool active: dragging || resizing
    property bool focused: false

    // ── Data & Async States ──────────────────────────────────────────────────
    property bool loading: false
    property string error: ""

    // ── Styling Tokens ───────────────────────────────────────────────────────
    property int radius: Theme.radiusLg
    property color surfaceColor: Theme.withAlpha(Theme.surface, Theme.transparency * 0.82)
    property alias headerActions: actionRow.children
    default property alias content: bodyContainer.data

    // ── Signals ──────────────────────────────────────────────────────────────
    signal retryClicked()
    signal closeClicked()

    // ── Drop Shadow MultiEffect ──────────────────────────────────────────────
    Rectangle {
        id: shadowSrc
        anchors.fill: cardSurface
        radius: cardSurface.radius
        color: "#000000"
        visible: false
        layer.enabled: true
    }

    MultiEffect {
        visible: !root.chromeless
        anchors.fill: shadowSrc
        source: shadowSrc
        autoPaddingEnabled: true
        shadowEnabled: true
        shadowColor: "#000000"
        shadowBlur: root.active ? 1.0 : (root.focused ? 0.75 : 0.45)
        shadowVerticalOffset: root.active ? 10 : (root.focused ? 6 : 3)
        shadowHorizontalOffset: 0
        shadowOpacity: root.active ? 0.65 : (root.focused ? 0.45 : 0.35)

        Behavior on shadowBlur {
            NumberAnimation { duration: Anim.d(Anim.fast); easing.type: Easing.OutCubic }
        }
        Behavior on shadowVerticalOffset {
            NumberAnimation { duration: Anim.d(Anim.fast); easing.type: Easing.OutCubic }
        }
        Behavior on shadowOpacity {
            NumberAnimation { duration: Anim.d(Anim.fast); easing.type: Easing.OutCubic }
        }
    }

    // ── Main Card Surface ────────────────────────────────────────────────────
    Rectangle {
        id: cardSurface
        anchors.fill: parent
        radius: root.radius
        color: root.chromeless ? "transparent"
             : (root.showGlass ? root.surfaceColor : Theme.surface)
        clip: !root.chromeless

        border.color: root.active ? Theme.accent
                    : (!root.locked ? Theme.withAlpha(Theme.accent, 0.55)
                    : (root.focused ? Theme.borderInteractive
                    : (cardHh.hovered ? Theme.borderStrong : Theme.withAlpha(Theme.borderStrong, 0.5))))
        border.width: root.active ? 2
                    : (!root.locked || root.focused ? 1.5
                    : (root.chromeless ? 0 : 1))

        Behavior on border.color {
            ColorAnimation { duration: Anim.d(Anim.fast) }
        }
        Behavior on border.width {
            NumberAnimation { duration: Anim.d(Anim.fast) }
        }

        // Active lift & scale
        scale: root.active ? 1.03 : (cardHh.hovered && !root.locked ? 1.01 : 1.0)
        opacity: root.active ? 0.92 : 1.0

        Behavior on scale {
            NumberAnimation { duration: Anim.d(Anim.fast); easing.type: Easing.OutCubic }
        }
        Behavior on opacity {
            NumberAnimation { duration: Anim.d(Anim.fast) }
        }

        // Specular top highlight line
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            radius: cardSurface.radius
            color: Theme.withAlpha("#ffffff", 0.06)
            visible: !root.chromeless
        }

        HoverHandler {
            id: cardHh
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: root.chromeless ? 0 : (root.showHeader ? 10 : 8)
            spacing: 6

            // ── Widget Header ────────────────────────────────────────────────
            Item {
                id: headerItem
                Layout.fillWidth: true
                implicitHeight: 22
                visible: root.showHeader

                RowLayout {
                    anchors.fill: parent
                    spacing: 7

                    MaterialIcon {
                        visible: root.iconName !== ""
                        iconName: root.iconName
                        pixelSize: 16
                        color: root.iconColor
                        Layout.alignment: Qt.AlignVCenter
                    }

                    Text {
                        visible: root.title !== ""
                        text: root.title
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        font.bold: true
                        Layout.alignment: Qt.AlignVCenter
                        elide: Text.ElideRight
                        Layout.maximumWidth: headerItem.width - 70
                    }

                    // Optional badge
                    Rectangle {
                        visible: root.badgeText !== ""
                        implicitWidth: badgeLabel.implicitWidth + 8
                        implicitHeight: 16
                        radius: Theme.radiusSm
                        color: Theme.withAlpha(root.badgeColor, 0.15)
                        border.color: Theme.withAlpha(root.badgeColor, 0.5)
                        Layout.alignment: Qt.AlignVCenter

                        Text {
                            id: badgeLabel
                            anchors.centerIn: parent
                            text: root.badgeText
                            color: root.badgeColor
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSizeLabel
                            font.bold: true
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // Custom header actions slot
                    RowLayout {
                        id: actionRow
                        spacing: 4
                        Layout.alignment: Qt.AlignVCenter
                    }

                }
            }

            // ── Widget Body Content Container ────────────────────────────────
            Item {
                id: bodyContainer
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: !root.loading && root.error === ""
                clip: true
            }
        }

        // ── Unlock-mode Delete Button ────────────────────────────────────────
        // Floats over the card instead of sitting in the header row, so unlocking
        // never reflows the widget body.
        Rectangle {
            visible: !root.locked
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 6
            z: 10
            implicitWidth: 20
            implicitHeight: 20
            radius: Theme.radiusSm
            color: delHh.hovered ? Theme.withAlpha(Theme.error, 0.22) : Theme.withAlpha(Theme.surfaceHover, 0.6)
            border.color: delHh.hovered ? Theme.error : Theme.border

            MaterialIcon {
                anchors.centerIn: parent
                iconName: "close"
                pixelSize: 13
                color: delHh.hovered ? Theme.error : Theme.textSecondary
            }
            HoverHandler { id: delHh; cursorShape: Qt.PointingHandCursor }
            TapHandler { gesturePolicy: TapHandler.ReleaseWithinBounds; onTapped: root.closeClicked() }
        }

        // ── Loading State Overlay ────────────────────────────────────────────
        Spinner {
            anchors.centerIn: parent
            visible: root.loading
            size: 28
        }

        // ── Error State Overlay ──────────────────────────────────────────────
        ColumnLayout {
            anchors.centerIn: parent
            width: parent.width - 24
            visible: root.error !== "" && !root.loading
            spacing: 6

            MaterialIcon {
                Layout.alignment: Qt.AlignHCenter
                iconName: "error_outline"
                pixelSize: 26
                color: Theme.error
            }

            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: root.error
                color: Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }

            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: retryText.implicitWidth + 22
                implicitHeight: 26
                radius: Theme.radiusSm
                color: retryHh.hovered ? Theme.surfaceHover : Theme.surfaceActive
                border.color: Theme.border

                Text {
                    id: retryText
                    anchors.centerIn: parent
                    text: "Retry"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                }
                HoverHandler { id: retryHh; cursorShape: Qt.PointingHandCursor }
                // Exclusive grab: this button sits inside the widget host's
                // focus tap on the desktop layer.
                TapHandler { gesturePolicy: TapHandler.ReleaseWithinBounds; onTapped: root.retryClicked() }
            }
        }
    }
}
