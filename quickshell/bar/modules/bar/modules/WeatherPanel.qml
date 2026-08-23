import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

// Weather — a large informational page: live current conditions + 5-day forecast
// (from the shared Weather service) plus configuration. All consumers in the
// shell read the same Weather singleton, so this page is both control and preview.
Item {
    id: root

    property var cfg: ({ units: "celsius", wind: "kmh", interval: 900, location: "" })
    property string loc: ""

    function set(key, val) { Quickshell.execDetached(["mujo", "weather", "set", key, String(val)]) }

    FileView {
        id: cfgView
        path: (Quickshell.env("HOME") || "/tmp") + "/.config/quickshell/weather.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: { try { root.cfg = JSON.parse(text()); root.loc = root.cfg.location || "" } catch (e) {} }
    }

    readonly property var wx: Weather.data
    readonly property var intervals: [{ v: 300, l: "5 min" }, { v: 900, l: "15 min" }, { v: 1800, l: "30 min" }, { v: 3600, l: "1 hour" }]

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

            Text { text: "Weather"; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeTitle + 7; font.bold: true }

            // ── Hero: current conditions ──────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                radius: Theme.radiusLg
                color: Theme.surface
                border.color: Theme.border
                implicitHeight: 150
                Rectangle {
                    anchors.fill: parent; radius: parent.radius
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.10) }
                        GradientStop { position: 1.0; color: "transparent" }
                    }
                }

                // loading / error / data
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 22
                    spacing: 22
                    visible: root.wx !== null && Weather.error === ""

                    MaterialIcon {
                        iconName: root.wx ? Weather.iconFor(root.wx.code) : "cloud"
                        pixelSize: 84
                        color: Theme.accent
                    }
                    ColumnLayout {
                        spacing: 0
                        RowLayout {
                            spacing: 4
                            Text { text: root.wx ? root.wx.temp : "–"; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: 52; font.bold: true }
                            Text { text: Weather.unitSymbol(); color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: 22; Layout.topMargin: 8 }
                        }
                        Text { text: root.wx ? Weather.descFor(root.wx.code) : ""; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeTitle }
                        Text { text: root.wx ? (root.wx.city + "  ·  feels " + root.wx.feels + Weather.unitSymbol() + "  ·  " + root.wx.humidity + "%  ·  " + root.wx.wind + " " + root.wx.windUnit) : ""
                               color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSmall }
                    }
                    Item { Layout.fillWidth: true }
                    IconButton { iconName: "refresh"; onClicked: Weather.refresh(true) }
                }

                // states
                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 8
                    visible: root.wx === null || Weather.error !== ""
                    Spinner { Layout.alignment: Qt.AlignHCenter; visible: Weather.loading }
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: Weather.error !== "" ? ("Weather unavailable — " + Weather.error) : "Loading weather…"
                        color: Theme.textDim; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeBody
                    }
                }
            }

            // ── 5-day forecast ────────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                visible: root.wx !== null && root.wx.daily !== undefined
                spacing: 10
                Repeater {
                    model: root.wx ? root.wx.daily : []
                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        implicitHeight: 96
                        radius: Theme.radiusMd
                        color: Theme.surface
                        border.color: Theme.border
                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 4
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: index === 0 ? "Today" : Qt.formatDate(new Date(modelData.date), "ddd")
                                color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSmall
                            }
                            MaterialIcon { Layout.alignment: Qt.AlignHCenter; iconName: Weather.iconFor(modelData.code); pixelSize: 26; color: Theme.text }
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: modelData.max + "° / " + modelData.min + "°"
                                color: Theme.text; font.family: Theme.fontMono; font.pixelSize: Theme.fontSizeSmall
                            }
                        }
                    }
                }
            }

            // ── Location ──────────────────────────────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true; spacing: 10
                SectionLabel { text: "Location" }
                RowLayout {
                    Layout.fillWidth: true; spacing: 8
                    TextField {
                        Layout.fillWidth: true
                        placeholder: "City (e.g. Berlin) — leave empty to auto-detect"
                        text: root.loc
                        onAccepted: root.set("location", text)
                    }
                    DialogButton { text: "Set"; primary: true; onClicked: root.set("location", root.loc) }
                    DialogButton { text: "Auto-detect"; onClicked: root.set("location", "") }
                }
            }

            // ── Units ─────────────────────────────────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true; spacing: 10
                SectionLabel { text: "Temperature" }
                Flow {
                    Layout.fillWidth: true; spacing: 7
                    DisplayChip { label: "Celsius (°C)"; selected: root.cfg.units === "celsius"; onClicked: root.set("units", "celsius") }
                    DisplayChip { label: "Fahrenheit (°F)"; selected: root.cfg.units === "fahrenheit"; onClicked: root.set("units", "fahrenheit") }
                }
            }
            ColumnLayout {
                Layout.fillWidth: true; spacing: 10
                SectionLabel { text: "Wind speed" }
                Flow {
                    Layout.fillWidth: true; spacing: 7
                    Repeater {
                        model: [{ v: "kmh", l: "km/h" }, { v: "mph", l: "mph" }, { v: "ms", l: "m/s" }]
                        delegate: DisplayChip {
                            required property var modelData
                            label: modelData.l
                            selected: root.cfg.wind === modelData.v
                            onClicked: root.set("wind", modelData.v)
                        }
                    }
                }
            }
            ColumnLayout {
                Layout.fillWidth: true; spacing: 10
                SectionLabel { text: "Update interval" }
                Flow {
                    Layout.fillWidth: true; spacing: 7
                    Repeater {
                        model: root.intervals
                        delegate: DisplayChip {
                            required property var modelData
                            label: modelData.l
                            selected: (root.cfg.interval || 900) === modelData.v
                            onClicked: root.set("interval", modelData.v)
                        }
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                text: "Powered by Open-Meteo (no API key). Data is cached and shared across the bar, widgets, and this page."
                color: Theme.textDim; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSmall; wrapMode: Text.WordWrap
            }
            Item { implicitHeight: 4 }
        }
    }
}
