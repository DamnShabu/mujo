import QtQuick
import QtQuick.Layouts
import "../theme"

// Pill button used by the modal prompts (polkit, keyring, dialogs).
// Supports primary accent fill, loading/spinner state, icon, and tactile micro-interactions.
Rectangle {
    id: btn
    property string text: ""
    property string iconName: ""
    property bool primary: false
    property bool danger: false
    property bool loading: false
    signal clicked()

    implicitWidth: btnRow.implicitWidth + 28
    implicitHeight: 34
    radius: Theme.radiusMd
    opacity: btn.enabled && !btn.loading ? 1.0 : (btn.loading ? 0.85 : 0.4)
    
    color: btn.danger
           ? (btnArea.containsMouse ? Theme.error : Theme.withAlpha(Theme.error, 0.2))
           : (btn.primary
              ? (btnArea.containsMouse ? Qt.lighter(Theme.accent, 1.1) : Theme.accent)
              : (btnArea.containsMouse ? Theme.surfaceHover : Theme.surface))

    border.color: btn.danger
                  ? Theme.error
                  : (btn.primary ? "transparent" : (btnArea.containsMouse ? Theme.borderInteractive : Theme.borderStrong))
    border.width: 1
    Behavior on color { ColorAnimation { duration: Anim.d(Anim.fast) } }
    Behavior on border.color { ColorAnimation { duration: Anim.d(Anim.fast) } }

    scale: (btn.enabled && !btn.loading && btnArea.pressed && Anim.microInteractions) ? 0.96 : 1.0
    Behavior on scale {
        NumberAnimation {
            duration: Anim.d(Anim.fast)
            easing.type: Anim.easeStandard
        }
    }

    RowLayout {
        id: btnRow
        anchors.centerIn: parent
        spacing: 7

        Spinner {
            visible: btn.loading
            size: 14
            color: btn.primary ? Theme.accentText : Theme.accent
            Layout.alignment: Qt.AlignVCenter
        }

        MaterialIcon {
            visible: btn.iconName !== "" && !btn.loading
            iconName: btn.iconName
            pixelSize: 16
            color: btn.danger
                   ? (btnArea.containsMouse ? "#ffffff" : Theme.error)
                   : (btn.primary ? Theme.accentText : Theme.text)
            Layout.alignment: Qt.AlignVCenter
        }

        Text {
            id: btnLabel
            text: btn.text
            color: btn.danger
                   ? (btnArea.containsMouse ? "#ffffff" : Theme.error)
                   : (btn.primary ? Theme.accentText : Theme.text)
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeBody
            font.bold: btn.primary || btn.danger
            Layout.alignment: Qt.AlignVCenter
        }
    }

    MouseArea {
        id: btnArea
        anchors.fill: parent
        hoverEnabled: true
        enabled: !btn.loading
        cursorShape: Qt.PointingHandCursor
        onClicked: btn.clicked()
    }
}

