import QtQuick
import Quickshell
import Quickshell.Io
import "../../theme"
import "../../components"

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
    readonly property int interval: wcfg.interval !== undefined ? Number(wcfg.interval) : 0

    property var files: []
    property int index: 0

    chromeless: true
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
        visible: root.files.length > 0
        radius: Theme.radiusLg
        color: "transparent"
        clip: true

        Image {
            anchors.fill: parent
            source: root.files.length > 0 ? "file://" + root.files[root.index] : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
        }
    }
}
