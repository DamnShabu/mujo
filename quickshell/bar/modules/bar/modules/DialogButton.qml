import QtQuick

// Pill button used by the modal prompts (polkit, keyring). `primary` fills with
// the accent; otherwise it's a quiet surface button.
Rectangle {
    id: btn
    property string text: ""
    property bool primary: false
    property bool enabled: true
    signal clicked()

    implicitWidth: btnLabel.implicitWidth + 32
    implicitHeight: 34
    radius: Theme.radiusMd
    opacity: btn.enabled ? 1 : 0.4
    color: btn.primary
           ? (btnArea.containsMouse ? Qt.lighter(Theme.accent, 1.1) : Theme.accent)
           : (btnArea.containsMouse ? Theme.surfaceHover : Theme.surface)
    border.color: btn.primary ? "transparent" : Theme.borderStrong
    Behavior on color { ColorAnimation { duration: Theme.durationFast } }

    Text {
        id: btnLabel
        anchors.centerIn: parent
        text: btn.text
        color: btn.primary ? Theme.accentText : Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeBody
        font.bold: btn.primary
    }

    MouseArea {
        id: btnArea
        anchors.fill: parent
        hoverEnabled: true
        enabled: btn.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: btn.clicked()
    }
}
