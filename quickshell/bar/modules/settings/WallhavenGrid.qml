import QtQuick
import QtQuick.Layouts
import "../../theme"
import "../../components"
import "../../services"

// Wallhaven search results. The grid owns the pagination trigger — it is the
// only thing that knows how close the viewport is to the end of the model.
MujoGridView {
    id: grid

    // Emitted on click; the panel opens the inspector modal.
    signal itemActivated(var itemData)

    cellWidth: Math.floor((width - 6) / Math.max(1, Math.floor((width - 6) / 230)))
    cellHeight: cellWidth * 0.62 + 8
    model: Wallhaven.resultsModel

    onContentYChanged: {
        if (!Wallhaven.loading && !Wallhaven.loadingMore && Wallhaven.hasMore) {
            if (contentY + height >= contentHeight - cellHeight * 2.5) {
                Wallhaven.loadMore()
            }
        }
    }

    delegate: Item {
        id: cardItem
        required property var itemData
        readonly property var modelData: itemData
        readonly property string targetUrl: (itemData && itemData.path) ? itemData.path : ""
        readonly property var dlInfo: targetUrl ? WallpaperDownloads.getDownload(targetUrl) : null
        readonly property bool isDlActive: dlInfo !== null && dlInfo.status === "downloading"
        readonly property bool isDlDone: targetUrl ? (WallpaperDownloads.isCompleted(targetUrl) || (dlInfo !== null && dlInfo.status === "done")) : false

        width: grid.cellWidth
        height: grid.cellHeight

        Rectangle {
            id: cardBox
            anchors.fill: parent
            anchors.margins: 5
            radius: Theme.radiusMd
            color: Theme.surface
            clip: true
            border.width: isDlActive ? 2 : (wh_hh.hovered ? 2 : 1)
            border.color: isDlActive ? Theme.accent : (wh_hh.hovered ? Theme.accent : Theme.border)

            Behavior on border.color { ColorAnimation { duration: Anim.d(Anim.fast) } }

            Image {
                id: thumbImg
                anchors.fill: parent
                anchors.margins: 2
                source: {
                    if (itemData.cached_preview) return itemData.cached_preview
                    if (itemData.thumbs && itemData.thumbs.small) return itemData.thumbs.small
                    return ""
                }
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                smooth: true
                sourceSize.width: 320
                sourceSize.height: 180
                clip: true

                Rectangle {
                    anchors.fill: parent
                    color: Theme.surfaceActive
                    visible: thumbImg.status !== Image.Ready
                    Spinner { anchors.centerIn: parent; visible: thumbImg.status === Image.Loading }
                }
            }

            // Dimension Pill
            Rectangle {
                anchors { bottom: parent.bottom; left: parent.left; margins: 6 }
                visible: !wh_hh.hovered && !isDlActive && itemData.dimension_x !== undefined
                radius: Theme.radiusSm
                color: "#cc000000"
                implicitWidth: dimLabel.implicitWidth + 10
                implicitHeight: 18

                Text {
                    id: dimLabel
                    anchors.centerIn: parent
                    text: itemData.dimension_x + "×" + itemData.dimension_y
                    color: "#ffffff"
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeLabel
                }
            }

            // Purity dot
            Rectangle {
                anchors { top: parent.top; left: parent.left; margins: 6 }
                visible: !wh_hh.hovered && !isDlActive
                width: 8; height: 8; radius: 4
                color: {
                    var p = (itemData.purity || "sfw").toLowerCase()
                    if (p === "sfw") return Theme.success
                    if (p === "sketchy") return Theme.warning
                    return Theme.error
                }
            }

            // Downloaded Checkmark Badge
            Rectangle {
                anchors { top: parent.top; right: parent.right; margins: 6 }
                visible: isDlDone && !isDlActive && !wh_hh.hovered
                width: 18; height: 18; radius: 9
                color: Theme.success

                MaterialIcon {
                    anchors.centerIn: parent
                    iconName: "check"
                    pixelSize: 12
                    color: "#000000"
                }
            }

            // Active Download Progress Overlay on Card
            Rectangle {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 4 }
                implicitHeight: 40
                radius: Theme.radiusSm
                color: "#ee090c14"
                border.color: Theme.accent
                visible: isDlActive
                z: 20

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 6
                    spacing: 4

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        Spinner { implicitWidth: 12; implicitHeight: 12 }

                        Text {
                            text: (dlInfo ? Math.round(dlInfo.progress) + "%" : "0%")
                            color: Theme.accent
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSizeSmall
                            font.bold: true
                        }

                        Text {
                            text: dlInfo ? dlInfo.speed : ""
                            color: Theme.textSecondary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeLabel - 1
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }

                        IconButton {
                            iconName: "close"
                            implicitWidth: 18; implicitHeight: 18
                            onClicked: {
                                if (targetUrl) WallpaperDownloads.cancelDownload(targetUrl)
                            }
                        }
                    }

                    // Progress track & fill
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 4
                        radius: 2
                        color: Theme.surfaceActive

                        Rectangle {
                            anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                            width: parent.width * (dlInfo ? (dlInfo.progress / 100.0) : 0)
                            radius: 2
                            color: Theme.accent
                            Behavior on width { NumberAnimation { duration: Anim.d(Anim.fast) } }
                        }
                    }
                }
            }

            TapHandler {
                onTapped: grid.itemActivated(itemData)
            }

            HoverHandler {
                id: wh_hh
                cursorShape: Qt.PointingHandCursor
                onHoveredChanged: {
                    if (hovered && itemData && itemData.id) {
                        Wallhaven.fetchDetails(itemData.id)
                    }
                }
            }

            // Hover Actions Overlay
            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: "#cc000000"
                opacity: wh_hh.hovered && !isDlActive ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: Anim.d(Anim.fast) } }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 6

                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 6

                        DialogButton {
                            text: Wallhaven.applyingUrl === itemData.path ? "Applying…" : "Apply"
                            primary: true
                            iconName: "wallpaper"
                            onClicked: {
                                Wallhaven.applyWallpaper(itemData.path, function(ok, path) {
                                    if (ok) Notifications.notify("Wallpaper Set", "Active on all screens.", "wallpaper", "normal", { appName: "Wallhaven" })
                                })
                            }
                        }

                        DialogButton {
                            text: isDlDone ? "Saved ✓" : "Save"
                            iconName: isDlDone ? "check" : "download"
                            onClicked: {
                                if (!isDlActive && !isDlDone) {
                                    Wallhaven.saveWallpaper(itemData.path, "Wallhaven #" + itemData.id)
                                }
                            }
                        }
                    }

                    DialogButton {
                        Layout.alignment: Qt.AlignHCenter
                        text: "Inspect Details"
                        iconName: "info"
                        onClicked: grid.itemActivated(itemData)
                    }
                }
            }
        }
    }
}
