import QtQuick
import QtQuick.Layouts
import Quickshell

Pill {
    id: root
    interactive: true
    active: calendarOpen
    implicitHeight: Theme.barHeight
    implicitWidth: rowLayout.implicitWidth + 26

    property var panelWindow
    property string screenName: ""
    readonly property string popupId: root.screenName + ":calendar"
    readonly property bool calendarOpen: PopupCoordinator.activeId === root.popupId

    property date now: new Date()
    Timer { interval: 1000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.now = new Date() }

    readonly property string timeFormat: {
        var f = Theme.clock24h ? "HH:mm" : "hh:mm"
        if (Theme.clockShowSeconds) f += ":ss"
        if (!Theme.clock24h) f += " AP"
        return f
    }

    onClicked: PopupCoordinator.toggle(root.popupId)

    RowLayout {
        id: rowLayout
        anchors.centerIn: parent
        spacing: 8

        Text {
            text: Qt.formatDateTime(root.now, root.timeFormat)
            color: root.active ? Theme.accent : Theme.text
            font.family: Theme.fontMono
            font.pixelSize: Theme.clockFontSize
            font.letterSpacing: 0.5
            Behavior on color { ColorAnimation { duration: Theme.durationFast } }
        }

        Rectangle {
            visible: Theme.clockShowDate
            Layout.preferredWidth: 3
            Layout.preferredHeight: 3
            radius: 1.5
            color: Theme.textDim
        }

        Text {
            visible: Theme.clockShowDate
            text: Qt.formatDate(root.now, "ddd, MMM d")
            color: Theme.textSecondary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
        }
    }

    PopupWindow {
        id: popup
        visible: root.calendarOpen && root.panelWindow
        color: "transparent"
        anchor.window: root.panelWindow
        anchor.item: root
        anchor.edges: Edges.Bottom
        anchor.gravity: Edges.Bottom
        anchor.adjustment: PopupAdjustment.Slide

        implicitWidth: 260 + 32
        implicitHeight: calendar.implicitHeight + 28 + 32

        onClosed: PopupCoordinator.close(root.popupId)

        PopupCard {
            anchors.fill: parent
            open: root.calendarOpen

            CalendarMenu {
                id: calendar
                anchors.fill: parent
                anchors.margins: 14
            }
        }
    }
}
