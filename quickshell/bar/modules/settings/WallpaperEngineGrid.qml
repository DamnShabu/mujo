import QtQuick
import QtQuick.Layouts
import "../../theme"
import "../../components"
import "../../services"

// Wallpaper Engine results — Workshop search or the installed set, whichever
// source the service is currently pointed at. Paginates only for Workshop,
// since the installed list arrives whole.
MujoGridView {
    id: grid

    // Emitted on click; the panel opens the inspector modal.
    signal itemActivated(var itemData)

    cellWidth: Math.floor((width - 6) / Math.max(1, Math.floor((width - 6) / 230)))
    cellHeight: cellWidth * 0.62 + 8
    model: WallpaperEngine.activeSource === "installed" ? WallpaperEngine.installedModel : WallpaperEngine.resultsModel

    onContentYChanged: {
        if (WallpaperEngine.activeSource === "workshop" && !WallpaperEngine.loading && !WallpaperEngine.loadingMore && WallpaperEngine.hasMore) {
            if (contentY + height >= contentHeight - cellHeight * 2.5) {
                WallpaperEngine.loadMore()
            }
        }
    }

    delegate: Item {
        id: weCardItem
        required property var itemData
        readonly property var modelData: itemData
        readonly property string weTargetUrl: (itemData && (itemData.cached_preview || itemData.preview || itemData.url)) ? (itemData.cached_preview || itemData.preview || itemData.url) : ""
        readonly property var weDlInfo: weTargetUrl ? WallpaperDownloads.getDownload(weTargetUrl) : null
        readonly property bool isWeDlActive: weDlInfo !== null && weDlInfo.status === "downloading"

        width: grid.cellWidth
        height: grid.cellHeight

        Rectangle {
            id: weCardBox
            anchors.fill: parent
            anchors.margins: 5
            radius: Theme.radiusMd
            color: Theme.surface
            clip: true
            border.width: isWeDlActive ? 2 : (we_hh.hovered ? 2 : 1)
            border.color: isWeDlActive ? Theme.accent : (we_hh.hovered ? Theme.accent : Theme.border)

            Behavior on border.color { ColorAnimation { duration: Anim.d(Anim.fast) } }

            Image {
                id: weThumbImg
                anchors.fill: parent
                anchors.margins: 2
                source: {
                    var p = (itemData && (itemData.cached_preview || itemData.preview)) ? (itemData.cached_preview || itemData.preview) : ""
                    if (p.startsWith("/")) return "file://" + p
                    return p
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
                    visible: weThumbImg.status !== Image.Ready
                    Spinner { anchors.centerIn: parent; visible: weThumbImg.status === Image.Loading }
                }
            }

            // NSFW Blur / Shield Overlay
            Rectangle {
                anchors.fill: parent
                visible: WallpaperEngine.blurNsfw && (itemData.purity === "nsfw" || itemData.age_rating === "Mature") && !we_hh.hovered && !isWeDlActive
                color: "#ee0f121a"

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 4
                    MaterialIcon {
                        Layout.alignment: Qt.AlignHCenter
                        iconName: "visibility_off"
                        pixelSize: 22
                        color: Theme.error
                    }
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "NSFW (18+)"
                        color: Theme.error
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeLabel
                        font.bold: true
                    }
                }
            }

            // Purity indicator dot at top-left
            Rectangle {
                anchors { top: parent.top; left: parent.left; margins: 6 }
                visible: !we_hh.hovered && !isWeDlActive
                width: 8; height: 8; radius: 4
                color: {
                    var p = (itemData && itemData.purity ? itemData.purity : "sfw").toLowerCase()
                    if (p === "sfw") return Theme.success
                    if (p === "sketchy") return Theme.warning
                    return Theme.error
                }
            }

            // Type Pill at top-left (offset right of purity dot)
            Rectangle {
                anchors { top: parent.top; left: parent.left; leftMargin: 18; topMargin: 6 }
                visible: !we_hh.hovered && !isWeDlActive
                radius: Theme.radiusSm
                implicitHeight: 18
                implicitWidth: weTypeTxt.implicitWidth + 10
                color: "#cc000000"

                Text {
                    id: weTypeTxt
                    anchors.centerIn: parent
                    text: ((itemData && itemData.type) ? itemData.type : "scene").toUpperCase()
                    color: Theme.accent
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeLabel - 1
                    font.bold: true
                }
            }

            // Rating badge at bottom-left
            Rectangle {
                anchors { bottom: parent.bottom; left: parent.left; margins: 6 }
                visible: !we_hh.hovered && !isWeDlActive && itemData.rating !== undefined && itemData.rating > 0
                radius: Theme.radiusSm
                color: "#cc000000"
                implicitWidth: weRatingLabel.implicitWidth + 10
                implicitHeight: 18

                RowLayout {
                    id: weRatingLabel
                    anchors.centerIn: parent
                    spacing: 2
                    MaterialIcon { iconName: "star"; pixelSize: 11; color: "#ffca28" }
                    Text {
                        text: "" + itemData.rating
                        color: "#ffffff"
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeLabel
                    }
                }
            }

            // Installed badge at top-right
            Rectangle {
                anchors { top: parent.top; right: parent.right; margins: 6 }
                visible: !we_hh.hovered && !isWeDlActive && itemData && itemData.is_local
                width: 18; height: 18; radius: 9
                color: Theme.success
                MaterialIcon {
                    anchors.centerIn: parent
                    iconName: "check"
                    pixelSize: 12
                    color: "#000000"
                }
            }

            // Active Direct Download Progress Bar Overlay
            Rectangle {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 4 }
                implicitHeight: 40
                radius: Theme.radiusSm
                color: "#ee090c14"
                border.color: Theme.accent
                visible: isWeDlActive
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
                            text: (weDlInfo ? Math.round(weDlInfo.progress) + "%" : "0%")
                            color: Theme.accent
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSizeSmall
                            font.bold: true
                        }

                        Text {
                            text: weDlInfo ? weDlInfo.speed : ""
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
                                if (weTargetUrl) WallpaperDownloads.cancelDownload(weTargetUrl)
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
                            width: parent.width * (weDlInfo ? (weDlInfo.progress / 100.0) : 0)
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
                id: we_hh
                cursorShape: Qt.PointingHandCursor
                onHoveredChanged: {
                    if (hovered && itemData && (itemData.id || itemData.path)) {
                        WallpaperEngine.fetchDetails(itemData.path || itemData.id)
                    }
                }
            }

            // Hover Actions Overlay
            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: "#cc000000"
                opacity: we_hh.hovered && !isWeDlActive ? 1 : 0
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
                            text: WallpaperEngine.applyingId === (itemData ? (itemData.id || itemData.path) : "") ? "Applying…" : "Apply Live"
                            primary: true
                            iconName: "wallpaper"
                            onClicked: {
                                WallpaperEngine.applyWallpaper(itemData, "", function(ok, path) {
                                    if (ok) Notifications.notify("Wallpaper Applied", "Wallpaper Engine project active.", "wallpaper", "normal", { appName: "Wallpaper Engine" })
                                })
                            }
                        }

                        DialogButton {
                            visible: itemData && !itemData.is_local
                            text: "Steam"
                            iconName: "sports_esports"
                            onClicked: {
                                WallpaperEngine.openInSteam(itemData.id)
                            }
                        }
                    }

                    DialogButton {
                        Layout.alignment: Qt.AlignHCenter
                        text: "Inspect Details"
                        iconName: "info"
                        onClicked: grid.itemActivated(itemData)
                    }

                    Text {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignHCenter
                        horizontalAlignment: Text.AlignHCenter
                        text: (itemData && itemData.title) ? itemData.title : ""
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        font.bold: true
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }
                }
            }
        }
    }
}
