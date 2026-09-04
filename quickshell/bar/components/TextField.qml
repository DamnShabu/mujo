import QtQuick
import "../theme"

// Small themed single-line text field with placeholder + optional password mask.
Rectangle {
    id: field
    property alias text: input.text
    property string placeholder: ""
    property bool password: false
    property alias input: input
    // Rejected input (wrong passphrase, mismatched confirmation). Outranks
    // focus on the border, so a field you are still typing in stays red.
    property bool invalid: false
    signal accepted()

    // Spoken label, filled in by SettingRow from the row title.
    property string a11yName: ""

    implicitHeight: 34
    implicitWidth: 200
    radius: Theme.radiusSm
    color: Theme.surface
    border.color: field.invalid ? Theme.error : (input.activeFocus ? Theme.accent : Theme.border)
    Behavior on border.color { ColorAnimation { duration: Anim.d(Anim.fast) } }

    TextInput {
        id: input
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        verticalAlignment: TextInput.AlignVCenter
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeBody
        clip: true
        selectByMouse: true
        echoMode: field.password ? TextInput.Password : TextInput.Normal
        Keys.onReturnPressed: field.accepted()

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: input.text === ""
            text: field.placeholder
            color: Theme.textDim
            font: input.font
        }

        // The field already shows focus by turning its border accent, so it
        // needs no FocusRing — a second ring would double up on the same edge.
        Accessible.role: Accessible.EditableText
        Accessible.name: field.a11yName
        Accessible.description: field.placeholder
        Accessible.passwordEdit: field.password
    }
}
