import QtQuick

Column {
  spacing: WizardTheme.padMedium
  width: parent.width

  Component.onCompleted: {
    WizardState.discoverMonitors()
  }

  Column {
    width: parent.width
    spacing: WizardTheme.padSmall

    Text {
      text: "Machine configuration"
      color: WizardTheme.fg
      font { family: WizardTheme.mono; pixelSize: WizardTheme.fsBody; weight: Font.Bold }
    }
    Text {
      width: parent.width
      wrapMode: Text.Wrap
      text: "Hostname, timezone, and monitor layout."
      color: WizardTheme.muted
      font { family: WizardTheme.mono; pixelSize: WizardTheme.fsTiny }
    }
  }

  WizField {
    label: "Hostname"
    placeholder: "main"
    value: WizardState.hostname
    onEdited: v => WizardState.hostname = v
  }

  // Timezone selector
  Column {
    width: parent.width
    spacing: 4

    Text {
      text: "Timezone"
      color: WizardTheme.muted
      font { family: WizardTheme.mono; pixelSize: WizardTheme.fsSmall }
    }

    Rectangle {
      width: parent.width
      height: 40
      radius: WizardTheme.radiusSmall
      color: WizardTheme.glassInput
      border.width: 1
      border.color: WizardTheme.glassBorder

      Row {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12

        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: WizardState.timezone || "Select timezone..."
          color: WizardState.timezone ? WizardTheme.fg : WizardTheme.muted
          font { family: WizardTheme.mono; pixelSize: WizardTheme.fsSmall }
          width: parent.width - 20
          elide: Text.ElideRight
        }

        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: "\u25BE"
          color: WizardTheme.muted
          font { family: WizardTheme.mono; pixelSize: WizardTheme.fsSmall }
        }
      }

      MouseArea {
        anchors.fill: parent
        onClicked: tzPopup.visible = !tzPopup.visible
      }
    }

    Rectangle {
      id: tzPopup
      visible: false
      focus: visible
      width: parent.width
      height: Math.min(tzCol.implicitHeight + 16, 200)
      radius: WizardTheme.radiusSmall
      color: WizardTheme.surface
      border.width: 1
      border.color: WizardTheme.glassBorder
      Keys.onEscapePressed: visible = false

      Column {
        id: tzCol
        anchors.fill: parent
        anchors.margins: 8

        Repeater {
          model: WizardState.timezones

          Rectangle {
            required property string modelData
            required property int index
            width: parent.width
            height: 28
            radius: 4
            color: tzArea.containsMouse ? WizardTheme.accentDim : "transparent"

            Text {
              anchors.left: parent.left
              anchors.leftMargin: 8
              anchors.verticalCenter: parent.verticalCenter
              text: modelData
              color: WizardTheme.fg
              font { family: WizardTheme.mono; pixelSize: WizardTheme.fsSmall }
            }

            MouseArea {
              id: tzArea
              anchors.fill: parent
              hoverEnabled: true
              onClicked: {
                WizardState.timezone = modelData
                tzPopup.visible = false
              }
            }
          }
        }
      }
    }
  }

  // Monitor layout panel
  Column {
    width: parent.width
    spacing: WizardTheme.padSmall
    visible: WizardState.discoveredMonitors.length > 0

    Text {
      text: "Monitors (" + WizardState.discoveredMonitors.length + " detected)"
      color: WizardTheme.muted
      font { family: WizardTheme.mono; pixelSize: WizardTheme.fsSmall }
    }

    // Visual layout canvas
    Rectangle {
      id: layoutCanvas
      width: parent.width
      height: 160
      radius: WizardTheme.radiusSmall
      color: Qt.alpha(WizardTheme.bg, 0.8)
      border.width: 1
      border.color: WizardTheme.glassBorder

      // Compute bounding box of all monitors for scaling
      readonly property real totalW: {
        var maxR = 0
        for (var i = 0; i < WizardState.monitorOutputs.length; i++) {
          var p = WizardState.monitorPositions[i] || {x:0,y:0}
          var m = WizardState.monitorModes[i]
          var w = (m && m.length > 0) ? m[0].w : 1920
          if (p.x + w > maxR) maxR = p.x + w
        }
        return Math.max(maxR, 1920)
      }
      readonly property real totalH: {
        var maxB = 0
        for (var i = 0; i < WizardState.monitorOutputs.length; i++) {
          var p = WizardState.monitorPositions[i] || {x:0,y:0}
          var m = WizardState.monitorModes[i]
          var h = (m && m.length > 0) ? m[0].h : 1080
          if (p.y + h > maxB) maxB = p.y + h
        }
        return Math.max(maxB, 1080)
      }
      readonly property real scaleF: Math.min((width - 16) / totalW, (height - 16) / totalH)
      readonly property real offsetX: (width - totalW * scaleF) / 2
      readonly property real offsetY: (height - totalH * scaleF) / 2

      Repeater {
        model: WizardState.monitorOutputs.length

        Rectangle {
          id: monRect
          required property int index
          property var monPos: WizardState.monitorPositions[index] || {x:0,y:0}
          property var monModes: WizardState.monitorModes[index] || []
          property real monW: (monModes.length > 0) ? monModes[0].w : 1920
          property real monH: (monModes.length > 0) ? monModes[0].h : 1080

          x: layoutCanvas.offsetX + monPos.x * layoutCanvas.scaleF
          y: layoutCanvas.offsetY + monPos.y * layoutCanvas.scaleF
          width: monW * layoutCanvas.scaleF
          height: monH * layoutCanvas.scaleF
          radius: 3
          color: WizardState.selectedMonitor === index
                 ? Qt.alpha(WizardTheme.accent, 0.35)
                 : Qt.alpha(WizardTheme.surfaceLight, 0.7)
          border.width: 2
          border.color: WizardState.selectedMonitor === index
                        ? WizardTheme.accent
                        : WizardTheme.glassBorder

          Behavior on x { NumberAnimation { duration: 100 } }
          Behavior on y { NumberAnimation { duration: 100 } }

          Text {
            anchors.centerIn: parent
            text: WizardState.monitorOutputs[index]
            color: WizardTheme.fg
            font { family: WizardTheme.mono; pixelSize: 10 }
          }

          MouseArea {
            anchors.fill: parent
            drag.target: monRect
            drag.minimumX: 0
            drag.minimumY: 0
            drag.maximumX: layoutCanvas.width - monRect.width
            drag.maximumY: layoutCanvas.height - monRect.height
            onClicked: WizardState.selectedMonitor = index
            onReleased: {
              var nx = Math.round((monRect.x - layoutCanvas.offsetX) / layoutCanvas.scaleF)
              var ny = Math.round((monRect.y - layoutCanvas.offsetY) / layoutCanvas.scaleF)
              var pos = WizardState.monitorPositions.slice()
              pos[index] = { x: Math.max(0, nx), y: Math.max(0, ny) }
              WizardState.monitorPositions = pos
            }
          }
        }
      }
    }

    // Per-monitor detail editor (shows when selected)
    Column {
      width: parent.width
      spacing: WizardTheme.padSmall
      visible: WizardState.selectedMonitor >= 0 && WizardState.selectedMonitor < WizardState.discoveredMonitors.length

      Text {
        text: "Editing: " + (WizardState.discoveredMonitors[WizardState.selectedMonitor] || "")
        color: WizardTheme.accent
        font { family: WizardTheme.mono; pixelSize: WizardTheme.fsSmall; weight: Font.Bold }
      }

      // Mode & Hz selector
      Row {
        spacing: 8
        width: parent.width

        Column {
          spacing: 2
          width: parent.width * 0.5 - 4

          Text {
            text: "Resolution & Refresh Rate"
            color: WizardTheme.muted
            font { family: WizardTheme.mono; pixelSize: WizardTheme.fsTiny }
          }

          Rectangle {
            width: parent.width
            height: 40
            radius: WizardTheme.radiusSmall
            color: WizardTheme.glassInput
            border.width: 1
            border.color: modeDropdown.containsMouse || modePopup.visible ? WizardTheme.accentBorder : WizardTheme.glassBorder

            property var modes: (WizardState.selectedMonitor >= 0 && WizardState.monitorModes[WizardState.selectedMonitor]) ? WizardState.monitorModes[WizardState.selectedMonitor] : []
            property string currentMode: {
              if (modes.length > 0) return modes[0].mode
              return "auto"
            }

            Text {
              anchors { left: parent.left; right: parent.right; leftMargin: 12; rightMargin: 24; verticalCenter: parent.verticalCenter }
              text: modeDropdown.currentMode
              color: WizardTheme.fg
              font { family: WizardTheme.mono; pixelSize: WizardTheme.fsSmall }
              elide: Text.ElideRight
            }

            Text {
              anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
              text: "\u25BE"
              color: WizardTheme.muted
              font { family: WizardTheme.mono; pixelSize: WizardTheme.fsSmall }
            }

            MouseArea {
              id: modeDropdown
              anchors.fill: parent
              hoverEnabled: true
              property string currentMode: parent.currentMode
              onClicked: modePopup.visible = !modePopup.visible
            }
          }

          // Mode popup
          Rectangle {
            id: modePopup
            visible: false
            focus: visible
            width: parent.width
            height: Math.min(modeCol.implicitHeight + 16, 220)
            radius: WizardTheme.radiusSmall
            color: WizardTheme.surface
            border.width: 1
            border.color: WizardTheme.glassBorder
            z: 100
            Keys.onEscapePressed: visible = false

            Column {
              id: modeCol
              anchors.fill: parent
              anchors.margins: 8
              clip: true

              Repeater {
                model: modeDropdown.modes

                Rectangle {
                  required property var modelData
                  required property int index
                  width: parent.width
                  height: 28
                  radius: 4
                  color: modeItemArea.containsMouse ? WizardTheme.accentDim : "transparent"

                  Text {
                    anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter }
                    text: modelData.mode
                    color: WizardTheme.fg
                    font { family: WizardTheme.mono; pixelSize: WizardTheme.fsTiny }
                  }

                  MouseArea {
                    id: modeItemArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                      var si = WizardState.selectedMonitor
                      var modes = WizardState.monitorModes.slice()
                      var m = modes[si].slice()
                      var sel = m.splice(index, 1)[0]
                      m.unshift(sel)
                      modes[si] = m
                      WizardState.monitorModes = modes
                      modePopup.visible = false
                    }
                  }
                }
              }
            }
          }
        }

        // Position X,Y
        Column {
          spacing: 2
          width: parent.width * 0.3 - 4

          Text {
            text: "Position"
            color: WizardTheme.muted
            font { family: WizardTheme.mono; pixelSize: WizardTheme.fsTiny }
          }

          Row {
            spacing: 4
            width: parent.width

            WizField {
              width: parent.width * 0.5 - 2
              placeholder: "X"
              value: {
                var si = WizardState.selectedMonitor
                var p = WizardState.monitorPositions[si]
                return p ? String(p.x) : "0"
              }
              onEdited: v => {
                var si = WizardState.selectedMonitor
                var pos = WizardState.monitorPositions.slice()
                var p = pos[si] || {x:0, y:0}
                pos[si] = { x: parseInt(v) || 0, y: p.y }
                WizardState.monitorPositions = pos
              }
            }

            WizField {
              width: parent.width * 0.5 - 2
              placeholder: "Y"
              value: {
                var si = WizardState.selectedMonitor
                var p = WizardState.monitorPositions[si]
                return p ? String(p.y) : "0"
              }
              onEdited: v => {
                var si = WizardState.selectedMonitor
                var pos = WizardState.monitorPositions.slice()
                var p = pos[si] || {x:0, y:0}
                pos[si] = { x: p.x, y: parseInt(v) || 0 }
                WizardState.monitorPositions = pos
              }
            }
          }
        }

        // Scale
        Column {
          spacing: 2
          width: parent.width * 0.2

          Text {
            text: "Scale"
            color: WizardTheme.muted
            font { family: WizardTheme.mono; pixelSize: WizardTheme.fsTiny }
          }

          Rectangle {
            width: parent.width
            height: 40
            radius: WizardTheme.radiusSmall
            color: WizardTheme.glassInput
            border.width: 1
            border.color: scaleArea.containsMouse || scalePopup.visible ? WizardTheme.accentBorder : WizardTheme.glassBorder

            property var scales: ["1.0", "1.25", "1.5", "1.75", "2.0"]
            property string currentScale: String(WizardState.monitorScales[WizardState.selectedMonitor] || "1.0")

            Text {
              anchors { left: parent.left; right: parent.right; leftMargin: 12; rightMargin: 24; verticalCenter: parent.verticalCenter }
              text: scaleArea.currentScale
              color: WizardTheme.fg
              font { family: WizardTheme.mono; pixelSize: WizardTheme.fsSmall }
              elide: Text.ElideRight
            }

            Text {
              anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
              text: "\u25BE"
              color: WizardTheme.muted
              font { family: WizardTheme.mono; pixelSize: WizardTheme.fsSmall }
            }

            MouseArea {
              id: scaleArea
              anchors.fill: parent
              hoverEnabled: true
              property string currentScale: parent.currentScale
              onClicked: scalePopup.visible = !scalePopup.visible
            }
          }

          Rectangle {
            id: scalePopup
            visible: false
            focus: visible
            width: parent.width
            height: scaleCol.implicitHeight + 16
            radius: WizardTheme.radiusSmall
            color: WizardTheme.surface
            border.width: 1
            border.color: WizardTheme.glassBorder
            z: 100
            Keys.onEscapePressed: visible = false

            Column {
              id: scaleCol
              anchors.fill: parent
              anchors.margins: 8

              Repeater {
                model: scaleArea.scales

                Rectangle {
                  required property string modelData
                  required property int index
                  width: parent.width
                  height: 28
                  radius: 4
                  color: scaleItemArea.containsMouse ? WizardTheme.accentDim : "transparent"

                  Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData
                    color: WizardTheme.fg
                    font { family: WizardTheme.mono; pixelSize: WizardTheme.fsSmall }
                  }

                  MouseArea {
                    id: scaleItemArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                      var si = WizardState.selectedMonitor
                      var s = WizardState.monitorScales.slice()
                      s[si] = parseFloat(modelData)
                      WizardState.monitorScales = s
                      scalePopup.visible = false
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }

  Text {
    visible: WizardState.discoveredMonitors.length === 0
    text: "No monitors detected. They can be configured after login."
    color: WizardTheme.muted
    font { family: WizardTheme.mono; pixelSize: WizardTheme.fsTiny }
    width: parent.width
    wrapMode: Text.Wrap
  }
}
