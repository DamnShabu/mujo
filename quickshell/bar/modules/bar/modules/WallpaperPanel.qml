import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

// Wallpaper manager: a local library (files under ~/Pictures[/Wallpapers]) and a
// Wallhaven browser (search → apply / save). All actions go through
// `mujo wallpaper …`, which owns wallpaper.json; the live Wallpaper surface
// picks the change up on its next poll. The current wallpaper is highlighted.
Item {
    id: root

    property string tab: "library"          // "library" | "wallhaven"
    property var localList: []
    property var whResults: []
    property string whQuery: ""
    property bool whLoading: false
    property string whError: ""
    property string currentImage: ""

    function runWp(args) { Quickshell.execDetached(["mujo", "wallpaper"].concat(args)) }

    // ── Current wallpaper (for the "applied" highlight) ──────────────────────
    FileView {
        id: wpConf
        path: (Quickshell.env("HOME") || "/tmp") + "/.config/quickshell/wallpaper.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                var c = JSON.parse(text())
                root.currentImage = (c["default"] || {}).image || ""
            } catch (e) { /* ignore */ }
        }
    }

    // ── Local library listing ────────────────────────────────────────────────
    Process {
        id: listProc
        command: ["mujo", "wallpaper", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.localList = JSON.parse(this.text) }
                catch (e) { root.localList = [] }
            }
        }
    }
    function refreshLocal() { listProc.running = true }
    Component.onCompleted: refreshLocal()

    // ── Wallhaven search ─────────────────────────────────────────────────────
    Process {
        id: searchProc
        stdout: StdioCollector {
            onStreamFinished: {
                root.whLoading = false
                try {
                    var r = JSON.parse(this.text)
                    root.whResults = r.data || []
                    root.whError = (root.whResults.length === 0) ? "No results." : ""
                } catch (e) {
                    root.whResults = []
                    root.whError = "Search failed — check your connection."
                }
            }
        }
    }
    function search() {
        var q = root.whQuery.trim()
        if (q === "") return
        root.whLoading = true
        root.whError = ""
        searchProc.command = ["mujo", "wallpaper", "search", q, "1"]
        searchProc.running = true
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 26
        spacing: 18

        // ── Header + tabs ─────────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            ColumnLayout {
                spacing: 3
                Text {
                    text: "Wallpaper"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeTitle + 7
                    font.bold: true
                }
                Text {
                    text: "Apply from your library or browse Wallhaven."
                    color: Theme.textSecondary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeBody
                }
            }
            Item { Layout.fillWidth: true }

            // segmented tab control
            Rectangle {
                radius: Theme.radiusMd
                color: Theme.surface
                border.color: Theme.border
                implicitWidth: tabRow.implicitWidth + 8
                implicitHeight: 34
                Row {
                    id: tabRow
                    anchors.centerIn: parent
                    spacing: 4
                    Repeater {
                        model: [{ id: "library", label: "Library" }, { id: "wallhaven", label: "Wallhaven" }]
                        delegate: Rectangle {
                            required property var modelData
                            readonly property bool on: root.tab === modelData.id
                            width: tabLabel.implicitWidth + 24
                            height: 26
                            radius: Theme.radiusSm
                            color: on ? Theme.accent : "transparent"
                            Text {
                                id: tabLabel
                                anchors.centerIn: parent
                                text: parent.modelData.label
                                color: parent.on ? Theme.accentText : Theme.textSecondary
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSmall
                                font.bold: parent.on
                            }
                            HoverHandler { cursorShape: Qt.PointingHandCursor }
                            TapHandler { onTapped: root.tab = parent.modelData.id }
                        }
                    }
                }
            }
        }

        // ── Wallhaven search bar (only on that tab) ───────────────────────────
        Rectangle {
            Layout.fillWidth: true
            visible: root.tab === "wallhaven"
            implicitHeight: 38
            radius: Theme.radiusMd
            color: Theme.surface
            border.color: searchInput.activeFocus ? Theme.accent : Theme.border
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 6
                spacing: 8
                MaterialIcon { iconName: "search"; pixelSize: 18; color: Theme.textSecondary }
                TextInput {
                    id: searchInput
                    Layout.fillWidth: true
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeBody
                    verticalAlignment: TextInput.AlignVCenter
                    clip: true
                    onTextChanged: root.whQuery = text
                    Keys.onReturnPressed: root.search()
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: searchInput.text === ""
                        text: "Search wallpapers…"
                        color: Theme.textDim
                        font: searchInput.font
                    }
                }
                DialogButton {
                    text: "Search"
                    primary: true
                    onClicked: root.search()
                }
            }
        }

        // ── Content grid ──────────────────────────────────────────────────────
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            // Library
            GridView {
                id: libGrid
                anchors.fill: parent
                visible: root.tab === "library"
                clip: true
                cellWidth: (width - (width % 168)) / Math.max(1, Math.floor(width / 168))
                cellHeight: cellWidth * 0.62 + 6
                model: root.localList
                delegate: Item {
                    required property var modelData
                    width: libGrid.cellWidth
                    height: libGrid.cellHeight
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 5
                        radius: Theme.radiusMd
                        color: Theme.surface
                        clip: true
                        border.width: modelData === root.currentImage ? 2 : 1
                        border.color: modelData === root.currentImage ? Theme.accent : Theme.border
                        Image {
                            anchors.fill: parent
                            anchors.margins: 3
                            source: "file://" + modelData
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: true
                            sourceSize.width: 320
                            clip: true
                        }
                        Rectangle {
                            visible: modelData === root.currentImage
                            anchors { top: parent.top; right: parent.right; margins: 6 }
                            width: 22; height: 22; radius: 11
                            color: Theme.accent
                            MaterialIcon { anchors.centerIn: parent; iconName: "check"; pixelSize: 14; color: Theme.accentText }
                        }
                        Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            color: Theme.accent
                            opacity: lib_hh.hovered && modelData !== root.currentImage ? 0.12 : 0
                            Behavior on opacity { NumberAnimation { duration: Theme.durationFast } }
                        }
                        HoverHandler { id: lib_hh; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: root.runWp(["set", modelData]) }
                    }
                }

                // empty state
                Text {
                    anchors.centerIn: parent
                    visible: root.localList.length === 0
                    horizontalAlignment: Text.AlignHCenter
                    text: "No wallpapers yet.\nDownload some from Wallhaven, or drop images\ninto ~/Pictures/Wallpapers."
                    color: Theme.textDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeBody
                }
            }

            // Wallhaven
            GridView {
                id: whGrid
                anchors.fill: parent
                visible: root.tab === "wallhaven"
                clip: true
                cellWidth: (width - (width % 168)) / Math.max(1, Math.floor(width / 168))
                cellHeight: cellWidth * 0.62 + 6
                model: root.whResults
                delegate: Item {
                    required property var modelData
                    width: whGrid.cellWidth
                    height: whGrid.cellHeight
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 5
                        radius: Theme.radiusMd
                        color: Theme.surface
                        clip: true
                        border.color: Theme.border
                        Image {
                            anchors.fill: parent
                            anchors.margins: 3
                            source: (modelData.thumbs && modelData.thumbs.small) ? modelData.thumbs.small : ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: true
                            clip: true
                        }
                        // resolution chip
                        Rectangle {
                            anchors { bottom: parent.bottom; left: parent.left; margins: 7 }
                            visible: !wh_hh.hovered && modelData.dimension_x !== undefined
                            radius: Theme.radiusSm
                            color: "#cc000000"
                            implicitWidth: dimLabel.implicitWidth + 12
                            implicitHeight: 18
                            Text {
                                id: dimLabel
                                anchors.centerIn: parent
                                text: modelData.dimension_x + "×" + modelData.dimension_y
                                color: "#ffffff"
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fontSizeLabel
                            }
                        }
                        // hover action overlay
                        Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            color: "#b3000000"
                            opacity: wh_hh.hovered ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: Theme.durationFast } }
                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 8
                                DialogButton {
                                    text: "Apply"
                                    primary: true
                                    onClicked: root.runWp(["apply-url", modelData.path])
                                }
                                DialogButton {
                                    text: "Save"
                                    onClicked: root.runWp(["save", modelData.path])
                                }
                            }
                        }
                        HoverHandler { id: wh_hh; cursorShape: Qt.PointingHandCursor }
                    }
                }
            }

            // Wallhaven states
            Spinner {
                anchors.centerIn: parent
                visible: root.tab === "wallhaven" && root.whLoading
            }
            Text {
                anchors.centerIn: parent
                visible: root.tab === "wallhaven" && !root.whLoading && root.whResults.length === 0
                horizontalAlignment: Text.AlignHCenter
                text: root.whError !== "" ? root.whError
                      : "Search Wallhaven for wallpapers.\nTry “nature”, “minimal”, “city”…"
                color: Theme.textDim
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeBody
            }
        }
    }
}
