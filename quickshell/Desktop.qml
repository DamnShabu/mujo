import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets

Variants {
  model: Quickshell.screens

  PanelWindow {
    id: root
    required property var modelData
    screen: modelData

    WlrLayershell.namespace: "qs-desktop"
    WlrLayershell.layer: WlrLayer.Bottom
    anchors { top: true; left: true; right: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    readonly property string desktopPath: Quickshell.env("HOME") + "/Desktop"
    readonly property string posFile: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/quickshell/desktop-positions.json"
    readonly property string thumbDir: (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/quickshell/thumbs/"
    readonly property color text: "@base05@"
    readonly property color surface: Qt.rgba(1, 1, 1, 0.1)
    readonly property color surface0: "@base02@"
    readonly property color surface1: "@base03@"
    readonly property color blue: "@base0D@"

    property var menuTarget: null
    property string menuFilePath: ""
    property string menuFileName: ""
    property int menuX: 0
    property int menuY: 0

    property var positions: ({})
    property bool positionsLoaded: false
    property var selectedFiles: []
    property var delegateMap: ({})
    property bool multiDragActive: false
    property var mimeIconCache: ({})

    readonly property var extIcons:({
        // Images – jpg/png/webp go through imageThumb for actual thumbnails
        jpg:"image-x-generic",jpeg:"image-x-generic",svg:"image-x-generic",
        gif:"image-x-generic",bmp:"image-x-generic",ico:"image-x-generic",
        tiff:"image-x-generic",tif:"image-x-generic",heic:"image-x-generic",
        heif:"image-x-generic",avif:"image-x-generic",raw:"image-x-generic",
        // Videos – mp4/mkv/webm get real thumbs via videoThumb; others get icon
        mp4:"video-mp4",mkv:"video-x-matroska",webm:"video-webm",
        avi:"video-x-msvideo",mov:"video-quicktime",m4v:"video-mp4",
        flv:"video-x-flv",wmv:"video-x-ms-wmv",mpg:"video-mpeg",
        mpeg:"video-mpeg","3gp":"video-3gpp",
        // Audio – audio-x-generic is the standard XDG icon name
        mp3:"audio-x-generic",flac:"audio-x-generic",ogg:"audio-x-generic",
        wav:"audio-x-generic",m4a:"audio-x-generic",aac:"audio-x-generic",
        opus:"audio-x-generic",wma:"audio-x-generic",aiff:"audio-x-generic",
        ape:"audio-x-generic",alac:"audio-x-generic",
        // Archives / compressed
        zip:"application-zip",tar:"application-zip",gz:"application-zip",
        rar:"application-zip",tgz:"application-zip","7z":"application-zip",
        rar:"application-zip",tgz:"application-zip",tbz2:"application-zip",
        txz:"application-zip",bz:"application-zip",zst:"application-zip",
        // Packages
        deb:"application-vnd.debian.binary-package",
        rpm:"application-vnd.ms-software-installer",
        pkg:"application-vnd.apple.installer",
        // Disk images
        iso:"application-x-iso9660-image",img:"application-x-iso9660-image",
        dmg:"application-x-dmg",
        // Documents – Office / OpenDoc
        pdf:"application-pdf",
        doc:"application-vnd.ms-word",docx:"application-vnd.ms-word",
        odt:"application-vnd.oasis.opendocument.text",
        xls:"application-vnd.ms-excel",xlsx:"application-vnd.ms-excel",
        ods:"application-vnd.oasis.opendocument.spreadsheet",
        ppt:"application-vnd.ms-powerpoint",pptx:"application-vnd.ms-powerpoint",
        odp:"application-vnd.oasis.opendocument.presentation",
        // Plain text
        txt:"text-x-generic",rtf:"text-x-generic",csv:"text-csv",
        md:"text-x-generic",org:"text-x-generic",rst:"text-x-generic",
        tex:"text-x-generic",
        // E-books
        epub:"application-epub+zip",mobi:"application-ebook",
        azw:"application-ebook",azw3:"application-ebook",
        djvu:"image-vnd.djvu",
        // Scripts & source code
        py:"text-x-script",sh:"text-x-script",js:"text-x-script",
        ts:"text-x-script",rs:"text-x-script",c:"text-x-script",
        cpp:"text-x-script",h:"text-x-script",hh:"text-x-script",
        json:"text-x-script",yaml:"text-x-script",yml:"text-x-script",
        toml:"text-x-script",nix:"text-x-script",bash:"text-x-script",
        zsh:"text-x-script",fish:"text-x-script",css:"text-x-script",
        xml:"text-x-script",go:"text-x-script",rb:"text-x-script",
        lua:"text-x-script",php:"text-x-script",java:"text-x-script",
        kt:"text-x-script",swift:"text-x-script",sql:"text-x-script",
        r:"text-x-script",scala:"text-x-script",hs:"text-x-script",
        ml:"text-x-script",ex:"text-x-script",exs:"text-x-script",
        clj:"text-x-script",vim:"text-x-script",el:"text-x-script",
        jsx:"text-x-script",tsx:"text-x-script",vue:"text-x-script",
        svelte:"text-x-script",dart:"text-x-script",wasm:"text-x-script",
        ipynb:"text-x-script",html:"text-html",htm:"text-html",
        // Binaries & libs
        so:"application-x-elf",dll:"application-x-elf",dylib:"application-x-elf",
        a:"application-x-elf",o:"application-x-elf",
        jar:"application-java-archive",war:"application-java-archive",
        exe:"application-x-executable",msi:"application-x-msi",
        // Databases
        sqlite:"application-sqlite3",db:"application-sqlite3",sqlite3:"application-sqlite3",
        // Fonts
        ttf:"font-x-generic",otf:"font-x-generic",woff:"font-x-generic",
        woff2:"font-x-generic",eot:"font-x-generic",
        // Misc
        torrent:"application-x-bittorrent",
        log:"text-x-generic",conf:"text-x-generic",config:"text-x-generic",
        ini:"text-x-generic",cfg:"text-x-generic",env:"text-x-generic",
        bin:"application-x-executable"
    });

    FolderListModel {
      id: folderModel
      folder: "file://" + desktopPath
      showDirs: true; showFiles: true; showHidden: false
      sortField: FolderListModel.Name
    }

    Timer {
      interval: 2000; running: true; repeat: true
      onTriggered: {
        folderModel.folder = "file://" + root.desktopPath
        savePos()
      }
    }

    function ensurePosDir() {
      var cacheDir = root.posFile.substring(0, root.posFile.lastIndexOf("/") + 1)
      Quickshell.execDetached(["/bin/sh", "-c", "mkdir -p '" + cacheDir + "'" ])
    }

    Component.onCompleted: ensurePosDir()

    Process {
      id: posLoader
      command: ["/bin/sh", "-c", "cat '" + root.posFile + "' 2>/dev/null || echo '{}'"]
      running: true
      stdout: StdioCollector {
        onStreamFinished: {
          try {
            var loaded = JSON.parse(this.text)
            for (var key in loaded) {
              root.positions[key] = loaded[key]
            }
          } catch(e) {}
          root.positionsLoaded = true
        }
      }
    }

    Timer {
      id: posRefreshTimer
      interval: 100; running: !root.positionsLoaded; repeat: false
      onTriggered: root.refreshPositions()
    }

    function gridPos(index) {
      var cols = Math.max(1, Math.floor((root.width - 80) / 100))
      return { x: 40 + (index % cols) * 100, y: 40 + Math.floor(index / cols) * 120 }
    }

    function clampToScreen(x, y) {
      var maxX = Math.max(40, root.width - 100)
      var maxY = Math.max(40, root.height - 120)
      return { x: Math.min(Math.max(40, x), maxX), y: Math.min(Math.max(40, y), maxY) }
    }

    function getPos(fileName, index) {
      if (positions[fileName]) {
        var p = positions[fileName]
        var c = clampToScreen(p.x, p.y)
        if (c.x !== p.x || c.y !== p.y) { positions[fileName] = c }
        return c
      }
      var gp = gridPos(index)
      if (positionsLoaded) positions[fileName] = gp
      return gp
    }

    function snapToGrid(x, y) {
      var sx = 40 + Math.round((x - 40) / 100) * 100
      var sy = 40 + Math.round((y - 40) / 120) * 120
      return clampToScreen(sx, sy)
    }

    function snapKey(x, y) { return snapToGrid(x, y).x + "," + snapToGrid(x, y).y }

    function isCellFree(cx, cy, excludeFile) {
      for (var fn in delegateMap) {
        if (fn === excludeFile) continue
        var del = delegateMap[fn]
        if (del && snapKey(del.x, del.y) === cx + "," + cy) return false
      }
      return true
    }

    function resolveConflicts(fileNames) {
      var cw = 100, ch = 120, ox = 40, oy = 40
      for (var j = 0; j < fileNames.length; j++) {
        var fn = fileNames[j]
        var del = delegateMap[fn]
        if (!del) continue
        var sg = snapToGrid(del.x, del.y)
        if (!isCellFree(sg.x, sg.y, fn)) {
          var found = false
          var startRow = Math.max(0, Math.round((sg.y - oy) / ch))
          var startCol = Math.max(0, Math.round((sg.x - ox) / cw))
          for (var dr = 0; dr < 200 && !found; dr++) {
            for (var dc = 0; dc < 200 && !found; dc++) {
              var nx = ox + (startCol + dc) * cw, ny = oy + (startRow + dr) * ch
              if (isCellFree(nx, ny, fn)) {
                del.x = nx; del.y = ny
                del.itemX = nx; del.itemY = ny
                found = true
              }
            }
          }
        } else {
          del.x = sg.x; del.y = sg.y
          del.itemX = sg.x; del.itemY = sg.y
        }
      }
    }

    function savePos() {
      var json = JSON.stringify(positions)
      var encoded = Qt.btoa(json)
      Quickshell.execDetached(["/bin/sh", "-c", "printf '%s' \"$1\" | base64 -d > '" + root.posFile + "'", "_", encoded])
    }

    function refreshPositions() {
      for (var fn in delegateMap) {
        var del = delegateMap[fn]
        if (del) {
          var pos = root.getPos(fn, 0)
          del.itemX = pos.x; del.itemY = pos.y
        }
      }
    }

    function rectsOverlap(ax1, ay1, ax2, ay2, bx1, by1, bx2, by2) {
      return !(ax2 < bx1 || ax1 > bx2 || ay2 < by1 || ay1 > by2)
    }

    function selectNone() {
      root.selectedFiles = []
      root.multiDragActive = false
    }

    function toggleSelection(fileName, ctrlHeld) {
      var idx = root.selectedFiles.indexOf(fileName)
      if (ctrlHeld) {
        if (idx >= 0) {
          var copy = root.selectedFiles.slice()
          copy.splice(idx, 1)
          root.selectedFiles = copy
        } else {
          root.selectedFiles = root.selectedFiles.concat([fileName])
        }
      } else {
        root.selectedFiles = [fileName]
      }
    }

    function moveSelectedBy(dx, dy, excludeName) {
      for (var i = 0; i < root.selectedFiles.length; i++) {
        var fn = root.selectedFiles[i]
        if (fn === excludeName) continue
        var del = root.delegateMap[fn]
        if (del) {
          del.itemX += dx
          del.itemY += dy
          del.x = del.itemX
          del.y = del.itemY
        }
      }
    }

    Item {
      anchors.fill: parent

      Rectangle {
        id: selRect
        visible: false; z: 50
        color: Qt.rgba(89 / 255, 194 / 255, 255 / 255, 0.12)
        border.color: root.blue
        border.width: 1
        radius: 3
      }

      Canvas {
        id: gridCanvas
        anchors.fill: parent; z: 0
        visible: root.multiDragActive
        opacity: 0.25
        onVisibleChanged: { if (visible) requestPaint() }
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
          var ctx = getContext("2d")
          if (!ctx) return
          ctx.clearRect(0, 0, width, height)
          ctx.strokeStyle = root.blue
          ctx.lineWidth = 0.5
          var ox = 40, oy = 40
          for (var x = ox; x < width; x += 100) { ctx.beginPath(); ctx.moveTo(x, 0); ctx.lineTo(x, height); ctx.stroke() }
          for (var y = oy; y < height; y += 120) { ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(width, y); ctx.stroke() }
        }
      }

      Repeater {
        id: repeater
        model: folderModel
        delegate: Item {
          id: delegateItem
          width: 100; height: 120

          readonly property string delegateFileName: model.fileName
          property real itemX: root.getPos(model.fileName, index).x
          property real itemY: root.getPos(model.fileName, index).y
          property bool isSelected: root.selectedFiles.indexOf(model.fileName) >= 0
          property bool isHovered: false
          property bool wasDragged: false
          property real grabX: 0
          property real grabY: 0
          property real prevX: 0
          property real prevY: 0
          property string fileIconName: model.isDir ? "" : (root.extIcons[model.fileSuffix.toLowerCase()] || "")

          z: root.multiDragActive && isSelected ? 15 : wasDragged ? 20 : isSelected ? 10 : (isHovered ? 5 : 1)

          Component.onCompleted: {
            x = itemX
            y = itemY
            root.delegateMap[model.fileName] = delegateItem
          }
          Component.onDestruction: delete root.delegateMap[model.fileName]

          Rectangle {
            anchors.fill: parent; anchors.margins: 3; radius: 8
            color: wasDragged ? Qt.rgba(89 / 255, 194 / 255, 255 / 255, 0.2) : isHovered ? root.surface : isSelected ? Qt.rgba(89 / 255, 194 / 255, 255 / 255, 0.1) : "transparent"
            border.color: isSelected && !wasDragged ? root.blue : "transparent"
            border.width: 1
            Behavior on color { ColorAnimation { duration: 100 } }
          }

          ColumnLayout {
            anchors.centerIn: parent; spacing: 4; width: parent.width - 8

            Loader {
              Layout.alignment: Qt.AlignHCenter; Layout.preferredWidth: 48; Layout.preferredHeight: 48
              sourceComponent: {
                var sp = model.fileSuffix.toLowerCase();
                if (model.isDir) return folderThumb;
                if (sp === "jpg" || sp === "jpeg" || sp === "png" || sp === "webp" || sp === "gif" || sp === "bmp" || sp === "ico" || sp === "tiff" || sp === "tif" || sp === "heic" || sp === "heif" || sp === "avif" || sp === "svg" || sp === "raw" || sp === "djvu") return imageThumb;
                if (sp === "mp4" || sp === "mkv" || sp === "webm" || sp === "avi" || sp === "mov" || sp === "m4v" || sp === "flv" || sp === "wmv" || sp === "mpg" || sp === "mpeg" || sp === "3gp") return videoThumb;
                if (delegateItem.fileIconName) return fileIcon;
                return iconThumb;
              }

              Component { id: folderThumb
                IconImage {
                    width: 48; height: 48
                    source: Quickshell.iconPath("folder", true)
                        || Quickshell.iconPath("inode-directory", true)
                        || Quickshell.iconPath("gnome-fs-directory", true)
                }
              }

              Component { id: imageThumb
                Image { source: "file://" + model.filePath; fillMode: Image.PreserveAspectFit; width: 48; height: 48; asynchronous: true; cache: true; sourceSize { width: 96; height: 96 } }
              }

              Component { id: videoThumb
                Item {
                  width: 48; height: 48
                  property string thumbFile: root.thumbDir + model.fileName.replace("/", "_") + ".png"
                  property bool thumbReady: false
                  Image {
                    anchors.fill: parent
                    source: parent.thumbReady ? "file://" + parent.thumbFile : ""
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true; visible: parent.thumbReady
                  }
                  IconImage {
                    anchors.fill: parent
                    visible: !parent.thumbReady
                    source: Quickshell.iconPath("video-x-generic", true)
                  }
                  Process {
                    command: ["/bin/sh", "-c", "test -f \"$4\" || { mkdir -p \"$1\" && \"$2\" -y -ss 00:00:02 -i \"$3\" -vframes 1 -s 96x96 \"$4\" 2>/dev/null; }", "_", root.thumbDir, "@ffmpeg@/bin/ffmpeg", model.filePath, parent.thumbFile]
                    running: !parent.thumbReady
                    onExited: { if (exitCode === 0) parent.thumbReady = true }
                  }
                }
              }

              Component { id: iconThumb
                IconImage {
                    width: 48; height: 48
                    source: Quickshell.iconPath("text-x-generic", true)
                        || Quickshell.iconPath("application-x-generic", true)
                        || Quickshell.iconPath("inode-x-generic", true)
                        || Quickshell.iconPath("unknown", true)
                }
              }

              Component { id: fileIcon
                IconImage {
                    width: 48; height: 48
                    source: Quickshell.iconPath(delegateItem.fileIconName, true)
                        || Quickshell.iconPath("text-x-generic", true)
                        || Quickshell.iconPath("application-x-generic", true)
                        || Quickshell.iconPath("inode-x-generic", true)
                        || Quickshell.iconPath("unknown", true)
                }
              }

            }

            Text {
              Layout.fillWidth: true; Layout.alignment: Qt.AlignHCenter
              text: model.fileName
              color: isHovered || wasDragged ? "white" : isSelected ? root.blue : root.text
              font.family: "JetBrains Mono"; font.pixelSize: 11
              horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight; maximumLineCount: 2; wrapMode: Text.Wrap
            }
          }

          MouseArea {
            id: ma
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            drag.target: parent
            drag.axis: Drag.XAndYAxis
            drag.smoothed: false
            drag.minimumX: 40
            drag.minimumY: 40
            drag.maximumX: Math.max(40, root.width - 100)
            drag.maximumY: Math.max(40, root.height - 120)

            onEntered: delegateItem.isHovered = true
            onExited: delegateItem.isHovered = false

            onPressed: mouse => {
              selRect.visible = false
              bgMouse.bandActive = false
              if (mouse.button === Qt.LeftButton) {
                delegateItem.grabX = mouse.x
                delegateItem.grabY = mouse.y
                delegateItem.wasDragged = false
                var ctrl = mouse.modifiers & Qt.ControlModifier
                if (ctrl) {
                  root.toggleSelection(model.fileName, true)
                } else if (root.selectedFiles.indexOf(model.fileName) < 0) {
                  root.selectedFiles = [model.fileName]
                }
                mouse.accepted = true
              }
            }

            onPositionChanged: mouse => {
              if (mouse.buttons & Qt.LeftButton) {
                delegateItem.itemX = parent.x
                delegateItem.itemY = parent.y
                if (!delegateItem.wasDragged &&
                    (Math.abs(mouse.x - delegateItem.grabX) > 5 ||
                     Math.abs(mouse.y - delegateItem.grabY) > 5)) {
                  delegateItem.wasDragged = true
                  root.multiDragActive = true
                  delegateItem.prevX = parent.x
                  delegateItem.prevY = parent.y
                  return
                }
                if (delegateItem.wasDragged) {
                  var dx = parent.x - delegateItem.prevX
                  var dy = parent.y - delegateItem.prevY
                  if (dx !== 0 || dy !== 0) {
                    root.moveSelectedBy(dx, dy, model.fileName)
                    delegateItem.prevX = parent.x
                    delegateItem.prevY = parent.y
                  }
                }
              }
            }

            onReleased: mouse => {
              selRect.visible = false
              if (delegateItem.wasDragged) {
                delegateItem.isHovered = false
                var moved = root.selectedFiles.slice()
                var sg = root.snapToGrid(parent.x, parent.y)
                parent.x = sg.x; parent.y = sg.y
                delegateItem.itemX = sg.x; delegateItem.itemY = sg.y
                root.resolveConflicts(moved)
                for (var i = 0; i < moved.length; i++) {
                  var del = root.delegateMap[moved[i]]
                  if (del) root.positions[moved[i]] = { x: del.x, y: del.y }
                }
                root.savePos()
                delegateItem.wasDragged = false
                root.multiDragActive = false
                root.selectedFiles = []
              }
            }

            onClicked: mouse => {
              if (delegateItem.wasDragged) return
              if (mouse.button === Qt.LeftButton) {
                if (!(mouse.modifiers & Qt.ControlModifier)) {
                  root.selectedFiles = [model.fileName]
                }
              } else if (mouse.button === Qt.RightButton) {
                if (!(mouse.modifiers & Qt.ControlModifier)) {
                  root.selectedFiles = [model.fileName]
                }
                root.menuTarget = parent
                root.menuFilePath = model.filePath
                root.menuFileName = model.fileName
                root.menuX = parent.x + 50
                root.menuY = parent.y + 30
                menuPopup.close()
                menuPopup.open()
              }
            }

            onDoubleClicked: Quickshell.execDetached(["xdg-open", model.filePath])
          }
        }
        }

      MouseArea {
        id: bgMouse
        anchors.fill: parent; z: -1
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        property real bandX1: 0
        property real bandY1: 0
        property bool bandActive: false

        onPressed: mouse => {
          if (mouse.button === Qt.LeftButton) {
            bandX1 = mouse.x
            bandY1 = mouse.y
            bandActive = true
            selRect.visible = true
            selRect.x = bandX1; selRect.y = bandY1
            selRect.width = 0; selRect.height = 0
            if (!(mouse.modifiers & Qt.ControlModifier)) root.selectNone()
          }
        }

        onPositionChanged: mouse => {
          if (bandActive) {
            var rx = Math.min(bandX1, mouse.x)
            var ry = Math.min(bandY1, mouse.y)
            var rw = Math.abs(mouse.x - bandX1)
            var rh = Math.abs(mouse.y - bandY1)
            selRect.x = rx; selRect.y = ry
            selRect.width = rw; selRect.height = rh

            if (root.delegateMap) {
              var sel = []
              for (var fn in root.delegateMap) {
                var del = root.delegateMap[fn]
                if (del && root.rectsOverlap(rx, ry, rx + rw, ry + rh,
                                              del.x, del.y, del.x + del.width, del.y + del.height)) {
                  sel.push(fn)
                }
              }
            }

            if (mouse.modifiers & Qt.ControlModifier) {
              var merged = root.selectedFiles.slice()
              for (var i = 0; i < sel.length; i++) {
                if (merged.indexOf(sel[i]) < 0) merged.push(sel[i])
              }
              root.selectedFiles = merged
            } else {
              root.selectedFiles = sel
            }
          }
        }

        onReleased: mouse => {
          bandActive = false
          selRect.visible = false
          selRect.x = 0; selRect.y = 0
          selRect.width = 0; selRect.height = 0
        }

        onClicked: mouse => {
          menuPopup.close()
          if (mouse.button === Qt.RightButton) {
            root.menuTarget = null
            root.menuFilePath = ""
            root.menuFileName = ""
            root.menuX = mouse.x
            root.menuY = mouse.y
            menuPopup.open()
          }
        }
      }
    }

    Popup {
      id: menuPopup
      x: root.menuX; y: root.menuY
      width: 180; height: menuCol.implicitHeight + 8; padding: 0
      closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
      background: Rectangle { radius: 8; color: root.surface0; border.color: root.surface1; border.width: 1 }

      ColumnLayout {
        id: menuCol; anchors.fill: parent; anchors.margins: 4; spacing: 2

        Item { height: 28; Layout.fillWidth: true
          Rectangle { anchors.fill: parent; radius: 4; color: b1.containsMouse ? root.surface0 : "transparent"; Behavior on color { ColorAnimation { duration: 100 } } }
          Text { anchors.left: parent.left; anchors.leftMargin: 8; anchors.verticalCenter: parent.verticalCenter; text: "Open"; color: b1.containsMouse ? "white" : root.text; font.family: "JetBrains Mono"; font.pixelSize: 12 }
          MouseArea { id: b1; anchors.fill: parent; hoverEnabled: true; onClicked: { Quickshell.execDetached(["xdg-open", root.menuFilePath]); menuPopup.close() } }
        }

        Item { height: 28; Layout.fillWidth: true
          Rectangle { anchors.fill: parent; radius: 4; color: b2.containsMouse ? root.surface0 : "transparent"; Behavior on color { ColorAnimation { duration: 100 } } }
          Text { anchors.left: parent.left; anchors.leftMargin: 8; anchors.verticalCenter: parent.verticalCenter; text: "Open in Terminal"; color: b2.containsMouse ? "white" : root.text; font.family: "JetBrains Mono"; font.pixelSize: 12 }
          MouseArea { id: b2; anchors.fill: parent; hoverEnabled: true; onClicked: { Quickshell.execDetached(["kitty", "-d", root.menuFilePath]); menuPopup.close() } }
        }

        Repeater {
          model: root.menuTarget !== null ? ["Copy Path", "Rename", "Move to Trash", "Properties"] : ["Paste", "Open in Terminal", "Properties"]
          delegate: Item { id: rit; required property string modelData; height: 28; Layout.fillWidth: true
            Rectangle { anchors.fill: parent; radius: 4; color: b3.containsMouse ? root.surface0 : "transparent"; Behavior on color { ColorAnimation { duration: 100 } } }
            Text { anchors.left: parent.left; anchors.leftMargin: 8; anchors.verticalCenter: parent.verticalCenter; text: rit.modelData; color: b3.containsMouse ? "white" : root.text; font.family: "JetBrains Mono"; font.pixelSize: 12 }
            MouseArea { id: b3; anchors.fill: parent; hoverEnabled: true
              onClicked: {
                if (rit.modelData === "Copy Path") {
                  Quickshell.execDetached(["bash", "-c", "printf '%s' \"$1\" | \"$2\"", "_", root.menuFilePath, "@wl-clipboard@/bin/wl-copy"])
                } else if (rit.modelData === "Move to Trash") {
                  Quickshell.execDetached(["mv", root.menuFilePath, Quickshell.env("HOME") + "/.local/share/Trash/files/"])
                  Qt.callLater(function() { folderModel.folder = "file://" + root.desktopPath })
                } else if (rit.modelData === "Rename") {
                  renameDialog.open()
                }
                menuPopup.close()
              }
            }
          }
        }
      }
    }

    Dialog {
      id: renameDialog; title: "Rename"
      standardButtons: Dialog.Ok | Dialog.Cancel
      x: (parent.width - width) / 2; y: (parent.height - height) / 2; modal: true
      background: Rectangle { radius: 8; color: root.surface0; border.color: root.surface1; border.width: 1 }
      contentItem: ColumnLayout { spacing: 8
        Text { text: "Rename " + root.menuFileName; color: root.text; font.family: "JetBrains Mono"; font.pixelSize: 13 }
        TextInput { id: renameInput; text: root.menuFileName; color: root.text; font.family: "JetBrains Mono"; font.pixelSize: 12; selectByMouse: true; Layout.fillWidth: true
          Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: root.blue } }
      }
      onAccepted: {
        var old = root.menuFilePath
        var dir = old.substring(0, old.lastIndexOf("/") + 1)
        Quickshell.execDetached(["mv", old, dir + renameInput.text])
        Qt.callLater(function() { folderModel.folder = "file://" + root.desktopPath })
      }
    }
  }
}
