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
        id: wallpaperWindow
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
            wallpaperWindow.bgColor = c.background || "#111111"
            wallpaperWindow.zoomEnabled = !!(c.effects && c.effects.motion)

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
            wallpaperWindow.imgSrc = img
            wallpaperWindow.vidSrc = vid
          }
        }

        Item {
          anchors.fill: parent

          Rectangle { anchors.fill: parent; color: wallpaperWindow.bgColor }

          Image {
            id: wallpaper
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            visible: wallpaperWindow.imgSrc !== ""
            source: wallpaperWindow.imgSrc !== "" ? "file://" + wallpaperWindow.imgSrc : ""
            mipmap: false
          }

          VideoOutput {
            id: video
            anchors.fill: parent
            visible: wallpaperWindow.vidSrc !== ""
          }

          MediaPlayer {
            id: player
            videoOutput: video
            loops: MediaPlayer.Infinite
            source: wallpaperWindow.vidSrc !== "" ? "file://" + wallpaperWindow.vidSrc : ""

            onSourceChanged: {
              if (source.toString() !== "") play()
            }
          }

          transform: [
            Scale {
              id: zoomScale
              origin.x: wallpaperWindow.width / 2
              origin.y: wallpaperWindow.height / 2
              xScale: wallpaperWindow.zoomEnabled ? 1.1 : 1.0
              yScale: wallpaperWindow.zoomEnabled ? 1.1 : 1.0
            },
            Translate {
              id: zoomTranslate
              x: wallpaperWindow.zoomEnabled ? (screen.smoothX - 0.5) * wallpaperWindow.width * -0.1 : 0
              y: wallpaperWindow.zoomEnabled ? (screen.smoothY - 0.5) * wallpaperWindow.height * -0.1 : 0
            }
          ]
        }
      }

      Process {
        id: cursorTracker
        command: ["cursor-tracker", String(screen.modelData.width), String(screen.modelData.height)]
        running: wallpaperWindow.zoomEnabled

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
