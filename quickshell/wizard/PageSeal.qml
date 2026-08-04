import QtQuick

Column {
  spacing: WizardTheme.padMedium
  width: parent.width

  Column {
    width: parent.width
    spacing: WizardTheme.padSmall

    Text {
      text: "Apply"
      color: WizardTheme.fg
      font { family: WizardTheme.mono; pixelSize: WizardTheme.fsBody; weight: Font.Bold }
    }
    Text {
      width: parent.width
      wrapMode: Text.Wrap
      text: "Write the user configuration and finish setup."
      color: WizardTheme.muted
      font { family: WizardTheme.mono; pixelSize: WizardTheme.fsTiny }
    }
  }

  // Summary of what will be written
  Column {
    width: parent.width
    spacing: 6

    Text {
      text: "Files to create:"
      color: WizardTheme.muted
      font { family: WizardTheme.mono; pixelSize: WizardTheme.fsSmall }
    }

    Repeater {
      model: [
        { path: "user-config/_user.nix", desc: "User config" },
        { path: "secrets/username", desc: "Username" },
        { path: "/persist/passwd", desc: "Hashed password" }
      ]

      Row {
        required property var modelData
        required property int index
        spacing: WizardTheme.padMedium

        Text {
          text: "\u2713"
          color: WizardTheme.success
          font { family: WizardTheme.mono; pixelSize: WizardTheme.fsSmall }
          visible: WizardState.done
        }

        Column {
          spacing: 1
          Text {
            text: modelData.path
            color: WizardTheme.fg
            font { family: WizardTheme.mono; pixelSize: WizardTheme.fsSmall }
          }
          Text {
            text: modelData.desc
            color: WizardTheme.muted
            font { family: WizardTheme.mono; pixelSize: WizardTheme.fsTiny }
          }
        }
      }
    }
  }

  Item { width: 1; height: WizardTheme.padMedium }

  // Done
  Text {
    visible: WizardState.done
    width: parent.width
    wrapMode: Text.Wrap
    color: WizardTheme.success
    font { family: WizardTheme.mono; pixelSize: WizardTheme.fsBody; weight: Font.Bold }
    text: "Setup complete. Reboot to apply."
  }
}
