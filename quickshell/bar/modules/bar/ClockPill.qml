import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../theme"
import "../../components"
import "../../services"

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

    readonly property bool format24: SettingsBus.get("bar.clock.format24", Theme.clock24h)
    readonly property bool showSeconds: SettingsBus.get("bar.clock.showSeconds", Theme.clockShowSeconds)
    readonly property bool showDate: SettingsBus.get("bar.clock.showDate", Theme.clockShowDate)
    readonly property string dateFormat: SettingsBus.get("bar.clock.dateFormat", "short")
    readonly property bool fontMono: SettingsBus.get("bar.clock.fontMono", true)
    readonly property bool fontBold: SettingsBus.get("bar.clock.bold", false)
    readonly property bool showIcon: SettingsBus.get("bar.clock.showIcon", false)

    property date now: new Date()
    // Sleep to the next minute boundary unless seconds are actually on screen:
    // ticking at 1Hz to re-render "HH:mm" re-ran formatDateTime and relaid out
    // the Text 59 times a minute for an identical string, on every bar, on
    // every monitor. Reassigning `interval` restarts the timer, so each tick
    // re-aims at the next boundary and drift corrects itself.
    Timer {
        interval: root.showSeconds
                  ? 1000
                  : Math.max(1000, 60000 - (root.now.getSeconds() * 1000 + root.now.getMilliseconds()))
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.now = new Date()
    }

    readonly property string timeFormat: {
        var f = root.format24 ? "HH:mm" : "hh:mm"
        if (root.showSeconds) f += ":ss"
        if (!root.format24) f += " AP"
        return f
    }

    readonly property string datePattern: {
        if (dateFormat === "full") return "dddd, MMMM d"
        if (dateFormat === "compact") return "M/d"
        if (dateFormat === "iso") return "yyyy-MM-dd"
        return "ddd, MMM d"
    }

    onClicked: PopupCoordinator.toggle(root.popupId)

    RowLayout {
        id: rowLayout
        anchors.centerIn: parent
        spacing: 7

        MaterialIcon {
            visible: root.showIcon
            iconName: "schedule"
            pixelSize: 14
            color: root.active ? Theme.accent : Theme.textSecondary
            Layout.alignment: Qt.AlignVCenter
        }

        Text {
            text: Qt.formatDateTime(root.now, root.timeFormat)
            color: root.active ? Theme.accent : Theme.text
            font.family: root.fontMono ? Theme.fontMono : Theme.fontFamily
            font.pixelSize: Theme.clockFontSize
            font.bold: root.fontBold
            font.letterSpacing: root.fontMono ? 0.5 : 0.0
            Behavior on color { ColorAnimation { duration: Anim.d(Anim.fast) } }
        }

        Rectangle {
            visible: root.showDate
            Layout.preferredWidth: 3
            Layout.preferredHeight: 3
            radius: 1.5
            color: Theme.textDim
        }

        Text {
            visible: root.showDate
            text: Qt.formatDate(root.now, root.datePattern)
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
        anchor.edges: Theme.popupEdge
        anchor.gravity: Theme.popupGravity
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
