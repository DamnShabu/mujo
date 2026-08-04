import QtQuick

Column {
  id: root
  width: parent.width
  spacing: 4

  property string label: ""
  property string placeholder: ""
  property string value: ""
  property bool secret: false
  property bool required: false
  signal edited(string v)

  Row {
    spacing: 2
    Text {
      text: root.label
      color: WizardTheme.muted
      font { family: WizardTheme.mono; pixelSize: WizardTheme.fsSmall }
    }
    Text {
      visible: root.required
      text: "*"
      color: WizardTheme.error
      font { family: WizardTheme.mono; pixelSize: WizardTheme.fsSmall; weight: Font.Bold }
    }
  }

  Rectangle {
    width: parent.width
    height: 40
    radius: WizardTheme.radiusSmall
    color: WizardTheme.glassInput
    border.width: 1
    border.color: inputField.activeFocus ? WizardTheme.accentBorder : WizardTheme.glassBorder

    Behavior on border.color { ColorAnimation { duration: 150 } }

    TextInput {
      id: inputField
      anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 12; rightMargin: 12 }
      text: root.value
      color: WizardTheme.fg
      font { family: WizardTheme.mono; pixelSize: WizardTheme.fsSmall }
      echoMode: root.secret ? TextInput.Password : TextInput.Normal
      clip: true
      selectByMouse: true
      selectionColor: Qt.alpha(WizardTheme.accent, 0.3)
      activeFocusOnPress: true

      property string placeholderText: root.placeholder

      Text {
        visible: !inputField.text && !inputField.activeFocus
        anchors { left: parent.left; verticalCenter: parent.verticalCenter }
        text: inputField.placeholderText
        color: WizardTheme.border
        font { family: WizardTheme.mono; pixelSize: WizardTheme.fsSmall }
      }

      Text {
        visible: root.secret && inputField.text && !inputField.activeFocus
        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
        text: "\u2022".repeat(Math.min(inputField.text.length, 20))
        color: WizardTheme.muted
        font { family: WizardTheme.mono; pixelSize: WizardTheme.fsSmall }
      }

      onTextChanged: root.edited(text)
    }
  }
}
