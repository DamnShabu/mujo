import QtQuick
import QtQuick.Layouts

// Notification history center content (WP-04) — grouped by app, newest first,
// each group showing up to 3 previews then a "+N more" expander. Header carries
// a DND toggle and Clear-all. Goes inside NotificationMenu's popup card. Reads
// Notifications.history (via grouped()); binding re-evaluates as history changes.
ColumnLayout {
    id: root
    spacing: 10
    // grouped() reads Notifications.history, so this rebinds when history changes.
    readonly property var groups: Notifications.grouped()
    property var expanded: ({})    // appName -> show all

    function fmtTime(ms) {
        var d = new Date(ms), now = new Date()
        var same = d.toDateString() === now.toDateString()
        var hh = ("0" + d.getHours()).slice(-2), mm = ("0" + d.getMinutes()).slice(-2)
        return same ? (hh + ":" + mm) : (d.getMonth() + 1) + "/" + d.getDate() + " " + hh + ":" + mm
    }

    // ── header ──
    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        SectionLabel { text: "Notifications"; accented: true; Layout.alignment: Qt.AlignVCenter }
        Item { Layout.fillWidth: true }
        IconButton {
            Layout.alignment: Qt.AlignVCenter
            iconName: Notifications.dnd ? "do_not_disturb_on" : "do_not_disturb_off"
            active: Notifications.dnd
            onClicked: Notifications.toggleDnd()
        }
        Rectangle {
            Layout.alignment: Qt.AlignVCenter
            visible: root.groups.length > 0
            implicitWidth: clrLabel.implicitWidth + 20; implicitHeight: 26
            radius: Theme.radiusSm
            color: clrHover.hovered ? Theme.surfaceHover : Theme.surface
            border.color: Theme.borderStrong
            Text { id: clrLabel; anchors.centerIn: parent; text: "Clear all"; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSmall }
            HoverHandler { id: clrHover; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: Notifications.clearHistory() }
        }
    }

    // ── empty state ──
    ColumnLayout {
        Layout.fillWidth: true
        Layout.topMargin: 24
        Layout.bottomMargin: 24
        visible: root.groups.length === 0
        spacing: 6
        MaterialIcon { Layout.alignment: Qt.AlignHCenter; iconName: "notifications_paused"; pixelSize: 34; color: Theme.textDim }
        Text { Layout.alignment: Qt.AlignHCenter; text: "No notifications"; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeBody }
        Text { Layout.alignment: Qt.AlignHCenter; text: Notifications.dnd ? "Do Not Disturb is on" : "You're all caught up"; color: Theme.textDim; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSmall }
    }

    // ── grouped history (scrolls) ──
    Flickable {
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(contentHeight, 420)
        visible: root.groups.length > 0
        contentHeight: groupCol.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: groupCol
            width: parent.width
            spacing: 10

            Repeater {
                model: root.groups
                delegate: ColumnLayout {
                    id: grp
                    required property var modelData
                    readonly property bool showAll: root.expanded[modelData.appName] === true
                    readonly property int shown: grp.showAll ? modelData.items.length : Math.min(3, modelData.items.length)
                    Layout.fillWidth: true
                    spacing: 4

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Rectangle {
                            implicitWidth: 18; implicitHeight: 18; radius: Theme.radiusSm
                            color: Theme.accentDim
                            Text { anchors.centerIn: parent; text: (grp.modelData.appName || "?").charAt(0).toUpperCase(); color: Theme.accent; font.family: Theme.fontFamily; font.pixelSize: 11; font.bold: true }
                        }
                        Text { text: grp.modelData.appName; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSmall; font.bold: true }
                        Item { Layout.fillWidth: true }
                        Text { text: grp.modelData.items.length; color: Theme.textDim; font.family: Theme.fontMono; font.pixelSize: Theme.fontSizeLabel }
                    }

                    Repeater {
                        // Iterate the sliced records directly (not an int count +
                        // items[index], which briefly indexes out of range while the
                        // grouped model rebuilds → undefined-to-QString warnings).
                        model: grp.modelData.items.slice(0, grp.shown)
                        delegate: Rectangle {
                            required property var modelData
                            readonly property var rec: modelData
                            Layout.fillWidth: true
                            implicitWidth: groupCol.width
                            implicitHeight: itemCol.implicitHeight + 14
                            radius: Theme.radiusMd
                            color: itemHover.hovered ? Theme.surfaceHover : Theme.surface
                            border.color: rec.urgency === "critical" ? Theme.error : Theme.border

                            HoverHandler { id: itemHover }
                            ColumnLayout {
                                id: itemCol
                                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 12; rightMargin: 8 }
                                spacing: 2
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8
                                    Text { Layout.fillWidth: true; text: rec.summary; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSmall; font.bold: true; elide: Text.ElideRight }
                                    Text { text: root.fmtTime(rec.time); color: Theme.textDim; font.family: Theme.fontMono; font.pixelSize: Theme.fontSizeLabel }
                                    MaterialIcon {
                                        iconName: "close"; pixelSize: 15; color: dismissHover.hovered ? Theme.text : Theme.textDim
                                        HoverHandler { id: dismissHover; cursorShape: Qt.PointingHandCursor }
                                        TapHandler { onTapped: Notifications.removeHistory(rec.id) }
                                    }
                                }
                                Text { Layout.fillWidth: true; visible: rec.body !== ""; text: rec.body; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSmall; wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight; textFormat: Text.PlainText }
                            }
                        }
                    }

                    // +N more / less
                    Text {
                        visible: grp.modelData.items.length > 3
                        text: grp.showAll ? "Show less" : ("+" + (grp.modelData.items.length - 3) + " more")
                        color: Theme.accent
                        font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSmall
                        Layout.leftMargin: 4
                        HoverHandler { id: moreHover; cursorShape: Qt.PointingHandCursor }
                        TapHandler {
                            onTapped: {
                                var e = Object.assign({}, root.expanded)
                                e[grp.modelData.appName] = !grp.showAll
                                root.expanded = e
                            }
                        }
                    }
                }
            }
        }
    }
}
