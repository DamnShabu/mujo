import QtQuick
import QtQuick.Window
import QtMultimedia
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Item {

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
        interval: 16; running: true; repeat: true
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

        readonly property string confFile: Quickshell.env("HOME") + "/.config/quickshell/wallpaper.json"
        readonly property real transitionDuration: 800

        property var conf: ({})
        property color bgColor: "#111111"
        property string imgSrcA: ""
        property string imgSrcB: ""
        property string vidSrcA: ""
        property string vidSrcB: ""
        property bool zoomEnabled: false
        property bool panEnabled: false
        property bool transitioning: false
        property int activeIdx: 0

        readonly property var screenMap: ({"DP-1":0,"HDMI-A-1":1,"DP-2":2,"HDMI-A-2":3,"eDP-1":4})
        property int screenIdx: screenMap[screen.monitorName] !== undefined ? screenMap[screen.monitorName] : -1

        function loadConf() {
          confReader.running = true
        }

        Process {
          id: confReader
          command: ["cat", root.confFile]
          running: false
          stdout: StdioCollector {
            onStreamFinished: {
              try {
                var c = JSON.parse(this.text)
                root.conf = c
                root.bgColor = c.background || "#111111"
                root.zoomEnabled = !!(c.effects && c.effects.motion)
                root.panEnabled = !!(c.effects && c.effects.motion)

                var def = c.default || {}
                var newImg = ""
                var newVid = ""

                var monitors = c.monitors || {}
                for (var name in monitors) {
                  var mon = monitors[name]
                  if (name === screen.monitorName) {
                    newImg = mon.image || def.image || ""
                    newVid = mon.video || def.video || ""
                  }
                }
                if (newImg === "") newImg = def.image || ""
                if (newVid === "") newVid = def.video || ""

                if (newImg !== root.imgSrcA && newImg !== "") {
                  root.startFadeIn(newImg, newVid)
                } else if (newImg === "") {
                  root.imgSrcA = ""
                  root.vidSrcA = ""
                }
              } catch(e) {}
            }
          }
        }

        Timer { interval: 2000; running: true; repeat: true; onTriggered: root.loadConf() }
        Component.onCompleted: root.loadConf()

        function startFadeIn(newImg, newVid) {
          root.transitioning = true
          var oldIdx = root.activeIdx

          if (newImg !== "") {
            if (oldIdx === 0) {
              root.imgSrcB = newImg
              wallpaperB.source = "file://" + newImg
              wallpaperB.opacity = 0
              wallpaperB.visible = true
              animNew.target = wallpaperB
              animOld.target = wallpaperA
            } else {
              root.imgSrcA = newImg
              wallpaperA.source = "file://" + newImg
              wallpaperA.opacity = 0
              wallpaperA.visible = true
              animNew.target = wallpaperA
              animOld.target = wallpaperB
            }
          }

          if (newVid !== "") {
            if (oldIdx === 0) {
              root.vidSrcB = newVid
              videoB.source = "file://" + newVid
              videoB.opacity = 0
              videoB.visible = true
            } else {
              root.vidSrcA = newVid
              videoA.source = "file://" + newVid
              videoA.opacity = 0
              videoA.visible = true
            }
          }

          crossfade.restart()
        }

        SequentialAnimation {
          id: crossfade
          ParallelAnimation {
            NumberAnimation { id: animNew; property: "opacity"; from: 0; to: 1; duration: root.transitionDuration; easing.type: Easing.InOutQuad }
            NumberAnimation { id: animOld; property: "opacity"; from: 1; to: 0; duration: root.transitionDuration; easing.type: Easing.InOutQuad }
          }
          ScriptAction {
            script: {
              var oldIdx = root.activeIdx
              root.activeIdx = oldIdx === 0 ? 1 : 0
              root.transitioning = false

              if (oldIdx === 0) {
                wallpaperA.visible = false; wallpaperA.opacity = 0
                videoA.visible = false; videoA.opacity = 0
              } else {
                wallpaperB.visible = false; wallpaperB.opacity = 0
                videoB.visible = false; videoB.opacity = 0
              }
            }
          }
        }

        Item {
          anchors.fill: parent

          Rectangle { anchors.fill: parent; color: root.bgColor }

          Image {
            id: wallpaperA
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            visible: root.imgSrcA !== ""
            source: root.imgSrcA !== "" ? "file://" + root.imgSrcA : ""
            mipmap: false

            Behavior on opacity {
              enabled: root.transitioning
              NumberAnimation { duration: root.transitionDuration; easing.type: Easing.InOutQuad }
            }

            onStatusChanged: {
              if (status === Image.Ready && !root.transitioning && opacity < 1) {
                opacity = 1
              }
            }
          }

          Image {
            id: wallpaperB
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            visible: false
            opacity: 0
            mipmap: false

            Behavior on opacity {
              enabled: root.transitioning
              NumberAnimation { duration: root.transitionDuration; easing.type: Easing.InOutQuad }
            }

            onStatusChanged: {
              if (status === Image.Ready && !root.transitioning && opacity < 1) {
                opacity = 1
              }
            }
          }

          VideoOutput {
            id: videoA
            anchors.fill: parent
            visible: false
            opacity: 0

            Behavior on opacity {
              enabled: root.transitioning
              NumberAnimation { duration: root.transitionDuration; easing.type: Easing.InOutQuad }
            }
          }

          VideoOutput {
            id: videoB
            anchors.fill: parent
            visible: false
            opacity: 0

            Behavior on opacity {
              enabled: root.transitioning
              NumberAnimation { duration: root.transitionDuration; easing.type: Easing.InOutQuad }
            }
          }

          MediaPlayer {
            id: playerA
            videoOutput: videoA
            loops: MediaPlayer.Infinite
            source: root.vidSrcA !== "" ? "file://" + root.vidSrcA : ""

            onSourceChanged: {
              if (source.toString() !== "") play()
            }
          }

          MediaPlayer {
            id: playerB
            videoOutput: videoB
            loops: MediaPlayer.Infinite
            source: root.vidSrcB !== "" ? "file://" + root.vidSrcB : ""

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
            } catch(e) {}
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

      readonly property string confFile: Quickshell.env("HOME") + "/.config/quickshell/wallpaper.json"
      readonly property string monitorName: modelData.name

      property string imgSrc: ""
      property color bgColor: "#111111"

      Process {
        id: bgConfReader
        command: ["cat", bgRoot.confFile]
        running: false
        stdout: StdioCollector {
          onStreamFinished: {
            try {
              var c = JSON.parse(this.text)
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
            } catch(e) {}
          }
        }
      }

      Timer { interval: 2000; running: true; repeat: true; onTriggered: bgConfReader.running = true }
      Component.onCompleted: bgConfReader.running = true

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
          visible: bgImage.visible
          radius: 48
          cached: true
        }
      }
    }
  }
}
