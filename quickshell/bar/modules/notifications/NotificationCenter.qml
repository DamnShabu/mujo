import QtQuick
import QtQuick.Layouts
import "../../theme"
import "../../components"
import "../../services"

// Notification history center content (WP-04) — grouped by app, newest first,
// with search filtering, per-group clearing, DND toggle, and rich item previews.
// Goes inside NotificationMenu's popup card. Reads Notifications.history.
ColumnLayout {
    id: root
    spacing: 12

    property string searchFilter: ""
    property var expanded: ({})    // appName -> bool

    readonly property var allGroups: Notifications.grouped()
    readonly property var filteredGroups: {
        var q = root.searchFilter.trim().toLowerCase()
        if (!q) return root.allGroups
        var res = []
        for (var i = 0; i < root.allGroups.length; i++) {
            var g = root.allGroups[i]
            var appMatches = (g.appName || "").toLowerCase().indexOf(q) >= 0
            var matchedItems = []
            for (var j = 0; j < g.items.length; j++) {
                var it = g.items[j]
                if (appMatches || (it.summary && it.summary.toLowerCase().indexOf(q) >= 0)
                               || (it.body && it.body.toLowerCase().indexOf(q) >= 0)) {
                    matchedItems.push(it)
                }
            }
            if (matchedItems.length > 0) {
                res.push({ appName: g.appName, icon: g.icon, desktopEntry: g.desktopEntry, items: matchedItems })
            }
        }
        return res
    }

    function fmtTime(ms) { return Notifications.fmtTime(ms) }

    // ── 1. Header ──
    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        RowLayout {
            spacing: 6
            Layout.alignment: Qt.AlignVCenter

            SectionLabel {
                text: "Notifications"
                accented: true
            }

            // Total count badge
            Rectangle {
                visible: Notifications.history.length > 0
                implicitWidth: cntTxt.implicitWidth + 8
                implicitHeight: 16
                radius: Theme.radiusSm
                color: Theme.accentDim
                border.color: Theme.accent

                Text {
                    id: cntTxt
                    anchors.centerIn: parent
                    text: String(Notifications.history.length)
                    color: Theme.accent
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeLabel
                    font.bold: true
                }
            }
        }

        Item { Layout.fillWidth: true }

        // DND Quick Toggle
        IconButton {
            Layout.alignment: Qt.AlignVCenter
            iconName: Notifications.dnd ? "do_not_disturb_on" : "do_not_disturb_off"
            active: Notifications.dnd
            iconColor: Notifications.dnd ? Theme.warning : Theme.textSecondary
            onClicked: Notifications.toggleDnd()
        }

        // Clear all button
        Rectangle {
            Layout.alignment: Qt.AlignVCenter
            visible: Notifications.history.length > 0
            implicitWidth: clrLabel.implicitWidth + 18
            implicitHeight: 26
            radius: Theme.radiusSm
            color: clrHh.hovered ? Theme.surfaceHover : Theme.surface
            border.color: clrHh.hovered ? Theme.borderInteractive : Theme.borderStrong

            Text {
                id: clrLabel
                anchors.centerIn: parent
                text: "Clear all"
                color: clrHh.hovered ? Theme.text : Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
            }
            HoverHandler { id: clrHh; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: Notifications.clearHistory() }
        }
    }

    // ── 2. Search Filter (when history has entries) ──
    Item {
        Layout.fillWidth: true
        implicitHeight: 30
        visible: Notifications.history.length > 2

        Rectangle {
            anchors.fill: parent
            radius: Theme.radiusSm
            color: Theme.surface
            border.color: searchField.activeFocus ? Theme.accent : Theme.border
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                spacing: 6

                MaterialIcon {
                    iconName: "search"
                    pixelSize: 14
                    color: Theme.textDim
                    Layout.alignment: Qt.AlignVCenter
                }

                TextInput {
                    id: searchField
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    selectByMouse: true
                    clip: true
                    onTextChanged: root.searchFilter = text

                    Text {
                        text: "Filter notifications…"
                        color: Theme.textDim
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        visible: !searchField.text && !searchField.activeFocus
                        anchors.fill: parent
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                MaterialIcon {
                    visible: searchField.text !== ""
                    iconName: "close"
                    pixelSize: 13
                    color: clearSearchHh.hovered ? Theme.text : Theme.textDim
                    Layout.alignment: Qt.AlignVCenter
                    HoverHandler { id: clearSearchHh; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: { searchField.text = ""; root.searchFilter = "" } }
                }
            }
        }
    }

    // ── 3. Empty state ──
    ColumnLayout {
        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: 24
        Layout.bottomMargin: 24
        visible: root.filteredGroups.length === 0
        spacing: 8

        MaterialIcon {
            Layout.alignment: Qt.AlignHCenter
            iconName: Notifications.dnd ? "notifications_off" : "notifications_paused"
            pixelSize: 36
            color: Notifications.dnd ? Theme.warning : Theme.textDim
        }
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: root.searchFilter !== "" ? "No matching notifications"
                : (Notifications.dnd ? "Do Not Disturb active" : "No notifications")
            color: Theme.textSecondary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeBody
            font.bold: true
        }
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: root.searchFilter !== "" ? "Try clearing your search query."
                : (Notifications.dnd ? "New notifications are silently archived." : "You are completely caught up.")
            color: Theme.textDim
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
        }
    }

    // ── 4. Grouped history (scrollable) ──
    Flickable {
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(contentHeight, 440)
        visible: root.filteredGroups.length > 0
        contentHeight: groupCol.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: groupCol
            width: parent.width
            spacing: 12

            Repeater {
                model: root.filteredGroups
                delegate: ColumnLayout {
                    id: grp
                    required property var modelData
                    readonly property bool isExpanded: root.expanded[modelData.appName] !== false
                    readonly property int maxShown: grp.isExpanded ? modelData.items.length : Math.min(3, modelData.items.length)
                    Layout.fillWidth: true
                    spacing: 6

                    // Group Header Row
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 28
                        radius: Theme.radiusSm
                        color: grpHh.hovered ? Theme.surfaceHover : Theme.surface
                        border.color: Theme.border

                        HoverHandler { id: grpHh }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 8

                            // App Icon
                            Item {
                                implicitWidth: 16; implicitHeight: 16
                                Layout.alignment: Qt.AlignVCenter

                                readonly property string iconSrc: Notifications.resolveIcon(grp.modelData.items[0])
                                readonly property bool hasBrand: Brand.has((grp.modelData.appName || "").toLowerCase())

                                Image {
                                    id: grpIconImg
                                    anchors.fill: parent
                                    source: parent.iconSrc
                                    fillMode: Image.PreserveAspectFit
                                    sourceSize.width: 32; sourceSize.height: 32
                                    smooth: true
                                    visible: parent.iconSrc !== "" && status === Image.Ready
                                }

                                BrandIcon {
                                    anchors.fill: parent
                                    brand: (grp.modelData.appName || "").toLowerCase()
                                    size: 16
                                    visible: !grpIconImg.visible && parent.hasBrand
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    radius: 3
                                    visible: !grpIconImg.visible && !parent.hasBrand
                                    color: Theme.accentDim
                                    Text {
                                        anchors.centerIn: parent
                                        text: (grp.modelData.appName || "?").charAt(0).toUpperCase()
                                        color: Theme.accent
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeLabel
                                        font.bold: true
                                    }
                                }
                            }

                            Text {
                                text: grp.modelData.appName
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSmall
                                font.bold: true
                                Layout.alignment: Qt.AlignVCenter
                            }

                            // Count chip
                            Rectangle {
                                implicitWidth: grpCnt.implicitWidth + 8
                                implicitHeight: 16
                                radius: 8
                                color: Theme.surfaceActive
                                Layout.alignment: Qt.AlignVCenter

                                Text {
                                    id: grpCnt
                                    anchors.centerIn: parent
                                    text: String(grp.modelData.items.length)
                                    color: Theme.textSecondary
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.fontSizeLabel - 1
                                }
                            }

                            Item { Layout.fillWidth: true }

                            // Clear Group Button
                            MaterialIcon {
                                visible: grpHh.hovered
                                iconName: "delete_sweep"
                                pixelSize: 14
                                color: clrGrpHh.hovered ? Theme.error : Theme.textDim
                                Layout.alignment: Qt.AlignVCenter
                                HoverHandler { id: clrGrpHh; cursorShape: Qt.PointingHandCursor }
                                TapHandler { onTapped: Notifications.clearAppHistory(grp.modelData.appName) }
                            }

                            // Mute App Button
                            MaterialIcon {
                                visible: grpHh.hovered
                                iconName: "volume_off"
                                pixelSize: 14
                                color: muteGrpHh.hovered ? Theme.warning : Theme.textDim
                                Layout.alignment: Qt.AlignVCenter
                                HoverHandler { id: muteGrpHh; cursorShape: Qt.PointingHandCursor }
                                TapHandler { onTapped: Notifications.muteApp(grp.modelData.appName, true) }
                            }

                            // Chevron toggle
                            MaterialIcon {
                                iconName: grp.isExpanded ? "expand_less" : "expand_more"
                                pixelSize: 16
                                color: Theme.textDim
                                Layout.alignment: Qt.AlignVCenter
                            }
                        }

                        TapHandler {
                            onTapped: {
                                var e = Object.assign({}, root.expanded)
                                e[grp.modelData.appName] = !grp.isExpanded
                                root.expanded = e
                            }
                        }
                    }

                    // Group Items
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        visible: grp.isExpanded

                        Repeater {
                            model: grp.modelData.items.slice(0, grp.maxShown)
                            delegate: Rectangle {
                                required property var modelData
                                readonly property var rec: modelData
                                Layout.fillWidth: true
                                implicitHeight: itemCol.implicitHeight + 16
                                radius: Theme.radiusMd
                                color: itemHover.hovered ? Theme.surfaceHover : Theme.surface
                                border.color: rec.urgency === "critical" ? Theme.error : (itemHover.hovered ? Theme.borderStrong : Theme.border)

                                HoverHandler { id: itemHover }

                                ColumnLayout {
                                    id: itemCol
                                    anchors {
                                        left: parent.left
                                        right: parent.right
                                        top: parent.top
                                        margins: 10
                                    }
                                    spacing: 4

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 6

                                        Text {
                                            Layout.fillWidth: true
                                            text: rec.summary || "Notification"
                                            color: Theme.text
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontSizeSmall
                                            font.bold: true
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            text: root.fmtTime(rec.time)
                                            color: Theme.textDim
                                            font.family: Theme.fontMono
                                            font.pixelSize: Theme.fontSizeLabel
                                        }

                                        MaterialIcon {
                                            iconName: "close"
                                            pixelSize: 14
                                            color: dismissHover.hovered ? Theme.error : Theme.textDim
                                            Layout.alignment: Qt.AlignVCenter
                                            HoverHandler { id: dismissHover; cursorShape: Qt.PointingHandCursor }
                                            TapHandler { onTapped: Notifications.removeHistory(rec.id) }
                                        }
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        visible: rec.body !== ""
                                        text: rec.body
                                        color: Theme.textSecondary
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeSmall
                                        wrapMode: Text.WordWrap
                                        maximumLineCount: 3
                                        elide: Text.ElideRight
                                        textFormat: Text.StyledText
                                        onLinkActivated: function(link) { Qt.openUrlExternally(link) }
                                    }

                                    // Progress bar if recorded
                                    Rectangle {
                                        Layout.fillWidth: true
                                        visible: rec.progress >= 0
                                        implicitHeight: 4
                                        radius: 2
                                        color: Theme.surfaceActive

                                        Rectangle {
                                            height: parent.height
                                            radius: parent.radius
                                            width: parent.width * Math.max(0, Math.min(100, rec.progress)) / 100
                                            color: Theme.accent
                                        }
                                    }
                                }
                            }
                        }

                        // Expand / Collapse +N items
                        Text {
                            visible: grp.modelData.items.length > 3
                            text: grp.isExpanded ? "Show less" : ("+" + (grp.modelData.items.length - 3) + " more")
                            color: Theme.accent
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            font.bold: true
                            Layout.leftMargin: 4
                            HoverHandler { id: moreHover; cursorShape: Qt.PointingHandCursor }
                            TapHandler {
                                onTapped: {
                                    var e = Object.assign({}, root.expanded)
                                    e[grp.modelData.appName] = !grp.isExpanded
                                    root.expanded = e
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

