import QtQuick
import QtQuick.Layouts
import "../theme"

// Dashboard primitive (WP-19). A titled, collapsible surface card used to build
// the Overview dashboard grid. Slots:
//   content   default child slot — the card body (a ColumnLayout)
//   badge     small right-of-title item (a count pill, STALE tag, …)
//   actions   optional footer row (buttons)
// A card can render `disabled` with a `disabledReason` in place of its body —
// this is how every unavailable data source is surfaced (LAW 10: never a fake
// control). The chevron and Space/Enter toggle collapse; the whole card is a
// tab stop so the dashboard is keyboard-navigable.
Rectangle {
    id: card

    property string title: ""
    property string icon: ""            // MaterialIcon name, optional
    property bool collapsible: true
    property bool expanded: true
    property bool disabled: false
    property string disabledReason: ""
    property bool hideable: true
    signal hideRequested()

    property alias badge: badgeHolder.data
    property alias actions: actionHolder.data
    default property alias content: contentHolder.data

    readonly property bool showBody: expanded && !disabled

    Layout.fillWidth: true
    radius: Theme.radiusLg
    color: Theme.surface
    border.color: (hh.hovered || card.activeFocus) ? Theme.borderStrong : Theme.border
    Behavior on border.color { ColorAnimation { duration: Anim.d(Anim.fast) } }
    implicitHeight: layout.implicitHeight + 28
    opacity: disabled ? 0.55 : 1

    activeFocusOnTab: true
    Keys.onPressed: function (e) {
        if ((e.key === Qt.Key_Return || e.key === Qt.Key_Space) && card.collapsible && !card.disabled) {
            card.expanded = !card.expanded
            e.accepted = true
        }
    }

    HoverHandler { id: hh }

    // Specular top highlight, matching MujoCard.
    Rectangle {
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: 1
        color: Theme.withAlpha("#ffffff", 0.04)
    }

    // Keyboard focus ring.
    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: "transparent"
        border.color: card.activeFocus ? Theme.accent : "transparent"
        border.width: 1.5
    }

    ColumnLayout {
        id: layout
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
        spacing: 10

        // ── Header ────────────────────────────────────────────────────────────
        Item {
            Layout.fillWidth: true
            implicitHeight: 26

            TapHandler {
                enabled: card.collapsible && !card.disabled
                onTapped: card.expanded = !card.expanded
            }

            RowLayout {
                anchors.fill: parent
                spacing: 9
                MaterialIcon { visible: card.icon !== ""; iconName: card.icon; pixelSize: 18; color: Theme.accent; Layout.alignment: Qt.AlignVCenter }
                Text {
                    text: card.title
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeBody + 1
                    font.bold: true
                    Layout.alignment: Qt.AlignVCenter
                }
                Item {
                    id: badgeHolder
                    implicitWidth: childrenRect.width
                    implicitHeight: childrenRect.height
                    Layout.alignment: Qt.AlignVCenter
                }
                Item { Layout.fillWidth: true }
                MaterialIcon {
                    visible: card.hideable && hh.hovered
                    iconName: "visibility_off"; pixelSize: 15
                    color: hideHh.hovered ? Theme.text : Theme.textDim
                    Layout.alignment: Qt.AlignVCenter
                    HoverHandler { id: hideHh; cursorShape: Qt.PointingHandCursor }
                    TapHandler { gesturePolicy: TapHandler.ReleaseWithinBounds; onTapped: card.hideRequested() }
                }
                MaterialIcon {
                    visible: card.collapsible && !card.disabled
                    iconName: card.expanded ? "expand_less" : "expand_more"
                    pixelSize: 18; color: chevHh.hovered ? Theme.text : Theme.textSecondary
                    Layout.alignment: Qt.AlignVCenter
                    HoverHandler { id: chevHh; cursorShape: Qt.PointingHandCursor }
                    // Exclusive grab: the header tap above also toggles
                    // `expanded`, which cancelled this one out.
                    TapHandler { gesturePolicy: TapHandler.ReleaseWithinBounds; onTapped: card.expanded = !card.expanded }
                }
            }
        }

        // ── Disabled reason (replaces body) ───────────────────────────────────
        Text {
            visible: card.disabled && card.disabledReason !== ""
            Layout.fillWidth: true
            text: card.disabledReason
            color: Theme.textDim
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            wrapMode: Text.WordWrap
        }

        // ── Body ──────────────────────────────────────────────────────────────
        ColumnLayout {
            id: contentHolder
            Layout.fillWidth: true
            visible: card.showBody
            spacing: 8
        }

        // ── Actions footer ────────────────────────────────────────────────────
        RowLayout {
            id: actionHolder
            Layout.fillWidth: true
            visible: card.showBody && children.length > 0
            spacing: 8
        }
    }
}
