import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import "../../theme"
import "../../components"
import "../../services"

// The Mujo Staging Surface (無常) — Per-screen edge slide-out staging deck.
//
// Input Architecture:
// - Always-on-top, mostly click-through PanelWindow.
// - Input mask covers only the sleek resting edge tab when idle, expanding
//   to the full interactive lane when hovering or during active drag staging.
// - Features ambient living edge luminescence, MultiEffect elevation shadows,
//   specular rim lighting, and a holographic drag-target harbor.
Variants {
    model: Quickshell.screens

    PanelWindow {
        id: win
        required property var modelData
        screen: modelData
        visible: Shelf.enabled

        WlrLayershell.namespace: "qs-shelf"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        anchors { top: true; bottom: true; left: true; right: true }

        readonly property bool onRight: Shelf.edge !== "left"
        readonly property int stripIdleW: 6
        readonly property int stripActiveW: 10
        readonly property int catchZoneW: 40
        readonly property int bodyW: 320
        readonly property int margin: Theme.barMargin + 4
        readonly property int laneH: Math.max(180, Math.round(win.height * Shelf.stripLength))
        readonly property int laneY: Math.round((win.height - laneH) / 2)

        // Open state management with anti-flicker boundary grace
        property bool _grace: false
        property bool _forceClosed: false
        readonly property bool open: !_forceClosed && (edgeDrop.containsDrag || drop.containsDrag || laneHover.hovered || notchHh.hovered || _grace)

        Connections {
            target: edgeDrop
            function onContainsDragChanged() {
                if (edgeDrop.containsDrag) {
                    graceTimer.stop()
                    win._grace = false
                } else if (!drop.containsDrag) {
                    win._grace = true
                    graceTimer.restart()
                }
            }
        }

        Connections {
            target: drop
            function onContainsDragChanged() {
                if (drop.containsDrag) {
                    graceTimer.stop()
                    win._grace = false
                } else if (!edgeDrop.containsDrag) {
                    win._grace = true
                    graceTimer.restart()
                }
            }
        }
        Timer { id: graceTimer; interval: 600; onTriggered: win._grace = false }

        // Mask region: Generous catch zone when idle; full interactive lane when active
        mask: Region { item: win.open ? lane : edgeCatchZone }

        // ── 1. Resting Edge Catch Zone & Tab (Zen Notch) ──────────────────────
        Item {
            id: edgeCatchZone
            width: win.catchZoneW
            height: win.laneH
            y: win.laneY
            x: win.onRight ? win.width - width : 0
            visible: !win.open

            HoverHandler {
                id: notchHh
                cursorShape: Qt.PointingHandCursor
            }

            DropArea {
                id: edgeDrop
                anchors.fill: parent
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

            // Visual Notch inside the Catch Zone (anchored to the actual screen edge)
            Rectangle {
                id: restingNotch
                anchors {
                    top: parent.top
                    bottom: parent.bottom
                    right: win.onRight ? parent.right : undefined
                    left: win.onRight ? undefined : parent.left
                }
                width: (notchHh.hovered || edgeDrop.containsDrag) ? win.stripActiveW : win.stripIdleW
                radius: width / 2

                color: (Shelf.count > 0 || edgeDrop.containsDrag)
                       ? (Anim.ambient ? Theme.withAlpha(Theme.accent, Anim.breath(0.5, 0.95)) : Theme.accent)
                       : (notchHh.hovered ? Theme.accent : Theme.borderStrong)

                opacity: (Shelf.count > 0 || edgeDrop.containsDrag) ? 1.0 : (notchHh.hovered ? 0.8 : 0.35)

                Behavior on width { NumberAnimation { duration: Anim.d(Anim.fast); easing.type: Anim.easeStandard } }
                Behavior on color { ColorAnimation { duration: Anim.d(Anim.fast) } }
                Behavior on opacity { NumberAnimation { duration: Anim.d(Anim.fast) } }

                // Micro jewel dot when holding items
                Rectangle {
                    visible: Shelf.count > 0
                    anchors.centerIn: parent
                    width: 4
                    height: 24
                    radius: 2
                    color: Theme.accentText
                    opacity: Shelf.count > 0 && Anim.ambient ? Anim.breath(0.7, 1.0) : 0.9
                }
            }
        }

        // ── 2. Interactive Lane (Sliding Body + Holographic Drag Target) ──────
        Item {
            id: lane
            width: win.bodyW + win.margin + 20
            height: Math.max(win.laneH, bodyContainer.height + 24)
            x: win.onRight ? win.width - width : 0
            y: Math.round((win.height - height) / 2)

            HoverHandler {
                id: laneHover
                onHoveredChanged: if (!hovered) win._forceClosed = false
            }

            DropArea {
                id: drop
                anchors.fill: parent
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

            // Elevation Drop Shadow
            Rectangle {
                id: shadowSrc
                x: bodyContainer.x
                y: bodyContainer.y
                width: bodyContainer.width
                height: bodyContainer.height
                radius: Theme.radiusLg
                color: "#000000"
                visible: false
                layer.enabled: true
            }
            MultiEffect {
                anchors.fill: shadowSrc
                source: shadowSrc
                autoPaddingEnabled: true
                shadowEnabled: true
                shadowColor: "#000000"
                shadowBlur: 1.2
                shadowVerticalOffset: 6
                shadowOpacity: 0.65
                opacity: win.open ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: Anim.d(Anim.enter) } }
            }

            // Sliding Body Container
            Item {
                id: bodyContainer
                width: win.bodyW
                height: Math.min(Math.round(win.height * 0.72),
                                 Math.max(win.laneH, flick.contentHeight + 36))
                anchors.verticalCenter: parent.verticalCenter

                // Spatial slide emergence
                x: win.open
                   ? (win.onRight ? lane.width - width - win.margin : win.margin)
                   : (win.onRight ? lane.width + 16 : -width - 16)

                Behavior on x {
                    NumberAnimation {
                        duration: Anim.d(Anim.slow)
                        easing.type: Anim.easeStandard
                    }
                }

                Rectangle {
                    id: body
                    anchors.fill: parent
                    color: Theme.bg
                    radius: Theme.radiusLg
                    border.color: drop.containsDrag
                                  ? Theme.accent
                                  : (win.open && Anim.ambient ? Theme.withAlpha(Theme.borderStrong, Anim.breath(0.6, 0.9)) : Theme.border)
                    border.width: drop.containsDrag ? 2 : 1
                    clip: true

                    Behavior on border.color { ColorAnimation { duration: Anim.d(Anim.fast) } }

                    // Specular top highlight line
                    Rectangle {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 1
                        color: Theme.withAlpha("#ffffff", 0.06)
                    }

                    Flickable {
                        id: flick
                        anchors.fill: parent
                        anchors.margins: 14
                        contentHeight: shelfBody.implicitHeight
                        boundsBehavior: Flickable.StopAtBounds
                        clip: true

                        ShelfView {
                            id: shelfBody
                            width: flick.width
                            panelWindow: win
                            onMinimizeRequested: {
                                win._grace = false
                                win._forceClosed = true
                            }
                        }
                    }

                    // ── 3. Holographic Drag-In Harbor Overlay ─────────────────
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 8
                        radius: Theme.radiusMd
                        color: Theme.withAlpha(Theme.accent, 0.18)
                        border.color: Theme.accent
                        border.width: 2
                        opacity: drop.containsDrag ? 1.0 : 0.0
                        visible: opacity > 0
                        Behavior on opacity { NumberAnimation { duration: Anim.d(Anim.fast) } }

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 10

                            Rectangle {
                                Layout.alignment: Qt.AlignHCenter
                                implicitWidth: 48
                                implicitHeight: 48
                                radius: Theme.radiusMd
                                color: Theme.accent
                                border.color: "#ffffff"
                                border.width: 1

                                MaterialIcon {
                                    anchors.centerIn: parent
                                    iconName: "file_download"
                                    pixelSize: 24
                                    color: Theme.accentText
                                }
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: "Release to Stage Items"
                                color: Theme.accent
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeTitle
                                font.bold: true
                            }
                        }
                    }
                }
            }
        }
    }
}
