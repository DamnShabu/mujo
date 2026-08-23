import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

// Desktop customization: wallpaper shortcut + current preview, wallpaper effects
// (motion parallax, letterbox background color), and a read-out of the active
// keyboard layout (owned by the NixOS niri config — shown, not edited here, to
// avoid a second source of truth).
Item {
    id: root

    readonly property var bgSwatches: [
        "#000000", "#0b0e13", "#111111", "#181825",
        "#1d2021", "#16161e", "#191724", "#21252b"
    ]

    property string currentImage: ""
    property string background: "#111111"
    property bool motion: false
    property var kbLayouts: []
    property int kbCurrent: 0

    function runWp(args) { Quickshell.execDetached(["mujo", "wallpaper"].concat(args)) }

    FileView {
        id: wpConf
        path: (Quickshell.env("HOME") || "/tmp") + "/.config/quickshell/wallpaper.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                var c = JSON.parse(text())
                root.currentImage = (c["default"] || {}).image || ""
                root.background = c.background || "#111111"
                root.motion = !!(c.effects && c.effects.motion)
            } catch (e) { /* ignore */ }
        }
    }

    Process {
        id: kbProc
        command: ["niri", "msg", "-j", "keyboard-layouts"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var k = JSON.parse(this.text)
                    root.kbLayouts = k.names || []
                    root.kbCurrent = k.current_idx || 0
                } catch (e) { root.kbLayouts = [] }
            }
        }
    }
    Component.onCompleted: kbProc.running = true

    // ── Desktop widgets ──────────────────────────────────────────────────────
    property bool widgetsLocked: true
    property var widgetList: []
    function runW(args) { Quickshell.execDetached(["mujo", "widgets"].concat(args)) }
    FileView {
        id: widgetsConf
        path: (Quickshell.env("HOME") || "/tmp") + "/.config/qsshell/widgets.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try { var c = JSON.parse(text()); root.widgetsLocked = !!c.locked; root.widgetList = c.widgets || [] }
            catch (e) { root.widgetList = [] }
        }
    }
    readonly property var widgetTypes: [
        { t: "clock", l: "Clock", i: "schedule" },
        { t: "weather", l: "Weather", i: "partly_cloudy_day" },
        { t: "sysmon", l: "System", i: "monitoring" }
    ]

    Flickable {
        anchors.fill: parent
        contentHeight: outerCol.implicitHeight + 52
        clip: true
        boundsBehavior: Flickable.StopAtBounds

    ColumnLayout {
        id: outerCol
        width: parent.width - 52
        x: 26
        y: 26
        spacing: 22

        ColumnLayout {
            spacing: 3
            Text {
                text: "Desktop"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeTitle + 7
                font.bold: true
            }
            Text {
                text: "Wallpaper, desktop effects, and input layout."
                color: Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeBody
            }
        }

        // ── Wallpaper ─────────────────────────────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 12
            SectionLabel { text: "Wallpaper" }

            RowLayout {
                Layout.fillWidth: true
                spacing: 16

                Rectangle {
                    width: 168; height: 104
                    radius: Theme.radiusMd
                    color: root.background
                    border.color: Theme.border
                    clip: true
                    Image {
                        anchors.fill: parent
                        anchors.margins: 2
                        source: root.currentImage !== "" ? "file://" + root.currentImage : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        sourceSize.width: 360
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: root.currentImage === ""
                        text: "No wallpaper"
                        color: Theme.textDim
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                    }
                }

                ColumnLayout {
                    Layout.alignment: Qt.AlignTop
                    spacing: 10
                    DialogButton {
                        text: "Open wallpaper library"
                        primary: true
                        onClicked: Quickshell.execDetached(["mujo", "settings", "wallpaper"])
                    }
                    DialogButton {
                        text: "Random wallpaper"
                        onClicked: root.runWp(["random"])
                    }
                }
                Item { Layout.fillWidth: true }
            }
        }

        // ── Effects ───────────────────────────────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 12
            SectionLabel { text: "Effects" }

            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                ColumnLayout {
                    spacing: 2
                    Text {
                        text: "Cursor parallax"
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeBody
                    }
                    Text {
                        text: "Subtle zoom + pan that follows the cursor."
                        color: Theme.textSecondary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                    }
                }
                Item { Layout.fillWidth: true }
                ToggleSwitch {
                    checked: root.motion
                    onToggled: function(c) { root.runWp(["motion", c ? "on" : "off"]) }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.topMargin: 4
                spacing: 8
                Text {
                    text: "Background color"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeBody
                }
                Text {
                    text: "Shown around wallpapers that don't fill the screen."
                    color: Theme.textSecondary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                }
                Flow {
                    Layout.fillWidth: true
                    spacing: 8
                    Repeater {
                        model: root.bgSwatches
                        delegate: Rectangle {
                            required property var modelData
                            readonly property bool selected: root.background.toLowerCase() === modelData.toLowerCase()
                            width: 30; height: 30
                            radius: Theme.radiusSm
                            color: modelData
                            border.width: selected ? 3 : 1
                            border.color: selected ? Theme.accent : Theme.borderStrong
                            MaterialIcon {
                                visible: parent.selected
                                anchors.centerIn: parent
                                iconName: "check"
                                pixelSize: 15
                                color: Theme.accent
                            }
                            HoverHandler { cursorShape: Qt.PointingHandCursor }
                            TapHandler { onTapped: root.runWp(["background", modelData]) }
                        }
                    }
                }
            }
        }

        // ── Audio visualizer (WP-15) ──────────────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                SectionLabel { text: "Audio visualizer" }
                Item { Layout.fillWidth: true }
                ToggleSwitch {
                    checked: SettingsBus.get("cava.enabled", false)
                    onToggled: function (c) { SettingsBus.set("cava.enabled", c) }
                }
            }
            Text {
                Layout.fillWidth: true
                text: "cava spectrum on the desktop. Pauses when audio is muted or nothing is playing."
                color: Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                wrapMode: Text.WordWrap
            }

            // Style + position chips.
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Repeater {
                    model: ["bars", "wave", "circle"]
                    delegate: DisplayChip {
                        required property var modelData
                        label: modelData
                        selected: SettingsBus.get("cava.style", "bars") === modelData
                        onClicked: SettingsBus.set("cava.style", modelData)
                    }
                }
                Item { Layout.fillWidth: true }
                Repeater {
                    model: ["bottom", "center", "top"]
                    delegate: DisplayChip {
                        required property var modelData
                        label: modelData
                        selected: SettingsBus.get("cava.position", "bottom") === modelData
                        onClicked: SettingsBus.set("cava.position", modelData)
                    }
                }
            }

            // Color: accent or a preset swatch.
            Flow {
                Layout.fillWidth: true
                spacing: 8
                DisplayChip {
                    label: "Accent"
                    selected: SettingsBus.get("cava.color", "") === ""
                    onClicked: SettingsBus.set("cava.color", "")
                }
                Repeater {
                    model: ["#f38ba8", "#a6e3a1", "#89b4fa", "#f9e2af", "#cba6f7"]
                    delegate: Rectangle {
                        required property var modelData
                        readonly property bool sel: SettingsBus.get("cava.color", "") === modelData
                        width: 30; height: 30
                        radius: Theme.radiusSm
                        color: modelData
                        border.width: sel ? 3 : 1
                        border.color: sel ? Theme.accent : Theme.borderStrong
                        TapHandler { onTapped: SettingsBus.set("cava.color", modelData) }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                Text {
                    text: "Opacity"
                    color: Theme.text
                    font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeBody
                }
                Slider {
                    Layout.fillWidth: true
                    from: 0.2; to: 1
                    value: SettingsBus.get("cava.opacity", 0.85)
                    onMoved: function (v) { SettingsBus.set("cava.opacity", v) }
                }
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                Text {
                    text: "Height"
                    color: Theme.text
                    font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeBody
                }
                Slider {
                    Layout.fillWidth: true
                    from: 0.08; to: 0.4
                    value: SettingsBus.get("cava.height", 0.18)
                    onMoved: function (v) { SettingsBus.set("cava.height", v) }
                }
                ToggleSwitch {
                    checked: SettingsBus.get("cava.reflection", true)
                    onToggled: function (c) { SettingsBus.set("cava.reflection", c) }
                }
            }
        }

        // ── Keyboard ──────────────────────────────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 12
            SectionLabel { text: "Keyboard layout" }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Repeater {
                    model: root.kbLayouts
                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        readonly property bool on: index === root.kbCurrent
                        implicitWidth: kbLabel.implicitWidth + 22
                        implicitHeight: 30
                        radius: Theme.radiusSm
                        color: on ? Theme.accentDim : Theme.surface
                        border.color: on ? Theme.accent : Theme.border
                        Text {
                            id: kbLabel
                            anchors.centerIn: parent
                            text: modelData
                            color: on ? Theme.accent : Theme.textSecondary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                        }
                    }
                }
                Text {
                    visible: root.kbLayouts.length === 0
                    text: "—"
                    color: Theme.textDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeBody
                }
                Item { Layout.fillWidth: true }
            }
            Text {
                text: "Configured in NixOS (niri xkb). Switch with Alt+Shift."
                color: Theme.textDim
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: Theme.border }

        // ── Desktop widgets ────────────────────────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 12
            RowLayout {
                Layout.fillWidth: true
                SectionLabel { text: "Desktop widgets" }
                Item { Layout.fillWidth: true }
                Text {
                    text: root.widgetsLocked ? "Locked" : "Editing"
                    color: root.widgetsLocked ? Theme.textDim : Theme.accent
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                }
                ToggleSwitch {
                    checked: !root.widgetsLocked
                    onToggled: function(c) { root.runW(["lock", c ? "off" : "on"]) }
                }
            }
            Text {
                text: "Toggle editing to drag widgets on the desktop. Positions persist across reboots."
                color: Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
            }

            Flow {
                Layout.fillWidth: true
                spacing: 8
                Repeater {
                    model: root.widgetTypes
                    delegate: Rectangle {
                        required property var modelData
                        implicitWidth: addRow.implicitWidth + 20
                        implicitHeight: 34
                        radius: Theme.radiusSm
                        color: add_hh.hovered ? Theme.surfaceHover : Theme.surface
                        border.color: Theme.border
                        RowLayout {
                            id: addRow
                            anchors.centerIn: parent
                            spacing: 7
                            MaterialIcon { iconName: "add"; pixelSize: 16; color: Theme.accent }
                            MaterialIcon { iconName: modelData.i; pixelSize: 16; color: Theme.textSecondary }
                            Text { text: modelData.l; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSmall }
                        }
                        HoverHandler { id: add_hh; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: root.runW(["add", modelData.t]) }
                    }
                }
                DisplayChip { label: "Reset positions"; onClicked: root.runW(["reset"]) }
            }

            // current widgets
            ColumnLayout {
                Layout.fillWidth: true
                Layout.topMargin: 4
                spacing: 6
                Repeater {
                    model: root.widgetList
                    delegate: Rectangle {
                        required property var modelData
                        Layout.fillWidth: true
                        implicitHeight: 40
                        radius: Theme.radiusSm
                        color: Theme.surface
                        border.color: Theme.border
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 6
                            spacing: 10
                            MaterialIcon {
                                iconName: modelData.type === "clock" ? "schedule" : modelData.type === "weather" ? "partly_cloudy_day" : modelData.type === "sysmon" ? "monitoring" : "widgets"
                                pixelSize: 18; color: Theme.textSecondary
                            }
                            Text {
                                Layout.fillWidth: true
                                text: modelData.type.charAt(0).toUpperCase() + modelData.type.slice(1)
                                    + (modelData.monitor ? ("  ·  " + modelData.monitor) : "")
                                color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeBody
                            }
                            IconButton { iconName: "delete"; onClicked: root.runW(["remove", modelData.id]) }
                        }
                    }
                }
                Text {
                    visible: root.widgetList.length === 0
                    text: "No widgets yet. Add one above."
                    color: Theme.textDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                }
            }
        }

        Item { implicitHeight: 8 }
    }
    }
}
