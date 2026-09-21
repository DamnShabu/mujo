import QtQuick
import QtQuick.Layouts
import "../../theme"
import "../../components"
import "../../services"

// Wallpaper presentation settings: cursor parallax, the letterbox fill colour,
// and Wallpaper Engine's render budget.
//
// Split out of WallpaperPanel because these are the only genuinely *settings*
// controls in the Wallpapers category — the three other tabs browse a
// catalogue. Keeping them in a plain ColumnLayout of MujoCards lets the page
// host them in a scrolling SettingsPage, the same as every other category.
ColumnLayout {
    id: root
    Layout.fillWidth: true
    spacing: 14

    // Owned by AppearancePage, which watches wallpaper.json for both of us.
    required property bool motionOn
    required property string letterbox

    // `mujo wallpaper …`. The host runs it so there is one writer to the
    // wallpaper config, and the FileView reload updates both of us.
    signal wpRun(var args)

    readonly property var bgSwatches: [
        "#000000", "#0b0e13", "#111111", "#181825",
        "#1d2021", "#16161e", "#191724", "#21252b"
    ]

    // ── 1. Parallax & Background ──────────────────────────────────────────────
    MujoCard {
        title: "Parallax & Background"
        iconName: "blur_on"

        MujoSettingRow {
            iconName: "pan_tool_alt"
            title: "Cursor Parallax Effect"
            description: "Subtle zoom and directional pan that follows cursor coordinates."

            ToggleSwitch {
                checked: root.motionOn
                onToggled: function (c) { root.wpRun(["motion", c ? "on" : "off"]) }
            }
        }

        MujoSettingRow {
            iconName: "format_color_fill"
            title: "Letterbox Fill Colour"
            description: "Shown around wallpapers that do not match the screen aspect ratio."

            Flow {
                Layout.preferredWidth: 190
                spacing: 6

                Rectangle {
                    readonly property bool selected:
                        root.letterbox.toLowerCase() === "theme"
                        || root.letterbox.toLowerCase() === Theme.active.bg.toLowerCase()
                    implicitWidth: 58
                    implicitHeight: 30
                    radius: Theme.radiusSm
                    color: selected ? Theme.accentDim : Theme.surfaceActive
                    border.color: selected ? Theme.accent : Theme.border

                    Accessible.role: Accessible.RadioButton
                    Accessible.name: "Theme background"
                    Accessible.checked: selected

                    Text {
                        anchors.centerIn: parent
                        text: "Theme"
                        color: parent.selected ? Theme.accent : Theme.textSecondary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        font.bold: parent.selected
                    }
                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: root.wpRun(["background", "theme"]) }
                }

                Repeater {
                    model: root.bgSwatches
                    delegate: Rectangle {
                        required property string modelData
                        readonly property bool selected:
                            root.letterbox.toLowerCase() === modelData.toLowerCase()
                        implicitWidth: 30
                        implicitHeight: 30
                        radius: Theme.radiusSm
                        color: modelData
                        border.width: selected ? 2 : 1
                        border.color: selected ? Theme.accent : Theme.borderStrong

                        Accessible.role: Accessible.RadioButton
                        Accessible.name: "Letterbox colour " + modelData
                        Accessible.checked: selected

                        MaterialIcon {
                            visible: parent.selected
                            anchors.centerIn: parent
                            iconName: "check"
                            pixelSize: 15
                            color: Theme.accent
                        }
                        HoverHandler { cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: root.wpRun(["background", parent.modelData]) }
                    }
                }
            }
        }
    }

    // ── 2. Wallpaper Engine Performance ───────────────────────────────────────
    MujoCard {
        title: "Wallpaper Engine Performance"
        iconName: "sports_esports"

        MujoSettingRow {
            iconName: "speed"
            title: "Frame Rate Target"
            description: "Maximum render FPS for live scene and video wallpapers."

            MujoSegmented {
                model: [
                    { id: 15, label: "15 FPS" },
                    { id: 30, label: "30 FPS" },
                    { id: 60, label: "60 FPS" }
                ]
                current: WallpaperEngine.targetFps
                onSelected: function (fps) {
                    WallpaperEngine.setEngineConfig(fps, undefined, undefined, undefined)
                }
            }
        }

        MujoSettingRow {
            iconName: "volume_up"
            title: "Live Wallpaper Audio"
            description: "Background audio playback for video and interactive scenes."

            RowLayout {
                spacing: 8
                DisplayChip {
                    label: WallpaperEngine.isSilent ? "Muted" : "Active"
                    selected: !WallpaperEngine.isSilent
                    onClicked: WallpaperEngine.setEngineConfig(undefined, undefined, !WallpaperEngine.isSilent, undefined)
                }
                Slider {
                    Layout.preferredWidth: 120
                    enabled: !WallpaperEngine.isSilent
                    from: 0
                    to: 100
                    value: WallpaperEngine.soundVolume
                    format: "%"
                    onMoved: function (v) {
                        WallpaperEngine.setEngineConfig(undefined, Math.round(v), undefined, undefined)
                    }
                }
            }
        }

        MujoSettingRow {
            iconName: "volume_off"
            title: "Auto-Mute on Other Audio"
            description: "Mute wallpaper sound when another application plays audio or takes focus."

            ToggleSwitch {
                checked: WallpaperEngine.autoMute
                onToggled: function (c) { WallpaperEngine.setEngineConfig(undefined, undefined, undefined, c) }
            }
        }
    }
}
