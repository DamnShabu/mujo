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

    // Optional keyboard chaining for multi-field forms (the greeter's
    // passphrase + confirmation). TextInput has activeFocusOnTab false, so Tab
    // is otherwise swallowed and every keystroke piles into the first field.
    // Left null, Tab and Return behave exactly as before.
    property var nextField: null

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
        // Focus the chained field, not the TextField wrapping it: the wrapper is
        // a plain Rectangle, so focusing it swallows the keystrokes.
        KeyNavigation.tab: field.nextField ? field.nextField.input : null

        // Return advances to an empty chained field and submits once it is
        // filled, so a two-field form is Return-Return rather than reach-for-Tab.
        Keys.onReturnPressed: {
            if (field.nextField && field.nextField.text === "") field.nextField.input.forceActiveFocus()
            else field.accepted()
        }

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
