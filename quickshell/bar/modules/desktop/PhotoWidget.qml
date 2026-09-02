import QtQuick
import Quickshell
import Quickshell.Io
import "../../theme"
import "../../components"
import "../../services"

// Chromeless photo frame. Lists a folder through `mujo photos <dir>` - QML never
// calls bare CLIs, only the mujo wrapper has a guaranteed PATH - and either
// shows one still or cycles the folder on an interval.
BaseWidget {
    id: root

    property var wcfg: ({})
    readonly property string dir: wcfg.dir !== undefined && wcfg.dir !== ""
                                  ? String(wcfg.dir)
                                  : (Quickshell.env("HOME") || "") + "/Pictures"
    // Seconds between images; 0 keeps a single still.
    readonly property int interval: wcfg.interval !== undefined ? Number(wcfg.interval) : SettingsBus.get("desktop.photo.interval", 0)
    readonly property string fitMode: wcfg.fitMode !== undefined ? wcfg.fitMode : SettingsBus.get("desktop.photo.fitMode", "crop")
    readonly property string cardStyle: wcfg.cardStyle !== undefined ? wcfg.cardStyle : "chromeless"

    property var files: []
    property int index: 0

    chromeless: cardStyle === "chromeless"
    title: ""
    iconName: ""
    loading: files.length === 0 && error === ""
    onRetryClicked: { root.error = ""; root.loading = true; lsProc.running = true }

    onDirChanged: lsProc.running = true

    Process {
        id: lsProc
        command: ["mujo", "photos", root.dir]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var list = JSON.parse(this.text)
                    root.files = list
                    root.index = 0
                    root.loading = false
                    root.error = list.length === 0 ? "No images in " + root.dir : ""
                } catch (e) {
                    root.loading = false
                    root.error = "Cannot read " + root.dir
                }
            }
        }
    }

    Timer {
        interval: Math.max(1, root.interval) * 1000
        running: root.interval > 0 && root.files.length > 1
        repeat: true
        onTriggered: root.index = (root.index + 1) % root.files.length
    }

    // Rounded via a clipping Rectangle rather than a shader: the frame is one
    // static image, so the extra layer buys nothing.
    Rectangle {
        anchors.fill: parent
        anchors.margins: root.chromeless ? 0 : 6
        visible: root.files.length > 0
        radius: root.radius
        color: "transparent"
        clip: true

        Image {
            anchors.fill: parent
            source: root.files.length > 0 ? "file://" + root.files[root.index] : ""
            fillMode: root.fitMode === "fit" ? Image.PreserveAspectFit : Image.PreserveAspectCrop
            asynchronous: true
            cache: false
            // Decode near the on-screen size, not at the camera's. A 24 MP
            // photo is ~48 MB of RGBA to paint a frame a few hundred pixels
            // wide, and `cache: false` pays that again on every rotation.
            // Quantised to 256 px steps because width and height animate when
            // the widget is resized, and an unquantised binding would re-decode
            // the photo on every frame of that animation.
            // ponytail: the 2x box keeps crop-fill sharp for aspect mismatches
            // up to 2:1 either way; a true panorama in a tall frame still
            // softens. Derive the box from the source's own aspect
            // (implicitWidth/implicitHeight, known after first load) if it shows.
            readonly property int decodeBox: Math.max(256,
                Math.ceil(2 * Math.max(width, height) / 256) * 256)
            sourceSize.width: decodeBox
            sourceSize.height: decodeBox
        }
    }
}
