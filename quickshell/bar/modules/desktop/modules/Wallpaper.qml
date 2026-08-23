import QtQuick
import QtMultimedia
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Desktop wallpaper: per-screen image/video with optional cursor-tracking
// zoom/pan, plus blurred backdrop surfaces for niri's overview animation.
//
// Config: ~/.config/quickshell/wallpaper.json  (managed by `mujo wallpaper`)
// Schema:
//   { "background": "#111111",
//     "effects": { "motion": false },
//     "default": { "image": "/path/to/img", "video": "/path/to/vid" },
//     "monitors": { "DP-1": { "image": "...", "video": "..." } } }
Item {
    id: wallpaper

    // ── Configuration ───────────────────────────────────────────────

    property var config: null

    readonly property string configPath:
        (Quickshell.env("HOME") || "/tmp") + "/.config/quickshell/wallpaper.json"

    readonly property color bgColor:
        config && config.background ? config.background : "#111111"

    readonly property bool motionEnabled:
        !!(config && config.effects && config.effects.motion)

    // Resolve the image/video path for a monitor.  Callers must reference
    // `wallpaper.config` in their binding expression so QML registers the
    // dependency (reads inside a function body are invisible to the engine).
    function imageFor(monitor) {
        if (!config) return ""
        var src = (config["default"] || {}).image || ""
        var mon = (config.monitors || {})[monitor]
        return mon && mon.image ? mon.image : src
    }

    function videoFor(monitor) {
        if (!config) return ""
        var src = (config["default"] || {}).video || ""
        var mon = (config.monitors || {})[monitor]
        return mon && mon.video ? mon.video : src
    }

    // ── Config loader ───────────────────────────────────────────────

    Process {
        id: configReader
        command: ["cat", wallpaper.configPath]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    wallpaper.config = JSON.parse(this.text)
                } catch (e) {
                    console.warn("Wallpaper: config parse error:", e)
                }
            }
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: configReader.running = true
    }

    Component.onCompleted: configReader.running = true

    // ── Main wallpaper surfaces ─────────────────────────────────────
    // Full-screen Background-layer window per screen.  Renders the
    // wallpaper image or video, with an optional 10 % zoom that tracks
    // the cursor position for a subtle parallax feel.

    Variants {
        model: Quickshell.screens

        Item {
            id: screen
            required property var modelData
            readonly property string monitorName: modelData.name

            // Resolved per-monitor sources.  The leading `wallpaper.config`
            // read makes QML re-evaluate whenever config is reloaded.
            readonly property string imgSrc:
                wallpaper.config ? wallpaper.imageFor(monitorName) : ""
            readonly property string vidSrc:
                wallpaper.config ? wallpaper.videoFor(monitorName) : ""

            // Cursor position (normalised 0–1), lerp-smoothed for zoom.
            property real cursorX: 0.5
            property real cursorY: 0.5
            property real smoothX: 0.5
            property real smoothY: 0.5

            Timer {
                interval: 16          // ~60 fps
                running: wallpaper.motionEnabled
                repeat: true
                onTriggered: {
                    screen.smoothX += (screen.cursorX - screen.smoothX) * 0.15
                    screen.smoothY += (screen.cursorY - screen.smoothY) * 0.15
                }
            }

            PanelWindow {
                id: wpWin
                screen: screen.modelData

                WlrLayershell.namespace: "qs-wallpaper"
                WlrLayershell.layer: WlrLayer.Background
                anchors { top: true; left: true; right: true; bottom: true }
                exclusionMode: ExclusionMode.Ignore
                color: "transparent"

                Item {
                    anchors.fill: parent

                    Rectangle {
                        anchors.fill: parent
                        color: wallpaper.bgColor
                    }

                    Image {
                        anchors.fill: parent
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: true
                        visible: screen.imgSrc !== ""
                        source: screen.imgSrc !== "" ? "file://" + screen.imgSrc : ""
                        mipmap: false
                    }

                    VideoOutput {
                        id: videoOut
                        anchors.fill: parent
                        visible: screen.vidSrc !== ""
                    }

                    MediaPlayer {
                        videoOutput: videoOut
                        loops: MediaPlayer.Infinite
                        source: screen.vidSrc !== "" ? "file://" + screen.vidSrc : ""
                        onSourceChanged: if (source.toString() !== "") play()
                    }

                    transform: [
                        Scale {
                            origin.x: wpWin.width / 2
                            origin.y: wpWin.height / 2
                            xScale: wallpaper.motionEnabled ? 1.1 : 1.0
                            yScale: wallpaper.motionEnabled ? 1.1 : 1.0
                        },
                        Translate {
                            x: wallpaper.motionEnabled
                               ? (screen.smoothX - 0.5) * wpWin.width * -0.1 : 0
                            y: wallpaper.motionEnabled
                               ? (screen.smoothY - 0.5) * wpWin.height * -0.1 : 0
                        }
                    ]
                }
            }

            // cursor-tracker: reads raw /dev/input mouse events and
            // outputs normalised {x,y} JSON.  Only spawned when the
            // motion effect is enabled.
            Process {
                command: ["cursor-tracker",
                          String(screen.modelData.width),
                          String(screen.modelData.height)]
                running: wallpaper.motionEnabled

                stdout: SplitParser {
                    onRead: data => {
                        try {
                            var pos = JSON.parse(data)
                            screen.cursorX = pos.x
                            screen.cursorY = pos.y
                        } catch (e) {
                            console.warn("Wallpaper: cursor parse error:", e)
                        }
                    }
                }
            }
        }
    }

    // ── Backdrop surfaces ───────────────────────────────────────────
    // Blurred copy of the wallpaper image in niri's backdrop layer.
    // Shown during the overview / workspace-switch animation.
    // Video is not used here — only the static image, heavily blurred.

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: bdWin
            required property var modelData
            screen: modelData

            WlrLayershell.namespace: "qs-wallpaper-bg"
            WlrLayershell.layer: WlrLayer.Background
            anchors { top: true; left: true; right: true; bottom: true }
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"

            readonly property string monitorName: modelData.name
            readonly property string imgSrc:
                wallpaper.config ? wallpaper.imageFor(monitorName) : ""

            Item {
                anchors.fill: parent

                Rectangle {
                    anchors.fill: parent
                    color: wallpaper.bgColor
                }

                Image {
                    id: bdImg
                    anchors.fill: parent
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                    visible: bdWin.imgSrc !== ""
                    source: bdWin.imgSrc !== "" ? "file://" + bdWin.imgSrc : ""
                    mipmap: false
                }

                FastBlur {
                    anchors.fill: parent
                    source: bdImg
                    visible: bdWin.imgSrc !== ""
                    radius: 64
                    cached: true
                }
            }
        }
    }
}
