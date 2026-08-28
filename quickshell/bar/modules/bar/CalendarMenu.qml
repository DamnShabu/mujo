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
