import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../theme"
import "../../components"
import "../../services"

// The Mujo Shelf Staging Body (無常) — Shared by both the edge slide-out drawer
// (ShelfSurface) and the floating top bar popup (ShelfButton).
//
// Features:
// - Category-aware iconography with distinct color accents & glyph tiles
// - Rich typography hierarchy (middle-elided filename + directory metadata path)
// - Floating Action Rail (Copy Path with instant checkmark feedback, Reveal in Files, Remove)
// - Tactile Drag-Out with visual lift feedback
// - Two-step animated Clear-All confirmation
// - Zen illustrated empty state with ambient breathing motion
ColumnLayout {
    id: view
    property var panelWindow
    signal minimizeRequested()

    spacing: 12
    property bool confirmingClear: false

    // Category styling helper
    function getCategoryInfo(it) {
        if (it.isDir) {
            return { icon: "folder", color: Theme.accent, label: "DIRECTORY" }
        }
        var n = it.name.toLowerCase()
        var dot = n.lastIndexOf(".")
        var ext = dot >= 0 ? n.substring(dot + 1) : ""

        if (/^(png|jpg|jpeg|gif|webp|svg|bmp|tiff|ico|avif)$/.test(ext)) {
            return { icon: "image", color: "#F59E0B", label: ext.toUpperCase() || "IMAGE" }
        }
        if (/^(mp4|mkv|webm|mov|avi|flv|wmv|m4v)$/.test(ext)) {
            return { icon: "movie", color: "#A855F7", label: ext.toUpperCase() || "VIDEO" }
        }
        if (/^(mp3|flac|wav|ogg|m4a|opus|aac)$/.test(ext)) {
            return { icon: "music_note", color: "#EC4899", label: ext.toUpperCase() || "AUDIO" }
        }
        if (ext === "pdf") {
            return { icon: "picture_as_pdf", color: "#F43F5E", label: "PDF" }
        }
        if (/^(zip|tar|gz|xz|zst|7z|rar|bz2|iso)$/.test(ext)) {
            return { icon: "folder_zip", color: "#06B6D4", label: ext.toUpperCase() || "ARCHIVE" }
        }
        if (/^(nix|qml|rs|ts|js|jsx|tsx|py|c|cpp|h|hpp|go|java|rb|lua|json|yaml|yml|toml|css|html|xml|sh)$/.test(ext)) {
            return { icon: "code", color: "#10B981", label: ext.toUpperCase() || "CODE" }
        }
        if (/^(txt|md|log|conf|ini|cfg|csv|org|rst)$/.test(ext)) {
            return { icon: "description", color: "#38BDF8", label: ext.toUpperCase() || "DOC" }
        }
        return { icon: "draft", color: Theme.textSecondary, label: ext ? ext.toUpperCase() : "FILE" }
    }

    // Path to URI helper (handles special characters and spaces cleanly)
    function pathToUri(p) {
        var parts = p.split("/")
        for (var i = 0; i < parts.length; i++) parts[i] = encodeURIComponent(parts[i])
        return "file://" + parts.join("/")
    }

    function getDirName(p) {
        if (!p) return ""
        var idx = p.lastIndexOf("/")
        if (idx <= 0) return "/"
        var parent = p.substring(0, idx)
        var home = Quickshell.env("HOME") || ""
        if (home && parent.indexOf(home) === 0) {
            return "~" + parent.substring(home.length)
        }
        return parent
    }

    DropArea {
        id: viewDrop
        Layout.fillWidth: true
        Layout.fillHeight: true
        keys: ["text/uri-list", "text/plain", "text/x-moz-url"]
        onDropped: (e) => {
            if (e.hasUrls) {
                for (var i = 0; i < e.urls.length; i++) Shelf.addUri("" + e.urls[i])
            } else {
                Shelf.addUriList(e.getDataAsString("text/uri-list") || e.getDataAsString("text/plain"))
            }
            e.accept(Qt.CopyAction)
        }
    }

    // ── 1. Header ─────────────────────────────────────────────────────────────
    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        RowLayout {
            spacing: 8
            Layout.alignment: Qt.AlignVCenter

            Rectangle {
                implicitWidth: 26
                implicitHeight: 26
                radius: Theme.radiusSm
                color: Theme.accentDim
                border.color: Theme.accent
                border.width: 1

                MaterialIcon {
                    anchors.centerIn: parent
                    iconName: "inventory_2"
                    pixelSize: 15
                    color: Theme.accent
                }
            }

            SectionLabel {
                text: "STAGING SHELF"
                accented: true
                Layout.alignment: Qt.AlignVCenter
            }
        }

        // Count chip
        Rectangle {
            visible: Shelf.count > 0
            implicitWidth: countTxt.implicitWidth + 12
            implicitHeight: 20
            radius: 10
            color: Theme.surface
            border.color: Theme.border
            border.width: 1
            Layout.alignment: Qt.AlignVCenter

            Text {
                id: countTxt
                anchors.centerIn: parent
                text: Shelf.count + (Shelf.count === 1 ? " item" : " items")
                color: Theme.textSecondary
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeLabel
                font.bold: true
            }
        }

        Item { Layout.fillWidth: true }

        // Clear All Action (Two-step animated confirmation)
        RowLayout {
            visible: Shelf.count > 0
            spacing: 4
            Layout.alignment: Qt.AlignVCenter

            Rectangle {
                visible: view.confirmingClear
                implicitHeight: 26
                implicitWidth: confTxt.implicitWidth + 12
                radius: Theme.radiusSm
                color: Theme.withAlpha(Theme.error, 0.15)
                border.color: Theme.error
                border.width: 1

                Text {
                    id: confTxt
                    anchors.centerIn: parent
                    text: "Clear all?"
                    color: Theme.error
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    font.bold: true
                }
            }

            IconButton {
                iconName: view.confirmingClear ? "check" : "delete_sweep"
                active: view.confirmingClear
                iconColor: view.confirmingClear ? Theme.error : (hovered ? Theme.text : Theme.textSecondary)
                onClicked: {
                    if (view.confirmingClear) {
                        Shelf.clear()
                        view.confirmingClear = false
                    } else {
                        view.confirmingClear = true
                    }
                }
                Tooltip {
                    panelWindow: view.panelWindow
                    target: parent
                    text: view.confirmingClear ? "Confirm Clear All" : "Clear Shelf"
                    hovered: parent.hovered && view.panelWindow !== undefined
                }
            }

            IconButton {
                visible: view.confirmingClear
                iconName: "close"
                iconColor: hovered ? Theme.text : Theme.textSecondary
                onClicked: view.confirmingClear = false
                Tooltip {
                    panelWindow: view.panelWindow
                    target: parent
                    text: "Cancel"
                    hovered: hovered && view.panelWindow !== undefined
                }
            }
        }

        IconButton {
            iconName: "minimize"
            iconColor: hovered ? Theme.text : Theme.textSecondary
            onClicked: view.minimizeRequested()
            Tooltip {
                panelWindow: view.panelWindow
                target: parent
                text: "Dock Shelf"
                hovered: hovered && view.panelWindow !== undefined
            }
        }
    }

    // ── 2. Zen Empty State ───────────────────────────────────────────────────
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 150
        visible: Shelf.count === 0
        radius: Theme.radiusMd
        color: Theme.withAlpha(Theme.surface, 0.4)
        border.color: Theme.borderStrong
        border.width: 1

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 8
            width: parent.width - 32

            Item {
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: 44
                implicitHeight: 44

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.radiusMd
                    color: Theme.accentDim
                    border.color: Theme.withAlpha(Theme.accent, 0.4)
                    border.width: 1

                    scale: view.visible && Anim.ambient ? Anim.breath(0.96, 1.04) : 1.0
                    Behavior on scale { NumberAnimation { duration: Anim.d(Anim.slow); easing.type: Anim.easeStandard } }

                    MaterialIcon {
                        anchors.centerIn: parent
                        iconName: "drive_file_move"
                        pixelSize: 22
                        color: Theme.accent
                    }
                }
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "Shelf is Empty"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeBody
                font.bold: true
            }

            Text {
                Layout.fillWidth: true
                text: "Drag files to the screen edge to stage them across apps & workspaces."
                color: Theme.textDim
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }
        }
    }

    // ── 3. Staged Items List ─────────────────────────────────────────────────
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 6
        visible: Shelf.count > 0

        Repeater {
            model: Shelf.items

            delegate: Rectangle {
                id: row
                required property var modelData
                required property int index

                readonly property var catInfo: view.getCategoryInfo(modelData)
                readonly property string uri: view.pathToUri(modelData.path)
                readonly property string iconSource: Icons.fileIcon(modelData.name, modelData.isDir === true)
                property bool copiedFeedback: false

                Layout.fillWidth: true
                implicitHeight: 48
                radius: Theme.radiusMd
                color: rowHh.hovered ? Theme.surfaceHover : Theme.surface
                border.color: modelData.missing
                              ? Theme.warning
                              : (rowHh.hovered ? Theme.borderInteractive : Theme.border)
                border.width: 1
                clip: true

                Behavior on color { ColorAnimation { duration: Anim.d(Anim.fast) } }
                Behavior on border.color { ColorAnimation { duration: Anim.d(Anim.fast) } }

                // Dragging Visual Lift
                scale: dragHandler.active ? 1.02 : 1.0
                opacity: modelData.missing ? 0.65 : (dragHandler.active ? 0.85 : 1.0)
                Behavior on scale { NumberAnimation { duration: Anim.d(Anim.fast); easing.type: Anim.easeStandard } }
                Behavior on opacity { NumberAnimation { duration: Anim.d(Anim.fast) } }

                // Specular top highlight line
                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 1
                    color: Theme.withAlpha("#ffffff", 0.04)
                }

                HoverHandler { id: rowHh; cursorShape: dragHandler.active ? Qt.CrossCursor : Qt.PointingHandCursor }

                // Nautilus-style Cursor Drag Preview Ghost
                ShelfDragPreview {
                    id: dragGhost
                    visible: false
                    name: row.modelData.name
                    path: row.modelData.path
                    isDir: row.modelData.isDir === true
                    missing: row.modelData.missing === true
                }

                function updateDragImage() {
                    dragGhost.capture(function (url) {
                        row.Drag.imageSource = url
                    })
                }

                Component.onCompleted: updateDragImage()
                onModelDataChanged: updateDragImage()

                // Drag-Out Engine
                Drag.active: dragHandler.active
                Drag.dragType: Drag.Automatic
                Drag.supportedActions: Qt.CopyAction | Qt.MoveAction
                Drag.proposedAction: Qt.CopyAction
                Drag.hotSpot.x: -14
                Drag.hotSpot.y: -14
                Drag.mimeData: ({ "text/uri-list": row.uri + "\r\n", "text/plain": modelData.path })

                DragHandler {
                    id: dragHandler
                    target: null
                    cursorShape: Qt.CrossCursor
                    enabled: !row.modelData.missing
                    onActiveChanged: {
                        if (active) {
                            if (!row.Drag.imageSource) row.updateDragImage()
                            row.Drag.startDrag()
                        } else {
                            Shelf.reconcileAfterDrag(row.modelData.path)
                        }
                    }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 10

                    // Full-colour MIME Icon (or category fallback)
                    Item {
                        implicitWidth: 32
                        implicitHeight: 32
                        Layout.alignment: Qt.AlignVCenter

                        Image {
                            anchors.centerIn: parent
                            width: 28
                            height: 28
                            visible: row.iconSource !== "" && !row.modelData.missing
                            source: row.iconSource
                            fillMode: Image.PreserveAspectFit
                            sourceSize.width: 28
                            sourceSize.height: 28
                            smooth: true
                            mipmap: true
                        }

                        Rectangle {
                            anchors.fill: parent
                            visible: row.iconSource === "" || row.modelData.missing
                            radius: Theme.radiusSm
                            color: Theme.withAlpha(row.catInfo.color, 0.14)
                            border.color: Theme.withAlpha(row.catInfo.color, 0.35)
                            border.width: 1

                            MaterialIcon {
                                anchors.centerIn: parent
                                iconName: row.modelData.missing ? "warning" : row.catInfo.icon
                                pixelSize: 16
                                color: row.modelData.missing ? Theme.warning : row.catInfo.color
                            }
                        }
                    }

                    // Metadata Titles
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Layout.alignment: Qt.AlignVCenter

                        TapHandler {
                            onDoubleTapped: Shelf.open(row.modelData.path)
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            Text {
                                Layout.fillWidth: true
                                text: row.modelData.name
                                color: row.modelData.missing ? Theme.textSecondary : Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeBody
                                font.bold: true
                                elide: Text.ElideMiddle
                            }

                            // Category / Extension Chip
                            Rectangle {
                                implicitWidth: tagTxt.implicitWidth + 8
                                implicitHeight: 14
                                radius: 3
                                color: Theme.withAlpha(row.catInfo.color, 0.12)
                                visible: !row.modelData.missing

                                Text {
                                    id: tagTxt
                                    anchors.centerIn: parent
                                    text: row.catInfo.label
                                    color: row.catInfo.color
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.fontSizeLabel - 2
                                    font.bold: true
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            Text {
                                Layout.fillWidth: true
                                text: row.modelData.missing ? "File moved or deleted" : view.getDirName(row.modelData.path)
                                color: row.modelData.missing ? Theme.warning : Theme.textDim
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fontSizeLabel
                                elide: Text.ElideMiddle
                            }
                        }
                    }

                    // Floating Action Rail (smooth reveal on hover)
                    RowLayout {
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 4
                        opacity: rowHh.hovered ? 1.0 : 0.0
                        visible: opacity > 0.01
                        Behavior on opacity { NumberAnimation { duration: Anim.d(Anim.fast) } }

                        IconButton {
                            iconName: row.copiedFeedback ? "check" : "content_copy"
                            iconColor: row.copiedFeedback ? Theme.success : (hovered ? Theme.text : Theme.textSecondary)
                            onClicked: {
                                Shelf.copyPath(row.modelData.path)
                                row.copiedFeedback = true
                                copyResetTimer.restart()
                            }
                            Tooltip {
                                panelWindow: view.panelWindow
                                target: parent
                                text: row.copiedFeedback ? "Path Copied!" : "Copy Path"
                                hovered: parent.hovered && view.panelWindow !== undefined
                            }
                            Timer {
                                id: copyResetTimer
                                interval: 1400
                                onTriggered: row.copiedFeedback = false
                            }
                        }

                        IconButton {
                            iconName: "folder_open"
                            iconColor: hovered ? Theme.text : Theme.textSecondary
                            onClicked: Shelf.reveal(row.modelData.path)
                            Tooltip {
                                panelWindow: view.panelWindow
                                target: parent
                                text: "Reveal in File Manager"
                                hovered: hovered && view.panelWindow !== undefined
                            }
                        }

                        IconButton {
                            iconName: "close"
                            iconColor: hovered ? Theme.error : Theme.textSecondary
                            onClicked: Shelf.remove(row.modelData.path)
                            Tooltip {
                                panelWindow: view.panelWindow
                                target: parent
                                text: "Remove from Shelf"
                                hovered: hovered && view.panelWindow !== undefined
                            }
                        }
                    }
                }

                // Full Path Hover Tooltip
                Tooltip {
                    panelWindow: view.panelWindow
                    target: row
                    text: row.modelData.path
                    hovered: rowHh.hovered && !row.copiedFeedback && view.panelWindow !== undefined
                }
            }
        }
    }
}
