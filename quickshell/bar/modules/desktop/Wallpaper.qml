import QtQuick
import QtMultimedia
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../../theme"

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
        (config && config.background && config.background !== "" && config.background !== "theme")
            ? config.background
            : Theme.active.bg

    readonly property bool motionEnabled:
        !!(config && config.effects && config.effects.motion)

    readonly property var engineConfig:
        (config && config.engine) ? config.engine : ({ "fps": 30, "silent": true, "volume": 50, "automute": true })

    readonly property int targetFps:
        engineConfig && engineConfig.fps ? engineConfig.fps : 30

    readonly property real engineVolume:
        engineConfig && engineConfig.volume !== undefined ? (engineConfig.volume / 100.0) : 0.5

    readonly property bool isSilent:
        engineConfig && engineConfig.silent !== undefined ? engineConfig.silent : true

    readonly property bool autoMute:
        engineConfig && engineConfig.automute !== undefined ? engineConfig.automute : true

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

    function engineFor(monitor) {
        if (!config) return ""
        var src = (config["default"] || {}).engine || ""
        var mon = (config.monitors || {})[monitor]
        return mon && mon.engine ? mon.engine : src
    }

    function typeFor(monitor) {
        if (!config) return "image"
        var src = (config["default"] || {}).type || ""
        var mon = (config.monitors || {})[monitor]
        return mon && mon.type ? mon.type : (src || "image")
    }

    // ── Config loader ───────────────────────────────────────────────

    // Watched, not polled: this used to fork `cat` every 2s for the life of the
    // shell. FileView reloads on the inotify change instead (same pattern as
    // SettingsBus / Notifications history).
    FileView {
        path: wallpaper.configPath
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                wallpaper.config = JSON.parse(text() || "{}")
            } catch (e) {
                console.warn("Wallpaper: config parse error:", e)
            }
        }
        onLoadFailed: function (err) { wallpaper.config = null }   // not created yet
    }

    // ── Main wallpaper surfaces ─────────────────────────────────────
    // Full-screen Background-layer window per screen.  Renders the
    // wallpaper image or video, with an optional 10 % zoom that tracks
    // the cursor position for a subtle parallax feel.

    Variants {
        model: Quickshell.screens

        Item {
            id: wpScreen
            required property var modelData
            readonly property string monitorName: modelData.name

            // Resolved per-monitor sources.  The leading `wallpaper.config`
            // read makes QML re-evaluate whenever config is reloaded.
            readonly property string imgSrc:
                wallpaper.config ? wallpaper.imageFor(monitorName) : ""
            readonly property string vidSrc:
                wallpaper.config ? wallpaper.videoFor(monitorName) : ""
            readonly property string engineSrc:
                wallpaper.config ? wallpaper.engineFor(monitorName) : ""
            readonly property string wpType:
                wallpaper.config ? wallpaper.typeFor(monitorName) : "image"
            // A wallpaper is one thing at a time. Without this an engine
            // wallpaper and a leftover `video` path both rendered.
            readonly property bool usesEngine:
                wpType === "scene" || wpType === "web" || wpType === "application"
            readonly property bool usesVideo: vidSrc !== "" && !usesEngine

            // Cursor position (normalised 0–1), smoothed for the zoom/pan.
            property real cursorX: 0.5
            property real cursorY: 0.5

            // These used to be chased by a 16ms repeating Timer running a lerp
            // in JavaScript — a hand-rolled 60fps loop on the QML main thread,
            // per screen. SmoothedAnimation is the built-in for "follow a
            // moving target with a soft lag" and interpolates on the render
            // thread instead, with the same ~100ms time constant the 0.15
            // per-frame lerp had.
            property real smoothX: wpScreen.cursorX
            property real smoothY: wpScreen.cursorY
            Behavior on smoothX { SmoothedAnimation { velocity: -1; duration: 120 } }
            Behavior on smoothY { SmoothedAnimation { velocity: -1; duration: 120 } }

            PanelWindow {
                id: wpWin
                screen: wpScreen.modelData

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
                        visible: wpScreen.imgSrc !== ""
                        source: wpScreen.imgSrc !== "" ? "file://" + wpScreen.imgSrc : ""
                        mipmap: false
                        // Without sourceSize a 4K JPEG decodes at native
                        // resolution — ~33 MB of RGBA held in the pixmap cache,
                        // per screen — to fill a 1080p surface. The 1.1x parallax
                        // scale below is why this is 1.15x and not 1.0x.
                        sourceSize.width: Math.round(wpWin.width * 1.15)
                        sourceSize.height: Math.round(wpWin.height * 1.15)
                    }

                    VideoOutput {
                        id: videoOut
                        anchors.fill: parent
                        visible: wpScreen.usesVideo
                    }

                    MediaPlayer {
                        id: mediaPlay
                        videoOutput: videoOut
                        audioOutput: AudioOutput {
                            volume: wallpaper.isSilent ? 0 : wallpaper.engineVolume
                            muted: wallpaper.isSilent
                        }
                        loops: MediaPlayer.Infinite
                        source: wpScreen.usesVideo ? "file://" + wpScreen.vidSrc : ""
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
                               ? (wpScreen.smoothX - 0.5) * wpWin.width * -0.1 : 0
                            y: wallpaper.motionEnabled
                               ? (wpScreen.smoothY - 0.5) * wpWin.height * -0.1 : 0
                        }
                    ]
                }
            }

            // Linux Wallpaper Engine renderer process for Scene / Web / Interactive wallpapers
            Process {
                id: lweProc
                command: {
                    var args = ["linux-wallpaperengine", "--screen-root", wpScreen.monitorName]
                    if (wallpaper.isSilent) args.push("--silent")
                    else {
                        args.push("--volume")
                        args.push(String(Math.round(wallpaper.engineVolume * 100)))
                    }
                    if (wallpaper.targetFps) {
                        args.push("--fps")
                        args.push(String(wallpaper.targetFps))
                    }
                    if (!wallpaper.autoMute) {
                        args.push("--noautomute")
                    }
                    args.push(wpScreen.engineSrc)
                    return args
                }
                running: wpScreen.engineSrc !== "" && wpScreen.usesEngine
            }

            // cursor-tracker: reads raw /dev/input mouse events and
            // outputs normalised {x,y} JSON.  Only spawned when the
            // motion effect is enabled.
            Process {
                command: ["cursor-tracker",
                          String(wpScreen.modelData.width),
                          String(wpScreen.modelData.height)]
                running: wallpaper.motionEnabled

                stdout: SplitParser {
                    onRead: data => {
                        try {
                            var pos = JSON.parse(data)
                            wpScreen.cursorX = pos.x
                            wpScreen.cursorY = pos.y
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
                    visible: false          // drawn only through the MultiEffect blur below
                    source: bdWin.imgSrc !== "" ? "file://" + bdWin.imgSrc : ""
                    mipmap: false
                    // This copy exists only to be blurred to blurMax 64, so it
                    // has no use for full resolution: decoding it at half size
                    // is invisible through that blur and quarters the memory.
                    // sourceSize is decode resolution only — the item is still
                    // laid out at window size, so the blur radius in screen
                    // pixels is unchanged.
                    sourceSize.width: Math.round(bdWin.width / 2)
                    sourceSize.height: Math.round(bdWin.height / 2)
                }

                MultiEffect {
                    anchors.fill: parent
                    source: bdImg
                    visible: bdWin.imgSrc !== ""
                    blurEnabled: true
                    blur: 1.0
                    blurMax: 64
                }
            }
        }
    }
}
