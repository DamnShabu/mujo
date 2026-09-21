import QtQuick
import QtQuick.Layouts
import "../../theme"
import "../../components"
import "../../services"

// The wallpaper catalogue browser: local library, Wallhaven, and Wallpaper
// Engine / Steam Workshop, plus their filter bars, loading / empty / error
// states and detail modals.
//
// This is deliberately NOT a SettingsPage. All three sources are infinite-
// scrolling grids that need the full viewport height and own their scrolling;
// nesting them inside the page Flickable would give two competing scroll axes.
// The settings that *do* belong to this category live in WallpaperEffectsGroup.
Item {
    id: root

    // "library" | "wallhaven" | "wallpaperengine", owned by AppearancePage.
    required property string tab
    required property var localList
    required property string currentImage

    signal wpRun(var args)

    // ── Source filter bars ────────────────────────────────────────────────────
    ColumnLayout {
        anchors.fill: parent
        spacing: 14

        WallhavenControls {
            id: whControls
            visible: root.tab === "wallhaven"
            Layout.fillWidth: true
        }

        WallpaperEngineControls {
            id: weControls
            visible: root.tab === "wallpaperengine"
            Layout.fillWidth: true
        }

        // ── Grids ─────────────────────────────────────────────────────────────
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            WallpaperLibraryGrid {
                id: libGrid
                anchors.fill: parent
                visible: root.tab === "library"
                model: root.localList
                currentImage: root.currentImage
                onWallpaperChosen: function (path) { root.wpRun(["set", path]) }
            }

            WallhavenGrid {
                id: whGrid
                anchors.fill: parent
                visible: root.tab === "wallhaven" && !Wallhaven.loading && count > 0
                onItemActivated: function (itemData) { detailModal.show(itemData) }
            }

            WallpaperEngineGrid {
                id: weGrid
                anchors.fill: parent
                visible: root.tab === "wallpaperengine" && !WallpaperEngine.loading && count > 0
                onItemActivated: function (itemData) { weDetailModal.show(itemData) }
            }

            // ── Empty library ─────────────────────────────────────────────────
            ColumnLayout {
                anchors.centerIn: parent
                visible: root.tab === "library" && root.localList.length === 0
                spacing: 12

                MaterialIcon {
                    Layout.alignment: Qt.AlignHCenter
                    iconName: "photo_library"
                    pixelSize: 44
                    color: Theme.textDim
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "Your library is empty"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeTitle
                    font.bold: true
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "Download from Wallhaven, or drop images into ~/Pictures/Wallpapers."
                    color: Theme.textSecondary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeBody
                }
            }

            // ── Active downloads pill ─────────────────────────────────────────
            Rectangle {
                anchors { right: parent.right; bottom: parent.bottom; margins: 20 }
                visible: WallpaperDownloads.activeCount > 0
                implicitHeight: 44
                implicitWidth: activeDlRow.implicitWidth + 24
                radius: Theme.radiusMd
                color: Theme.surface
                border.color: Theme.accent
                border.width: 1.5
                z: 80

                scale: WallpaperDownloads.activeCount > 0 ? 1.0 : 0.8
                Behavior on scale { NumberAnimation { duration: Anim.d(Anim.standard); easing.type: Anim.easeStandard } }

                RowLayout {
                    id: activeDlRow
                    anchors.centerIn: parent
                    spacing: 10

                    Spinner { implicitWidth: 16; implicitHeight: 16 }

                    ColumnLayout {
                        spacing: 1
                        Text {
                            text: "Downloading " + WallpaperDownloads.activeCount + " wallpaper" + (WallpaperDownloads.activeCount > 1 ? "s" : "") + "…"
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            font.bold: true
                        }
                        Text {
                            text: "Saving straight to your library"
                            color: Theme.textSecondary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeLabel
                        }
                    }
                }
            }

            // ── Scroll to top ─────────────────────────────────────────────────
            Rectangle {
                anchors { right: parent.right; bottom: parent.bottom; margins: 16 }
                visible: WallpaperDownloads.activeCount === 0
                         && ((root.tab === "wallhaven" && whGrid.contentY > 500)
                             || (root.tab === "wallpaperengine" && weGrid.contentY > 500))
                implicitWidth: 38
                implicitHeight: 38
                radius: 19
                color: Theme.accent
                border.color: Theme.borderStrong
                z: 30

                Accessible.role: Accessible.Button
                Accessible.name: "Scroll back to top"

                MaterialIcon {
                    anchors.centerIn: parent
                    iconName: "arrow_upward"
                    pixelSize: 18
                    color: Theme.accentText
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: root.tab === "wallhaven" ? whGrid.scrollToTop() : weGrid.scrollToTop()
                }
            }

            // ── Pagination spinner ────────────────────────────────────────────
            Rectangle {
                anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter; margins: 10 }
                visible: (root.tab === "wallhaven" && Wallhaven.loadingMore)
                         || (root.tab === "wallpaperengine" && WallpaperEngine.loadingMore)
                implicitHeight: 32
                implicitWidth: loadMoreRow.implicitWidth + 24
                radius: Theme.radiusSm
                color: Theme.surface
                border.color: Theme.border
                z: 25

                RowLayout {
                    id: loadMoreRow
                    anchors.centerIn: parent
                    spacing: 8
                    Spinner { implicitWidth: 16; implicitHeight: 16 }
                    Text {
                        text: "Loading more wallpapers…"
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                    }
                }
            }

            // ── Initial load ──────────────────────────────────────────────────
            ColumnLayout {
                anchors.centerIn: parent
                visible: (root.tab === "wallhaven" && Wallhaven.loading)
                         || (root.tab === "wallpaperengine" && (WallpaperEngine.loading || WallpaperEngine.loadingInstalled))
                spacing: 12

                Spinner {
                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth: 36
                    implicitHeight: 36
                }
                Text {
                    text: root.tab === "wallhaven" ? "Exploring Wallhaven wallpapers…" : "Exploring Wallpaper Engine wallpapers…"
                    color: Theme.textSecondary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeBody
                }
            }

            // ── Error pill (bottom-anchored, compact like pagination loader) ──
            Rectangle {
                id: errorPill
                anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter; margins: 10 }
                visible: (root.tab === "wallhaven" && !Wallhaven.loading && !Wallhaven.loadingMore && Wallhaven.error !== "" && Wallhaven.errorType !== "empty")
                         || (root.tab === "wallpaperengine" && !WallpaperEngine.loading && !WallpaperEngine.loadingMore && WallpaperEngine.error !== "" && WallpaperEngine.errorType !== "empty")
                implicitHeight: 32
                implicitWidth: errRow.implicitWidth + 20
                radius: Theme.radiusSm
                color: Theme.surface
                border.color: Theme.borderStrong
                z: 35

                RowLayout {
                    id: errRow
                    anchors.centerIn: parent
                    spacing: 8

                    MaterialIcon {
                        iconName: "cloud_off"
                        pixelSize: 14
                        color: Theme.warning
                    }

                    Text {
                        text: {
                            var msg = root.tab === "wallhaven" ? Wallhaven.error : WallpaperEngine.error
                            if (!msg) return "Connection issue"
                            if (msg.toLowerCase().indexOf("network") >= 0 || msg.toLowerCase().indexOf("connection") >= 0 || msg.toLowerCase().indexOf("timed out") >= 0) {
                                return "Connection timed out"
                            }
                            return msg
                        }
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                    }

                    Rectangle {
                        implicitHeight: 20
                        implicitWidth: retryRow.implicitWidth + 10
                        radius: Theme.radiusSm
                        color: retryHh.hovered ? Theme.surfaceHover : Theme.surfaceActive
                        border.color: Theme.border

                        RowLayout {
                            id: retryRow
                            anchors.centerIn: parent
                            spacing: 3
                            MaterialIcon {
                                iconName: "refresh"
                                pixelSize: 11
                                color: Theme.accent
                            }
                            Text {
                                text: "Retry"
                                color: Theme.accent
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeLabel
                                font.bold: true
                            }
                        }

                        HoverHandler { id: retryHh; cursorShape: Qt.PointingHandCursor }
                        TapHandler {
                            onTapped: {
                                if (root.tab === "wallhaven") Wallhaven.search(true)
                                else WallpaperEngine.search(true)
                            }
                        }
                    }

                    IconButton {
                        iconName: "close"
                        implicitWidth: 18
                        implicitHeight: 18
                        iconColor: Theme.textDim
                        onClicked: {
                            if (root.tab === "wallhaven") {
                                Wallhaven.error = ""
                                Wallhaven.errorType = ""
                            } else {
                                WallpaperEngine.error = ""
                                WallpaperEngine.errorType = ""
                            }
                        }
                    }
                }
            }

            // ── No results ────────────────────────────────────────────────────
            ColumnLayout {
                anchors.centerIn: parent
                visible: (root.tab === "wallhaven" && !Wallhaven.loading
                          && Wallhaven.resultsModel.count === 0
                          && (Wallhaven.errorType === "empty" || Wallhaven.error === "" || Wallhaven.errorType === "timeout" || Wallhaven.errorType === "network_error"))
                         || (root.tab === "wallpaperengine" && !WallpaperEngine.loading && !WallpaperEngine.loadingInstalled
                             && (WallpaperEngine.errorType === "empty" || WallpaperEngine.error === "" || WallpaperEngine.errorType === "timeout" || WallpaperEngine.errorType === "network_error")
                             && ((WallpaperEngine.activeSource === "installed" ? WallpaperEngine.installedModel.count : WallpaperEngine.resultsModel.count) === 0))
                spacing: 14

                MaterialIcon {
                    Layout.alignment: Qt.AlignHCenter
                    iconName: "image_search"
                    pixelSize: 44
                    color: Theme.textDim
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.tab === "wallpaperengine" && WallpaperEngine.activeSource === "installed"
                        ? "No Installed Wallpapers Found" : "No Wallpapers Found"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeTitle
                    font.bold: true
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.tab === "wallpaperengine" && WallpaperEngine.activeSource === "installed"
                        ? "Subscribe to items on Steam Workshop, or place project folders into ~/Pictures/Wallpapers/WallpaperEngine"
                        : "Try broadening your keywords, removing active tag filters, or resetting filters."
                    color: Theme.textSecondary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeBody
                }
                DialogButton {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.tab === "wallpaperengine" && WallpaperEngine.activeSource === "installed"
                        ? "Switch to Steam Workshop" : "Clear All Filters"
                    iconName: root.tab === "wallpaperengine" && WallpaperEngine.activeSource === "installed"
                        ? "cloud_download" : "restart_alt"
                    primary: true
                    onClicked: {
                        if (root.tab === "wallhaven") {
                            Wallhaven.resetFilters()
                        } else if (WallpaperEngine.activeSource === "installed") {
                            WallpaperEngine.activeSource = "workshop"
                            WallpaperEngine.search(true)
                        } else {
                            WallpaperEngine.resetFilters()
                        }
                    }
                }
            }
        }
    }

    // ── Dismiss scrim for the tag suggestion dropdowns ───────────────────────
    MouseArea {
        anchors.fill: parent
        z: 45
        visible: whControls.suggestionsOpen || weControls.suggestionsOpen
        onClicked: {
            whControls.dismissSuggestions()
            weControls.dismissSuggestions()
        }
    }

    // ── Inspector modals ──────────────────────────────────────────────────────
    WallhavenDetailModal {
        id: detailModal
        onTagClicked: function (t) { whControls.addTag(t) }
        onColorClicked: function (c) { Wallhaven.setColor(c) }
        onCategoryClicked: function (cat) { whControls.addTag(cat) }
        onResolutionClicked: function (res) {
            Wallhaven.atleast = res
            Wallhaven.search(true)
        }
    }

    WallpaperEngineDetailModal {
        id: weDetailModal
        onTagClicked: function (t) { weControls.addTag(t) }
        onTypeClicked: function (t) {
            WallpaperEngine.selectedType = t
            WallpaperEngine.search(true)
        }
    }
}
