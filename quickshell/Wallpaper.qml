import QtQuick
import QtQuick.Window
import QtMultimedia
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Item {
  property var wallpaperConfig: null

  function loadWallpaperConfig() {
    confReader.running = true
  }

  Process {
    id: confReader
    command: ["cat", Quickshell.env("HOME") + "/.config/quickshell/wallpaper.json"]
    running: false
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          wallpaperConfig = JSON.parse(this.text)
        } catch(e) {
          console.log("Wallpaper: failed to parse config:", e)
        }
      }
    }
  }

  Timer { interval: 2000; running: true; repeat: true; onTriggered: loadWallpaperConfig() } // poll config every 2s
  Component.onCompleted: loadWallpaperConfig()

  Variants {
    model: Quickshell.screens

    Item {
      id: screen
      required property var modelData
      readonly property string monitorName: modelData.name

      property real mouseX: 0.5
      property real mouseY: 0.5
      property real smoothX: 0.5
      property real smoothY: 0.5

      Timer {
        interval: 16; running: true; repeat: true // ~60fps for smooth cursor tracking
        onTriggered: {
          var lerp = 0.15
          screen.smoothX += (screen.mouseX - screen.smoothX) * lerp
          screen.smoothY += (screen.mouseY - screen.smoothY) * lerp
        }
      }

      PanelWindow {
        id: root
        screen: screen.modelData

        WlrLayershell.namespace: "qs-wallpaper"
        WlrLayershell.layer: WlrLayer.Background
        anchors { top: true; left: true; right: true; bottom: true }
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"

        property color bgColor: "#111111"
        property string imgSrc: ""
        property string vidSrc: ""
        property bool zoomEnabled: false

        onWallpaperConfigChanged: {
          if (wallpaperConfig) {
            var c = wallpaperConfig
            root.bgColor = c.background || "#111111"
            root.zoomEnabled = !!(c.effects && c.effects.motion)

            var def = c.default || {}
            var img = def.image || ""
            var vid = def.video || ""

            var monitors = c.monitors || {}
            for (var name in monitors) {
              if (name === screen.monitorName) {
                img = monitors[name].image || img
                vid = monitors[name].video || vid
              }
            }
            root.imgSrc = img
            root.vidSrc = vid
          }
        }

        Item {
          anchors.fill: parent

          Rectangle { anchors.fill: parent; color: root.bgColor }

          Image {
            id: wallpaper
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            visible: root.imgSrc !== ""
            source: root.imgSrc !== "" ? "file://" + root.imgSrc : ""
            mipmap: false
          }

          VideoOutput {
            id: video
            anchors.fill: parent
            visible: root.vidSrc !== ""
          }

          MediaPlayer {
            id: player
            videoOutput: video
            loops: MediaPlayer.Infinite
            source: root.vidSrc !== "" ? "file://" + root.vidSrc : ""

            onSourceChanged: {
              if (source.toString() !== "") play()
            }
          }

          transform: [
            Scale {
              id: zoomScale
              origin.x: root.width / 2
              origin.y: root.height / 2
              xScale: root.zoomEnabled ? 1.1 : 1.0
              yScale: root.zoomEnabled ? 1.1 : 1.0
            },
            Translate {
              id: zoomTranslate
              x: root.zoomEnabled ? (screen.smoothX - 0.5) * root.width * -0.1 : 0
              y: root.zoomEnabled ? (screen.smoothY - 0.5) * root.height * -0.1 : 0
            }
          ]
        }
      }

      Process {
        id: cursorTracker
        command: ["cursor-tracker", String(screen.modelData.width), String(screen.modelData.height)]
        running: root.zoomEnabled

        stdout: SplitParser {
          onRead: data => {
            try {
              var pos = JSON.parse(data)
              screen.mouseX = pos.x
              screen.mouseY = pos.y
            } catch(e) {
              console.log("Wallpaper: cursor tracker parse error:", e)
            }
          }
        }
      }

    }
  }

  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: bgRoot
      required property var modelData
      screen: modelData

      WlrLayershell.namespace: "qs-wallpaper-bg"
      WlrLayershell.layer: WlrLayer.Background
      anchors { top: true; left: true; right: true; bottom: true }
      exclusionMode: ExclusionMode.Ignore
      color: "transparent"

      readonly property string monitorName: modelData.name

      property string imgSrc: ""
      property color bgColor: "#111111"

      onWallpaperConfigChanged: {
        if (wallpaperConfig) {
          var c = wallpaperConfig
          bgRoot.bgColor = c.background || "#111111"
          var def = c.default || {}
          var src = def.image || ""
          var monitors = c.monitors || {}
          for (var name in monitors) {
            if (name === bgRoot.monitorName) {
              src = monitors[name].image || src
            }
          }
          bgRoot.imgSrc = src
        }
      }

      Item {
        anchors.fill: parent

        Rectangle { anchors.fill: parent; color: bgRoot.bgColor }

        Image {
          id: bgImage
          anchors.fill: parent
          fillMode: Image.PreserveAspectCrop
          asynchronous: true
          cache: true
          visible: bgRoot.imgSrc !== ""
          source: bgRoot.imgSrc !== "" ? "file://" + bgRoot.imgSrc : ""
          mipmap: false
        }

        FastBlur {
          anchors.fill: parent
          source: bgImage
          visible: bgRoot.imgSrc !== ""
          radius: 64
          cached: true
        }
      }
    }
  }
}
