import QtQuick
import QtQuick.Layouts
import "../../theme"
import "../../components"

ColumnLayout {
    id: root
    spacing: 12

    property date today: new Date()
    property int viewYear: today.getFullYear()
    property int viewMonth: today.getMonth()

    readonly property var monthNames: ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
    readonly property var dayLabels: ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]

    function daysInMonth(year, month) {
        return new Date(year, month + 1, 0).getDate()
    }

    function buildGrid() {
        var firstWeekday = new Date(root.viewYear, root.viewMonth, 1).getDay()
        var total = root.daysInMonth(root.viewYear, root.viewMonth)
        var prevTotal = root.daysInMonth(root.viewYear, root.viewMonth === 0 ? 11 : root.viewMonth - 1)
        var cells = []
        for (var i = 0; i < firstWeekday; i++) {
            cells.push({day: prevTotal - firstWeekday + 1 + i, inMonth: false})
        }
        for (var d = 1; d <= total; d++) {
            cells.push({day: d, inMonth: true})
        }
        while (cells.length % 7 !== 0 || cells.length < 42) {
            cells.push({day: cells.length - firstWeekday - total + 1, inMonth: false})
        }
        return cells
    }

    property var gridCells: buildGrid()
    onViewYearChanged: root.gridCells = root.buildGrid()
    onViewMonthChanged: root.gridCells = root.buildGrid()

    // Off for the bar's popup; the desktop calendar widget turns it on from
    // `desktop.calendar.showWeekNumbers`.
    property bool showWeekNumbers: false

    // ISO-8601 week: weeks start Monday and week 1 is the one holding Jan 4th.
    function isoWeek(year, month, day) {
        var d = new Date(Date.UTC(year, month, day))
        d.setUTCDate(d.getUTCDate() + 4 - (d.getUTCDay() || 7))
        var jan1 = new Date(Date.UTC(d.getUTCFullYear(), 0, 1))
        return Math.ceil(((d - jan1) / 86400000 + 1) / 7)
    }

    // Week number of grid row `i`, taken from that row's 4th cell (Wednesday),
    // which is always inside the week the row shows even at a month boundary.
    function rowWeek(i) {
        var c = root.gridCells[i * 7 + 3]
        if (!c) return ""
        var m = root.viewMonth, y = root.viewYear
        if (!c.inMonth) {
            if (i === 0) { m -= 1; if (m < 0) { m = 11; y -= 1 } }
            else { m += 1; if (m > 11) { m = 0; y += 1 } }
        }
        return root.isoWeek(y, m, c.day)
    }

    function isToday(day, inMonth) {
        return inMonth && day === root.today.getDate() && root.viewMonth === root.today.getMonth() && root.viewYear === root.today.getFullYear()
    }

    component NavButton: Rectangle {
        property string icon: ""
        property bool hovered: navArea.containsMouse
        signal tapped()
        implicitWidth: 24
        implicitHeight: 24
        radius: Theme.radiusMd
        color: hovered ? Theme.surfaceHover : Theme.surface
        Behavior on color { ColorAnimation { duration: Anim.d(Anim.fast) } }
        MaterialIcon { anchors.centerIn: parent; iconName: parent.icon; pixelSize: 15; color: parent.hovered ? Theme.text : Theme.textSecondary }
        MouseArea {
            id: navArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.tapped()
        }
    }

    RowLayout {
        Layout.fillWidth: true

        NavButton {
            icon: "chevron_left"
            onTapped: {
                if (root.viewMonth === 0) { root.viewMonth = 11; root.viewYear -= 1 }
                else root.viewMonth -= 1
            }
        }

        Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: root.monthNames[root.viewMonth] + " " + root.viewYear
            color: Theme.text
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontSizeBody
            font.letterSpacing: Theme.labelSpacing
            font.capitalization: Font.AllUppercase
        }

        NavButton {
            icon: "chevron_right"
            onTapped: {
                if (root.viewMonth === 11) { root.viewMonth = 0; root.viewYear += 1 }
                else root.viewMonth += 1
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 4

        // Week-number gutter. A sibling column rather than an 8th grid column so
        // the day grid keeps its fixed 7-wide shape and the widget's uniform
        // scale still works.
        ColumnLayout {
            visible: root.showWeekNumbers
            spacing: 4

            Text {
                Layout.preferredWidth: 20
                horizontalAlignment: Text.AlignHCenter
                text: "WK"
                color: Theme.textDim
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeLabel - 1
                font.letterSpacing: 0.5
            }

            Repeater {
                model: Math.ceil(root.gridCells.length / 7)
                delegate: Text {
                    required property int index
                    Layout.preferredWidth: 20
                    Layout.preferredHeight: 26
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: root.rowWeek(index)
                    color: Theme.textDim
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeSmall
                }
            }
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 7
            rowSpacing: 4
            columnSpacing: 4

            Repeater {
                model: root.dayLabels
                delegate: Text {
                    Layout.preferredWidth: 28
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData
                    color: Theme.textDim
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeLabel - 1
                    font.letterSpacing: 0.5
                    font.capitalization: Font.AllUppercase
                }
            }

            Repeater {
                model: root.gridCells
                delegate: Rectangle {
                    id: dayCell
                    required property var modelData
                    property bool isToday: root.isToday(modelData.day, modelData.inMonth)
                    property bool hovered: dayArea.containsMouse
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 26
                    radius: Theme.radiusMd
                    color: isToday ? Theme.accent
                                  : (hovered && modelData.inMonth ? Theme.surfaceHover : "transparent")
                    Behavior on color { ColorAnimation { duration: Anim.d(Anim.fast) } }

                    Text {
                        anchors.centerIn: parent
                        text: dayCell.modelData.day
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeSmall
                        font.bold: dayCell.isToday
                        color: dayCell.isToday ? Theme.accentText
                                              : (dayCell.modelData.inMonth ? Theme.text : Theme.textDim)
                    }

                    MouseArea { id: dayArea; anchors.fill: parent; hoverEnabled: true }
                }
            }
        }
    }
}
