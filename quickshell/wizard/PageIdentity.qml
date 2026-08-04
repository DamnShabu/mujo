import QtQuick

Column {
  spacing: WizardTheme.padMedium
  width: parent.width

  Column {
    width: parent.width
    spacing: WizardTheme.padSmall

    Text {
      text: "User identity"
      color: WizardTheme.fg
      font { family: WizardTheme.mono; pixelSize: WizardTheme.fsBody; weight: Font.Bold }
    }
    Text {
      width: parent.width
      wrapMode: Text.Wrap
      text: "Username and login password."
      color: WizardTheme.muted
      font { family: WizardTheme.mono; pixelSize: WizardTheme.fsTiny }
    }
  }

  WizField {
    label: "Username"
    placeholder: "yurii"
    value: WizardState.username
    onEdited: v => WizardState.username = v
    required: true
  }

  WizField {
    label: "Password"
    placeholder: "Login password"
    value: WizardState.password
    onEdited: v => WizardState.password = v
    secret: true
    required: true
  }

  // Password strength indicator
  Row {
    width: parent.width
    spacing: 6
    visible: WizardState.password.length > 0

    property int strength: WizardState.passwordStrength

    Row {
      spacing: 3
      width: parent.width - 60
      anchors.verticalCenter: parent.verticalCenter
      Repeater {
        model: 4
        Rectangle {
          required property int index
          width: Math.floor((parent.width - 3 * parent.spacing) / 4)
          height: 4
          radius: 2
          color: index < parent.parent.strength
                 ? (parent.parent.strength <= 1 ? WizardTheme.error
                    : parent.parent.strength <= 2 ? WizardTheme.warning
                    : WizardTheme.success)
                 : Qt.alpha(WizardTheme.border, 0.4)
          Behavior on color { ColorAnimation { duration: 150 } }
        }
      }
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: ["", "Weak", "Fair", "Good", "Strong"][parent.strength]
      color: parent.strength <= 1 ? WizardTheme.error
             : parent.strength <= 2 ? WizardTheme.warning
             : WizardTheme.success
      font { family: WizardTheme.mono; pixelSize: WizardTheme.fsTiny }
    }
  }

  WizField {
    label: "Confirm password"
    placeholder: "Re-enter password"
    value: WizardState.confirmPassword
    onEdited: v => WizardState.confirmPassword = v
    secret: true
    required: true
  }

  // Password mismatch warning
  Text {
    visible: WizardState.confirmPassword.length > 0 && !WizardState.passwordsMatch
    width: parent.width
    text: "Passwords do not match"
    color: WizardTheme.error
    font { family: WizardTheme.mono; pixelSize: WizardTheme.fsTiny }
  }
}
