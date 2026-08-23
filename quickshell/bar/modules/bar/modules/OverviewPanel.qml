import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

// Overview — a dashboard of live status cards that jump to their section.
Item {
    id: root

    property int displays: 0
    property string vpn: "…"
    property int persistCount: 0
    property int credCount: 0
    property string wallpaper: ""

    Process { id: dsp; command: ["niri", "msg", "-j", "outputs"]
        stdout: StdioCollector { onStreamFinished: { try { root.displays = Object.keys(JSON.parse(this.text)).length } catch (e) {} } } }
    Process { id: vpnp; command: ["mullvad", "status"]
        stdout: StdioCollector { onStreamFinished: root.vpn = this.text.trim().split("\n")[0].trim() || "Disconnected" } }
    Process { id: prst; command: ["mujo", "persist", "current"]
        stdout: StdioCollector { onStreamFinished: { try { var c = JSON.parse(this.text); root.persistCount = (c.user.length + c.system.length) } catch (e) {} } } }
    Process { id: krg; command: ["mujo-keyring", "list"]
        stdout: StdioCollector { onStreamFinished: { try { root.credCount = JSON.parse(this.text).length } catch (e) {} } } }
    FileView { id: wpConf; path: (Quickshell.env("HOME") || "/tmp") + "/.config/quickshell/wallpaper.json"; watchChanges: true
        onFileChanged: reload(); onLoaded: { try { root.wallpaper = (JSON.parse(text())["default"] || {}).image || "" } catch (e) {} } }
    Component.onCompleted: { dsp.running = true; vpnp.running = true; prst.running = true; krg.running = true }

    readonly property color vpnColor: vpn === "Connected" ? Theme.success : (vpn === "Disconnected" ? Theme.textDim : Theme.warning)

    readonly property var cards: [
        { brand: "appearance", key: "appearance", title: "Appearance", value: Theme.presetLabels[Theme.presetName] || Theme.presetName, tint: Theme.accent },
        { brand: "display",    key: "display",    title: "Displays",   value: root.displays + (root.displays === 1 ? " monitor" : " monitors"), tint: "#22D3EE" },
        { brand: "network",    key: "network",    title: "Network / VPN", value: root.vpn, tint: root.vpnColor },
        { brand: "persistence",key: "persistence",title: "Persistence", value: root.persistCount + " paths", tint: "#F472B6" },
        { brand: "keyring",    key: "keyring",    title: "Keyring",    value: root.credCount + (root.credCount === 1 ? " credential" : " credentials"), tint: "#FBBF24" },
        { brand: "applications",key: "applications",title: "Applications", value: "Integrations", tint: "#818CF8" }
    ]

    Flickable {
        anchors.fill: parent
        anchors.margins: 26
        contentHeight: col.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: col
            width: parent.width
            spacing: 20

            RowLayout {
                spacing: 14
                BrandIcon { brand: "overview"; size: 48 }
                ColumnLayout {
                    spacing: 2
                    Text { text: "Welcome to mujō"; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeTitle + 8; font.bold: true }
                    Text { text: "A cohesive control center for your desktop."; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeBody }
                }
            }

            Grid {
                Layout.fillWidth: true
                columns: Math.max(1, Math.floor(width / 300))
                columnSpacing: 14
                rowSpacing: 14
                property real cellW: (width - (columns - 1) * 14) / columns

                Repeater {
                    model: root.cards
                    delegate: Rectangle {
                        required property var modelData
                        width: parent.cellW
                        height: 108
                        radius: Theme.radiusLg
                        color: Theme.surface
                        border.color: card_hh.hovered ? Theme.borderStrong : Theme.border
                        Behavior on border.color { ColorAnimation { duration: Theme.durationFast } }
                        scale: card_hh.hovered ? 1.01 : 1.0
                        Behavior on scale { NumberAnimation { duration: Theme.durationFast; easing.type: Easing.OutQuad } }

                        Rectangle {
                            anchors.fill: parent; radius: parent.radius
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: Qt.rgba(modelData.tint.r, modelData.tint.g, modelData.tint.b, 0.08) }
                                GradientStop { position: 1.0; color: "transparent" }
                            }
                        }
                        ColumnLayout {
                            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
                            spacing: 12
                            RowLayout {
                                Layout.fillWidth: true
                                BrandIcon { brand: modelData.brand; size: 38 }
                                Item { Layout.fillWidth: true }
                                MaterialIcon { iconName: "arrow_outward"; pixelSize: 18; color: card_hh.hovered ? Theme.accent : Theme.textDim }
                            }
                            ColumnLayout {
                                spacing: 1
                                Text { text: modelData.title; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSmall }
                                Text { text: modelData.value; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeTitle + 1; font.bold: true; elide: Text.ElideRight; Layout.fillWidth: true }
                            }
                        }
                        HoverHandler { id: card_hh; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: SettingsBus.go(modelData.key) }
                    }
                }
            }
        }
    }
}
