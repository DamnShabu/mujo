import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import "Wizard" as W

ShellRoot {
  id: root

  PanelWindow {
    id: win
    WlrLayershell.namespace: "setup-wizard"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    anchors { top: true; left: true; right: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    Keys.onEscapePressed: {
      if (W.WizardState.currentPage === 0 && !W.WizardState.busy && !W.WizardState.done)
        Qt.quit()
      else
        W.WizardState.confirmationPending = false
    }
    readonly property real cardWidth: 620
    readonly property real footerHeight: 56
    readonly property real cardPadding: W.WizardTheme.padXLarge
    readonly property real cardContentHeight: contentCol.implicitHeight
    readonly property real cardTotalHeight: cardContentHeight + cardPadding * 2 + footerHeight
    readonly property real cardMaxHeight: win.height - 120

    Item {
      anchors.fill: parent

      // Frosted glass backdrop
      Rectangle {
        anchors.fill: parent
        color: W.WizardTheme.glassBg
      }

      // Card shadow layers
      Rectangle {
        anchors.centerIn: parent
        width: win.cardWidth + 6
        height: Math.min(win.cardTotalHeight, win.cardMaxHeight) + 6
        radius: W.WizardTheme.radiusLarge + 3
        color: Qt.alpha("#000000", 0.15)
        y: parent.height / 2 - height / 2 + 4
      }
      Rectangle {
        anchors.centerIn: parent
        width: win.cardWidth + 3
        height: Math.min(win.cardTotalHeight, win.cardMaxHeight) + 3
        radius: W.WizardTheme.radiusLarge + 1
        color: Qt.alpha("#000000", 0.08)
        y: parent.height / 2 - height / 2 + 2
      }

      // Card
      Rectangle {
        id: card
        anchors.centerIn: parent
        width: win.cardWidth
        height: Math.min(win.cardTotalHeight, win.cardMaxHeight)
        radius: W.WizardTheme.radiusLarge
        color: W.WizardTheme.glassCard
        border.width: 1
        border.color: W.WizardTheme.glassBorder

        Behavior on height {
          NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
        }

        Column {
          id: contentCol
          anchors {
            left: parent.left; right: parent.right; top: parent.top
            leftMargin: win.cardPadding; rightMargin: win.cardPadding; topMargin: win.cardPadding
            bottomMargin: win.footerHeight + 8
          }
          spacing: 0

          // Header
          Column {
            width: parent.width
            spacing: W.WizardTheme.padMedium

            Text {
              text: "Setup"
              color: W.WizardTheme.fg
              font { family: W.WizardTheme.mono; pixelSize: W.WizardTheme.fsHero; weight: Font.Bold }
            }

            // Step indicators
            Row {
              spacing: 8
              Repeater {
                model: W.WizardState.totalPages
                Rectangle {
                  required property int index
                  width: index === W.WizardState.currentPage ? 32 : 10
                  height: 10
                  radius: 5
                  color: index === W.WizardState.currentPage ? W.WizardTheme.accent
                         : index < W.WizardState.currentPage ? Qt.alpha(W.WizardTheme.accent, 0.5)
                         : W.WizardTheme.border
                  Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                  Behavior on color { ColorAnimation { duration: 200 } }
                }
              }
            }

            // Page title
            Text {
              text: W.WizardState.pageTitles[W.WizardState.currentPage]
              color: W.WizardTheme.muted
              font { family: W.WizardTheme.mono; pixelSize: W.WizardTheme.fsSmall }
            }
          }

          // Separator line
          Rectangle {
            width: parent.width
            height: 1
            color: W.WizardTheme.glassBorder
            anchors.topMargin: W.WizardTheme.padMedium
          }

          Item { width: 1; height: W.WizardTheme.padMedium }

          // Page content
          Item {
            id: pageContainer
            width: parent.width
            height: pageLoader.height

            Loader {
              id: pageLoader
              width: parent.width
              source: {
                switch (W.WizardState.currentPage) {
                  case 0: return "Wizard/PageIdentity.qml"
                  case 1: return "Wizard/PageMachine.qml"
                  case 2: return "Wizard/PageSeal.qml"
                }
              }

              Behavior on y {
                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
              }
            }
          }

          Item { width: 1; height: W.WizardTheme.padMedium }

          // Error message
          Text {
            visible: W.WizardState.error !== ""
            width: parent.width
            wrapMode: Text.Wrap
            color: W.WizardTheme.error
            font { family: W.WizardTheme.mono; pixelSize: W.WizardTheme.fsSmall }
            text: W.WizardState.error
          }
        }

        // Navigation footer — anchored to card bottom, below content
        Item {
          anchors {
            left: parent.left; right: parent.right; bottom: parent.bottom
            leftMargin: win.cardPadding; rightMargin: win.cardPadding; bottomMargin: W.WizardTheme.padLarge
          }
          height: win.footerHeight

          // Separator line at top of footer
          Rectangle {
            anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: -W.WizardTheme.padSmall }
            height: 1
            color: W.WizardTheme.glassBorder
          }

          // Back button
          Rectangle {
            id: backBtn
            visible: W.WizardState.currentPage > 0 && !W.WizardState.busy && !W.WizardState.done
            width: 90
            height: 40
            radius: W.WizardTheme.radiusSmall
            color: backArea.containsMouse ? Qt.alpha(W.WizardTheme.fg, 0.12) : "transparent"
            border.width: 1
            border.color: W.WizardTheme.glassBorder
            anchors.verticalCenter: parent.verticalCenter

            Behavior on color { ColorAnimation { duration: 150 } }

            Text {
              anchors.centerIn: parent
              text: "\u2039 Back"
              color: W.WizardTheme.fg
              font { family: W.WizardTheme.mono; pixelSize: W.WizardTheme.fsSmall }
            }

            MouseArea {
              id: backArea
              anchors.fill: parent
              hoverEnabled: true
              onClicked: W.WizardState.prevPage()
            }
          }

          // Next / Finish button
          Rectangle {
            id: nextBtn
            property bool enabled: W.WizardState.pageValid(W.WizardState.currentPage)
            visible: !W.WizardState.busy && !W.WizardState.done
            width: W.WizardState.currentPage === W.WizardState.totalPages - 1 ? 140 : 90
            height: 40
            radius: W.WizardTheme.radiusSmall
            color: !nextBtn.enabled ? Qt.alpha(W.WizardTheme.border, 0.15)
                   : nextArea.containsMouse ? Qt.alpha(W.WizardTheme.accent, 0.35) : Qt.alpha(W.WizardTheme.accent, 0.15)
            border.width: 1
            border.color: nextBtn.enabled ? W.WizardTheme.accentBorder : Qt.alpha(W.WizardTheme.border, 0.3)
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right

            Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: 150 } }

            Text {
              anchors.centerIn: parent
              text: W.WizardState.currentPage === W.WizardState.totalPages - 1
                    ? (W.WizardState.confirmationPending ? "Confirm?" : "Apply")
                    : "Next \u203A"
              color: nextBtn.enabled ? W.WizardTheme.accent : W.WizardTheme.border
              font { family: W.WizardTheme.mono; pixelSize: W.WizardTheme.fsSmall; weight: Font.Bold }
            }

            MouseArea {
              id: nextArea
              anchors.fill: parent
              hoverEnabled: nextBtn.enabled
              cursorShape: nextBtn.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
              onClicked: {
                if (!nextBtn.enabled) return
                if (W.WizardState.currentPage === W.WizardState.totalPages - 1) {
                  W.WizardState.writePassword()
                } else {
                  W.WizardState.nextPage()
                }
              }
            }
          }

          // Busy indicator
          Row {
            visible: W.WizardState.busy
            anchors.centerIn: parent
            spacing: W.WizardTheme.padMedium

            Rectangle {
              width: 18; height: 18; radius: 9
              color: "transparent"
              border.width: 2; border.color: Qt.alpha(W.WizardTheme.accent, 0.3)
            }
            Rectangle {
              width: 18; height: 18; radius: 9
              color: "transparent"
              border.width: 2; border.color: W.WizardTheme.accent
              RotationAnimator on rotation {
                from: 0; to: 360; duration: 800; loops: Animation.Infinite; running: true
              }
            }

            Text {
              text: "Working..."
              color: W.WizardTheme.muted
              font { family: W.WizardTheme.mono; pixelSize: W.WizardTheme.fsSmall }
              anchors.verticalCenter: parent.verticalCenter
            }
          }

          // Done state
          Text {
            visible: W.WizardState.done
            anchors.centerIn: parent
            text: "Done! Setup complete. Reboot to apply."
            color: W.WizardTheme.success
            font { family: W.WizardTheme.mono; pixelSize: W.WizardTheme.fsBody; weight: Font.Bold }
          }
        }
      }
    }
  }
}
