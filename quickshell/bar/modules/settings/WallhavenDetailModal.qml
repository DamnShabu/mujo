import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../theme"
import "../../components"
import "../../services"

// Wallhaven Wallpaper Detail & Inspector Modal for Mujo (無常).
// Provides full metadata inspection, media preview, interactive tags,
// color palette swatches, specifications, and one-click live wallpaper application.
Rectangle {
    id: root

    property var wallpaperItem: null
    property var details: null
    readonly property bool isOpen: wallpaperItem !== null

    readonly property var dlInfo: root.wallpaperItem ? WallpaperDownloads.getDownload(root.wallpaperItem.path || "") : null
    readonly property bool isDownloading: dlInfo !== null && dlInfo.status === "downloading"
    readonly property bool isCompleted: root.wallpaperItem ? WallpaperDownloads.isCompleted(root.wallpaperItem.path || "") : false

    signal tagClicked(string tag)
    signal colorClicked(string color)
    signal categoryClicked(string category)
    signal resolutionClicked(string resolution)
    signal closed()

    function show(item) {
        root.wallpaperItem = item
        root.details = null
        if (item && item.id) {
            Wallhaven.fetchDetails(item.id, function(data) {
                if (root.wallpaperItem && root.wallpaperItem.id === item.id) {
                    root.details = data
                }
            })
        }
    }

    function close() {
        root.wallpaperItem = null
        root.details = null
        root.closed()
    }

    visible: opacity > 0
    opacity: root.isOpen ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: Anim.d(Anim.fast); easing.type: Anim.easeStandard } }

    anchors.fill: parent
    color: "#d9000000"
    z: 100

    // Intercept clicks on background scrim to dismiss
    MouseArea {
        anchors.fill: parent
        onClicked: root.close()
    }

    // Modal Card
    Rectangle {
        id: modalBox
        width: Math.min(parent.width - 48, 960)
        height: Math.min(parent.height - 48, 680)
        anchors.centerIn: parent
        radius: Theme.radiusLg
        color: Theme.surface
        border.color: Theme.borderStrong
        border.width: 1
        clip: true

        scale: root.isOpen ? 1.0 : 0.95
        Behavior on scale { NumberAnimation { duration: Anim.d(Anim.standard); easing.type: Anim.easeStandard } }

        TapHandler {
            // Absorb taps inside modal
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 16

            // ── Header ──────────────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                BrandIcon {
                    brand: "wallhaven"
                    size: 26
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Text {
                        text: root.wallpaperItem ? ("Wallhaven #" + root.wallpaperItem.id) : "Wallpaper Details"
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeTitle
                        font.bold: true
                    }
                    Text {
                        text: {
                            if (!root.wallpaperItem) return ""
                            var cat = (root.wallpaperItem.category || "General").toUpperCase()
                            var purity = (root.wallpaperItem.purity || "SFW").toUpperCase()
                            var res = root.wallpaperItem.resolution || (root.wallpaperItem.dimension_x + "×" + root.wallpaperItem.dimension_y)
                            return cat + " · " + purity + " · " + res
                        }
                        color: Theme.textSecondary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                    }
                }

                // Top Actions
                IconButton {
                    iconName: "open_in_new"
                    visible: root.wallpaperItem && root.wallpaperItem.url
                    onClicked: {
                        if (root.wallpaperItem && root.wallpaperItem.url) {
                            Quickshell.execDetached(["xdg-open", root.wallpaperItem.url])
                        }
                    }
                }

                IconButton {
                    iconName: "content_copy"
                    onClicked: {
                        if (root.wallpaperItem && root.wallpaperItem.path) {
                            Quickshell.execDetached(["wl-copy", root.wallpaperItem.path])
                            Notifications.notify("Link Copied", "Direct wallpaper image URL copied to clipboard.", "link", "low", { appName: "Wallhaven", transient: true })
                        }
                    }
                }

                IconButton {
                    iconName: "close"
                    onClicked: root.close()
                }
            }

            // ── Main Content: Media Preview & Metadata ──────────────────────
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 18

                // Media Preview Frame
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredWidth: 3
                    radius: Theme.radiusMd
                    color: "#05070a"
                    border.color: Theme.border
                    clip: true

                    Image {
                        id: previewImg
                        anchors.fill: parent
                        anchors.margins: 4
                        source: {
                            if (!root.wallpaperItem) return ""
                            if (root.details && root.details.path) return root.details.path
                            if (root.wallpaperItem.path) return root.wallpaperItem.path
                            if (root.wallpaperItem.thumbs && root.wallpaperItem.thumbs.large) return root.wallpaperItem.thumbs.large
                            return ""
                        }
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        cache: true
                        smooth: true

                        Spinner {
                            anchors.centerIn: parent
                            visible: previewImg.status === Image.Loading
                        }
                    }

                    // Resolution pill at bottom-left
                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.margins: 12
                        radius: Theme.radiusSm
                        implicitHeight: 24
                        implicitWidth: resPillRow.implicitWidth + 14
                        color: "#cc000000"
                        border.color: Theme.border

                        RowLayout {
                            id: resPillRow
                            anchors.centerIn: parent
                            spacing: 4
                            MaterialIcon {
                                iconName: "aspect_ratio"
                                pixelSize: 13
                                color: Theme.accent
                            }
                            Text {
                                text: root.wallpaperItem ? (root.wallpaperItem.resolution || (root.wallpaperItem.dimension_x + "×" + root.wallpaperItem.dimension_y)) : ""
                                color: "#ffffff"
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fontSizeLabel
                                font.bold: true
                            }
                        }
                    }

                    // Purity Badge at top-left
                    Rectangle {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.margins: 12
                        radius: Theme.radiusSm
                        implicitHeight: 22
                        implicitWidth: purBadgeRow.implicitWidth + 12
                        color: "#cc000000"

                        RowLayout {
                            id: purBadgeRow
                            anchors.centerIn: parent
                            spacing: 4
                            Rectangle {
                                width: 6; height: 6; radius: 3
                                color: {
                                    var p = (root.wallpaperItem ? root.wallpaperItem.purity : "sfw").toLowerCase()
                                    if (p === "sfw") return Theme.success
                                    if (p === "sketchy") return Theme.warning
                                    return Theme.error
                                }
                            }
                            Text {
                                text: (root.wallpaperItem ? root.wallpaperItem.purity : "SFW").toUpperCase()
                                color: "#ffffff"
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeLabel
                                font.bold: true
                            }
                        }
                    }
                }

                // Metadata Sidebar
                Flickable {
                    Layout.fillHeight: true
                    Layout.preferredWidth: 320
                    Layout.minimumWidth: 290
                    contentHeight: sidebarCol.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    ColumnLayout {
                        id: sidebarCol
                        width: parent.width
                        spacing: 14

                        // Specifications Box
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: specGrid.implicitHeight + 20
                            radius: Theme.radiusMd
                            color: Theme.surfaceActive
                            border.color: Theme.border

                            GridLayout {
                                id: specGrid
                                anchors.fill: parent
                                anchors.margins: 10
                                columns: 2
                                columnSpacing: 10
                                rowSpacing: 8

                                Text { text: "Resolution"; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSmall }
                                Text {
                                    text: root.wallpaperItem ? (root.wallpaperItem.resolution || (root.wallpaperItem.dimension_x + "×" + root.wallpaperItem.dimension_y)) : "—"
                                    color: Theme.text
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.bold: true
                                    Layout.alignment: Qt.AlignRight
                                }

                                Text { text: "Aspect Ratio"; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSmall }
                                Text {
                                    text: root.wallpaperItem ? (root.wallpaperItem.ratio || "—") : "—"
                                    color: Theme.text
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.fontSizeSmall
                                    Layout.alignment: Qt.AlignRight
                                }

                                Text { text: "File Size"; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSmall }
                                Text {
                                    text: {
                                        if (!root.wallpaperItem) return "—"
                                        var bytes = root.details && root.details.file_size ? root.details.file_size : root.wallpaperItem.file_size
                                        if (!bytes) return "—"
                                        return (bytes / (1024 * 1024)).toFixed(2) + " MB"
                                    }
                                    color: Theme.text
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.fontSizeSmall
                                    Layout.alignment: Qt.AlignRight
                                }

                                Text { text: "Views / Favs"; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSmall }
                                Text {
                                    text: root.wallpaperItem ? ((root.wallpaperItem.views || 0).toLocaleString() + " / " + (root.wallpaperItem.favorites || 0).toLocaleString()) : "—"
                                    color: Theme.text
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.fontSizeSmall
                                    Layout.alignment: Qt.AlignRight
                                }

                                Text { text: "Category"; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSmall }
                                Text {
                                    text: root.wallpaperItem ? (root.wallpaperItem.category || "General") : "—"
                                    color: Theme.accent
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.bold: true
                                    Layout.alignment: Qt.AlignRight
                                }
                            }
                        }

                        // Color Palette Swatches
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            visible: root.wallpaperItem && root.wallpaperItem.colors && root.wallpaperItem.colors.length > 0

                            Text {
                                text: "Color Palette"
                                color: Theme.textSecondary
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSmall
                                font.bold: true
                            }

                            RowLayout {
                                spacing: 6
                                Repeater {
                                    model: root.wallpaperItem ? (root.wallpaperItem.colors || []) : []
                                    delegate: Rectangle {
                                        id: palSwatch
                                        required property var modelData
                                        width: 28; height: 28
                                        radius: Theme.radiusSm
                                        color: palSwatch.modelData
                                        border.color: Theme.borderStrong
                                        border.width: 1

                                        HoverHandler { id: palHh; cursorShape: Qt.PointingHandCursor }
                                        TapHandler {
                                            onTapped: {
                                                root.colorClicked(palSwatch.modelData)
                                                root.close()
                                            }
                                        }

                                        scale: palHh.hovered ? 1.15 : 1.0
                                        Behavior on scale { NumberAnimation { duration: Anim.d(Anim.fast) } }
                                    }
                                }
                            }
                        }

                        // Tags Section
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    text: "Tags"
                                    color: Theme.textSecondary
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.bold: true
                                }
                                Item { Layout.fillWidth: true }
                                Spinner {
                                    visible: root.details === null
                                    implicitWidth: 14; implicitHeight: 14
                                }
                            }

                            Flow {
                                Layout.fillWidth: true
                                spacing: 5

                                Repeater {
                                    model: (root.details && root.details.tags) ? root.details.tags : []
                                    delegate: Rectangle {
                                        id: tagPill
                                        required property var modelData
                                        implicitWidth: tagRow.implicitWidth + 14
                                        implicitHeight: 24
                                        radius: Theme.radiusSm
                                        color: th_tag.hovered ? Theme.accentDim : Theme.surfaceActive
                                        border.color: th_tag.hovered ? Theme.accent : Theme.border
                                        border.width: th_tag.hovered ? 1.5 : 1

                                        RowLayout {
                                            id: tagRow
                                            anchors.centerIn: parent
                                            spacing: 4
                                            MaterialIcon {
                                                iconName: "tag"
                                                pixelSize: 11
                                                color: th_tag.hovered ? Theme.accent : Theme.textSecondary
                                            }
                                            Text {
                                                text: tagPill.modelData.name
                                                color: th_tag.hovered ? Theme.accent : Theme.text
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.fontSizeLabel
                                                font.bold: th_tag.hovered
                                            }
                                        }

                                        HoverHandler { id: th_tag; cursorShape: Qt.PointingHandCursor }
                                        TapHandler {
                                            onTapped: {
                                                root.tagClicked(tagPill.modelData.name)
                                                root.close()
                                            }
                                        }
                                    }
                                }

                                Text {
                                    visible: root.details !== null && (!root.details.tags || root.details.tags.length === 0)
                                    text: "No tags available"
                                    color: Theme.textDim
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeSmall
                                }
                            }
                        }

                        Item { Layout.fillHeight: true }
                    }
                }
            }

            // ── Action Footer ───────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Item { Layout.fillWidth: true }

                // Live Download Progress Bar (visible during active download)
                Rectangle {
                    visible: root.isDownloading
                    implicitHeight: 36
                    implicitWidth: 260
                    radius: Theme.radiusMd
                    color: Theme.surfaceActive
                    border.color: Theme.accent
                    clip: true

                    // Animated Progress Fill Bar
                    Rectangle {
                        anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                        width: parent.width * (root.dlInfo ? (root.dlInfo.progress / 100.0) : 0)
                        color: Theme.accentDim
                        radius: Theme.radiusMd
                        Behavior on width { NumberAnimation { duration: Anim.d(Anim.fast) } }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 8
                        spacing: 8

                        Spinner { implicitWidth: 14; implicitHeight: 14 }

                        Text {
                            text: (root.dlInfo ? Math.round(root.dlInfo.progress) + "%" : "0%")
                            color: Theme.accent
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSizeSmall
                            font.bold: true
                        }

                        Text {
                            text: root.dlInfo ? (root.dlInfo.speed + (root.dlInfo.eta ? (" · " + root.dlInfo.eta) : "")) : "Downloading…"
                            color: Theme.textSecondary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeLabel
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }

                        IconButton {
                            iconName: "close"
                            implicitWidth: 22; implicitHeight: 22
                            onClicked: {
                                if (root.wallpaperItem && root.wallpaperItem.path) {
                                    WallpaperDownloads.cancelDownload(root.wallpaperItem.path)
                                }
                            }
                        }
                    }
                }

                // Save to Library Button (when not actively downloading)
                DialogButton {
                    visible: !root.isDownloading
                    text: root.isCompleted ? "Saved to Library ✓" : "Save to Library"
                    iconName: root.isCompleted ? "check_circle" : "download"
                    onClicked: {
                        if (root.wallpaperItem && root.wallpaperItem.path) {
                            Wallhaven.saveWallpaper(root.wallpaperItem.path, "Wallhaven #" + root.wallpaperItem.id)
                        }
                    }
                }

                // Set as Wallpaper Button
                DialogButton {
                    text: Wallhaven.applyingUrl === (root.wallpaperItem ? root.wallpaperItem.path : "") ? "Applying…" : "Set as Wallpaper"
                    iconName: "wallpaper"
                    primary: true
                    onClicked: {
                        if (root.wallpaperItem && root.wallpaperItem.path) {
                            Wallhaven.applyWallpaper(root.wallpaperItem.path, function(ok, path) {
                                if (ok) Notifications.notify("Wallpaper Applied", "New wallpaper active across all monitors.", "wallpaper", "normal", { appName: "Wallhaven" })
                            })
                        }
                    }
                }
            }
        }
    }

    Keys.onEscapePressed: root.close()
}
