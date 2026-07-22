import QtQuick
import QtQuick.Window
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Variants {
  model: Quickshell.screens

  PanelWindow {
    id: root
    required property var modelData
    screen: modelData

    WlrLayershell.namespace: "qs-wallpaper-bg"
    WlrLayershell.layer: WlrLayer.Background
    anchors { top: true; left: true; right: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    readonly property string confFile: Quickshell.env("HOME") + "/.config/quickshell/wallpaper.json"
    readonly property string monitorName: modelData.name

    property string imgSrc: ""
    property color bgColor: "#111111"

    Process {
      id: confReader
      command: ["cat", root.confFile]
      running: false
      stdout: StdioCollector {
        onStreamFinished: {
          try {
            var c = JSON.parse(this.text)
            root.bgColor = c.background || "#111111"
            var def = c.default || {}
            var src = def.image || ""
            var monitors = c.monitors || {}
            for (var name in monitors) {
              if (name === root.monitorName) {
                src = monitors[name].image || src
              }
            }
            root.imgSrc = src
          } catch(e) {}
        }
      }
    }

    Timer { interval: 2000; running: true; repeat: true; onTriggered: confReader.running = true }
    Component.onCompleted: confReader.running = true

    Item {
      anchors.fill: parent

      Rectangle { anchors.fill: parent; color: root.bgColor }

      Image {
        id: bgImage
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        visible: root.imgSrc !== ""
        source: root.imgSrc !== "" ? "file://" + root.imgSrc : ""
        mipmap: false
      }

      FastBlur {
        anchors.fill: parent
        source: bgImage
        visible: bgImage.visible
        radius: 48
        cached: true
      }
    }
  }
}
