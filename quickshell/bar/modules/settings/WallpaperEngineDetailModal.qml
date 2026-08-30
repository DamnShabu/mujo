import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../theme"
import "../../components"
import "../../services"

// Wallpaper Engine & Steam Workshop Detail & Inspector Modal for Mujo (無常).
// Provides full metadata inspection, media preview, interactive genre tags,
// content purity ratings (SFW, Sketchy, NSFW), author profiles, rating & subscription metrics,
// and one-click Steam Workshop subscription, direct download progress, and live wallpaper application.
Rectangle {
    id: root

    property var wallpaperItem: null
    property var details: null
    readonly property bool isOpen: wallpaperItem !== null

    readonly property string previewTargetUrl: (root.details && root.details.preview) ? root.details.preview : (root.wallpaperItem ? (root.wallpaperItem.preview || "") : "")
    readonly property var dlInfo: previewTargetUrl ? WallpaperDownloads.getDownload(previewTargetUrl) : null
    readonly property bool isDownloading: dlInfo !== null && dlInfo.status === "downloading"
    readonly property bool isCompleted: previewTargetUrl ? WallpaperDownloads.isCompleted(previewTargetUrl) : false

    signal tagClicked(string tag)
    signal typeClicked(string type)
    signal closed()

    function show(item) {
        root.wallpaperItem = item
        root.details = null
        if (item) {
            var target = item.path || item.id || ""
            if (target) {
                WallpaperEngine.fetchDetails(target, function(data) {
                    if (root.wallpaperItem && (root.wallpaperItem.id === item.id || root.wallpaperItem.path === item.path)) {
                        root.details = data
                    }
                })
            }
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
                    brand: "steam"
                    size: 28
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Text {
                        text: root.wallpaperItem ? (root.wallpaperItem.title || ("Workshop #" + root.wallpaperItem.id)) : "Wallpaper Details"
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeTitle
                        font.bold: true
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                    Text {
                        text: {
                            if (!root.wallpaperItem) return ""
                            var author = root.details && root.details.author ? root.details.author : (root.wallpaperItem.author || "Steam Community")
                            var type = (root.details && root.details.type ? root.details.type : (root.wallpaperItem.type || "scene")).toUpperCase()
                            var isLoc = root.wallpaperItem.is_local ? " · INSTALLED" : " · STEAM WORKSHOP"
                            return type + isLoc + " · by " + author
                        }
                        color: Theme.textSecondary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }

                // Top Actions
                IconButton {
                    iconName: "sports_esports"
                    visible: root.wallpaperItem && root.wallpaperItem.id && !root.wallpaperItem.is_local
                    onClicked: {
                        if (root.wallpaperItem && root.wallpaperItem.id) {
                            WallpaperEngine.openInSteam(root.wallpaperItem.id)
                        }
                    }
                }

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
                        var targetLink = root.wallpaperItem ? (root.wallpaperItem.url || ("https://steamcommunity.com/sharedfiles/filedetails/?id=" + root.wallpaperItem.id)) : ""
                        if (targetLink) {
                            Quickshell.execDetached(["wl-copy", targetLink])
                            Notifications.notify("Link Copied", "Workshop link copied to clipboard.", "link", "low", { appName: "Wallpaper Engine", transient: true })
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
                            var p = root.details && root.details.cached_preview ? root.details.cached_preview : (root.details && root.details.preview ? root.details.preview : (root.wallpaperItem.cached_preview || root.wallpaperItem.preview || ""))
                            if (p.startsWith("/")) return "file://" + p
                            return p
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

                    // Overlay Badges at bottom-left
                    RowLayout {
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.margins: 12
                        spacing: 8

                        // Type Pill
                        Rectangle {
                            radius: Theme.radiusSm
                            implicitHeight: 24
                            implicitWidth: typeBadgeTxt.implicitWidth + 16
                            color: Theme.accent
                            Text {
                                id: typeBadgeTxt
                                anchors.centerIn: parent
                                text: {
                                    if (!root.wallpaperItem) return "SCENE"
                                    var t = (root.details && root.details.type ? root.details.type : (root.wallpaperItem.type || "scene")).toUpperCase()
                                    return t
                                }
                                color: Theme.accentText
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeLabel
                                font.bold: true
                            }
                        }

                        // Purity Badge (SFW / Sketchy / NSFW)
                        Rectangle {
                            radius: Theme.radiusSm
                            implicitHeight: 24
                            implicitWidth: purityBadgeRow.implicitWidth + 14
                            color: "#cc000000"
                            border.color: {
                                var pur = root.details && root.details.purity ? root.details.purity : (root.wallpaperItem ? root.wallpaperItem.purity : "sfw")
                                if (pur === "sfw") return Theme.success
                                if (pur === "sketchy") return Theme.warning
                                return Theme.error
                            }

                            RowLayout {
                                id: purityBadgeRow
                                anchors.centerIn: parent
                                spacing: 4

                                Rectangle {
                                    width: 7; height: 7; radius: 3.5
                                    color: {
                                        var pur = root.details && root.details.purity ? root.details.purity : (root.wallpaperItem ? root.wallpaperItem.purity : "sfw")
                                        if (pur === "sfw") return Theme.success
                                        if (pur === "sketchy") return Theme.warning
                                        return Theme.error
                                    }
                                }

                                Text {
                                    text: {
                                        var pur = root.details && root.details.purity ? root.details.purity : (root.wallpaperItem ? root.wallpaperItem.purity : "sfw")
                                        if (pur === "sfw") return "SFW"
                                        if (pur === "sketchy") return "SKETCHY"
                                        return "NSFW (18+)"
                                    }
                                    color: "#ffffff"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeLabel
                                    font.bold: true
                                }
                            }
                        }

                        // Rating Badge (if online)
                        Rectangle {
                            visible: root.wallpaperItem && root.wallpaperItem.rating > 0
                            radius: Theme.radiusSm
                            implicitHeight: 24
                            implicitWidth: ratingRow.implicitWidth + 14
                            color: "#cc000000"
                            border.color: Theme.border

                            RowLayout {
                                id: ratingRow
                                anchors.centerIn: parent
                                spacing: 3
                                MaterialIcon {
                                    iconName: "star"
                                    pixelSize: 13
                                    color: "#ffca28"
                                }
                                Text {
                                    text: root.wallpaperItem ? (root.wallpaperItem.rating + " / 5") : ""
                                    color: "#ffffff"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeLabel
                                    font.bold: true
                                }
                            }
                        }

                        // Installed / Local Badge
                        Rectangle {
                            visible: root.wallpaperItem && root.wallpaperItem.is_local
                            radius: Theme.radiusSm
                            implicitHeight: 24
                            implicitWidth: locBadgeTxt.implicitWidth + 14
                            color: Theme.withAlpha(Theme.success, 0.2)
                            border.color: Theme.success
                            border.width: 1

                            RowLayout {
                                id: locBadgeTxt
                                anchors.centerIn: parent
                                spacing: 4
                                MaterialIcon {
                                    iconName: "check_circle"
                                    pixelSize: 12
                                    color: Theme.success
                                }
                                Text {
                                    text: "INSTALLED"
                                    color: Theme.success
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeLabel
                                    font.bold: true
                                }
                            }
                        }
                    }
                }

                // Metadata Sidebar
                MujoFlickable {
                    Layout.fillHeight: true
                    Layout.preferredWidth: 320
                    Layout.minimumWidth: 290
                    contentHeight: sidebarCol.implicitHeight

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

                                Text { text: "Type"; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSmall }
                                Text {
                                    text: {
                                        if (!root.wallpaperItem) return "—"
                                        return (root.details && root.details.type ? root.details.type : (root.wallpaperItem.type || "scene")).toUpperCase()
                                    }
                                    color: Theme.accent
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.bold: true
                                    Layout.alignment: Qt.AlignRight
                                }

                                Text { text: "Content Rating"; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSmall }
                                Text {
                                    text: {
                                        var ar = root.details && root.details.age_rating ? root.details.age_rating : (root.wallpaperItem && root.wallpaperItem.age_rating ? root.wallpaperItem.age_rating : "Everyone")
                                        return ar
                                    }
                                    color: {
                                        var pur = root.details && root.details.purity ? root.details.purity : (root.wallpaperItem ? root.wallpaperItem.purity : "sfw")
                                        if (pur === "sfw") return Theme.success
                                        if (pur === "sketchy") return Theme.warning
                                        return Theme.error
                                    }
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.bold: true
                                    Layout.alignment: Qt.AlignRight
                                }

                                Text { text: "Workshop ID"; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSmall }
                                Text {
                                    text: root.wallpaperItem ? (root.wallpaperItem.id || "—") : "—"
                                    color: Theme.text
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.fontSizeSmall
                                    Layout.alignment: Qt.AlignRight
                                }

                                Text { text: "Subscriptions"; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSmall; visible: root.details && root.details.subscriptions !== undefined }
                                Text {
                                    text: root.details && root.details.subscriptions !== undefined ? (root.details.subscriptions).toLocaleString() : "—"
                                    color: Theme.text
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.fontSizeSmall
                                    Layout.alignment: Qt.AlignRight
                                    visible: root.details && root.details.subscriptions !== undefined
                                }

                                Text { text: "File Size"; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSmall; visible: root.details && root.details.file_size }
                                Text {
                                    text: root.details && root.details.file_size ? root.details.file_size : "—"
                                    color: Theme.text
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.fontSizeSmall
                                    Layout.alignment: Qt.AlignRight
                                    visible: root.details && root.details.file_size
                                }

                                Text { text: "Posted"; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSmall; visible: root.details && root.details.posted }
                                Text {
                                    text: root.details && root.details.posted ? root.details.posted : "—"
                                    color: Theme.text
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeSmall
                                    Layout.alignment: Qt.AlignRight
                                    visible: root.details && root.details.posted
                                }

                                Text { text: "Updated"; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSmall; visible: root.details && root.details.updated }
                                Text {
                                    text: root.details && root.details.updated ? root.details.updated : "—"
                                    color: Theme.text
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeSmall
                                    Layout.alignment: Qt.AlignRight
                                    visible: root.details && root.details.updated
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
                                    text: "Tags & Genres"
                                    color: Theme.textSecondary
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.bold: true
                                }
                                Item { Layout.fillWidth: true }
                                Spinner {
                                    visible: root.details === null && !root.wallpaperItem.is_local
                                    implicitWidth: 14; implicitHeight: 14
                                }
                            }

                            Flow {
                                Layout.fillWidth: true
                                spacing: 5

                                readonly property var activeTagsList: {
                                    if (root.details && root.details.tags && root.details.tags.length > 0) return root.details.tags
                                    if (root.wallpaperItem && root.wallpaperItem.tags) {
                                        var raw = root.wallpaperItem.tags
                                        var list = []
                                        for (var i = 0; i < raw.length; i++) {
                                            list.push({ name: typeof raw[i] === "string" ? raw[i] : raw[i].name })
                                        }
                                        return list
                                    }
                                    return []
                                }

                                Repeater {
                                    model: parent.activeTagsList
                                    delegate: Rectangle {
                                        id: weTagPill
                                        required property var modelData
                                        implicitWidth: weTagRow.implicitWidth + 14
                                        implicitHeight: 24
                                        radius: Theme.radiusSm
                                        color: we_th_tag.hovered ? Theme.accentDim : Theme.surfaceActive
                                        border.color: we_th_tag.hovered ? Theme.accent : Theme.border
                                        border.width: we_th_tag.hovered ? 1.5 : 1

                                        RowLayout {
                                            id: weTagRow
                                            anchors.centerIn: parent
                                            spacing: 4
                                            MaterialIcon {
                                                iconName: "tag"
                                                pixelSize: 11
                                                color: we_th_tag.hovered ? Theme.accent : Theme.textSecondary
                                            }
                                            Text {
                                                text: weTagPill.modelData.name
                                                color: we_th_tag.hovered ? Theme.accent : Theme.text
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.fontSizeLabel
                                                font.bold: we_th_tag.hovered
                                            }
                                        }

                                        HoverHandler { id: we_th_tag; cursorShape: Qt.PointingHandCursor }
                                        TapHandler {
                                            onTapped: {
                                                root.tagClicked(weTagPill.modelData.name)
                                                root.close()
                                            }
                                        }
                                    }
                                }

                                Text {
                                    visible: parent.activeTagsList.length === 0 && root.details !== null
                                    text: "No tags specified"
                                    color: Theme.textDim
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeSmall
                                }
                            }
                        }

                        // Description Box
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            Text {
                                text: "Description"
                                color: Theme.textSecondary
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSmall
                                font.bold: true
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: Math.min(180, descText.implicitHeight + 20)
                                radius: Theme.radiusMd
                                color: Theme.surfaceActive
                                border.color: Theme.border
                                clip: true

                                MujoFlickable {
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    contentHeight: descText.implicitHeight

                                    Text {
                                        id: descText
                                        width: parent.width
                                        text: {
                                            if (root.details && root.details.description) return root.details.description
                                            if (root.wallpaperItem && root.wallpaperItem.description) return root.wallpaperItem.description
                                            return "No description provided."
                                        }
                                        color: Theme.text
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeSmall
                                        wrapMode: Text.WordWrap
                                    }
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

                // Live Download Progress Bar (visible during active direct download)
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
                                if (root.previewTargetUrl) {
                                    WallpaperDownloads.cancelDownload(root.previewTargetUrl)
                                }
                            }
                        }
                    }
                }

                // Subscribe in Steam Action
                DialogButton {
                    visible: root.wallpaperItem && !root.wallpaperItem.is_local && !root.isDownloading
                    text: WallpaperEngine.downloadingId === (root.wallpaperItem ? root.wallpaperItem.id : "") ? "Opening Steam…" : "Subscribe in Steam"
                    iconName: "sports_esports"
                    onClicked: {
                        if (root.wallpaperItem && root.wallpaperItem.id) {
                            WallpaperEngine.downloadWallpaper(root.wallpaperItem.id, function(ok) {
                                Notifications.notify("Steam Workshop", "Opened subscription in Steam client.", "sports_esports", "normal", { appName: "Wallpaper Engine" })
                            })
                        }
                    }
                }

                // Apply Wallpaper Action
                DialogButton {
                    text: WallpaperEngine.applyingId === (root.wallpaperItem ? (root.wallpaperItem.id || root.wallpaperItem.path) : "") ? "Applying…" : "Apply Wallpaper"
                    iconName: "wallpaper"
                    primary: true
                    onClicked: {
                        if (root.wallpaperItem) {
                            WallpaperEngine.applyWallpaper(root.wallpaperItem, "", function(ok, path) {
                                if (ok) Notifications.notify("Wallpaper Applied", "Active Wallpaper Engine project set.", "wallpaper", "normal", { appName: "Wallpaper Engine" })
                            })
                        }
                    }
                }
            }
        }
    }

    Keys.onEscapePressed: root.close()
}
